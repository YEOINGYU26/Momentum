import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  Future<dynamic> get(String path) async {
    final res = await http.get(Uri.parse('$kBaseUrl$path'));
    _check(res);
    return json.decode(utf8.decode(res.bodyBytes));
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    _check(res);
    return json.decode(utf8.decode(res.bodyBytes));
  }

  Future<void> delete(String path) async {
    final res = await http.delete(Uri.parse('$kBaseUrl$path'));
    _check(res);
  }

  Future<dynamic> postEmpty(String path) async {
    final res = await http.post(Uri.parse('$kBaseUrl$path'));
    _check(res);
    return json.decode(utf8.decode(res.bodyBytes));
  }

  void _check(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }
}
