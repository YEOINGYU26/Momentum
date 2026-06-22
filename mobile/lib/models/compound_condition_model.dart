class CompoundConditionModel {
  final String ruleId;
  final String ticker;
  final String side;
  final int quantity;
  final int intervalSeconds;
  final String timeframe;
  final List<Map<String, dynamic>> lineConditions;
  final List<Map<String, dynamic>> indicatorConditions;
  final double createdAt;
  final int triggeredCount;

  const CompoundConditionModel({
    required this.ruleId,
    required this.ticker,
    required this.side,
    required this.quantity,
    required this.intervalSeconds,
    required this.timeframe,
    required this.lineConditions,
    required this.indicatorConditions,
    required this.createdAt,
    required this.triggeredCount,
  });

  bool get isBuy => side == 'buy';

  String get conditionSummary {
    final parts = <String>[];
    if (lineConditions.isNotEmpty) parts.add('매매선(${lineConditions.length}개)');
    for (final ic in indicatorConditions) {
      switch (ic['type'] as String) {
        case 'rsi':            parts.add('RSI'); break;
        case 'moving_average': parts.add('골든크로스'); break;
        case 'scalping':       parts.add('볼린저밴드'); break;
      }
    }
    return parts.join(' + ');
  }

  factory CompoundConditionModel.fromJson(Map<String, dynamic> j) =>
      CompoundConditionModel(
        ruleId:              j['rule_id'] as String,
        ticker:              j['ticker'] as String,
        side:                j['side'] as String,
        quantity:            j['quantity'] as int,
        intervalSeconds:     j['interval_seconds'] as int,
        timeframe:           j['timeframe'] as String? ?? 'D',
        lineConditions:      (j['line_conditions'] as List).cast<Map<String, dynamic>>(),
        indicatorConditions: (j['indicator_conditions'] as List).cast<Map<String, dynamic>>(),
        createdAt:           (j['created_at'] as num).toDouble(),
        triggeredCount:      j['triggered_count'] as int? ?? 0,
      );
}
