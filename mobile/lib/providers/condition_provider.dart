import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/compound_condition_model.dart';
import '../models/chart_line_info.dart';

class ConditionProvider extends ChangeNotifier {
  List<CompoundConditionModel> _rules = [];
  bool _loading = false;

  List<CompoundConditionModel> get rules => _rules;
  bool get loading => _loading;

  Future<void> fetchRules() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/api/v1/conditions');
      _rules = (data as List).map((e) => CompoundConditionModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addRule({
    required String ticker,
    required String side,
    required int quantity,
    required int intervalSeconds,
    required String timeframe,
    required List<ChartLineInfo> lineConditions,
    required bool useRsi,
    required int rsiBuyThr,
    required int rsiSellThr,
    required bool useMaCross,
    required bool useBollinger,
  }) async {
    final body = <String, dynamic>{
      'ticker': ticker,
      'side': side,
      'quantity': quantity,
      'interval_seconds': intervalSeconds,
      'timeframe': timeframe,
      'line_conditions': lineConditions.map((l) => {
        'start_time': l.startTime,
        'start_price': l.startPrice,
        'end_time': l.endTime,
        'end_price': l.endPrice,
      }).toList(),
      'indicator_conditions': [
        if (useRsi)       {'type': 'rsi', 'rsi_buy_thr': rsiBuyThr, 'rsi_sell_thr': rsiSellThr},
        if (useMaCross)   {'type': 'moving_average', 'rsi_buy_thr': 30, 'rsi_sell_thr': 70},
        if (useBollinger) {'type': 'scalping', 'rsi_buy_thr': 30, 'rsi_sell_thr': 70},
      ],
    };
    await ApiClient.instance.post('/api/v1/conditions', body);
    await fetchRules();
  }

  Future<void> deleteRule(String ruleId) async {
    await ApiClient.instance.delete('/api/v1/conditions/$ruleId');
    _rules.removeWhere((r) => r.ruleId == ruleId);
    notifyListeners();
  }
}
