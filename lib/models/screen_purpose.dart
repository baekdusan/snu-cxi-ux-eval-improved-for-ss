class ScreenPurpose {
  final String screenId;         // 화면 ID (screen_1, screen_2, ...)
  final String purpose;          // 화면의 목적

  ScreenPurpose({
    required this.screenId,
    required this.purpose,
  });

  factory ScreenPurpose.fromJson(Map<String, dynamic> json) {
    return ScreenPurpose(
      screenId: json['screen_id'] as String,
      purpose: json['purpose'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'screen_id': screenId,
      'purpose': purpose,
    };
  }
}
