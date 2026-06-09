import 'package:flutter/material.dart';

class ChartProvider extends ChangeNotifier {
  String _ticker = '005930';
  String get ticker => _ticker;

  void setTicker(String t) {
    if (_ticker == t) return;
    _ticker = t;
    notifyListeners();
  }
}
