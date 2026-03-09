import 'dart:convert';
import 'dart:typed_data';
import 'MIA_result.dart';

/// Model for complete saved analysis state including images and analysis results
class SavedAnalysisData {
  final String savedAt;
  final List<ScreenImageData> uploadedScreens;
  final MIAResult miaResult;

  SavedAnalysisData({
    required this.savedAt,
    required this.uploadedScreens,
    required this.miaResult,
  });

  /// Convert from uploadedScreens format used in the app
  factory SavedAnalysisData.fromUploadedScreens({
    required List<Map<String, dynamic>> uploadedScreens,
    required MIAResult miaResult,
  }) {
    return SavedAnalysisData(
      savedAt: DateTime.now().toIso8601String(),
      uploadedScreens: uploadedScreens
          .map((screen) => ScreenImageData.fromUploadedScreen(screen))
          .toList(),
      miaResult: miaResult,
    );
  }

  /// Convert to JSON for file storage
  Map<String, dynamic> toJson() {
    return {
      'savedAt': savedAt,
      'uploadedScreens': uploadedScreens.map((s) => s.toJson()).toList(),
      'MIAResult': miaResult.toJson(),
    };
  }

  /// Create from JSON loaded from file
  factory SavedAnalysisData.fromJson(Map<String, dynamic> json) {
    return SavedAnalysisData(
      savedAt: json['savedAt'] as String,
      uploadedScreens: (json['uploadedScreens'] as List)
          .map((s) => ScreenImageData.fromJson(s as Map<String, dynamic>))
          .toList(),
      miaResult:
          MIAResult.fromJson(json['MIAResult'] as Map<String, dynamic>),
    );
  }

  /// Convert back to uploadedScreens format for use in the app
  List<Map<String, dynamic>> toUploadedScreensFormat() {
    return uploadedScreens
        .map((screen) => screen.toUploadedScreenFormat())
        .toList();
  }
}

/// Image-only saved data (MIAResult 없음)
/// MIAx 모드에서 이미지만 불러올 때 사용
class SavedImagesData {
  final String savedAt;
  final List<ScreenImageData> uploadedScreens;

  SavedImagesData({
    required this.savedAt,
    required this.uploadedScreens,
  });

  factory SavedImagesData.fromJson(Map<String, dynamic> json) {
    return SavedImagesData(
      savedAt: json['savedAt'] as String? ?? '',
      uploadedScreens: (json['uploadedScreens'] as List)
          .map((s) => ScreenImageData.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  List<Map<String, dynamic>> toUploadedScreensFormat() {
    return uploadedScreens
        .map((screen) => screen.toUploadedScreenFormat())
        .toList();
  }
}

/// Model for individual screen image data
class ScreenImageData {
  final String name;
  final String bytesBase64;

  ScreenImageData({
    required this.name,
    required this.bytesBase64,
  });

  /// Create from uploadedScreen format
  factory ScreenImageData.fromUploadedScreen(Map<String, dynamic> screen) {
    final bytes = screen['bytes'] as Uint8List?;
    return ScreenImageData(
      name: screen['name'] as String,
      bytesBase64: bytes != null ? base64Encode(bytes) : '',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bytes': bytesBase64,
    };
  }

  /// Create from JSON
  factory ScreenImageData.fromJson(Map<String, dynamic> json) {
    return ScreenImageData(
      name: json['name'] as String,
      bytesBase64: json['bytes'] as String,
    );
  }

  /// Convert back to uploadedScreen format
  Map<String, dynamic> toUploadedScreenFormat() {
    final bytes = bytesBase64.isNotEmpty ? base64Decode(bytesBase64) : null;
    return {
      'name': name,
      'bytes': bytes,
    };
  }
}
