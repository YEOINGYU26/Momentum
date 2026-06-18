import 'package:flutter/material.dart';
import '../models/chart_line_info.dart';

class ChartProvider extends ChangeNotifier {
  String _ticker = '005930';
  final Map<String, List<ChartLineInfo>> _linesByTicker = {};

  String get ticker => _ticker;

  /// 현재 선택된 티커의 라인
  List<ChartLineInfo> get chartLines => getLinesForTicker(_ticker);

  /// 특정 티커의 라인 반환
  List<ChartLineInfo> getLinesForTicker(String t) =>
      List.unmodifiable(_linesByTicker[t] ?? []);

  void setTicker(String t) {
    if (_ticker == t) return;
    _ticker = t;
    notifyListeners();
  }

  /// 현재 ticker 에 대한 라인 저장
  void setChartLines(List<ChartLineInfo> lines) {
    _linesByTicker[_ticker] = lines;
    notifyListeners();
  }
}
