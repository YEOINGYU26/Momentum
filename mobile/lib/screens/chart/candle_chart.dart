import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/chart_line_info.dart';

// ─── Shared color palette ─────────────────────────────────────────────────────

final List<Color> _kColorOptions = [
  Colors.white, const Color(0xFFFFD700), const Color(0xFF4FC3F7),
  AppColors.green, AppColors.red, const Color(0xFFCE93D8), const Color(0xFFFF8A65),
];

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

// ─── Drawing types ───────────────────────────────────────────────────────────

enum DrawTool {
  none,
  // 트렌드 라인
  trendLine, crossLine, parallelChannel,
  horizontalLine, verticalLine,
  // 간과 피보나치
  fibRetracement, fibExtension, fibTimeZone,
  fibFan, fibArc, gannFan, gannSquare,
  // 패턴
  headAndShoulders, elliottWave, xabcdPattern,
  abcdPattern, trianglePattern,
  // 예측 및 측정
  longPosition, shortPosition,
  priceRange, dateRange, barsPattern,
  // 기하 도형
  brush, rectangle, ellipse, triangle, arc,
  // 주석
  text, note, priceNote, arrowUp, arrowDown, callout,
}
enum DrawPhase { idle, placingFirst, placingSecond, placingMore, selected }
enum LineStyle { solid, dashed, dotted }

class DrawingPoint {
  final int time;
  final double price;
  const DrawingPoint(this.time, this.price);
}

extension _DrawToolX on DrawTool {
  int get pointCount {
    switch (this) {
      // 1점 도구
      case DrawTool.crossLine:
      case DrawTool.horizontalLine: case DrawTool.verticalLine:
      case DrawTool.arrowUp: case DrawTool.arrowDown:
      case DrawTool.text: case DrawTool.note: case DrawTool.priceNote:
      case DrawTool.callout: return 1;
      // 2점 도구
      case DrawTool.trendLine:
      case DrawTool.fibRetracement: case DrawTool.fibTimeZone:
      case DrawTool.fibFan: case DrawTool.fibArc:
      case DrawTool.gannFan: case DrawTool.gannSquare:
      case DrawTool.longPosition: case DrawTool.shortPosition:
      case DrawTool.priceRange: case DrawTool.dateRange: case DrawTool.barsPattern:
      case DrawTool.rectangle: case DrawTool.ellipse: return 2;
      // 3점 도구
      case DrawTool.parallelChannel: case DrawTool.fibExtension:
      case DrawTool.trianglePattern: case DrawTool.triangle: case DrawTool.arc: return 3;
      // 4점 도구
      case DrawTool.abcdPattern: return 4;
      // 5점 도구
      case DrawTool.headAndShoulders: case DrawTool.xabcdPattern: return 5;
      // 6점 도구
      case DrawTool.elliottWave: return 6;
      // 드래그 도구
      case DrawTool.brush: return -1;
      case DrawTool.none: return 0;
    }
  }
  bool get isTextTool =>
      this == DrawTool.text || this == DrawTool.note ||
      this == DrawTool.priceNote || this == DrawTool.callout;
}

class ChartLine {
  final int    startTime, endTime;
  final double startPrice, endPrice;
  final Color  color;
  final bool   isHorizontal;
  final double width;
  final LineStyle style;
  final LineRole  role;
  final DrawTool  drawType;
  final List<DrawingPoint> pts;
  final String? text;

  const ChartLine({
    required this.startTime, required this.endTime,
    required this.startPrice, required this.endPrice,
    required this.color,
    this.isHorizontal = false,
    this.width = 1.5,
    this.style = LineStyle.solid,
    this.role = LineRole.none,
    this.drawType = DrawTool.trendLine,
    this.pts = const [],
    this.text,
  });

  ChartLine copyWith({
    int? startTime, int? endTime,
    double? startPrice, double? endPrice,
    Color? color, double? width, LineStyle? style, LineRole? role,
    DrawTool? drawType, List<DrawingPoint>? pts, String? text,
  }) => ChartLine(
    startTime:  startTime  ?? this.startTime,
    endTime:    endTime    ?? this.endTime,
    startPrice: startPrice ?? this.startPrice,
    endPrice:   endPrice   ?? this.endPrice,
    color: color ?? this.color, isHorizontal: isHorizontal,
    width: width ?? this.width, style: style ?? this.style,
    role: role ?? this.role,
    drawType: drawType ?? this.drawType,
    pts: pts ?? this.pts,
    text: text ?? this.text,
  );
}

// ─── Indicator config ─────────────────────────────────────────────────────────

class IndicatorConfig {
  final List<double> params;  // RSI:[14] MACD:[12,26,9] Stoch:[14,3] MA:[5,20,60] BB:[20,2] Ichi:[9,26,52]
  final List<Color>  colors;
  final bool         visible;
  final Color?       labelColor;  // null = colors[0] 사용

  const IndicatorConfig({required this.params, required this.colors, this.visible = true, this.labelColor});

  IndicatorConfig withLabelColor(Color? c) =>
      IndicatorConfig(params: params, colors: colors, visible: visible, labelColor: c);

  IndicatorConfig copyWith({List<double>? params, List<Color>? colors, bool? visible}) =>
      IndicatorConfig(
        params:     params  ?? this.params,
        colors:     colors  ?? this.colors,
        visible:    visible ?? this.visible,
        labelColor: labelColor,
      );
}

const _kDefaultConfigs = <IndicatorType, IndicatorConfig>{
  IndicatorType.rsi:            IndicatorConfig(params: [14],       colors: [Color(0xFF7E57C2)]),
  IndicatorType.macd:           IndicatorConfig(params: [12,26,9],  colors: [Color(0xFF26C6DA), Color(0xFFFF9800)]),
  IndicatorType.stochastic:     IndicatorConfig(params: [14,3],     colors: [Color(0xFF64B5F6), Color(0xFFFF9800)]),
  IndicatorType.movingAverage:  IndicatorConfig(params: [5,20,60],  colors: [Color(0xFFFFD700), Color(0xFF4FC3F7), Color(0xFFCE93D8)]),
  IndicatorType.bollingerBands: IndicatorConfig(params: [20,2],     colors: [Color(0xFF4FC3F7), Color(0xFF78909C)]),
  IndicatorType.ichimoku:       IndicatorConfig(params: [9,26,52],  colors: [Color(0xFFEF5350), Color(0xFF1976D2), Color(0xFF4CAF50), Color(0xFFEF5350)]),
};

// ─── Indicator types ─────────────────────────────────────────────────────────

enum IndicatorType { rsi, macd, stochastic, movingAverage, bollingerBands, ichimoku }

class _IndMeta {
  final IndicatorType type;
  final String name, shortName, description;
  final bool isPanel;
  const _IndMeta(this.type, this.name, this.shortName, this.description, this.isPanel);
}

const List<_IndMeta> _kIndicators = [
  _IndMeta(IndicatorType.rsi,            'RSI',        'RSI(14)',        '상대강도지수. 0–100 오실레이터.\n70↑ 과매수, 30↓ 과매도 신호.', true),
  _IndMeta(IndicatorType.macd,           'MACD',       'MACD',          'EMA 차이와 시그널선 교차로\n추세 전환을 포착.', true),
  _IndMeta(IndicatorType.stochastic,     '스토캐스틱',  'Stoch',         '%K·%D 교차 오실레이터.\n80↑ 과매수, 20↓ 과매도.', true),
  _IndMeta(IndicatorType.movingAverage,  '이동평균선',  'MA',            '단순이동평균.\n골든/데드크로스 포착.', false),
  _IndMeta(IndicatorType.bollingerBands, '볼린저 밴드', 'BB',            'SMA ± σ 밴드.\n변동성·추세 이탈 확인.', false),
  _IndMeta(IndicatorType.ichimoku,       '이치모쿠',   'Ichi',          '일목균형표. 전환선·기준선·구름대로\n지지/저항과 추세 방향 확인.', false),
];

const _panelIndicatorTypes = {
  IndicatorType.rsi, IndicatorType.macd, IndicatorType.stochastic,
};

// ─── Widget ──────────────────────────────────────────────────────────────────

class CandleChart extends StatefulWidget {
  final List<CandleData> candles;
  final void Function(CandleData?)? onCrosshair;
  final void Function(List<ChartLineInfo>)? onLinesChanged;
  final String pricePrefix;
  final String ticker;
  final List<ChartLineInfo> initialLines;

  const CandleChart({
    super.key, required this.candles,
    this.onCrosshair, this.onLinesChanged,
    this.pricePrefix = '',
    this.ticker = '',
    this.initialLines = const [],
  });

  @override
  State<CandleChart> createState() => _CandleChartState();
}

// ─── State ───────────────────────────────────────────────────────────────────

class _CandleChartState extends State<CandleChart> {
  static const double _minVis    = 10;
  static const double _maxVis    = 200;
  static const double _axisW     = 58;
  static const double _timeH     = 26;
  static const double _volR      = 0.18;
  static const double _panelH    = 80.0;
  static const double _baseToolH = 36.0;
  static const int    _futureBuf = 500;

  double _vis      = 60;
  double _scroll   = 0;
  double _startVis = 60;
  double _pzoom    = 1.0;
  double _startPz  = 1.0;

  Offset?    _cross;
  CandleData? _crossCandle;
  bool    _longPress   = false;
  bool    _crossDrag   = false;  // 십자선 근처 pan → 십자선 이동 모드
  Offset? _lpFinger;
  Offset? _lpCrossStart;
  Offset? _lpDownPos;
  Timer?  _lpTimer;
  Offset? _lastTouch;
  bool    _inPriceAxis = false;

  final Set<IndicatorType> _activeIndicators = {};
  final Map<IndicatorType, IndicatorConfig> _indConfigs =
      Map.from(_kDefaultConfigs);
  bool _indicatorPickerOpen = false;
  bool _drawingPickerOpen  = false;
  List<DrawingPoint> _pendingPts  = [];
  List<DrawingPoint> _brushPending = [];

  DrawTool  _tool  = DrawTool.none;
  DrawPhase _phase = DrawPhase.idle;
  final Color     _dColor = Colors.white;
  final double    _dWidth = 1.5;
  final LineStyle _dStyle = LineStyle.solid;
  Offset?   _cursor;
  Offset?   _drawFinger;
  Offset?   _drawCursorBase;
  int?      _fpTime;
  double?   _fpPrice;
  final List<ChartLine> _lines = [];
  int?  _selIdx;
  int?  _selEndpoint;        // 0 or 1 when dragging an endpoint
  ChartLine? _selLineOrig;   // line snapshot at drag start (absolute movement)
  Offset?    _selDragOrigin; // finger position at drag start
  IndicatorType? _selIndicator; // 보조지표 선택 상태

  Offset _selToolbarOffset = const Offset(8, 6);

  Size _sz = Size.zero;

  List<CandleData> get _c => widget.candles;
  bool get _drawing =>
      _phase == DrawPhase.placingFirst ||
      _phase == DrawPhase.placingSecond ||
      _phase == DrawPhase.placingMore;
  bool get _selVisible => _phase == DrawPhase.selected && _selIdx != null;

  double get _toolbarH => _baseToolH;
  double get _chartH   => math.max(_sz.height - _toolbarH, 1);
  double get _chartW   => math.max(_sz.width  - _axisW, 1);
  double get _cw       => _chartW / _vis;

  double get _totalPanelH =>
      _activeIndicators.where(_panelIndicatorTypes.contains).length * _panelH;

  @override
  void initState() {
    super.initState();
    if (widget.initialLines.isNotEmpty) {
      _lines.addAll(widget.initialLines.map(_infoToLine));
    }
  }

  /// ChartLineInfo → ChartLine 변환 (색상은 역할 기반)
  static ChartLine _infoToLine(ChartLineInfo info) => ChartLine(
    startTime:   info.startTime,
    endTime:     info.endTime,
    startPrice:  info.startPrice,
    endPrice:    info.endPrice,
    isHorizontal: info.isHorizontal,
    role:        info.role,
    color:       info.role != LineRole.none
                   ? info.role.roleColor : Colors.white70,
  );

  @override
  void didUpdateWidget(CandleChart old) {
    super.didUpdateWidget(old);
    if (old.candles != widget.candles) {
      _scroll = 0; _pzoom = 1.0; _vis = 60; _cross = null; _crossCandle = null;
    }
    if (old.ticker != widget.ticker && widget.ticker.isNotEmpty) {
      _lines.clear();
      _selIdx = null; _selEndpoint = null;
      _phase = DrawPhase.idle; _tool = DrawTool.none;
      _cross = null; _crossCandle = null;
      _notifyLinesChanged();
    }
    // ChartProvider.load()가 비동기 완료된 후 initialLines가 뒤늦게 도착한 경우 복원
    if (_lines.isEmpty && widget.initialLines.isNotEmpty) {
      setState(() {
        _lines.addAll(widget.initialLines.map(_infoToLine));
      });
    }
  }

  // ── Range ─────────────────────────────────────────────────────────────────
  ({int s, int e, double rp, int futureSlots}) _range() {
    final mx  = math.max(0.0, _c.length.toDouble() - _vis);
    final off = _scroll.clamp(-_futureBuf.toDouble(), mx);
    final futureSlots = off < 0 ? (-off).round().clamp(0, _futureBuf) : 0;
    final normalOff   = math.max(0.0, off);
    final e        = (_c.length - normalOff.round()).clamp(0, _c.length);
    // 미래로 스크롤해도 최소 20개 캔들(또는 전체 데이터 수)은 항상 표시
    final minCandles = math.max(1, math.min(20, math.min(_c.length, _vis.floor())));
    final wantData = (_vis.ceil() - futureSlots).clamp(minCandles, _c.length);
    final s        = (e - wantData).clamp(0, _c.length);
    final cnt      = e - s;
    final rp       = (_vis - cnt - futureSlots).clamp(0.0, double.infinity);
    return (s: s, e: e, rp: rp, futureSlots: futureSlots);
  }

