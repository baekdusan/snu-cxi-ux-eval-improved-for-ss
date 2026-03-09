import 'dart:convert';
import 'gemini_service.dart';
import '../models/MIA_result.dart';
import '../constants/MIA_prompt.dart';
import 'debug_logger.dart';


class AnalysisService {
  final GeminiService _geminiService = GeminiService();

  Future<MIAResult> analyzeScreenshots({
    required List<String> images,
    String? evaluationScope,
    String? specialNotes,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║  [AnalysisService] 스크린샷 분석 시작 (MIA)               ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('📊 단계: 스크린샷 → 사용 맥락 + 화면별 분석 + Evaluation Context');
    print('📥 입력 스크린샷 개수: ${images.length}개');
    print('🎯 Evaluation Scope: ${evaluationScope ?? "Not specified"}');
    print('📋 Special Notes: ${specialNotes ?? "Not specified"}\n');

    // 1. 프롬프트 생성
    final prompt = MIAPrompts.getScreenshotAnalysisPrompt(
      images.length,
      evaluationScope: evaluationScope,
      specialNotes: specialNotes
    );
    print('📝 생성된 프롬프트 정보:');
    print('   - 프롬프트 타입: 스크린샷 분석 (MIA)');
    print('   - 프롬프트 길이: ${prompt.length} 글자\n');

    // 2. Base64 문자열을 Uint8List로 변환
    final imageBytes = images.map((base64String) {
      return base64Decode(base64String);
    }).toList();
    print('🔄 Base64 → Uint8List 변환 완료');
    for (var i = 0; i < imageBytes.length; i++) {
      print('   - 이미지 ${i + 1}: ${(imageBytes[i].length / 1024).toStringAsFixed(2)} KB');
    }

    // 디버그 로깅: 단계 안내
    DebugLogger.logMIAInput(screenshotCount: imageBytes.length);

    // 3. Gemini API 호출
    print('\n🚀 Gemini API 호출 중...\n');
    final content = await _geminiService.analyzeScreenshots(
      imageBytes: imageBytes,
      prompt: prompt,
    );

    print('\n[AnalysisService] Gemini 응답 수신 완료');
    print('📦 응답 데이터 처리 중...\n');

    // 4. JSON 추출 (마크다운 코드 블록 제거)
    final jsonString = _extractJson(content);
    print('✂️  JSON 추출 완료');
    print('   - 추출된 JSON 길이: ${jsonString.length} 글자');
    print('   - JSON 미리보기: ${jsonString.substring(0, jsonString.length > 100 ? 100 : jsonString.length)}...\n');

    // 5. JSON 파싱
    try {
      print('🔍 JSON 파싱 중...');
      final jsonData = jsonDecode(jsonString);
      final result = MIAResult.fromJson(jsonData);

      print('✅ JSON 파싱 성공!');
      print('📊 분석 결과:');
      print('   - 사용 맥락: ✓');
      print('     └─ 타겟 사용자: ${result.usageContext.targetUser.substring(0, result.usageContext.targetUser.length > 30 ? 30 : result.usageContext.targetUser.length)}...');
      print('     └─ 사용자 목표: ${result.usageContext.userGoal.substring(0, result.usageContext.userGoal.length > 30 ? 30 : result.usageContext.userGoal.length)}...');
      print('   - 화면 분석: ${result.screenPurposes.length}개');
      for (var i = 0; i < result.screenPurposes.length; i++) {
        print('     └─ 화면 ${i + 1}: ${result.screenPurposes[i].purpose}');
      }
      print('╔════════════════════════════════════════════════════════════╗');
      print('║  [AnalysisService] 스크린샷 분석 완료 ✅                  ║');
      print('╚════════════════════════════════════════════════════════════╝\n');

      return result;
    } on FormatException catch (e) {
      print('❌ [AnalysisService] JSON 파싱 실패 (FormatException): $e');
      print('💀 실패한 JSON:\n$jsonString\n');
      throw Exception('AI 응답을 파싱할 수 없습니다: $e');
    } catch (e) {
      print('❌ [AnalysisService] 분석 중 오류 발생: $e\n');
      throw Exception('분석 중 오류 발생: $e');
    }
  }

  String _extractJson(String content) {
    // Case 1: ```json 코드 블록
    if (content.contains('```json')) {
      return content
          .split('```json')[1]
          .split('```')[0]
          .trim();
    }

    // Case 2: ``` 코드 블록
    if (content.contains('```')) {
      return content
          .split('```')[1]
          .split('```')[0]
          .trim();
    }

    // Case 3: 첫 { 부터 마지막 } 까지
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start != -1 && end != -1) {
      return content.substring(start, end + 1);
    }

    // Case 4: 그대로 반환
    return content.trim();
  }
}
