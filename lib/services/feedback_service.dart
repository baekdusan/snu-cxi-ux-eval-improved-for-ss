import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'gemini_service.dart';
import '../models/ux_issue_result.dart';
import '../models/MIA_result.dart';
import '../models/DR_result.dart';

/// FeedbackService
///
/// 사용자 피드백을 반영하여 UX 이슈를 개선하는 서비스입니다.
/// Gemini API에 기존 이슈 + 사용자 코멘트를 전달하여
/// 수정/삭제/추가된 이슈와 변경 내용 요약을 반환합니다.
class FeedbackService {
  GeminiService? _geminiService;
  bool? _lastMIAState;

  /// 사용자 피드백을 반영하여 UX 이슈를 개선
  ///
  /// Returns: FeedbackResult (업데이트된 이슈 + 변경 내용 요약)
  Future<FeedbackResult> refineFeedback({
    required int agentNumber,
    required List<Uint8List> imageBytes,
    required DRResult drData,
    required List<UXIssue> targetIssues,
    required String userComment,
    required String issueIdPrefix,
    MIAResult? miaData,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  [Feedback] Agent $agentNumber 피드백 처리 시작 💬              ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('📊 입력 요약:');
    print('   🖼️  이미지: ${imageBytes.length}개');
    print('   📋 DR 데이터: ${drData.screens.length}개 화면');
    print('   🐛 대상 이슈: ${targetIssues.length}개');
    print('   🔧 MIA 컨텍스트: ${miaData != null ? "있음" : "없음"}');
    print('   🏷️  ID Prefix: $issueIdPrefix');
    print('💬 사용자 코멘트: $userComment');

    // 대상 이슈 상세 로깅
    print('\n📋 대상 이슈 목록:');
    for (final issue in targetIssues) {
      print('   ─ ${issue.issueId} [${issue.screenId}]: ${issue.problemDescription.length > 80 ? '${issue.problemDescription.substring(0, 80)}...' : issue.problemDescription}');
    }

    // MIA 컨텍스트 로깅
    if (miaData != null) {
      print('\n🔧 MIA 컨텍스트:');
      print('   - Target User: ${miaData.usageContext.targetUser}');
      print('   - User Goal: ${miaData.usageContext.userGoal}');
      print('   - Task Scenario: ${miaData.usageContext.taskScenario}');
      if (miaData.evaluationContext != null) {
        print('   - Eval Scope: ${miaData.evaluationContext!.evaluationScope}');
      }
    }

    // 1. GeminiService 초기화 (System Instruction 포함)
    final service = await _getGeminiService(miaData: miaData);

    // 2. User Prompt 생성
    final prompt = await _buildFeedbackPrompt(
      drData: drData,
      targetIssues: targetIssues,
      userComment: userComment,
      issueIdPrefix: issueIdPrefix,
    );

    // 이슈 JSON 로깅 (프롬프트에 실제로 주입되는 데이터)
    final issuesJsonForLog = jsonEncode(targetIssues.map((i) => i.toJson()).toList());
    print('\n📦 프롬프트에 주입된 이슈 JSON:');
    print(issuesJsonForLog.length > 1000
        ? '${issuesJsonForLog.substring(0, 1000)}...'
        : issuesJsonForLog);

    // 최종 프롬프트 로깅
    print('\n📝 최종 User Prompt (처음 500자):');
    print(prompt.length > 500 ? '${prompt.substring(0, 500)}...' : prompt);
    print('📝 User Prompt 전체 길이: ${prompt.length}자');

    // 3. Gemini API 호출
    final startTime = DateTime.now();
    final response = await service.analyzeScreenshots(
      imageBytes: imageBytes,
      prompt: prompt,
    );
    final duration = DateTime.now().difference(startTime);
    print('⏱️  피드백 처리 소요 시간: ${duration.inSeconds}초');

    // Gemini 응답 로깅
    print('\n📤 Gemini 응답 (처음 500자):');
    print('${response.length > 500 ? '${response.substring(0, 500)}...' : response}');
    print('📤 응답 전체 길이: ${response.length}자');

    // 4. JSON 파싱
    final jsonString = _extractJson(response);
    final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

    // 파싱된 JSON 키 로깅
    print('\n🔑 파싱된 JSON 최상위 키: ${jsonData.keys.toList()}');
    final problemCount = (jsonData['problems'] as List?)?.length ?? 0;
    final changeCount = (jsonData['changes'] as List?)?.length ?? 0;
    print('   problems: $problemCount개, changes: $changeCount개');

    // 5. 이슈 파싱
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

    // 6. 변경 내용 파싱
    final changes = (jsonData['changes'] as List? ?? []).map((c) {
      final map = c as Map<String, dynamic>;
      return FeedbackChange(
        issueId: map['issue_id'] as String? ?? '',
        action: map['action'] as String? ?? 'unchanged',
        summary: map['summary'] as String? ?? '',
      );
    }).toList();

    print('✅ 피드백 처리 완료: ${issues.length}개 이슈, ${changes.length}개 변경사항');

    return FeedbackResult(
      updatedIssues: issues,
      changes: changes,
    );
  }

  Future<GeminiService> _getGeminiService({MIAResult? miaData}) async {
    final hasMIA = miaData != null;
    if (_geminiService != null && _lastMIAState == hasMIA) {
      return _geminiService!;
    }

    final systemPrompt =
        await rootBundle.loadString('lib/prompts/Feedback_system.md');

    final fullSystemInstruction =
        hasMIA ? _appendMIAContext(systemPrompt, miaData) : systemPrompt;

    _geminiService = GeminiService(systemInstruction: fullSystemInstruction);
    _lastMIAState = hasMIA;

    return _geminiService!;
  }

  String _appendMIAContext(String systemPrompt, MIAResult miaData) {
    final buffer = StringBuffer(systemPrompt);
    buffer.writeln('\n---\n');
    buffer.writeln(
        'Consider the following MIA results as context for evaluating and refining UX issues.');
    buffer.writeln();

    if (miaData.evaluationContext != null) {
      buffer.writeln('Evaluation Context (from MIA):');
      buffer.writeln(
          '- Evaluation Scope: ${miaData.evaluationContext!.evaluationScope}');
      buffer.writeln(
          '- Special Evaluation Notes: ${miaData.evaluationContext!.specialEvaluationNotes}');
      buffer.writeln();
    }

    buffer.writeln('Usage Context (from MIA):');
    buffer.writeln('- Target User: ${miaData.usageContext.targetUser}');
    buffer.writeln(
        '- Usage Environment: ${miaData.usageContext.usageEnvironment}');
    buffer.writeln('- User Goal: ${miaData.usageContext.userGoal}');
    buffer.writeln('- Task Scenario: ${miaData.usageContext.taskScenario}');
    buffer.writeln();

    buffer.writeln('Screen Purposes (from MIA):');
    for (var screen in miaData.screenPurposes) {
      buffer.writeln('- ${screen.screenId}: ${screen.purpose}');
    }

    return buffer.toString();
  }

  Future<String> _buildFeedbackPrompt({
    required DRResult drData,
    required List<UXIssue> targetIssues,
    required String userComment,
    required String issueIdPrefix,
  }) async {
    final template =
        await rootBundle.loadString('lib/prompts/Feedback_user.md');

    // DR 데이터 JSON
    final drJson = jsonEncode(
      drData.screens.map((s) => s.toJson()).toList(),
    );

    // 대상 이슈 JSON
    final issuesJson = jsonEncode(
      targetIssues.map((i) => i.toJson()).toList(),
    );

    return template
        .replaceAll(r'$DR_DATA$', drJson)
        .replaceAll(r'$ISSUES$', issuesJson)
        .replaceAll(r'$USER_COMMENT$', userComment)
        .replaceAll(r'$ID_PREFIX$', issueIdPrefix);
  }

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

/// 피드백 처리 결과
class FeedbackResult {
  final List<UXIssue> updatedIssues;
  final List<FeedbackChange> changes;

  FeedbackResult({required this.updatedIssues, required this.changes});

  /// 변경 내용 요약 텍스트 생성 (채팅 메시지용)
  String buildChangeSummary() {
    if (changes.isEmpty) return '변경 사항이 없습니다.';

    final modified =
        changes.where((c) => c.action == 'modified').toList();
    final removed = changes.where((c) => c.action == 'removed').toList();
    final added = changes.where((c) => c.action == 'added').toList();

    final buffer = StringBuffer();

    final totalChanged = modified.length + removed.length + added.length;
    if (totalChanged == 0) {
      buffer.writeln('피드백을 검토했지만 변경이 필요한 이슈가 없습니다.');
      return buffer.toString().trim();
    }

    buffer.writeln('$totalChanged개 이슈 업데이트 완료');
    buffer.writeln();

    for (final change in changes) {
      if (change.action == 'unchanged') continue;
      final icon = switch (change.action) {
        'modified' => '✏️',
        'removed' => '🗑️',
        'added' => '➕',
        _ => '•',
      };
      buffer.writeln('$icon ${change.issueId}: ${change.summary}');
    }

    return buffer.toString().trim();
  }
}

/// 개별 이슈 변경 정보
class FeedbackChange {
  final String issueId;
  final String action; // "modified" | "removed" | "added" | "unchanged"
  final String summary;

  FeedbackChange({
    required this.issueId,
    required this.action,
    required this.summary,
  });
}
