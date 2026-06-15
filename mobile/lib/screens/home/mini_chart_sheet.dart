import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/chart_provider.dart';
import '../../services/market_data_service.dart';

class MiniChartSheet extends StatefulWidget {
  final String ticker;
  final String name;
  final String price;
  final String change;
  final String pct;
  final bool isUp;
  final VoidCallback onGoToChart;

  const MiniChartSheet({
    super.key,
    required this.ticker,
    required this.name,
    required this.price,
    required this.change,
    required this.pct,
    required this.isUp,
    required this.onGoToChart,
  });

  @override
  State<MiniChartSheet> createState() => _MiniChartSheetState();
}

class _MiniChartSheetState extends State<MiniChartSheet> {
  List<double> _data = [];
  bool _loading = true;
  String _range = '1년';

  static const _ranges = ['일봉', '주봉', '월봉', '1년', '5년', '모두'];

  @override
  void initState() {
    super.initState();
    _loadChart();
  }

  Future<void> _loadChart() async {
    setState(() => _loading = true);
    final data = await MarketDataService.fetchOhlcvRange(widget.ticker, _range);
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  static const _avatarColors = [
    Color(0xFF1565C0), Color(0xFFE65100), Color(0xFFC62828),
    Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFF00695C),
    Color(0xFF37474F), Color(0xFF558B2F),
  ];

  @override
  Widget build(BuildContext context) {
    final color = widget.isUp ? AppColors.green : AppColors.red;
    final avatarColor = _avatarColors[widget.ticker.hashCode.abs() % _avatarColors.length];
    final label = widget.ticker.length > 4 ? widget.ticker.substring(0, 4) : widget.ticker;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13161E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: AppColors.gray.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
                  child: Center(
                    child: Text(label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(widget.ticker,
                          style: const TextStyle(color: AppColors.gray, fontSize: 12)),
                    ],
                  ),
                ),
                // Go to full chart
                GestureDetector(
                  onTap: () {
                    context.read<ChartProvider>().setTicker(widget.ticker);
                    Navigator.pop(context);
                    widget.onGoToChart();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.open_in_full, color: AppColors.gray, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Price
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(widget.price,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Text('${widget.change}  ${widget.pct}',
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Chart area
          SizedBox(
            height: 140,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2))
                : _data.isEmpty
                    ? const Center(child: Text('차트 데이터 없음', style: TextStyle(color: AppColors.gray)))
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: CustomPaint(
                          painter: _AreaChartPainter(data: _data, isUp: widget.isUp),
                          child: Container(),
                        ),
                      ),
          ),

          // Range selector
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _ranges.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final r = _ranges[i];
                final sel = _range == r;
                return GestureDetector(
                  onTap: () {
                    setState(() => _range = r);
                    _loadChart();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.card : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(r,
                        style: TextStyle(
                            color: sel ? Colors.white : AppColors.gray,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Area chart painter ────────────────────────────────────────────────────────

class _AreaChartPainter extends CustomPainter {
  final List<double> data;
  final bool isUp;
  const _AreaChartPainter({required this.data, required this.isUp});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minV = data.reduce(math.min);
    final maxV = data.reduce(math.max);
    final range = (maxV - minV).clamp(1.0, double.infinity);
    final padV = range * 0.1;

    final color = isUp ? AppColors.green : AppColors.red;

    Offset toOffset(int i) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - ((data[i] - minV + padV) / (range + padV * 2)) * size.height * 0.85 - 8;
      return Offset(x, y);
    }

    final points = List.generate(data.length, toOffset);

    // Area fill
    final areaPath = Path()..moveTo(0, size.height);
    for (final p in points) areaPath.lineTo(p.dx, p.dy);
    areaPath.lineTo(size.width, size.height);
    areaPath.close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Last price dot
    canvas.drawCircle(points.last, 4, Paint()..color = color);
    canvas.drawCircle(points.last, 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Y-axis labels (min / max)
    final textStyle = const TextStyle(color: AppColors.gray, fontSize: 10);
    _drawText(canvas, _fmtPrice(minV), Offset(4, size.height - 14), textStyle);
    _drawText(canvas, _fmtPrice(maxV), const Offset(4, 4), textStyle);
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  String _fmtPrice(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) => old.data != data;
}
