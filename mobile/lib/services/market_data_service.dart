import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class MarketDataService {
  static String get _backend => kBaseUrl;
  static const _upbit = 'https://api.upbit.com/v1';

  static const _cryptoMarkets = {
    'BTC': 'KRW-BTC', 'ETH': 'KRW-ETH', 'XRP': 'KRW-XRP',
    'SOL': 'KRW-SOL', 'BNB': 'KRW-BNB', 'ADA': 'KRW-ADA',
    'DOGE': 'KRW-DOGE', 'AVAX': 'KRW-AVAX', 'SHIB': 'KRW-SHIB',
  };

  static bool isKoreanStock(String t) => RegExp(r'^\d{6}$').hasMatch(t);
  static bool isCrypto(String t) => _cryptoMarkets.containsKey(t.toUpperCase());

  // ── Current price ──────────────────────────────────────────────────────────

  static Future<PriceResult?> fetchPrice(String ticker) async {
    final t = ticker.toUpperCase();
    if (isKoreanStock(t)) return _fetchKis(t);
    if (isCrypto(t)) return _fetchUpbit(_cryptoMarkets[t]!);
    return null;
  }

  static Future<PriceResult?> _fetchKis(String ticker) async {
    try {
      final res = await http
          .get(Uri.parse('$_backend/api/v1/market/price/$ticker'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final o = jsonDecode(res.body) as Map<String, dynamic>;
      final sign = o['change_sign'] as String? ?? '3';
      final isUp = sign == '1' || sign == '2';
      final price = (o['current_price'] as num?)?.toDouble() ?? 0.0;
      final change = (o['change'] as num?)?.toDouble() ?? 0.0;
      final rate = (o['change_rate'] as num?)?.toDouble() ?? 0.0;
      return PriceResult(
        price: _fmtNum(price),
        change: '${change >= 0 ? '+' : ''}${_fmtNum(change.abs())}',
        pct: '${rate >= 0 ? '+' : ''}${rate.abs().toStringAsFixed(2)}%',
        isUp: isUp,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<PriceResult?> _fetchUpbit(String market) async {
    try {
      final res = await http
          .get(Uri.parse('$_upbit/ticker?markets=$market'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final d = jsonDecode(res.body)[0];
      final price = (d['trade_price'] as num).toDouble();
      final change = (d['signed_change_price'] as num).toDouble();
      final rate = (d['signed_change_rate'] as num).toDouble() * 100;
      return PriceResult(
        price: _fmtNum(price),
        change: '${change >= 0 ? '+' : ''}${_fmtNum(change.abs())}',
        pct: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
        isUp: change >= 0,
      );
    } catch (_) {
      return null;
    }
  }

  // ── OHLCV for mini chart (close prices only) ──────────────────────────────

  static Future<List<double>> fetchOhlcv(String ticker) =>
      fetchOhlcvRange(ticker, '모두');

  // range: '일봉' | '주봉' | '월봉' | '1년' | '5년' | '모두'
  static Future<List<double>> fetchOhlcvRange(String ticker, String range) async {
    final t = ticker.toUpperCase();
    if (isKoreanStock(t)) return _kisOhlcvRange(t, range);
    if (isCrypto(t)) return _upbitOhlcvRange(_cryptoMarkets[t]!, range);
    return _fakePrices(ticker, 30);
  }

  static Future<List<double>> _kisOhlcvRange(String ticker, String range) async {
    String interval;
    int maxCount;
    switch (range) {
      case '일봉': interval = '1d';  maxCount = 60;   break;
      case '주봉': interval = '1w';  maxCount = 104;  break;
      case '월봉': interval = '1mo'; maxCount = 60;   break;
      case '1년':  interval = '1d';  maxCount = 252;  break;
      case '5년':  interval = '1w';  maxCount = 260;  break;
      case '모두':
      default:     interval = '1d';  maxCount = 9999; break;
    }
    try {
      final res = await http
          .get(Uri.parse('$_backend/api/v1/market/ohlcv/$ticker?interval=$interval'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _fakePrices(ticker, 30);
      final List raw = jsonDecode(res.body) as List;
      final closes = raw
          .map((d) => (d['close'] as num?)?.toDouble() ?? 0.0)
          .where((v) => v > 0)
          .toList();
      if (closes.isEmpty) return _fakePrices(ticker, 30);
      return closes.length > maxCount ? closes.sublist(closes.length - maxCount) : closes;
    } catch (_) {
      return _fakePrices(ticker, 30);
    }
  }

  static Future<List<double>> _upbitOhlcvRange(String market, String range) async {
    String endpoint;
    int count;
    switch (range) {
      case '일봉': endpoint = 'days';   count = 60;  break;
      case '주봉': endpoint = 'weeks';  count = 104; break;
      case '월봉': endpoint = 'months'; count = 60;  break;
      case '1년':  endpoint = 'days';   count = 365; break;
      case '5년':  endpoint = 'weeks';  count = 260; break;
      case '모두':
      default:     endpoint = 'days';   count = 500; break;
    }
    try {
      final res = await http
          .get(Uri.parse('$_upbit/candles/$endpoint?market=$market&count=$count'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _fakePrices(market, 30);
      final List data = jsonDecode(res.body);
      return data
          .map<double>((d) => (d['trade_price'] as num).toDouble())
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return _fakePrices(market, 30);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _fmtNum(double v) {
    return v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  // Deterministic fake prices based on ticker hash (for non-supported tickers)
  static List<double> _fakePrices(String ticker, int count) {
    final seed = ticker.hashCode.abs() % 1000;
    double price = 50000.0 + seed * 100;
    final result = <double>[];
    for (int i = 0; i < count; i++) {
      final hash = (ticker.hashCode + i * 31) & 0xFFFFFF;
      final delta = ((hash % 200) - 98) * price * 0.003;
      price += delta;
      result.add(price);
    }
    return result;
  }
}

class PriceResult {
  final String price, change, pct;
  final bool isUp;
  const PriceResult({
    required this.price,
    required this.change,
    required this.pct,
    required this.isUp,
  });
}

// ── Symbol search — API 우선, 오프라인 폴백 ────────────────────────────────────

class SymbolDatabase {
  // 오프라인 폴백용 최소 목록
  static const _fallback = [
    SymbolInfo(ticker: '005930', name: '삼성전자',   sub: 'Samsung Electronics', exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '000660', name: 'SK하이닉스', sub: 'SK Hynix Inc',        exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '035420', name: '네이버',      sub: 'NAVER Corp',          exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: 'AAPL',   name: 'Apple',       sub: 'Apple Inc.',          exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'NVDA',   name: 'NVIDIA',      sub: 'NVIDIA Corp',         exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'BTC',    name: 'Bitcoin',     sub: 'Bitcoin / KRW',       exchange: 'Upbit',  category: '암호화폐'),
    SymbolInfo(ticker: 'ETH',    name: 'Ethereum',    sub: 'Ethereum / KRW',      exchange: 'Upbit',  category: '암호화폐'),
  ];

  static Future<List<SymbolInfo>> searchAsync(String query, String category) async {
    try {
      final uri = Uri.parse('$kBaseUrl/api/v1/market/search')
          .replace(queryParameters: {'q': query, 'category': category});
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return _localFilter(query, category);
      final List raw = jsonDecode(res.body) as List;
      return raw
          .map((d) => SymbolInfo(
                ticker:   d['ticker'] as String,
                name:     d['name'] as String,
                sub:      d['sub'] as String,
                exchange: d['exchange'] as String,
                category: d['category'] as String,
              ))
          .toList();
    } catch (_) {
      return _localFilter(query, category);
    }
  }

  static List<SymbolInfo> _localFilter(String query, String category) {
    final q = query.toLowerCase();
    return _fallback.where((s) {
      final matchCat = category == '전체' || s.category == category;
      final matchQ = q.isEmpty ||
          s.ticker.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q);
      return matchCat && matchQ;
    }).toList();
  }

  // 동기 검색은 폴백 전용 (왓치리스트 복원 등 ticker→name 매핑 용도)
  static SymbolInfo? findByTicker(String ticker) {
    try {
      return _fallback.firstWhere((s) => s.ticker == ticker);
    } catch (_) {
      return null;
    }
  }
}

class SymbolInfo {
  final String ticker, name, sub, exchange, category;
  const SymbolInfo({
    required this.ticker,
    required this.name,
    required this.sub,
    required this.exchange,
    required this.category,
  });
}
