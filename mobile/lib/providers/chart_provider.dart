import 'package:flutter/material.dart';
import '../models/chart_line_info.dart';

class ChartProvider extends ChangeNotifier {
  String _ticker = '005930';
  List<ChartLineInfo> _chartLines = [];

  String get ticker => _ticker;
  List<ChartLineInfo> get chartLines => List.unmodifiable(_chartLines);

  void setTicker(String t) {
    if (_ticker == t) return;
    _ticker = t;
    notifyListeners();
  }

  void setChartLines(List<ChartLineInfo> lines) {
    _chartLines = lines;
    notifyListeners();
  }
}
