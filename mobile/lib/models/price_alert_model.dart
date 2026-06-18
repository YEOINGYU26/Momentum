class PriceAlertModel {
  final String ticker;
  final int targetPrice;
  final String side;
  final int quantity;
  final bool triggered;
  final bool isTrendline;
  final int? lineStartTime;
  final double? lineStartPrice;
  final int? lineEndTime;
  final double? lineEndPrice;

  const PriceAlertModel({
    required this.ticker,
    required this.targetPrice,
    required this.side,
    required this.quantity,
    required this.triggered,
    this.isTrendline = false,
    this.lineStartTime,
    this.lineStartPrice,
    this.lineEndTime,
    this.lineEndPrice,
  });

  factory PriceAlertModel.fromJson(Map<String, dynamic> j) => PriceAlertModel(
        ticker:         j['ticker'] as String,
        targetPrice:    (j['target_price'] as num).toInt(),
        side:           j['side'] as String,
        quantity:       (j['quantity'] as num).toInt(),
        triggered:      j['triggered'] as bool? ?? false,
        isTrendline:    j['is_trendline'] as bool? ?? false,
        lineStartTime:  (j['line_start_time'] as num?)?.toInt(),
        lineStartPrice: (j['line_start_price'] as num?)?.toDouble(),
        lineEndTime:    (j['line_end_time'] as num?)?.toInt(),
        lineEndPrice:   (j['line_end_price'] as num?)?.toDouble(),
      );

  bool get isBuy => side == 'buy';

  /// 주어진 시각(Unix seconds)의 유효 목표가 (추세선이면 선형 보간/외삽)
  double effectiveTargetAt(int nowSec) {
    if (!isTrendline ||
        lineStartTime == null ||
        lineStartPrice == null ||
        lineEndTime == null ||
        lineEndPrice == null) {
      return targetPrice.toDouble();
    }
    final t0 = lineStartTime!;
    final t1 = lineEndTime!;
    if (t1 == t0) return lineStartPrice!;
    final frac = (nowSec - t0) / (t1 - t0);
    return lineStartPrice! + frac * (lineEndPrice! - lineStartPrice!);
  }
}
