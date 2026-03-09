import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:file_picker/file_picker.dart';
import '../models/saved_MIA_result.dart';
import '../models/MIA_result.dart';
import '../models/DR_result.dart';
import '../models/ux_issue_result.dart';

/// Service for saving and loading analysis data to/from JSON files
class DataPersistenceService {
  /// 파일명에서 에이전트 번호와 스테이지(dr/issues)를 파싱
  ///
  /// 파일명 규칙 (프리픽스 기반):
  /// - A1_*_DR*.json → (1, 'dr')   Agent 1 (UX Writing)
  /// - A2_*_DR*.json → (2, 'dr')   Agent 2 (Error Prevention & Forgiveness)
  /// - A3_*_DR*.json → (3, 'dr')   Agent 3 (Visual Consistency)
  /// - A1_*_E*.json  → (1, 'issues')
  /// - A2_*_E*.json  → (2, 'issues')
  /// - A3_*_E*.json  → (3, 'issues')
  ///
  /// S1_*, S2_* 등 MIA 파일은 별도 처리 (여기서는 null 반환)
  /// 인식 불가 시 null 반환
  static (int, String)? parseAgentFromFilename(String filename) {
    final upper = filename.toUpperCase();

    // Determine agent from A1_, A2_, A3_ prefix
    int? agent;
    if (upper.startsWith('A1_')) {
      agent = 1;
    } else if (upper.startsWith('A2_')) {
      agent = 2;
    } else if (upper.startsWith('A3_')) {
      agent = 3;
    }
    if (agent == null) return null;

    // Determine stage: _DR or _E in filename
    String? stage;
    if (upper.contains('_DR')) {
      stage = 'dr';
    } else if (upper.contains('_E')) {
      stage = 'issues';
    }
    if (stage == null) return null;

    return (agent, stage);
  }

  /// JSON 내용(필드)으로 에이전트 번호와 스테이지(dr/issues)를 자동 판별
  ///
  /// stage 판별:
  ///   - 최상위 키에 'screens' → 'dr'
  ///   - 최상위 키에 'problems' → 'issues'
  ///
  /// DR 에이전트 판별 (screens[0] 키 기준):
  ///   - 'text_elements' → Agent 1 (UX Writing)
  ///   - 'screen_level' or 'elements' → Agent 3 (Visual Consistency)
  ///   - 그 외 → Agent 2 (Error Prevention)
  ///
  /// Issues 에이전트 판별 (problems[0].issue_id prefix 기준):
  ///   - 'UX-WRITING' → Agent 1
  ///   - 'ERROR-PREV' → Agent 2
  ///   - 'VISUAL-CONSIST' → Agent 3
  ///
  /// 인식 불가 시 null 반환
  static (int, String)? parseAgentFromJson(Map<String, dynamic> json) {
    // stage 판별
    String stage;
    if (json.containsKey('screens')) {
      stage = 'dr';
    } else if (json.containsKey('problems')) {
      stage = 'issues';
    } else {
      return null;
    }

    int? agent;

    if (stage == 'dr') {
      final screens = json['screens'] as List?;
      if (screens == null || screens.isEmpty) return null;
      final firstScreen = screens.first as Map<String, dynamic>;
      if (firstScreen.containsKey('text_elements')) {
        agent = 1;
      } else if (firstScreen.containsKey('screen_level') || firstScreen.containsKey('elements')) {
        agent = 3;
      } else {
        agent = 2;
      }
    } else {
      // issues
      final problems = json['problems'] as List?;
      if (problems == null || problems.isEmpty) return null;
      final firstIssue = problems.first as Map<String, dynamic>;
      final issueId = firstIssue['issue_id'] as String? ?? '';
      if (issueId.startsWith('UX-WRITING')) {
        agent = 1;
      } else if (issueId.startsWith('ERROR-PREV')) {
        agent = 2;
      } else if (issueId.startsWith('VISUAL-CONSIST')) {
        agent = 3;
      } else {
        return null;
      }
    }

    return (agent, stage);
  }

  /// 여러 JSON 파일을 동시에 선택
  ///
  /// Returns: (파일명, 바이트) 리스트, 취소 시 빈 리스트
  Future<List<(String, List<int>)>> pickMultipleJsonFiles(String dialogTitle) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return [];

