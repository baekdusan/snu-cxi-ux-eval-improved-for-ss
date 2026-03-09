/// Model classes for DR (Design Representation) analysis results
/// Agent 1 (UX Writing): text_elements
/// Agent 2 (Error Prevention): 입력, 확인, 오류_경고_피드백, 복구, 네비게이션_이탈
/// Agent 3 (Visual Consistency): screen_level, elements
library;

class DRResult {
  final List<DRData> screens;

  DRResult({required this.screens});

  factory DRResult.fromJson(Map<String, dynamic> json) {
    return DRResult(
      screens: (json['screens'] as List? ?? [])
          .map((e) => DRData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'screens': screens.map((e) => e.toJson()).toList(),
    };
  }
}

class DRData {
  final String screenId;
  final List<TextElement> textElements; // Agent 1 전용
  final Map<String, dynamic>? rawData;  // Agent 2·3 전용 (나머지 모든 필드 보존)

  DRData({
    required this.screenId,
    this.textElements = const [],
    this.rawData,
  });

  factory DRData.fromJson(Map<String, dynamic> json) {
    final textElements = (json['text_elements'] as List? ?? [])
        .map((e) => TextElement.fromJson(e as Map<String, dynamic>))
        .toList();

    // screen_id, text_elements를 제외한 나머지 필드를 rawData로 보존
    final rawData = Map<String, dynamic>.from(json)
      ..remove('screen_id')
      ..remove('text_elements');

    print('   [DRData.fromJson] screen_id=${json['screen_id']}, '
        'textElements=${textElements.length}, rawData keys=${rawData.keys.toList()}');

    return DRData(
      screenId: json['screen_id'] as String? ?? '',
      textElements: textElements,
      rawData: rawData.isEmpty ? null : rawData,
    );
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{'screen_id': screenId};
    if (textElements.isNotEmpty) {
      result['text_elements'] = textElements.map((e) => e.toJson()).toList();
    }
    // rawData 필드를 그대로 병합 (Agent 2·3의 모든 필드 E 프롬프트에 전달)
    if (rawData != null) {
      result.addAll(rawData!);
    }
    return result;
  }
}

/// TextElement for text analysis (used by all 3 modules)
class TextElement {
  final int id;
  final String text;
  final String component;

  TextElement({
    required this.id,
    required this.text,
    required this.component,
  });

  factory TextElement.fromJson(Map<String, dynamic> json) {
    return TextElement(
      id: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      component: json['component'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'component': component,
    };
  }
}
