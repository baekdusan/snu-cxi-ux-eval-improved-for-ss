class UsageContext {
  final String targetUser;       // 타겟 사용자
  final String usageEnvironment; // 사용 환경
  final String userGoal;         // 사용자 목표
  final String taskScenario;     // 과업 시나리오

  UsageContext({
    required this.targetUser,
    required this.usageEnvironment,
    required this.userGoal,
    required this.taskScenario,
  });

  factory UsageContext.fromJson(Map<String, dynamic> json) {
    return UsageContext(
      targetUser: json['target_user'] as String,
      usageEnvironment: json['usage_environment'] as String,
      userGoal: json['user_goal'] as String,
      taskScenario: json['task_scenario'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'target_user': targetUser,
      'usage_environment': usageEnvironment,
      'user_goal': userGoal,
      'task_scenario': taskScenario,
    };
  }
}
