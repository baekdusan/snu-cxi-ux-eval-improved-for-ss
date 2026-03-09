import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'gemini_service.dart';
import '../models/DR_result.dart';
import '../models/MIA_result.dart';
import '../models/ux_issue_result.dart';
import 'feedback_service.dart';

/// AI 도우미 응답 결과
///
/// 3가지 인텐트에 대한 통합 응답 객체:
/// - system_usage: responseText만 사용
/// - explain_reasoning: responseText만 사용
/// - feedback: responseText + updatedDR (DR 화면) 또는 feedbackResult (Eval 화면)
class AIAssistantResponse {
  final String intent; // 'system_usage', 'explain_reasoning', 'feedback'
  final String responseText;
  final DRResult? updatedDR; // Intent 3 + DR 화면
  final FeedbackResult? feedbackResult; // Intent 3 + Eval 화면

  AIAssistantResponse({
    required this.intent,
    required this.responseText,
    this.updatedDR,
    this.feedbackResult,
  });
}

/// AIAssistantService
///
/// 사용자 메시지를 3가지 인텐트로 자동 분류하여 처리하는 통합 AI 도우미 서비스:
/// 1. system_usage — 시스템 사용법 질문
/// 2. explain_reasoning — AI 추론 이해 질문
/// 3. feedback — 피드백/수정 요청 (기존 기능)
///
/// DR 화면과 Evaluation 화면 모두에서 사용됩니다.
/// Stage 1 경량 분류 결과
class _ClassificationResult {
  final String intent;
  final String responseText;
  _ClassificationResult({required this.intent, required this.responseText});
}

class AIAssistantService {
  GeminiService? _geminiService;
  GeminiService? _classifierService;
  bool? _lastMIAState;

  static const _agentNames = [
    'UX Writing',
    'Error Prevention & Forgiveness',
    'Visual Consistency',
  ];

