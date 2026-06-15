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
    // datetime: YYYYMMDDHHMMSS (분봉), date/stck_bsop_date: YYYYMMDD (일봉)
    final ds = (j['datetime'] ?? j['stck_bsop_date'] ?? j['date'])?.toString() ?? '';
    if (ds.length >= 8) {
      try {
        final year = int.parse(ds.substring(0, 4));
        final month = int.parse(ds.substring(4, 6));
        final day = int.parse(ds.substring(6, 8));
        int hour = 0, minute = 0, second = 0;
        if (ds.length >= 14) {
          hour = int.parse(ds.substring(8, 10));
          minute = int.parse(ds.substring(10, 12));
          second = int.parse(ds.substring(12, 14));
        }
        t = DateTime.utc(year, month, day, hour, minute, second)
            .millisecondsSinceEpoch ~/ 1000;
      } catch (_) {}
    }
    return CandleData(
      time: t,
      open: p(j['stck_oprc'] ?? j['open']),
      high: p(j['stck_hgpr'] ?? j['high']),
      low: p(j['stck_lwpr'] ?? j['low']),
      close: p(j['stck_clpr'] ?? j['close'] ?? j['stck_prpr']),
      volume: p(j['acml_vol'] ?? j['volume'] ?? j['cntg_vol']),
    );
  }
}

class CandleChart extends StatefulWidget {
  final List<CandleData> candles;
  final void Function(CandleData?)? onCrosshair;
  final String pricePrefix;

  const CandleChart({
    super.key,
    required this.candles,
    this.onCrosshair,
    this.pricePrefix = '',
  });

  @override
  State<CandleChart> createState() => _CandleChartState();
}

class _CandleChartState extends State<CandleChart> {
  static const double _minVisible = 10;
  static const double _maxVisible = 200;
  static const double _priceAxisW = 58;

  // Horizontal
  double _visibleCount = 60;
  double _scrollOffset = 0;
  double _scaleStartVisible = 60;

  // Vertical (price zoom)
  double _priceZoom = 1.0;
  double _scaleStartPriceZoom = 1.0;

  // Crosshair — null = hidden, non-null = visible (sticky)
  Offset? _crosshairPos;

  // Gesture zone detection
  bool _gestureInPriceAxis = false;
  bool _isLongPressing = false;

  // 크로스헤어 상대 이동용
  Offset? _longPressStartFinger;
  Offset? _crosshairAtPressStart;

  Size _size = Size.zero;

  List<CandleData> get _candles => widget.candles;

  @override
  void didUpdateWidget(CandleChart old) {
    super.didUpdateWidget(old);
    if (old.candles != widget.candles) {
      _scrollOffset = 0;
      _priceZoom = 1.0;
    }
  }

  double get _chartW => math.max(_size.width - _priceAxisW, 1);
  double get _candleW => _chartW / _visibleCount;

