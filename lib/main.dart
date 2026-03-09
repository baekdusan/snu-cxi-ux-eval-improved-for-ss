import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'models/MIA_result.dart';
import 'models/DR_result.dart';
import 'models/saved_MIA_result.dart';
import 'models/screen_purpose.dart';
import 'models/usage_context.dart';
import 'models/evaluation_context.dart';
import 'models/ux_issue_result.dart';
import 'services/analysis_service.dart';
import 'services/dr_generation_service.dart';
import 'services/data_persistence_service.dart';
import 'screens/ux_evaluation_screen.dart';
import 'screens/design_representation_screen.dart';

// DEBUG: Set to true to start at UXEvaluationScreen for testing
const bool _debugStartAtUXEvaluation = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firebase AI를 사용하기 위해 익명 로그인 (API 키 대신 사용)
  await FirebaseAuth.instance.signInAnonymously();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CXI팀 휴리스틱 평가 자동화 시스템',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: _debugStartAtUXEvaluation
          ? UXEvaluationScreen(
              uploadedScreens: [
                // Mock data for debugging
                {'name': 'screen_1.png', 'bytes': null},
                {'name': 'screen_2.png', 'bytes': null},
                {'name': 'screen_3.png', 'bytes': null},
                {'name': 'screen_4.png', 'bytes': null},
              ],
            )
          : const UploadStartPage(),
    );
  }
}

class UploadStartPage extends StatefulWidget {
  const UploadStartPage({super.key});

  @override
  State<UploadStartPage> createState() => _UploadStartPageState();
}

class _UploadStartPageState extends State<UploadStartPage> {
  List<Map<String, dynamic>> uploadedScreens = [];
  int currentUploadIndex = 0;
  bool _isMIAEnabled = true; // MIA 토글 상태 (기본값: ON)

  // 평가 범위 및 특이사항 (MIA ON일 때 사용)
  String selectedScope = '변경/개선점에 집중하여 UX 이슈 찾기';
  final TextEditingController evaluationScopeController = TextEditingController();
  final TextEditingController evaluationNotesController = TextEditingController();

