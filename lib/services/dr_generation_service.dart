import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'gemini_service.dart';
import '../models/DR_result.dart';
import '../models/MIA_result.dart';
import 'debug_logger.dart';

/// DRGenerationService
///
/// 3개 에이전트의 DR (Design Representation) 단계를 담당하는 서비스입니다.
/// 스크린샷에서 각 에이전트가 담당하는 디자인 요소를 추출합니다.
///
/// 🔹 주요 기능:
/// - Agent 1 DR: UXWriting 텍스트 요소 추출
/// - Agent 2 DR: Error Prevention & Forgiveness
/// - Agent 3 DR: Visual Consistency
/// 🔹 데이터 흐름:
/// 1. 스크린샷 Base64 인코딩
/// 2. 프롬프트 로드
/// 3. Gemini API 호출 (JSON 모드) - 모든 스크린샷을 한 번에 전송
/// 4. JSON 응답 파싱 (배열 응답 처리 포함)
/// 5. DRResult 객체 반환
class DRGenerationService {
  final GeminiService _geminiService = GeminiService();

  // ============================================================
  // Agent 1 DR: Text Element Extraction (UX Writing)
  // ============================================================

  /// Agent 1 DR - UXWriting 텍스트 요소 추출
  Future<DRResult> generateAgent1DR({
    required List<String> base64Images,
    MIAResult? analysisData,
  }) async {
    return _generateDR(
      agentNumber: 1,
      agentName: 'UXWriting',
      base64Images: base64Images,
      analysisData: analysisData,
      promptFilePrefix: 'Agent1',
    );
  }

  // ============================================================
  // Agent 2 DR: Error Prevention & Forgiveness
  // ============================================================

  /// Agent 2 DR - Error Prevention & Forgiveness
  Future<DRResult> generateAgent2DR({
    required List<String> base64Images,
    MIAResult? analysisData,
  }) async {
    return _generateDR(
      agentNumber: 2,
      agentName: 'Error Prevention',
      base64Images: base64Images,
      analysisData: analysisData,
      promptFilePrefix: 'Agent2',
    );
  }

  // ============================================================
  // Agent 3 DR: Visual Consistency
  // ============================================================

  /// Agent 3 DR - Visual Consistency
  Future<DRResult> generateAgent3DR({
    required List<String> base64Images,
    MIAResult? analysisData,
  }) async {
    return _generateDR(
      agentNumber: 3,
      agentName: 'Visual Consistency',
      base64Images: base64Images,
      analysisData: analysisData,
      promptFilePrefix: 'Agent3',
    );
  }

  // ============================================================
  // 공통 DR 생성 메서드
  // ============================================================

  /// 공통 DR 생성 로직
  ///
  /// 모든 에이전트가 동일한 DR 파이프라인을 사용합니다:
  /// 1. 프롬프트 로드 (MIA 모드에 따라 다른 파일)
  /// 2. Gemini API 호출
  /// 3. JSON 파싱 및 DRResult 반환
  Future<DRResult> _generateDR({
    required int agentNumber,
    required String agentName,
    required List<String> base64Images,
    MIAResult? analysisData,
    required String promptFilePrefix,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print(
      '║  [Agent $agentNumber DR] $agentName 분석 시작 📝                     ║',
    );
    print('╚════════════════════════════════════════════════════════════╝');
    print('📥 입력:');
    if (analysisData != null) {
      print('   - MIA Context: 포함 (MIA 평가 데이터)');
      print('   - Context 화면 수: ${analysisData.screenPurposes.length}개');
    } else {
      print('   - MIA Context: 없음 (순수 DR만 수행)');
    }
    print('   - 스크린샷 개수: ${base64Images.length}개\n');

    // DR 프롬프트 로드 (MIA 모드에 따라 다른 프롬프트 사용)
    final prompt = await _loadDRPrompt(promptFilePrefix, analysisData);
    final promptFile = analysisData != null
        ? '${promptFilePrefix}_DR_MIA_prompt.md'
        : '${promptFilePrefix}_DR_prompt.md';
    print('📝 프롬프트 로드 완료:');
    print('   - 프롬프트 타입: Agent $agentNumber DR ($agentName)');
    print('   - 프롬프트 파일: $promptFile');
    print('   - 프롬프트 길이: ${prompt.length} 글자\n');

    // Base64 문자열을 바이너리 데이터로 변환
    final imageBytes = base64Images.map((base64String) {
      return base64Decode(base64String);
    }).toList();
    print('🔄 Base64 → Binary 변환 완료');
    for (var i = 0; i < imageBytes.length; i++) {
      print(
        '   - 이미지 ${i + 1}: ${(imageBytes[i].length / 1024).toStringAsFixed(2)} KB',
      );
    }

    // 디버그 로깅
    DebugLogger.logDRInput(
      agentName: 'Agent $agentNumber ($agentName)',
      screenshotCount: imageBytes.length,
    );

    // Gemini API 호출 (503/일시적 오류 시 최대 3회 재시도)
    const maxRetries = 3;
    String content = '';
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('\n🚀 Gemini API 호출 중... (시도 $attempt/$maxRetries)\n');
        final startTime = DateTime.now();
        content = await _geminiService.analyzeScreenshots(
          imageBytes: imageBytes,
          prompt: prompt,
        );
        final duration = DateTime.now().difference(startTime);
        print('\n✅ Gemini 응답 수신 완료 (시도 $attempt)');
        print('⏱️  소요 시간: ${duration.inSeconds}초 ${duration.inMilliseconds % 1000}ms');
        break; // 성공 시 루프 탈출
      } catch (e) {
        final isTransient = e.toString().contains('503') ||
            e.toString().contains('UNAVAILABLE') ||
            e.toString().contains('429') ||
            e.toString().contains('RESOURCE_EXHAUSTED') ||
            e.toString().contains('cancelled') ||
            e.toString().contains('canceled');
        if (isTransient && attempt < maxRetries) {
          final waitSec = attempt * 3; // 3초, 6초, ...
          print('⚠️  [Agent $agentNumber DR] 일시적 오류 (시도 $attempt/$maxRetries), $waitSec초 후 재시도: $e');
          await Future.delayed(Duration(seconds: waitSec));
        } else {
          print('❌ [Agent $agentNumber DR] 최종 실패 (시도 $attempt/$maxRetries): $e');
          rethrow;
        }
      }
    }
    print('📦 응답 데이터 처리 중...\n');

