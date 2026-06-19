import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chart_line_info.dart';

class ChartProvider extends ChangeNotifier {
  static const _kKey = 'chart_lines_v1';

  String _ticker = '005930';
  final Map<String, List<ChartLineInfo>> _linesByTicker = {};

  String get ticker => _ticker;

  List<ChartLineInfo> get chartLines => getLinesForTicker(_ticker);

  List<ChartLineInfo> getLinesForTicker(String t) =>
      List.unmodifiable(_linesByTicker[t] ?? []);

  void setTicker(String t) {
    if (_ticker == t) return;
    _ticker = t;
    notifyListeners();
  }

  void setChartLines(List<ChartLineInfo> lines) {
    _linesByTicker[_ticker] = lines;
    notifyListeners();
    _save();
  }

  /// 앱 시작 시 SharedPreferences에서 라인 복원
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final Map<String, dynamic> decoded = json.decode(raw);
      for (final entry in decoded.entries) {
        _linesByTicker[entry.key] = (entry.value as List)
            .map((e) => ChartLineInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      for (final entry in _linesByTicker.entries)
        if (entry.value.isNotEmpty)
          entry.key: entry.value.map((l) => l.toJson()).toList(),
    };
    await prefs.setString(_kKey, json.encode(data));
  }
}
