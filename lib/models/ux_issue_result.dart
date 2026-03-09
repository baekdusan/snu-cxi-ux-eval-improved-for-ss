/// Model classes for UX Issues evaluation results
/// Agent 1 (UX Writing)       → UXWritingIssue
/// Agent 2 (Error Prevention) → ErrorPreventionIssue
/// Agent 3 (Visual Consistency) → VisualConsistencyIssue
library;

// ============================================================
// UXIssueResult — 모든 에이전트 이슈를 담는 컨테이너
// ============================================================

class UXIssueResult {
  final List<UXIssue> uxIssues;

  UXIssueResult({required this.uxIssues});

  /// JSON 로드: [agentNumber]가 지정되면 해당 타입으로, 없으면 자동 감지
  factory UXIssueResult.fromJson(Map<String, dynamic> json, {int? agentNumber}) {
    final rawList = (json['UX_issues'] ?? json['problems']) as List?;
    if (rawList == null || rawList.isEmpty) return UXIssueResult(uxIssues: []);

    return UXIssueResult(
      uxIssues: rawList.map((e) {
        final map = e as Map<String, dynamic>;
        switch (agentNumber) {
          case 1:
            return UXWritingIssue.fromJson(map);
          case 2:
            return ErrorPreventionIssue.fromJson(map);
          case 3:
            return VisualConsistencyIssue.fromJson(map);
          default:
            // 자동 감지 (하위 호환)
            if (map.containsKey('violation_level')) {
              return VisualConsistencyIssue.fromJson(map);
            }
            return UXWritingIssue.fromJson(map);
        }
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'problems': uxIssues.map((e) => e.toJson()).toList()};
  }
}

// ============================================================
// AgentType enum (서비스에서 factory 분기용으로 사용)
// ============================================================

enum AgentType {
  uxWriting,         // Agent 1
  errorPrevention,   // Agent 2
  visualConsistency, // Agent 3
}

// ============================================================
// 공통 기반 클래스
// ============================================================

abstract class UXIssue {
  final String issueId;
  final String screenId;
  final String problemDescription;
  final String heuristicViolated;
  final String heuristicCategory;
  final String reasoning;
  final String recommendation;

  const UXIssue({
    required this.issueId,
    this.screenId = '',
    required this.problemDescription,
    required this.heuristicViolated,
    this.heuristicCategory = '',
    required this.reasoning,
    required this.recommendation,
  });

  Map<String, dynamic> toJson();

  /// issueId만 교체한 새 인스턴스 반환 (서비스에서 ID 부여 시 사용)
  UXIssue copyWithId(String newId);
}

// ============================================================
// Agent 1: UX Writing
// ============================================================

class UXWritingIssue extends UXIssue {
  final int textElementId;
  final String text;

  const UXWritingIssue({
    required super.issueId,
    super.screenId,
    this.textElementId = 0,
    this.text = '',
    required super.problemDescription,
    required super.heuristicViolated,
    super.heuristicCategory,
    required super.reasoning,
    required super.recommendation,
  });

  factory UXWritingIssue.fromJson(
    Map<String, dynamic> json, {
    String? categoryOverride,
    String? heuristicOverride,
  }) {
    return UXWritingIssue(
      issueId: json['issue_id'] as String? ?? '',
      screenId: json['screen_id'] as String? ?? '',
      textElementId: json['id'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      problemDescription: json['problem_description'] as String? ?? '',
      heuristicViolated:
          heuristicOverride ?? json['heuristic_violated'] as String? ?? '',
      heuristicCategory:
          categoryOverride ?? json['heuristic_category'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'issue_id': issueId,
        'screen_id': screenId,
        'id': textElementId,
        'text': text,
        'problem_description': problemDescription,
        'heuristic_violated': heuristicViolated,
        'heuristic_category': heuristicCategory,
        'reasoning': reasoning,
        'recommendation': recommendation,
      };

  @override
  UXWritingIssue copyWithId(String newId) => UXWritingIssue(
        issueId: newId,
        screenId: screenId,
        textElementId: textElementId,
        text: text,
        problemDescription: problemDescription,
        heuristicViolated: heuristicViolated,
        heuristicCategory: heuristicCategory,
        reasoning: reasoning,
        recommendation: recommendation,
      );
}

// ============================================================
// Agent 2: Error Prevention
// ============================================================

class ErrorPreventionIssue extends UXIssue {
  final int? elementId;       // element_id (null = 특정 요소 없음)
  final String? elementType;  // element_type (null = 특정 요소 없음)

  const ErrorPreventionIssue({
    required super.issueId,
    super.screenId,
    this.elementId,
    this.elementType,
    required super.problemDescription,
    required super.heuristicViolated,
    super.heuristicCategory,
    required super.reasoning,
    required super.recommendation,
  });

  factory ErrorPreventionIssue.fromJson(
    Map<String, dynamic> json, {
    String? categoryOverride,
    String? heuristicOverride,
  }) {
    return ErrorPreventionIssue(
      issueId: json['issue_id'] as String? ?? '',
      screenId: json['screen_id'] as String? ?? '',
      elementId: json['element_id'] as int?,
      elementType: json['element_type'] as String?,
      problemDescription: json['problem_description'] as String? ?? '',
      heuristicViolated: heuristicOverride ?? json['heuristic_violated'] as String? ?? '',
      heuristicCategory: categoryOverride ?? json['heuristic_category'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'issue_id': issueId,
        'screen_id': screenId,
        'element_id': elementId,
        'element_type': elementType,
        'problem_description': problemDescription,
        'heuristic_violated': heuristicViolated,
        'heuristic_category': heuristicCategory,
        'reasoning': reasoning,
        'recommendation': recommendation,
      };

  @override
  ErrorPreventionIssue copyWithId(String newId) => ErrorPreventionIssue(
        issueId: newId,
        screenId: screenId,
        elementId: elementId,
        elementType: elementType,
        problemDescription: problemDescription,
        heuristicViolated: heuristicViolated,
        heuristicCategory: heuristicCategory,
        reasoning: reasoning,
        recommendation: recommendation,
      );
}

// ============================================================
// Agent 3: Visual Consistency
// ============================================================

class VisualConsistencyIssue extends UXIssue {
  final String violationLevel;    // "screen" | "element"
  final int? elementId;           // screen-level 시 null
  final String? elementDescription; // screen-level 시 null
  final String violatedAttribute; // "layout" | "shape" | "color" | "screen_level" 등

  const VisualConsistencyIssue({
    required super.issueId,
    super.screenId,
    required this.violationLevel,
    this.elementId,
    this.elementDescription,
    required this.violatedAttribute,
    required super.problemDescription,
    required super.heuristicViolated,
    super.heuristicCategory,
    required super.reasoning,
    required super.recommendation,
  });

  factory VisualConsistencyIssue.fromJson(
    Map<String, dynamic> json, {
    String? categoryOverride,
    String? heuristicOverride,
  }) {
    return VisualConsistencyIssue(
      issueId: json['issue_id'] as String? ?? '',
      screenId: json['screen_id'] as String? ?? '',
      violationLevel: json['violation_level'] as String? ?? 'element',
      elementId: json['element_id'] as int?,
      elementDescription: json['element_description'] as String?,
      violatedAttribute: json['violated_attribute'] as String? ?? '',
      problemDescription: json['problem_description'] as String? ?? '',
      heuristicViolated: heuristicOverride ?? json['heuristic_violated'] as String? ?? '',
      heuristicCategory: categoryOverride ?? json['heuristic_category'] as String? ?? '',
      reasoning: json['reasoning'] as String? ?? '',
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final isScreenLevel = violationLevel == 'screen';
    return {
      'issue_id': issueId,
      'screen_id': screenId,
      'violation_level': violationLevel,
      'element_id': isScreenLevel ? null : elementId,
      'element_description':
          isScreenLevel ? null : (elementDescription?.isEmpty ?? true) ? null : elementDescription,
      'violated_attribute': violatedAttribute,
      'problem_description': problemDescription,
      'heuristic_violated': heuristicViolated,
      'heuristic_category': heuristicCategory,
      'reasoning': reasoning,
      'recommendation': recommendation,
    };
  }

  @override
  VisualConsistencyIssue copyWithId(String newId) => VisualConsistencyIssue(
        issueId: newId,
        screenId: screenId,
        violationLevel: violationLevel,
        elementId: elementId,
        elementDescription: elementDescription,
        violatedAttribute: violatedAttribute,
        problemDescription: problemDescription,
        heuristicViolated: heuristicViolated,
        heuristicCategory: heuristicCategory,
        reasoning: reasoning,
        recommendation: recommendation,
      );
}

// ============================================================
// Importance Filter Models (Filter ver.2)
// ============================================================

/// 개별 중요도 기준 평가 결과
class CriteriaResult {
  final bool matched;
  final int score;
  final String reason;

  CriteriaResult({
    required this.matched,
    required this.score,
    required this.reason,
  });

  factory CriteriaResult.fromJson(Map<String, dynamic> json) {
    return CriteriaResult(
      matched: json['matched'] as bool? ?? false,
      score: json['score'] as int? ?? 0,
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matched': matched,
      'score': score,
      'reason': reason,
    };
  }
}

/// 이슈별 중요도 평가 결과
class ImportanceEvaluation {
  final String issueId;
  final Map<String, CriteriaResult> criteriaEvaluation;
  final int totalScore;
  final List<String> matchedCriteria;

  ImportanceEvaluation({
    required this.issueId,
    required this.criteriaEvaluation,
    required this.totalScore,
    required this.matchedCriteria,
  });

  factory ImportanceEvaluation.fromJson(Map<String, dynamic> json) {
    final criteriaMap = <String, CriteriaResult>{};
    final evalJson = json['criteria_evaluation'] as Map<String, dynamic>? ?? {};

    for (final entry in evalJson.entries) {
      criteriaMap[entry.key] = CriteriaResult.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }

    return ImportanceEvaluation(
      issueId: json['issue_id'] as String? ?? '',
      criteriaEvaluation: criteriaMap,
      totalScore: json['total_score'] as int? ?? 0,
      matchedCriteria:
          (json['matched_criteria'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'issue_id': issueId,
      'criteria_evaluation': criteriaEvaluation.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'total_score': totalScore,
      'matched_criteria': matchedCriteria,
    };
  }

  /// 점수에 따른 우선순위 레벨 반환 (9점 이상: Important, 9점 미만: Not Important)
  String getPriorityLevel() {
    if (totalScore >= 9) return 'important';
    return 'not_important';
  }
}
