import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';
import '../core/api_client.dart';
import '../models/price.dart';

class PriceProvider extends ChangeNotifier {
  PriceData? _price;
  bool _loading = false;
  String? _error;
  WebSocketChannel? _channel;
  String? _connectedTicker;

  PriceData? get price => _price;
  bool get loading => _loading;
  String? get error => _error;
  bool get isConnected => _channel != null;
  String? get connectedTicker => _connectedTicker;

  Future<void> fetchPrice(String ticker) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await ApiClient.instance.get('/api/v1/market/price/$ticker');
      _price = PriceData.fromJson(ticker, data);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void connectWs(String ticker) {
    disconnectWs();
    _connectedTicker = ticker;
    _channel = WebSocketChannel.connect(
      Uri.parse('$kWsBaseUrl/ws/price/$ticker'),
    );
    _channel!.stream.listen(
      (message) {
        try {
          final data = json.decode(message);
          _price = PriceData.fromJson(ticker, data);
          notifyListeners();
        } catch (_) {}
      },
      onError: (_) {
        _channel = null;
        _connectedTicker = null;
        notifyListeners();
      },
      onDone: () {
        _channel = null;
        _connectedTicker = null;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  void disconnectWs() {
    _channel?.sink.close();
    _channel = null;
    _connectedTicker = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