  double? _toPrice(double dy) {
    if (_c.isEmpty) return null;
    final r   = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) return null;
    final usable = _chartH - _timeH - _totalPanelH;
    final pH = usable * (1 - _volR);
    if (dy < 0 || dy > pH) return null;
    double lo = vis[0].low, hi = vis[0].high;
    for (final c in vis) {
      if (c.low < lo) { lo = c.low; }
      if (c.high > hi) { hi = c.high; }
    }
    final pad  = (hi - lo) * 0.06;
    final cent = (hi + lo) / 2;
    final half = (hi - lo) / 2 + pad;
    return (cent - half / _pzoom) + (1 - dy / pH) * (2 * half / _pzoom);
  }

  int? _toTime(double dx) {
    if (_c.isEmpty) return null;
    final r   = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) return null;
    final totalSlots = vis.length + r.futureSlots;
    final slot = ((dx / _cw) - r.rp).floor().clamp(0, totalSlots - 1);
    if (slot < vis.length) return vis[slot].time;
    // future slot: 마지막 캔들에서 평균 간격만큼 외삽
    final avgI = vis.length >= 2
        ? (vis.last.time - vis.first.time) / math.max(1, vis.length - 1)
        : 86400.0;
    final fi = slot - vis.length;
    return (vis.last.time + (fi + 1) * avgI).round();
  }

  Offset _snapCursor(Offset raw) {
    if (_c.isEmpty) return raw;
    final r   = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) return raw;
    final totalSlots = vis.length + r.futureSlots;
    final slot = ((raw.dx / _cw) - r.rp).floor().clamp(0, totalSlots - 1);
    return Offset((r.rp + slot + 0.5) * _cw, raw.dy);
  }

  ({List<CandleData> vc, double rp, double pMin, double pSpan, double pH})? _viewParams() {
    if (_c.isEmpty) return null;
    final r  = _range();
    final vc = _c.sublist(r.s, r.e);
    if (vc.isEmpty) return null;
    double lo = vc[0].low, hi = vc[0].high;
    for (final c in vc) {
      if (c.low < lo) { lo = c.low; }
      if (c.high > hi) { hi = c.high; }
    }
    final pad   = (hi - lo) * 0.06;
    final cent  = (hi + lo) / 2;
    final half  = (hi - lo) / 2 + pad;
    final pMin  = cent - half / _pzoom;
    final pSpan = 2 * half / _pzoom;
    if (pSpan <= 0) return null;
    final usable = _chartH - _timeH - _totalPanelH;
    final pH = usable * (1 - _volR);
    return (vc: vc, rp: r.rp, pMin: pMin, pSpan: pSpan, pH: pH);
  }

  (Offset, Offset)? _linePixels(ChartLine ln) {
    final vp = _viewParams();
    if (vp == null) return null;
    final vc = vp.vc; final rp = vp.rp;
    double pyF(double p) => vp.pH - (p - vp.pMin) / vp.pSpan * vp.pH;
    double txToX(int t) {
      if (vc.isEmpty) return 0;
      final avg = vc.length >= 2
          ? (vc.last.time - vc.first.time) / (vc.length - 1) : 86400.0;
      if (t <= vc.first.time) {
        return (rp + 0.5 - (vc.first.time - t) / avg) * _cw;
      }
      if (t >= vc.last.time) {
        return (rp + vc.length - 0.5 + (t - vc.last.time) / avg) * _cw;
      }
      for (int i = 0; i < vc.length - 1; i++) {
        if (t < vc[i + 1].time) {
          final frac = (t - vc[i].time) / (vc[i + 1].time - vc[i].time);
          return (rp + i + frac + 0.5) * _cw;
        }
      }
      return (rp + vc.length - 0.5) * _cw;
    }
    if (ln.isHorizontal || ln.drawType == DrawTool.horizontalLine) {
      final y = pyF(ln.startPrice);
      return (Offset(0, y), Offset(_chartW, y));
    }
    return (Offset(txToX(ln.startTime), pyF(ln.startPrice)),
            Offset(txToX(ln.endTime),   pyF(ln.endPrice)));
  }

  static double _ptSegDist(Offset p, Offset a, Offset b) {
    final ab   = b - a;
    final len2 = ab.distanceSquared;
    if (len2 == 0) { return (p - a).distance; }
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // Minimum distance from tap to any visible part of a drawn line/shape.
  double _lineHitDist(ChartLine ln, Offset tap) {
    final vp = _viewParams();
    if (vp == null) return double.infinity;
    final vc = vp.vc; final rp = vp.rp;
    double pyF(double p) => vp.pH - (p - vp.pMin) / vp.pSpan * vp.pH;
    double txToX(int t) {
      if (vc.isEmpty) return 0;
      final avg = vc.length >= 2
          ? (vc.last.time - vc.first.time) / (vc.length - 1) : 86400.0;
      if (t <= vc.first.time) return (rp + 0.5 - (vc.first.time - t) / avg) * _cw;
      if (t >= vc.last.time) return (rp + vc.length - 0.5 + (t - vc.last.time) / avg) * _cw;
      for (int i = 0; i < vc.length - 1; i++) {
        if (t < vc[i + 1].time) {
          final frac = (t - vc[i].time) / (vc[i + 1].time - vc[i].time);
          return (rp + i + frac + 0.5) * _cw;
        }
      }
      return (rp + vc.length - 0.5) * _cw;
    }
    Offset px(DrawingPoint dp) => Offset(txToX(dp.time), pyF(dp.price));

    // Full-width horizontal line
    if (ln.isHorizontal || ln.drawType == DrawTool.horizontalLine) {
      final y = pyF(ln.startPrice);
      return _ptSegDist(tap, Offset(0, y), Offset(_chartW, y));
    }
    // Full-height vertical line
    if (ln.drawType == DrawTool.verticalLine) {
      final x = txToX(ln.startTime);
      return _ptSegDist(tap, Offset(x, 0), Offset(x, _chartH));
    }
    // Crosshair: check both H and V lines
    if (ln.drawType == DrawTool.crossLine) {
      final x = txToX(ln.startTime); final y = pyF(ln.startPrice);
      return math.min(
        _ptSegDist(tap, Offset(0, y), Offset(_chartW, y)),
        _ptSegDist(tap, Offset(x, 0), Offset(x, _chartH)),
      );
    }
    // Multi-point tools: check all consecutive segments
    if (ln.pts.length >= 2) {
      double minD = double.infinity;
      for (int j = 0; j < ln.pts.length - 1; j++) {
        minD = math.min(minD, _ptSegDist(tap, px(ln.pts[j]), px(ln.pts[j + 1])));
      }
      return minD;
    }
    // 1-point tools (text, note, arrow, etc.): proximity to anchor point
    if (ln.pts.isNotEmpty) {
      return (tap - px(ln.pts.first)).distance;
    }
    // Fallback: SharedPreferences에서 복원한 선은 pts=[]이므로
    // startTime/endTime/startPrice/endPrice 좌표로 히트 테스트
    final pxPair = _linePixels(ln);
    if (pxPair != null) return _ptSegDist(tap, pxPair.$1, pxPair.$2);
    return double.infinity;
  }

  int? _findLineAt(Offset tap) {
    int? hit; double minD = 12.0;
    for (int i = 0; i < _lines.length; i++) {
      final d = _lineHitDist(_lines[i], tap);
      if (d < minD) { minD = d; hit = i; }
    }
    return hit;
  }

  // Returns 0 (start endpoint) or 1 (end endpoint) if tap is near either
  int? _findEndpointAt(Offset tap) {
    final i = _selIdx;
    if (i == null || i >= _lines.length) { return null; }
    final pts = _linePixels(_lines[i]);
    if (pts == null) { return null; }
    if ((tap - pts.$1).distance < 36) { return 0; }
    if ((tap - pts.$2).distance < 36) { return 1; }
    return null;
  }

  void _handleTapOnChart(Offset tap) {
    // 보조지표 선택 해제
    if (_selIndicator != null) {
      setState(() => _selIndicator = null);
      return;
    }
    // 추세선 히트 검사 (십자선 여부와 무관하게 먼저)
    final hit = _findLineAt(tap);
    if (hit != null) {
      setState(() {
        _selIdx = hit; _phase = DrawPhase.selected; _tool = DrawTool.none;
        _cross = null; _crossCandle = null; _selToolbarOffset = const Offset(8, 6); _selEndpoint = null;
      });
      return;
    }
    // 추세선 선택 해제
    if (_phase == DrawPhase.selected) {
      setState(() { _phase = DrawPhase.idle; _selIdx = null; _tool = DrawTool.none; _selEndpoint = null; });
      return;
    }
    // 십자선 해제
    if (_cross != null) {
      setState(() { _cross = null; _crossCandle = null; });
      widget.onCrosshair?.call(null);
    }
  }

  // delta = 드래그 시작점 대비 총 이동량 (누적 오차 없음), orig = 드래그 시작 시 선 좌표
  void _moveSelLine(Offset delta, ChartLine orig) {
    final i = _selIdx;
    if (i == null || i >= _lines.length) { return; }
    final vp = _viewParams();
    if (vp == null) { return; }
    final vc = vp.vc;
    if (vc.length < 2) { return; }
    final avg = (vc.last.time - vc.first.time) / (vc.length - 1);
    setState(() {
      _lines[i] = orig.copyWith(
        startTime:  orig.startTime  + (delta.dx / _cw * avg).round(),
        endTime:    orig.endTime    + (delta.dx / _cw * avg).round(),
        startPrice: orig.startPrice - delta.dy / vp.pH * vp.pSpan,
        endPrice:   orig.endPrice   - delta.dy / vp.pH * vp.pSpan,
      );
    });
  }

  void _moveSelEndpoint(int ep, Offset delta, ChartLine orig) {
    final i = _selIdx;
    if (i == null || i >= _lines.length) { return; }
    final vp = _viewParams();
    if (vp == null) { return; }
    final vc = vp.vc;
    if (vc.length < 2) { return; }
    final avg = (vc.last.time - vc.first.time) / (vc.length - 1);
    setState(() {
      if (ep == 0) {
        _lines[i] = orig.copyWith(
          startTime:  orig.startTime  + (delta.dx / _cw * avg).round(),
          startPrice: orig.startPrice - delta.dy / vp.pH * vp.pSpan,
        );
      } else {
        _lines[i] = orig.copyWith(
          endTime:  orig.endTime  + (delta.dx / _cw * avg).round(),
          endPrice: orig.endPrice - delta.dy / vp.pH * vp.pSpan,
        );
      }
    });
  }

  void _activateTool(DrawTool tool) {
    setState(() {
      if (_tool == tool && (_drawing || _tool == DrawTool.brush)) {
        _tool = DrawTool.none; _phase = DrawPhase.idle;
        _cursor = null; _fpTime = null; _fpPrice = null;
        _drawFinger = null; _drawCursorBase = null;
        _pendingPts = []; _brushPending = [];
      } else {
        _tool = tool; _pendingPts = []; _brushPending = [];
        if (tool == DrawTool.brush) {
          _phase = DrawPhase.idle;
          _cursor = null;
        } else if (tool.pointCount != 0) {
          _phase = DrawPhase.placingFirst;
          _cursor = Offset(_chartW / 2, _chartH * 0.35);
          _drawFinger = null; _drawCursorBase = null;
          _fpTime = null; _fpPrice = null;
        }
      }
      _selIdx = null; _selEndpoint = null; _cross = null; _crossCandle = null;
    });
  }

  void _handleDrawTap() {
    final pos = _cursor ?? _lastTouch;
    if (pos == null) return;
    if (_tool == DrawTool.brush) return;

    if (_tool.isTextTool) {
      final t = _toTime(pos.dx); final p = _toPrice(pos.dy);
      if (t != null && p != null) _showTextInput(t, p, _tool);
      return;
    }

    final needed = _tool.pointCount;

    if (_phase == DrawPhase.placingFirst) {
      final t = _toTime(pos.dx); final p = _toPrice(pos.dy);
      if (t != null && p != null) {
        if (needed == 1) {
          setState(() {
            _lines.add(ChartLine(
              startTime: t, endTime: t, startPrice: p, endPrice: p,
              color: _dColor, width: _dWidth, style: _dStyle,
              drawType: _tool, pts: [DrawingPoint(t, p)],
            ));
            _phase = DrawPhase.idle; _tool = DrawTool.none;
            _cursor = null; _fpTime = null; _fpPrice = null;
            _pendingPts = [];
          });
          _notifyLinesChanged();
        } else {
          final secondX = (pos.dx + _cw * 8).clamp(0.0, _chartW - 1);
          final secondPos = Offset(secondX, pos.dy);
          setState(() {
            _pendingPts = [DrawingPoint(t, p)];
            _fpTime = t; _fpPrice = p; _phase = DrawPhase.placingSecond;
            _cursor = secondPos; _drawFinger = null; _drawCursorBase = secondPos;
          });
        }
      }
    } else if (_phase == DrawPhase.placingSecond || _phase == DrawPhase.placingMore) {
      final t = _toTime(pos.dx); final p = _toPrice(pos.dy);
      if (t != null && p != null) {
        _pendingPts.add(DrawingPoint(t, p));
        if (_pendingPts.length >= needed) {
          final pts = List<DrawingPoint>.from(_pendingPts);
          setState(() {
            _lines.add(ChartLine(
              startTime: pts.first.time, endTime: pts.last.time,
              startPrice: pts.first.price, endPrice: pts.last.price,
              color: _dColor, width: _dWidth, style: _dStyle,
              drawType: _tool, pts: pts,
            ));
            _phase = DrawPhase.idle; _tool = DrawTool.none;
            _fpTime = null; _fpPrice = null; _cursor = null;
            _drawFinger = null; _drawCursorBase = null; _selIdx = null;
            _pendingPts = [];
          });
          _notifyLinesChanged();
        } else {
          final nextX = (pos.dx + _cw * 8).clamp(0.0, _chartW - 1);
          setState(() {
            _phase = DrawPhase.placingMore;
            _cursor = Offset(nextX, pos.dy);
            _drawFinger = null; _drawCursorBase = Offset(nextX, pos.dy);
          });
        }
      }
    }
  }

  void _showTextInput(int time, double price, DrawTool tool) {
    final ctrl = TextEditingController();
    final title = tool == DrawTool.text ? '텍스트' : tool == DrawTool.note ? '노트' : '프라이스 노트';
    showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: ctrl, autofocus: true,
          maxLines: tool == DrawTool.text ? 1 : 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '내용을 입력하세요',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('확인', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    ).then((txt) {
      if (!mounted || txt == null || txt.isEmpty) {
        setState(() { _phase = DrawPhase.idle; _tool = DrawTool.none; });
        return;
      }
      setState(() {
        _lines.add(ChartLine(
          startTime: time, endTime: time, startPrice: price, endPrice: price,
          color: _dColor, width: _dWidth, style: _dStyle,
          drawType: tool, pts: [DrawingPoint(time, price)], text: txt,
        ));
        _phase = DrawPhase.idle; _tool = DrawTool.none;
        _cursor = null; _pendingPts = [];
      });
      _notifyLinesChanged();
    });
  }

  void _updateSel({Color? color, double? width, LineStyle? style}) {
    final i = _selIdx;
    if (i == null || i >= _lines.length) { return; }
    setState(() => _lines[i] = _lines[i].copyWith(color: color, width: width, style: style));
  }

  void _cloneSel() {
    final i = _selIdx;
    if (i == null || i >= _lines.length) { return; }
    final ln  = _lines[i];
    final vp  = _viewParams();
    final priceOff = (vp?.pSpan ?? 0) * 0.05;
    setState(() {
      _lines.add(ln.copyWith(
        startPrice: ln.startPrice + priceOff,
        endPrice:   ln.endPrice   + priceOff,
      ));
      _selIdx = _lines.length - 1;
      _selEndpoint = null;
      _selLineOrig = _lines.last;
      _selDragOrigin = null;
    });
    _notifyLinesChanged();
  }

  void _deleteSel() {
    final i = _selIdx;
    if (i == null || i >= _lines.length) { return; }
    setState(() {
      _lines.removeAt(i); _selIdx = null; _selEndpoint = null;
      _phase = DrawPhase.idle; _tool = DrawTool.none;
    });
    _notifyLinesChanged();
  }

  void _notifyLinesChanged() {
    final infos = _lines
      .where((ln) => ln.drawType == DrawTool.trendLine || ln.isHorizontal)
      .map((ln) => ChartLineInfo(
        startPrice:   ln.startPrice,
        endPrice:     ln.endPrice,
        startTime:    ln.startTime,
        endTime:      ln.endTime,
        isHorizontal: ln.isHorizontal,
        role:         ln.role,
      )).toList();
    widget.onLinesChanged?.call(infos);
  }

  void _showCross(Offset pos) {
    if (_c.isEmpty) { return; }
    final r   = _range();
    final vis = _c.sublist(r.s, r.e);
    if (vis.isEmpty) { return; }
    final totalSlots = vis.length + r.futureSlots;
    final slot = ((pos.dx / _cw) - r.rp).round().clamp(0, totalSlots - 1);
    final isFuture = slot >= vis.length;
    setState(() {
      _cross = Offset((r.rp + slot + 0.5) * _cw, pos.dy);
      _crossCandle = isFuture ? null : vis[slot];
    });
    widget.onCrosshair?.call(isFuture ? null : vis[slot]);
  }

  Color _indColor(IndicatorType type) {
    final cfg = _indConfigs[type];
    if (cfg == null) return Colors.white;
    return cfg.labelColor ?? (cfg.colors.isNotEmpty ? cfg.colors[0] : Colors.white);
  }

  // ── OHLCV 범례 ─────────────────────────────────────────────────────────────

  static String _fmtVol(double v) {
    if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(1)}억';
    if (v >= 1e4) return '${(v / 1e4).toStringAsFixed(0)}만';
    return v.toStringAsFixed(0);
  }

  static String _fmtPrice(String prefix, double v) {
    final String n;
    if (v >= 1e6) {
      n = '${(v / 1e6).toStringAsFixed(2)}M';
    } else if (v >= 1000) {
      n = v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    } else if (v < 1) {
      n = v.toStringAsFixed(4);
    } else {
      n = v.toStringAsFixed(2);
    }
    return '$prefix$n';
  }

  Widget _buildLegend(CandleData c) {
    final isUp = c.close >= c.open;
    final col  = isUp ? AppColors.red : AppColors.blue;
    final pfx  = widget.pricePrefix;
    Widget lbl(String k, String v, [Color? vc]) => RichText(text: TextSpan(children: [
      TextSpan(text: '$k ', style: const TextStyle(color: AppColors.gray, fontSize: 10)),
      TextSpan(text: v,  style: TextStyle(
          color: vc ?? Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
    ]));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        lbl('시', _fmtPrice(pfx, c.open)),
        const SizedBox(width: 8),
        lbl('고', _fmtPrice(pfx, c.high),  AppColors.red),
        const SizedBox(width: 8),
        lbl('저', _fmtPrice(pfx, c.low),   AppColors.blue),
        const SizedBox(width: 8),
        lbl('종', _fmtPrice(pfx, c.close), col),
        const SizedBox(width: 8),
        lbl('거', _fmtVol(c.volume)),
      ]),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      _sz = c.biggest;
      final clampX = math.max(0.0, _chartW - 268);
      final clampY = math.max(0.0, _chartH - 52);
      return Column(children: [
        _buildToolbar(),
        Expanded(
          child: Stack(children: [
            Listener(
              onPointerDown: (e) {
                if (_drawing) return;
                _lpDownPos = e.localPosition;
                _lpTimer?.cancel();
                _lpTimer = Timer(const Duration(milliseconds: 200), () {
                  _lpTimer = null;
                  if (!mounted) return;
                  _longPress = true;
                  _lpFinger  = _lpDownPos;
                  if (_cross == null && _lpDownPos != null) {
                    _showCross(_lpDownPos!);
                  } else {
                    setState(() {});
                  }
                  _lpCrossStart = _cross;
                });
              },
              onPointerMove: (e) {
                if (_lpTimer == null) return;
                final moved = (_lpDownPos == null)
                    ? 0.0
                    : (e.localPosition - _lpDownPos!).distance;
                if (moved > 8) { _lpTimer!.cancel(); _lpTimer = null; }
              },
              onPointerUp: (_) {
                _lpTimer?.cancel(); _lpTimer = null;
                if (_longPress) {
                  setState(() {
                    _longPress = false; _lpFinger = null; _lpCrossStart = null;
                  });
                }
              },
              onPointerCancel: (_) {
                _lpTimer?.cancel(); _lpTimer = null;
                if (_longPress) {
                  setState(() {
                    _longPress = false; _lpFinger = null; _lpCrossStart = null;
                  });
                }
              },
              child: GestureDetector(
              onScaleStart: (d) {
                _lastTouch = d.localFocalPoint;
                if (_tool == DrawTool.brush && d.pointerCount == 1) {
                  final t = _toTime(d.localFocalPoint.dx);
                  final p = _toPrice(d.localFocalPoint.dy);
                  if (t != null && p != null) {
                    setState(() { _brushPending = [DrawingPoint(t, p)]; _phase = DrawPhase.placingMore; });
                  }
                  return;
                }
                if (_drawing) {
                  _drawFinger = d.localFocalPoint; _drawCursorBase = _cursor;
                  return;
                }
                _inPriceAxis = d.localFocalPoint.dx > _chartW;
                if (_selVisible && d.pointerCount == 1) {
                  final ep = _findEndpointAt(d.localFocalPoint);
                  _selEndpoint   = ep;
                  _selDragOrigin = d.localFocalPoint;
                  _selLineOrig   = _selIdx != null ? _lines[_selIdx!] : null;
                  setState(() {});
                  return;
                }
                if (!_inPriceAxis && _cross != null &&
                    d.pointerCount == 1 && _phase == DrawPhase.idle) {
                  final t = d.localFocalPoint;
                  if ((t.dx - _cross!.dx).abs() < 28 || (t.dy - _cross!.dy).abs() < 28) {
                    _crossDrag = true; _lpFinger = t; _lpCrossStart = _cross;
                    return;
                  }
                }
                _startVis = _vis; _startPz = _pzoom;
              },
              onScaleUpdate: (d) {
                if (_tool == DrawTool.brush && _phase == DrawPhase.placingMore && d.pointerCount == 1) {
                  final t = _toTime(d.localFocalPoint.dx);
                  final p = _toPrice(d.localFocalPoint.dy);
                  if (t != null && p != null) {
                    setState(() => _brushPending.add(DrawingPoint(t, p)));
                  }
                  return;
                }
                if (_drawing && d.pointerCount == 1) {
                  final df = _drawFinger; final dc = _drawCursorBase;
                  if (df != null && dc != null) {
                    setState(() => _cursor = _snapCursor(dc + (d.localFocalPoint - df)));
                  }
                  return;
                }
                if (_selVisible && _selIdx != null && d.pointerCount == 1) {
                  final ep = _selEndpoint;
                  final orig = _selLineOrig;
                  final origin = _selDragOrigin;
                  if (orig == null || origin == null) { return; }
                  final totalDelta = d.localFocalPoint - origin;
                  if (ep != null) {
                    _moveSelEndpoint(ep, totalDelta, orig);
                  } else {
                    _moveSelLine(totalDelta, orig);
                  }
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
                if (_crossDrag || _longPress) {
                  final sf = _lpFinger; final sc = _lpCrossStart;
                  if (sf != null && sc != null) { _showCross(sc + (d.localFocalPoint - sf)); }
                  return;
                }
                final had = _cross != null;
                setState(() {
                  if (had) { _cross = null; _crossCandle = null; }
                  final mx = math.max(0.0, _c.length.toDouble() - _vis);
                  _scroll = (_scroll + d.focalPointDelta.dx / _cw)
                      .clamp(-_futureBuf.toDouble(), mx);
                });
                if (had) { widget.onCrosshair?.call(null); }
              },
              onScaleEnd: (_) {
                if (_tool == DrawTool.brush && _phase == DrawPhase.placingMore) {
                  if (_brushPending.length >= 2) {
                    final pts = List<DrawingPoint>.from(_brushPending);
                    setState(() {
                      _lines.add(ChartLine(
                        startTime: pts.first.time, endTime: pts.last.time,
                        startPrice: pts.first.price, endPrice: pts.last.price,
                        color: _dColor, width: _dWidth * 2, style: LineStyle.solid,
                        drawType: DrawTool.brush, pts: pts,
                      ));
                      _brushPending = []; _phase = DrawPhase.idle;
                    });
                    _notifyLinesChanged();
                  } else {
                    setState(() { _brushPending = []; _phase = DrawPhase.idle; });
                  }
                  return;
                }
                _selEndpoint = null; _selLineOrig = null; _selDragOrigin = null; _crossDrag = false;
              },
              onTapDown: (d) { _lastTouch = d.localPosition; },
              onTap: () {
                if (_drawing) { _handleDrawTap(); return; }
                final touch = _lastTouch;
                if (touch == null || _longPress) { return; }
                if (touch.dx < _chartW) { _handleTapOnChart(touch); }
              },
              child: CustomPaint(
                painter: _Painter(
                  candles: _c, vis: _vis, scroll: _scroll, pzoom: _pzoom,
                  cross: _cross, prefix: widget.pricePrefix,
                  activeIndicators: Set.unmodifiable(_activeIndicators),
                  indConfigs: Map.unmodifiable(_indConfigs),
                  lines: _lines, selIdx: _selIdx,
                  phase: _phase, cursor: _cursor,
                  fpTime: _fpTime, fpPrice: _fpPrice,
                  currentTool: _tool,
                  pendingPts: _pendingPts,
                  brushPending: _brushPending,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            ),  // Listener
            // OHLCV + 지표 레이블 — 왼쪽 상단
            Positioned(
              left: 4, top: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_crossCandle != null) ...[
                    _buildLegend(_crossCandle!),
                    if (_activeIndicators.isNotEmpty) const SizedBox(height: 4),
                  ],
                  if (_activeIndicators.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final meta in _kIndicators
                            .where((m) => _activeIndicators.contains(m.type)))
                          _buildIndLabel(meta),
                      ],
                    ),
                ],
              ),
            ),
            // Floating selection toolbar
            if (_selVisible)
              Positioned(
                left:  _selToolbarOffset.dx.clamp(0.0, clampX),
                top:   _selToolbarOffset.dy.clamp(0.0, clampY),
                child: _buildFloatingSelToolbar(),
              ),
          ]),
        ),
      ]);
    });
  }

  // ── Indicator label chip ──────────────────────────────────────────────────

  Widget _buildIndLabel(_IndMeta meta) {
    final config     = _indConfigs[meta.type]!;
    final base       = _indColor(meta.type);
    final color      = config.visible ? base : base.withValues(alpha: 0.3);
    final shortLabel = _buildShortLabel(meta.type, config.params);
    final isSel      = _selIndicator == meta.type;

    return GestureDetector(
      onTap: () => setState(() => _selIndicator = isSel ? null : meta.type),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSel
              ? Colors.white.withValues(alpha: 0.13)
              : Colors.black.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(5),
          border: isSel
              ? Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.9)
              : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(shortLabel, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w500,
            decoration: config.visible ? null : TextDecoration.lineThrough,
            decorationColor: color,
          )),
          if (isSel) ...[
            const SizedBox(width: 6),
            // 설정
            _indIconBtn(Icons.settings_outlined, () => _showIndicatorSettings(meta)),
            // 숨기기 / 보이기
            _indIconBtn(
              config.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              () => setState(() {
                _indConfigs[meta.type] = config.copyWith(visible: !config.visible);
              }),
              color: config.visible ? Colors.white70 : Colors.white38,
            ),
            // 제거
            _indIconBtn(Icons.close, () {
              setState(() {
                _activeIndicators.remove(meta.type);
                _selIndicator = null;
              });
            }, color: AppColors.red.withValues(alpha: 0.8)),
          ],
        ]),
      ),
    );
  }

  Widget _indIconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Icon(icon, size: 14, color: color ?? Colors.white70),
      ),
    );
  }

  static String _buildShortLabel(IndicatorType type, List<double> params) {
    switch (type) {
      case IndicatorType.rsi:
        return 'RSI(${params[0].toInt()})';
      case IndicatorType.macd:
        return 'MACD(${params[0].toInt()},${params[1].toInt()},${params[2].toInt()})';
      case IndicatorType.stochastic:
        return 'Stoch(${params[0].toInt()},${params[1].toInt()})';
      case IndicatorType.movingAverage:
        return 'MA(${params[0].toInt()}/${params[1].toInt()}/${params[2].toInt()})';
      case IndicatorType.bollingerBands:
        return 'BB(${params[0].toInt()},${params[1].toStringAsFixed(1)})';
      case IndicatorType.ichimoku:
        return 'Ichi(${params[0].toInt()},${params[1].toInt()},${params[2].toInt()})';
    }
  }

  // ── Indicator settings sheet ──────────────────────────────────────────────

  void _showIndicatorSettings(_IndMeta meta) {
    final config = _indConfigs[meta.type]!;
    final pLabels = _paramLabels(meta.type);
    final cLabels = _colorLabels(meta.type);
    final controllers = config.params
        .map((p) => TextEditingController(text: _fmtParam(p)))
        .toList();
    var tempColors = [...config.colors];
    Color tempLabelColor = config.labelColor ??
        (config.colors.isNotEmpty ? config.colors.first : const Color(0xFF7E57C2));

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(children: [
                  Text('${meta.name} 설정', style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final np = controllers
                          .map((c) => double.tryParse(c.text) ?? 14.0)
                          .toList();
                      setState(() => _indConfigs[meta.type] =
                          config.copyWith(params: np, colors: [...tempColors])
                              .withLabelColor(tempLabelColor));
                      Navigator.pop(ctx);
                    },
                    child: const Text('적용', style: TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              // Period / param inputs
              for (int i = 0; i < math.min(pLabels.length, controllers.length); i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(children: [
                    SizedBox(width: 100, child: Text(pLabels[i],
                        style: const TextStyle(color: AppColors.gray, fontSize: 13))),
                    const SizedBox(width: 12),
                    SizedBox(width: 80, child: TextField(
                      controller: controllers[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: true, fillColor: AppColors.card,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        isDense: true, contentPadding: const EdgeInsets.all(10),
                      ),
                    )),
                  ]),
                ),
              // Color pickers
              for (int i = 0; i < math.min(cLabels.length, tempColors.length); i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(children: [
                    SizedBox(width: 100, child: Text(cLabels[i],
                        style: const TextStyle(color: AppColors.gray, fontSize: 13))),
                    const SizedBox(width: 12),
                    Wrap(spacing: 10, children: _kColorOptions.map((col) {
                        final sel = tempColors[i].toARGB32() == col.toARGB32();
                        final ck = col.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                        return GestureDetector(
                          onTap: () => setModal(() => tempColors[i] = col),
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: col, shape: BoxShape.circle,
                              boxShadow: sel ? [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 0, spreadRadius: 3),
                                BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 0, spreadRadius: 1.5),
                              ] : [],
                            ),
                            child: sel ? Icon(Icons.check, size: 13, color: ck) : null,
                          ),
                        );
                      }).toList()),
                  ]),
                ),
              // Label color picker
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(children: [
                  const SizedBox(width: 100, child: Text('레이블 색상',
                      style: TextStyle(color: AppColors.gray, fontSize: 13))),
                  const SizedBox(width: 12),
                  Wrap(spacing: 10, children: _kColorOptions.map((col) {
                      final sel = tempLabelColor.toARGB32() == col.toARGB32();
                      final ck = col.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
                      return GestureDetector(
                        onTap: () => setModal(() => tempLabelColor = col),
                        child: Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: col, shape: BoxShape.circle,
                            boxShadow: sel ? [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 0, spreadRadius: 3),
                              BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 0, spreadRadius: 1.5),
                            ] : [],
                          ),
                          child: sel ? Icon(Icons.check, size: 13, color: ck) : null,
                        ),
                      );
                    }).toList()),
                ]),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      }),
    );
  }

  static List<String> _paramLabels(IndicatorType type) {
    switch (type) {
      case IndicatorType.rsi:            return ['기간'];
      case IndicatorType.macd:           return ['빠른선(EMA)', '느린선(EMA)', '시그널'];
      case IndicatorType.stochastic:     return ['기간(%K)', '스무딩(%D)'];
      case IndicatorType.movingAverage:  return ['단기', '중기', '장기'];
      case IndicatorType.bollingerBands: return ['기간', '배수(σ)'];
      case IndicatorType.ichimoku:       return ['전환선', '기준선', '선행스팬B'];
    }
  }

  static List<String> _colorLabels(IndicatorType type) {
    switch (type) {
      case IndicatorType.rsi:            return ['선 색상'];
      case IndicatorType.macd:           return ['MACD', '시그널'];
      case IndicatorType.stochastic:     return ['%K', '%D'];
      case IndicatorType.movingAverage:  return ['단기', '중기', '장기'];
      case IndicatorType.bollingerBands: return ['밴드', '중선'];
      case IndicatorType.ichimoku:       return ['전환선', '기준선', '선행A', '선행B'];
    }
  }

  static String _fmtParam(double p) =>
      (p == p.roundToDouble()) ? p.toInt().toString() : p.toStringAsFixed(1);

  // ── Main toolbar ──────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return SizedBox(
      height: _baseToolH,
      child: Row(children: [
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showDrawingPicker,
          child: Container(
            width: 26, height: 26, padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: (_drawing || _drawingPickerOpen || _tool != DrawTool.none)
                  ? AppColors.green.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (_drawing || _drawingPickerOpen || _tool != DrawTool.none)
                    ? AppColors.green.withValues(alpha: 0.6) : Colors.white24,
              ),
            ),
            child: Image.asset('assets/icons/pencil_draw.png',
                fit: BoxFit.contain,
                color: (_drawing || _drawingPickerOpen || _tool != DrawTool.none)
                    ? AppColors.green : AppColors.gray),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showIndicatorPicker,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: (_activeIndicators.isNotEmpty || _indicatorPickerOpen)
                  ? AppColors.green.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (_activeIndicators.isNotEmpty || _indicatorPickerOpen)
                    ? AppColors.green.withValues(alpha: 0.6) : Colors.white24,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('보조지표', style: TextStyle(
                color: (_activeIndicators.isNotEmpty || _indicatorPickerOpen) ? AppColors.green : AppColors.gray,
                fontSize: 10, fontWeight: FontWeight.w600,
              )),
              if (_activeIndicators.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                      color: AppColors.green, borderRadius: BorderRadius.circular(8)),
                  child: Text('${_activeIndicators.length}', style: const TextStyle(
                    color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold,
                  )),
                ),
              ],
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // ── 매매선 버튼
        GestureDetector(
          onTap: _showTradingLinePicker,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _lines.any((l) => l.role != LineRole.none)
                  ? const Color(0xFFCE93D8).withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _lines.any((l) => l.role != LineRole.none)
                    ? const Color(0xFFCE93D8).withValues(alpha: 0.6) : Colors.white24,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('매매선', style: TextStyle(
                color: _lines.any((l) => l.role != LineRole.none)
                    ? const Color(0xFFCE93D8) : AppColors.gray,
                fontSize: 10, fontWeight: FontWeight.w600,
              )),
              if (_lines.any((l) => l.role != LineRole.none)) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCE93D8), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${_lines.where((l) => l.role != LineRole.none).length}',
                    style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Floating selection toolbar ─────────────────────────────────────────────

  Widget _buildFloatingSelToolbar() {
    final i = _selIdx;
    if (i == null || i >= _lines.length) { return const SizedBox.shrink(); }
    final ln = _lines[i];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C2232),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 10, offset: const Offset(0, 3),
          )],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          GestureDetector(
            onPanUpdate: (d) => setState(() {
              _selToolbarOffset = Offset(
                (_selToolbarOffset.dx + d.delta.dx)
                    .clamp(0.0, math.max(0.0, _chartW - 268)).toDouble(),
                (_selToolbarOffset.dy + d.delta.dy)
                    .clamp(0.0, math.max(0.0, _chartH - 52)).toDouble(),
              );
            }),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
              child: Icon(Icons.drag_indicator, size: 16, color: Colors.white30),
            ),
          ),
          _fDiv(),
          Builder(builder: (ctx) => GestureDetector(
            onTap: () => _showSelColorMenu(ctx, ln),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: ln.color, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white38, width: 1.5),
                ),
              ),
            ),
          )),
          _fDiv(),
          Builder(builder: (ctx) => GestureDetector(
            onTap: () => _showSelWidthMenu(ctx, ln),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text('${ln.width.toInt()}px', style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
              )),
            ),
          )),
          _fDiv(),
          Builder(builder: (ctx) => GestureDetector(
            onTap: () => _showSelStyleMenu(ctx, ln),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: SizedBox(
                width: 24, height: 10,
                child: CustomPaint(
                  painter: _LinePreviewPainter(ln.style, ln.color, ln.width.clamp(1, 2.5)),
                ),
              ),
            ),
          )),
          _fDiv(),
          // 역할 지정 버튼
          GestureDetector(
            onTap: () { final i = _selIdx; if (i != null) _showRolePicker(i); },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(ln.role.icon, size: 14,
                    color: ln.role != LineRole.none ? ln.role.roleColor : Colors.white54),
                const SizedBox(width: 3),
                Text(ln.role.label, style: TextStyle(
                  color: ln.role != LineRole.none ? ln.role.roleColor : Colors.white54,
                  fontSize: 10, fontWeight: FontWeight.w600,
                )),
              ]),
            ),
          ),
          _fDiv(),
          GestureDetector(
            onTap: _cloneSel,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Icon(Icons.copy_outlined, size: 16, color: Colors.white60),
            ),
          ),
          GestureDetector(
            onTap: _deleteSel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Icon(Icons.delete_outline, size: 16,
                  color: AppColors.red.withValues(alpha: 0.8)),
            ),
          ),
          _fDiv(),
          GestureDetector(
            onTap: () => setState(() { _phase = DrawPhase.idle; _selIdx = null; _selEndpoint = null; }),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Icon(Icons.close, size: 15, color: Colors.white30),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fDiv() => Container(
    width: 1, height: 22, color: Colors.white.withValues(alpha: 0.1));

  // ── 역할 지정 ──────────────────────────────────────────────────────────────

  void _showRolePicker(int lineIdx) {
    final ln = _lines[lineIdx];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('역할 지정', style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: LineRole.values.map((role) {
            final sel = ln.role == role;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _lines[lineIdx] = ln.copyWith(
                    role: role,
                    color: role != LineRole.none ? role.roleColor : ln.color,
                  );
                });
                _notifyLinesChanged();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: sel
                      ? role.roleColor.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? role.roleColor : Colors.white24,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(role.icon, size: 14, color: sel ? role.roleColor : Colors.white54),
                  const SizedBox(width: 6),
                  Text(role.label, style: TextStyle(
                    color: sel ? role.roleColor : Colors.white70,
                    fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  )),
                ]),
              ),
            );
          }).toList()),
        ]),
      ),
    );
  }

  // ── 매매선 관리 피커 ───────────────────────────────────────────────────────

  void _showTradingLinePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(builder: (_, setSheet) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55, minChildSize: 0.35, maxChildSize: 0.85,
          expand: false,
          builder: (_, scroll) => Column(children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Text('매매선 관리', style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('추세선에 역할을 지정하거나 새 매매선을 그립니다.',
                style: TextStyle(color: Color(0xFF8891A4), fontSize: 11)),
            ),
            Expanded(
              child: _lines.isEmpty
                  ? Center(child: Text('추세선이 없습니다.\n아래 버튼으로 새 선을 그려보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gray.withValues(alpha: 0.6), fontSize: 13)))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: _lines.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (_, i) {
                        final ln = _lines[i];
                        final roleColor = ln.role != LineRole.none
                            ? ln.role.roleColor : Colors.white38;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: ln.role != LineRole.none
                                  ? roleColor.withValues(alpha: 0.4) : Colors.white12,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(ln.role.icon, size: 16, color: roleColor),
                            ),
                            title: Text(ln.role.label, style: TextStyle(
                              color: roleColor, fontSize: 13, fontWeight: FontWeight.w600,
                            )),
                            subtitle: Text(
                              ln.isHorizontal
                                  ? '수평선  ${ln.startPrice.toStringAsFixed(0)}원'
                                  : '${ln.startPrice.toStringAsFixed(0)} → ${ln.endPrice.toStringAsFixed(0)}원',
                              style: const TextStyle(color: Color(0xFF8891A4), fontSize: 11),
                            ),
                            trailing: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _showRolePicker(i);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFCE93D8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('역할 변경', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _tool = DrawTool.trendLine;
                      _phase = DrawPhase.placingFirst;
                      _cursor = Offset(_chartW / 2, _chartH * 0.35);
                      _drawFinger = null; _drawCursorBase = null;
                      _fpTime = null; _fpPrice = null;
                      _selIdx = null; _selEndpoint = null;
                      _cross = null; _crossCandle = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCE93D8).withValues(alpha: 0.2),
                    foregroundColor: const Color(0xFFCE93D8),
                    side: const BorderSide(color: Color(0xFFCE93D8), width: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('새 선 그리기', style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

  // ── Indicator picker ──────────────────────────────────────────────────────

  void _showIndicatorPicker() {
    setState(() => _indicatorPickerOpen = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62, minChildSize: 0.4, maxChildSize: 0.88,
          expand: false,
          builder: (ctx, scroll) => Column(children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(children: [
                const Text('보조지표', style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_activeIndicators.isNotEmpty)
                  GestureDetector(
                    onTap: () { setState(() => _activeIndicators.clear()); setModal(() {}); },
                    child: Text('전체 해제', style: TextStyle(
                        color: AppColors.red.withValues(alpha: 0.85), fontSize: 12)),
                  ),
              ]),
            ),
            Expanded(child: GridView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 10,
                mainAxisSpacing: 10, childAspectRatio: 1.6,
              ),
              itemCount: _kIndicators.length,
              itemBuilder: (_, idx) {
                final meta   = _kIndicators[idx];
                final active = _activeIndicators.contains(meta.type);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (active) {
                        _activeIndicators.remove(meta.type);
                      } else {
                        _activeIndicators.add(meta.type);
                      }
                    });
                    setModal(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.green.withValues(alpha: 0.1)
                          : const Color(0xFF252A34),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? AppColors.green.withValues(alpha: 0.55)
                            : Colors.white12,
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(meta.name, style: TextStyle(
                          color: active ? AppColors.green : Colors.white,
                          fontSize: 13, fontWeight: FontWeight.bold,
                        ))),
                        if (active) const Icon(Icons.check_circle, size: 14, color: AppColors.green),
                      ]),
                      const SizedBox(height: 2),
                      Text(meta.shortName, style: const TextStyle(
                          color: AppColors.gray, fontSize: 10)),
                      const SizedBox(height: 5),
                      Expanded(child: Text(meta.description, style: const TextStyle(
                        color: Color(0xFF8891A4), fontSize: 10, height: 1.4,
                      ), overflow: TextOverflow.fade)),
                    ]),
                  ),
                );
              },
            )),
          ]),
        );
      }),
    ).then((_) { if (mounted) setState(() => _indicatorPickerOpen = false); });
  }

  void _showDrawingPicker() {
    setState(() => _drawingPickerOpen = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _DrawingPickerSheet(
        activeTool: _tool,
        onToolSelected: (tool) {
          Navigator.pop(ctx);
          _activateTool(tool);
        },
      ),
    ).then((_) { if (mounted) setState(() => _drawingPickerOpen = false); });
  }

  // ── Popup menus ───────────────────────────────────────────────────────────

  void _showSelColorMenu(BuildContext ctx, ChartLine ln) async {
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final c = await showMenu<Color>(
      context: ctx,
      color: const Color(0xFF1A1F2E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white12)),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + box.size.height + 4, pos.dx + 160, 0),
      items: _kColorOptions.map((col) {
        final sel = ln.color.toARGB32() == col.toARGB32();
        final ck = col.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
        return PopupMenuItem<Color>(value: col, height: 36, child: Row(children: [
          Container(width: 18, height: 18, decoration: BoxDecoration(
            color: col, shape: BoxShape.circle,
            boxShadow: sel ? [
              BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 0, spreadRadius: 2.5),
              BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 0, spreadRadius: 1.5),
            ] : [],
          ), child: sel ? Icon(Icons.check, size: 11, color: ck) : null),
          const SizedBox(width: 10),
          Text(_colorName(col), style: TextStyle(
              color: sel ? Colors.white : Colors.white70, fontSize: 12)),
          if (sel) ...[const Spacer(), const Icon(Icons.check, size: 12, color: AppColors.green)],
        ]));
      }).toList(),
    );
    if (c != null) { _updateSel(color: c); }
  }

  void _showSelWidthMenu(BuildContext ctx, ChartLine ln) async {
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final w = await showMenu<double>(
      context: ctx,
      color: const Color(0xFF1A1F2E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white12)),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + box.size.height + 4, pos.dx + 100, 0),
      items: [1.0, 2.0, 3.0, 4.0].map((wv) {
        final sel = (ln.width - wv).abs() < 0.1;
        return PopupMenuItem<double>(value: wv, height: 28, child: SizedBox(width: 66,
          child: Row(children: [
            Container(width: 22, height: sel ? wv + 1 : wv, color: sel ? AppColors.green : Colors.white54),
            const SizedBox(width: 8),
            Text('${wv.toInt()}px', style: TextStyle(
                color: sel ? AppColors.green : Colors.white70,
                fontSize: 11, fontWeight: FontWeight.w600)),
            if (sel) ...[const Spacer(), const Icon(Icons.check, size: 11, color: AppColors.green)],
          ]),
        ));
      }).toList(),
    );
    if (w != null) { _updateSel(width: w); }
  }

  void _showSelStyleMenu(BuildContext ctx, ChartLine ln) async {
    final box = ctx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final s = await showMenu<LineStyle>(
      context: ctx,
      color: const Color(0xFF1A1F2E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.white12)),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + box.size.height + 4, pos.dx + 120, 0),
      items: LineStyle.values.map((style) {
        final sel = ln.style == style;
        return PopupMenuItem<LineStyle>(value: style, height: 32,
          child: SizedBox(width: 70, child: Row(children: [
            SizedBox(width: 44, height: 10, child: CustomPaint(
              painter: _LinePreviewPainter(style, sel ? Colors.white : Colors.white54, 1.5),
            )),
            const Spacer(),
            if (sel) const Icon(Icons.check, size: 11, color: AppColors.green),
          ])));
      }).toList(),
    );
    if (s != null) { _updateSel(style: s); }
  }

  static String _colorName(Color c) {
    if (c == Colors.white)             { return '흰색'; }
    if (c == const Color(0xFFFFD700))  { return '노란색'; }
    if (c == const Color(0xFF4FC3F7))  { return '하늘색'; }
    if (c == AppColors.green)          { return '초록색'; }
    if (c == AppColors.red)            { return '빨간색'; }
    if (c == const Color(0xFFCE93D8))  { return '보라색'; }
    if (c == const Color(0xFFFF8A65))  { return '주황색'; }
    return '';
  }
}

