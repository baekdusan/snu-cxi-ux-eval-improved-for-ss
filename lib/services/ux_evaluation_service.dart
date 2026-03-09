import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'gemini_service.dart';
import '../models/ux_issue_result.dart';
import '../models/MIA_result.dart';
import '../models/DR_result.dart';
import '../references/agent1_text_heuristics.dart';
import '../references/agent2_error_heuristics.dart';
import '../references/agent3_visual_heuristics.dart';

/// UXEvaluationService
///
/// 3개 에이전트의 E (Evaluation) 단계를 담당하는 서비스입니다.
/// DR (Design Representation) 결과를 바탕으로 Heuristic을 적용하여
/// 실제 UX 문제점을 식별하고 개선 방안을 제시합니다.
///
/// 🔹 주요 기능:
/// - Agent 1 E: UXWriting 이슈 평가
/// - Agent 2 E: Error Prevention & Forgiveness 이슈 평가
/// - Agent 3 E: Visual Consistency 이슈 평가
///
/// 모든 에이전트가 동일한 평가 파이프라인을 사용합니다:
/// 1. DR 결과 + Heuristic 항목 로드
/// 2. 휴리스틱별 개별 프롬프트 생성 (System Prompt + User Prompt)
/// 3. 5개씩 배치로 Gemini API 병렬 호출
/// 4. JSON 응답 파싱 → UXIssueResult 반환
class UXEvaluationService {
  // Agent별 전용 GeminiService (system instruction 포함, lazy 초기화)
  GeminiService? _agent1GeminiService;
  GeminiService? _agent2GeminiService;
  GeminiService? _agent3GeminiService;

  // 마지막 MIA 유무 상태 (캐시 무효화용)
  bool? _lastMIAState1;
  bool? _lastMIAState2;
  bool? _lastMIAState3;

  /// Agent별 전용 GeminiService lazy 초기화
  Future<GeminiService> _getAgentGeminiService({
    required int agentNumber,
    required String systemPromptFile,
    MIAResult? analysisData,
  }) async {
    final hasMIA = analysisData != null;

    // 캐시된 서비스 반환 또는 새로 생성
    GeminiService? cached;
    bool? lastState;
    switch (agentNumber) {
      case 1:
        cached = _agent1GeminiService;
        lastState = _lastMIAState1;
      case 2:
        cached = _agent2GeminiService;
        lastState = _lastMIAState2;
      case 3:
        cached = _agent3GeminiService;
        lastState = _lastMIAState3;
    }

    if (cached != null && lastState == hasMIA) {
      return cached;
    }

    // 새로 생성
    final systemPrompt = await _loadSystemPrompt(systemPromptFile);
    final fullSystemInstruction = hasMIA
        ? _appendMIAContext(systemPrompt, analysisData)
        : systemPrompt;

    final service = GeminiService(systemInstruction: fullSystemInstruction);

    switch (agentNumber) {
      case 1:
        _agent1GeminiService = service;
        _lastMIAState1 = hasMIA;
      case 2:
        _agent2GeminiService = service;
        _lastMIAState2 = hasMIA;
      case 3:
        _agent3GeminiService = service;
        _lastMIAState3 = hasMIA;
    }

    print('✅ [Agent $agentNumber] System instruction 파일에서 로드 완료');
    print('   📄 파일: $systemPromptFile');
    print('   🔧 MIA Context: ${hasMIA ? "포함" : "없음"}');

    return service;
  }

  /// System Prompt 파일 로드
  Future<String> _loadSystemPrompt(String filePath) async {
    try {
      return await rootBundle.loadString(filePath);
    } catch (e) {
      print('⚠️ $filePath 로드 실패: $e');
      throw Exception('$filePath is required but not found');
    }
  }