  ({int start, int end, double rightPad}) _range() {
    final max = math.max(0.0, _candles.length.toDouble() - _visibleCount);
    final off = _scrollOffset.clamp(0.0, max);
    final end = (_candles.length - off.toInt()).clamp(0, _candles.length);
    final start = (end - _visibleCount.ceil()).clamp(0, _candles.length);
    return (start: start, end: end, rightPad: _visibleCount - (end - start));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _size = c.biggest;
      return GestureDetector(
        // ── Pan / Zoom ──────────────────────────────────────────────
        onScaleStart: (d) {
          _gestureInPriceAxis = d.localFocalPoint.dx > _chartW;
          _scaleStartVisible = _visibleCount;
          _scaleStartPriceZoom = _priceZoom;
        },
        onScaleUpdate: (d) {
          if (_gestureInPriceAxis) {
            setState(() {
              if (d.pointerCount >= 2) {
                _priceZoom = (_scaleStartPriceZoom * d.scale).clamp(0.15, 10.0);
              } else {
                _priceZoom = (_priceZoom *
                        math.exp(-d.focalPointDelta.dy / 80))
                    .clamp(0.15, 10.0);
              }
            });
            return;
          }
          if (d.pointerCount >= 2) {
            setState(() {
              _visibleCount = (_scaleStartVisible / d.scale)
                  .clamp(_minVisible, _maxVisible);
            });
            return;
          }
          // 단일 손가락 슬라이드: 롱프레스 중이 아니면 십자선 제거 + 패닝
          if (_isLongPressing) return;
          final hadCrosshair = _crosshairPos != null;
          setState(() {
            if (hadCrosshair) _crosshairPos = null;
            final max = math.max(0.0, _candles.length.toDouble() - _visibleCount);
            _scrollOffset =
                (_scrollOffset + d.focalPointDelta.dx / _candleW)
                    .clamp(0.0, max);
          });
          if (hadCrosshair) widget.onCrosshair?.call(null);
        },
        // ── Crosshair ───────────────────────────────────────────────
        onLongPressStart: (d) {
          _isLongPressing = true;
          _longPressStartFinger = d.localPosition;
          if (_crosshairPos == null) {
            // 십자선 없으면 누른 위치에 생성
            _showCrosshair(d.localPosition);
          }
          _crosshairAtPressStart = _crosshairPos;
        },
        onLongPressMoveUpdate: (d) {
          final startFinger = _longPressStartFinger;
          final startCrosshair = _crosshairAtPressStart;
          if (startFinger == null || startCrosshair == null) {
            _showCrosshair(d.localPosition);
            return;
          }
          // 손가락 이동량만큼 기존 십자선 위치에서 상대 이동
          final delta = d.localPosition - startFinger;
          _showCrosshair(startCrosshair + delta);
        },
        onLongPressEnd: (_) {
          _isLongPressing = false;
          _longPressStartFinger = null;
          _crosshairAtPressStart = null;
          // 십자선 유지
        },
        onTap: () {
          // Tap dismisses the crosshair
          if (_crosshairPos != null) {
            setState(() => _crosshairPos = null);
            widget.onCrosshair?.call(null);
          }
        },

        child: CustomPaint(
          size: _size,
          painter: _Painter(
            candles: _candles,
            visibleCount: _visibleCount,
            scrollOffset: _scrollOffset,
            priceZoom: _priceZoom,
            crosshairPos: _crosshairPos,
            pricePrefix: widget.pricePrefix,
          ),
        ),
      );
    });
  }

  void _showCrosshair(Offset pos) {
    if (_candles.isEmpty) return;
    final r = _range();
    final visible = _candles.sublist(r.start, r.end);
    if (visible.isEmpty) return;

    // Snap x to nearest candle center
    final rawSlot = pos.dx / _candleW - r.rightPad;
    final slot = rawSlot.round().clamp(0, visible.length - 1);
    final snappedX = (r.rightPad + slot + 0.5) * _candleW;

    setState(() => _crosshairPos = Offset(snappedX, pos.dy));
    widget.onCrosshair?.call(visible[slot]);
  }
}

// ─── Painter ──────────────────────────────────────────────────────────────────

class _Painter extends CustomPainter {
  final List<CandleData> candles;
  final double visibleCount;
  final double scrollOffset;
  final double priceZoom;
  final Offset? crosshairPos;
  final String pricePrefix;

  static const _priceAxisW = 58.0;
  static const _timeAxisH = 26.0;
  static const _volRatio = 0.18;

