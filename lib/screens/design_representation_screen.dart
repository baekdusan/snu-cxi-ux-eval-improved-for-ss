import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ux_evaluation_screen.dart';
import '../models/DR_result.dart' as dr_models;
import '../models/MIA_result.dart';
import '../models/ux_issue_result.dart';
import '../services/ux_evaluation_service.dart';
import '../services/ai_assistant_service.dart';
import '../utils/download_helper.dart';

class DesignRepresentationScreen extends StatefulWidget {
  final List<Map<String, dynamic>> uploadedScreens;
  final dr_models.DRResult? agent1Result; // Agent 1: UXWriting textElements
  final dr_models.DRResult? agent2Result; // Agent 2: Error Prevention & Forgiveness
  final dr_models.DRResult? agent3Result; // Agent 3: Visual Consistency
  final MIAResult? miaResult;
  final bool isMIAEnabled; // MIA 모드 상태
  final Set<int> selectedAgents; // 선택된 에이전트 (1, 2, 3)

  const DesignRepresentationScreen({
    super.key,
    required this.uploadedScreens,
    this.agent1Result,
    this.agent2Result,
    this.agent3Result,
    this.miaResult,
    this.isMIAEnabled = true, // 기본값: MIA 모드
    this.selectedAgents = const {1, 2, 3}, // 기본값: 전체 선택
  });

  @override
  State<DesignRepresentationScreen> createState() =>
      _DesignRepresentationScreenState();
}

class _DesignRepresentationScreenState extends State<DesignRepresentationScreen> {
  // Agent analysis data
  dr_models.DRResult? _agent1Data; // Agent 1: UXWriting textElements
  dr_models.DRResult? _agent2Data; // Agent 2: Error Prevention & Forgiveness
  dr_models.DRResult? _agent3Data; // Agent 3: Visual Consistency
  MIAResult? _miaResult;

  // 선택된 에이전트 추적
  late Set<int> _selectedAgents;

  // Per-module chat state
  final List<TextEditingController> _chatControllers = [];
  final List<List<Map<String, dynamic>>> _chatMessagesPerModule = [];
  final List<bool> _isAILoadingPerModule = [];

