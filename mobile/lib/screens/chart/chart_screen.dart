import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({super.key});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedTicker = '005930';
  String _selectedInterval = '1일';

  static const _intervals = ['1분', '5분', '15분', '1시간', '1일', '1주'];

  static const _quickPicks = [
    _Ticker('005930', '삼성전자'),
    _Ticker('000660', 'SK하이닉스'),
    _Ticker('AAPL', 'Apple'),
    _Ticker('TSLA', 'Tesla'),
    _Ticker('BTC', 'Bitcoin'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 4),
            _buildPriceInfo(),
            Expanded(child: _buildChart()),
            _buildStats(),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedTicker,
              style: const TextStyle(
                  color: AppColors.green, fontSize: 13, fontWeight: FontWeight.w600),
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
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
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
                    setState(() => _selectedTicker = v.trim().toUpperCase());
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
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = _quickPicks[i];
          final isSelected = _selectedTicker == t.code;
          return GestureDetector(
            onTap: () => setState(() => _selectedTicker = t.code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) {
          final interval = _intervals[i];
          final isSelected = _selectedInterval == interval;
          return GestureDetector(
            onTap: () => setState(() => _selectedInterval = interval),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildPriceInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text('73,200',
              style: TextStyle(
                  color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('+1,300  +1.81%',
                style: TextStyle(
                    color: AppColors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: CustomPaint(
        painter: _CandlestickPainter(),
        child: Container(),
      ),
    );
  }

  Widget _buildStats() {
    final stats = [
      _Stat('시가', '71,900'),
      _Stat('고가', '73,500'),
      _Stat('저가', '71,600'),
      _Stat('거래량', '18.2M'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: Color(0xFF252A34))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: stats
            .map((s) => Column(
                  children: [
                    Text(s.label,
                        style: const TextStyle(
                            color: AppColors.gray, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(s.value,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _Ticker {
  final String code, name;
  const _Ticker(this.code, this.name);
}

class _Stat {
  final String label, value;
  const _Stat(this.label, this.value);
}

// ─── Candlestick painter ──────────────────────────────────────────────────────

class _CandlestickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);

    // Generate fake OHLCV data
    final candles = <_Candle>[];
    double price = 71000;
    for (int i = 0; i < 40; i++) {
      final open = price;
      final move = (rng.nextDouble() - 0.48) * 800;
      price += move;
      final close = price;
      final high = math.max(open, close) + rng.nextDouble() * 400;
      final low = math.min(open, close) - rng.nextDouble() * 400;
      candles.add(_Candle(open: open, close: close, high: high, low: low));
    }

    final minP = candles.map((c) => c.low).reduce(math.min);
    final maxP = candles.map((c) => c.high).reduce(math.max);
    final range = maxP - minP;

    final candleW = size.width / candles.length;
    final bodyW = candleW * 0.6;

    double toY(double price) =>
        size.height - ((price - minP) / range) * size.height * 0.9 - size.height * 0.05;

    final upPaint = Paint()..color = AppColors.green;
    final downPaint = Paint()..color = AppColors.red;
    final wickPaint = Paint()..strokeWidth = 1;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isUp = c.close >= c.open;
      final paint = isUp ? upPaint : downPaint;
      wickPaint.color = isUp ? AppColors.green : AppColors.red;

      final x = i * candleW + candleW / 2;
      final bodyTop = toY(math.max(c.open, c.close));
      final bodyBot = toY(math.min(c.open, c.close));
      final bodyH = math.max(bodyBot - bodyTop, 1.0);

      // Wick
      canvas.drawLine(
        Offset(x, toY(c.high)),
        Offset(x, toY(c.low)),
        wickPaint,
      );
      // Body
      canvas.drawRect(
        Rect.fromLTWH(x - bodyW / 2, bodyTop, bodyW, bodyH),
        paint,
      );
    }

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF252A34)
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Candle {
  final double open, close, high, low;
  const _Candle({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
  });
}
