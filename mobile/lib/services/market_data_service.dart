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

// ── Static symbol database for search ─────────────────────────────────────────

class SymbolDatabase {
  static const all = [
    // ── 코스피 대형주 ─────────────────────────────────────────────
    SymbolInfo(ticker: '005930', name: '삼성전자',         sub: 'Samsung Electronics',    exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '000660', name: 'SK하이닉스',       sub: 'SK Hynix Inc',           exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '005380', name: '현대차',           sub: 'Hyundai Motor',          exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '000270', name: '기아',             sub: 'Kia Corp',               exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '006400', name: '삼성SDI',          sub: 'Samsung SDI',            exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '051910', name: 'LG화학',           sub: 'LG Chem',                exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '066570', name: 'LG전자',           sub: 'LG Electronics',         exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '003550', name: 'LG',               sub: 'LG Corp',                exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '207940', name: '삼성바이오로직스', sub: 'Samsung Biologics',      exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '068270', name: '셀트리온',         sub: 'Celltrion',              exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '005490', name: 'POSCO홀딩스',      sub: 'POSCO Holdings',         exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '096770', name: 'SK이노베이션',     sub: 'SK Innovation',          exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '034730', name: 'SK',               sub: 'SK Holdings',            exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '017670', name: 'SK텔레콤',         sub: 'SK Telecom',             exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '030200', name: 'KT',               sub: 'KT Corp',                exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '015760', name: '한국전력',         sub: 'Korea Electric Power',   exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '028260', name: '삼성물산',         sub: 'Samsung C&T',            exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '012330', name: '현대모비스',       sub: 'Hyundai Mobis',          exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '105560', name: 'KB금융',           sub: 'KB Financial Group',     exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '055550', name: '신한지주',         sub: 'Shinhan Financial',      exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '086790', name: '하나금융지주',     sub: 'Hana Financial Group',   exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '316140', name: '우리금융지주',     sub: 'Woori Financial Group',  exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '032830', name: '삼성생명',         sub: 'Samsung Life Insurance', exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '003490', name: '대한항공',         sub: 'Korean Air',             exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '010950', name: 'S-Oil',            sub: 'S-Oil Corp',             exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '011200', name: 'HMM',              sub: 'HMM Co Ltd',             exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '004020', name: '현대제철',         sub: 'Hyundai Steel',          exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '010130', name: '고려아연',         sub: 'Korea Zinc',             exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '009150', name: '삼성전기',         sub: 'Samsung Electro-Mech',   exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '018880', name: '한온시스템',       sub: 'Hanon Systems',          exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '011790', name: 'SK케미칼',         sub: 'SK Chemicals',           exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '373220', name: 'LG에너지솔루션',   sub: 'LG Energy Solution',     exchange: 'KRX', category: '주식'),
    // ── 두산 그룹 ─────────────────────────────────────────────────
    SymbolInfo(ticker: '034020', name: '두산에너빌리티',   sub: 'Doosan Enerbility',      exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '241560', name: '두산밥캣',         sub: 'Doosan Bobcat',          exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '336260', name: '두산퓨얼셀',       sub: 'Doosan Fuel Cell',       exchange: 'KRX', category: '주식'),
    SymbolInfo(ticker: '000150', name: '두산',             sub: 'Doosan Corp',            exchange: 'KRX', category: '주식'),
    // ── 2차전지 / 반도체 ──────────────────────────────────────────
    SymbolInfo(ticker: '247540', name: '에코프로비엠',     sub: 'EcoPro BM',              exchange: 'KOSDAQ', category: '주식'),
    SymbolInfo(ticker: '086520', name: '에코프로',         sub: 'EcoPro',                 exchange: 'KOSDAQ', category: '주식'),
    SymbolInfo(ticker: '112610', name: '씨에스윈드',       sub: 'CS Wind',                exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '000990', name: 'DB하이텍',         sub: 'DB HiTek',               exchange: 'KRX',    category: '주식'),
    // ── 코스닥 대형주 ─────────────────────────────────────────────
    SymbolInfo(ticker: '035420', name: '네이버',            sub: 'NAVER Corp',             exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '035720', name: '카카오',           sub: 'Kakao Corp',             exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '323410', name: '카카오뱅크',       sub: 'Kakao Bank',             exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '259960', name: '크래프톤',         sub: 'Krafton',                exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '251270', name: '넷마블',           sub: 'Netmarble',              exchange: 'KRX',    category: '주식'),
    SymbolInfo(ticker: '263750', name: '펄어비스',         sub: 'Pearl Abyss',            exchange: 'KOSDAQ', category: '주식'),
    SymbolInfo(ticker: '293490', name: '카카오게임즈',     sub: 'Kakao Games',            exchange: 'KOSDAQ', category: '주식'),
    SymbolInfo(ticker: '196170', name: '알테오젠',         sub: 'Alteogen',               exchange: 'KOSDAQ', category: '주식'),
    SymbolInfo(ticker: '091990', name: '셀트리온헬스케어', sub: 'Celltrion Healthcare',   exchange: 'KOSDAQ', category: '주식'),
    SymbolInfo(ticker: '357780', name: '솔브레인',         sub: 'Soulbrain',              exchange: 'KOSDAQ', category: '주식'),
    // ── 글로벌 주식 (참고용, 차트 데모) ──────────────────────────
    SymbolInfo(ticker: 'AAPL',  name: 'Apple',             sub: 'Apple Inc.',             exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'MSFT',  name: 'Microsoft',         sub: 'Microsoft Corp',         exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'NVDA',  name: 'NVIDIA',            sub: 'NVIDIA Corp',            exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'TSLA',  name: 'Tesla',             sub: 'Tesla Inc.',             exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'AMZN',  name: 'Amazon',            sub: 'Amazon.com Inc.',        exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'GOOGL', name: 'Alphabet',          sub: 'Alphabet Inc.',          exchange: 'NASDAQ', category: '해외주식'),
    SymbolInfo(ticker: 'META',  name: 'Meta',              sub: 'Meta Platforms Inc.',    exchange: 'NASDAQ', category: '해외주식'),
    // ── 암호화폐 (Upbit 실데이터) ─────────────────────────────────
    SymbolInfo(ticker: 'BTC',  name: 'Bitcoin',            sub: 'Bitcoin / KRW',          exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'ETH',  name: 'Ethereum',           sub: 'Ethereum / KRW',         exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'XRP',  name: 'Ripple',             sub: 'Ripple / KRW',           exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'SOL',  name: 'Solana',             sub: 'Solana / KRW',           exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'BNB',  name: 'BNB',                sub: 'BNB / KRW',              exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'DOGE', name: 'Dogecoin',           sub: 'Dogecoin / KRW',         exchange: 'Upbit', category: '암호화폐'),
    SymbolInfo(ticker: 'ADA',  name: 'Cardano',            sub: 'Cardano / KRW',          exchange: 'Upbit', category: '암호화폐'),
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
