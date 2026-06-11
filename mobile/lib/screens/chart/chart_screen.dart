import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/app_colors.dart';
import '../../providers/chart_provider.dart';
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

  static const _intervals = ['1분', '5분', '15분', '1시간', '1일', '1주'];

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
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _fetchCandles());
  }

  Future<void> _fetchCandles() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse(
              'https://358f13bb37fe73.lhr.life/api/v1/market/ohlcv/$_currentTicker'))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final raw = jsonDecode(res.body) as List;
        final parsed = raw
            .map((d) => CandleData.fromJson(d as Map<String, dynamic>))
            .where((c) => c.time > 0)
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
        setState(() => _candles = parsed.isNotEmpty ? parsed : _demoCandles());
      }
    } catch (_) {
      if (mounted && _candles.isEmpty) {
        setState(() => _candles = _demoCandles());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CandleData> _demoCandles() {
    final now = DateTime.now();
    final candles = <CandleData>[];
    double price = 70000;
    for (int i = 200; i >= 0; i--) {
      final t = now.subtract(Duration(days: i));
      final open = price;
      price += (i % 3 == 0 ? 1 : -1) * price * 0.015 *
          (0.5 + (i * 7 % 10) / 10);
      final close = price;
      final high = [open, close].reduce((a, b) => a > b ? a : b) *
          (1 + (i % 5) * 0.002);
      final low = [open, close].reduce((a, b) => a < b ? a : b) *
          (1 - (i % 4) * 0.002);
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
            _buildQuickPicks(),
            const SizedBox(height: 8),
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
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_loading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  color: AppColors.green, strokeWidth: 2),
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
                    color: AppColors.green,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: '종목 코드 검색...',
                  hintStyle: TextStyle(color: AppColors.gray),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) {
                    context
                        .read<ChartProvider>()
                        .setTicker(v.trim().toUpperCase());
                    _searchCtrl.clear();
                  }
                },
              ),
            ),
          ],
        ),
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _quickPicks[i];
          final sel = _currentTicker == t.code;
          return GestureDetector(
            onTap: () => context.read<ChartProvider>().setTicker(t.code),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.green.withValues(alpha: 0.15)
                    : AppColors.card,
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
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _intervals.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final iv = _intervals[i];
          final sel = _selectedInterval == iv;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedInterval = iv);
              _fetchCandles();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
    );
  }

  Widget _buildLegend(CandleData c) {
    final isUp = c.close >= c.open;
    final col = isUp ? AppColors.green : AppColors.red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Row(children: [
        _lg('O', c.open),
        const SizedBox(width: 14),
        _lg('H', c.high, AppColors.green),
        const SizedBox(width: 14),
        _lg('L', c.low, AppColors.red),
        const SizedBox(width: 14),
        _lg('C', c.close, col),
      ]),
    );
  }

  Widget _lg(String label, double value, [Color? color]) {
    String fmt(double v) {
      if (v >= 1000) {
        return v.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
      }
      if (v < 1) return v.toStringAsFixed(4);
      return v.toStringAsFixed(2);
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
                      style:
                          TextStyle(color: AppColors.gray, fontSize: 14)),
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

    return CandleChart(
      candles: _candles,
      onCrosshair: (c) => setState(() => _crosshairCandle = c),
    );
  }
}

class _Ticker {
  final String code, name;
  const _Ticker(this.code, this.name);
}
