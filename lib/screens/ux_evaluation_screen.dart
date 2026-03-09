import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/MIA_result.dart';
import '../models/DR_result.dart';
import '../models/ux_issue_result.dart';
import '../services/ai_assistant_service.dart';

class UXEvaluationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> uploadedScreens;
  final MIAResult? miaResult;
  final DRResult? agent1Result; // Agent 1: UXWriting DR
  final DRResult? agent2Result; // Agent 2: Error Prevention DR
  final DRResult? agent3Result; // Agent 3: Visual Consistency DR
  final UXIssueResult? agent1IssueResult; // Agent 1: UXWriting issues
  final UXIssueResult? agent2IssueResult; // Agent 2: Error Prevention issues
  final UXIssueResult? agent3IssueResult; // Agent 3: Visual Consistency issues
  final Set<int> selectedAgents; // 선택된 에이전트 (1, 2, 3)

  const UXEvaluationScreen({
    super.key,
    required this.uploadedScreens,
    this.miaResult,
    this.agent1Result,
    this.agent2Result,
    this.agent3Result,
    this.agent1IssueResult,
    this.agent2IssueResult,
    this.agent3IssueResult,
    this.selectedAgents = const {1, 2, 3}, // 기본값: 전체 선택
  });

  @override
  State<UXEvaluationScreen> createState() => _UXEvaluationScreenState();
}

class _UXEvaluationScreenState extends State<UXEvaluationScreen> {
  // PageView controller for card-view navigation between modules
  late PageController _pageController;
  int _currentPageIndex = 0;

  // UX Issue data
  UXIssueResult? _agent1IssueResult; // Agent 1 E: UXWriting issues
  UXIssueResult? _agent2IssueResult; // Agent 2 E: Error Prevention issues
  UXIssueResult? _agent3IssueResult; // Agent 3 E: Visual Consistency issues

  // 선택된 에이전트 추적
  late Set<int> _selectedAgents;

  // Per-module chat interface state (각 모듈마다 독립적인 AI 도우미)
  final List<TextEditingController> _chatControllers = [];
  final List<List<Map<String, dynamic>>> _chatMessagesPerModule = [];

  // 모듈별 선택된 이슈 ID Set (피드백 대상 이슈 추적)
  final List<Set<String>> _selectedIssueIdsPerModule = [];

  // 모듈별 AI 로딩 상태
  final List<bool> _isAILoadingPerModule = [];

  // Pagination state
  final Map<int, int> _moduleScreenOffsets = {0: 0, 1: 0, 2: 0};

  // Constants
  static const double _screenCardWidth = 250.0;

  final List<String> _moduleNames = [
    'UX Writing',                      // Index 0 (Agent 1)
    'Error Prevention & Forgiveness',  // Index 1 (Agent 2)
    'Visual Consistency',              // Index 2 (Agent 3)
  ];