  /// 사용자 메시지를 처리하여 적절한 응답 반환
  Future<AIAssistantResponse> processMessage({
    required String screenType, // 'dr' | 'evaluation'
    required int agentNumber, // 1, 2, 3
    required List<Uint8List> imageBytes,
    required String userMessage,
    DRResult? drData,
    List<UXIssue>? targetIssues,
    List<UXIssue>? selectedIssues,
    MIAResult? miaData,
    String? issueIdPrefix,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  [AIAssistant] Agent $agentNumber ($screenType) 메시지 처리 시작    ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('💬 사용자 메시지: $userMessage');
    print('📊 입력: 이미지 ${imageBytes.length}개, DR ${drData?.screens.length ?? 0}개 화면');
    if (targetIssues != null) {
      print('   이슈 ${targetIssues.length}개, 선택된 이슈 ${selectedIssues?.length ?? 0}개');
    }

    // ========================================
    // Stage 1: 경량 텍스트 전용 분류 (이미지 없음)
    // Intent 1 (system_usage)이면 여기서 즉시 반환 (~1-2초)
    // ========================================
    final classification = await _classifyIntent(
      screenType: screenType,
      userMessage: userMessage,
    );

    if (classification.intent == 'system_usage') {
      print('🎯 Stage 1 → system_usage → 즉시 반환');
      return AIAssistantResponse(
        intent: 'system_usage',
        responseText: classification.responseText,
      );
    }

    print('🎯 Stage 1 → ${classification.intent} → Stage 2 전체 처리 진행');

    // ========================================
    // Stage 2: 전체 처리 (Intent 2/3만 도달)
    // ========================================

    // 1. GeminiService 초기화
    final service = await _getGeminiService(miaData: miaData);

    // 2. 프롬프트 생성
    final prompt = await _buildPrompt(
      screenType: screenType,
      agentNumber: agentNumber,
      userMessage: userMessage,
      drData: drData,
      targetIssues: targetIssues,
      selectedIssues: selectedIssues,
      miaData: miaData,
      issueIdPrefix: issueIdPrefix,
    );

    print('📝 프롬프트 길이: ${prompt.length}자');

    // 3. Gemini API 호출
    final startTime = DateTime.now();
    final response = await service.analyzeScreenshots(
      imageBytes: imageBytes,
      prompt: prompt,
    );
    final duration = DateTime.now().difference(startTime);
    print('⏱️  처리 시간: ${duration.inSeconds}초');

    // 4. JSON 파싱
    final jsonString = _extractJson(response);
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

    final intent = jsonData['intent'] as String? ?? 'explain_reasoning';
    final responseText = jsonData['response_text'] as String? ?? '';

    print('🎯 Stage 2 분류된 인텐트: $intent');
    print('📤 응답 텍스트: ${responseText.length > 100 ? '${responseText.substring(0, 100)}...' : responseText}');

    // 5. 인텐트별 처리
    switch (intent) {
      case 'system_usage':
      case 'explain_reasoning':
        return AIAssistantResponse(
          intent: intent,
          responseText: responseText,
        );

      case 'feedback':
        if (screenType == 'dr') {
          return _handleDRFeedback(jsonData, responseText);
        } else {
          return _handleEvalFeedback(jsonData, responseText, agentNumber);
        }

      default:
        return AIAssistantResponse(
          intent: 'explain_reasoning',
          responseText: responseText.isNotEmpty
              ? responseText
              : '메시지를 이해하지 못했습니다. 다시 시도해주세요.',
        );
    }
  }

  // ============================================================
  // Stage 1: 경량 인텐트 분류 (텍스트 전용, 이미지 없음)
  // ============================================================

  /// 텍스트 전용 경량 분류 + Intent 1 응답 생성
  Future<_ClassificationResult> _classifyIntent({
    required String screenType,
    required String userMessage,
  }) async {
    final classifierService = _getClassifierService();
    final prompt = _buildClassificationPrompt(
      screenType: screenType,
      userMessage: userMessage,
    );

    final startTime = DateTime.now();
    final response = await classifierService.analyzeScreenshots(
      imageBytes: [], // 이미지 없음 — 텍스트 전용
      prompt: prompt,
    );
    final duration = DateTime.now().difference(startTime);
    print('⚡ Stage 1 분류 소요 시간: ${duration.inMilliseconds}ms');

    final jsonString = _extractJson(response);
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

    return _ClassificationResult(
      intent: jsonData['intent'] as String? ?? 'explain_reasoning',
      responseText: jsonData['response_text'] as String? ?? '',
    );
  }

  /// 분류 전용 경량 GeminiService (캐싱)
  GeminiService _getClassifierService() {
    if (_classifierService != null) return _classifierService!;
    _classifierService = GeminiService(
      systemInstruction:
          'You are a Korean-speaking intent classifier for a UX evaluation tool. '
          'Output valid JSON only. Classify user messages and respond in Korean.',
      maxOutputTokens: 1024,
    );
    return _classifierService!;
  }

  /// 분류 전용 경량 프롬프트 (이미지/데이터 컨텍스트 없음)
  String _buildClassificationPrompt({
    required String screenType,
    required String userMessage,
  }) {
    final guideText = screenType == 'dr'
        ? _getDRUsageGuide()
        : _getEvalUsageGuide();

    return '''
사용자 메시지를 다음 3가지 인텐트 중 하나로 분류하세요:

- "system_usage": 도구/화면의 사용법을 묻는 질문 (버튼, 네비게이션, 기능 등)
- "explain_reasoning": 분석 결과의 이유나 근거를 묻는 질문 (왜, 어떻게, 무슨 뜻)
- "feedback": 분석 결과를 수정/추가/삭제 요청

분류 규칙:
- 변경/삭제/추가/수정/업데이트 요청 → "feedback"
- 왜/어떻게/무슨 뜻 질문 → "explain_reasoning"
- 버튼/화면/기능/사용법 질문 → "system_usage"
- explain_reasoning과 feedback 중 애매하면 → "explain_reasoning"

system_usage로 분류된 경우, 아래 가이드를 참고하여 response_text에 한국어 답변도 함께 작성하세요.
그 외 인텐트는 response_text를 빈 문자열("")로 출력하세요.

## 시스템 사용 가이드
$guideText

## 사용자 메시지
$userMessage

## 출력 형식 (JSON만 출력, 다른 텍스트 없음)
{"intent": "system_usage"|"explain_reasoning"|"feedback", "response_text": "한국어 답변 (system_usage만) 또는 빈 문자열"}
''';
  }

  String _getDRUsageGuide() {
    return '''
- DR 화면 개요: 업로드된 앱 스크린샷에서 추출된 디자인 요소를 보여주는 화면입니다.
- 모듈 탭: 상단의 탭 버튼(UX Writing, Error Prevention & Forgiveness, Visual Consistency)을 클릭하면 해당 모듈의 분석 결과로 이동합니다.
- 스크린 캐러셀: 좌우 화살표로 여러 스크린의 분석 결과를 넘겨볼 수 있습니다.
- 상세보기: 각 스크린 하단의 평가 박스를 클릭하면 상세 모달이 열립니다.
- AI 도우미: 오른쪽 채팅창에서 DR 데이터에 대해 질문하거나 수정을 요청할 수 있습니다.
- 다운로드: 우측 하단의 녹색 다운로드 버튼으로 DR 결과를 JSON 파일로 저장할 수 있습니다.
- 다음 단계: 우측 하단의 파란색 화살표 버튼을 클릭하면 UX 이슈 평가(Evaluation) 단계로 이동합니다.''';
  }

  String _getEvalUsageGuide() {
    return '''
- Evaluation 화면 개요: DR 단계에서 추출된 디자인 요소를 바탕으로 발견된 UX 이슈를 보여주는 화면입니다.
- 모듈 탭: 상단의 탭 버튼(UX Writing, Error Prevention & Forgiveness, Visual Consistency)을 클릭하면 해당 모듈의 이슈로 이동합니다.
- 스크린 캐러셀: 좌우 화살표로 여러 스크린의 이슈를 넘겨볼 수 있습니다.
- 이슈 상세보기: 각 스크린 하단의 이슈 요약을 클릭하면 상세 모달이 열립니다.
- 이슈 선택: 상세 모달에서 개별 이슈를 클릭하면 선택/해제됩니다. 선택된 이슈는 AI 도우미에게 피드백을 줄 때 대상이 됩니다.
- AI 도우미: 오른쪽 채팅창에서 이슈에 대해 질문하거나 수정을 요청할 수 있습니다. 이슈를 선택한 상태에서 질문하면 해당 이슈에 대해서만 답변합니다.
- 다운로드: 우측 하단의 녹색 다운로드 버튼으로 이슈 결과를 JSON 파일로 저장할 수 있습니다.''';
  }

  /// DR 화면 피드백 처리 (Intent 3)
  AIAssistantResponse _handleDRFeedback(
    Map<String, dynamic> jsonData,
    String responseText,
  ) {
    final drDataJson = jsonData['dr_data'] as Map<String, dynamic>?;
    if (drDataJson == null) {
      print('⚠️  dr_data 필드 없음 — 텍스트 응답만 반환');
      return AIAssistantResponse(
        intent: 'feedback',
        responseText: responseText.isNotEmpty
            ? responseText
            : 'DR 업데이트 데이터를 생성하지 못했습니다.',
      );
    }

    try {
      // 배열 응답 처리 (Gemini가 간혹 배열로 응답)
      var data = drDataJson;
      if (data['screens'] is! List && drDataJson.keys.length == 1) {
        final firstValue = drDataJson.values.first;
        if (firstValue is List) {
          data = {'screens': firstValue};
        }
      }

      final updatedDR = DRResult.fromJson(data);
      print('✅ DR 업데이트 성공: ${updatedDR.screens.length}개 화면');

      return AIAssistantResponse(
        intent: 'feedback',
        responseText: responseText.isNotEmpty
            ? responseText
            : 'DR이 업데이트되었습니다.',
        updatedDR: updatedDR,
      );
    } catch (e) {
      print('❌ DR 파싱 실패: $e');
      return AIAssistantResponse(
        intent: 'feedback',
        responseText: 'DR 업데이트 파싱 중 오류가 발생했습니다: $e',
      );
    }
  }

  /// Evaluation 화면 피드백 처리 (Intent 3)
  AIAssistantResponse _handleEvalFeedback(
    Map<String, dynamic> jsonData,
    String responseText,
    int agentNumber,
  ) {
    try {
      // 이슈 파싱
      final problems = jsonData['problems'] as List? ?? [];
      final issues = problems.map((p) {
        final map = p as Map<String, dynamic>;
        switch (agentNumber) {
          case 1:
            return UXWritingIssue.fromJson(map);
          case 2:
            return ErrorPreventionIssue.fromJson(map);
          case 3:
            return VisualConsistencyIssue.fromJson(map);
          default:
            return UXWritingIssue.fromJson(map);
        }
      }).toList();

      // 변경 내용 파싱
      final changes = (jsonData['changes'] as List? ?? []).map((c) {
        final map = c as Map<String, dynamic>;
        return FeedbackChange(
          issueId: map['issue_id'] as String? ?? '',
          action: map['action'] as String? ?? 'unchanged',
          summary: map['summary'] as String? ?? '',
        );
      }).toList();

      final feedbackResult = FeedbackResult(
        updatedIssues: issues,
        changes: changes,
      );

      print('✅ 이슈 업데이트 성공: ${issues.length}개 이슈, ${changes.length}개 변경사항');

      return AIAssistantResponse(
        intent: 'feedback',
        responseText: responseText.isNotEmpty
            ? responseText
            : feedbackResult.buildChangeSummary(),
        feedbackResult: feedbackResult,
      );
    } catch (e) {
      print('❌ 이슈 파싱 실패: $e');
      return AIAssistantResponse(
        intent: 'feedback',
        responseText: '이슈 업데이트 파싱 중 오류가 발생했습니다: $e',
      );
    }
  }

  // ============================================================
  // 프롬프트 생성
  // ============================================================

  Future<String> _buildPrompt({
    required String screenType,
    required int agentNumber,
    required String userMessage,
    DRResult? drData,
    List<UXIssue>? targetIssues,
    List<UXIssue>? selectedIssues,
    MIAResult? miaData,
    String? issueIdPrefix,
  }) async {
    final agentName = _agentNames[agentNumber - 1];
    final drJson = drData != null
        ? jsonEncode(drData.screens.map((s) => s.toJson()).toList())
        : '없음';
    final miaContext = miaData != null
        ? _formatMIAContext(miaData)
        : '없음';

    if (screenType == 'dr') {
      final template = await rootBundle.loadString(
        'lib/prompts/AIAssistant_user_dr.md',
      );
      return template
          .replaceAll(r'$AGENT_NUMBER$', agentNumber.toString())
          .replaceAll(r'$AGENT_NAME$', agentName)
          .replaceAll(r'$DR_DATA$', drJson)
          .replaceAll(r'$MIA_CONTEXT$', miaContext)
          .replaceAll(r'$USER_MESSAGE$', userMessage);
    } else {
      final template = await rootBundle.loadString(
        'lib/prompts/AIAssistant_user_eval.md',
      );
      final issuesJson = targetIssues != null
          ? jsonEncode(targetIssues.map((i) => i.toJson()).toList())
          : '없음';
      final selectedJson = selectedIssues != null && selectedIssues.isNotEmpty
          ? jsonEncode(selectedIssues.map((i) => i.toJson()).toList())
          : '없음';

      return template
          .replaceAll(r'$AGENT_NUMBER$', agentNumber.toString())
          .replaceAll(r'$AGENT_NAME$', agentName)
          .replaceAll(r'$DR_DATA$', drJson)
          .replaceAll(r'$ISSUES$', issuesJson)
          .replaceAll(r'$SELECTED_ISSUES$', selectedJson)
          .replaceAll(r'$MIA_CONTEXT$', miaContext)
          .replaceAll(r'$USER_MESSAGE$', userMessage)
          .replaceAll(r'$ID_PREFIX$', issueIdPrefix ?? 'ISSUE');
    }
  }

  // ============================================================
  // GeminiService 초기화
  // ============================================================

  Future<GeminiService> _getGeminiService({MIAResult? miaData}) async {
    final hasMIA = miaData != null;
    if (_geminiService != null && _lastMIAState == hasMIA) {
      return _geminiService!;
    }

    final systemPrompt = await rootBundle.loadString(
      'lib/prompts/AIAssistant_system.md',
    );

    final fullSystemInstruction = hasMIA
        ? _appendMIAToSystem(systemPrompt, miaData)
        : systemPrompt;

    _geminiService = GeminiService(systemInstruction: fullSystemInstruction);
    _lastMIAState = hasMIA;

    return _geminiService!;
  }

  String _appendMIAToSystem(String systemPrompt, MIAResult miaData) {
    final buffer = StringBuffer(systemPrompt);
    buffer.writeln('\n---\n');
    buffer.writeln(
      'Consider the following MIA results as additional context for your responses.',
    );
    buffer.writeln();

    if (miaData.evaluationContext != null) {
      buffer.writeln('Evaluation Context (from MIA):');
      buffer.writeln(
        '- Evaluation Scope: ${miaData.evaluationContext!.evaluationScope}',
      );
      buffer.writeln(
        '- Special Evaluation Notes: ${miaData.evaluationContext!.specialEvaluationNotes}',
      );
      buffer.writeln();
    }

    buffer.writeln('Usage Context (from MIA):');
    buffer.writeln('- Target User: ${miaData.usageContext.targetUser}');
    buffer.writeln(
      '- Usage Environment: ${miaData.usageContext.usageEnvironment}',
    );
    buffer.writeln('- User Goal: ${miaData.usageContext.userGoal}');
    buffer.writeln('- Task Scenario: ${miaData.usageContext.taskScenario}');
    buffer.writeln();

    buffer.writeln('Screen Purposes (from MIA):');
    for (var screen in miaData.screenPurposes) {
      buffer.writeln('- ${screen.screenId}: ${screen.purpose}');
    }

    return buffer.toString();
  }

  String _formatMIAContext(MIAResult miaData) {
    final buffer = StringBuffer();

    if (miaData.evaluationContext != null) {
      buffer.writeln('Evaluation Context:');
      buffer.writeln(
        '- Evaluation Scope: ${miaData.evaluationContext!.evaluationScope}',
      );
      buffer.writeln(
        '- Special Notes: ${miaData.evaluationContext!.specialEvaluationNotes}',
      );
      buffer.writeln();
    }

    buffer.writeln('Usage Context:');
    buffer.writeln('- Target User: ${miaData.usageContext.targetUser}');
    buffer.writeln(
      '- Usage Environment: ${miaData.usageContext.usageEnvironment}',
    );
    buffer.writeln('- User Goal: ${miaData.usageContext.userGoal}');
    buffer.writeln('- Task Scenario: ${miaData.usageContext.taskScenario}');
    buffer.writeln();

    buffer.writeln('Screen Purposes:');
    for (var screen in miaData.screenPurposes) {
      buffer.writeln('- ${screen.screenId}: ${screen.purpose}');
    }

    return buffer.toString();
  }

  // ============================================================
  // JSON 추출 유틸리티
  // ============================================================

  String _extractJson(String content) {
    // ```json ... ``` 형식
    if (content.contains('```json')) {
      return content.split('```json')[1].split('```')[0].trim();
    }

    // ``` ... ``` 형식
    if (content.contains('```')) {
      return content.split('```')[1].split('```')[0].trim();
    }

    // { ... } 형식 — 중괄호 균형 맞추기
    final start = content.indexOf('{');
    if (start != -1) {
      int braceCount = 0;
      int end = start;
      for (int i = start; i < content.length; i++) {
        if (content[i] == '{') braceCount++;
        if (content[i] == '}') braceCount--;
        if (braceCount == 0) {
          end = i;
          break;
        }
      }
      if (braceCount == 0 && end > start) {
        return content.substring(start, end + 1).trim();
      }
    }

    return content.trim();
  }
}
