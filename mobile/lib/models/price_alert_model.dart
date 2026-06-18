class PriceAlertModel {
  final String ticker;
  final int targetPrice;
  final String side;     // 'buy' | 'sell'
  final int quantity;
  final bool triggered;

  const PriceAlertModel({
    required this.ticker,
    required this.targetPrice,
    required this.side,
    required this.quantity,
    required this.triggered,
  });

  factory PriceAlertModel.fromJson(Map<String, dynamic> j) => PriceAlertModel(
        ticker:      j['ticker'] as String,
        targetPrice: (j['target_price'] as num).toInt(),
        side:        j['side'] as String,
        quantity:    (j['quantity'] as num).toInt(),
        triggered:   j['triggered'] as bool? ?? false,
      );

  bool get isBuy => side == 'buy';
}
