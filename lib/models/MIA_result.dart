import 'screen_purpose.dart';
import 'usage_context.dart';
import 'evaluation_context.dart';

class MIAResult {
  final EvaluationContext? evaluationContext;
  final List<ScreenPurpose> screenPurposes;
  final UsageContext usageContext;

  MIAResult({
    this.evaluationContext,
    required this.screenPurposes,
    required this.usageContext,
  });

  factory MIAResult.fromJson(Map<String, dynamic> json) {
    return MIAResult(
      evaluationContext: json.containsKey('evaluation_context')
          ? EvaluationContext.fromJson(json['evaluation_context'] as Map<String, dynamic>)
          : null,
      screenPurposes: (json['screens'] as List)
          .map((e) => ScreenPurpose.fromJson(e as Map<String, dynamic>))
          .toList(),
      usageContext: UsageContext.fromJson(json['usage_context'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'screens': screenPurposes.map((e) => e.toJson()).toList(),
      'usage_context': usageContext.toJson(),
    };
    if (evaluationContext != null) {
      json['evaluation_context'] = evaluationContext!.toJson();
    }
    return json;
  }
}
