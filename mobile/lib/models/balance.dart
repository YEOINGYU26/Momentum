class Holding {
  final String ticker;
  final String name;
  final String quantity;
  final String avgPrice;
  final String currentPrice;
  final String evalAmount;
  final String profitLoss;
  final String profitRate;

  Holding({
    required this.ticker,
    required this.name,
    required this.quantity,
    required this.avgPrice,
    required this.currentPrice,
    required this.evalAmount,
    required this.profitLoss,
    required this.profitRate,
  });

  factory Holding.fromJson(Map<String, dynamic> json) {
    return Holding(
      ticker: json['pdno'] ?? '',
      name: json['prdt_name'] ?? '',
      quantity: json['hldg_qty'] ?? '0',
      avgPrice: json['pchs_avg_pric'] ?? '0',
      currentPrice: json['prpr'] ?? '0',
      evalAmount: json['evlu_amt'] ?? '0',
      profitLoss: json['evlu_pfls_amt'] ?? '0',
      profitRate: json['evlu_pfls_rt'] ?? '0.00',
    );
  }

  bool get isProfit => !profitLoss.startsWith('-');
}

class BalanceData {
  final String totalEvalAmount;
  final String totalPurchaseAmount;
  final String totalProfitLoss;
  final String totalProfitRate;
  final String cashBalance;
  final List<Holding> holdings;

  BalanceData({
    required this.totalEvalAmount,
    required this.totalPurchaseAmount,
    required this.totalProfitLoss,
    required this.totalProfitRate,
    required this.cashBalance,
    required this.holdings,
  });

  factory BalanceData.fromJson(Map<String, dynamic> json) {
    final summary = (json['output2'] as List?)?.firstOrNull ?? {};
    final items = (json['output1'] as List?) ?? [];
    return BalanceData(
      totalEvalAmount: summary['scts_evlu_amt'] ?? '0',
      totalPurchaseAmount: summary['pchs_amt_smtl_amt'] ?? '0',
      totalProfitLoss: summary['evlu_pfls_smtl_amt'] ?? '0',
      totalProfitRate: summary['tot_evlu_pfls_rt'] ?? '0.00',
      cashBalance: summary['dnca_tot_amt'] ?? '0',
      holdings: items.map((e) => Holding.fromJson(e)).toList(),
    );
  }
}
