class SchedulerJob {
  final String jobId;
  final String ticker;
  final String strategyName;
  final int? intervalSeconds;
  final String? cronExpression;
  final String status;
  final String? nextRunTime;

  SchedulerJob({
    required this.jobId,
    required this.ticker,
    required this.strategyName,
    this.intervalSeconds,
    this.cronExpression,
    required this.status,
    this.nextRunTime,
  });

  factory SchedulerJob.fromJson(Map<String, dynamic> json) {
    return SchedulerJob(
      jobId: json['job_id'] ?? '',
      ticker: json['ticker'] ?? '',
      strategyName: json['strategy_name'] ?? '',
      intervalSeconds: json['interval_seconds'],
      cronExpression: json['cron_expression'],
      status: json['status'] ?? 'unknown',
      nextRunTime: json['next_run_time'],
    );
  }

  bool get isRunning => status == 'running';
  bool get isPaused => status == 'paused';

  String get scheduleLabel {
    if (intervalSeconds != null) return '$intervalSeconds초 간격';
    if (cronExpression != null) return cronExpression!;
    return '-';
  }
}
