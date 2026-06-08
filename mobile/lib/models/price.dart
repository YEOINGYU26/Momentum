class PriceData {
  final String ticker;
  final String price;
  final String change;
  final String changeRate;
  final String volume;

  PriceData({
    required this.ticker,
    required this.price,
    required this.change,
    required this.changeRate,
    required this.volume,
  });

  factory PriceData.fromJson(String ticker, Map<String, dynamic> json) {
    final output = json['output'] ?? json;
    return PriceData(
      ticker: ticker,
      price: output['stck_prpr'] ?? output['price'] ?? '0',
      change: output['prdy_vrss'] ?? '0',
      changeRate: output['prdy_ctrt'] ?? '0.00',
      volume: output['acml_vol'] ?? '0',
    );
  }

  bool get isUp => !change.startsWith('-');
}