  Future<void> _pickImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result != null) {
      setState(() {
        // 파일명 순서대로 정렬
        final sortedFiles = result.files.toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        uploadedScreens = sortedFiles.map((file) {
          return {'name': file.name, 'bytes': file.bytes};
        }).toList();
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      uploadedScreens.removeAt(index);
    });
  }

  void _removeAllImages() {
    setState(() {
      uploadedScreens.clear();
    });
  }

  Future<void> _loadSavedAnalysisData() async {
    // ========================================
    // Step 1: 파일 선택 다이얼로그 표시 (MIA 토글 상태 전달)
    // ========================================
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => LoadFilesDialog(isMIAEnabled: _isMIAEnabled),
    );

    // 사용자가 취소했거나 위젯이 unmount된 경우
    if (result == null || !mounted) return;

    // ========================================
    // Step 2: 에이전트별 결과 추출
    // ========================================
    final mode = result['mode'] as String;
    final drResult1 = result['drResult1'] as DRResult?;
    final drResult2 = result['drResult2'] as DRResult?;
    final drResult3 = result['drResult3'] as DRResult?;
    final issuesResult1 = result['issuesResult1'] as UXIssueResult?;
    final issuesResult2 = result['issuesResult2'] as UXIssueResult?;
    final issuesResult3 = result['issuesResult3'] as UXIssueResult?;
    final selectedAgents = result['selectedAgents'] as Set<int>;

    final hasDR = drResult1 != null || drResult2 != null || drResult3 != null;
    final hasIssues = issuesResult1 != null || issuesResult2 != null || issuesResult3 != null;

    if (mode == 'mia') {
      // ========================================
      // MIA 모드
      // ========================================
      final savedData = result['savedData'] as SavedAnalysisData;
      final uploadedScreens = savedData.toUploadedScreensFormat();
      final miaResult = savedData.miaResult;

      if (!hasDR && !hasIssues) {
        // Case 1: MIA만 → MIA 결과 화면
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HeuristicEvaluationPage(
                uploadedScreens: uploadedScreens,
                miaResult: miaResult,
              ),
            ),
          );
        }
      } else if (hasDR && !hasIssues) {
        // Case 2: MIA + DR → DR 화면
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DesignRepresentationScreen(
                uploadedScreens: uploadedScreens,
                miaResult: miaResult,
                agent1Result: drResult1,
                agent2Result: drResult2,
                agent3Result: drResult3,
                isMIAEnabled: true,
                selectedAgents: selectedAgents,
              ),
            ),
          );
        }
      } else if (hasDR && hasIssues) {
        // Case 3: MIA + DR + Issues → UX Evaluation 화면
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UXEvaluationScreen(
                uploadedScreens: uploadedScreens,
                miaResult: miaResult,
                agent1Result: drResult1,
                agent2Result: drResult2,
                agent3Result: drResult3,
                agent1IssueResult: issuesResult1,
                agent2IssueResult: issuesResult2,
                agent3IssueResult: issuesResult3,
                selectedAgents: selectedAgents,
              ),
            ),
          );
        }
      }
    } else {
      // ========================================
      // MIAx 모드: 이미지만 로드 (MIAResult 없음)
      // ========================================
      final imagesData = result['imagesData'] as SavedImagesData;
      final loadedScreens = imagesData.toUploadedScreensFormat();

      if (!hasDR && !hasIssues) {
        // Case 1: 이미지만 → 메인 화면에 이미지 설정
        if (mounted) {
          setState(() {
            uploadedScreens = loadedScreens;
          });
        }
      } else if (hasDR && !hasIssues) {
        // Case 2: 이미지 + DR → DR 화면
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DesignRepresentationScreen(
                uploadedScreens: loadedScreens,
                agent1Result: drResult1,
                agent2Result: drResult2,
                agent3Result: drResult3,
                isMIAEnabled: false,
                selectedAgents: selectedAgents,
              ),
            ),
          );
        }
      } else if (hasDR && hasIssues) {
        // Case 3: 이미지 + DR + Issues → UX Evaluation 화면
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UXEvaluationScreen(
                uploadedScreens: loadedScreens,
                agent1Result: drResult1,
                agent2Result: drResult2,
                agent3Result: drResult3,
                agent1IssueResult: issuesResult1,
                agent2IssueResult: issuesResult2,
                agent3IssueResult: issuesResult3,
                selectedAgents: selectedAgents,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _proceedToEvaluation() async {
    // 1. 로딩 다이얼로그 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(179),
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 24),
            Text(
              'AI가 스크린샷을 분석하고 있습니다...\n잠시만 기다려주세요.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      // 2. 이미지를 base64로 변환
      final base64Images = uploadedScreens
          .map((screen) => base64Encode(screen['bytes'] as List<int>))
          .toList();

      // 3. AI 분석 수행
      final analysisService = AnalysisService();
      final result = await analysisService.analyzeScreenshots(
        images: base64Images,
        evaluationScope: selectedScope == '변경/개선점에 집중하여 UX 이슈 찾기'
            ? evaluationScopeController.text
            : '',
        specialNotes: evaluationNotesController.text,
      );

      // 4. 로딩 닫기
      if (mounted) Navigator.pop(context);

      // 5. 분석 결과와 함께 평가 화면으로 이동 (입력한 평가 범위/특이사항 전달)
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HeuristicEvaluationPage(
              uploadedScreens: uploadedScreens,
              miaResult: result,
              initialScope: selectedScope,
              initialEvaluationScope: evaluationScopeController.text,
              initialNotes: evaluationNotesController.text,
            ),
          ),
        );
      }
    } catch (e) {
      // 에러 처리
      if (mounted) Navigator.pop(context); // 로딩 닫기
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('분석 실패'),
            content: Text('AI 분석 중 오류가 발생했습니다:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// MIAx Mode: 바로 DR 분석으로 진행 (Agent 1 생략)
  Future<void> _proceedToDRAnalysis() async {
    // ========================================
    // Step 1: 모듈 선택 다이얼로그 표시
    // ========================================
    final Set<int>? selectedAgents = await showDialog<Set<int>>(
      context: context,
      builder: (context) => const ModuleSelectionDialog(),
    );

    // 사용자가 취소했거나 위젯이 unmount된 경우
    if (selectedAgents == null || !mounted) return;

    // 빈 선택 검증 (다이얼로그에서 이미 방지하지만 추가 안전장치)
    if (selectedAgents.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('선택 필요'),
          content: const Text('최소 1개의 에이전트를 선택해야 합니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

    // ========================================
    // Step 2: 로딩 다이얼로그 표시
    // ========================================
    final agentNames = selectedAgents.map((i) => 'Agent $i').join(', ');
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(179),
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(
              'AI가 스크린샷을 분석하고 있습니다...\n($agentNames 실행 중)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      // ========================================
      // Step 3: 이미지를 Base64로 변환
      // ========================================
      final base64Images = uploadedScreens
          .map((screen) => base64Encode(screen['bytes'] as List<int>))
          .toList();

      // ========================================
      // Step 4: 조건부 DR 분석 - 선택된 에이전트만 실행
      // ========================================
      final drService = DRGenerationService();

      // 각 에이전트를 병렬로 실행하되, 개별 실패 시 null 반환 (partial success)
      Future<DRResult?> safeRun(Future<DRResult> f, String name) async {
        try { return await f; } catch (e) {
          print('⚠️ $name DR 실패: $e'); return null;
        }
      }

      final futures = <Future<DRResult?>>[];
      if (selectedAgents.contains(1)) {
        futures.add(safeRun(drService.generateAgent1DR(
          base64Images: base64Images, analysisData: null,
        ), 'Agent 1'));
      }
      if (selectedAgents.contains(2)) {
        futures.add(safeRun(drService.generateAgent2DR(
          base64Images: base64Images, analysisData: null,
        ), 'Agent 2'));
      }
      if (selectedAgents.contains(3)) {
        futures.add(safeRun(drService.generateAgent3DR(
          base64Images: base64Images, analysisData: null,
        ), 'Agent 3'));
      }

      // 병렬 실행 (일부 실패해도 나머지 결과로 네비게이션 진행)
      final results = await Future.wait(futures);

      // ========================================
      // Step 5: 결과 매핑
      // ========================================
      int resultIndex = 0;
      DRResult? agent1Result = selectedAgents.contains(1) ? results[resultIndex++] : null;
      DRResult? agent2Result = selectedAgents.contains(2) ? results[resultIndex++] : null;
      DRResult? agent3Result = selectedAgents.contains(3) ? results[resultIndex++] : null;

      // ========================================
      // Step 6: 로딩 닫기
      // ========================================
      print('📍 [MIAx DR] Step 6: Future.wait 완료, mounted=$mounted');
      print('📍 [MIAx DR] agent1=${agent1Result != null}, agent2=${agent2Result != null}, agent3=${agent3Result != null}');
      if (mounted) {
        print('📍 [MIAx DR] Navigator.pop (로딩 닫기)');
        Navigator.of(context).pop();
      }
      // 이벤트 루프 한 번 양보 후 push (pop 완료 보장)
      await Future.microtask(() {});

      // ========================================
      // Step 7: DR 결과와 함께 Design Representation 화면으로 이동
      // ========================================
      print('📍 [MIAx DR] Step 7: mounted=$mounted, Navigator.push 시작');
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DesignRepresentationScreen(
              uploadedScreens: uploadedScreens,
              agent1Result: agent1Result,
              agent2Result: agent2Result,
              agent3Result: agent3Result,
              selectedAgents: selectedAgents,
              isMIAEnabled: false,
            ),
          ),
        );
        print('📍 [MIAx DR] Navigator.push 완료');
      } else {
        print('❌ [MIAx DR] mounted=false, 네비게이션 불가');
      }
    } catch (e, st) {
      print('❌ [MIAx DR] catch 블록 진입: $e');
      print('❌ [MIAx DR] StackTrace: $st');
      if (mounted) Navigator.of(context).pop(); // 로딩 닫기
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('분석 실패'),
            content: Text('MIAx 분석 중 오류가 발생했습니다:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0046BE), Color(0xFF0062FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CXI팀 휴리스틱 평가 자동화 시스템${_isMIAEnabled ? '' : ' (MIAx)'}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                // MIA 토글 스위치
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'MIA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _isMIAEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isMIAEnabled = value;
                          });
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.green.shade400,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.grey.shade400,
                      ),
                      Text(
                        _isMIAEnabled ? 'ON' : 'OFF',
                        style: TextStyle(
                          color: _isMIAEnabled ? Colors.white : Colors.grey.shade300,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Center(
              child: uploadedScreens.isEmpty
                  ? _buildUploadArea()
                  : _buildImageGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 600,
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              style: BorderStyle.solid,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: _pickImages,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '스크린샷 업로드',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '클릭하여 여러 개의 이미지를 선택하세요',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 저장된 결과 불러오기 버튼
        Center(
          child: ElevatedButton.icon(
            onPressed: _loadSavedAnalysisData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.folder_open),
            label: const Text(
              '저장된 결과 불러오기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    return SingleChildScrollView(
      child: Container(
      constraints: const BoxConstraints(maxWidth: 1400),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 전체 삭제 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _removeAllImages,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('전체 삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 이미지 그리드 (5개씩, 화살표로 페이지 이동)
          SizedBox(
            height: 500,
            child: Row(
              children: [
                // 왼쪽 화살표
                IconButton(
                  onPressed: currentUploadIndex > 0
                      ? () => setState(() => currentUploadIndex -= 5)
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                // 이미지 그리드 (5개씩)
                Expanded(
                  child: Row(
                    children: List.generate(5, (index) {
                      final imageIndex = currentUploadIndex + index;
                      if (imageIndex >= uploadedScreens.length) {
                        return const Expanded(child: SizedBox.shrink());
                      }
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  color: Colors.white,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child:
                                      uploadedScreens[imageIndex]['bytes'] !=
                                          null
                                      ? Image.memory(
                                          uploadedScreens[imageIndex]['bytes'],
                                          fit: BoxFit.contain,
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.image,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: () => _removeImage(imageIndex),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(51),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // 오른쪽 화살표
                IconButton(
                  onPressed: currentUploadIndex + 5 < uploadedScreens.length
                      ? () => setState(() => currentUploadIndex += 5)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0046BE),
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // MIA 토글 ON일 때만 평가 범위 및 특이사항 표시
          if (_isMIAEnabled) ...[
            _buildEvaluationScopeCard(),
            const SizedBox(height: 32),
          ],

          // 진행 버튼 (MIA 상태에 따라 다른 플로우 실행)
          ElevatedButton.icon(
            onPressed: _isMIAEnabled ? _proceedToEvaluation : _proceedToDRAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0046BE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(_isMIAEnabled ? Icons.play_arrow : Icons.fast_forward),
            label: Text(
              _isMIAEnabled ? '진행' : 'DR 분석 시작 (MIAx)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
    );
  }

  /// 평가 범위 및 특이사항 카드
  /// MIA 토글이 ON일 때만 UploadStartPage에 표시됨
  Widget _buildEvaluationScopeCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "평가 범위" 제목
          Row(
            children: [
              const Text(
                '평가 범위',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Text(
                '*',
                style: TextStyle(fontSize: 24, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 라디오 옵션 1: 전반적인 UX 이슈 찾기
          _buildRadioOption(
            '전반적인 UX 이슈 찾기',
            selectedScope == '전반적인 UX 이슈 찾기',
            () => setState(() => selectedScope = '전반적인 UX 이슈 찾기'),
          ),

          const SizedBox(height: 8),

          // 라디오 옵션 2: 변경/개선점에 집중하여 UX 이슈 찾기 + TextField
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildRadioOption(
                  '변경/개선점에 집중하여 UX 이슈 찾기',
                  selectedScope == '변경/개선점에 집중하여 UX 이슈 찾기',
                  () => setState(() => selectedScope = '변경/개선점에 집중하여 UX 이슈 찾기'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: evaluationScopeController,
                  enabled: selectedScope == '변경/개선점에 집중하여 UX 이슈 찾기',
                  decoration: InputDecoration(
                    hintText: '구체적인 변경/개선점을 입력하세요',
                    filled: true,
                    fillColor: selectedScope == '변경/개선점에 집중하여 UX 이슈 찾기'
                        ? const Color(0xFFF8F9FA)
                        : Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF0046BE),
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // "평가 특이사항" 제목
          const Text(
            '평가 특이사항',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 특이사항 입력 필드
          TextField(
            controller: evaluationNotesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '예: 고령인 관점의 사용성 평가, 출시 직전 가능한 다양한 관점의 깊은 평가',
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF0046BE),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 라디오 버튼 UI 컴포넌트
  Widget _buildRadioOption(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF0046BE) : Colors.grey,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0046BE),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    evaluationNotesController.dispose();
    super.dispose();
  }
}

/// ========================================
/// 시나리오 선택 다이얼로그
/// ========================================
/// S1-S4 중 분석할 시나리오를 선택하는 팝업
/// Returns: int (선택된 시나리오 번호: 1, 2, 3, 4) 또는 null (취소)
class ScenarioSelectionDialog extends StatefulWidget {
  const ScenarioSelectionDialog({super.key});

  @override
  State<ScenarioSelectionDialog> createState() => _ScenarioSelectionDialogState();
}

class _ScenarioSelectionDialogState extends State<ScenarioSelectionDialog> {
  int? _selectedScenario;

  final List<Map<String, String>> _scenarioInfo = [
    {'number': '1', 'name': '시나리오 1', 'description': 'One UI Home 분석'},
    {'number': '2', 'name': '시나리오 2', 'description': '배경화면 설정 분석'},
    {'number': '3', 'name': '시나리오 3', 'description': '설정 메뉴 분석'},
    {'number': '4', 'name': '시나리오 4', 'description': '앱 설정 분석'},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 450),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            const Text(
              '시나리오 선택',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '분석 결과를 불러올 시나리오를 선택하세요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // 시나리오 라디오 버튼 리스트
            Expanded(
              child: ListView.builder(
                itemCount: _scenarioInfo.length,
                itemBuilder: (context, index) {
                  final scenario = _scenarioInfo[index];
                  final scenarioNumber = int.parse(scenario['number']!);
                  final isSelected = _selectedScenario == scenarioNumber;

                  return _buildScenarioRadio(
                    scenarioNumber: scenarioNumber,
                    name: scenario['name']!,
                    description: scenario['description']!,
                    isSelected: isSelected,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedScenario == null
                      ? null
                      : () => Navigator.pop(context, _selectedScenario),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0046BE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioRadio({
    required int scenarioNumber,
    required String name,
    required String description,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedScenario = scenarioNumber;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0046BE).withAlpha(26) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0046BE) : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // 라디오 버튼
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0046BE) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0046BE),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // 시나리오 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF0046BE) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ========================================
/// 모듈 선택 다이얼로그
/// ========================================
/// 4개 에이전트 중 실행할 모듈을 선택하는 팝업
/// Returns: Set<int> (선택된 에이전트 인덱스: 1, 2, 3, 4) 또는 null (취소)
class ModuleSelectionDialog extends StatefulWidget {
  const ModuleSelectionDialog({super.key});

  @override
  State<ModuleSelectionDialog> createState() => _ModuleSelectionDialogState();
}

class _ModuleSelectionDialogState extends State<ModuleSelectionDialog> {
  final Set<int> _selectedAgents = {1, 2, 3}; // 기본값: 전체 선택

  final List<Map<String, String>> _agentInfo = [
    {'index': '1', 'name': 'UX Writing', 'description': '텍스트 요소 추출 및 평가'},
    {'index': '2', 'name': 'Error Prevention & Forgiveness', 'description': '에러 예방 및 용서 평가'},
    {'index': '3', 'name': 'Visual Consistency', 'description': '시각적 일관성 평가'},
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            const Text(
              '분석할 모듈 선택',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '분석하려는 에이전트를 선택하세요 (최소 1개)',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // 에이전트 체크박스 리스트
            Expanded(
              child: ListView.builder(
                itemCount: _agentInfo.length,
                itemBuilder: (context, index) {
                  final agent = _agentInfo[index];
                  final agentIndex = int.parse(agent['index']!);
                  final isSelected = _selectedAgents.contains(agentIndex);

                  return _buildAgentCheckbox(
                    agentIndex: agentIndex,
                    name: agent['name']!,
                    description: agent['description']!,
                    isSelected: isSelected,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _selectedAgents.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selectedAgents),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0046BE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCheckbox({
    required int agentIndex,
    required String name,
    required String description,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedAgents.remove(agentIndex);
          } else {
            _selectedAgents.add(agentIndex);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0046BE).withAlpha(26) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0046BE) : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            // 체크박스
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0046BE) : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0046BE) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),

            // 에이전트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agent $agentIndex: $name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF0046BE) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ========================================
/// 파일 불러오기 다이얼로그 (3개 파일 선택)
/// ========================================
/// MIA 모드: MIA, DR, UX 이슈 파일을 각각 선택하여 불러오는 팝업
/// MIAx 모드: 이미지, DR, UX 이슈 파일을 각각 선택하여 불러오는 팝업
/// 선택된 파일 조합에 따라 시작 화면이 결정됨:
/// - MIA/이미지만: DR 분석부터
/// - MIA/이미지 + DR: E 평가부터
/// - MIA/이미지 + DR + Issues: Filter부터
class LoadFilesDialog extends StatefulWidget {
  final bool isMIAEnabled;
  const LoadFilesDialog({super.key, required this.isMIAEnabled});

  @override
  State<LoadFilesDialog> createState() => _LoadFilesDialogState();
}

class _LoadFilesDialogState extends State<LoadFilesDialog> {
  final DataPersistenceService _persistenceService = DataPersistenceService();

  static const _agentNames = {1: 'UX Writing', 2: 'Error Prevention', 3: 'Visual Consistency'};

  // MIA/이미지 파일 (단일)
  String? _miaFileName;
  List<int>? _miaFileBytes;

  // DR 파일 (에이전트별)
  final Map<int, String> _drFileNames = {};
  final Map<int, List<int>> _drFileByteMap = {};

  // Issues 파일 (에이전트별)
  final Map<int, String> _issuesFileNames = {};
  final Map<int, List<int>> _issuesFileByteMap = {};

  bool _isLoading = false;
  String? _errorMessage;

  /// MIA/이미지 파일 선택
  Future<void> _pickMIAFile() async {
    try {
      final dialogTitle = widget.isMIAEnabled ? 'MIA 파일 선택' : '이미지 파일 선택';
      final result = await _persistenceService.pickJsonFile(dialogTitle);
      if (result != null) {
        setState(() {
          _miaFileName = result.$1;
          _miaFileBytes = result.$2;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = widget.isMIAEnabled
            ? 'MIA 파일 선택 실패: $e'
            : '이미지 파일 선택 실패: $e';
      });
    }
  }

  /// DR 파일 선택 (여러 개 가능, JSON 필드로 에이전트 자동 감지)
  Future<void> _pickDRFiles() async {
    try {
      final files = await _persistenceService.pickMultipleJsonFiles('DR 파일 선택 (여러 개 가능)');
      if (files.isEmpty) return;

      setState(() {
        final unrecognized = <String>[];
        for (final (filename, bytes) in files) {
          try {
            final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            final parsed = DataPersistenceService.parseAgentFromJson(json);
            if (parsed != null && parsed.$2 == 'dr') {
              _drFileNames[parsed.$1] = filename;
              _drFileByteMap[parsed.$1] = bytes;
            } else {
              unrecognized.add(filename);
            }
          } catch (_) {
            unrecognized.add(filename);
          }
        }
        if (unrecognized.isNotEmpty) {
          _errorMessage = '에이전트를 식별할 수 없는 DR 파일: ${unrecognized.join(", ")}\n'
              'screens 필드와 text_elements/screen_level/elements 키가 필요합니다.';
        } else {
          _errorMessage = null;
        }
      });
    } catch (e) {
      setState(() { _errorMessage = 'DR 파일 선택 실패: $e'; });
    }
  }

  /// Issues 파일 선택 (여러 개 가능, JSON 필드로 에이전트 자동 감지)
  Future<void> _pickIssuesFiles() async {
    try {
      final files = await _persistenceService.pickMultipleJsonFiles('UX 이슈 파일 선택 (여러 개 가능)');
      if (files.isEmpty) return;

      setState(() {
        final unrecognized = <String>[];
        for (final (filename, bytes) in files) {
          try {
            final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            final parsed = DataPersistenceService.parseAgentFromJson(json);
            if (parsed != null && parsed.$2 == 'issues') {
              _issuesFileNames[parsed.$1] = filename;
              _issuesFileByteMap[parsed.$1] = bytes;
            } else {
              unrecognized.add(filename);
            }
          } catch (_) {
            unrecognized.add(filename);
          }
        }
        if (unrecognized.isNotEmpty) {
          _errorMessage = '에이전트를 식별할 수 없는 Issues 파일: ${unrecognized.join(", ")}\n'
              'problems 필드와 UX-WRITING/ERROR-PREV/VISUAL-CONSIST issue_id가 필요합니다.';
        } else {
          _errorMessage = null;
        }
      });
    } catch (e) {
      setState(() { _errorMessage = 'UX 이슈 파일 선택 실패: $e'; });
    }
  }

  /// 현재 선택 상태에 따른 시작 단계 설명
  String _getStartStageDescription() {
    final hasFirst = _miaFileBytes != null;
    final hasDR = _drFileByteMap.isNotEmpty;
    final hasIssues = _issuesFileByteMap.isNotEmpty;
    final isMIA = widget.isMIAEnabled;

    if (!hasFirst) {
      return isMIA
          ? 'MIA 파일을 선택하세요 (필수)'
          : '이미지 파일을 선택하세요 (필수)';
    }

    // 감지된 에이전트 목록
    final drAgents = _drFileNames.keys.map((k) => 'Agent $k').join(', ');
    final issuesAgents = _issuesFileNames.keys.map((k) => 'Agent $k').join(', ');

    if (hasFirst && !hasDR && !hasIssues) {
      return isMIA
          ? 'MIA만 선택됨 → DR 분석부터 시작'
          : '이미지만 선택됨 → DR 분석부터 시작';
    } else if (hasFirst && hasDR && !hasIssues) {
      final prefix = isMIA ? 'MIA + DR' : '이미지 + DR';
      return '$prefix ($drAgents) → E 평가부터 시작';
    } else if (hasFirst && hasDR && hasIssues) {
      final prefix = isMIA ? 'MIA + DR + Issues' : '이미지 + DR + Issues';
      return '$prefix (DR: $drAgents / Issues: $issuesAgents) → Filter부터 시작';
    } else if (hasFirst && !hasDR && hasIssues) {
      return 'DR 없이 Issues를 선택할 수 없습니다';
    }
    return '';
  }

  /// 불러오기 버튼 활성화 여부
  bool _canLoad() {
    final hasFirst = _miaFileBytes != null;
    final hasDR = _drFileByteMap.isNotEmpty;
    final hasIssues = _issuesFileByteMap.isNotEmpty;

    if (!hasFirst) return false;
    if (!hasDR && hasIssues) return false;

    return true;
  }

  /// 불러오기 실행
  Future<void> _onLoadPressed() async {
    if (!_canLoad()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // DR 파일 에이전트별 파싱
      DRResult? drResult1, drResult2, drResult3;
      for (final entry in _drFileByteMap.entries) {
        final dr = await _persistenceService.loadDRFromBytes(entry.value);
        switch (entry.key) {
          case 1: drResult1 = dr;
          case 2: drResult2 = dr;
          case 3: drResult3 = dr;
        }
      }

      // Issues 파일 에이전트별 파싱 (agentNumber 전달)
      UXIssueResult? issuesResult1, issuesResult2, issuesResult3;
      for (final entry in _issuesFileByteMap.entries) {
        final issues = await _persistenceService.loadIssuesFromBytes(
          entry.value, agentNumber: entry.key);
        switch (entry.key) {
          case 1: issuesResult1 = issues;
          case 2: issuesResult2 = issues;
          case 3: issuesResult3 = issues;
        }
      }

      // selectedAgents 동적 계산
      final selectedAgents = <int>{};
      if (drResult1 != null || issuesResult1 != null) selectedAgents.add(1);
      if (drResult2 != null || issuesResult2 != null) selectedAgents.add(2);
      if (drResult3 != null || issuesResult3 != null) selectedAgents.add(3);
      // DR/Issues 없이 MIA만 있으면 기본 전체 선택
      if (selectedAgents.isEmpty) selectedAgents.addAll({1, 2, 3});

      if (widget.isMIAEnabled) {
        final savedData = await _persistenceService.loadMIAFromBytes(_miaFileBytes!);
        if (mounted) {
          Navigator.pop(context, {
            'mode': 'mia',
            'savedData': savedData,
            'drResult1': drResult1,
            'drResult2': drResult2,
            'drResult3': drResult3,
            'issuesResult1': issuesResult1,
            'issuesResult2': issuesResult2,
            'issuesResult3': issuesResult3,
            'selectedAgents': selectedAgents,
          });
        }
      } else {
        final imagesData = await _persistenceService.loadImagesFromBytes(_miaFileBytes!);
        if (mounted) {
          Navigator.pop(context, {
            'mode': 'miax',
            'imagesData': imagesData,
            'drResult1': drResult1,
            'drResult2': drResult2,
            'drResult3': drResult3,
            'issuesResult1': issuesResult1,
            'issuesResult2': issuesResult2,
            'issuesResult3': issuesResult3,
            'selectedAgents': selectedAgents,
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '파일 파싱 실패: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final startStageDesc = _getStartStageDescription();
    final canLoad = _canLoad();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 650),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            const Text(
              '저장된 결과 불러오기',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '불러올 파일을 선택하세요 (DR/Issues는 여러 에이전트 파일 동시 선택 가능)',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // 파일 선택 버튼들
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // MIA/이미지 파일 선택 (필수)
                    _buildSingleFileSelector(
                      icon: widget.isMIAEnabled ? Icons.analytics : Icons.image,
                      label: widget.isMIAEnabled ? 'MIA 파일' : '이미지 파일',
                      required: true,
                      fileName: _miaFileName,
                      onPressed: _pickMIAFile,
                      onClear: () => setState(() {
                        _miaFileName = null;
                        _miaFileBytes = null;
                      }),
                    ),
                    const SizedBox(height: 16),

                    // DR 파일 선택 (여러 개)
                    _buildMultiFileSelector(
                      icon: Icons.description,
                      label: 'DR 파일',
                      required: false,
                      fileNames: _drFileNames,
                      onPressed: _pickDRFiles,
                      onClearAgent: (agentNum) => setState(() {
                        _drFileNames.remove(agentNum);
                        _drFileByteMap.remove(agentNum);
                      }),
                      onClearAll: () => setState(() {
                        _drFileNames.clear();
                        _drFileByteMap.clear();
                      }),
                    ),
                    const SizedBox(height: 16),

                    // UX 이슈 파일 선택 (여러 개)
                    _buildMultiFileSelector(
                      icon: Icons.warning_amber,
                      label: 'UX 이슈 파일',
                      required: false,
                      fileNames: _issuesFileNames,
                      onPressed: _pickIssuesFiles,
                      onClearAgent: (agentNum) => setState(() {
                        _issuesFileNames.remove(agentNum);
                        _issuesFileByteMap.remove(agentNum);
                      }),
                      onClearAll: () => setState(() {
                        _issuesFileNames.clear();
                        _issuesFileByteMap.clear();
                      }),
                      enabled: _drFileByteMap.isNotEmpty,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 시작 단계 표시
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: canLoad ? const Color(0xFF0046BE).withAlpha(26) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canLoad ? const Color(0xFF0046BE) : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    canLoad ? Icons.info : Icons.info_outline,
                    color: canLoad ? const Color(0xFF0046BE) : Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      startStageDesc,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: canLoad ? const Color(0xFF0046BE) : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 에러 메시지
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],

            const SizedBox(height: 24),

            // 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context, null),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading || !canLoad ? null : _onLoadPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0046BE),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('불러오기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 단일 파일 선택 위젯 (MIA/이미지용)
  Widget _buildSingleFileSelector({
    required IconData icon,
    required String label,
    required bool required,
    required String? fileName,
    required VoidCallback onPressed,
    required VoidCallback onClear,
    bool enabled = true,
  }) {
    final isSelected = fileName != null;

    return InkWell(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.grey.shade100
              : isSelected
                  ? const Color(0xFF0046BE).withAlpha(26)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: !enabled
                ? Colors.grey.shade300
                : isSelected
                    ? const Color(0xFF0046BE)
                    : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0046BE) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                    if (required) ...[const SizedBox(width: 4), const Text('*', style: TextStyle(color: Colors.red, fontSize: 16))],
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    isSelected ? fileName : '클릭하여 파일 선택',
                    style: TextStyle(fontSize: 13, color: isSelected ? const Color(0xFF0046BE) : Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              IconButton(onPressed: onClear, icon: const Icon(Icons.close, size: 20),
                style: IconButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.grey.shade700))
            else
              Icon(Icons.folder_open, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  /// 멀티 파일 선택 위젯 (DR/Issues용 - 에이전트별 파일 표시)
  Widget _buildMultiFileSelector({
    required IconData icon,
    required String label,
    required bool required,
    required Map<int, String> fileNames,
    required VoidCallback onPressed,
    required void Function(int agentNum) onClearAgent,
    required VoidCallback onClearAll,
    bool enabled = true,
  }) {
    final hasFiles = fileNames.isNotEmpty;

    return InkWell(
      onTap: enabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.grey.shade100
              : hasFiles
                  ? const Color(0xFF0046BE).withAlpha(26)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: !enabled
                ? Colors.grey.shade300
                : hasFiles
                    ? const Color(0xFF0046BE)
                    : Colors.grey.shade300,
            width: hasFiles ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: !enabled
                        ? Colors.grey.shade200
                        : hasFiles ? const Color(0xFF0046BE) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon,
                    color: !enabled ? Colors.grey.shade400
                        : hasFiles ? Colors.white : Colors.grey.shade600, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: !enabled ? Colors.grey.shade400 : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(
                        hasFiles ? '${fileNames.length}개 에이전트 선택됨' : '클릭하여 파일 선택 (여러 개 가능)',
                        style: TextStyle(fontSize: 13,
                          color: hasFiles ? const Color(0xFF0046BE) : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                if (hasFiles)
                  IconButton(onPressed: onClearAll, icon: const Icon(Icons.close, size: 20),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.grey.shade700))
                else
                  Icon(Icons.folder_open,
                    color: !enabled ? Colors.grey.shade300 : Colors.grey.shade400),
              ],
            ),
            // 에이전트별 파일 칩 표시
            if (hasFiles) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fileNames.entries.map((entry) {
                  return Chip(
                    label: Text(
                      '${_agentNames[entry.key] ?? "Agent ${entry.key}"}: ${entry.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => onClearAgent(entry.key),
                    backgroundColor: const Color(0xFF0046BE).withAlpha(20),
                    side: BorderSide(color: const Color(0xFF0046BE).withAlpha(60)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HeuristicEvaluationPage extends StatefulWidget {
  final List<Map<String, dynamic>> uploadedScreens;
  final MIAResult? miaResult;
  final String? initialScope;
  final String? initialEvaluationScope;
  final String? initialNotes;

  const HeuristicEvaluationPage({
    super.key,
    required this.uploadedScreens,
    this.miaResult,
    this.initialScope,
    this.initialEvaluationScope,
    this.initialNotes,
  });

  @override
  State<HeuristicEvaluationPage> createState() =>
      _HeuristicEvaluationPageState();
}

class _HeuristicEvaluationPageState extends State<HeuristicEvaluationPage> {
  String selectedScope = '변경/개선점에 집중하여 UX 이슈 찾기';
  final TextEditingController selectionInfoController = TextEditingController();
  final TextEditingController evaluationScopeController = TextEditingController();
  final TextEditingController evaluationNotesController =
      TextEditingController();
  final TextEditingController targetUserController = TextEditingController();
  final TextEditingController usageContextController = TextEditingController();
  final TextEditingController userGoalController = TextEditingController();
  final TextEditingController taskScenarioController = TextEditingController();

  int currentScreenIndex = 0;
  late List<Map<String, dynamic>> uploadedScreens;
  List<TextEditingController> screenDescriptionControllers = [];

  // 수정 가능한 MIAResult (사용자가 TextField를 수정하면 이 객체도 업데이트됨)
  MIAResult? _updatedMiaResult;

  @override
  void initState() {
    super.initState();
    uploadedScreens = widget.uploadedScreens;

    // UploadStartPage에서 입력한 평가 범위 및 특이사항으로 초기화
    if (widget.initialScope != null) {
      selectedScope = widget.initialScope!;
    }
    if (widget.initialEvaluationScope != null) {
      evaluationScopeController.text = widget.initialEvaluationScope!;
    }
    if (widget.initialNotes != null) {
      evaluationNotesController.text = widget.initialNotes!;
    }

    // 각 화면별로 설명 컨트롤러 생성
    screenDescriptionControllers = List.generate(
      uploadedScreens.length,
      (index) => TextEditingController(),
    );

    // 분석 결과가 있으면 텍스트 필드에 채우기
    if (widget.miaResult != null) {
      _fillMIAResults(widget.miaResult!);
      _updatedMiaResult = widget.miaResult; // 초기값 설정
    }
  }

  void _fillMIAResults(MIAResult result) {
    // 사용 맥락 채우기
    targetUserController.text = result.usageContext.targetUser;
    usageContextController.text = result.usageContext.usageEnvironment;
    userGoalController.text = result.usageContext.userGoal;
    taskScenarioController.text = result.usageContext.taskScenario;

    // 화면별 분석 결과를 uploadedScreens 및 컨트롤러에 추가
    for (var i = 0; i < result.screenPurposes.length; i++) {
      if (i < uploadedScreens.length &&
          i < screenDescriptionControllers.length) {
        uploadedScreens[i]['title'] = result.screenPurposes[i].purpose;
        uploadedScreens[i]['description'] = result.screenPurposes[i].purpose;
        screenDescriptionControllers[i].text = result.screenPurposes[i].purpose;
      }
    }

    // Evaluation Context 채우기 (파일 불러오기 시 필요)
    if (result.evaluationContext != null) {
      final scope = result.evaluationContext!.evaluationScope;
      evaluationScopeController.text = scope;
      evaluationNotesController.text = result.evaluationContext!.specialEvaluationNotes;

      // evaluation_scope가 비어있으면 "전반적인 UX 이슈 찾기" 선택
      if (scope.isEmpty) {
        selectedScope = '전반적인 UX 이슈 찾기';
      } else {
        selectedScope = '변경/개선점에 집중하여 UX 이슈 찾기';
      }
    }
  }

  /// TextField 수정 사항을 _updatedMiaResult에 반영
  void _applyMiaChanges() {
    if (widget.miaResult == null) return;

    // 수정된 ScreenPurpose 리스트 생성
    final updatedScreenPurposes = <ScreenPurpose>[];
    for (var i = 0; i < screenDescriptionControllers.length; i++) {
      final originalScreenId = i < widget.miaResult!.screenPurposes.length
          ? widget.miaResult!.screenPurposes[i].screenId
          : 'screen_${i + 1}';
      updatedScreenPurposes.add(ScreenPurpose(
        screenId: originalScreenId,
        purpose: screenDescriptionControllers[i].text,
      ));
    }

    // 수정된 UsageContext 생성
    final updatedUsageContext = UsageContext(
      targetUser: targetUserController.text,
      usageEnvironment: usageContextController.text,
      userGoal: userGoalController.text,
      taskScenario: taskScenarioController.text,
    );

    // 수정된 MIAResult 생성 (evaluationContext도 컨트롤러 값으로 갱신)
    _updatedMiaResult = MIAResult(
      evaluationContext: EvaluationContext(
        evaluationScope: evaluationScopeController.text,
        specialEvaluationNotes: evaluationNotesController.text,
      ),
      screenPurposes: updatedScreenPurposes,
      usageContext: updatedUsageContext,
    );

    // 성공 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('수정 사항이 반영되었습니다.'),
        backgroundColor: Color(0xFF4CAF50),
        duration: Duration(seconds: 2),
      ),
    );

    setState(() {});
  }

  Future<void> _saveAnalysisData() async {
    if (widget.miaResult == null) return;

    try {
      final service = DataPersistenceService();
      // 수정된 MIAResult가 있으면 사용, 없으면 원본 사용
      final miaResultToSave = _updatedMiaResult ?? widget.miaResult!;
      final filename = await service.saveAnalysisData(
        uploadedScreens: uploadedScreens,
        miaResult: miaResultToSave,
      );

      if (filename != null && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('저장 완료'),
            content: Text('분석 결과가 저장되었습니다.\n파일명: $filename'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('저장 실패'),
            content: Text('분석 결과 저장 중 오류가 발생했습니다:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleAllAtOnceAnalysis() async {
    if (widget.miaResult == null) {
      _showErrorDialog('분석 결과가 없습니다. 먼저 화면 분석을 완료해주세요.');
      return;
    }

    // 수정된 MIA 결과가 있으면 사용, 없으면 원본 사용
    final miaResult = _updatedMiaResult ?? widget.miaResult!;

    // ========================================
    // Step 1: 모듈 선택 다이얼로그 표시
    // ========================================
    final Set<int>? selectedAgents = await showDialog<Set<int>>(
      context: context,
      builder: (context) => const ModuleSelectionDialog(),
    );

    // 사용자가 취소했거나 위젯이 unmount된 경우
    if (selectedAgents == null || !mounted) return;

    // 빈 선택 검증
    if (selectedAgents.isEmpty) {
      _showErrorDialog('최소 1개의 에이전트를 선택해야 합니다.');
      return;
    }

    // ========================================
    // Step 2: 로딩 다이얼로그 표시
    // ========================================
    final agentNames = selectedAgents.map((i) => 'Agent $i').join(', ');
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(179),
      builder: (context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'DR 생성 중...\n($agentNames 실행 중)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Only analyze screens that have analysis data from Agent 1
      final analyzedScreenCount = miaResult.screenPurposes.length;
      final screensToAnalyze = uploadedScreens.take(analyzedScreenCount).toList();

      // ========================================
      // Step 3: Base64 변환
      // ========================================
      final base64Images = screensToAnalyze
          .map((screen) => base64Encode(screen['bytes'] as List<int>))
          .toList();

      // ========================================
      // Step 4: 조건부 DR 분석 - 선택된 에이전트만 실행 (MIA 모드)
      // ========================================
      // 💡 MIA 모드: 3개 에이전트 모두에 Heuristic context 전달
      //    - Agent 1: MIA context 포함 (Agent1_DR_MIA_prompt 사용)
      //    - Agent 2: MIA context 포함 (Agent2_DR_MIA_prompt 사용)
      //    - Agent 3: MIA context 포함 (Agent3_DR_MIA_prompt 사용)
      final drService = DRGenerationService();

      // 각 에이전트를 병렬로 실행하되, 개별 실패 시 null 반환 (partial success)
      Future<DRResult?> safeRun(Future<DRResult> f, String name) async {
        try { return await f; } catch (e) {
          print('⚠️ $name DR 실패: $e'); return null;
        }
      }

      final futures = <Future<DRResult?>>[];
      if (selectedAgents.contains(1)) {
        futures.add(safeRun(drService.generateAgent1DR(
          base64Images: base64Images, analysisData: miaResult,
        ), 'Agent 1'));
      }
      if (selectedAgents.contains(2)) {
        futures.add(safeRun(drService.generateAgent2DR(
          base64Images: base64Images, analysisData: miaResult,
        ), 'Agent 2'));
      }
      if (selectedAgents.contains(3)) {
        futures.add(safeRun(drService.generateAgent3DR(
          base64Images: base64Images, analysisData: miaResult,
        ), 'Agent 3'));
      }

      // 병렬 실행 (일부 실패해도 나머지 결과로 네비게이션 진행)
      final results = await Future.wait(futures);

      // ========================================
      // Step 5: 결과 매핑
      // ========================================
      int resultIndex = 0;
      DRResult? agent1Result = selectedAgents.contains(1) ? results[resultIndex++] : null;
      DRResult? agent2Result = selectedAgents.contains(2) ? results[resultIndex++] : null;
      DRResult? agent3Result = selectedAgents.contains(3) ? results[resultIndex++] : null;

      // ========================================
      // Step 6: 로딩 닫기
      // ========================================
      print('📍 [MIA DR] Step 6: Future.wait 완료, mounted=$mounted');
      print('📍 [MIA DR] agent1=${agent1Result != null}, agent2=${agent2Result != null}, agent3=${agent3Result != null}');
      if (mounted) {
        print('📍 [MIA DR] Navigator.pop (로딩 닫기)');
        Navigator.of(context).pop();
      }
      // 이벤트 루프 한 번 양보 후 push (pop 완료 보장)
      await Future.microtask(() {});

      // ========================================
      // Step 7: DR 결과와 함께 Design Representation 화면으로 이동
      // ========================================
      print('📍 [MIA DR] Step 7: mounted=$mounted, Navigator.push 시작');
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DesignRepresentationScreen(
              uploadedScreens: uploadedScreens,
              agent1Result: agent1Result,
              agent2Result: agent2Result,
              agent3Result: agent3Result,
              selectedAgents: selectedAgents,
              miaResult: miaResult,
              isMIAEnabled: true,
            ),
          ),
        );
        print('📍 [MIA DR] Navigator.push 완료');
      } else {
        print('❌ [MIA DR] mounted=false, 네비게이션 불가');
      }
    } catch (e, st) {
      print('❌ [MIA DR] catch 블록 진입: $e');
      print('❌ [MIA DR] StackTrace: $st');
      if (mounted) Navigator.of(context).pop();
      _showErrorDialog('DR 생성 중 오류가 발생했습니다:\n$e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0046BE), Color(0xFF0062FF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('확인'),
                          content: const Text(
                            '입력한 데이터가 저장되지 않습니다. 시작 화면으로 돌아가시겠습니까?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context); // 다이얼로그 닫기
                                Navigator.pop(context); // 평가 화면 닫기
                              },
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'CXI팀 휴리스틱 평가 자동화 시스템',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // 저장 버튼
                  if (widget.miaResult != null) ...[
                    ElevatedButton.icon(
                      onPressed: () => _saveAnalysisData(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0046BE),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text(
                        '결과 저장',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _applyMiaChanges(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text(
                        '수정 완료',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(80),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildEvaluationScopeCard(),
                        const SizedBox(height: 32),
                        _buildScreenObjectiveCard(),
                      ],
                    ),
                  ),

                  const SizedBox(width: 40),

                  // Right Column
                  Expanded(flex: 1, child: _buildScrumUsageMapCard()),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'all_at_once',
        onPressed: _handleAllAtOnceAnalysis,
        backgroundColor: const Color(0xFF0046BE),
        tooltip: '모듈 선택 후 DR 분석',
        child: const Icon(Icons.arrow_forward, color: Colors.white),
      ),
    );
  }

  Widget _buildEvaluationScopeCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '평가 범위',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              const Text(
                '*',
                style: TextStyle(fontSize: 24, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _buildRadioOption(
                '전반적인 UX 이슈 찾기',
                selectedScope == '전반적인 UX 이슈 찾기',
                () => setState(() => selectedScope = '전반적인 UX 이슈 찾기'),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildRadioOption(
                      '변경/개선점에 집중하여 UX 이슈 찾기',
                      selectedScope == '변경/개선점에 집중하여 UX 이슈 찾기',
                      () =>
                          setState(() => selectedScope = '변경/개선점에 집중하여 UX 이슈 찾기'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: evaluationScopeController,
                      enabled: selectedScope == '변경/개선점에 집중하여 UX 이슈 찾기',
                      decoration: InputDecoration(
                        hintText: '구체적인 변경/개선점을 입력하세요',
                        filled: true,
                        fillColor: selectedScope == '변경/개선점에 집중하여 UX 이슈 찾기'
                            ? const Color(0xFFF8F9FA)
                            : Colors.grey.shade200,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF0046BE),
                            width: 2,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            '평가 특이사항',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: evaluationNotesController,
            maxLines: 3,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF0046BE),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF0046BE) : Colors.grey,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0046BE),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildScreenObjectiveCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '화면 단위 사용자 목적',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildScreenCarousel(),
        ],
      ),
    );
  }

  Widget _buildScreenCarousel() {
    return SizedBox(
      height: 580,
      child: Row(
        children: [
          IconButton(
            onPressed: currentScreenIndex > 0
                ? () => setState(() => currentScreenIndex -= 3)
                : null,
            icon: const Icon(Icons.chevron_left, size: 32),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: const CircleBorder(),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(3, (index) {
                final screenIndex = currentScreenIndex + index;
                if (screenIndex >= uploadedScreens.length) {
                  return const SizedBox.shrink();
                }
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: uploadedScreens[screenIndex]['bytes'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      uploadedScreens[screenIndex]['bytes'],
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 화면 ID
                        Text(
                          '화면 ${screenIndex + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 화면 설명 TextField
                        SizedBox(
                          height: 120,
                          child: TextField(
                            controller:
                                screenDescriptionControllers[screenIndex],
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: '화면의 주요 기능을 설명해주세요...',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0046BE),
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            style: const TextStyle(fontSize: 13),
                            onChanged: (value) {
                              uploadedScreens[screenIndex]['description'] =
                                  value;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          IconButton(
            onPressed: currentScreenIndex + 3 < uploadedScreens.length
                ? () => setState(() => currentScreenIndex += 3)
                : null,
            icon: const Icon(Icons.chevron_right, size: 32),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0046BE),
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrumUsageMapCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '사용 맥락',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          _buildFormField('타겟 사용자(Target User)', targetUserController),
          const SizedBox(height: 24),
          _buildFormField('사용 환경(Usage Envrionnment)', usageContextController),
          const SizedBox(height: 24),
          _buildFormField('사용자 목표(User Goal)', userGoalController),
          const SizedBox(height: 24),
          _buildFormField(
            '과업 시나리오(Task Scenario)',
            taskScenarioController,
            maxLines: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0046BE), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    selectionInfoController.dispose();
    evaluationNotesController.dispose();
    targetUserController.dispose();
    usageContextController.dispose();
    userGoalController.dispose();
    taskScenarioController.dispose();
    super.dispose();
  }
}
