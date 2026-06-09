import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketDataService {
  static const _backend = 'http://localhost:8000';
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
      final o = jsonDecode(res.body)['output'];
      final sign = o['prdy_vrss_sign'];
      final isUp = sign == '2' || sign == '1';
      return PriceResult(
        price: _fmtStr(o['stck_prpr'] ?? '0'),
        change: '${isUp ? '+' : ''}${_fmtStr(o['prdy_vrss'] ?? '0')}',
        pct: '${isUp ? '+' : ''}${o['prdy_ctrt'] ?? '0'}%',
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

  // ── OHLCV for chart ────────────────────────────────────────────────────────

  static Future<List<double>> fetchOhlcv(String ticker) async {
    final t = ticker.toUpperCase();
    if (isKoreanStock(t)) return _kisOhlcv(t);
    if (isCrypto(t)) return _upbitOhlcv(_cryptoMarkets[t]!);
    return _fakePrices(ticker, 30);
  }

  static Future<List<double>> _kisOhlcv(String ticker) async {
    try {
      final res = await http
          .get(Uri.parse('$_backend/api/v1/market/ohlcv/$ticker'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return _fakePrices(ticker, 30);
      final List raw = jsonDecode(res.body)['output2'] ?? [];
      final closes = raw
          .map((d) => double.tryParse(d['stck_clpr'] ?? '0') ?? 0)
          .where((v) => v > 0)
          .toList()
          .reversed
          .toList();
      return closes.isEmpty ? _fakePrices(ticker, 30) : closes;
    } catch (_) {
      return _fakePrices(ticker, 30);
    }
  }

  static Future<List<double>> _upbitOhlcv(String market) async {
    try {
      final res = await http
          .get(Uri.parse('$_upbit/candles/days?market=$market&count=30'))
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

  static String _fmtStr(String v) {
    final n = int.tryParse(v.replaceAll(',', '').replaceAll('-', ''));
    if (n == null) return v;
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

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

// ── Static symbol database for search ─────────────────────────────────────────

class SymbolDatabase {
  static const all = [
    SymbolInfo(ticker: 'KOSPI',  name: 'KOSPI Composite Index', sub: '코스피',            exchange: 'KRX',    category: '지수'),
    SymbolInfo(ticker: 'KOSDAQ', name: 'KOSDAQ Composite Index', sub: '코스닥',           exchange: 'KRX',    category: '지수'),
    SymbolInfo(ticker: 'SPX',    name: 'S&P 500 Index',          sub: 'S&P 500',          exchange: 'SPX',    category: '지수'),
    SymbolInfo(ticker: 'NDQ',    name: 'NASDAQ 100',             sub: 'US 100 Index',     exchange: 'NASDAQ', category: '지수'),
    SymbolInfo(ticker: 'NI225',  name: 'Nikkei 225',             sub: 'Nikkei 225 Index', exchange: 'OSE',    category: '지수'),
    // Korean stocks
    SymbolInfo(ticker: '005930', name: '삼성전자',   sub: 'Samsung Electronics', exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '000660', name: 'SK하이닉스', sub: 'SK Hynix Inc',        exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '035420', name: 'NAVER',      sub: 'NAVER Corp',         exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '035720', name: '카카오',     sub: 'Kakao Corp',         exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '005380', name: '현대차',     sub: 'Hyundai Motor',      exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '000270', name: '기아',       sub: 'Kia Corp',           exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '006400', name: '삼성SDI',   sub: 'Samsung SDI',        exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '051910', name: 'LG화학',    sub: 'LG Chem',            exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '207940', name: '삼성바이오로직스', sub: 'Samsung Biologics', exchange: 'KRX', category: '주식'),
    // Global stocks
    SymbolInfo(ticker: 'AAPL',   name: 'Apple',        sub: 'Apple Inc.',        exchange: 'NASDAQ', category: '주식'),
    SymbolInfo(ticker: 'MSFT',   name: 'Microsoft',    sub: 'Microsoft Corp',    exchange: 'NASDAQ', category: '주식'),
    SymbolInfo(ticker: 'NVDA',   name: 'NVIDIA',       sub: 'NVIDIA Corp',       exchange: 'NASDAQ', category: '주식'),
    SymbolInfo(ticker: 'TSLA',   name: 'Tesla',        sub: 'Tesla Inc.',        exchange: 'NASDAQ', category: '주식'),
    SymbolInfo(ticker: 'AMZN',   name: 'Amazon',       sub: 'Amazon.com Inc.',   exchange: 'NASDAQ', category: '주식'),
    SymbolInfo(ticker: 'GOOGL',  name: 'Alphabet',     sub: 'Alphabet Inc.',     exchange: 'NASDAQ', category: '주식'),
    SymbolInfo(ticker: 'META',   name: 'Meta',         sub: 'Meta Platforms Inc.',exchange: 'NASDAQ', category: '주식'),
    // Crypto
    SymbolInfo(ticker: 'BTC',  name: 'BTCKRW',  sub: 'Bitcoin / South Korean Won',   exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'ETH',  name: 'ETHKRW',  sub: 'Ethereum / South Korean Won',  exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'XRP',  name: 'XRPKRW',  sub: 'Ripple / South Korean Won',    exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'SOL',  name: 'SOLKRW',  sub: 'Solana / South Korean Won',    exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'BNB',  name: 'BNBKRW',  sub: 'BNB / South Korean Won',       exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'DOGE', name: 'DOGEKRW', sub: 'Dogecoin / South Korean Won',  exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'ADA',  name: 'ADAKRW',  sub: 'Cardano / South Korean Won',   exchange: 'Upbit', category: '암호화폐'),
    // FX
    SymbolInfo(ticker: 'USDKRW', name: 'USD/KRW', sub: 'US Dollar / Korean Won',      exchange: 'FX', category: '외환'),
    SymbolInfo(ticker: 'JPYKRW', name: 'JPY/KRW', sub: 'Japanese Yen / Korean Won',   exchange: 'FX', category: '외환'),
    SymbolInfo(ticker: 'EURKRW', name: 'EUR/KRW', sub: 'Euro / Korean Won',           exchange: 'FX', category: '외환'),
  ];

  static List<SymbolInfo> search(String query, String category) {
    final q = query.toLowerCase();
    return all.where((s) {
      final matchCat = category == '전체' || s.category == category;
      final matchQ = q.isEmpty ||
          s.ticker.toLowerCase().contains(q) ||
          s.name.toLowerCase().contains(q) ||
          s.sub.toLowerCase().contains(q);
      return matchCat && matchQ;
    }).toList();
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