  _Painter({
    required this.candles,
    required this.visibleCount,
    required this.scrollOffset,
    required this.priceZoom,
    required this.crosshairPos,
    this.pricePrefix = '',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    // 차트 영역 밖으로 캔들이 삐져나오지 않도록 클립
    canvas.save();
    canvas.clipRect(Offset.zero & size);

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

    final rightPad = visibleCount - vis.length;

    // Auto price range from visible candles
    double lo = vis[0].low, hi = vis[0].high, maxVol = vis[0].volume;
    for (final c in vis) {
      if (c.low < lo) lo = c.low;
      if (c.high > hi) hi = c.high;
      if (c.volume > maxVol) maxVol = c.volume;
    }
    final pad = (hi - lo) * 0.06;
    final autoMin = lo - pad;
    final autoMax = hi + pad;
    final autoCenter = (autoMin + autoMax) / 2;
    final autoHalf = (autoMax - autoMin) / 2;

    // Apply vertical zoom (priceZoom > 1 = zoomed in = smaller range)
    final zoomedHalf = autoHalf / priceZoom;
    final pMin = autoCenter - zoomedHalf;
    final pMax = autoCenter + zoomedHalf;
    final pSpan = pMax - pMin;
    if (pSpan <= 0) return;

    double py(double p) => priceH - (p - pMin) / pSpan * priceH;
    double vy(double v) => maxVol > 0 ? (v / maxVol) * volH * 0.9 : 0;

    // ── Grid ────────────────────────────────────────────────────────
    final grid = Paint()
      ..color = const Color(0xFF252A34)
      ..strokeWidth = 0.5;
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(Offset(0, priceH * i / 5), Offset(chartW, priceH * i / 5), grid);
    }
    canvas.drawLine(Offset(0, priceH), Offset(chartW, priceH), grid);

    // ── Candles ─────────────────────────────────────────────────────
    for (var i = 0; i < vis.length; i++) {
      final c = vis[i];
      final x = (rightPad + i + 0.5) * candleW;
      final isUp = c.close >= c.open;
      final col = isUp ? AppColors.green : AppColors.red;
      final bw = math.max(candleW * 0.65, 1.0);

      canvas.drawLine(
        Offset(x, py(c.high)),
        Offset(x, py(c.low)),
        Paint()
          ..color = col
          ..strokeWidth = math.max(candleW * 0.12, 0.8),
      );

      final top = py(math.max(c.open, c.close));
      final bot = py(math.min(c.open, c.close));
      canvas.drawRect(
        Rect.fromLTWH(x - bw / 2, top, bw, math.max(bot - top, 1.0)),
        Paint()..color = col,
      );

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
    // 분봉/일봉 자동 감지: 연속 캔들 간격이 2시간 미만이면 분봉
    final isIntraday = vis.length >= 2 &&
        (vis.last.time - vis.first.time) < 7200;
    String _timeFmt(int unixSec) {
      final dt = DateTime.fromMillisecondsSinceEpoch(unixSec * 1000, isUtc: true);
      if (isIntraday) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.month}/${dt.day}';
    }
    final step = math.max(1, (vis.length / 5).round());
    for (var i = 0; i < vis.length; i += step) {
      final x = (rightPad + i + 0.5) * candleW;
      tp.text = TextSpan(
          text: _timeFmt(vis[i].time),
          style: const TextStyle(color: AppColors.gray, fontSize: 10));
      tp.layout();
      if (x + tp.width / 2 < chartW) {
        tp.paint(canvas, Offset(x - tp.width / 2, usableH + 4));
      }
    }

    // ── Crosshair (dashed) ──────────────────────────────────────────
    if (crosshairPos != null) {
      final pos = crosshairPos!;
      final slot = ((pos.dx / candleW) - rightPad)
          .round()
          .clamp(0, vis.length - 1);
      final sx = (rightPad + slot + 0.5) * candleW;
      final c = vis[slot];

      final dash = Paint()
        ..color = AppColors.gray.withValues(alpha: 0.7)
        ..strokeWidth = 0.8;

      // Vertical dashed line (snapped to candle center)
      _dashed(canvas, Offset(sx, 0), Offset(sx, usableH), dash);

      // Horizontal dashed line (at touch y, price area only)
      if (pos.dy >= 0 && pos.dy < priceH) {
        _dashed(canvas, Offset(0, pos.dy), Offset(chartW, pos.dy), dash);
        final price = pMin + (1 - pos.dy / priceH) * pSpan;
        _axisLabel(canvas, chartW + 4, pos.dy, _fmt(price), center: false);
      }

      // Time label at bottom
      final dtc = DateTime.fromMillisecondsSinceEpoch(c.time * 1000, isUtc: true);
      final crossLabel = isIntraday
          ? '${dtc.hour.toString().padLeft(2, '0')}:${dtc.minute.toString().padLeft(2, '0')}'
          : '${dtc.year}/${dtc.month.toString().padLeft(2, '0')}/${dtc.day.toString().padLeft(2, '0')}';
      _axisLabel(canvas, sx, usableH + 4, crossLabel, center: true);
    }
    canvas.restore();
  }

  void _dashed(Canvas canvas, Offset p1, Offset p2, Paint paint,
      {double dash = 4, double gap = 4}) {
    final d = p2 - p1;
    final len = d.distance;
    if (len == 0) return;
    final unit = d / len;
    double pos = 0;
    bool draw = true;
    while (pos < len) {
      final seg = math.min(pos + (draw ? dash : gap), len);
      if (draw) {
        canvas.drawLine(p1 + unit * pos, p1 + unit * seg, paint);
      }
      pos = seg;
      draw = !draw;
    }
  }

  void _axisLabel(Canvas canvas, double x, double y, String text,
      {required bool center}) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500)),
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
    final String n;
    if (p >= 1e6) {
      n = '${(p / 1e6).toStringAsFixed(2)}M';
    } else if (p >= 1000) {
      n = p.toStringAsFixed(0)
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    } else if (p < 1) {
      n = p.toStringAsFixed(4);
    } else {
      n = p.toStringAsFixed(2);
    }
    return '$pricePrefix$n';
  }

  @override
  bool shouldRepaint(_Painter old) =>
      candles != old.candles ||
      visibleCount != old.visibleCount ||
      scrollOffset != old.scrollOffset ||
      priceZoom != old.priceZoom ||
      crosshairPos != old.crosshairPos ||
      pricePrefix != old.pricePrefix;
}
