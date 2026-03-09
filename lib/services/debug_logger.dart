/// DebugLogger - 단계 진입 안내를 위한 유틸리티 클래스
///
/// 각 단계(MIA, DR, E)의 진입을 콘솔에 간단히 안내합니다.
/// 상세 정보(스크린샷, 프롬프트, 레퍼런스 등)는 각 서비스에서 출력합니다.
class DebugLogger {
  static const bool _enableDetailedLogging = true;

  /// Stage 1: MIA (Heuristic Evaluation) 진입 안내
  static void logMIAInput({
    required int screenshotCount,
  }) {
    if (!_enableDetailedLogging) return;
    print('\n═══ [STAGE 1] MIA - $screenshotCount screenshots ═══\n');
  }

  /// Stage 2: DR (Design Representation) 진입 안내
  static void logDRInput({
    required String agentName,
    required int screenshotCount,
  }) {
    if (!_enableDetailedLogging) return;
    print('\n═══ [STAGE 2] $agentName DR - $screenshotCount screenshots ═══\n');
  }

  /// Stage 3: E (Evaluation) 진입 안내
  static void logEInput({
    required String agentName,
    required int screenshotCount,
  }) {
    if (!_enableDetailedLogging) return;
    print('\n═══ [STAGE 3] $agentName E - $screenshotCount screenshots ═══\n');
  }
}
