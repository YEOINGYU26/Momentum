import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class CandleData {
  final int time;
  final double open, high, low, close, volume;
  const CandleData({
    required this.time, required this.open, required this.high,
    required this.low,  required this.close, required this.volume,
  });
  factory CandleData.fromJson(Map<String, dynamic> j) {
    double p(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }
    int t = 0;
    final ds = (j['datetime'] ?? j['stck_bsop_date'] ?? j['date'])?.toString() ?? '';
    if (ds.length >= 8) {
      try {
        final yr = int.parse(ds.substring(0, 4));
        final mo = int.parse(ds.substring(4, 6));
        final dy = int.parse(ds.substring(6, 8));
        int h = 0, m = 0, s = 0;
        if (ds.length >= 14) {
          h = int.parse(ds.substring(8,  10));
          m = int.parse(ds.substring(10, 12));
          s = int.parse(ds.substring(12, 14));
        }
        t = DateTime.utc(yr, mo, dy, h, m, s).millisecondsSinceEpoch ~/ 1000;
      } catch (_) {}
    }
    return CandleData(
      time:   t,
      open:   p(j['stck_oprc'] ?? j['open']),
      high:   p(j['stck_hgpr'] ?? j['high']),
      low:    p(j['stck_lwpr'] ?? j['low']),
      close:  p(j['stck_clpr'] ?? j['close'] ?? j['stck_prpr']),
      volume: p(j['acml_vol']  ?? j['volume'] ?? j['cntg_vol']),
    );
  }
}

// ─── Drawing types ────────────────────────────────────────────────────────────

enum DrawTool  { none, trendLine, hLine }
enum DrawPhase { idle, placingFirst, placingSecond, selected }
enum LineStyle { solid, dashed, dotted }

class ChartLine {
  final int    startTime, endTime;
  final double startPrice, endPrice;
  final Color  color;
  final bool   isHorizontal;
  final double width;
  final LineStyle style;

  const ChartLine({
    required this.startTime, required this.endTime,
    required this.startPrice, required this.endPrice,
    required this.color,
    this.isHorizontal = false,
    this.width = 1.5,
    this.style = LineStyle.solid,
  });

  ChartLine copyWith({Color? color, double? width, LineStyle? style}) => ChartLine(
    startTime: startTime, endTime: endTime,
    startPrice: startPrice, endPrice: endPrice,
    color: color ?? this.color, isHorizontal: isHorizontal,
    width: width ?? this.width, style: style ?? this.style,
  );
}

// ─── Widget ──────────────────────────────────────────────────────────────────

class CandleChart extends StatefulWidget {
  final List<CandleData> candles;
  final void Function(CandleData?)? onCrosshair;
  final String pricePrefix;

  const CandleChart({
    super.key, required this.candles,
    this.onCrosshair, this.pricePrefix = '',
  });

  @override
  State<CandleChart> createState() => _CandleChartState();
}

// ─── State ───────────────────────────────────────────────────────────────────

class _CandleChartState extends State<CandleChart> {
  static const double _minVis   = 10;
  static const double _maxVis   = 200;
  static const double _axisW    = 58;
  static const double _timeH    = 26;
  static const double _volR     = 0.18;
  static const double _indH     = 80;
  static const double _toolbarH = 36;
  static const double _propH    = 44;

  // scroll/zoom
  double _vis      = 60;
  double _scroll   = 0;
  double _startVis = 60;
  double _pzoom    = 1.0;
  double _startPz  = 1.0;

  // crosshair
  Offset? _cross;
  bool    _longPress     = false;
  Offset? _lpFinger;
  Offset? _lpCrossStart;
  Offset? _lastTouch;
  bool    _inPriceAxis   = false;

  // RSI
  bool _showRsi = false;

  // drawing
  DrawTool  _tool  = DrawTool.none;
  DrawPhase _phase = DrawPhase.idle;
  Color     _dColor = Colors.white;
  double    _dWidth = 1.5;
  LineStyle _dStyle = LineStyle.solid;
  Offset?   _cursor;
  int?      _fpTime;
  double?   _fpPrice;
  final List<ChartLine> _lines = [];
  int? _selIdx;

  Size _sz = Size.zero;

  List<CandleData> get _c => widget.candles;