    // JSON 추출 및 파싱
    final jsonString = _extractJson(content);
    print('✂️  JSON 추출 완료 (${jsonString.length} 글자)\n');

    try {
      print('🔍 JSON 파싱 중...');
      var jsonData = jsonDecode(jsonString);

      // ========================================
      // Gemini 배열 응답 처리 (중요!)
      // ========================================
      if (jsonData is List) {
        print('⚠️  배열 형식 감지...');
        if (jsonData.isNotEmpty && jsonData.first is Map) {
          final firstItem = jsonData.first as Map<String, dynamic>;
          if (firstItem.containsKey('screens')) {
            print('   └─ 첫 번째 요소에서 screens 추출');
            jsonData = firstItem;
          } else {
            print('   └─ {"screens": [...]} 형태로 래핑');
            jsonData = <String, dynamic>{'screens': jsonData};
          }
        }
      }

      final result = DRResult.fromJson(jsonData);

      print('✅ JSON 파싱 성공!');
      print('📊 $agentName 결과:');
      print('   - 분석된 화면 수: ${result.screens.length}개');
      for (var i = 0; i < result.screens.length; i++) {
        final screen = result.screens[i];
        final summary = screen.textElements.isNotEmpty
            ? '${screen.textElements.length}개 텍스트 요소'
            : screen.rawData != null
                ? 'rawData keys: ${screen.rawData!.keys.toList()}'
                : '데이터 없음';
        print('     └─ 화면 ${i + 1} (${screen.screenId}): $summary');
      }
      print('╔════════════════════════════════════════════════════════════╗');
      print(
        '║  [Agent $agentNumber DR] $agentName 분석 완료 ✅                      ║',
      );
      print('╚════════════════════════════════════════════════════════════╝\n');

      return result;
    } catch (e) {
      print('❌ [Agent $agentNumber DR] JSON 파싱 실패: $e');
      final preview = jsonString.length > 200
          ? '${jsonString.substring(0, 200)}...'
          : jsonString;
      print('💀 실패한 JSON 미리보기:\n$preview\n');
      throw Exception(
        'Agent $agentNumber DR parsing failed: $e\n\nJSON Response: $preview',
      );
    }
  }

  // ============================================================
  // 프롬프트 로드 유틸리티
  // ============================================================

  /// DR 프롬프트를 파일에서 로드
  ///
  /// MIA 모드에 따라 다른 프롬프트 파일을 로드합니다:
  /// - MIA 모드: {prefix}_DR_MIA_prompt.md
  /// - MIAx 모드: {prefix}_DR_prompt.md
  Future<String> _loadDRPrompt(String prefix, MIAResult? analysisData) async {
    try {
      final promptFile = analysisData != null
          ? 'lib/prompts/${prefix}_DR_MIA_prompt.md'
          : 'lib/prompts/${prefix}_DR_prompt.md';

      var prompt = await rootBundle.loadString(promptFile);

      // MIA 모드: $MIA results$ 플레이스홀더를 실제 MIA 데이터로 치환
      if (analysisData != null) {
        final miaContext = _formatMIAContextForDR(analysisData);
        prompt = prompt.replaceAll(r'$MIA results$', miaContext);
      }

      return prompt;
    } catch (e) {
      print('⚠️  $prefix DR 프롬프트 로드 실패: $e');
      throw Exception(
        '$prefix DR prompt is required but not found in lib/prompts/',
      );
    }
  }

  /// MIA 결과를 DR 프롬프트용 텍스트로 변환
  String _formatMIAContextForDR(MIAResult miaData) {
    final buffer = StringBuffer();

    // 1. Evaluation Context (if available)
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

    // 2. Usage Context
    buffer.writeln('Usage Context (from MIA):');
    buffer.writeln('- Target User: ${miaData.usageContext.targetUser}');
    buffer.writeln(
      '- Usage Environment: ${miaData.usageContext.usageEnvironment}',
    );
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
  // DR Refinement (Human-in-the-loop)
  // ============================================================

  /// 유저 피드백을 반영하여 DR 데이터를 업데이트
  ///
  /// Human-in-the-loop: MIA 데이터 + 현재 DR + 유저 코멘트 → Gemini → 업데이트된 DR
  Future<DRResult> refineDRWithUserFeedback({
    required int agentNumber,
    required DRResult currentDR,
    required List<Uint8List> imageBytes,
    required String userComment,
    MIAResult? miaResult,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  [Agent $agentNumber DR Refine] 유저 피드백 반영 시작              ║');
    print('╚════════════════════════════════════════════════════════════╝');

    final currentDRJson = jsonEncode(currentDR.toJson());
    final miaContext = miaResult != null ? _formatMIAContextForDR(miaResult) : '없음';

    final agentName = ['UX Writing', 'Error Prevention & Forgiveness', 'Visual Consistency'][agentNumber - 1];
    final prompt = '''
당신은 $agentName 디자인 표현(DR) 분석 전문가입니다.

아래는 현재 앱 화면들에 대한 DR 분석 결과입니다:

=== 현재 DR 데이터 (JSON) ===
$currentDRJson

=== MIA 컨텍스트 ===
$miaContext

=== 유저 피드백 ===
$userComment

위 유저 피드백을 반영하여 DR 데이터를 업데이트해주세요.
- 피드백에서 언급된 항목만 수정하고, 나머지는 그대로 유지하세요.
- 반드시 현재 DR과 동일한 JSON 구조로 출력하세요.
- screens 배열의 모든 화면을 포함해야 합니다.
''';

    print('📝 Refinement 프롬프트 생성 완료 (${prompt.length} 글자)');
    print('📸 이미지 수: ${imageBytes.length}개');

    final content = await _geminiService.analyzeScreenshots(
      imageBytes: imageBytes,
      prompt: prompt,
    );

    final jsonString = _extractJson(content);

    try {
      var jsonData = jsonDecode(jsonString);
      if (jsonData is List) {
        if (jsonData.isNotEmpty && jsonData.first is Map) {
          final firstItem = jsonData.first as Map<String, dynamic>;
          jsonData = firstItem.containsKey('screens')
              ? firstItem
              : <String, dynamic>{'screens': jsonData};
        }
      }
      final result = DRResult.fromJson(jsonData);
      print('✅ DR Refinement 성공! 화면 수: ${result.screens.length}개');
      return result;
    } catch (e) {
      print('❌ DR Refinement JSON 파싱 실패: $e');
      throw Exception('DR Refinement 파싱 실패: $e');
    }
  }

  // ============================================================
  // Utility Methods (유틸리티 메서드)
  // ============================================================

  /// Gemini 응답에서 JSON 부분만 추출
  String _extractJson(String content) {
    // ```json ... ``` 형식
    if (content.contains('```json')) {
      return content.split('```json')[1].split('```')[0].trim();
    }

    // ``` ... ``` 형식
    if (content.contains('```')) {
      return content.split('```')[1].split('```')[0].trim();
    }

    // [ ... ] 형식 (배열 JSON) - 객체보다 먼저 확인
    final arrayStart = content.indexOf('[');
    final arrayEnd = content.lastIndexOf(']');
    if (arrayStart != -1 && arrayEnd != -1 && arrayStart < arrayEnd) {
      final objStart = content.indexOf('{');
      if (arrayStart < objStart || objStart == -1) {
        return content.substring(arrayStart, arrayEnd + 1).trim();
      }
    }

    // { ... } 형식 (객체 JSON) - 중괄호 균형 맞추기
    final start = content.indexOf('{');
    if (start != -1) {
      int braceCount = 0;
      int end = start;

      for (int i = start; i < content.length; i++) {
        if (content[i] == '{') {
          braceCount++;
        } else if (content[i] == '}') {
          braceCount--;
          if (braceCount == 0) {
            end = i;
            break;
          }
        }
      }

      if (braceCount == 0 && end > start) {
        return content.substring(start, end + 1).trim();
      }
    }

    // 추출 실패 시 전체 반환
    return content.trim();
  }
}
