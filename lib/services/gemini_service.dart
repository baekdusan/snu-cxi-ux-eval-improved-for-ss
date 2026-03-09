import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GeminiService {
  late final GenerativeModel _model;

  GeminiService({String? systemInstruction, int maxOutputTokens = 65536}) {
    // Firebase를 통해 Vertex AI의 Gemini 모델 초기화
    // API 키 불필요! Firebase 프로젝트 설정만으로 작동
    final vertexAI = FirebaseAI.vertexAI(
      auth: FirebaseAuth.instance,
      location: 'us-central1', // 가장 안정적인 리전 (503 에러 방지)
    );
    _model = vertexAI.generativeModel(
      model: 'gemini-2.5-flash', // 최신 Gemini 2.0 Flash 모델
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // JSON 모드 강제
        temperature: 0, // 더 일관된 출력을 위해 temperature 낮춤
        maxOutputTokens: maxOutputTokens, // 분류 전용: 1024, 전체 처리: 65536
      ),
      systemInstruction: systemInstruction != null
          ? Content.text(systemInstruction)
          : null,
    );
  }

  Future<String> analyzeScreenshots({
    required List<Uint8List> imageBytes,
    required String prompt,
  }) async {
    // 디버깅: 입력 정보 로깅
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔵 [GeminiService] API 호출 시작');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📥 입력 이미지: ${imageBytes.length}개');
    print('📝 User Prompt 길이: ${prompt.length} 글자');

    // 이미지를 InlineDataPart로 변환
    final imageParts = imageBytes.map((bytes) {
      return InlineDataPart('image/jpeg', bytes);
    }).toList();

    // 프롬프트와 이미지를 결합한 콘텐츠 생성
    final content = [
      Content.multi([TextPart(prompt), ...imageParts]),
    ];

    // Gemini API 호출
    try {
      final startTime = DateTime.now();
      print('⏱️  API 호출 시작 시간: ${startTime.toIso8601String()}');

      // 스트리밍으로 호출 (타임아웃 방지 — 청크 단위로 연결 유지)
      final responseStream = _model.generateContentStream(content);
      final buffer = StringBuffer();
      int chunkCount = 0;

      await for (final chunk in responseStream) {
        chunkCount++;
        final chunkText = chunk.text;
        if (chunkText != null && chunkText.isNotEmpty) {
          buffer.write(chunkText);
          print('📦 청크 $chunkCount 수신 (${chunkText.length} 글자)');
        }
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      print('⏱️  API 호출 완료 시간: ${endTime.toIso8601String()}');
      print(
        '⏱️  소요 시간: ${duration.inSeconds}초 ${duration.inMilliseconds % 1000}ms',
      );

      final responseText = buffer.toString();

      if (responseText.isEmpty) {
        print('❌ 오류: Gemini API 응답이 비어있습니다 (청크 $chunkCount개 수신).');
        throw Exception('Gemini API 응답이 비어있습니다.');
      }

      // 디버깅: 출력 정보 로깅
      print('📤 응답 길이: ${responseText.length} 글자 (청크 $chunkCount개)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ [GeminiService] API 호출 성공 (${duration.inSeconds}초)\n');

      return responseText;
    } catch (e) {
      print('❌ [GeminiService] API 호출 실패: $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      throw Exception('Gemini API 호출 실패: $e');
    }
  }
}
