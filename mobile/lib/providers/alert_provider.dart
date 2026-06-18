import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/price_alert_model.dart';

class AlertProvider extends ChangeNotifier {
  List<PriceAlertModel> _alerts = [];
  bool _loading = false;
  String? _error;

  List<PriceAlertModel> get alerts => _alerts;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchAlerts() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/api/v1/orders/alerts');
      _alerts = (data as List).map((e) => PriceAlertModel.fromJson(e)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addAlert({
    required String ticker,
    required String side,
    required int quantity,
    int targetPrice = 0,
    int? lineStartTime,
    double? lineStartPrice,
    int? lineEndTime,
    double? lineEndPrice,
  }) async {
    final body = <String, dynamic>{
      'ticker': ticker,
      'target_price': targetPrice,
      'side': side,
      'quantity': quantity,
      if (lineStartTime != null) 'line_start_time': lineStartTime,
      if (lineStartPrice != null) 'line_start_price': lineStartPrice,
      if (lineEndTime != null) 'line_end_time': lineEndTime,
      if (lineEndPrice != null) 'line_end_price': lineEndPrice,
    };
    await ApiClient.instance.post('/api/v1/orders/alerts', body);
    await fetchAlerts();
  }

  Future<void> deleteAlert(String ticker) async {
    await ApiClient.instance.delete('/api/v1/orders/alerts/$ticker');
    _alerts.removeWhere((a) => a.ticker == ticker);
    notifyListeners();
  }
}
