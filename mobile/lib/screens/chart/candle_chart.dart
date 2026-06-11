import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class CandleData {
  final int time;
  final double open, high, low, close, volume;

  const CandleData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory CandleData.fromJson(Map<String, dynamic> j) {
    double p(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    int t = 0;
    final ds =
        (j['stck_bsop_date'] ?? j['date'])?.toString() ?? '';
    if (ds.length == 8) {
      try {
        t = DateTime.utc(
          int.parse(ds.substring(0, 4)),
          int.parse(ds.substring(4, 6)),
          int.parse(ds.substring(6, 8)),
        ).millisecondsSinceEpoch ~/ 1000;
      } catch (_) {}
    }
    return CandleData(
      time: t,
      open: p(j['stck_oprc'] ?? j['open']),
      high: p(j['stck_hgpr'] ?? j['high']),
      low: p(j['stck_lwpr'] ?? j['low']),
      close: p(j['stck_clpr'] ?? j['close']),
      volume: p(j['acml_vol'] ?? j['volume']),
    );
  }
}

class CandleChart extends StatefulWidget {
  final List<CandleData> candles;
  final void Function(CandleData?)? onCrosshair;

  const CandleChart({super.key, required this.candles, this.onCrosshair});

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart> {
  static const double _minVisible = 10;
  static const double _maxVisible = 200;
  static const double _priceAxisW = 58;

  double _visibleCount = 60;
  double _scrollOffset = 0; // candles hidden from the right end (0 = latest)
  Offset? _crosshairPos;
  double _scaleStartVisible = 60;
  Size _size = Size.zero;

  List<CandleData> get _candles => widget.candles;

  @override
  void didUpdateWidget(CandleChart old) {
    super.didUpdateWidget(old);
    if (old.candles != widget.candles) _scrollOffset = 0;
  }

  double get _chartW => math.max(_size.width - _priceAxisW, 1);
  double get _candleW => _chartW / _visibleCount;

  ({int start, int end, double rightPad}) _range() {
    final max = math.max(0.0, _candles.length.toDouble() - _visibleCount);
    final off = _scrollOffset.clamp(0.0, max);
    final end = (_candles.length - off.toInt()).clamp(0, _candles.length);
    final start = (end - _visibleCount.ceil()).clamp(0, _candles.length);
    final visible = end - start;
    return (start: start, end: end, rightPad: _visibleCount - visible);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _size = c.biggest;
      return GestureDetector(
        onScaleStart: (_) => _scaleStartVisible = _visibleCount,
        onScaleUpdate: (d) => setState(() {
          if (d.pointerCount >= 2) {
            _visibleCount =
                (_scaleStartVisible / d.scale).clamp(_minVisible, _maxVisible);
          } else {
            final max =
                math.max(0.0, _candles.length.toDouble() - _visibleCount);
            _scrollOffset =
                (_scrollOffset - d.focalPointDelta.dx / _candleW)
                    .clamp(0.0, max);
          }
        }),
        onLongPressStart: (d) => _handleCrosshair(d.localPosition),
        onLongPressMoveUpdate: (d) => _handleCrosshair(d.localPosition),
        onLongPressEnd: (_) {
          setState(() => _crosshairPos = null);
          widget.onCrosshair?.call(null);
        },
        child: CustomPaint(
          size: _size,
          painter: _Painter(
            candles: _candles,
            visibleCount: _visibleCount,
            scrollOffset: _scrollOffset,
            crosshairPos: _crosshairPos,
          ),
        ),
      );
    });
  }

  void _handleCrosshair(Offset pos) {
    if (_candles.isEmpty) return;
    setState(() => _crosshairPos = pos);

    final r = _range();
    final visible = _candles.sublist(r.start, r.end);
    if (visible.isEmpty) return;
    final idx =
        ((pos.dx / _candleW) - r.rightPad).round().clamp(0, visible.length - 1);
    widget.onCrosshair?.call(visible[idx]);
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _Painter extends CustomPainter {
  final List<CandleData> candles;
  final double visibleCount;
  final double scrollOffset;
  final Offset? crosshairPos;

  static const _priceAxisW = 58.0;
  static const _timeAxisH = 26.0;
  static const _volRatio = 0.18;

  _Painter({
    required this.candles,
    required this.visibleCount,
    required this.scrollOffset,
    required this.crosshairPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final chartW = size.width - _priceAxisW;
    final usableH = size.height - _timeAxisH;
    final priceH = usableH * (1 - _volRatio);
    final volH = usableH * _volRatio;
    final candleW = chartW / visibleCount;

    // Visible slice
    final maxOff = math.max(0.0, candles.length.toDouble() - visibleCount);
    final off = scrollOffset.clamp(0.0, maxOff);
    final end = (candles.length - off.toInt()).clamp(0, candles.length);
    final start = (end - visibleCount.ceil()).clamp(0, candles.length);
    final vis = candles.sublist(start, end);
    if (vis.isEmpty) return;

    final rightPad = visibleCount - vis.length; // empty slots on left

    // Price + volume range
    double lo = vis[0].low, hi = vis[0].high, maxVol = vis[0].volume;
    for (final c in vis) {
      if (c.low < lo) lo = c.low;
      if (c.high > hi) hi = c.high;
      if (c.volume > maxVol) maxVol = c.volume;
    }
    final pad = (hi - lo) * 0.06;
    final pMin = lo - pad;
    final pMax = hi + pad;
    final pSpan = pMax - pMin;
    if (pSpan <= 0) return;

    py(double p) => priceH - (p - pMin) / pSpan * priceH;
    double vy(double v) => maxVol > 0 ? (v / maxVol) * volH * 0.9 : 0;

    // ── Grid ────────────────────────────────────────────────────────
    final grid = Paint()
      ..color = const Color(0xFF252A34)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 5; i++) {
      final y = priceH * i / 5;
      canvas.drawLine(Offset(0, y), Offset(chartW, y), grid);
    }
    canvas.drawLine(Offset(0, priceH), Offset(chartW, priceH), grid);

    // ── Candles ─────────────────────────────────────────────────────
    for (var i = 0; i < vis.length; i++) {
      final c = vis[i];
      final x = (rightPad + i + 0.5) * candleW;
      final isUp = c.close >= c.open;
      final col = isUp ? AppColors.green : AppColors.red;
      final bw = math.max(candleW * 0.65, 1.0);

      // Wick
      canvas.drawLine(Offset(x, py(c.high)), Offset(x, py(c.low)),
          Paint()
            ..color = col
            ..strokeWidth = math.max(candleW * 0.12, 0.8));

      // Body
      final top = py(math.max(c.open, c.close));
      final bot = py(math.min(c.open, c.close));
      canvas.drawRect(
        Rect.fromLTWH(x - bw / 2, top, bw, math.max(bot - top, 1.0)),
        Paint()..color = col,
      );

      // Volume bar
      final vh = vy(c.volume);
      canvas.drawRect(
        Rect.fromLTWH(x - bw / 2, priceH + volH - vh, bw, vh),
        Paint()..color = col.withValues(alpha: 0.35),
      );
    }

    // ── Price axis ──────────────────────────────────────────────────
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 4; i++) {
      final price = pMax - pSpan * i / 4;
      final y = priceH * i / 4;
      tp.text = TextSpan(
          text: _fmt(price),
          style: const TextStyle(color: AppColors.gray, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset(chartW + 4, y - tp.height / 2));
    }

    // ── Time axis ───────────────────────────────────────────────────
    final step = math.max(1, (vis.length / 5).round());
    for (var i = 0; i < vis.length; i += step) {
      final x = (rightPad + i + 0.5) * candleW;
      final dt =
          DateTime.fromMillisecondsSinceEpoch(vis[i].time * 1000, isUtc: true);
      tp.text = TextSpan(
          text: '${dt.month}/${dt.day}',
          style: const TextStyle(color: AppColors.gray, fontSize: 10));
      tp.layout();
      if (x + tp.width / 2 < chartW) {
        tp.paint(canvas, Offset(x - tp.width / 2, usableH + 4));
      }
    }

    // ── Crosshair ───────────────────────────────────────────────────
    if (crosshairPos != null) {
      final pos = crosshairPos!;
      final slotF = pos.dx / candleW - rightPad;
      final slot = slotF.round().clamp(0, vis.length - 1);
      final sx = (rightPad + slot + 0.5) * candleW;
      final c = vis[slot];

      final ch = Paint()
        ..color = AppColors.gray.withValues(alpha: 0.5)
        ..strokeWidth = 0.5;

      canvas.drawLine(Offset(sx, 0), Offset(sx, usableH), ch);

      if (pos.dy >= 0 && pos.dy < priceH) {
        canvas.drawLine(Offset(0, pos.dy), Offset(chartW, pos.dy), ch);

        // Price label on axis
        final price = pMin + (1 - pos.dy / priceH) * pSpan;
        _axisLabel(canvas, chartW + 4, pos.dy, _fmt(price), center: false);
      }

      // Time label
      final dt =
          DateTime.fromMillisecondsSinceEpoch(c.time * 1000, isUtc: true);
      _axisLabel(canvas, sx, usableH + 4,
          '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}',
          center: true);
    }
  }

  void _axisLabel(Canvas canvas, double x, double y, String text,
      {required bool center}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = center ? x - tp.width / 2 : x;
    final ly = center ? y : y - tp.height / 2;
    canvas.drawRect(
      Rect.fromLTWH(lx - 2, ly - 1, tp.width + 4, tp.height + 2),
      Paint()..color = const Color(0xFF252A34),
    );
    tp.paint(canvas, Offset(lx, ly));
  }

  String _fmt(double p) {
    if (p >= 1e6) return '${(p / 1e6).toStringAsFixed(2)}M';
    if (p >= 1000) {
      return p.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    }
    if (p < 1) return p.toStringAsFixed(4);
    return p.toStringAsFixed(2);
  }

  @override
  bool shouldRepaint(_Painter old) =>
      candles != old.candles ||
      visibleCount != old.visibleCount ||
      scrollOffset != old.scrollOffset ||
      crosshairPos != old.crosshairPos;
}
