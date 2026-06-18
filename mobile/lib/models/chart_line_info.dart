class ChartLineInfo {
  final double startPrice;
  final double endPrice;
  final int startTime; // unix seconds
  final int endTime;   // unix seconds
  final bool isHorizontal;

  const ChartLineInfo({
    required this.startPrice,
    required this.endPrice,
    required this.startTime,
    required this.endTime,
    this.isHorizontal = false,
  });

  double priceAt(int unixSec) {
    if (isHorizontal) return startPrice;
    if (endTime == startTime) return startPrice;
    final t = (unixSec - startTime) / (endTime - startTime);
    return startPrice + t * (endPrice - startPrice);
  }

  String get label {
    if (isHorizontal) {
      return '수평선  ${startPrice.toStringAsFixed(0)}원';
    }
    return '추세선  ${startPrice.toStringAsFixed(0)} → ${endPrice.toStringAsFixed(0)}원';
  }
}