  /// MIA Context를 System Instruction에 추가
  String _appendMIAContext(String systemPrompt, MIAResult miaData) {
    final buffer = StringBuffer(systemPrompt);
    buffer.writeln('\n---\n');
    buffer.writeln('Consider the following MIA results as the primary context for UX evaluation.');
    buffer.writeln('You must evaluate from the perspectives of evaluation context, usage context, and screen purposes.');
    buffer.writeln('Always align your reasoning with the stated evaluation scope.');
    buffer.writeln('Interpret user needs and constraints from the usage context, not from assumptions.');
    buffer.writeln('Prioritize task success, clarity, and fitness for the intended screen purpose.');
    buffer.writeln('Do not evaluate text elements in isolation.');
    buffer.writeln('Use the surrounding screens and the full task scenario to judge whether the text effectively supports user understanding and task completion.');
    buffer.writeln();

    // 1. Evaluation Context (if available)
    if (miaData.evaluationContext != null) {
      buffer.writeln('Evaluation Context (from MIA):');
      buffer.writeln('- Evaluation Scope: ${miaData.evaluationContext!.evaluationScope}');
      buffer.writeln('- Special Evaluation Notes: ${miaData.evaluationContext!.specialEvaluationNotes}');
      buffer.writeln();
    }

    // 2. Usage Context
    buffer.writeln('Usage Context (from MIA):');
    buffer.writeln('- Target User: ${miaData.usageContext.targetUser}');
    buffer.writeln('- Usage Environment: ${miaData.usageContext.usageEnvironment}');
    buffer.writeln('- User Goal: ${miaData.usageContext.userGoal}');
    buffer.writeln('- Task Scenario: ${miaData.usageContext.taskScenario}');
    buffer.writeln();

    // 3. Screen Purposes
    buffer.writeln('Screen Purposes (from MIA):');
    for (var screen in miaData.screenPurposes) {
      buffer.writeln('- ${screen.screenId}: ${screen.purpose}');
    }

    return buffer.toString();
  }

  // ============================================================
  // Agent 1 E: UX Writing Evaluation
  // ============================================================

  Future<UXIssueResult> evaluateUXWritingIssues({
    required List<String> base64Images,
    required DRResult textElementData,
    MIAResult? analysisData,
  }) async {
    return _evaluateWithHeuristics(
      agentNumber: 1,
      agentName: 'UXWriting',
      agentType: AgentType.uxWriting,
      issueIdPrefix: 'UX-WRITING',
      systemPromptFile: 'lib/prompts/Agent1_E_system.md',
      userPromptFile: 'lib/prompts/Agent1_E_prompt.md',
      heuristics: agent1TextHeuristics,
      base64Images: base64Images,
      drData: textElementData,
      analysisData: analysisData,
    );
  }

  // ============================================================
  // Agent 2 E: Error Prevention & Forgiveness Evaluation
  // ============================================================

  Future<UXIssueResult> evaluateErrorPreventionIssues({
    required List<String> base64Images,
    required DRResult drData,
    MIAResult? analysisData,
  }) async {
    return _evaluateWithHeuristics(
      agentNumber: 2,
      agentName: 'Error Prevention',
      agentType: AgentType.errorPrevention,
      issueIdPrefix: 'ERROR-PREV',
      systemPromptFile: 'lib/prompts/Agent2_E_system.md',
      userPromptFile: 'lib/prompts/Agent2_E_prompt.md',
      heuristics: agent2ErrorHeuristics,
      base64Images: base64Images,
      drData: drData,
      analysisData: analysisData,
    );
  }

  // ============================================================
  // Agent 3 E: Visual Consistency Evaluation
  // ============================================================

  Future<UXIssueResult> evaluateVisualConsistencyIssues({
    required List<String> base64Images,
    required DRResult drData,
    MIAResult? analysisData,
  }) async {
    return _evaluateWithHeuristics(
      agentNumber: 3,
      agentName: 'Visual Consistency',
      agentType: AgentType.visualConsistency,
      issueIdPrefix: 'VISUAL-CONSIST',
      systemPromptFile: 'lib/prompts/Agent3_E_system.md',
      userPromptFile: 'lib/prompts/Agent3_E_prompt.md',
      heuristics: agent3VisualHeuristics,
      base64Images: base64Images,
      drData: drData,
      analysisData: analysisData,
    );
  }

