import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/app_colors.dart';
import '../../providers/chart_provider.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedInterval = '1일';
  String _currentTicker = '005930';
  bool _chartReady = false;
  Map<String, dynamic>? _crosshairData;

  late final WebViewController _webController;

  static const _intervals = ['1분', '5분', '15분', '1시간', '1일', '1주'];

  static const _quickPicks = [
    _Ticker('005930', '삼성전자'),
    _Ticker('000660', 'SK하이닉스'),
    _Ticker('AAPL', 'Apple'),
    _Ticker('TSLA', 'Tesla'),
    _Ticker('BTC', 'Bitcoin'),
  ];

  static const _intervalCodes = {
    '1분': 'D',
    '5분': 'D',
    '15분': 'D',
    '1시간': 'D',
    '1일': 'D',
    '1주': 'W',
  };

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..addJavaScriptChannel(
        'ChartChannel',
        onMessageReceived: (msg) {
          if (!mounted) return;
          setState(() {
            _crosshairData = jsonDecode(msg.message) as Map<String, dynamic>;
          });
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _chartReady = true;
          _loadChartData();
        },
      ))
      ..loadFlutterAsset('assets/chart.html');
  }

  Future<void> _loadChartData() async {
    if (!_chartReady || !mounted) return;
    final code = _intervalCodes[_selectedInterval] ?? 'D';
    try {
      final res = await http
          .get(Uri.parse(
              'http://localhost:8000/api/v1/market/ohlcv/$_currentTicker?period_div_code=$code'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final raw = jsonDecode(res.body) as List;
      final candles = <Map<String, dynamic>>[];
      final volumes = <Map<String, dynamic>>[];

      for (final d in raw) {
        final t = _dateToUnix(
            d['stck_bsop_date']?.toString() ?? d['date']?.toString() ?? '');
        if (t == 0) continue;
        final o = _num(d['stck_oprc'] ?? d['open']);
        final h = _num(d['stck_hgpr'] ?? d['high']);
        final l = _num(d['stck_lwpr'] ?? d['low']);
        final c = _num(d['stck_clpr'] ?? d['close']);
        final v = _num(d['acml_vol'] ?? d['volume']);
        candles.add({'time': t, 'open': o, 'high': h, 'low': l, 'close': c});
        volumes.add({
          'time': t,
          'value': v,
          'color': c >= o ? 'rgba(0,229,160,0.25)' : 'rgba(237,64,64,0.25)',
        });
      }

      candles.sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));
      volumes.sort((a, b) => (a['time'] as int).compareTo(b['time'] as int));

      if (candles.isEmpty) return;

      await _webController.runJavaScript(
        'updateChart(${jsonEncode({'candles': candles, 'volumes': volumes})})',
      );
    } catch (_) {
      // Keep HTML demo data on error
    }
  }

  int _dateToUnix(String s) {
    if (s.length != 8) return 0;
    try {
      return DateTime.utc(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
      ).millisecondsSinceEpoch ~/ 1000;
    } catch (_) {
      return 0;
    }
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  String _fmt(dynamic v) {
    final d = _num(v);
    if (d == 0) return '—';
    if (d >= 1000) {
      return d
          .toStringAsFixed(0)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    }
    if (d < 1) return d.toStringAsFixed(4);
    return d.toStringAsFixed(2);
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
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadChartData();
      });
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
            if (_crosshairData != null) _buildLegend(),
            Expanded(child: WebViewWidget(controller: _webController)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _currentTicker,
              style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
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
          final isSelected = _currentTicker == t.code;
          return GestureDetector(
            onTap: () => context.read<ChartProvider>().setTicker(t.code),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.green.withValues(alpha: 0.15)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: AppColors.green.withValues(alpha: 0.5))
                    : null,
              ),
              child: Text(t.code,
                  style: TextStyle(
                      color: isSelected ? AppColors.green : AppColors.gray,
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
          final interval = _intervals[i];
          final isSelected = _selectedInterval == interval;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedInterval = interval);
              _loadChartData();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(interval,
                  style: TextStyle(
                      color: isSelected ? AppColors.bg : AppColors.gray,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    final d = _crosshairData!;
    final close = _num(d['close']);
    final open = _num(d['open']);
    final isUp = close >= open;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
      child: Row(
        children: [
          _lgItem('O', d['open']),
          const SizedBox(width: 14),
          _lgItem('H', d['high'], AppColors.green),
          const SizedBox(width: 14),
          _lgItem('L', d['low'], AppColors.red),
          const SizedBox(width: 14),
          _lgItem('C', d['close'], isUp ? AppColors.green : AppColors.red),
        ],
      ),
    );
  }

  Widget _lgItem(String label, dynamic value, [Color? color]) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(color: AppColors.gray, fontSize: 11)),
          TextSpan(
              text: _fmt(value),
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Ticker {
  final String code, name;
  const _Ticker(this.code, this.name);
}
