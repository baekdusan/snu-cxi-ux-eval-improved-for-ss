class EvaluationContext {
  final String evaluationScope;
  final String specialEvaluationNotes;

  EvaluationContext({
    required this.evaluationScope,
    required this.specialEvaluationNotes,
  });

  factory EvaluationContext.fromJson(Map<String, dynamic> json) {
    return EvaluationContext(
      evaluationScope: json['evaluation_scope'] as String? ?? '',
      specialEvaluationNotes: json['special_evaluation_notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'evaluation_scope': evaluationScope,
      'special_evaluation_notes': specialEvaluationNotes,
    };
  }
}