  @override
  void initState() {
    super.initState();
    _agent1IssueResult = widget.agent1IssueResult;
    _agent2IssueResult = widget.agent2IssueResult;
    _agent3IssueResult = widget.agent3IssueResult;
    _selectedAgents = widget.selectedAgents;
    _pageController = PageController(initialPage: 0);
    // 모듈별 채팅 컨트롤러/메시지/선택/로딩 초기화
    for (int i = 0; i < _moduleNames.length; i++) {
      _chatControllers.add(TextEditingController());
      _chatMessagesPerModule.add([]);
      _selectedIssueIdsPerModule.add({});
      _isAILoadingPerModule.add(false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _chatControllers) {
      c.dispose();
    }
    super.dispose();
  }

  int _getScreensPerPage(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Calculate available dimensions
    final aiSectionWidth = screenWidth * 0.2; // 1/5 of screen for AI section
    final carouselWidth = screenWidth - 160 - 40 - aiSectionWidth;
    final carouselHeight = screenHeight - 200 - 160; // header + padding

    // Card aspect ratio: width 250, height 650 → ~0.38
    const cardAspectRatio = 250.0 / 650.0;

    // Calculate capacity based on BOTH dimensions
    final maxByWidth = ((carouselWidth - 100) / 282).floor();

    // Aspect ratio consideration: wider screens show more
    final viewportAspect = carouselWidth / carouselHeight;
    final adjustment = (viewportAspect / cardAspectRatio).clamp(0.8, 1.5);

    final screensPerPage = (maxByWidth * adjustment).floor().clamp(3, 7);
    return screensPerPage;
  }

  Future<void> _sendChatMessage(int moduleIndex) async {
    final controller = _chatControllers[moduleIndex];
    if (controller.text.isEmpty) return;
    if (_isAILoadingPerModule[moduleIndex]) return;

    final userComment = controller.text;
    final agentNumber = moduleIndex + 1; // moduleIndex 0→Agent1, 1→Agent2, 2→Agent3
    final selectedIds = _selectedIssueIdsPerModule[moduleIndex];

    // 1. 사용자 메시지 추가 + 로딩 시작
    setState(() {
      _chatMessagesPerModule[moduleIndex].add({
        'role': 'user',
        'message': userComment,
      });
      _isAILoadingPerModule[moduleIndex] = true;
      controller.clear();
    });

    try {
      // 2. 데이터 수집
      final issueResult = _getIssueResultForAgent(agentNumber);
      final allIssues = issueResult?.uxIssues ?? [];
      final selectedIssuesList = selectedIds.isNotEmpty
          ? allIssues.where((i) => selectedIds.contains(i.issueId)).toList()
          : null;

      final imageBytes = widget.uploadedScreens
          .where((s) => s['bytes'] != null)
          .map((s) => s['bytes'] as Uint8List)
          .toList();

      final drData = _getDRResultForAgent(agentNumber);

      final idPrefix = switch (agentNumber) {
        1 => 'UX-WRITING',
        2 => 'ERROR-PREV',
        3 => 'VISUAL-CONSIST',
        _ => 'ISSUE',
      };

      // 3. AIAssistantService 호출 (인텐트 자동 분류)
      final service = AIAssistantService();
      final response = await service.processMessage(
        screenType: 'evaluation',
        agentNumber: agentNumber,
        imageBytes: imageBytes,
        userMessage: userComment,
        drData: drData,
        targetIssues: allIssues,
        selectedIssues: selectedIssuesList,
        miaData: widget.miaResult,
        issueIdPrefix: idPrefix,
      );

      // 4. 인텐트별 처리
      setState(() {
        if (response.intent == 'feedback' && response.feedbackResult != null) {
          // Intent 3: 이슈 업데이트
          final result = response.feedbackResult!;
          final isSelectedMode = selectedIds.isNotEmpty;

          if (isSelectedMode) {
            // 선택 모드: 선택된 이슈만 교체, 나머지 유지
            final updatedMap = {for (var i in result.updatedIssues) i.issueId: i};
            final removedIds = result.changes
                .where((c) => c.action == 'removed')
                .map((c) => c.issueId)
                .toSet();
            final newList = <UXIssue>[];
            for (final existing in allIssues) {
              if (removedIds.contains(existing.issueId)) continue;
              if (updatedMap.containsKey(existing.issueId)) {
                newList.add(updatedMap.remove(existing.issueId)!);
              } else {
                newList.add(existing);
              }
            }
            newList.addAll(updatedMap.values);
            _setIssueResultForAgent(agentNumber, UXIssueResult(uxIssues: newList));
          } else {
            // 전체 모드: 전체 교체
            _setIssueResultForAgent(
                agentNumber, UXIssueResult(uxIssues: result.updatedIssues));
          }

          // Intent 3에서만 선택 해제
          _selectedIssueIdsPerModule[moduleIndex].clear();
        }
        // Intent 1/2: 선택 상태 유지 (데이터 변경 없음)

        // 모든 인텐트: 텍스트 응답 표시
        _chatMessagesPerModule[moduleIndex].add({
          'role': 'assistant',
          'message': response.responseText,
        });
        _isAILoadingPerModule[moduleIndex] = false;
      });
    } catch (e) {
      setState(() {
        _chatMessagesPerModule[moduleIndex].add({
          'role': 'assistant',
          'message': '처리 중 오류가 발생했습니다: $e',
        });
        _isAILoadingPerModule[moduleIndex] = false;
      });
    }
  }

  /// agentNumber (1,2,3) → 해당 에이전트의 UXIssueResult
  UXIssueResult? _getIssueResultForAgent(int agentNumber) {
    return switch (agentNumber) {
      1 => _agent1IssueResult,
      2 => _agent2IssueResult,
      3 => _agent3IssueResult,
      _ => null,
    };
  }

  /// agentNumber (1,2,3) → 해당 에이전트의 DRResult
  DRResult? _getDRResultForAgent(int agentNumber) {
    return switch (agentNumber) {
      1 => widget.agent1Result,
      2 => widget.agent2Result,
      3 => widget.agent3Result,
      _ => null,
    };
  }

  /// agentNumber (1,2,3) → 해당 에이전트의 이슈 결과 설정
  void _setIssueResultForAgent(int agentNumber, UXIssueResult result) {
    switch (agentNumber) {
      case 1:
        _agent1IssueResult = result;
      case 2:
        _agent2IssueResult = result;
      case 3:
        _agent3IssueResult = result;
    }
  }

  void _downloadUXIssueResults() {
    if (_agent1IssueResult == null && _agent2IssueResult == null && _agent3IssueResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UX 이슈 결과가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Create timestamp-based filename
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      // Download Agent 1 (UXWriting) issues if available
      if (_agent1IssueResult != null) {
        final jsonData = _agent1IssueResult!.toJson();
        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
        final filename = 'ux_writing_issues_$timestamp.json';

        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      // Download Agent 2 (Error Prevention) issues if available
      if (_agent2IssueResult != null) {
        final jsonData = _agent2IssueResult!.toJson();
        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
        final filename = 'error_prevention_issues_$timestamp.json';

        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      // Download Agent 3 (Visual Consistency) issues if available
      if (_agent3IssueResult != null) {
        final jsonData = _agent3IssueResult!.toJson();
        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
        final filename = 'visual_consistency_issues_$timestamp.json';

        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('결과 저장 완료'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('결과 저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          _buildHeader(),
          _buildModuleTabBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              children: [
                for (int i = 0; i < _moduleNames.length; i++)
                  _buildModulePage(i),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Download Button (녹색)
          FloatingActionButton(
            heroTag: 'download_button',
            onPressed: (_agent1IssueResult != null || _agent2IssueResult != null || _agent3IssueResult != null)
                ? _downloadUXIssueResults
                : null,
            backgroundColor: (_agent1IssueResult != null || _agent2IssueResult != null || _agent3IssueResult != null)
                ? const Color(0xFF00A86B)
                : Colors.grey,
            tooltip: 'UX 이슈 결과 다운로드',
            child: const Icon(Icons.download, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
                  content: const Text('이전 화면으로 돌아가시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
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
            'UX 이슈 발견 완료',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 80),
      child: Row(
        children: [
          for (int i = 0; i < _moduleNames.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _currentPageIndex == i
                      ? const Color(0xFF0046BE)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _currentPageIndex == i
                        ? const Color(0xFF0046BE)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  '${i + 1}. ${_moduleNames[i]}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _currentPageIndex == i
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModulePage(int moduleIndex) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: module content
          Expanded(
            flex: 4,
            child: Container(
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
              child: _buildModuleSection(
                moduleName: _moduleNames[moduleIndex],
                moduleIndex: moduleIndex,
              ),
            ),
          ),
          const SizedBox(width: 40),
          // Right: per-module AI chat
          Expanded(
            flex: 1,
            child: _buildAIAssistantSection(moduleIndex: moduleIndex),
          ),
        ],
      ),
    );
  }


  Widget _buildModuleSection({
    required String moduleName,
    required int moduleIndex,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            moduleName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0046BE),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildModuleCarousel(moduleIndex)),
        ],
      ),
    );
  }

  Widget _buildModuleCarousel(int moduleIndex) {
    final screensPerPage = _getScreensPerPage(context);
    final offset = _moduleScreenOffsets[moduleIndex] ?? 0;
    final totalScreens = widget.uploadedScreens.length;
    final endIndex = (offset + screensPerPage).clamp(0, totalScreens);
    final visibleCount = endIndex - offset;

    return Row(
        children: [
          // Left Arrow
          IconButton(
            onPressed: offset > 0
                ? () {
                    setState(() {
                      _moduleScreenOffsets[moduleIndex] =
                          (offset - screensPerPage).clamp(0, totalScreens);
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_left, size: 32),
            style: IconButton.styleFrom(
              backgroundColor: offset > 0 ? Colors.white : Colors.grey.shade200,
              foregroundColor: offset > 0
                  ? const Color(0xFF0046BE)
                  : Colors.grey,
              shape: const CircleBorder(),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),

          // Screens
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  for (int i = 0; i < screensPerPage; i++)
                    Expanded(
                      child: i < visibleCount
                          ? _buildScreenWithEvaluation(
                              moduleIndex: moduleIndex,
                              screenIndex: offset + i,
                            )
                          : Container(),
                    ),
                ],
              ),
            ),
          ),

          // Right Arrow
          IconButton(
            onPressed: endIndex < totalScreens
                ? () {
                    setState(() {
                      _moduleScreenOffsets[moduleIndex] =
                          (offset + screensPerPage).clamp(0, totalScreens);
                    });
                  }
                : null,
            icon: const Icon(Icons.chevron_right, size: 32),
            style: IconButton.styleFrom(
              backgroundColor: endIndex < totalScreens
                  ? const Color(0xFF0046BE)
                  : Colors.grey.shade200,
              foregroundColor: endIndex < totalScreens
                  ? Colors.white
                  : Colors.grey,
              shape: const CircleBorder(),
            ),
          ),
        ],
      );
  }

  Widget _buildScreenWithEvaluation({
    required int moduleIndex,
    required int screenIndex,
  }) {
    final screen = widget.uploadedScreens[screenIndex];

    return Container(
      width: _screenCardWidth,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Screen number
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Screen ${screenIndex + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),

          // Screenshot (이미지 비율에 맞게 축소, 남은 공간은 평가 박스에)
          Flexible(
            flex: 3,
            child: Container(
              width: _screenCardWidth,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: screen['bytes'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(screen['bytes'], fit: BoxFit.contain),
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

          const SizedBox(height: 12),

          // Evaluation box (남은 공간 최대한 활용)
          Expanded(
            flex: 2,
            child: Container(
              width: _screenCardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: _buildEvaluationContent(
                  moduleIndex: moduleIndex,
                  screenIndex: screenIndex,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationContent({
    required int moduleIndex,
    required int screenIndex,
  }) {
    // ========================================
    // 미선택 모듈 체크
    // ========================================
    final agentIndex = moduleIndex + 1; // moduleIndex 0-3 → agentIndex 1-4
    if (!_selectedAgents.contains(agentIndex)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '이 모듈은 평가되지 않았습니다.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // ========================================
    // 선택된 모듈 - 기존 로직
    // ========================================
    // Module 0: UX Writing (Agent 1 E)
    if (moduleIndex == 0 && _agent1IssueResult != null) {
      final issuesForThisScreen = _getIssuesForScreen(screenIndex, isAgent1: true);

      if (issuesForThisScreen.isEmpty) {
        return Text(
          '이 화면에서 발견된 UX Writing 이슈가 없습니다.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '발견된 UX Writing 이슈: ${issuesForThisScreen.length}개',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...issuesForThisScreen.take(2).map((issue) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${issue.problemDescription.length > 80 ? "${issue.problemDescription.substring(0, 80)}..." : issue.problemDescription}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          if (issuesForThisScreen.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => _showUXIssuesModal(screenIndex, isAgent1: true),
                child: Text(
                  '[클릭하여 ${issuesForThisScreen.length}개 이슈 전체 보기]',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (issuesForThisScreen.length <= 2 && issuesForThisScreen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => _showUXIssuesModal(screenIndex, isAgent1: true),
                child: Text(
                  '[클릭하여 상세 보기]',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Module 1: Error Prevention & Forgiveness (Agent 2 E)
    // Module 2: Visual Consistency (Agent 3 E)
    // Both use the same UX Writing-style issue display
    if ((moduleIndex == 1 && _agent2IssueResult != null) ||
        (moduleIndex == 2 && _agent3IssueResult != null)) {
      final agentIdx = moduleIndex + 1;
      final issuesForThisScreen = _getIssuesForScreen(screenIndex, agentIndex: agentIdx);
      final moduleName = _moduleNames[moduleIndex];

      if (issuesForThisScreen.isEmpty) {
        return Text(
          '이 화면에서 발견된 $moduleName 이슈가 없습니다.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '발견된 $moduleName 이슈: ${issuesForThisScreen.length}개',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...issuesForThisScreen.take(2).map((issue) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${issue.problemDescription.length > 80 ? "${issue.problemDescription.substring(0, 80)}..." : issue.problemDescription}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          if (issuesForThisScreen.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => _showUXIssuesModal(screenIndex, agentIndex: agentIdx),
                child: Text(
                  '[클릭하여 ${issuesForThisScreen.length}개 이슈 전체 보기]',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (issuesForThisScreen.length <= 2 && issuesForThisScreen.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => _showUXIssuesModal(screenIndex, agentIndex: agentIdx),
                child: Text(
                  '[클릭하여 상세 보기]',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // For other modules or when no data, show placeholder
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_moduleNames[moduleIndex]} 평가',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0046BE),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Screen ${screenIndex + 1}의 ${_moduleNames[moduleIndex]} 평가 항목이 여기 표시됩니다.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '평가 항목 예시:\n• 항목 1\n• 항목 2\n• 항목 3',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  /// 특정 화면의 UX 이슈만 필터링하여 반환
  ///
  /// 4개 에이전트의 이슈 결과에서 screenIndex에 해당하는 이슈만 추출합니다.
  ///
  /// Parameters:
  /// - [screenIndex]: 화면 인덱스 (0-based)
  /// - [isAgent1]: (Legacy) Agent 1이면 true, Agent 3이면 false
  /// - [agentIndex]: (권장) 1=Agent1, 2=Agent2, 3=Agent3, 4=Agent4
  ///
  /// Returns: 해당 화면의 UX 이슈 목록
  ///
  /// 💡 Agent 4 특수 처리:
  ///    Agent 4는 two-phase evaluation (flow-level + interaction-level)이므로
  ///    getAllIssues()를 호출하여 두 단계의 이슈를 모두 반환합니다.
  List<UXIssue> _getIssuesForScreen(int screenIndex,
      {bool? isAgent1, int? agentIndex}) {
    // ========================================
    // Step 1: 에이전트별 이슈 결과 선택
    // ========================================
    List<UXIssue>? allIssues;

    if (agentIndex != null) {
      // 권장 방식: agentIndex 사용
      switch (agentIndex) {
        case 1:
          allIssues = _agent1IssueResult?.uxIssues;
          break;
        case 2:
          allIssues = _agent2IssueResult?.uxIssues;
          break;
        case 3:
          allIssues = _agent3IssueResult?.uxIssues;
          break;
      }
    } else if (isAgent1 != null) {
      // Legacy 방식: isAgent1 사용 (Agent 1 or 3만 지원)
      final issueResult = isAgent1 ? _agent1IssueResult : _agent3IssueResult;
      allIssues = issueResult?.uxIssues;
    }

    if (allIssues == null) return [];

    // ========================================
    // Step 2: screenId로 필터링
    // ========================================
    // screenIndex 0 → "screen_1"
    // screenIndex 1 → "screen_2" ...
    final screenId = 'screen_${screenIndex + 1}';

    return allIssues.where((issue) {
      return issue.screenId == screenId;
    }).toList();
  }

  void _showUXIssuesModal(int screenIndex, {bool isAgent1 = true, int? agentIndex}) {
    final issuesForScreen = agentIndex != null
        ? _getIssuesForScreen(screenIndex, agentIndex: agentIndex)
        : _getIssuesForScreen(screenIndex, isAgent1: isAgent1);
    if (issuesForScreen.isEmpty) return;

    // Get screenshot image
    final screenImage = screenIndex < widget.uploadedScreens.length
        ? widget.uploadedScreens[screenIndex]['bytes'] as List<int>
        : null;

    final resolvedAgentIndex = agentIndex ?? (isAgent1 ? 1 : 3);
    final moduleIndex = resolvedAgentIndex - 1;
    final modalTitle = '${_moduleNames[moduleIndex]} 이슈 - Screen ${screenIndex + 1}';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setModalState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 800),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        modalTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // 선택된 이슈 개수 표시
                      if (_selectedIssueIdsPerModule[moduleIndex].isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0046BE).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedIssueIdsPerModule[moduleIndex].length}개 선택됨',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0046BE),
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          // 모달 닫힐 때 메인 화면도 갱신 (선택 상태 반영)
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content with screenshot and issues side by side
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Screenshot
                      if (screenImage != null)
                        Container(
                          width: 350,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '스크린샷',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0046BE),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      Uint8List.fromList(screenImage),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Divider
                      if (screenImage != null)
                        Container(
                          width: 1,
                          color: Colors.grey.shade300,
                          margin: const EdgeInsets.symmetric(vertical: 20),
                        ),

                      // Right: UX Issues (선택 가능)
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _buildSelectableUXIssuesList(
                            issuesForScreen,
                            moduleIndex,
                            setModalState,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectableUXIssuesList(
    List<UXIssue> issues,
    int moduleIndex,
    StateSetter setModalState,
  ) {
    final sortedIssues = List<UXIssue>.from(issues);
    final selectedIds = _selectedIssueIdsPerModule[moduleIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '총 ${issues.length}개의 UX 이슈가 발견되었습니다',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 선택 안내 텍스트
        Text(
          '이슈를 클릭하여 AI 피드백 대상으로 선택할 수 있습니다',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),

        // Issues list (선택 가능)
        for (int i = 0; i < sortedIssues.length; i++) ...[
          _buildSelectableIssueCard(
            sortedIssues[i],
            i + 1,
            selectedIds.contains(sortedIssues[i].issueId),
            () {
              setModalState(() {
                final id = sortedIssues[i].issueId;
                if (selectedIds.contains(id)) {
                  selectedIds.remove(id);
                } else {
                  selectedIds.add(id);
                }
              });
            },
          ),
          if (i < sortedIssues.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// 선택 가능한 이슈 카드 래퍼
  Widget _buildSelectableIssueCard(
    UXIssue issue,
    int issueNumber,
    bool isSelected,
    VoidCallback onToggle,
  ) {
    final innerCard = issue is VisualConsistencyIssue
        ? _buildVisualConsistencyIssueCard(issue, issueNumber)
        : _buildUXWritingIssueCard(issue, issueNumber);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF0046BE),
                  width: 2.5,
                ),
                color: const Color(0xFF0046BE).withValues(alpha: 0.03),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0046BE).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: Stack(
          children: [
            innerCard,
            // 선택 체크마크
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0046BE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Agent 1: UX Writing Issue Card
  Widget _buildUXWritingIssueCard(UXIssue issue, int issueNumber) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Issue header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0046BE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Issue $issueNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    issue.issueId,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Element info (Agent별 분기)
            if (issue is ErrorPreventionIssue) ...[
              if (issue.elementId != null) ...[
                _buildInfoSection('요소 ID', '#${issue.elementId}', Icons.tag),
                const SizedBox(height: 8),
              ],
              if (issue.elementType != null) ...[
                _buildInfoSection('요소 유형', issue.elementType!, Icons.widgets),
                const SizedBox(height: 8),
              ],
            ] else if (issue is UXWritingIssue) ...[
              _buildInfoSection('텍스트 요소 ID', '#${issue.textElementId}', Icons.tag),
              const SizedBox(height: 8),
              _buildInfoSection('원본 텍스트', issue.text, Icons.text_fields),
              const SizedBox(height: 8),
            ],

            const Divider(height: 32),

            // Problem description
            _buildDetailSection(
              '문제 설명',
              issue.problemDescription,
              Colors.red.shade700,
            ),

            const SizedBox(height: 16),

            // Heuristic violated
            _buildDetailSection(
              '위반된 휴리스틱',
              issue.heuristicViolated,
              const Color(0xFF0046BE),
            ),

            const SizedBox(height: 16),

            // Reasoning
            _buildDetailSection(
              '근거',
              issue.reasoning,
              Colors.grey.shade800,
            ),

            const Divider(height: 32),

            // Recommendation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.green.shade700,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '개선 제안',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    issue.recommendation,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade900,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Agent 3: Visual Consistency Issue Card
  Widget _buildVisualConsistencyIssueCard(VisualConsistencyIssue issue, int issueNumber) {
    final isScreenLevel = issue.violationLevel == 'screen';
    final elementIdLabel = isScreenLevel ? 'Screen Level' : '#${issue.elementId ?? 0}';
    final descriptionLabel = isScreenLevel || (issue.elementDescription?.isEmpty ?? true)
        ? '화면 전체'
        : issue.elementDescription!;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Issue header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0046BE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Issue $issueNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    issue.issueId,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Element info — 출력 포맷 순서 그대로 모든 필드 표시
            _buildInfoSection('Screen ID', issue.screenId, Icons.phone_android),
            const SizedBox(height: 8),
            _buildInfoSection('Violation Level', issue.violationLevel, Icons.layers_outlined),
            const SizedBox(height: 8),
            _buildInfoSection('Element ID', elementIdLabel, Icons.tag),
            const SizedBox(height: 8),
            _buildInfoSection('Element Description', descriptionLabel, Icons.text_fields),
            const SizedBox(height: 8),
            _buildInfoSection('Violated Attribute', issue.violatedAttribute, Icons.layers),

            const Divider(height: 32),

            // Problem description
            _buildDetailSection('문제 설명', issue.problemDescription, Colors.red.shade700),
            const SizedBox(height: 16),

            // Heuristic violated
            _buildDetailSection('위반된 휴리스틱', issue.heuristicViolated, const Color(0xFF0046BE)),
            const SizedBox(height: 16),

            // Reasoning
            _buildDetailSection('근거', issue.reasoning, Colors.grey.shade800),

            const Divider(height: 32),

            // Recommendation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '개선 제안',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    issue.recommendation,
                    style: TextStyle(fontSize: 13, color: Colors.green.shade900, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, String content, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade800,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildAIAssistantSection({required int moduleIndex}) {
    final isLoading = _isAILoadingPerModule[moduleIndex];
    final selectedIds = _selectedIssueIdsPerModule[moduleIndex];

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
            'AI 도우미',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Chat messages area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _chatMessagesPerModule[moduleIndex].isEmpty && !isLoading
                  ? Center(
                      child: Text(
                        'AI 도우미에게 질문해보세요\n\n• 사용법 질문\n• 이슈에 대한 설명 요청\n• 이슈 수정 요청',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _chatMessagesPerModule[moduleIndex].length +
                          (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 로딩 인디케이터 (마지막 항목)
                        if (isLoading &&
                            index == _chatMessagesPerModule[moduleIndex].length) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '분석 중...',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final message =
                            _chatMessagesPerModule[moduleIndex][index];
                        final isUser = message['role'] == 'user';

                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            constraints: const BoxConstraints(maxWidth: 250),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? const Color(0xFF0046BE)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: isUser
                                  ? null
                                  : Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              message['message'],
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // 선택된 이슈 칩 오버레이
          if (selectedIds.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0046BE).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0046BE).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '선택된 이슈 (${selectedIds.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0046BE),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: selectedIds.map((id) {
                      return Chip(
                        label: Text(
                          id,
                          style: const TextStyle(fontSize: 10),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            selectedIds.remove(id);
                          });
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Input field
          Container(
            decoration: BoxDecoration(
              color: isLoading ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatControllers[moduleIndex],
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: isLoading ? '분석 중...' : '메시지를 입력하세요...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: isLoading
                        ? null
                        : (_) => _sendChatMessage(moduleIndex),
                  ),
                ),
                IconButton(
                  onPressed:
                      isLoading ? null : () => _sendChatMessage(moduleIndex),
                  icon: Icon(
                    Icons.send,
                    color: isLoading
                        ? Colors.grey.shade400
                        : const Color(0xFF0046BE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
