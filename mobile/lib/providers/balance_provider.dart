import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../models/balance.dart';

class BalanceProvider extends ChangeNotifier {
  BalanceData? _balance;
  bool _loading = false;
  String? _error;

  BalanceData? get balance => _balance;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchBalance() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/api/v1/account/balance');
      _balance = BalanceData.fromJson(data);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