  // ============================================================
  // 공통 Heuristic 기반 평가 메서드
  // ============================================================

  /// 모든 에이전트가 공유하는 Evaluation 파이프라인
  ///
  /// 1. 휴리스틱 항목을 평탄화
  /// 2. 5개씩 배치로 Gemini API 병렬 호출
  /// 3. 결과 병합 및 정렬
  Future<UXIssueResult> _evaluateWithHeuristics({
    required int agentNumber,
    required String agentName,
    required AgentType agentType,
    required String issueIdPrefix,
    required String systemPromptFile,
    required String userPromptFile,
    required List<HeuristicCategory> heuristics,
    required List<String> base64Images,
    required DRResult drData,
    MIAResult? analysisData,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  [Agent $agentNumber E] $agentName 이슈 평가 시작 📝                 ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('📊 입력: 스크린샷 ${base64Images.length}개, DR 데이터 ${drData.screens.length}개 화면');
    print('🔧 프롬프트 구조: System Instruction (역할/규칙) + User Prompt (휴리스틱/데이터)');

    // Base64 → Binary 변환
    final imageBytes = base64Images.map((base64String) {
      return base64Decode(base64String);
    }).toList();

    // ========================================
    // 휴리스틱 평탄화
    // ========================================
    final allHeuristicItems = <(HeuristicCategory, HeuristicItem)>[];
    for (var category in heuristics) {
      for (var item in category.items) {
        allHeuristicItems.add((category, item));
      }
    }

    print('📋 총 ${allHeuristicItems.length}개 휴리스틱 평가 (${(allHeuristicItems.length / 5).ceil()}개 배치)\n');

    // 최종 결과 리스트
    List<UXIssue> allIssues = [];
    int issueCounter = 1;
    final overallStartTime = DateTime.now();

    // ========================================
    // 5개씩 배치로 병렬 처리
    // ========================================
    for (int i = 0; i < allHeuristicItems.length; i += 5) {
      final batchEnd = (i + 5 < allHeuristicItems.length) ? i + 5 : allHeuristicItems.length;
      final batch = allHeuristicItems.sublist(i, batchEnd);
      final batchNumber = (i ~/ 5) + 1;

      print('🔄 배치 $batchNumber/${(allHeuristicItems.length / 5).ceil()} 처리 중...');
      final batchStartTime = DateTime.now();

      // 5개 항목 동시 평가
      final batchResults = await Future.wait(
        batch.map((tuple) async {
          final category = tuple.$1;
          final item = tuple.$2;

          try {
            // 1. 프롬프트 생성 ($HEURISTIC$ 치환)
            final prompt = await _buildHeuristicSpecificPrompt(
              userPromptFile: userPromptFile,
              heuristicCategory: category.category,
              heuristicItem: item,
              drData: drData,
            );

            // 2. Gemini API 호출 (Agent 전용 서비스 사용)
            final agentService = await _getAgentGeminiService(
              agentNumber: agentNumber,
              systemPromptFile: systemPromptFile,
              analysisData: analysisData,
            );
            final content = await agentService.analyzeScreenshots(
              imageBytes: imageBytes,
              prompt: prompt,
            );

            // 3. JSON 추출 및 파싱
            final jsonString = _extractJson(content);
            final jsonData = jsonDecode(jsonString);
            final problems = jsonData['problems'] as List;

            // 4. UXIssue 객체 생성 — Agent별 클래스 사용
            return problems.map((problem) {
              if (agentType == AgentType.visualConsistency) {
                return VisualConsistencyIssue.fromJson(
                  problem,
                  categoryOverride: category.category,
                  heuristicOverride: item.title,
                );
              } else if (agentType == AgentType.errorPrevention) {
                return ErrorPreventionIssue.fromJson(
                  problem,
                  categoryOverride: category.category,
                  heuristicOverride: item.title,
                );
              } else {
                return UXWritingIssue.fromJson(
                  problem,
                  categoryOverride: category.category,
                  heuristicOverride: item.title,
                );
              }
            }).toList();
          } catch (e) {
            print('❌ 오류 [${category.category}/${item.title}]: $e');
            return <UXIssue>[]; // 빈 리스트 반환
          }
        }),
      );

      // 배치 결과 병합 + ID 부여 (copyWithId로 타입 보존)
      for (var issueList in batchResults) {
        for (var issue in issueList) {
          allIssues.add(issue.copyWithId('$issueIdPrefix-${issueCounter++}'));
        }
      }

      final batchDuration = DateTime.now().difference(batchStartTime);
      print('✅ 배치 $batchNumber 완료 (${batchDuration.inSeconds}초, 누적 이슈: ${allIssues.length}개)');
    }

    // ========================================
    // 이슈 정렬: screen_id → textElementId 오름차순
    // ========================================
    allIssues.sort((a, b) {
      final screenA = int.tryParse(a.screenId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final screenB = int.tryParse(b.screenId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (screenA != screenB) return screenA.compareTo(screenB);
      final aId = (a is UXWritingIssue) ? a.textElementId
                : (a is ErrorPreventionIssue) ? (a.elementId ?? 0)
                : (a is VisualConsistencyIssue) ? (a.elementId ?? 0) : 0;
      final bId = (b is UXWritingIssue) ? b.textElementId
                : (b is ErrorPreventionIssue) ? (b.elementId ?? 0)
                : (b is VisualConsistencyIssue) ? (b.elementId ?? 0) : 0;
      return aId.compareTo(bId);
    });

    final overallDuration = DateTime.now().difference(overallStartTime);
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  [Agent $agentNumber E] 평가 완료 ✅ 이슈: ${allIssues.length}개, 소요: ${overallDuration.inMinutes}분 ${overallDuration.inSeconds % 60}초 ║');
    print('╚════════════════════════════════════════════════════════════╝\n');

    return UXIssueResult(uxIssues: allIssues);
  }

  // ============================================================
  // 프롬프트 생성 유틸리티
  // ============================================================

  /// User Prompt 템플릿을 파일에서 로드
  Future<String> _loadUserPrompt(String filePath) async {
    try {
      return await rootBundle.loadString(filePath);
    } catch (e) {
      print('⚠️ $filePath 로드 실패: $e');
      throw Exception('$filePath is required but not found');
    }
  }

  /// 개별 휴리스틱을 위한 User Prompt 생성
  ///
  /// $HEURISTIC$와 $DR_DATA$ placeholder를 치환합니다.
  Future<String> _buildHeuristicSpecificPrompt({
    required String userPromptFile,
    required String heuristicCategory,
    required HeuristicItem heuristicItem,
    required DRResult drData,
  }) async {
    // 1. 프롬프트 템플릿 파일 로드
    final promptTemplate = await _loadUserPrompt(userPromptFile);

    // 2. 휴리스틱 섹션 생성
    final heuristicSection = '''
Category: $heuristicCategory

Heuristic: ${heuristicItem.title}

Descriptions:
${heuristicItem.descriptions.map((d) => '- $d').join('\n')}

${heuristicItem.examples.isNotEmpty ? '''
Examples:
${heuristicItem.examples.map((e) => '- $e').join('\n')}
''' : ''}
${heuristicItem.additional_info.isNotEmpty ? '''
Additional Information:
${heuristicItem.additional_info.map((a) => '- $a').join('\n')}
''' : ''}'''.trim();

    // 3. DR 데이터를 JSON으로 변환
    final drJson = jsonEncode(drData.toJson());

    // 4. 템플릿의 placeholder 치환
    return promptTemplate
        .replaceAll('\$HEURISTIC\$', heuristicSection)
        .replaceAll('\$DR_DATA\$', drJson);
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Gemini 응답에서 JSON 부분만 추출
  String _extractJson(String content) {
    if (content.contains('```json')) {
      return content.split('```json')[1].split('```')[0].trim();
    }
    if (content.contains('```')) {
      return content.split('```')[1].split('```')[0].trim();
    }
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start != -1 && end != -1) {
      return content.substring(start, end + 1);
    }
    return content.trim();
  }
}