// ─── Line preview painter ────────────────────────────────────────────────────

class _LinePreviewPainter extends CustomPainter {
  final LineStyle style;
  final Color color;
  final double lineWidth;
  const _LinePreviewPainter(this.style, this.color, this.lineWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Offset(0, size.height / 2);
    final p2 = Offset(size.width, size.height / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    switch (style) {
      case LineStyle.solid:  canvas.drawLine(p1, p2, paint);
      case LineStyle.dashed: _dash(canvas, p1, p2, paint, dash: 6, gap: 4);
      case LineStyle.dotted: _dot(canvas, p1, p2);
    }
  }

  void _dash(Canvas c, Offset p1, Offset p2, Paint paint, {double dash=4, double gap=4}) {
    final d = p2 - p1; final len = d.distance; if (len == 0) { return; }
    final u = d / len; double pos = 0; bool draw = true;
    while (pos < len) {
      final seg = math.min(pos + (draw ? dash : gap), len);
      if (draw) { c.drawLine(p1 + u * pos, p1 + u * seg, paint); }
      pos = seg; draw = !draw;
    }
  }

  void _dot(Canvas c, Offset p1, Offset p2) {
    final d = p2 - p1; final len = d.distance; if (len == 0) { return; }
    final u = d / len; final gap = lineWidth * 3.5; double pos = lineWidth / 2;
    while (pos < len) {
      c.drawCircle(p1 + u * pos, lineWidth / 2, Paint()..color = color);
      pos += gap;
    }
  }

  @override
  bool shouldRepaint(_LinePreviewPainter o) =>
      style != o.style || color != o.color || lineWidth != o.lineWidth;
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _Painter extends CustomPainter {
  final List<CandleData> candles;
  final double vis, scroll, pzoom;
  final Offset? cross;
  final String prefix;
  final Set<IndicatorType> activeIndicators;
  final Map<IndicatorType, IndicatorConfig> indConfigs;
  final List<ChartLine> lines;
  final int? selIdx;
  final DrawPhase phase;
  final Offset? cursor;
  final int? fpTime;
  final double? fpPrice;
  final DrawTool currentTool;
  final List<DrawingPoint> pendingPts;
  final List<DrawingPoint> brushPending;

  static const _axisW    = 58.0;
  static const _timeH    = 26.0;
  static const _volR     = 0.18;
  static const _panelH   = 80.0;
  static const _futureBuf = 500;

  _Painter({
    required this.candles, required this.vis, required this.scroll,
    required this.pzoom,   required this.cross, required this.prefix,
    required this.activeIndicators, required this.indConfigs,
    required this.lines, required this.selIdx,
    required this.phase,   required this.cursor,
    required this.fpTime,  required this.fpPrice,
    required this.currentTool,
    required this.pendingPts,
    required this.brushPending,
  });

  bool _indVisible(IndicatorType t) =>
      activeIndicators.contains(t) && (indConfigs[t]?.visible ?? true);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) { return; }
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final mx          = math.max(0.0, candles.length.toDouble() - vis);
    final off         = scroll.clamp(-_futureBuf.toDouble(), mx);
    final futureSlots = off < 0 ? (-off).round().clamp(0, _futureBuf) : 0;
    final normalOff   = math.max(0.0, off);
    final e        = (candles.length - normalOff.round()).clamp(0, candles.length);
    final minCandles = math.max(1, math.min(20, math.min(candles.length, vis.floor().toInt())));
    final wantData = (vis.ceil() - futureSlots).clamp(minCandles, candles.length);
    final s        = (e - wantData).clamp(0, candles.length);
    final vc       = candles.sublist(s, e);
    if (vc.isEmpty) { canvas.restore(); return; }
    final rp = (vis - vc.length - futureSlots).clamp(0.0, double.infinity);

    final panelCount  = activeIndicators.where((t) => _panelIndicatorTypes.contains(t) && (indConfigs[t]?.visible ?? true)).length;
    final totalPanelH = panelCount * _panelH;
    final chartW  = size.width - _axisW;
    final usableH = size.height - _timeH - totalPanelH;
    final pH = usableH * (1 - _volR);
    final vH = usableH * _volR;
    final cw = chartW / vis;

    double lo = vc[0].low, hi = vc[0].high, mv = vc[0].volume;
    for (final c in vc) {
      if (c.low  < lo) { lo = c.low; }
      if (c.high > hi) { hi = c.high; }
      if (c.volume > mv) { mv = c.volume; }
    }
    final pad   = (hi - lo) * 0.06;
    final cent  = (hi + lo) / 2;
    final half  = (hi - lo) / 2 + pad;
    final pMin  = cent - half / pzoom;
    final pMax  = cent + half / pzoom;
    final pSpan = pMax - pMin;
    if (pSpan <= 0) { canvas.restore(); return; }

    double pyF(double p) => pH - (p - pMin) / pSpan * pH;
    double vyF(double v) => mv > 0 ? (v / mv) * vH * 0.9 : 0;

    // Grid
    final grid = Paint()..color = const Color(0xFF252A34)..strokeWidth = 0.5;
    for (var i = 1; i < 5; i++) {
      canvas.drawLine(Offset(0, pH * i / 5), Offset(chartW, pH * i / 5), grid);
    }
    canvas.drawLine(Offset(0, pH), Offset(chartW, pH), grid);

    // Overlay indicators
    canvas.save(); canvas.clipRect(Rect.fromLTWH(0, 0, chartW, pH));
    if (_indVisible(IndicatorType.bollingerBands)) {
      _drawBB(canvas, candles, vc, s, pyF, cw, rp);
    }
    if (_indVisible(IndicatorType.ichimoku)) {
      _drawIchimoku(canvas, candles, vc, s, pyF, cw, rp, futureSlots);
    }
    canvas.restore();

    // Candles
    canvas.save(); canvas.clipRect(Rect.fromLTWH(0, 0, chartW, pH));
    for (var i = 0; i < vc.length; i++) {
      final c  = vc[i];
      final x  = (rp + i + 0.5) * cw;
      final up = c.close >= c.open;
      final col = up ? AppColors.green : AppColors.red;
      final bw  = math.max(cw * 0.65, 1.0);
      canvas.drawLine(Offset(x, pyF(c.high)), Offset(x, pyF(c.low)),
          Paint()..color = col..strokeWidth = math.max(cw * 0.12, 0.8));
      final t = pyF(math.max(c.open, c.close));
      final b = pyF(math.min(c.open, c.close));
      canvas.drawRect(Rect.fromLTWH(x - bw / 2, t, bw, math.max(b - t, 1.0)),
          Paint()..color = col);
    }
    canvas.restore();

    if (_indVisible(IndicatorType.movingAverage)) {
      canvas.save(); canvas.clipRect(Rect.fromLTWH(0, 0, chartW, pH));
      _drawMA(canvas, candles, vc, s, pyF, cw, rp);
      canvas.restore();
    }

    // Volume
    for (var i = 0; i < vc.length; i++) {
      final c  = vc[i];
      final x  = (rp + i + 0.5) * cw;
      final bw = math.max(cw * 0.65, 1.0);
      final vh = vyF(c.volume);
      canvas.drawRect(
        Rect.fromLTWH(x - bw / 2, pH + vH - vh, bw, vh),
        Paint()..color = (c.close >= c.open ? AppColors.green : AppColors.red)
            .withValues(alpha: 0.35),
      );
    }

    // Trend lines — 캔들 영역(pH)으로 클리핑
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, chartW, pH));
    _drawLines(canvas, vc, chartW, pH, pyF, cw, rp);
    canvas.restore();

    // Panel indicators
    double panY = usableH + _timeH;
    for (final pt in [IndicatorType.rsi, IndicatorType.macd, IndicatorType.stochastic]) {
      if (!_indVisible(pt)) { continue; }
      _drawPanelBg(canvas, panY, chartW);
      switch (pt) {
        case IndicatorType.rsi:        _drawRsi(canvas, candles, vc, s, chartW, panY, cw, rp);
        case IndicatorType.macd:       _drawMacd(canvas, candles, vc, s, chartW, panY, cw, rp);
        case IndicatorType.stochastic: _drawStochastic(canvas, candles, vc, s, chartW, panY, cw, rp);
        default: break;
      }
      panY += _panelH;
    }

    // Price axis labels — nice round ticks
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final p in _niceTicks(pMin, pMax, 4)) {
      final y = pyF(p);
      if (y < -2 || y > pH + 2) continue;
      tp.text = TextSpan(text: _fmtAxis(p), style: const TextStyle(color: AppColors.gray, fontSize: 10));
      tp.layout();
      tp.paint(canvas, Offset(chartW + 4, y - tp.height / 2));
    }

    // Time axis labels (past + future, no overlap)
    final avgI   = vc.length >= 2
        ? (vc.last.time - vc.first.time) / math.max(1, vc.length - 1)
        : 86400.0;
    final hhmm   = avgI < 14400;
    final mmdd   = avgI < 172800;
    final yyyymm = avgI < 5184000;

    String tfmt(int t) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true);
      if (hhmm)   { return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}'; }
      if (mmdd)   { return '${dt.month}/${dt.day}'; }
      if (yyyymm) { return '${dt.year}/${dt.month.toString().padLeft(2,'0')}'; }
      return '${dt.year}';
    }

    final lpw    = hhmm ? 34.0 : mmdd ? 26.0 : yyyymm ? 46.0 : 30.0;
    final minStp = math.max(1, ((lpw + 8) / math.max(cw, 0.1)).ceil());
    final step   = math.max(minStp, math.max(1, (vc.length / 6).round()));
    final xAxisY = usableH + 4;

    // 장중(intraday) 차트에서 세션 경계 캔들 검출
    // 연속 간격이 평균의 3배 이상 = 개장/폐장 경계
    final sessionBounds = <int>{};
    if (hhmm && vc.length >= 2) {
      for (int i = 0; i < vc.length; i++) {
        final gapB = i == 0           ? double.infinity : (vc[i].time - vc[i-1].time).toDouble();
        final gapA = i == vc.length-1 ? double.infinity : (vc[i+1].time - vc[i].time).toDouble();
        if (gapB > avgI * 3 || gapA > avgI * 3) sessionBounds.add(i);
      }
    }

    // 겹침 없는 라벨 드로우 헬퍼
    final drawnRng = <(double, double)>[];
    bool fits(double lx, double w) =>
        drawnRng.every((r) => lx >= r.$2 + 4 || lx + w <= r.$1 - 4);

    void drawTL(double x, int t, Color c) {
      if (x < 0 || x > chartW) return;
      tp.text = TextSpan(text: tfmt(t), style: TextStyle(color: c, fontSize: 10));
      tp.layout();
      final lx = x - tp.width / 2;
      if (lx < 0 || lx + tp.width > chartW) return;
      if (fits(lx, tp.width)) {
        tp.paint(canvas, Offset(lx, xAxisY));
        drawnRng.add((lx, lx + tp.width));
      }
    }

    // 1순위: 개장/폐장 시각 (밝게)
    for (final i in sessionBounds.toList()..sort()) {
      drawTL((rp + i + 0.5) * cw, vc[i].time, Colors.white70);
    }
    // 2순위: 일반 스텝 라벨
    for (var i = 0; i < vc.length; i += step) {
      if (sessionBounds.contains(i)) continue;
      drawTL((rp + i + 0.5) * cw, vc[i].time, AppColors.gray);
    }
    // 미래 슬롯 라벨
    if (futureSlots > 0) {
      final lastTime = vc.last.time;
      for (var fi = 0; fi < futureSlots; fi += step) {
        final x = (rp + vc.length + fi + 0.5) * cw;
        if (x > chartW) break;
        drawTL(x, (lastTime + (fi + 1) * avgI).round(), const Color(0xFF4A5368));
      }
    }

    // Crosshair
    if (cross != null && phase == DrawPhase.idle) {
      final pos        = cross!;
      final totalSlots = vc.length + futureSlots;
      final slot = ((pos.dx / cw) - rp).round().clamp(0, totalSlots - 1);
      final sx   = (rp + slot + 0.5) * cw;
      final isFuture = slot >= vc.length;
      final dash = Paint()..color = AppColors.gray.withValues(alpha: 0.7)..strokeWidth = 0.8;
      _dashed(canvas, Offset(sx, 0), Offset(sx, size.height), dash);
      if (pos.dy >= 0 && pos.dy < pH) {
        _dashed(canvas, Offset(0, pos.dy), Offset(chartW, pos.dy), dash);
        final pr = pMin + (1 - pos.dy / pH) * pSpan;
        _axisLabel(canvas, chartW + 4, pos.dy, _fmt(pr), center: false);
      }
      // Volume (과거 캔들만)
      if (!isFuture) {
        final volStr = _fmtVol(vc[slot].volume);
        _axisLabel(canvas, chartW + 4, pH + vH / 2, volStr,
            center: false, color: Colors.white54);
      }
      // Time label
      final int crossTime;
      if (!isFuture) {
        crossTime = vc[slot].time;
      } else {
        final fi = slot - vc.length;
        crossTime = (vc.last.time + (fi + 1) * avgI).round();
      }
      final dtc = DateTime.fromMillisecondsSinceEpoch(crossTime * 1000, isUtc: true);
      final cl = hhmm
          ? '${dtc.hour.toString().padLeft(2,'0')}:${dtc.minute.toString().padLeft(2,'0')}'
          : '${dtc.year}/${dtc.month.toString().padLeft(2,'0')}/${dtc.day.toString().padLeft(2,'0')}';
      _axisLabel(canvas, sx, xAxisY, cl,
          center: true,
          color: isFuture ? const Color(0xFF4A5368) : Colors.white);
    }

    // Drawing cursor & in-progress strokes
    if (phase == DrawPhase.placingFirst || phase == DrawPhase.placingSecond ||
        phase == DrawPhase.placingMore) {
      if (currentTool != DrawTool.brush) {
        final cur = cursor;
        if (cur != null) {
          final gd = Paint()..color = AppColors.green.withValues(alpha: 0.8)..strokeWidth = 0.8;
          _dashed(canvas, Offset(cur.dx, 0), Offset(cur.dx, usableH), gd);
          _dashed(canvas, Offset(0, cur.dy), Offset(chartW, cur.dy), gd);
          _drawAnchor(canvas, cur, AppColors.green);
          if (cur.dy >= 0 && cur.dy < pH) {
            final pr = pMin + (1 - cur.dy / pH) * pSpan;
            _axisLabel(canvas, chartW + 4, cur.dy, _fmt(pr),
                center: false, color: AppColors.green);
          }
        }
        // Draw all pending placed points and connecting lines
        Offset? prevAnchor;
        for (final pt in pendingPts) {
          final px = _txToX(pt.time, vc, cw, rp);
          final py = pyF(pt.price);
          final anchor = Offset(px, py);
          if (prevAnchor != null) {
            canvas.drawLine(prevAnchor, anchor,
                Paint()..color = AppColors.green.withValues(alpha: 0.5)..strokeWidth = 1.5);
          }
          _drawAnchor(canvas, anchor, AppColors.green);
          prevAnchor = anchor;
        }
        if (prevAnchor != null && cursor != null) {
          canvas.drawLine(prevAnchor, cursor!,
              Paint()..color = AppColors.green.withValues(alpha: 0.5)..strokeWidth = 1.5);
        } else if (pendingPts.isEmpty && phase == DrawPhase.placingSecond &&
            fpTime != null && fpPrice != null) {
          double? fx;
          for (int i = 0; i < vc.length; i++) {
            if (vc[i].time >= fpTime!) { fx = (rp + i + 0.5) * cw; break; }
          }
          final fy = pyF(fpPrice!);
          if (fx != null) {
            _drawAnchor(canvas, Offset(fx, fy), AppColors.green);
            if (cursor != null) {
              canvas.drawLine(Offset(fx, fy), cursor!,
                  Paint()..color = AppColors.green.withValues(alpha: 0.5)..strokeWidth = 1.5);
            }
          }
        }
      }
    }

    // Brush in-progress stroke
    if (currentTool == DrawTool.brush && brushPending.length >= 2) {
      final path = Path();
      for (int i = 0; i < brushPending.length; i++) {
        final px = _txToX(brushPending[i].time, vc, cw, rp);
        final py = pyF(brushPending[i].price);
        if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
      }
      canvas.drawPath(path, Paint()
        ..color = AppColors.green.withValues(alpha: 0.8)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round);
    }

    canvas.restore();
  }

  // ── Indicator drawing ─────────────────────────────────────────────────────

  void _drawPanelBg(Canvas canvas, double panY, double chartW) {
    canvas.drawRect(Rect.fromLTWH(0, panY, chartW + _axisW, _panelH),
        Paint()..color = const Color(0xFF0D1117));
    canvas.drawLine(Offset(0, panY), Offset(chartW + _axisW, panY),
        Paint()..color = const Color(0xFF252A34)..strokeWidth = 0.5);
  }

  void _drawMA(Canvas canvas, List<CandleData> all, List<CandleData> vc,
      int si, double Function(double) pyFn, double cw, double rp) {
    final cfg     = indConfigs[IndicatorType.movingAverage] ?? _kDefaultConfigs[IndicatorType.movingAverage]!;
    final periods = cfg.params.map((p) => p.toInt()).toList();
    final colors  = cfg.colors;
    for (int pi = 0; pi < periods.length; pi++) {
      final period = periods[pi];
      final color  = pi < colors.length ? colors[pi] : Colors.white;
      final path = Path(); bool started = false;
      for (int i = 0; i < vc.length; i++) {
        final ai = si + i;
        if (ai < period - 1) { continue; }
        double sum = 0;
        for (int j = ai - period + 1; j <= ai; j++) { sum += all[j].close; }
        final x = (rp + i + 0.5) * cw;
        final y = pyFn(sum / period);
        if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path,
          Paint()..color = color..strokeWidth = 1.0..style = PaintingStyle.stroke);
    }
  }

  void _drawBB(Canvas canvas, List<CandleData> all, List<CandleData> vc,
      int si, double Function(double) pyFn, double cw, double rp) {
    final cfg    = indConfigs[IndicatorType.bollingerBands] ?? _kDefaultConfigs[IndicatorType.bollingerBands]!;
    final period = cfg.params[0].toInt();
    final mult   = cfg.params.length > 1 ? cfg.params[1] : 2.0;
    final bandC  = cfg.colors.isNotEmpty ? cfg.colors[0] : const Color(0xFF4FC3F7);
    final midC   = cfg.colors.length > 1 ? cfg.colors[1] : const Color(0xFF78909C);

    final upPts = <Offset>[], midPts = <Offset>[], loPts = <Offset>[];
    for (int i = 0; i < vc.length; i++) {
      final ai = si + i;
      if (ai < period - 1) { continue; }
      double sum = 0;
      for (int j = ai - period + 1; j <= ai; j++) { sum += all[j].close; }
      final sma = sum / period;
      double vari = 0;
      for (int j = ai - period + 1; j <= ai; j++) { vari += math.pow(all[j].close - sma, 2); }
      final sd = math.sqrt(vari / period);
      final x  = (rp + i + 0.5) * cw;
      upPts.add(Offset(x, pyFn(sma + mult * sd)));
      midPts.add(Offset(x, pyFn(sma)));
      loPts.add(Offset(x, pyFn(sma - mult * sd)));
    }
    if (upPts.isEmpty) { return; }
    final fill = Path()..moveTo(upPts.first.dx, upPts.first.dy);
    for (final p in upPts) { fill.lineTo(p.dx, p.dy); }
    for (final p in loPts.reversed) { fill.lineTo(p.dx, p.dy); }
    fill.close();
    canvas.drawPath(fill, Paint()..color = bandC.withValues(alpha: 0.06));
    void drl(List<Offset> pts, Paint p) {
      if (pts.isEmpty) { return; }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts) { path.lineTo(pt.dx, pt.dy); }
      canvas.drawPath(path, p);
    }
    drl(upPts,  Paint()..color = bandC.withValues(alpha: 0.5)..strokeWidth = 0.8..style = PaintingStyle.stroke);
    drl(midPts, Paint()..color = midC.withValues(alpha: 0.7)..strokeWidth = 0.8..style = PaintingStyle.stroke);
    drl(loPts,  Paint()..color = bandC.withValues(alpha: 0.5)..strokeWidth = 0.8..style = PaintingStyle.stroke);
  }

  void _drawIchimoku(Canvas canvas, List<CandleData> all, List<CandleData> vc,
      int si, double Function(double) pyFn, double cw, double rp, int futureSlots) {
    final cfg  = indConfigs[IndicatorType.ichimoku] ?? _kDefaultConfigs[IndicatorType.ichimoku]!;
    final tenP = cfg.params[0].toInt();
    final kijP = cfg.params.length > 1 ? cfg.params[1].toInt() : 26;
    final spanP= cfg.params.length > 2 ? cfg.params[2].toInt() : 52;
    final cols = cfg.colors;
    final tenC = cols.isNotEmpty     ? cols[0] : const Color(0xFFEF5350);
    final kijC = cols.length > 1     ? cols[1] : const Color(0xFF1976D2);
    final spAC = cols.length > 2     ? cols[2] : AppColors.green;
    final spBC = cols.length > 3     ? cols[3] : AppColors.red;

    double calcMid(int endIdx, int n) {
      final start = math.max(0, endIdx - n + 1);
      double lo = all[start].low, hi = all[start].high;
      for (int j = start + 1; j <= endIdx; j++) {
        if (all[j].low < lo) { lo = all[j].low; }
        if (all[j].high > hi) { hi = all[j].high; }
      }
      return (hi + lo) / 2;
    }

    final tenPts = <Offset>[], kijPts = <Offset>[], spAPts = <Offset>[], spBPts = <Offset>[];
    final total  = vc.length + futureSlots;
    for (int slot = 0; slot < total; slot++) {
      final x       = (rp + slot + 0.5) * cw;
      final dataIdx = si + slot;
      final spanSrc = dataIdx - kijP;
      if (slot < vc.length && dataIdx < all.length) {
        if (dataIdx >= tenP - 1) { tenPts.add(Offset(x, pyFn(calcMid(dataIdx, tenP)))); }
        if (dataIdx >= kijP - 1) { kijPts.add(Offset(x, pyFn(calcMid(dataIdx, kijP)))); }
      }
      if (spanSrc >= kijP - 1 && spanSrc < all.length) {
        final tk = calcMid(spanSrc, tenP);
        final kj = calcMid(spanSrc, kijP);
        final sA = (tk + kj) / 2;
        final sB = spanSrc >= spanP - 1 ? calcMid(spanSrc, spanP) : calcMid(spanSrc, spanSrc + 1);
        spAPts.add(Offset(x, pyFn(sA)));
        spBPts.add(Offset(x, pyFn(sB)));
      }
    }
    if (spAPts.length >= 2 && spAPts.length == spBPts.length) {
      for (int i = 0; i < spAPts.length - 1; i++) {
        final fill = Path()
          ..moveTo(spAPts[i].dx, spAPts[i].dy)
          ..lineTo(spAPts[i+1].dx, spAPts[i+1].dy)
          ..lineTo(spBPts[i+1].dx, spBPts[i+1].dy)
          ..lineTo(spBPts[i].dx, spBPts[i].dy)
          ..close();
        canvas.drawPath(fill, Paint()
          ..color = (spAPts[i].dy < spBPts[i].dy ? spAC : spBC).withValues(alpha: 0.08));
      }
    }
    void drl(List<Offset> pts, Color color, {double w = 1.0}) {
      if (pts.isEmpty) { return; }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts) { path.lineTo(p.dx, p.dy); }
      canvas.drawPath(path, Paint()..color = color..strokeWidth = w..style = PaintingStyle.stroke);
    }
    drl(spAPts, spAC.withValues(alpha: 0.6));
    drl(spBPts, spBC.withValues(alpha: 0.6));
    drl(kijPts, kijC, w: 1.2);
    drl(tenPts, tenC, w: 1.0);
  }

  void _drawRsi(Canvas canvas, List<CandleData> all, List<CandleData> vc,
      int si, double chartW, double panY, double cw, double rp) {
    final cfg    = indConfigs[IndicatorType.rsi] ?? _kDefaultConfigs[IndicatorType.rsi]!;
    final period = cfg.params[0].toInt();
    final color  = cfg.colors.isNotEmpty ? cfg.colors[0] : const Color(0xFF7E57C2);
    if (all.length < period + 1) { return; }
    final rsi = _calcRsi(all, period);

    const labelH = 16.0;
    double ryF(double v) => panY + labelH + (_panelH - labelH - 4) * (1 - v / 100);
    final gp = Paint()..color = const Color(0xFF2A3040)..strokeWidth = 0.5;
    for (final lv in [30.0, 70.0]) {
      canvas.drawLine(Offset(0, ryF(lv)), Offset(chartW, ryF(lv)), gp);
    }
    final path = Path(); bool started = false;
    for (int i = 0; i < vc.length; i++) {
      final ai = si + i;
      if (ai >= rsi.length) { break; }
      final x = (rp + i + 0.5) * cw;
      final y = ryF(rsi[ai]);
      if (!started) { path.moveTo(x, y); started = true; } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.2..style = PaintingStyle.stroke);

    final lastIdx = si + vc.length - 1;
    final lv      = lastIdx < rsi.length ? rsi[lastIdx] : 50.0;
    final tp = TextPainter(text: TextSpan(children: [
      TextSpan(text: 'RSI($period)  ', style: const TextStyle(color: Color(0xFF5A6270), fontSize: 9)),
      TextSpan(text: lv.toStringAsFixed(1), style: TextStyle(color: color, fontSize: 9)),
    ]), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(4, panY + 3));
    for (final lv2 in [30.0, 70.0]) {
      final lvTp = TextPainter(text: TextSpan(text: lv2.toStringAsFixed(0),
          style: const TextStyle(color: Color(0xFF5A6270), fontSize: 8)),
          textDirection: TextDirection.ltr)..layout();
      lvTp.paint(canvas, Offset(chartW + 4, ryF(lv2) - lvTp.height / 2));
    }
  }

  void _drawMacd(Canvas canvas, List<CandleData> all, List<CandleData> vc,
      int si, double chartW, double panY, double cw, double rp) {
    final cfg    = indConfigs[IndicatorType.macd] ?? _kDefaultConfigs[IndicatorType.macd]!;
    final fast   = cfg.params[0].toInt();
    final slow   = cfg.params.length > 1 ? cfg.params[1].toInt() : 26;
    final sig    = cfg.params.length > 2 ? cfg.params[2].toInt() : 9;
    final macdC  = cfg.colors.isNotEmpty ? cfg.colors[0] : const Color(0xFF26C6DA);
    final sigC   = cfg.colors.length > 1 ? cfg.colors[1] : const Color(0xFFFF9800);
    if (all.length < slow + 1) { return; }
    final closes = all.map((c) => c.close).toList();
    final ema1   = _ema(closes, fast);
    final ema2   = _ema(closes, slow);
    final macd   = List.generate(all.length, (i) => ema1[i] - ema2[i]);
    final signal = _ema(macd, sig);
    final hist   = List.generate(all.length, (i) => macd[i] - signal[i]);

    double mn = double.infinity, mx = double.negativeInfinity;
    for (int i = 0; i < vc.length; i++) {
      final ai = si + i; if (ai >= macd.length) { break; }
      for (final v in [macd[ai], signal[ai], hist[ai]]) {
        if (v < mn) { mn = v; } if (v > mx) { mx = v; }
      }
    }
    if (mx == mn) { return; }
    const labelH = 16.0;
    double vyF(double v) => panY + labelH + (_panelH - labelH - 4) * (1 - (v - mn) / (mx - mn));
    final zero = vyF(0.0).clamp(panY + labelH, panY + _panelH - 4);
    canvas.drawLine(Offset(0, zero), Offset(chartW, zero),
        Paint()..color = Colors.white12..strokeWidth = 0.5);

    for (int i = 0; i < vc.length; i++) {
      final ai = si + i; if (ai >= hist.length) { break; }
      final x  = (rp + i + 0.5) * cw; final bw = math.max(cw * 0.6, 1.0);
      final hv = hist[ai]; final top = vyF(hv); final bot = zero;
      canvas.drawRect(Rect.fromLTWH(x - bw/2, math.min(top, bot), bw, (top-bot).abs()),
          Paint()..color = (hv >= 0 ? AppColors.green : AppColors.red).withValues(alpha: 0.5));
    }
    void drl(List<double> vals, Color col, double w) {
      final path = Path(); bool st = false;
      for (int i = 0; i < vc.length; i++) {
        final ai = si + i; if (ai >= vals.length) { break; }
        final x = (rp + i + 0.5) * cw; final y = vyF(vals[ai]);
        if (!st) { path.moveTo(x, y); st = true; } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path, Paint()..color = col..strokeWidth = w..style = PaintingStyle.stroke);
    }
    drl(macd, macdC, 1.2); drl(signal, sigC, 1.0);
    final li = si + vc.length - 1;
    final lm = li < macd.length ? macd[li] : 0.0;
    final ls = li < signal.length ? signal[li] : 0.0;
    final tp = TextPainter(text: TextSpan(children: [
      TextSpan(text: 'MACD ', style: const TextStyle(color: Color(0xFF5A6270), fontSize: 9)),
      TextSpan(text: lm.toStringAsFixed(1), style: TextStyle(color: macdC, fontSize: 9)),
      TextSpan(text: '  Sig ', style: const TextStyle(color: Color(0xFF5A6270), fontSize: 9)),
      TextSpan(text: ls.toStringAsFixed(1), style: TextStyle(color: sigC, fontSize: 9)),
    ]), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(4, panY + 3));
  }

  void _drawStochastic(Canvas canvas, List<CandleData> all, List<CandleData> vc,
      int si, double chartW, double panY, double cw, double rp) {
    final cfg  = indConfigs[IndicatorType.stochastic] ?? _kDefaultConfigs[IndicatorType.stochastic]!;
    final per  = cfg.params[0].toInt();
    final smo  = cfg.params.length > 1 ? cfg.params[1].toInt() : 3;
    final kCol = cfg.colors.isNotEmpty ? cfg.colors[0] : const Color(0xFF64B5F6);
    final dCol = cfg.colors.length > 1 ? cfg.colors[1] : const Color(0xFFFF9800);
    if (all.length < per) { return; }
    final k = List<double>.generate(all.length, (i) {
      final start = math.max(0, i - per + 1);
      double lo = all[start].low, hi = all[start].high;
      for (int j = start + 1; j <= i; j++) {
        if (all[j].low < lo) { lo = all[j].low; }
        if (all[j].high > hi) { hi = all[j].high; }
      }
      return (hi == lo) ? 50.0 : (all[i].close - lo) / (hi - lo) * 100;
    });
    final d = List<double>.generate(all.length,
        (i) => i < smo - 1 ? k[i] : k.sublist(i - smo + 1, i + 1).reduce((a, b) => a + b) / smo);

    const labelH = 16.0;
    double syF(double v) => panY + labelH + (_panelH - labelH - 4) * (1 - v / 100);
    final gp = Paint()..color = const Color(0xFF2A3040)..strokeWidth = 0.5;
    for (final lv in [20.0, 80.0]) {
      canvas.drawLine(Offset(0, syF(lv)), Offset(chartW, syF(lv)), gp);
    }
    void drl(List<double> vals, Color col, double w) {
      final path = Path(); bool st = false;
      for (int i = 0; i < vc.length; i++) {
        final ai = si + i; if (ai >= vals.length) { break; }
        final x = (rp + i + 0.5) * cw; final y = syF(vals[ai].clamp(0, 100));
        if (!st) { path.moveTo(x, y); st = true; } else { path.lineTo(x, y); }
      }
      canvas.drawPath(path, Paint()..color = col..strokeWidth = w..style = PaintingStyle.stroke);
    }
    drl(k, kCol, 1.2); drl(d, dCol, 1.0);
    final li = si + vc.length - 1;
    final lk = li < k.length ? k[li] : 50.0;
    final ld = li < d.length ? d[li] : 50.0;
    final tp = TextPainter(text: TextSpan(children: [
      TextSpan(text: 'Stoch  %K ', style: const TextStyle(color: Color(0xFF5A6270), fontSize: 9)),
      TextSpan(text: lk.toStringAsFixed(1), style: TextStyle(color: kCol, fontSize: 9)),
      TextSpan(text: '  %D ', style: const TextStyle(color: Color(0xFF5A6270), fontSize: 9)),
      TextSpan(text: ld.toStringAsFixed(1), style: TextStyle(color: dCol, fontSize: 9)),
    ]), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(4, panY + 3));
    for (final lv in [20.0, 80.0]) {
      final lvTp = TextPainter(text: TextSpan(text: lv.toStringAsFixed(0),
          style: const TextStyle(color: Color(0xFF5A6270), fontSize: 8)),
          textDirection: TextDirection.ltr)..layout();
      lvTp.paint(canvas, Offset(chartW + 4, syF(lv) - lvTp.height / 2));
    }
  }

  // ── Math helpers ──────────────────────────────────────────────────────────

  static List<double> _ema(List<double> v, int p) {
    final r = List<double>.filled(v.length, 0);
    if (v.length < p) { return r; }
    double s = 0;
    for (int i = 0; i < p; i++) { s += v[i]; }
    r[p - 1] = s / p;
    final k = 2.0 / (p + 1);
    for (int i = p; i < v.length; i++) { r[i] = v[i] * k + r[i-1] * (1 - k); }
    return r;
  }

  static List<double> _calcRsi(List<CandleData> all, int period) {
    final rsi = List<double>.filled(all.length, 50);
    if (all.length < period + 1) { return rsi; }
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
      rsi[i] = 100 - 100 / (1 + (al == 0 ? double.infinity : ag / al));
    }
    return rsi;
  }

  // ── Drawing helpers ───────────────────────────────────────────────────────

  void _drawLines(Canvas canvas, List<CandleData> vc, double chartW,
      double pH, double Function(double) pyFn, double cw, double rp) {
    double txToX(int t) => _txToX(t, vc, cw, rp);

    for (int idx = 0; idx < lines.length; idx++) {
      final ln  = lines[idx];
      final sel = idx == selIdx;
      final w   = sel ? ln.width + 1.0 : ln.width;
      final col = sel ? ln.color : ln.color.withValues(alpha: 0.85);
      void seg(Offset p1, Offset p2) {
        final p = Paint()..color = col..strokeWidth = w..style = PaintingStyle.stroke;
        switch (ln.style) {
          case LineStyle.solid:  canvas.drawLine(p1, p2, p);
          case LineStyle.dashed: _dashed(canvas, p1, p2, p, dash: 8, gap: 5);
          case LineStyle.dotted: _dotted(canvas, p1, p2, col, w);
        }
      }
      void lbl(String t, Color c, double x, double y) {
        final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: c, fontSize: 9)),
            textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x, y));
      }

      // ── 새 드로잉 툴 렌더링 ────────────────────────────────────────────────
      if (ln.drawType == DrawTool.brush && ln.pts.length >= 2) {
        final path = Path();
        for (int i = 0; i < ln.pts.length; i++) {
          final x = txToX(ln.pts[i].time), y = pyFn(ln.pts[i].price);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
        }
        canvas.drawPath(path, Paint()..color = col..strokeWidth = w * 1.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
        continue;
      }

      if (ln.drawType == DrawTool.crossLine) {
        final x = txToX(ln.startTime), y = pyFn(ln.startPrice);
        if (y >= -1 && y <= pH + 1) seg(Offset(0, y), Offset(chartW, y));
        seg(Offset(x, 0), Offset(x, pH));
        continue;
      }

      if (ln.drawType == DrawTool.text || ln.drawType == DrawTool.note ||
          ln.drawType == DrawTool.priceNote) {
        final txt = ln.text ?? '';
        if (txt.isEmpty) { continue; }
        final x = txToX(ln.startTime), y = pyFn(ln.startPrice);
        final display = ln.drawType == DrawTool.priceNote ? '${_fmt(ln.startPrice)}\n$txt' : txt;
        final tp = TextPainter(
          text: TextSpan(text: display, style: TextStyle(color: col, fontSize: 11)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 140);
        final tx = (x - tp.width / 2).clamp(2.0, chartW - tp.width - 4);
        final ty = (y - tp.height - 10).clamp(2.0, pH - tp.height - 2);
        if (ln.drawType != DrawTool.text) {
          final bg = RRect.fromRectAndRadius(
            Rect.fromLTWH(tx - 4, ty - 3, tp.width + 8, tp.height + 6),
            const Radius.circular(4));
          canvas.drawRRect(bg, Paint()..color = col.withValues(alpha: 0.12));
          canvas.drawRRect(bg, Paint()..color = col.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke..strokeWidth = 0.8);
          canvas.drawLine(Offset(x, y), Offset(tx + tp.width / 2, ty + tp.height + 3),
              Paint()..color = col.withValues(alpha: 0.5)..strokeWidth = 0.8);
          canvas.drawCircle(Offset(x, y), 2.5, Paint()..color = col);
        }
        tp.paint(canvas, Offset(tx, ty));
        continue;
      }

      if (ln.drawType == DrawTool.parallelChannel && ln.pts.length >= 3) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final x1 = txToX(ln.pts[1].time), y1 = pyFn(ln.pts[1].price);
        final dy  = pyFn(ln.pts[2].price) - y0;
        seg(Offset(x0, y0), Offset(x1, y1));
        seg(Offset(x0, y0 + dy), Offset(x1, y1 + dy));
        _dashed(canvas, Offset(x0, y0 + dy / 2), Offset(x1, y1 + dy / 2),
            Paint()..color = col.withValues(alpha: 0.3)..strokeWidth = w * 0.6
              ..style = PaintingStyle.stroke);
        continue;
      }

      if (ln.drawType == DrawTool.fibRetracement && ln.pts.length >= 2) {
        final p0 = ln.pts[0], p1 = ln.pts[1];
        seg(Offset(txToX(p0.time), pyFn(p0.price)), Offset(txToX(p1.time), pyFn(p1.price)));
        const lvs = [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0];
        const lbs = ['0', '0.236', '0.382', '0.5', '0.618', '0.786', '1.0'];
        for (int i = 0; i < lvs.length; i++) {
          final py = pyFn(p0.price + (p1.price - p0.price) * lvs[i]);
          if (py < -1 || py > pH + 1) continue;
          canvas.drawLine(Offset(0, py), Offset(chartW, py),
              Paint()..color = col.withValues(alpha: i == 0 || i == 6 ? 0.7 : 0.4)..strokeWidth = 0.8);
          lbl(lbs[i], col.withValues(alpha: 0.8), chartW - 36, py - 11);
        }
        continue;
      }

      if (ln.drawType == DrawTool.fibExtension && ln.pts.length >= 3) {
        final p0 = ln.pts[0], p1 = ln.pts[1], p2 = ln.pts[2];
        seg(Offset(txToX(p0.time), pyFn(p0.price)), Offset(txToX(p1.time), pyFn(p1.price)));
        seg(Offset(txToX(p1.time), pyFn(p1.price)), Offset(txToX(p2.time), pyFn(p2.price)));
        final swing = p1.price - p0.price;
        const lvs = [0.0, 0.618, 1.0, 1.618, 2.618];
        const lbs = ['0', '0.618', '1.0', '1.618', '2.618'];
        for (int i = 0; i < lvs.length; i++) {
          final py = pyFn(p2.price + swing * lvs[i]);
          if (py < -1 || py > pH + 1) continue;
          canvas.drawLine(Offset(0, py), Offset(chartW, py),
              Paint()..color = col.withValues(alpha: 0.45)..strokeWidth = 0.8);
          lbl(lbs[i], col.withValues(alpha: 0.8), chartW - 36, py - 11);
        }
        continue;
      }

      if (ln.drawType == DrawTool.fibTimeZone && ln.pts.length >= 2) {
        final t0 = ln.pts[0].time, t1 = ln.pts[1].time;
        final base = (t1 - t0).abs();
        if (base == 0) { continue; }
        canvas.drawLine(Offset(txToX(t0), 0), Offset(txToX(t0), pH),
            Paint()..color = col.withValues(alpha: 0.6)..strokeWidth = 0.8);
        const fibs = [1, 2, 3, 5, 8, 13, 21, 34];
        for (final f in fibs) {
          final xt = txToX(t0 + f * base);
          if (xt < -2 || xt > chartW + 2) continue;
          canvas.drawLine(Offset(xt, 0), Offset(xt, pH),
              Paint()..color = col.withValues(alpha: 0.4)..strokeWidth = 0.8);
          lbl('$f', col.withValues(alpha: 0.7), xt + 2, 2);
        }
        continue;
      }

      if ((ln.drawType == DrawTool.headAndShoulders || ln.drawType == DrawTool.xabcdPattern)
          && ln.pts.length >= 5) {
        final labels = ln.drawType == DrawTool.headAndShoulders
            ? ['LS', 'LN', 'H', 'RN', 'RS'] : ['X', 'A', 'B', 'C', 'D'];
        final offs = ln.pts.take(5).map((p) => Offset(txToX(p.time), pyFn(p.price))).toList();
        for (int i = 0; i < offs.length - 1; i++) seg(offs[i], offs[i + 1]);
        if (ln.drawType == DrawTool.headAndShoulders) {
          _dashed(canvas, offs[1], offs[3], Paint()..color = col.withValues(alpha: 0.5)
            ..strokeWidth = 0.8..style = PaintingStyle.stroke);
        }
        for (int i = 0; i < labels.length; i++) {
          canvas.drawCircle(offs[i], 3.5, Paint()..color = col.withValues(alpha: 0.3));
          final tp = TextPainter(
            text: TextSpan(text: labels[i], style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, offs[i] + Offset(-tp.width / 2, -15));
        }
        continue;
      }

      if (ln.drawType == DrawTool.elliottWave && ln.pts.length >= 6) {
        final offs = ln.pts.take(6).map((p) => Offset(txToX(p.time), pyFn(p.price))).toList();
        for (int i = 0; i < offs.length - 1; i++) seg(offs[i], offs[i + 1]);
        for (int i = 1; i < offs.length; i++) {
          canvas.drawCircle(offs[i], 8, Paint()..color = col.withValues(alpha: 0.18));
          canvas.drawCircle(offs[i], 8, Paint()..color = col.withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke..strokeWidth = 0.8);
          final tp = TextPainter(
            text: TextSpan(text: '$i', style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, offs[i] + Offset(-tp.width / 2, -tp.height / 2));
        }
        continue;
      }

      if ((ln.drawType == DrawTool.longPosition || ln.drawType == DrawTool.shortPosition)
          && ln.pts.length >= 2) {
        final isLong = ln.drawType == DrawTool.longPosition;
        final x0 = txToX(ln.pts[0].time), x1 = txToX(ln.pts[1].time);
        final yEntry  = pyFn(ln.pts[0].price), yTarget = pyFn(ln.pts[1].price);
        final zoneCol = isLong ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
        final rect = Rect.fromLTRB(
          math.min(x0, x1), math.min(yEntry, yTarget),
          math.max(x0, x1), math.max(yEntry, yTarget));
        canvas.drawRect(rect, Paint()..color = zoneCol.withValues(alpha: 0.12));
        canvas.drawLine(Offset(math.min(x0,x1), yEntry), Offset(math.max(x0,x1), yEntry),
            Paint()..color = Colors.white54..strokeWidth = 1.0);
        canvas.drawLine(Offset(math.min(x0,x1), yTarget), Offset(math.max(x0,x1), yTarget),
            Paint()..color = zoneCol..strokeWidth = 1.5);
        final lx = (math.max(x0, x1) + 4).clamp(0.0, chartW - 48.0);
        lbl('진입', Colors.white54, lx, yEntry - 11);
        lbl('목표가', zoneCol, lx, yTarget - 11);
        final pct = (ln.pts[1].price - ln.pts[0].price) / ln.pts[0].price * 100;
        final pctStr = (isLong ? '+' : '') + pct.toStringAsFixed(1) + '%';
        lbl(pctStr, zoneCol,
            (math.min(x0,x1) + math.max(x0,x1)) / 2 - 12,
            (yEntry + yTarget) / 2 - 6);
        continue;
      }

      // ── 트렌드 라인 확장 ──────────────────────────────────────────────────
      if (ln.drawType == DrawTool.horizontalLine && ln.pts.isNotEmpty) {
        final y = pyFn(ln.pts[0].price);
        if (y >= -1 && y <= pH + 1) seg(Offset(0, y), Offset(chartW, y));
        continue;
      }

      if (ln.drawType == DrawTool.verticalLine && ln.pts.isNotEmpty) {
        final x = txToX(ln.pts[0].time);
        seg(Offset(x, 0), Offset(x, pH));
        continue;
      }

      // ── 간과 피보나치 확장 ────────────────────────────────────────────────
      if (ln.drawType == DrawTool.fibFan && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final x1 = txToX(ln.pts[1].time), y1 = pyFn(ln.pts[1].price);
        const fibs = [0.236, 0.382, 0.5, 0.618, 1.0];
        const labs = ['0.236', '0.382', '0.5', '0.618', '1.0'];
        final dx = x1 - x0, dy = y1 - y0;
        seg(Offset(x0, y0), Offset(x1, y1));
        for (int i = 0; i < fibs.length; i++) {
          final yt = y0 + dy * fibs[i];
          final tRight = chartW / math.max(dx.abs(), 1);
          canvas.drawLine(Offset(x0, y0), Offset(x0 + dx * tRight, y0 + dy * fibs[i] * tRight),
              Paint()..color = col.withValues(alpha: 0.45)..strokeWidth = 0.8
                ..style = PaintingStyle.stroke);
          lbl(labs[i], col.withValues(alpha: 0.75), chartW - 36, y0 + dy * fibs[i] * tRight - 11);
        }
        continue;
      }

      if (ln.drawType == DrawTool.fibArc && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final x1 = txToX(ln.pts[1].time), y1 = pyFn(ln.pts[1].price);
        final r = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
        const fibs = [0.236, 0.382, 0.5, 0.618, 1.0];
        const labs = ['0.236', '0.382', '0.5', '0.618', '1.0'];
        canvas.drawCircle(Offset(x0, y0), 3, Paint()..color = col);
        for (int i = 0; i < fibs.length; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x0, y0), radius: r * fibs[i]),
            math.pi, math.pi, false,
            Paint()..color = col.withValues(alpha: 0.45)..strokeWidth = 0.8
              ..style = PaintingStyle.stroke,
          );
          lbl(labs[i], col.withValues(alpha: 0.75), x0 + r * fibs[i] - 10, y0 - 11);
        }
        continue;
      }

      if (ln.drawType == DrawTool.gannFan && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final dx = txToX(ln.pts[1].time) - x0;
        final dy = pyFn(ln.pts[1].price) - y0;
        final unit = dx.abs() < 0.5 ? 1.0 : dy / dx;
        final ratios = [8.0, 4.0, 3.0, 2.0, 1.0, 0.5, 0.333, 0.25, 0.125];
        final labs   = ['8:1','4:1','3:1','2:1','1:1','1:2','1:3','1:4','1:8'];
        final tRight = (chartW - x0) / math.max(dx.abs(), 1);
        for (int i = 0; i < ratios.length; i++) {
          final slope = unit * ratios[i];
          final xe = x0 + (chartW - x0); final ye = y0 + slope * tRight * dx.sign;
          canvas.drawLine(Offset(x0, y0), Offset(xe, ye),
              Paint()..color = col.withValues(alpha: i == 4 ? 0.8 : 0.35)..strokeWidth = i == 4 ? w : 0.8
                ..style = PaintingStyle.stroke);
          if (ye >= 0 && ye <= pH) lbl(labs[i], col.withValues(alpha: 0.65), xe - 28, ye - 11);
        }
        continue;
      }

      if (ln.drawType == DrawTool.gannSquare && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final x1 = txToX(ln.pts[1].time), y1 = pyFn(ln.pts[1].price);
        final cellW = (x1 - x0) / 4, cellH = (y1 - y0) / 4;
        final gridPaint = Paint()..color = col.withValues(alpha: 0.25)..strokeWidth = 0.6
          ..style = PaintingStyle.stroke;
        for (int i = 0; i <= 4; i++) {
          canvas.drawLine(Offset(x0 + cellW * i, y0), Offset(x0 + cellW * i, y1), gridPaint);
          canvas.drawLine(Offset(x0, y0 + cellH * i), Offset(x1, y0 + cellH * i), gridPaint);
        }
        canvas.drawRect(Rect.fromLTRB(x0, y0, x1, y1),
            Paint()..color = col.withValues(alpha: 0.08));
        canvas.drawLine(Offset(x0, y0), Offset(x1, y1),
            Paint()..color = col.withValues(alpha: 0.5)..strokeWidth = w..style = PaintingStyle.stroke);
        continue;
      }

      // ── 패턴 확장 ─────────────────────────────────────────────────────────
      if (ln.drawType == DrawTool.abcdPattern && ln.pts.length >= 4) {
        const labels = ['A', 'B', 'C', 'D'];
        final offs = ln.pts.take(4).map((p) => Offset(txToX(p.time), pyFn(p.price))).toList();
        for (int i = 0; i < offs.length - 1; i++) seg(offs[i], offs[i + 1]);
        for (int i = 0; i < labels.length; i++) {
          canvas.drawCircle(offs[i], 3.5, Paint()..color = col.withValues(alpha: 0.3));
          final tp = TextPainter(
            text: TextSpan(text: labels[i], style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, offs[i] + Offset(-tp.width / 2, -15));
        }
        continue;
      }

      if (ln.drawType == DrawTool.trianglePattern && ln.pts.length >= 3) {
        final offs = ln.pts.take(3).map((p) => Offset(txToX(p.time), pyFn(p.price))).toList();
        seg(offs[0], offs[1]); seg(offs[1], offs[2]); seg(offs[2], offs[0]);
        const labels = ['A', 'B', 'C'];
        for (int i = 0; i < labels.length; i++) {
          canvas.drawCircle(offs[i], 3.5, Paint()..color = col.withValues(alpha: 0.3));
          final tp = TextPainter(
            text: TextSpan(text: labels[i], style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, offs[i] + Offset(-tp.width / 2, -15));
        }
        continue;
      }

      // ── 예측 및 측정 확장 ─────────────────────────────────────────────────
      if (ln.drawType == DrawTool.priceRange && ln.pts.length >= 2) {
        final y0 = pyFn(ln.pts[0].price), y1 = pyFn(ln.pts[1].price);
        final top = math.min(y0, y1), bot = math.max(y0, y1);
        canvas.drawRect(Rect.fromLTRB(0, top, chartW, bot),
            Paint()..color = col.withValues(alpha: 0.1));
        canvas.drawLine(Offset(0, top), Offset(chartW, top),
            Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w..style = PaintingStyle.stroke);
        canvas.drawLine(Offset(0, bot), Offset(chartW, bot),
            Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w..style = PaintingStyle.stroke);
        final pct = ((ln.pts[1].price - ln.pts[0].price) / ln.pts[0].price * 100).toStringAsFixed(2);
        final diff = (ln.pts[1].price - ln.pts[0].price).toStringAsFixed(0);
        lbl('$diff  $pct%', col, chartW / 2 - 30, (top + bot) / 2 - 7);
        continue;
      }

      if (ln.drawType == DrawTool.dateRange && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), x1 = txToX(ln.pts[1].time);
        final left = math.min(x0, x1), right = math.max(x0, x1);
        canvas.drawRect(Rect.fromLTRB(left, 0, right, pH),
            Paint()..color = col.withValues(alpha: 0.1));
        canvas.drawLine(Offset(left, 0), Offset(left, pH),
            Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w..style = PaintingStyle.stroke);
        canvas.drawLine(Offset(right, 0), Offset(right, pH),
            Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w..style = PaintingStyle.stroke);
        continue;
      }

      if (ln.drawType == DrawTool.barsPattern && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final x1 = txToX(ln.pts[1].time), y1 = pyFn(ln.pts[1].price);
        seg(Offset(x0, y0), Offset(x1, y0));
        seg(Offset(x1, y0), Offset(x1, y1));
        seg(Offset(x1, y1), Offset(x0, y1));
        seg(Offset(x0, y1), Offset(x0, y0));
        final pct = ((ln.pts[1].price - ln.pts[0].price) / ln.pts[0].price * 100);
        final bars = ((ln.pts[1].time - ln.pts[0].time) / 86400).round().abs();
        lbl('$bars 바  ${pct.toStringAsFixed(2)}%',
            col, math.min(x0, x1) + 4, math.min(y0, y1) + 4);
        continue;
      }

      // ── 기하 도형 ─────────────────────────────────────────────────────────
      if (ln.drawType == DrawTool.rectangle && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final x1 = txToX(ln.pts[1].time), y1 = pyFn(ln.pts[1].price);
        final rect = Rect.fromLTRB(math.min(x0,x1), math.min(y0,y1), math.max(x0,x1), math.max(y0,y1));
        canvas.drawRect(rect, Paint()..color = col.withValues(alpha: 0.1));
        canvas.drawRect(rect, Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w
          ..style = PaintingStyle.stroke);
        continue;
      }

      if (ln.drawType == DrawTool.ellipse && ln.pts.length >= 2) {
        final x0 = txToX(ln.pts[0].time), y0 = pyFn(ln.pts[0].price);
        final x1 = txToX(ln.pts[1].time), y1 = pyFn(ln.pts[1].price);
        final rect = Rect.fromLTRB(math.min(x0,x1), math.min(y0,y1), math.max(x0,x1), math.max(y0,y1));
        canvas.drawOval(rect, Paint()..color = col.withValues(alpha: 0.1));
        canvas.drawOval(rect, Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w
          ..style = PaintingStyle.stroke);
        continue;
      }

      if (ln.drawType == DrawTool.triangle && ln.pts.length >= 3) {
        final offs = ln.pts.take(3).map((p) => Offset(txToX(p.time), pyFn(p.price))).toList();
        final path = Path()..moveTo(offs[0].dx, offs[0].dy)
          ..lineTo(offs[1].dx, offs[1].dy)..lineTo(offs[2].dx, offs[2].dy)..close();
        canvas.drawPath(path, Paint()..color = col.withValues(alpha: 0.1));
        canvas.drawPath(path, Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w
          ..style = PaintingStyle.stroke);
        continue;
      }

      if (ln.drawType == DrawTool.arc && ln.pts.length >= 3) {
        final offs = ln.pts.take(3).map((p) => Offset(txToX(p.time), pyFn(p.price))).toList();
        final path = Path()..moveTo(offs[0].dx, offs[0].dy);
        path.quadraticBezierTo(offs[1].dx, offs[1].dy, offs[2].dx, offs[2].dy);
        canvas.drawPath(path, Paint()..color = col.withValues(alpha: 0.7)..strokeWidth = w
          ..style = PaintingStyle.stroke);
        canvas.drawCircle(offs[1], 3, Paint()..color = col.withValues(alpha: 0.5));
        continue;
      }

      // ── 주석 확장 ─────────────────────────────────────────────────────────
      if ((ln.drawType == DrawTool.arrowUp || ln.drawType == DrawTool.arrowDown)
          && ln.pts.isNotEmpty) {
        final x = txToX(ln.pts[0].time), y = pyFn(ln.pts[0].price);
        final isUp = ln.drawType == DrawTool.arrowUp;
        final path = Path();
        const hw = 7.0; const ah = 12.0; const sh = 6.0;
        if (isUp) {
          path.moveTo(x, y - ah);
          path.lineTo(x - hw, y); path.lineTo(x - hw / 2, y);
          path.lineTo(x - hw / 2, y + sh); path.lineTo(x + hw / 2, y + sh);
          path.lineTo(x + hw / 2, y); path.lineTo(x + hw, y);
        } else {
          path.moveTo(x, y + ah);
          path.lineTo(x - hw, y); path.lineTo(x - hw / 2, y);
          path.lineTo(x - hw / 2, y - sh); path.lineTo(x + hw / 2, y - sh);
          path.lineTo(x + hw / 2, y); path.lineTo(x + hw, y);
        }
        path.close();
        canvas.drawPath(path, Paint()..color = col.withValues(alpha: 0.8));
        continue;
      }

      if (ln.drawType == DrawTool.callout && ln.pts.isNotEmpty) {
        final txt = ln.text ?? '';
        if (txt.isEmpty) { continue; }
        final x = txToX(ln.pts[0].time), y = pyFn(ln.pts[0].price);
        final tp = TextPainter(
          text: TextSpan(text: txt, style: TextStyle(color: col, fontSize: 11)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 120);
        const pad = 6.0; const tailH = 8.0;
        final bx = (x - tp.width / 2 - pad).clamp(2.0, chartW - tp.width - pad * 2 - 2);
        final by = y - tp.height - pad * 2 - tailH - 12;
        final bubbleRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, tp.width + pad * 2, tp.height + pad * 2),
          const Radius.circular(6));
        canvas.drawRRect(bubbleRect, Paint()..color = col.withValues(alpha: 0.15));
        canvas.drawRRect(bubbleRect, Paint()..color = col.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke..strokeWidth = 1.0);
        // 꼬리
        final tailPath = Path()
          ..moveTo(x - 5, by + tp.height + pad * 2)
          ..lineTo(x + 5, by + tp.height + pad * 2)
          ..lineTo(x, y - 10)..close();
        canvas.drawPath(tailPath, Paint()..color = col.withValues(alpha: 0.4));
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = col);
        tp.paint(canvas, Offset(bx + pad, by + pad));
        continue;
      }

      // ── 기존: trendLine + isHorizontal ────────────────────────────────────
      if (ln.isHorizontal) {
        final y = pyFn(ln.startPrice);
        if (y >= -1 && y <= pH + 1) { seg(Offset(0, y), Offset(chartW, y)); }
        continue;
      }
      final x1 = txToX(ln.startTime); final y1 = pyFn(ln.startPrice);
      final x2 = txToX(ln.endTime);   final y2 = pyFn(ln.endPrice);
      seg(Offset(x1, y1), Offset(x2, y2));
      if (sel) {
        for (final pt in [Offset(x1, y1), Offset(x2, y2)]) {
          canvas.drawCircle(pt, 5, Paint()..color = ln.color.withValues(alpha: 0.25));
          canvas.drawCircle(pt, 5,
              Paint()..color = ln.color..strokeWidth = 1..style = PaintingStyle.stroke);
        }
      }
      if (ln.role != LineRole.none) {
        final labelX = x2.clamp(4.0, chartW - 52.0);
        final labelY = (y2 - 18).clamp(2.0, pH - 16.0);
        final roleColor = ln.role.roleColor;
        final tp = TextPainter(
          text: TextSpan(
            text: ln.role.label,
            style: TextStyle(color: roleColor, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bgRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(labelX - 3, labelY - 2, tp.width + 6, tp.height + 4),
          const Radius.circular(3),
        );
        canvas.drawRRect(bgRect, Paint()..color = roleColor.withValues(alpha: 0.18));
        canvas.drawRRect(bgRect, Paint()..color = roleColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke..strokeWidth = 0.8);
        tp.paint(canvas, Offset(labelX, labelY));
      }
    }
  }

  void _drawAnchor(Canvas canvas, Offset pos, Color color) {
    canvas.drawCircle(pos, 7, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawCircle(pos, 7,
        Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);
    canvas.drawCircle(pos, 2.5, Paint()..color = color);
  }

  void _dotted(Canvas canvas, Offset p1, Offset p2, Color color, double w) {
    final d = p2 - p1; final len = d.distance;
    if (len == 0) { return; }
    final u = d / len; final gap = w * 3; double pos = 0;
    while (pos < len) { canvas.drawCircle(p1 + u * pos, w / 2, Paint()..color = color); pos += gap; }
  }

  void _dashed(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dash=4, double gap=4}) {
    final d = p2 - p1; final len = d.distance;
    if (len == 0) { return; }
    final u = d / len; double pos = 0; bool draw = true;
    while (pos < len) {
      final seg = math.min(pos + (draw ? dash : gap), len);
      if (draw) { canvas.drawLine(p1 + u * pos, p1 + u * seg, paint); }
      pos = seg; draw = !draw;
    }
  }

  void _axisLabel(Canvas canvas, double x, double y, String text,
      {required bool center, Color color = Colors.white}) {
    final tp = TextPainter(text: TextSpan(text: text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr)..layout();
    final lx = center ? x - tp.width / 2 : x;
    final ly = center ? y : y - tp.height / 2;
    canvas.drawRect(Rect.fromLTWH(lx - 2, ly - 1, tp.width + 4, tp.height + 2),
        Paint()..color = const Color(0xFF252A34));
    tp.paint(canvas, Offset(lx, ly));
  }

  String _fmt(double p) {
    final String n;
    if (p >= 1e6) {
      n = '${(p/1e6).toStringAsFixed(2)}M';
    } else if (p >= 1000) {
      n = p.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    } else if (p < 1) {
      n = p.toStringAsFixed(4);
    } else {
      n = p.toStringAsFixed(2);
    }
    return '$prefix$n';
  }

  /// 가격 축 레이블 — 콤마 구분 정수 (줌 레벨에 따라 자릿수 자동 조정)
  String _fmtAxis(double p) {
    if (p < 0) return '$prefix${_fmtAxisAbs(-p)}';
    return '$prefix${_fmtAxisAbs(p)}';
  }

  static String _fmtAxisAbs(double p) {
    if (p < 0.001) return p.toStringAsFixed(6);
    if (p < 1)     return p.toStringAsFixed(4);
    if (p < 10)    return p.toStringAsFixed(p % 1 == 0 ? 0 : 2);
    // 10 이상: 정수로 반올림 후 콤마 표기
    final ip = p.round();
    return ip.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  /// lo~hi 사이의 깔끔한 눈금 목록
  static List<double> _niceTicks(double lo, double hi, int target) {
    final range = hi - lo;
    if (range <= 0) return [];
    final rawStep = range / target;
    final mag = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
    final norm = rawStep / mag;
    final step = norm < 1.5 ? mag
               : norm < 3.5 ? mag * 2
               : norm < 7.5 ? mag * 5
               : mag * 10;
    final start = (lo / step).ceil() * step;
    final ticks = <double>[];
    var t = start;
    while (t <= hi + step * 0.01) {
      ticks.add(t);
      t += step;
    }
    return ticks;
  }

  static String _fmtVol(double v) {
    if (v >= 1e8) { return '${(v/1e8).toStringAsFixed(1)}억'; }
    if (v >= 1e4) { return '${(v/1e4).toStringAsFixed(0)}만'; }
    return v.toStringAsFixed(0);
  }

  static double _txToX(int t, List<CandleData> vc, double cw, double rp) {
    if (vc.isEmpty) return 0;
    final avg = vc.length >= 2 ? (vc.last.time - vc.first.time) / (vc.length - 1) : 86400.0;
    if (t <= vc.first.time) return (rp + 0.5 - (vc.first.time - t) / avg) * cw;
    if (t >= vc.last.time)  return (rp + vc.length - 0.5 + (t - vc.last.time) / avg) * cw;
    for (int i = 0; i < vc.length - 1; i++) {
      if (t < vc[i + 1].time) {
        return (rp + i + (t - vc[i].time) / (vc[i + 1].time - vc[i].time) + 0.5) * cw;
      }
    }
    return (rp + vc.length - 0.5) * cw;
  }

  @override
  bool shouldRepaint(_Painter o) =>
      candles != o.candles || vis != o.vis || scroll != o.scroll ||
      pzoom != o.pzoom || cross != o.cross || prefix != o.prefix ||
      activeIndicators != o.activeIndicators || indConfigs != o.indConfigs ||
      lines != o.lines || selIdx != o.selIdx ||
      phase != o.phase || cursor != o.cursor ||
      fpTime != o.fpTime || fpPrice != o.fpPrice ||
      currentTool != o.currentTool || pendingPts != o.pendingPts ||
      brushPending != o.brushPending;
}

// ─── Drawing Tool Picker ──────────────────────────────────────────────────────

enum _DrawCategory {
  trendLine, fibonacci, pattern, forecast, geometric, annotation;
  String get label {
    switch (this) {
      case _DrawCategory.trendLine:  return '트렌드 라인';
      case _DrawCategory.fibonacci:  return '간과 피보나치';
      case _DrawCategory.pattern:    return '패턴';
      case _DrawCategory.forecast:   return '예측 및 측정';
      case _DrawCategory.geometric:  return '기하 도형';
      case _DrawCategory.annotation: return '주석';
    }
  }
}

class _DrawToolMeta {
  final DrawTool tool;
  final String name;
  final IconData icon;
  final _DrawCategory category;
  const _DrawToolMeta(this.tool, this.name, this.icon, this.category);
}

const _kDrawToolMetas = <_DrawToolMeta>[
  // ── 트렌드 라인 ────────────────────────────────────────────────────────────
  _DrawToolMeta(DrawTool.trendLine,        '추세선',          Icons.show_chart,              _DrawCategory.trendLine),
  _DrawToolMeta(DrawTool.crossLine,        '크로스 라인',     Icons.add,                     _DrawCategory.trendLine),
  _DrawToolMeta(DrawTool.parallelChannel,  '패러렐 채널',     Icons.horizontal_rule,         _DrawCategory.trendLine),
  _DrawToolMeta(DrawTool.horizontalLine,   '수평선',          Icons.drag_handle,             _DrawCategory.trendLine),
  _DrawToolMeta(DrawTool.verticalLine,     '수직선',          Icons.vertical_distribute,     _DrawCategory.trendLine),
  // ── 간과 피보나치 ──────────────────────────────────────────────────────────
  _DrawToolMeta(DrawTool.fibRetracement,   '피보나치\n되돌림', Icons.stacked_line_chart,      _DrawCategory.fibonacci),
  _DrawToolMeta(DrawTool.fibExtension,     '피보나치\n확장',   Icons.trending_up,             _DrawCategory.fibonacci),
  _DrawToolMeta(DrawTool.fibTimeZone,      '피보나치\n타임존', Icons.view_week,               _DrawCategory.fibonacci),
  _DrawToolMeta(DrawTool.fibFan,           '피보나치\n팬',     Icons.album,                   _DrawCategory.fibonacci),
  _DrawToolMeta(DrawTool.fibArc,           '피보나치\n아크',   Icons.pie_chart_outline,       _DrawCategory.fibonacci),
  _DrawToolMeta(DrawTool.gannFan,          '간 팬',           Icons.grain,                   _DrawCategory.fibonacci),
  _DrawToolMeta(DrawTool.gannSquare,       '간 스퀘어',        Icons.grid_on,                 _DrawCategory.fibonacci),
  // ── 패턴 ───────────────────────────────────────────────────────────────────
  _DrawToolMeta(DrawTool.headAndShoulders, '헤드 앤\n숄더',   Icons.hdr_strong,              _DrawCategory.pattern),
  _DrawToolMeta(DrawTool.elliottWave,      '엘리엇\n임펄스',  Icons.ssid_chart,              _DrawCategory.pattern),
  _DrawToolMeta(DrawTool.xabcdPattern,     'XABCD\n패턴',    Icons.scatter_plot,            _DrawCategory.pattern),
  _DrawToolMeta(DrawTool.abcdPattern,      'ABCD\n패턴',     Icons.account_tree,            _DrawCategory.pattern),
  _DrawToolMeta(DrawTool.trianglePattern,  '삼각형\n패턴',    Icons.change_history,          _DrawCategory.pattern),
  // ── 예측 및 측정 ───────────────────────────────────────────────────────────
  _DrawToolMeta(DrawTool.longPosition,     '롱 포지션',       Icons.arrow_upward,            _DrawCategory.forecast),
  _DrawToolMeta(DrawTool.shortPosition,    '숏 포지션',       Icons.arrow_downward,          _DrawCategory.forecast),
  _DrawToolMeta(DrawTool.priceRange,       '가격 범위',       Icons.height,                  _DrawCategory.forecast),
  _DrawToolMeta(DrawTool.dateRange,        '날짜 범위',       Icons.date_range,              _DrawCategory.forecast),
  _DrawToolMeta(DrawTool.barsPattern,      '바 측정',         Icons.straighten,              _DrawCategory.forecast),
  // ── 기하 도형 ──────────────────────────────────────────────────────────────
  _DrawToolMeta(DrawTool.rectangle,        '사각형',          Icons.rectangle_outlined,      _DrawCategory.geometric),
  _DrawToolMeta(DrawTool.ellipse,          '타원',            Icons.circle_outlined,         _DrawCategory.geometric),
  _DrawToolMeta(DrawTool.triangle,         '삼각형',          Icons.change_history_outlined, _DrawCategory.geometric),
  _DrawToolMeta(DrawTool.arc,              '아크',            Icons.roundabout_left,         _DrawCategory.geometric),
  _DrawToolMeta(DrawTool.brush,            '붓',              Icons.brush,                   _DrawCategory.geometric),
  // ── 주석 ───────────────────────────────────────────────────────────────────
  _DrawToolMeta(DrawTool.text,             '텍스트',          Icons.text_fields,             _DrawCategory.annotation),
  _DrawToolMeta(DrawTool.note,             '노트',            Icons.sticky_note_2,           _DrawCategory.annotation),
  _DrawToolMeta(DrawTool.priceNote,        '프라이스\n노트',  Icons.price_check,             _DrawCategory.annotation),
  _DrawToolMeta(DrawTool.arrowUp,          '위 화살표',       Icons.north,                   _DrawCategory.annotation),
  _DrawToolMeta(DrawTool.arrowDown,        '아래 화살표',     Icons.south,                   _DrawCategory.annotation),
  _DrawToolMeta(DrawTool.callout,          '말풍선',          Icons.chat_bubble_outline,     _DrawCategory.annotation),
];

class _DrawingPickerSheet extends StatefulWidget {
  final DrawTool activeTool;
  final void Function(DrawTool) onToolSelected;
  const _DrawingPickerSheet({required this.activeTool, required this.onToolSelected});
  @override
  State<_DrawingPickerSheet> createState() => _DrawingPickerSheetState();
}

class _DrawingPickerSheetState extends State<_DrawingPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  static const _cats = _DrawCategory.values;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _cats.length, vsync: this);
    // 현재 활성 툴의 카테고리 탭으로 자동 이동
    final catIdx = _cats.indexWhere((c) =>
        _kDrawToolMetas.any((m) => m.tool == widget.activeTool && m.category == c));
    if (catIdx >= 0) _tabCtrl.index = catIdx;
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62, minChildSize: 0.4, maxChildSize: 0.88,
      expand: false,
      builder: (context, _) => Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(alignment: Alignment.centerLeft,
              child: Text('그리기 도구', style: TextStyle(
                  color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
        ),
        TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppColors.green,
          unselectedLabelColor: Colors.white54,
          indicatorColor: AppColors.green,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          tabs: _cats.map((c) => Tab(text: c.label)).toList(),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: _cats.map((cat) {
              final tools = _kDrawToolMetas.where((m) => m.category == cat).toList();
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 10,
                  mainAxisSpacing: 10, childAspectRatio: 1.0,
                ),
                itemCount: tools.length,
                itemBuilder: (_, i) {
                  final meta   = tools[i];
                  final active = meta.tool == widget.activeTool;
                  return GestureDetector(
                    onTap: () => widget.onToolSelected(meta.tool),
                    child: Container(
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.green.withValues(alpha: 0.12)
                            : const Color(0xFF252A34),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? AppColors.green.withValues(alpha: 0.55)
                              : Colors.white12,
                        ),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(meta.icon,
                            color: active ? AppColors.green : Colors.white70, size: 26),
                        const SizedBox(height: 6),
                        Text(meta.name, textAlign: TextAlign.center, style: TextStyle(
                          color: active ? AppColors.green : Colors.white70,
                          fontSize: 10, fontWeight: FontWeight.w500,
                        )),
                      ]),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}
