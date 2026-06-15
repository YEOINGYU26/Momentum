import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../providers/chart_provider.dart';
import '../../services/market_data_service.dart';
import 'candle_chart.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedInterval = '1일';
  String _currentTicker = '005930';
  List<CandleData> _candles = [];
  bool _loading = false;
  CandleData? _crosshairCandle;
  List<SymbolInfo> _suggestions = [];

  // 통화 토글
  String _currency = 'KRW';
  double _usdRate = 0.0;  // 1 KRW → USD 환율

  static const _intervals = ['1분', '5분', '15분', '1시간', '1일', '1주', '월봉', '1년봉', '전체'];
  static const _intervalParams = {
    '1분': '1m',
    '5분': '5m',
    '15분': '15m',
    '1시간': '1h',
    '1일': '1d',
    '1주': '1w',
    '월봉': '1mo',
    '1년봉': '1y',
    '전체': 'all',
  };

  static const _cryptoMarkets = {
    'BTC': 'KRW-BTC', 'ETH': 'KRW-ETH', 'XRP': 'KRW-XRP',
    'SOL': 'KRW-SOL', 'BNB': 'KRW-BNB', 'DOGE': 'KRW-DOGE', 'ADA': 'KRW-ADA',
  };

  bool get _isCrypto => _cryptoMarkets.containsKey(_currentTicker.toUpperCase());

  static const _quickPicks = [
    _Ticker('005930', '삼성전자'),
    _Ticker('000660', 'SK하이닉스'),
    _Ticker('AAPL', 'Apple'),
    _Ticker('TSLA', 'Tesla'),
    _Ticker('BTC', 'Bitcoin'),
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) => _fetchCandles());
    _fetchUsdRate();
  }

  Future<void> _fetchUsdRate() async {
    try {
      final res = await http.get(
        Uri.parse('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/krw.json'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rate = (data['krw']?['usd'] as num?)?.toDouble() ?? 0.0;
        if (mounted && rate > 0) setState(() => _usdRate = rate);
      }
    } catch (_) {}
  }

  List<CandleData> get _displayCandles {
    List<CandleData> candles = _candles;

    // 전체봉: 일봉 300개 초과 시 연봉으로 자동 집계 (한눈에 볼 수 있도록)
    if (_selectedInterval == '전체' && candles.length > 300) {
      candles = _aggregateToYearly(candles);
    }

    if (_currency == 'USD' && _usdRate > 0) {
      return candles.map((c) => CandleData(
        time: c.time,
        open:   c.open   * _usdRate,
        high:   c.high   * _usdRate,
        low:    c.low    * _usdRate,
        close:  c.close  * _usdRate,
        volume: c.volume,
      )).toList();
    }
    return candles;
  }

  String get _pricePrefix => _currency == 'USD' ? '\$' : '';

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _suggestions = SymbolDatabase.search(q, '전체').take(6).toList());
  }

  void _selectSymbol(SymbolInfo s) {
    context.read<ChartProvider>().setTicker(s.ticker);
    _searchCtrl.clear();
    setState(() => _suggestions = []);
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchCandles() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final candles = _isCrypto
          ? await _fetchUpbitCandles()
          : await _fetchKisCandles();
      if (!mounted) return;
      setState(() => _candles = candles.isNotEmpty ? candles : _demoCandles());
    } catch (_) {
      if (mounted && _candles.isEmpty) {
        setState(() => _candles = _demoCandles());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<CandleData>> _fetchKisCandles() async {
    final interval = _intervalParams[_selectedInterval] ?? '1d';
    // '전체'/'1년봉' 은 페이지네이션으로 여러 번 호출하므로 타임아웃을 늘림
    // 타임아웃: all/1y=120s, 1d/1w/1mo=30s, 나머지=8s
    final timeout = const {
      'all': 120, '1y': 60,
      '1d': 30, '1w': 30, '1mo': 20,
      '1m': 15, '5m': 20, '15m': 30, '1h': 30,
    };
    final res = await http
        .get(Uri.parse('$kBaseUrl/api/v1/market/ohlcv/$_currentTicker?interval=$interval'))
        .timeout(Duration(seconds: timeout[interval] ?? 8));
    if (res.statusCode != 200) return [];
    final raw = jsonDecode(res.body) as List;
    return raw
        .map((d) => CandleData.fromJson(d as Map<String, dynamic>))
        .where((c) => c.time > 0)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<List<CandleData>> _fetchUpbitCandles() async {
    final market = _cryptoMarkets[_currentTicker.toUpperCase()]!;
    String endpoint;
    int count;
    switch (_selectedInterval) {
      case '1분':   endpoint = 'minutes/1';  count = 200; break;
      case '5분':   endpoint = 'minutes/5';  count = 200; break;
      case '15분':  endpoint = 'minutes/15'; count = 200; break;
      case '1시간': endpoint = 'minutes/60'; count = 200; break;
      case '1주':   endpoint = 'weeks';      count = 200; break;
      case '월봉':  endpoint = 'months';     count = 200; break;
      case '1년봉': endpoint = 'months';     count = 200; break;
      case '전체':  endpoint = 'days';       count = 200; break;
      case '1일':
      default:      endpoint = 'days';       count = 200; break;
    }
    final res = await http
        .get(Uri.parse('https://api.upbit.com/v1/candles/$endpoint?market=$market&count=$count'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [];
    final List raw = jsonDecode(res.body);
    var candles = raw.map((d) => CandleData(
      time: DateTime.parse(d['candle_date_time_utc'] as String).millisecondsSinceEpoch ~/ 1000,
      open: (d['opening_price'] as num).toDouble(),
      high: (d['high_price'] as num).toDouble(),
      low: (d['low_price'] as num).toDouble(),
      close: (d['trade_price'] as num).toDouble(),
      volume: (d['candle_acc_trade_volume'] as num).toDouble(),
    )).toList()..sort((a, b) => a.time.compareTo(b.time));

    // '1년봉' for crypto: aggregate monthly → yearly
    if (_selectedInterval == '1년봉') {
      candles = _aggregateToYearly(candles);
    }
    return candles;
  }

  List<CandleData> _aggregateToYearly(List<CandleData> monthly) {
    final byYear = <int, List<CandleData>>{};
    for (final c in monthly) {
      final year = DateTime.fromMillisecondsSinceEpoch(c.time * 1000).year;
      byYear.putIfAbsent(year, () => []).add(c);
    }
    final result = <CandleData>[];
    for (final year in byYear.keys.toList()..sort()) {
      final cs = byYear[year]!;
      result.add(CandleData(
        time: DateTime(year, 1, 1).millisecondsSinceEpoch ~/ 1000,
        open: cs.first.open,
        high: cs.map((c) => c.high).reduce((a, b) => a > b ? a : b),
        low: cs.map((c) => c.low).reduce((a, b) => a < b ? a : b),
        close: cs.last.close,
        volume: cs.fold(0.0, (s, c) => s + c.volume),
      ));
    }
    return result;
  }

  List<CandleData> _demoCandles() {
    final now = DateTime.now();
    final candles = <CandleData>[];
    double price = 70000;
    for (int i = 200; i >= 0; i--) {
      final t = now.subtract(Duration(days: i));
      final open = price;
      price += (i % 3 == 0 ? 1 : -1) * price * 0.015 * (0.5 + (i * 7 % 10) / 10);
      final close = price;
      final high = [open, close].reduce((a, b) => a > b ? a : b) * (1 + (i % 5) * 0.002);
      final low = [open, close].reduce((a, b) => a < b ? a : b) * (1 - (i % 4) * 0.002);
      candles.add(CandleData(
        time: t.millisecondsSinceEpoch ~/ 1000,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 500000 + (i * 31337) % 1500000,
      ));
    }
    return candles;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticker = context.watch<ChartProvider>().ticker;
    if (ticker != _currentTicker) {
      _currentTicker = ticker;
      SchedulerBinding.instance
          .addPostFrameCallback((_) { if (mounted) _fetchCandles(); });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            if (_suggestions.isNotEmpty)
              _buildSuggestions()
            else ...[
              _buildQuickPicks(),
              const SizedBox(height: 8),
            ],
            _buildIntervalBar(),
            if (_crosshairCandle != null) _buildLegend(_crosshairCandle!),
            Expanded(child: _buildChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Text('차트',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_loading)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2),
            ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_currentTicker,
                style: const TextStyle(
                    color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
            color: AppColors.card, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.gray, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '종목명 또는 코드 검색...',
                  hintStyle: TextStyle(color: AppColors.gray),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (v) {
                  final q = v.trim();
                  if (q.isEmpty) return;
                  if (_suggestions.isNotEmpty) {
                    _selectSymbol(_suggestions.first);
                  } else {
                    context.read<ChartProvider>().setTicker(q.toUpperCase());
                    _searchCtrl.clear();
                  }
                },
              ),
            ),
            if (_suggestions.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  FocusScope.of(context).unfocus();
                },
                child: const Icon(Icons.close, color: AppColors.gray, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: _suggestions.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          BorderRadius radius = BorderRadius.zero;
          if (_suggestions.length == 1) {
            radius = BorderRadius.circular(12);
          } else if (i == 0) {
            radius = const BorderRadius.vertical(top: Radius.circular(12));
          } else if (i == _suggestions.length - 1) {
            radius = const BorderRadius.vertical(bottom: Radius.circular(12));
          }
          return Column(
            children: [
              if (i > 0)
                const Divider(height: 1, color: Color(0xFF252A34), indent: 16, endIndent: 16),
              InkWell(
                onTap: () => _selectSymbol(s),
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text(s.sub,
                                style: const TextStyle(color: AppColors.gray, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(s.ticker,
                              style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(s.exchange,
                              style: const TextStyle(color: AppColors.gray, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickPicks() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _quickPicks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _quickPicks[i];
          final sel = _currentTicker == t.code;
          return GestureDetector(
            onTap: () => context.read<ChartProvider>().setTicker(t.code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppColors.green.withValues(alpha: 0.15) : AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: sel
                    ? Border.all(color: AppColors.green.withValues(alpha: 0.5))
                    : null,
              ),
              child: Text(t.code,
                  style: TextStyle(
                      color: sel ? AppColors.green : AppColors.gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntervalBar() {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          // 스크롤 가능한 봉 선택 버튼
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20),
              itemCount: _intervals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final iv = _intervals[i];
                final sel = _selectedInterval == iv;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedInterval = iv);
                    _fetchCandles();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(iv,
                        style: TextStyle(
                            color: sel ? AppColors.bg : AppColors.gray,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          // 통화 단위 드롭다운: 가격축(58px) 폭에 맞춤
          if (!_isCrypto)
            SizedBox(width: 58, child: _buildCurrencyDropdown()),
        ],
      ),
    );
  }

  Widget _buildLegend(CandleData c) {
    final mult = (_currency == 'USD' && _usdRate > 0) ? _usdRate : 1.0;
    final isUp = c.close >= c.open;
    final col = isUp ? AppColors.green : AppColors.red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Row(children: [
        _lg('O', c.open  * mult),
        const SizedBox(width: 14),
        _lg('H', c.high  * mult, AppColors.green),
        const SizedBox(width: 14),
        _lg('L', c.low   * mult, AppColors.red),
        const SizedBox(width: 14),
        _lg('C', c.close * mult, col),
      ]),
    );
  }

  Widget _lg(String label, double value, [Color? color]) {
    String fmt(double v) {
      final pfx = _pricePrefix;
      final String n;
      if (v >= 1000) {
        n = v.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
      } else if (v < 1) {
        n = v.toStringAsFixed(4);
      } else {
        n = v.toStringAsFixed(2);
      }
      return '$pfx$n';
    }

    return RichText(
      text: TextSpan(children: [
        TextSpan(
            text: '$label ',
            style: const TextStyle(color: AppColors.gray, fontSize: 11)),
        TextSpan(
            text: fmt(value),
            style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildChart() {
    if (_candles.isEmpty) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator(color: AppColors.green)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bar_chart, color: AppColors.gray, size: 48),
                  const SizedBox(height: 12),
                  const Text('백엔드 서버를 시작하세요',
                      style: TextStyle(color: AppColors.gray, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _fetchCandles,
                    child: const Text('다시 시도',
                        style: TextStyle(color: AppColors.green)),
                  ),
                ],
              ),
      );
    }

    return ClipRect(
      child: CandleChart(
        candles: _displayCandles,
        pricePrefix: _pricePrefix,
        onCrosshair: (c) => setState(() => _crosshairCandle = c),
      ),
    );
  }

  Widget _buildCurrencyDropdown() {
    return PopupMenuButton<String>(
      initialValue: _currency,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      offset: const Offset(0, 34),
      color: const Color(0xFF1E2330),
      onSelected: (val) {
        setState(() => _currency = val);
        if (val == 'USD' && _usdRate == 0) _fetchUsdRate();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'KRW',
          height: 36,
          child: Text('₩  KRW', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
        PopupMenuItem(
          value: 'USD',
          height: 36,
          child: Text('\$  USD', style: TextStyle(color: Colors.white, fontSize: 13)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_currency,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down, color: AppColors.gray, size: 13),
          ],
        ),
      ),
    );
  }
}

class _Ticker {
  final String code, name;
  const _Ticker(this.code, this.name);
}