    return result.files
        .where((f) => f.bytes != null)
        .map((f) => (f.name, f.bytes!.toList()))
        .toList();
  }

  /// Save analysis data to a JSON file (Web platform only)
  ///
  /// Returns the filename if successful, null otherwise
  Future<String?> saveAnalysisData({
    required List<Map<String, dynamic>> uploadedScreens,
    required MIAResult miaResult,
  }) async {
    try {
      // Create SavedAnalysisData from current state
      final savedData = SavedAnalysisData.fromUploadedScreens(
        uploadedScreens: uploadedScreens,
        miaResult: miaResult,
      );

      // Convert to JSON string with pretty printing
      final jsonString =
          const JsonEncoder.withIndent('  ').convert(savedData.toJson());

      // Generate filename with timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .split('.')[0]
          .replaceAll(':', '-');
      final filename = 'analysis_$timestamp.json';

      // Web platform: Download file using anchor element
      final bytes = utf8.encode(jsonString);
      final blob = html.Blob([bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);

      return filename;
    } catch (e) {
      throw Exception('분석 결과 저장 중 오류 발생: $e');
    }
  }

  /// Load analysis data from a JSON file
  ///
  /// Returns SavedAnalysisData if successful, throws exception otherwise
  Future<SavedAnalysisData> loadAnalysisData() async {
    try {
      // Let user choose file to load
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: '저장된 분석 결과 불러오기',
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // Important: Load file contents into memory
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('파일이 선택되지 않았습니다');
      }

      final file = result.files.first;

      if (file.bytes == null) {
        throw Exception('파일을 읽을 수 없습니다');
      }

      // Parse JSON
      final jsonString = utf8.decode(file.bytes!);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate required fields
      if (!jsonData.containsKey('savedAt') ||
          !jsonData.containsKey('uploadedScreens') ||
          !jsonData.containsKey('MIAResult')) {
        throw Exception('잘못된 파일 형식입니다. 필수 필드가 누락되었습니다.');
      }

      // Create SavedAnalysisData from JSON
      final savedData = SavedAnalysisData.fromJson(jsonData);

      return savedData;
    } on FormatException catch (e) {
      throw Exception('JSON 형식이 올바르지 않습니다: $e');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('파일 불러오기 중 오류 발생: $e');
    }
  }

  /// 파일 선택 다이얼로그 표시 후 JSON 파일 바이트 반환
  ///
  /// Returns: (파일명, 바이트) 또는 null (취소 시)
  Future<(String, List<int>)?> pickJsonFile(String dialogTitle) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    if (file.bytes == null) {
      throw Exception('파일을 읽을 수 없습니다');
    }

    return (file.name, file.bytes!.toList());
  }

  /// DR 파일 로드 (Agent 1)
  ///
  /// DR 파일 형식: {"screens": [...]}
  Future<DRResult> loadDRFromBytes(List<int> bytes) async {
    try {
      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!jsonData.containsKey('screens')) {
        throw Exception('잘못된 DR 파일 형식입니다. screens 필드가 필요합니다.');
      }

      return DRResult.fromJson(jsonData);
    } on FormatException catch (e) {
      throw Exception('DR JSON 형식이 올바르지 않습니다: $e');
    }
  }

  /// UX 이슈 파일 로드
  ///
  /// [agentNumber]를 지정하면 해당 Agent 타입으로 역직렬화합니다.
  /// 이슈 파일 형식: {"problems": [...]} 또는 {"UX_issues": [...]}
  Future<UXIssueResult> loadIssuesFromBytes(List<int> bytes, {int? agentNumber}) async {
    try {
      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (jsonData.containsKey('problems') || jsonData.containsKey('UX_issues')) {
        return UXIssueResult.fromJson(jsonData, agentNumber: agentNumber);
      }
      else {
        throw Exception('잘못된 이슈 파일 형식입니다. problems 또는 UX_issues 필드가 필요합니다.');
      }
    } on FormatException catch (e) {
      throw Exception('이슈 JSON 형식이 올바르지 않습니다: $e');
    }
  }

  /// MIA 파일 로드 (바이트에서)
  Future<SavedAnalysisData> loadMIAFromBytes(List<int> bytes) async {
    try {
      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!jsonData.containsKey('savedAt') ||
          !jsonData.containsKey('uploadedScreens') ||
          !jsonData.containsKey('MIAResult')) {
        throw Exception('잘못된 MIA 파일 형식입니다. 필수 필드가 누락되었습니다.');
      }

      return SavedAnalysisData.fromJson(jsonData);
    } on FormatException catch (e) {
      throw Exception('MIA JSON 형식이 올바르지 않습니다: $e');
    }
  }

  /// 이미지 전용 파일 로드 (MIAx 모드 - MIAResult 불필요)
  ///
  /// 이미지 파일 형식: {"uploadedScreens": [{name, bytes}, ...]}
  /// MIAResult/analysisResult 필드는 무시됨
  Future<SavedImagesData> loadImagesFromBytes(List<int> bytes) async {
    try {
      final jsonString = utf8.decode(bytes);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (!jsonData.containsKey('uploadedScreens')) {
        throw Exception('잘못된 이미지 파일 형식입니다. uploadedScreens 필드가 필요합니다.');
      }

      return SavedImagesData.fromJson(jsonData);
    } on FormatException catch (e) {
      throw Exception('이미지 JSON 형식이 올바르지 않습니다: $e');
    }
  }
}