  // Module/page navigation
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  // Pagination state (per-module screen offsets)
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
    _agent1Data = widget.agent1Result;
    _agent2Data = widget.agent2Result;
    _agent3Data = widget.agent3Result;
    _miaResult = widget.miaResult;
    _selectedAgents = widget.selectedAgents;
    // Per-module 채팅 상태 초기화
    for (int i = 0; i < _moduleNames.length; i++) {
      _chatControllers.add(TextEditingController());
      _chatMessagesPerModule.add([]);
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
    final aiSectionWidth = screenWidth * 0.33; // 1/3 of screen for AI section
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
    final text = _chatControllers[moduleIndex].text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessagesPerModule[moduleIndex].add({'role': 'user', 'message': text});
      _isAILoadingPerModule[moduleIndex] = true;
      _chatControllers[moduleIndex].clear();
    });

    try {
      final currentDR = _getDRDataForModule(moduleIndex);
      final imageBytes = widget.uploadedScreens
          .where((s) => s['bytes'] != null)
          .map((s) => s['bytes'] as Uint8List)
          .toList();

      final service = AIAssistantService();
      final response = await service.processMessage(
        screenType: 'dr',
        agentNumber: moduleIndex + 1,
        imageBytes: imageBytes,
        userMessage: text,
        drData: currentDR,
        miaData: _miaResult,
      );

      setState(() {
        // Intent 3 (feedback): DR 데이터 업데이트
        if (response.intent == 'feedback' && response.updatedDR != null) {
          _setDRDataForModule(moduleIndex, response.updatedDR!);
        }
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
          'message': '오류가 발생했습니다: $e',
        });
        _isAILoadingPerModule[moduleIndex] = false;
      });
    }
  }

  dr_models.DRResult? _getDRDataForModule(int moduleIndex) {
    switch (moduleIndex) {
      case 0: return _agent1Data;
      case 1: return _agent2Data;
      case 2: return _agent3Data;
      default: return null;
    }
  }

  void _setDRDataForModule(int moduleIndex, dr_models.DRResult updated) {
    switch (moduleIndex) {
      case 0: _agent1Data = updated; break;
      case 1: _agent2Data = updated; break;
      case 2: _agent3Data = updated; break;
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
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: (i) => setState(() => _currentPageIndex = i),
              itemCount: _moduleNames.length,
              itemBuilder: (_, i) => _buildModulePage(i),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Download button
          FloatingActionButton(
            heroTag: 'download_btn',
            onPressed: (_agent1Data != null || _agent2Data != null || _agent3Data != null)
                ? _downloadMIAResults
                : null,
            backgroundColor: (_agent1Data != null || _agent2Data != null || _agent3Data != null)
                ? const Color(0xFF00A86B)
                : Colors.grey,
            child: const Icon(Icons.download, color: Colors.white),
          ),
          const SizedBox(height: 16),
          // Navigate to UX Evaluation button
          FloatingActionButton(
            heroTag: 'navigate_btn',
            onPressed: _handleNavigateToUXEvaluation,
            backgroundColor: const Color(0xFF0046BE),
            child: const Icon(Icons.arrow_forward, color: Colors.white),
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
            '디자인 표현 생성 완료',
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

  // 각 PageView 페이지: 좌(모듈 캐러셀) + 우(AI 도우미)를 함께 담아 동기 스와이프 구현
  Widget _buildModulePage(int moduleIndex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(80, 32, 80, 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: module content (white card)
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
          // Right: AI assistant for this module
          Expanded(
            flex: 1,
            child: _buildAIAssistantSection(moduleIndex),
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

          // Screen image (flex:3 of available height)
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

          // Evaluation box (flex:2 of available height)
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                // Module 0: UX Writing (Agent 1)
                if (moduleIndex == 0 && _agent1Data != null) {
                  _showTextElementDetailModal(screenIndex);
                }
                // Module 1: Error Prevention & Forgiveness (Agent 2)
                else if (moduleIndex == 1 && _agent2Data != null) {
                  _showTextElementDetailModal(screenIndex, agentIndex: 2);
                }
                // Module 2: Visual Consistency (Agent 3)
                else if (moduleIndex == 2 && _agent3Data != null) {
                  _showTextElementDetailModal(screenIndex, agentIndex: 3);
                }
              },
              child: Container(
                width: _screenCardWidth,
                padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _moduleNames[moduleIndex],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0046BE),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildEvaluationContent(moduleIndex, screenIndex),
                    ),
                  ),
                  // Show clickable hint if data exists
                  if ((moduleIndex == 0 && _agent1Data != null) ||
                      (moduleIndex == 1 && _agent2Data != null) ||
                      (moduleIndex == 2 && _agent3Data != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '[클릭하여 상세보기]',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantSection(int moduleIndex) {
    final messages = _chatMessagesPerModule[moduleIndex];
    final isLoading = _isAILoadingPerModule[moduleIndex];
    final controller = _chatControllers[moduleIndex];

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
              child: messages.isEmpty && !isLoading
                  ? Center(
                      child: Text(
                        'AI 도우미에게 질문해보세요\n\n• 사용법 질문\n• DR 결과에 대한 설명 요청\n• DR 수정 요청',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          height: 1.6,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: messages.length + (isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isLoading && index == messages.length) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '분석 중...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final message = messages[index];
                        final isUser = message['role'] == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxWidth: 280),
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
                              message['message'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: isUser ? Colors.white : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          // Input field
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F9FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Color(0xFF0046BE)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(fontSize: 14),
                  onSubmitted: (_) => _sendChatMessage(moduleIndex),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: isLoading ? null : () => _sendChatMessage(moduleIndex),
                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: isLoading ? Colors.grey : const Color(0xFF0046BE),
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationContent(int moduleIndex, int screenIndex) {
    // ========================================
    // 미선택 모듈 체크
    // ========================================
    final agentIndex = moduleIndex + 1; // moduleIndex 0-2 → agentIndex 1-3
    if (!_selectedAgents.contains(agentIndex)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '이 모듈은 분석되지 않았습니다.',
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
    // Module 0 is UX Writing (index 0)
    if (moduleIndex == 0 && _agent1Data != null) {
      // Find the screen data for this screenIndex
      final screenData = _getScreenDataByIndex(screenIndex, isAgent1: true);

      if (screenData != null && screenData.textElements.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '발견된 텍스트 요소: ${screenData.textElements.length}개',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            ...screenData.textElements.take(3).map((textElement) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${textElement.text.length > 30 ? "${textElement.text.substring(0, 30)}..." : textElement.text}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            if (screenData.textElements.length > 3)
              Text(
                '... 외 ${screenData.textElements.length - 3}개',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        );
      } else {
        return Text(
          '텍스트 요소가 발견되지 않았습니다.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        );
      }
    }

    // Module 1: Error Prevention & Forgiveness (Agent 2)
    if (moduleIndex == 1 && _agent2Data != null) {
      final screenData = _getScreenDataByIndex(screenIndex, agentIndex: 2);
      print('[DR Screen] Agent2 화면 $screenIndex 데이터: ${screenData?.rawData?.keys.toList()}');

      if (screenData?.rawData != null) {
        final raw = screenData!.rawData!;
        final inputCount = (raw['입력'] as List? ?? []).length;
        final confirmCount = (raw['확인'] as List? ?? []).length;
        final errorCount = (raw['오류_경고_피드백'] as List? ?? []).length;
        final recoveryCount = (raw['복구'] as List? ?? []).length;
        print('[DR Screen] Agent2 요약: input=$inputCount, confirm=$confirmCount, error=$errorCount, recovery=$recoveryCount');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('입력', inputCount),
            _buildSummaryRow('확인', confirmCount),
            _buildSummaryRow('오류 경고/피드백', errorCount),
            _buildSummaryRow('복구 제어', recoveryCount),
          ],
        );
      } else {
        return Text(
          'Error Prevention 데이터가 없습니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        );
      }
    }

    // Module 2: Visual Consistency (Agent 3)
    if (moduleIndex == 2 && _agent3Data != null) {
      final screenData = _getScreenDataByIndex(screenIndex, agentIndex: 3);
      print('[DR Screen] Agent3 화면 $screenIndex 데이터: ${screenData?.rawData?.keys.toList()}');

      if (screenData?.rawData != null) {
        final raw = screenData!.rawData!;
        final screenLevel = raw['screen_level'] as Map<String, dynamic>?;
        final elements = (raw['elements'] as List? ?? []);
        final structureType = screenLevel?['structure_type'] ?? '알 수 없음';
        print('[DR Screen] Agent3 요약: structureType=$structureType, elements=${elements.length}');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow('Structure', 1, valueLabel: structureType.toString()),
            _buildSummaryRow('Elements', elements.length),
            if (screenLevel != null) ...[
              _buildSummaryRow('Background', 1, valueLabel: screenLevel['background_type']?.toString() ?? '-'),
              _buildSummaryRow('Brightness', 1, valueLabel: screenLevel['brightness_level']?.toString() ?? '-'),
            ],
          ],
        );
      } else {
        return Text(
          'Visual Consistency 데이터가 없습니다.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        );
      }
    }

    // For other modules, show placeholder
    return Text(
      '평가 내용이 여기에 표시됩니다.\n\n각 모듈별로 해당 스크린에 대한 평가 결과가 표시됩니다.',
      style: TextStyle(
        fontSize: 12,
        color: Colors.grey.shade700,
        height: 1.4,
      ),
    );
  }

  dr_models.DRData? _getScreenDataByIndex(int screenIndex,
      {bool? isAgent1, int? agentIndex}) {
    // Support both old (isAgent1) and new (agentIndex) parameters
    dr_models.DRResult? data;

    if (agentIndex != null) {
      switch (agentIndex) {
        case 1:
          data = _agent1Data;
          break;
        case 2:
          data = _agent2Data;
          break;
        case 3:
          data = _agent3Data;
          break;
        default:
          return null;
      }
    } else if (isAgent1 != null) {
      // Legacy support for isAgent1 parameter
      data = isAgent1 ? _agent1Data : _agent3Data;
    } else {
      return null;
    }

    if (data == null) return null;

    // Validate screenIndex is within bounds
    if (screenIndex < 0) return null;

    // Match by screen_id only (e.g., "screen_1" for index 0)
    // screen_id must exactly match the expected format
    final expectedScreenId = 'screen_${screenIndex + 1}';
    for (final screen in data.screens) {
      if (screen.screenId == expectedScreenId) {
        return screen;
      }
    }

    // Return null if no exact match found
    // This ensures UI shows "no data" instead of showing wrong screen data
    return null;
  }

  void _downloadMIAResults() {
    if (_agent1Data == null && _agent2Data == null && _agent3Data == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('분석 결과가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Create timestamp for filename
      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      // Download Agent 1 (UXWriting) results if available
      if (_agent1Data != null) {
        DownloadHelper.downloadJson(
          'ux_writing_dr_$timestamp.json',
          _agent1Data!.toJson(),
        );
      }

      // Download Agent 2 (Error Prevention) results if available
      if (_agent2Data != null) {
        DownloadHelper.downloadJson(
          'error_prevention_dr_$timestamp.json',
          _agent2Data!.toJson(),
        );
      }

      // Download Agent 3 (Visual Consistency) results if available
      if (_agent3Data != null) {
        DownloadHelper.downloadJson(
          'visual_consistency_dr_$timestamp.json',
          _agent3Data!.toJson(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('결과 저장 완료'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('결과 저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showTextElementDetailModal(int screenIndex, {int agentIndex = 1}) {
    final screenData = _getScreenDataByIndex(screenIndex, agentIndex: agentIndex);
    if (screenData == null) return;

    // Get screenshot image for this screen
    final screenImage = screenIndex < widget.uploadedScreens.length
        ? widget.uploadedScreens[screenIndex]['bytes'] as List<int>
        : null;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      '${_moduleNames[agentIndex - 1]} 상세 - Screen ${screenIndex + 1}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content with image and details side by side
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side: Screenshot image
                    if (screenImage != null)
                      Container(
                        width: 300,
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

                    // Divider between image and content
                    if (screenImage != null)
                      Container(
                        width: 1,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(vertical: 20),
                      ),

                    // Right side: agent별 상세 콘텐츠
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: agentIndex == 2
                            ? _buildFormattedAgent2Content(screenData)
                            : agentIndex == 3
                                ? _buildFormattedAgent3Content(screenData)
                                : _buildFormattedTextElementContent(screenData),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedTextElementContent(
      dr_models.DRData screenData) {
    if (screenData.textElements.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            '이 화면에서 발견된 텍스트 요소가 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < screenData.textElements.length; i++) ...[
          _buildTextElementCard(screenData.textElements[i], i + 1),
          if (i < screenData.textElements.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildTextElementCard(
      dr_models.TextElement textElement, int elementNumber) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text element header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0046BE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '텍스트 요소 $elementNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ID: ${textElement.id}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Text content
            _buildInfoRow('텍스트', textElement.text),
            const SizedBox(height: 12),

            // Component type
            if (textElement.component.isNotEmpty) ...[
              _buildInfoRow('컴포넌트 타입', textElement.component),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // 카드 내 요약 행 (Agent 2·3용)
  Widget _buildSummaryRow(String label, int count, {String? valueLabel}) {
    final displayValue = valueLabel ?? '$count개';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: count > 0 || valueLabel != null
                  ? const Color(0xFF0046BE)
                  : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Agent 2 상세 모달 콘텐츠 (Error Prevention)
  // ============================================================
  Widget _buildFormattedAgent2Content(dr_models.DRData screenData) {
    final raw = screenData.rawData;
    if (raw == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'Error Prevention 데이터가 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    print('[DR Modal] Agent2 rawData keys: ${raw.keys.toList()}');

    final sections = [
      ('입력', '입력', ['element_id', 'element_설명', '라벨_텍스트', '플레이스홀더_텍스트', '필수_표시텍스트', '기본값_존재여부', '형식_안내텍스트', '사용자_입력값']),
      ('확인', '확인', ['element_id', 'element_설명', '표현유형', '확인텍스트_표시여부', '취소옵션_표시여부', '명시적_재입력_요구여부']),
      ('오류 경고/피드백', '오류_경고_피드백', ['element_id', 'element_설명', '표현유형', '메시지_텍스트']),
      ('복구 제어', '복구', ['element_id', 'element_설명', '표현유형', '복구유형']),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation escape (object, not array)
        if (raw['네비게이션_이탈'] != null) ...[
          _buildAgent2SectionHeader('네비게이션 이탈'),
          const SizedBox(height: 8),
          _buildKeyValueCard(raw['네비게이션_이탈'] as Map<String, dynamic>),
          const SizedBox(height: 24),
        ],
        // Array sections
        for (final section in sections) ...[
          _buildAgent2SectionHeader('${section.$1} (${(raw[section.$2] as List? ?? []).length}개)'),
          const SizedBox(height: 8),
          ...(raw[section.$2] as List? ?? []).map((item) {
            print('[DR Modal] Agent2 ${section.$1} item: $item');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildKeyValueCard(item as Map<String, dynamic>),
            );
          }),
          if ((raw[section.$2] as List? ?? []).isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('없음', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // ============================================================
  // Agent 3 상세 모달 콘텐츠 (Visual Consistency)
  // ============================================================
  Widget _buildFormattedAgent3Content(dr_models.DRData screenData) {
    final raw = screenData.rawData;
    if (raw == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text(
            'Visual Consistency 데이터가 없습니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    print('[DR Modal] Agent3 rawData keys: ${raw.keys.toList()}');

    final screenLevel = raw['screen_level'] as Map<String, dynamic>?;
    final elements = raw['elements'] as List? ?? [];

    print('[DR Modal] Agent3 screen_level: $screenLevel, elements: ${elements.length}개');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Screen-level attributes
        if (screenLevel != null) ...[
          _buildAgent2SectionHeader('Screen Level'),
          const SizedBox(height: 8),
          _buildKeyValueCard(screenLevel),
          const SizedBox(height: 24),
        ],
        // Elements
        _buildAgent2SectionHeader('Elements (${elements.length}개)'),
        const SizedBox(height: 8),
        ...elements.map((item) {
          final el = item as Map<String, dynamic>;
          final elementId = el['element_id'];
          // element_rep가 빈 객체 {}이면 이전 출현과 동일한 반복 요소
          final elementRep = el['element_rep'] as Map<String, dynamic>?;
          final isRepeat = elementRep == null || elementRep.isEmpty;
          final description = isRepeat ? null : elementRep['element_description']?.toString();
          print('[DR Modal] Agent3 element_id=$elementId: ${isRepeat ? "(repeated)" : description}');
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0046BE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Element $elementId',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isRepeat
                                ? '(이전 화면과 동일한 요소)'
                                : description ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: isRepeat ? Colors.grey.shade400 : Colors.grey.shade700,
                              fontStyle: isRepeat ? FontStyle.italic : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (!isRepeat) ...[
                      const SizedBox(height: 12),
                      // Sub-maps (layout, shape, color, typography, visual_effect, text)
                      for (final key in ['layout', 'shape', 'color', 'typography', 'visual_effect', 'text']) ...[
                        if (elementRep[key] is Map) ...[
                          Text(key.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0046BE))),
                          const SizedBox(height: 4),
                          _buildKeyValueCard(elementRep[key] as Map<String, dynamic>, compact: true),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
        if (elements.isEmpty)
          Text('요소 없음', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ],
    );
  }

  Widget _buildAgent2SectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0046BE).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0046BE)),
      ),
    );
  }

  Widget _buildKeyValueCard(Map<String, dynamic> data, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.map((e) {
          return Padding(
            padding: EdgeInsets.only(bottom: compact ? 2 : 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: compact ? 120 : 160,
                  child: Text(
                    '${e.key}:',
                    style: TextStyle(fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value?.toString() ?? 'null',
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: e.value == null ? Colors.grey : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// UX Evaluation 화면으로 이동 (E 단계 수행)
  ///
  /// 3개 에이전트의 DR 결과를 바탕으로 E (Evaluation) 단계를 병렬 실행하여
  /// UX 이슈를 발견하고 Evaluation 화면으로 이동합니다.
  ///
  /// 처리 흐름:
  /// 1. 3개 에이전트 DR 결과 검증 (필수)
  /// 2. 로딩 다이얼로그 표시
  /// 3. 3개 에이전트 E 병렬 실행 (Future.wait)
  ///    - Agent 1 E: UXWriting 이슈 평가
  ///    - Agent 2 E: Error Prevention & Forgiveness 이슈 평가
  ///    - Agent 3 E: Visual Consistency 이슈 평가
  /// 4. UX Evaluation 화면으로 이동 (DR 결과 + E 결과 전달)
  Future<void> _handleNavigateToUXEvaluation() async {
    // ========================================
    // Step 1: 선택된 에이전트 검증
    // ========================================
    final missingAgents = <int>[];
    if (_selectedAgents.contains(1) && _agent1Data == null) missingAgents.add(1);
    if (_selectedAgents.contains(2) && _agent2Data == null) missingAgents.add(2);
    if (_selectedAgents.contains(3) && _agent3Data == null) missingAgents.add(3);

    if (missingAgents.isNotEmpty) {
      _showErrorDialog(
        '선택한 에이전트의 DR 결과가 없습니다.\n'
        '에이전트: ${missingAgents.join(", ")}',
      );
      return;
    }

    // ========================================
    // Step 2: 로딩 다이얼로그 표시
    // ========================================
    final agentNames = _selectedAgents.map((i) => 'Agent $i').join(', ');
    final loadingMessage = widget.isMIAEnabled
        ? 'UX 이슈를 평가하고 있습니다...\n($agentNames 실행 중)'
        : 'UX 이슈를 평가하고 있습니다...\n(MIAx: $agentNames 실행 중)';

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
              loadingMessage,
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
      // ========================================
      // Step 3: 스크린샷을 Base64로 변환
      // ========================================
      final base64Images = widget.uploadedScreens
          .map((screen) => base64Encode(screen['bytes'] as List<int>))
          .toList();

      // ========================================
      // Step 4: 조건부 E 실행 - 선택된 에이전트만 평가
      // ========================================
      final service = UXEvaluationService();

      // 조건부 Future 리스트 생성
      final futures = <Future>[];
      final futureIndexMap = <int, int>{}; // Agent index → Future index

      int futureIndex = 0;
      if (_selectedAgents.contains(1) && _agent1Data != null) {
        futures.add(service.evaluateUXWritingIssues(
          base64Images: base64Images,
          textElementData: _agent1Data!,
          analysisData: widget.isMIAEnabled ? _miaResult : null,
        ));
        futureIndexMap[1] = futureIndex++;
      }
      if (_selectedAgents.contains(2) && _agent2Data != null) {
        futures.add(service.evaluateErrorPreventionIssues(
          base64Images: base64Images,
          drData: _agent2Data!,
          analysisData: widget.isMIAEnabled ? _miaResult : null,
        ));
        futureIndexMap[2] = futureIndex++;
      }
      if (_selectedAgents.contains(3) && _agent3Data != null) {
        futures.add(service.evaluateVisualConsistencyIssues(
          base64Images: base64Images,
          drData: _agent3Data!,
          analysisData: widget.isMIAEnabled ? _miaResult : null,
        ));
        futureIndexMap[3] = futureIndex++;
      }

      // ========================================
      // Pre-warming: rootBundle 캐시 선점으로 Platform Channel deadlock 방지
      // ========================================
      // Future.wait() 병렬 실행 시 Agent 2의 Firebase 초기화(GeminiService 생성자)와
      // Agent 3의 rootBundle.loadString()이 동시에 Platform Channel을 요청 → deadlock.
      // 미리 순차적으로 캐시를 채우면 병렬 실행 시 캐시에서 즉시 반환되므로 경합이 사라짐.
      if (futureIndexMap.containsKey(1)) {
        await rootBundle.loadString('lib/prompts/Agent1_E_system.md');
        await rootBundle.loadString('lib/prompts/Agent1_E_prompt.md');
      }
      if (futureIndexMap.containsKey(2)) {
        await rootBundle.loadString('lib/prompts/Agent2_E_system.md');
        await rootBundle.loadString('lib/prompts/Agent2_E_prompt.md');
      }
      if (futureIndexMap.containsKey(3)) {
        await rootBundle.loadString('lib/prompts/Agent3_E_system.md');
        await rootBundle.loadString('lib/prompts/Agent3_E_prompt.md');
      }

      // 선택된 에이전트들을 병렬 실행
      final results = await Future.wait(futures);

      // ========================================
      // Step 5: 결과 매핑
      // ========================================
      UXIssueResult? agent1IssueResult = _selectedAgents.contains(1) && futureIndexMap.containsKey(1)
          ? results[futureIndexMap[1]!] as UXIssueResult : null;
      UXIssueResult? agent2IssueResult = _selectedAgents.contains(2) && futureIndexMap.containsKey(2)
          ? results[futureIndexMap[2]!] as UXIssueResult : null;
      UXIssueResult? agent3IssueResult = _selectedAgents.contains(3) && futureIndexMap.containsKey(3)
          ? results[futureIndexMap[3]!] as UXIssueResult : null;

      // ========================================
      // Step 6: 로딩 닫기
      // ========================================
      if (mounted) Navigator.pop(context);

      // ========================================
      // Step 7: UX Evaluation 화면으로 이동
      // ========================================
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UXEvaluationScreen(
              uploadedScreens: widget.uploadedScreens,
              miaResult: _miaResult,
              agent1Result: _agent1Data,
              agent2Result: _agent2Data,
              agent3Result: _agent3Data,
              agent1IssueResult: agent1IssueResult,
              agent2IssueResult: agent2IssueResult,
              agent3IssueResult: agent3IssueResult,
              selectedAgents: _selectedAgents, // 선택된 에이전트 전달
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error dialog
      _showErrorDialog('UX 평가 중 오류가 발생했습니다:\n$e');
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
}