  bool get _drawing =>
      _phase == DrawPhase.placingFirst || _phase == DrawPhase.placingSecond;

  double get _shownPropH =>
      (_phase == DrawPhase.selected && _selIdx != null) ? _propH : 0.0;

  double get _chartH => math.max(_sz.height - _toolbarH - _shownPropH, 1);
  double get _chartW => math.max(_sz.width  - _axisW, 1);
  double get _cw     => _chartW / _vis;

  @override
  void didUpdateWidget(CandleChart old) {
    super.didUpdateWidget(old);
    if (old.candles != widget.candles) {
      _scroll = 0; _pzoom = 1.0; _vis = 60; _cross = null;
    }
  }

  ({int s, int e, double rp}) _range() {
    final mx = math.max(0.0, _c.length.toDouble() - _vis);
    final off = _scroll.clamp(0.0, mx);
    final e   = (_c.length - off.toInt()).clamp(0, _c.length);
    final s   = (e - _vis.ceil()).clamp(0, _c.length);
    return (s: s, e: e, rp: _vis - (e - s));
  }

  double? _toPrice(double dy) {
    if (_c.isEmpty) return null;
    final r = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) return null;
    final usable = _chartH - _timeH - (_showRsi ? _indH : 0.0);
    final pH = usable * (1 - _volR);
    if (dy < 0 || dy > pH) return null;
    double lo = vis[0].low, hi = vis[0].high;
    for (final c in vis) { if (c.low < lo) lo = c.low; if (c.high > hi) hi = c.high; }
    final pad = (hi - lo) * 0.06;
    final cent = (hi + lo) / 2;
    final half = (hi - lo) / 2 + pad;
    final pMin = cent - half / _pzoom;
    final pMax = cent + half / _pzoom;
    return pMin + (1 - dy / pH) * (pMax - pMin);
  }

  int? _toTime(double dx) {
    if (_c.isEmpty) return null;
    final r   = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) return null;
    final slot = ((dx / _cw) - r.rp).round().clamp(0, vis.length - 1);
    return vis[slot].time;
  }

  Offset _snapCursor(Offset raw) {
    if (_c.isEmpty) return raw;
    final r   = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) return raw;
    final slot = ((raw.dx / _cw) - r.rp).round().clamp(0, vis.length - 1);
    return Offset((r.rp + slot + 0.5) * _cw, raw.dy);
  }

  // ── drawing actions ───────────────────────────────────────────────────
  void _activateTool(DrawTool tool) {
    setState(() {
      if (_tool == tool && _drawing) {
        _tool = DrawTool.none; _phase = DrawPhase.idle;
        _cursor = null; _fpTime = null; _fpPrice = null;
      } else {
        _tool = tool; _phase = DrawPhase.placingFirst;
        _cursor = Offset(_chartW / 2, _chartH / 2);
        _fpTime = null; _fpPrice = null;
      }
      _selIdx = null; _cross = null;
    });
  }

  void _handleDrawTap() {
    final pos = _cursor ?? _lastTouch;
    if (pos == null) return;

    if (_phase == DrawPhase.placingFirst) {
      if (_tool == DrawTool.hLine) {
        final p = _toPrice(pos.dy);
        if (p != null && _c.isNotEmpty) {
          setState(() {
            _lines.add(ChartLine(
              startTime: _c.first.time, endTime: _c.last.time,
              startPrice: p, endPrice: p,
              color: _dColor, width: _dWidth, style: _dStyle, isHorizontal: true,
            ));
            _selIdx = _lines.length - 1;
            _phase = DrawPhase.selected; _cursor = null;
          });
        }
      } else {
        final t = _toTime(pos.dx);
        final p = _toPrice(pos.dy);
        if (t != null && p != null) {
          setState(() { _fpTime = t; _fpPrice = p; _phase = DrawPhase.placingSecond; });
        }
      }
    } else if (_phase == DrawPhase.placingSecond) {
      final t = _toTime(pos.dx);
      final p = _toPrice(pos.dy);
      if (t != null && p != null) {
        setState(() {
          _lines.add(ChartLine(
            startTime: _fpTime!, endTime: t,
            startPrice: _fpPrice!, endPrice: p,
            color: _dColor, width: _dWidth, style: _dStyle,
          ));
          _selIdx = _lines.length - 1;
          _phase = DrawPhase.selected;
          _fpTime = null; _fpPrice = null; _cursor = null;
        });
      }
    }
  }

  void _updateSel({Color? color, double? width, LineStyle? style}) {
    final i = _selIdx;
    if (i == null || i >= _lines.length) return;
    setState(() => _lines[i] = _lines[i].copyWith(color: color, width: width, style: style));
  }

  void _cloneSel() {
    final i = _selIdx;
    if (i == null || i >= _lines.length) return;
    setState(() { _lines.add(_lines[i]); _selIdx = _lines.length - 1; });
  }

  void _deleteSel() {
    final i = _selIdx;
    if (i == null || i >= _lines.length) return;
    setState(() {
      _lines.removeAt(i); _selIdx = null;
      _phase = DrawPhase.idle; _tool = DrawTool.none;
    });
  }

  // ── crosshair ─────────────────────────────────────────────────────────
  void _showCross(Offset pos) {
    if (_c.isEmpty) return;
    final r   = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) return;
    final slot = ((pos.dx / _cw) - r.rp).round().clamp(0, vis.length - 1);
    final sx   = (r.rp + slot + 0.5) * _cw;
    setState(() => _cross = Offset(sx, pos.dy));
    widget.onCrosshair?.call(vis[slot]);
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _sz = c.biggest;
      return Column(children: [
        _buildToolbar(),
        if (_phase == DrawPhase.selected && _selIdx != null) _buildProps(),
        Expanded(
          child: GestureDetector(
            onScaleStart: (d) {
              _lastTouch = d.localFocalPoint;
              if (_drawing) {
                setState(() => _cursor = _snapCursor(d.localFocalPoint));
                return;
              }
              _inPriceAxis = d.localFocalPoint.dx > _chartW;
              _startVis = _vis; _startPz = _pzoom;
            },
            onScaleUpdate: (d) {
              if (_drawing) {
                if (d.pointerCount == 1) setState(() => _cursor = _snapCursor(d.localFocalPoint));
                return;
              }
              if (_inPriceAxis) {
                setState(() {
                  _pzoom = (d.pointerCount >= 2
                      ? _startPz * d.scale
                      : _pzoom * math.exp(-d.focalPointDelta.dy / 80))
                      .clamp(0.15, 10.0);
                });
                return;
              }
              if (d.pointerCount >= 2) {
                setState(() => _vis = (_startVis / d.scale).clamp(_minVis, _maxVis));
                return;
              }
              if (_longPress) return;
              final had = _cross != null;
              setState(() {
                if (had) _cross = null;
                final mx = math.max(0.0, _c.length.toDouble() - _vis);
                _scroll = (_scroll + d.focalPointDelta.dx / _cw).clamp(0.0, mx);
              });
              if (had) widget.onCrosshair?.call(null);
            },
            onScaleEnd: (_) {},
            onTapDown: (d) { _lastTouch = d.localPosition; },
            onTap: () {
              if (_drawing) { _handleDrawTap(); return; }
              if (_phase == DrawPhase.selected) {
                setState(() { _phase = DrawPhase.idle; _selIdx = null; _tool = DrawTool.none; });
                return;
              }
              if (_cross != null && _lastTouch != null && !_longPress) {
                _showCross(_lastTouch!);
              }
            },
            onLongPressStart: (d) {
              if (_drawing) return;
              _longPress = true; _lpFinger = d.localPosition;
              if (_cross == null) _showCross(d.localPosition);
              _lpCrossStart = _cross;
            },
            onLongPressMoveUpdate: (d) {
              if (_drawing) return;
              final sf = _lpFinger; final sc = _lpCrossStart;
              if (sf == null || sc == null) { _showCross(d.localPosition); return; }
              _showCross(sc + (d.localPosition - sf));
            },
            onLongPressEnd: (_) {
              _longPress = false; _lpFinger = null; _lpCrossStart = null;
            },
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _Painter(
                  candles: _c, vis: _vis, scroll: _scroll, pzoom: _pzoom,
                  cross: _cross, prefix: widget.pricePrefix,
                  showRsi: _showRsi, lines: _lines, selIdx: _selIdx,
                  phase: _phase, cursor: _cursor,
                  fpTime: _fpTime, fpPrice: _fpPrice,
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }

  // ── Toolbar ───────────────────────────────────────────────────────────
  static const _colors = [
    Colors.white, Color(0xFFFFD700), Color(0xFF4FC3F7),
    AppColors.green, AppColors.red, Color(0xFFCE93D8), Color(0xFFFF8A65),
  ];

  Widget _buildToolbar() => SizedBox(
    height: _toolbarH,
    child: Row(children: [
      const SizedBox(width: 8),
      _toolBtn(DrawTool.trendLine, '✏️', '추세선'),
      const SizedBox(width: 4),
      _toolBtn(DrawTool.hLine,     '➖', '수평선'),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _showColorSheet,
        child: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: _dColor, shape: BoxShape.circle,
            border: Border.all(color: Colors.white30, width: 1.5),
          ),
        ),
      ),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: () => setState(() => _lines.clear()),
        child: const Icon(Icons.delete_outline, size: 16, color: AppColors.gray),
      ),
      const Spacer(),
      GestureDetector(
        onTap: () => setState(() => _showRsi = !_showRsi),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _showRsi ? const Color(0xFF7E57C2).withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _showRsi
                  ? const Color(0xFF7E57C2).withValues(alpha: 0.6)
                  : Colors.white12,
            ),
          ),
          child: Text('RSI', style: TextStyle(
            color: _showRsi ? const Color(0xFF9575CD) : AppColors.gray,
            fontSize: 10, fontWeight: FontWeight.w600,
          )),
        ),
      ),
    ]),
  );

  Widget _toolBtn(DrawTool tool, String emoji, String label) {
    final active = _tool == tool;
    return GestureDetector(
      onTap: () => _activateTool(tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.green.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: AppColors.green.withValues(alpha: 0.5)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: active ? AppColors.green : AppColors.gray,
          )),
        ]),
      ),
    );
  }

  // ── Properties panel ──────────────────────────────────────────────────
  Widget _buildProps() {
    final i = _selIdx;
    if (i == null || i >= _lines.length) return const SizedBox.shrink();
    final ln = _lines[i];
    return Container(
      height: _propH,
      color: const Color(0xFF0A0E17),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // color swatches
          ..._colors.map((c) => GestureDetector(
            onTap: () => _updateSel(color: c),
            child: Container(
              width: 16, height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: c, shape: BoxShape.circle,
                border: ln.color.toARGB32() == c.toARGB32()
                    ? Border.all(color: Colors.white, width: 2) : null,
              ),
            ),
          )),
          _div(),
          // width 1-4
          ...[1.0, 2.0, 3.0, 4.0].map((w) {
            final sel = (ln.width - w).abs() < 0.1;
            return GestureDetector(
              onTap: () => _updateSel(width: w),
              child: Container(
                width: 30, height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: sel ? AppColors.green.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: sel ? Border.all(color: AppColors.green.withValues(alpha: 0.5)) : null,
                ),
                child: Center(child: Text('${w.toInt()}px', style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600,
                  color: sel ? AppColors.green : AppColors.gray,
                ))),
              ),
            );
          }),
          _div(),
          // style
          _styleBtn(ln, LineStyle.solid,  '─'),
          _styleBtn(ln, LineStyle.dashed, '--'),
          _styleBtn(ln, LineStyle.dotted, '···'),
          _div(),
          // clone
          GestureDetector(
            onTap: _cloneSel,
            child: _actBtn('복제', Icons.copy_outlined, AppColors.gray),
          ),
          const SizedBox(width: 6),
          // delete
          GestureDetector(
            onTap: _deleteSel,
            child: _actBtn('제거', Icons.delete_outline, AppColors.red),
          ),
        ]),
      ),
    );
  }

  Widget _div() => Container(
    width: 1, height: 20, margin: const EdgeInsets.symmetric(horizontal: 6),
    color: Colors.white12,
  );

  Widget _styleBtn(ChartLine ln, LineStyle s, String sym) {
    final sel = ln.style == s;
    return GestureDetector(
      onTap: () => _updateSel(style: s),
      child: Container(
        height: 28, padding: const EdgeInsets.symmetric(horizontal: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: sel ? AppColors.green.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: sel ? Border.all(color: AppColors.green.withValues(alpha: 0.5)) : null,
        ),
        child: Center(child: Text(sym, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: sel ? AppColors.green : AppColors.gray,
        ))),
      ),
    );
  }

  Widget _actBtn(String label, IconData icon, Color col) => Container(
    height: 28, padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: col.withValues(alpha: 0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: col),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.w500)),
    ]),
  );

  void _showColorSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('기본 선 색상', style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12,
              children: _colors.map((c) => GestureDetector(
                onTap: () { setState(() => _dColor = c); Navigator.pop(context); },
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: c, shape: BoxShape.circle,
                    border: _dColor.toARGB32() == c.toARGB32()
                        ? Border.all(color: Colors.white, width: 2.5) : null,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _Painter extends CustomPainter {
  final List<CandleData> candles;
  final double vis, scroll, pzoom;
  final Offset? cross;
  final String prefix;
  final bool showRsi;
  final List<ChartLine> lines;
  final int? selIdx;
  final DrawPhase phase;
  final Offset? cursor;
  final int? fpTime;
  final double? fpPrice;

  static const _axisW = 58.0;
  static const _timeH = 26.0;
  static const _volR  = 0.18;
  static const _indH  = 80.0;

  _Painter({
    required this.candles, required this.vis, required this.scroll,
    required this.pzoom,   required this.cross, required this.prefix,
    required this.showRsi, required this.lines, required this.selIdx,
    required this.phase,   required this.cursor,
    required this.fpTime,  required this.fpPrice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final hasInd  = showRsi && candles.length > 15;
    final indH    = hasInd ? _indH : 0.0;
    final chartW  = size.width - _axisW;
    final usableH = size.height - _timeH - indH;
    final pH      = usableH * (1 - _volR);
    final vH      = usableH * _volR;
    final cw      = chartW / vis;

    final mx  = math.max(0.0, candles.length.toDouble() - vis);
    final off = scroll.clamp(0.0, mx);
    final e   = (candles.length - off.toInt()).clamp(0, candles.length);
    final s   = (e - vis.ceil()).clamp(0, candles.length);
    final vc  = candles.sublist(s, e);
    if (vc.isEmpty) return;
    final rp = vis - vc.length;

    // price range
    double lo = vc[0].low, hi = vc[0].high, mv = vc[0].volume;
    for (final c in vc) {
      if (c.low  < lo) lo = c.low;
      if (c.high > hi) hi = c.high;
      if (c.volume > mv) mv = c.volume;
    }
    final pad  = (hi - lo) * 0.06;
    final cent = (hi + lo) / 2;
    final half = (hi - lo) / 2 + pad;
    final pMin = cent - half / pzoom;
    final pMax = cent + half / pzoom;
    final pSpan = pMax - pMin;
    if (pSpan <= 0) return;

    double py(double p) => pH - (p - pMin) / pSpan * pH;
    double vy(double v) => mv > 0 ? (v / mv) * vH * 0.9 : 0;

    // grid
    final grid = Paint()..color = const Color(0xFF252A34)..strokeWidth = 0.5;
    for (var i = 1; i < 5; i++) canvas.drawLine(Offset(0, pH * i / 5), Offset(chartW, pH * i / 5), grid);
    canvas.drawLine(Offset(0, pH), Offset(chartW, pH), grid);

    // stored lines (behind candles)
    _drawLines(canvas, vc, s, chartW, pH, py, cw, rp);

    // candles (clipped to price zone)
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, chartW, pH));
    for (var i = 0; i < vc.length; i++) {
      final c   = vc[i];
      final x   = (rp + i + 0.5) * cw;
      final up  = c.close >= c.open;
      final col = up ? AppColors.green : AppColors.red;
      final bw  = math.max(cw * 0.65, 1.0);
      canvas.drawLine(Offset(x, py(c.high)), Offset(x, py(c.low)),
          Paint()..color = col..strokeWidth = math.max(cw * 0.12, 0.8));
      final t = py(math.max(c.open, c.close));
      final b = py(math.min(c.open, c.close));
      canvas.drawRect(Rect.fromLTWH(x - bw / 2, t, bw, math.max(b - t, 1.0)), Paint()..color = col);
    }
    canvas.restore();

    // volume
    for (var i = 0; i < vc.length; i++) {
      final c  = vc[i];
      final x  = (rp + i + 0.5) * cw;
      final bw = math.max(cw * 0.65, 1.0);
      final vh = vy(c.volume);
      canvas.drawRect(
        Rect.fromLTWH(x - bw / 2, pH + vH - vh, bw, vh),
        Paint()..color = (c.close >= c.open ? AppColors.green : AppColors.red).withValues(alpha: 0.35),
      );
    }

    // RSI
    if (hasInd) _drawRsi(canvas, candles, vc, s, chartW, pH + vH, _indH, cw, rp, size);

    // price axis labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 1; i <= 4; i++) {
      final p = pMax - pSpan * i / 4;
      final y = pH * i / 4;
      tp.text = TextSpan(text: _fmt(p), style: const TextStyle(color: AppColors.gray, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset(chartW + 4, y - tp.height / 2));
    }

    // time axis
    final avgI = vc.length >= 2
        ? (vc.last.time - vc.first.time) / math.max(1, vc.length - 1)
        : 86400.0;
    final hhmm  = avgI < 14400;
    final mmdd  = avgI < 172800;
    final yyyymm = avgI < 5184000;

    String tfmt(int t) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true);
      if (hhmm)   return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
      if (mmdd)   return '${dt.month}/${dt.day}';
      if (yyyymm) return '${dt.year}/${dt.month.toString().padLeft(2,'0')}';
      return '${dt.year}';
    }

    final lpw = hhmm ? 34.0 : mmdd ? 26.0 : yyyymm ? 46.0 : 30.0;
    final minStep = math.max(1, ((lpw + 8) / math.max(cw, 0.1)).ceil());
    int step;
    if (!hhmm && !mmdd && !yyyymm) {
      int fs = math.max(1, (5.0 * 365 * 86400 / avgI).round());
      if (fs > 2) { fs = ((fs / 5.0).round() * 5); if (fs < 1) fs = 1; }
      step = math.max(minStep, fs);
    } else {
      step = math.max(minStep, math.max(1, (vc.length / 6).round()));
    }
    if (step < 1) step = 1;

    final xAxisY = size.height - indH - _timeH + 4;
    for (var i = 0; i < vc.length; i += step) {
      final x = (rp + i + 0.5) * cw;
      tp.text = TextSpan(text: tfmt(vc[i].time), style: const TextStyle(color: AppColors.gray, fontSize: 10));
      tp.layout();
      if (x + tp.width / 2 < chartW) tp.paint(canvas, Offset(x - tp.width / 2, xAxisY));
    }

    // normal crosshair (only when idle)
    if (cross != null && phase == DrawPhase.idle) {
      final pos  = cross!;
      final slot = ((pos.dx / cw) - rp).round().clamp(0, vc.length - 1);
      final sx   = (rp + slot + 0.5) * cw;
      final c    = vc[slot];
      final dash = Paint()..color = AppColors.gray.withValues(alpha: 0.7)..strokeWidth = 0.8;
      _dashed(canvas, Offset(sx, 0), Offset(sx, usableH + indH), dash);
      if (pos.dy >= 0 && pos.dy < pH) {
        _dashed(canvas, Offset(0, pos.dy), Offset(chartW, pos.dy), dash);
        final pr = pMin + (1 - pos.dy / pH) * pSpan;
        _axisLabel(canvas, chartW + 4, pos.dy, _fmt(pr), center: false);
      }
      final dtc = DateTime.fromMillisecondsSinceEpoch(c.time * 1000, isUtc: true);
      final cl = hhmm
          ? '${dtc.hour.toString().padLeft(2,'0')}:${dtc.minute.toString().padLeft(2,'0')}'
          : '${dtc.year}/${dtc.month.toString().padLeft(2,'0')}/${dtc.day.toString().padLeft(2,'0')}';
      _axisLabel(canvas, sx, xAxisY, cl, center: true);
    }

    // drawing cursor + anchors
    if (phase == DrawPhase.placingFirst || phase == DrawPhase.placingSecond) {
      final cur = cursor;
      if (cur != null) {
        final gd = Paint()..color = AppColors.green.withValues(alpha: 0.8)..strokeWidth = 0.8;
        _dashed(canvas, Offset(cur.dx, 0), Offset(cur.dx, usableH), gd);
        _dashed(canvas, Offset(0, cur.dy), Offset(chartW, cur.dy), gd);
        _drawAnchor(canvas, cur, AppColors.green);
        if (cur.dy >= 0 && cur.dy < pH) {
          final pr = pMin + (1 - cur.dy / pH) * pSpan;
          _axisLabel(canvas, chartW + 4, cur.dy, _fmt(pr), center: false, color: AppColors.green);
        }
      }

      // first anchor + preview line when placing second point
      if (phase == DrawPhase.placingSecond && fpTime != null && fpPrice != null) {
        double? fx;
        for (int i = 0; i < vc.length; i++) {
          if (vc[i].time >= fpTime!) { fx = (rp + i + 0.5) * cw; break; }
        }
        final fy = py(fpPrice!);
        if (fx != null) {
          _drawAnchor(canvas, Offset(fx, fy), AppColors.green);
          if (cur != null) {
            canvas.drawLine(Offset(fx, fy), cur,
              Paint()..color = AppColors.green.withValues(alpha: 0.5)..strokeWidth = 1.5);
          }
        }
      }
    }

    canvas.restore();
  }

  // ── anchor circle ─────────────────────────────────────────────────────
  void _drawAnchor(Canvas canvas, Offset pos, Color color) {
    canvas.drawCircle(pos, 7, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawCircle(pos, 7, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);
    canvas.drawCircle(pos, 2.5, Paint()..color = color);
  }

  // ── stored lines ──────────────────────────────────────────────────────
  void _drawLines(Canvas canvas, List<CandleData> vc, int startIdx,
      double chartW, double pH, double Function(double) py,
      double cw, double rp) {

    for (int idx = 0; idx < lines.length; idx++) {
      final ln  = lines[idx];
      final sel = idx == selIdx;
      final w   = sel ? ln.width + 1.0 : ln.width;
      final col = sel ? ln.color : ln.color.withValues(alpha: 0.85);

      void drawSeg(Offset p1, Offset p2) {
        final paint = Paint()..color = col..strokeWidth = w..style = PaintingStyle.stroke;
        switch (ln.style) {
          case LineStyle.solid:
            canvas.drawLine(p1, p2, paint);
          case LineStyle.dashed:
            _dashed(canvas, p1, p2, paint, dash: 8, gap: 5);
          case LineStyle.dotted:
            _dotted(canvas, p1, p2, col, w);
        }
      }

      if (ln.isHorizontal) {
        final y = py(ln.startPrice);
        if (y >= -1 && y <= pH + 1) drawSeg(Offset(0, y), Offset(chartW, y));
        if (sel) {
          _axisLabel(canvas, chartW + 4, y, _fmt(ln.startPrice), center: false, color: ln.color);
        }
        continue;
      }

      double? txToX(int t) {
        for (int i = 0; i < vc.length; i++) {
          if (vc[i].time >= t) return (rp + i + 0.5) * cw;
        }
        return null;
      }

      final x1 = txToX(ln.startTime);
      final x2 = txToX(ln.endTime);
      if (x1 == null && x2 == null) continue;

      final y1 = py(ln.startPrice);
      final y2 = py(ln.endPrice);
      drawSeg(Offset(x1 ?? 0, y1), Offset(x2 ?? chartW, y2));

      if (sel) {
        for (final pt in [Offset(x1 ?? 0, y1), Offset(x2 ?? chartW, y2)]) {
          canvas.drawCircle(pt, 5, Paint()..color = ln.color.withValues(alpha: 0.25));
          canvas.drawCircle(pt, 5,
              Paint()..color = ln.color..strokeWidth = 1..style = PaintingStyle.stroke);
        }
      }
    }
  }

  // ── RSI ──────────────────────────────────────────────────────────────
  void _drawRsi(Canvas canvas, List<CandleData> all, List<CandleData> vc,
      int si, double chartW, double panY, double panH,
      double cw, double rp, Size size) {
    const period = 14;
    if (all.length < period + 1) return;

    final rsi = List<double>.filled(all.length, 50);
    double ag = 0, al = 0;
    for (int i = 1; i <= period; i++) {
      final d = all[i].close - all[i-1].close;
      if (d > 0) { ag += d; } else { al -= d; }
    }
    ag /= period; al /= period;
    for (int i = period; i < all.length; i++) {
      if (i > period) {
        final d = all[i].close - all[i-1].close;
        ag = (ag * (period - 1) + (d > 0 ? d : 0)) / period;
        al = (al * (period - 1) + (d < 0 ? -d : 0)) / period;
      }
      rsi[i] = 100 - 100 / (1 + (al == 0 ? 0.0 : ag / al));
    }

    canvas.drawRect(Rect.fromLTWH(0, panY, size.width, panH), Paint()..color = const Color(0xFF0D1117));
    canvas.drawLine(Offset(0, panY), Offset(size.width, panY),
        Paint()..color = const Color(0xFF252A34)..strokeWidth = 0.5);

    final gp = Paint()..color = const Color(0xFF2A3040)..strokeWidth = 0.5;
    double ry(double v) => panY + panH * (1 - v / 100) - 4;
    for (final lv in [30.0, 70.0]) canvas.drawLine(Offset(0, ry(lv)), Offset(chartW, ry(lv)), gp);

    final path = Path(); bool started = false;
    for (int i = 0; i < vc.length; i++) {
      final ai = si + i;
      if (ai >= rsi.length) break;
      final x = (rp + i + 0.5) * cw;
      final y = ry(rsi[ai]);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF7E57C2)..strokeWidth = 1.2..style = PaintingStyle.stroke);

    final tp = TextPainter(textDirection: TextDirection.ltr);
    final last = (si + vc.length - 1 < rsi.length) ? rsi[si + vc.length - 1] : 50.0;
    tp.text = TextSpan(text: 'RSI(14)  ${last.toStringAsFixed(1)}',
        style: const TextStyle(color: Color(0xFF7E57C2), fontSize: 9));
    tp.layout(); tp.paint(canvas, Offset(4, panY + 3));

    for (final lv in [30.0, 70.0]) {
      tp.text = TextSpan(text: lv.toStringAsFixed(0),
          style: const TextStyle(color: Color(0xFF5A6270), fontSize: 8));
      tp.layout(); tp.paint(canvas, Offset(chartW + 4, ry(lv) - tp.height / 2));
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────
  void _dotted(Canvas canvas, Offset p1, Offset p2, Color color, double w) {
    final d = p2 - p1; final len = d.distance;
    if (len == 0) return;
    final unit = d / len; final gap = w * 3;
    double pos = 0;
    while (pos < len) {
      canvas.drawCircle(p1 + unit * pos, w / 2, Paint()..color = color);
      pos += gap;
    }
  }

  void _dashed(Canvas canvas, Offset p1, Offset p2, Paint paint,
      {double dash = 4, double gap = 4}) {
    final d = p2 - p1; final len = d.distance;
    if (len == 0) return;
    final unit = d / len; double pos = 0; bool draw = true;
    while (pos < len) {
      final seg = math.min(pos + (draw ? dash : gap), len);
      if (draw) canvas.drawLine(p1 + unit * pos, p1 + unit * seg, paint);
      pos = seg; draw = !draw;
    }
  }

  void _axisLabel(Canvas canvas, double x, double y, String text,
      {required bool center, Color color = Colors.white}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: color, fontSize: 10, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = center ? x - tp.width / 2 : x;
    final ly = center ? y : y - tp.height / 2;
    canvas.drawRect(Rect.fromLTWH(lx - 2, ly - 1, tp.width + 4, tp.height + 2),
        Paint()..color = const Color(0xFF252A34));
    tp.paint(canvas, Offset(lx, ly));
  }

  String _fmt(double p) {
    final String n;
    if (p >= 1e6)       { n = '${(p/1e6).toStringAsFixed(2)}M'; }
    else if (p >= 1000) { n = p.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','); }
    else if (p < 1)     { n = p.toStringAsFixed(4); }
    else                { n = p.toStringAsFixed(2); }
    return '$prefix$n';
  }

  @override
  bool shouldRepaint(_Painter o) =>
      candles != o.candles || vis != o.vis || scroll != o.scroll ||
      pzoom != o.pzoom || cross != o.cross || prefix != o.prefix ||
      showRsi != o.showRsi || lines != o.lines || selIdx != o.selIdx ||
      phase != o.phase || cursor != o.cursor ||
      fpTime != o.fpTime || fpPrice != o.fpPrice;
}
