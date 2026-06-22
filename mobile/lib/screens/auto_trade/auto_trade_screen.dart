import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/app_colors.dart';
import '../../core/constants.dart';
import '../../models/chart_line_info.dart';
import '../../models/price_alert_model.dart';
import '../../models/scheduler_job.dart';
import '../../providers/job_provider.dart';
import '../../providers/alert_provider.dart';
import '../../providers/chart_provider.dart';
import '../../services/market_data_service.dart';
import '../../main.dart';
import '../home/mini_chart_sheet.dart';
import 'expert_strategy_tab.dart';

// ─── Main Screen ──────────────────────────────────────────────────────────────

class AutoTradeScreen extends StatefulWidget {
  const AutoTradeScreen({super.key});
  @override
  State<AutoTradeScreen> createState() => _AutoTradeScreenState();
}

class _AutoTradeScreenState extends State<AutoTradeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // 공유 종목 상태 (양쪽 탭이 동일 종목 사용)
  SymbolInfo? _selectedSymbol;
  String? _currentPrice;
  bool _isUp = false;
  final _searchCtrl = TextEditingController();
  List<SymbolInfo> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJobs();
      context.read<AlertProvider>().fetchAlerts();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await SymbolDatabase.searchAsync(q, '주식');
      if (mounted) setState(() => _suggestions = results.take(6).toList());
    });
  }

  void _selectSymbol(SymbolInfo s) {
    _searchCtrl.clear();
    setState(() {
      _selectedSymbol = s;
      _suggestions = [];
      _currentPrice = null;
    });
    FocusScope.of(context).unfocus();
    _fetchPrice(s.ticker);
  }

  void _openMiniChart() {
    final sym = _selectedSymbol;
    if (sym == null) return;
    final parts = _currentPrice?.split('  ') ?? [];
    final priceStr = parts.isNotEmpty ? parts[0] : '';
    final pctStr   = parts.length > 1 ? parts[1] : '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChartProvider>(),
        child: MiniChartSheet(
          ticker: sym.ticker,
          name: sym.name,
          price: priceStr,
          pct: pctStr,
          isUp: _isUp,
          onGoToChart: () {
            context.read<ChartProvider>().setTicker(sym.ticker);
            MainScaffold.goToChart();
          },
        ),
      ),
    );
  }

  Future<void> _fetchPrice(String ticker) async {
    try {
      final res = await http
          .get(Uri.parse('$kBaseUrl/api/v1/market/price/$ticker'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final o = jsonDecode(res.body) as Map<String, dynamic>;
        final price  = (o['current_price'] as num?)?.toDouble() ?? 0;
        final change = (o['change'] as num?)?.toDouble() ?? 0;
        final rate   = (o['change_rate'] as num?)?.toDouble() ?? 0;
        final up     = change > 0;
        if (mounted) {
          setState(() {
            _isUp = up;
            _currentPrice =
                '${_fmtNum(price)}  ${up ? '+' : ''}${rate.toStringAsFixed(2)}%';
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_tab.index < 2) ...[
                _buildSearchBar(),
                if (_suggestions.isNotEmpty) _buildSuggestions(),
                if (_selectedSymbol != null && _suggestions.isEmpty)
                  _buildSymbolChip(),
              ],
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ConditionTradeTab(selected: _selectedSymbol),
                    _ConditionalTab(
                      selected: _selectedSymbol,
                      currentPrice: _currentPrice,
                    ),
                    const ExpertStrategyTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('자동매매',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                  if (_suggestions.isNotEmpty) _selectSymbol(_suggestions.first);
                },
              ),
            ),
            if (_suggestions.isNotEmpty || _searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _suggestions = []);
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
                const Divider(
                    height: 1,
                    color: Color(0xFF252A34),
                    indent: 16,
                    endIndent: 16),
              InkWell(
                onTap: () => _selectSymbol(s),
                borderRadius: radius,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(s.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ),
                      Text(s.ticker,
                          style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
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

  Widget _buildSymbolChip() {
    final sym = _selectedSymbol!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openMiniChart,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.green.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(sym.ticker,
                    style: const TextStyle(
                        color: AppColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Text(sym.name,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                if (_currentPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(_currentPrice!,
                      style: const TextStyle(
                          color: AppColors.green, fontSize: 11)),
                ],
                const SizedBox(width: 8),
                const Icon(Icons.candlestick_chart_outlined,
                    color: AppColors.green, size: 14),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _selectedSymbol = null;
              _currentPrice = null;
            }),
            child: const Icon(Icons.close, color: AppColors.gray, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.bg,
          unselectedLabelColor: AppColors.gray,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '조건 매매'),
            Tab(text: '지정가 매매'),
            Tab(text: '전문가 전략'),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 0: 조건 매매 ────────────────────────────────────────────────────────

class _ConditionTradeTab extends StatefulWidget {
  final SymbolInfo? selected;
  const _ConditionTradeTab({this.selected});
  @override
  State<_ConditionTradeTab> createState() => _ConditionTradeTabState();
}

class _ConditionTradeTabState extends State<_ConditionTradeTab> {
  // ── 매매선 트리거 ──
  int  _lineBuyQty    = 10;
  int  _lineSellQty   = 10;
  bool _submittingBuy  = false;
  bool _submittingSell = false;

  // ── 지표 조건 ──
  String _indicator    = 'rsi';
  String _timeframe    = 'D';
  int    _indQty       = 10;
  int    _intervalSec  = 60;
  int    _rsiBuyThr    = 30;
  int    _rsiSellThr   = 70;
  bool   _submittingInd = false;

  static const _indicators = [
    _IndMeta(id: 'rsi',            name: 'RSI',       badge: 'RSI(14)',   icon: Icons.show_chart,      color: AppColors.green,        buyDesc: 'RSI 과매도 기준 이하 매수',   sellDesc: 'RSI 과매수 기준 이상 매도'),
    _IndMeta(id: 'moving_average', name: '골든크로스', badge: 'MA 5/20',  icon: Icons.trending_up,     color: Color(0xFFF2B41E),      buyDesc: '단기MA가 장기MA 상향 돌파 시 매수', sellDesc: '단기MA가 장기MA 하향 돌파 시 매도'),
    _IndMeta(id: 'scalping',       name: '볼린저밴드', badge: 'BB(20,2)', icon: Icons.speed,            color: Color(0xFF6C63FF),      buyDesc: '볼린저 하단(−2σ) 이탈 시 매수', sellDesc: '볼린저 상단(+2σ) 도달 시 매도'),
    _IndMeta(id: 'ichimoku',       name: '이치모쿠',   badge: 'Ichimoku', icon: Icons.layers_outlined,  color: Color(0xFF00BCD4),      buyDesc: '구름대 하단 지지선 근접 시 매수', sellDesc: '구름대 상단 저항선 도달 시 매도'),
  ];

  static const _timeframes = [
    (label: '일봉', value: 'D'),
    (label: '주봉', value: 'W'),
    (label: '월봉', value: 'M'),
    (label: '1년봉', value: 'Y'),
  ];

  static const _intervals = [
    (label: '30초', sec: 30),
    (label: '1분',  sec: 60),
    (label: '5분',  sec: 300),
    (label: '15분', sec: 900),
    (label: '1시간', sec: 3600),
  ];

  static const _rsiBuyOptions  = [20, 25, 30, 35];
  static const _rsiSellOptions = [65, 70, 75, 80];

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.green : AppColors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _linePriceLabel(ChartLineInfo l) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final p = l.priceAt(now);
    return l.isHorizontal ? '${_fmtNum(p)}원' : '약 ${_fmtNum(p)}원';
  }

  Future<void> _submitLineCondition(bool isBuy, List<ChartLineInfo> lines) async {
    final s = widget.selected;
    if (s == null) return;
    if (isBuy) { setState(() => _submittingBuy = true); }
    else { setState(() => _submittingSell = true); }
    try {
      final qty = isBuy ? _lineBuyQty : _lineSellQty;
      for (final l in lines) {
        await context.read<AlertProvider>().addAlert(
          ticker: s.ticker,
          side: isBuy ? 'buy' : 'sell',
          quantity: qty,
          lineStartTime:  l.startTime,
          lineStartPrice: l.startPrice,
          lineEndTime:    l.endTime,
          lineEndPrice:   l.endPrice,
        );
      }
      if (mounted) _snack('${isBuy ? '매수' : '매도'} 조건이 등록됐습니다', success: true);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) {
        if (isBuy) { setState(() => _submittingBuy = false); }
        else { setState(() => _submittingSell = false); }
      }
    }
  }

  Future<void> _submitIndicator() async {
    final s = widget.selected;
    if (s == null) { _snack('종목을 선택하세요'); return; }
    setState(() => _submittingInd = true);
    try {
      await context.read<JobProvider>().addJob(
        ticker: s.ticker,
        strategyName: _indicator,
        quantity: _indQty,
        intervalSeconds: _intervalSec,
        dataInterval: _timeframe,
      );
      if (mounted) _snack('지표 조건이 등록됐습니다', success: true);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submittingInd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = widget.selected;
    final allLines = sym != null
        ? context.watch<ChartProvider>().getLinesForTicker(sym.ticker)
        : <ChartLineInfo>[];
    final buyLines  = allLines.where((l) => l.role == LineRole.buyTrigger).toList();
    final sellLines = allLines.where((l) => l.role == LineRole.sellTrigger).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── 매매선 트리거 ──────────────────────────
        _buildSectionHeader(Icons.timeline, '매매선 트리거', '차트 추세선 기반 예약 주문'),
        const SizedBox(height: 12),
        if (sym == null)
          _buildNoSymbolHint()
        else if (buyLines.isEmpty && sellLines.isEmpty)
          _buildNoLineHint()
        else ...[
          if (buyLines.isNotEmpty) ...[
            _buildLineTriggerCard(
              lines: buyLines, isBuy: true,
              qty: _lineBuyQty,
              onQtyChanged: (v) => setState(() => _lineBuyQty = v),
              submitting: _submittingBuy,
              onSubmit: () => _submitLineCondition(true, buyLines),
            ),
            const SizedBox(height: 10),
          ],
          if (sellLines.isNotEmpty)
            _buildLineTriggerCard(
              lines: sellLines, isBuy: false,
              qty: _lineSellQty,
              onQtyChanged: (v) => setState(() => _lineSellQty = v),
              submitting: _submittingSell,
              onSubmit: () => _submitLineCondition(false, sellLines),
            ),
        ],

        const SizedBox(height: 28),

        // ── 지표 조건 ──────────────────────────────
        _buildSectionHeader(Icons.analytics_outlined, '지표 조건', '기술 지표 기반 자동 전략'),
        const SizedBox(height: 12),
        if (sym == null)
          _buildNoSymbolHint()
        else ...[
          _buildIndicatorGrid(),
          const SizedBox(height: 16),
          _buildTimeframeChips(),
          const SizedBox(height: 16),
          _buildIndicatorConditionCard(),
          const SizedBox(height: 14),
          _buildIndQuantityRow(),
          const SizedBox(height: 14),
          _buildIntervalChips(),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _submittingInd ? null : _submitIndicator,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: _submittingInd
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.bolt, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('지표 조건 등록',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      ]),
              ),
            ),
          ),
        ],

        const SizedBox(height: 28),
        _SectionLabel('대기 중인 매매선 예약'),
        const SizedBox(height: 12),
        _PendingAlertsList(),
        const SizedBox(height: 28),
        _SectionLabel('실행 중인 지표 전략'),
        const SizedBox(height: 12),
        _RunningJobsList(),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String sub) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.green, size: 18),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
      ]),
    ]);
  }

  Widget _buildNoSymbolHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: AppColors.gray, size: 16),
        SizedBox(width: 8),
        Text('위 검색창에서 종목을 선택하세요',
            style: TextStyle(color: AppColors.gray, fontSize: 13)),
      ]),
    );
  }

  Widget _buildNoLineHint() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.draw_outlined, color: Color(0xFF26A69A), size: 16),
          SizedBox(width: 6),
          Text('차트에 매매선을 그려주세요',
              style: TextStyle(color: Color(0xFF26A69A), fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        const Text(
          '차트 탭에서 추세선을 그리고, 선을 탭해 툴바에서\n매수선 또는 매도선 역할을 지정하면 조건 등록이 가능합니다.',
          style: TextStyle(color: AppColors.gray, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 10),
        const Row(children: [
          _MiniTag('매수선', Color(0xFF26A69A)),
          SizedBox(width: 6),
          _MiniTag('매도선', AppColors.red),
          SizedBox(width: 8),
          Text('역할 지정 후 여기서 조건 등록', style: TextStyle(color: AppColors.gray, fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _buildLineTriggerCard({
    required List<ChartLineInfo> lines,
    required bool isBuy,
    required int qty,
    required ValueChanged<int> onQtyChanged,
    required bool submitting,
    required VoidCallback onSubmit,
  }) {
    final color = isBuy ? const Color(0xFF26A69A) : AppColors.red;
    final label = isBuy ? '매수선' : '매도선';
    final icon  = isBuy ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text('$label  ${lines.length}개 감지',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        ...lines.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Text('${e.key + 1}',
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${e.value.isHorizontal ? '수평선' : '추세선'}  ${_linePriceLabel(e.value)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            )),
          ]),
        )),
        const SizedBox(height: 10),
        const Divider(height: 1, color: Color(0xFF252A34)),
        const SizedBox(height: 10),
        Row(children: [
          const Text('수량', style: TextStyle(color: AppColors.gray, fontSize: 13)),
          const Spacer(),
          _CounterButton(icon: Icons.remove, onTap: () { if (qty > 1) onQtyChanged(qty - 1); }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('$qty주', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          _CounterButton(icon: Icons.add, onTap: () => onQtyChanged(qty + 1)),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: submitting ? null : onSubmit,
          child: Container(
            height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('$label 조건 등록',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildIndicatorGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.82,
      ),
      itemCount: _indicators.length,
      itemBuilder: (_, i) {
        final ind = _indicators[i];
        final sel = _indicator == ind.id;
        return GestureDetector(
          onTap: () => setState(() => _indicator = ind.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: sel ? ind.color.withValues(alpha: 0.15) : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? ind.color : Colors.transparent, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ind.icon, color: ind.color, size: 18),
                const SizedBox(height: 4),
                Text(ind.name, style: TextStyle(
                    color: sel ? ind.color : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(ind.badge, style: TextStyle(color: ind.color.withValues(alpha: 0.8), fontSize: 9)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeframeChips() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('봉 주기'),
      const SizedBox(height: 8),
      Row(children: _timeframes.map((tf) {
        final sel = _timeframe == tf.value;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _timeframe = tf.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? AppColors.green : AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(tf.label, style: TextStyle(
                  color: sel ? AppColors.bg : AppColors.gray,
                  fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        );
      }).toList()),
    ]);
  }

  Widget _buildIndicatorConditionCard() {
    final ind = _indicators.firstWhere((i) => i.id == _indicator);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ind.color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 매수 조건
        const Row(children: [
          Icon(Icons.arrow_upward, color: Color(0xFF26A69A), size: 13),
          SizedBox(width: 5),
          Text('매수 조건', style: TextStyle(color: Color(0xFF26A69A), fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        if (ind.id == 'rsi') ...[
          Text('RSI < $_rsiBuyThr  일 때 매수',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: _rsiBuyOptions.map((v) {
            final sel = _rsiBuyThr == v;
            return GestureDetector(
              onTap: () => setState(() => _rsiBuyThr = v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF26A69A) : AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? const Color(0xFF26A69A) : AppColors.gray.withValues(alpha: 0.3)),
                ),
                child: Text('$v', style: TextStyle(
                    color: sel ? Colors.white : AppColors.gray,
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList()),
        ] else
          Text(ind.buyDesc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),

        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFF252A34)),
        const SizedBox(height: 14),

        // 매도 조건
        const Row(children: [
          Icon(Icons.arrow_downward, color: AppColors.red, size: 13),
          SizedBox(width: 5),
          Text('매도 조건', style: TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        if (ind.id == 'rsi') ...[
          Text('RSI > $_rsiSellThr  일 때 매도',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: _rsiSellOptions.map((v) {
            final sel = _rsiSellThr == v;
            return GestureDetector(
              onTap: () => setState(() => _rsiSellThr = v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppColors.red : AppColors.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? AppColors.red : AppColors.gray.withValues(alpha: 0.3)),
                ),
                child: Text('$v', style: TextStyle(
                    color: sel ? Colors.white : AppColors.gray,
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList()),
        ] else
          Text(ind.sellDesc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),

        if (ind.id == 'ichimoku') ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.yellow.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.construction_outlined, color: AppColors.yellow, size: 12),
              SizedBox(width: 6),
              Text('백엔드 구현 예정', style: TextStyle(color: AppColors.yellow, fontSize: 11)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildIndQuantityRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Text('수량', style: TextStyle(color: AppColors.gray, fontSize: 13)),
        const Spacer(),
        _CounterButton(icon: Icons.remove, onTap: () { if (_indQty > 1) setState(() => _indQty--); }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('$_indQty주', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        _CounterButton(icon: Icons.add, onTap: () => setState(() => _indQty++)),
      ]),
    );
  }

  Widget _buildIntervalChips() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionLabel('실행 간격'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: _intervals.map((iv) {
        final sel = _intervalSec == iv.sec;
        return GestureDetector(
          onTap: () => setState(() => _intervalSec = iv.sec),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.green : AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(iv.label, style: TextStyle(
                color: sel ? AppColors.bg : AppColors.gray,
                fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        );
      }).toList()),
    ]);
  }
}

// ─── Tab 1: 지정가 매매 ───────────────────────────────────────────────────────

class _ConditionalTab extends StatefulWidget {
  final SymbolInfo? selected;
  final String? currentPrice;
  const _ConditionalTab({this.selected, this.currentPrice});
  @override
  State<_ConditionalTab> createState() => _ConditionalTabState();
}

class _ConditionalTabState extends State<_ConditionalTab> {
  String _side = 'buy';
  final _priceCtrl = TextEditingController();
  int _quantity = 10;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _priceCtrl.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_ConditionalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?.ticker != widget.selected?.ticker) {
      _priceCtrl.clear();
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = widget.selected;
    if (s == null) { _snack('종목을 선택하세요'); return; }

    final parsed = int.tryParse(_priceCtrl.text.replaceAll(',', ''));
    if (parsed == null || parsed <= 0) { _snack('목표 가격을 입력하세요'); return; }

    setState(() => _submitting = true);
    try {
      await context.read<AlertProvider>().addAlert(
        ticker: s.ticker,
        side: _side,
        quantity: _quantity,
        targetPrice: parsed,
      );
      if (mounted) {
        _snack('예약이 등록됐습니다', success: true);
        _priceCtrl.clear();
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.green : AppColors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final parsed = int.tryParse(_priceCtrl.text.replaceAll(',', ''));
    final totalAmount = (parsed != null && parsed > 0) ? parsed * _quantity : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (widget.selected == null)
          _buildNoSymbolHint()
        else ...[
          _SectionLabel('방향'),
          const SizedBox(height: 10),
          _buildBuySellToggle(),
          const SizedBox(height: 20),
          _SectionLabel('목표 가격'),
          const SizedBox(height: 10),
          _buildPriceInput(),
          const SizedBox(height: 20),
          _SectionLabel('수량'),
          const SizedBox(height: 10),
          _buildQuantityRow(),
          const SizedBox(height: 24),
          _ConditionalRegisterButton(
            side: _side,
            loading: _submitting,
            totalAmount: totalAmount,
            onTap: _submit,
          ),
        ],
        const SizedBox(height: 28),
        _SectionLabel('대기 중인 예약'),
        const SizedBox(height: 12),
        _PendingAlertsList(),
      ],
    );
  }

  Widget _buildNoSymbolHint() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.gray, size: 18),
          SizedBox(width: 10),
          Text('위 검색창에서 종목을 선택하세요',
              style: TextStyle(color: AppColors.gray, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildBuySellToggle() {
    return Row(
      children: [
        Expanded(
            child: _SideButton(
          label: '매수',
          selected: _side == 'buy',
          color: AppColors.red,
          onTap: () => setState(() => _side = 'buy'),
        )),
        const SizedBox(width: 8),
        Expanded(
            child: _SideButton(
          label: '매도',
          selected: _side == 'sell',
          color: AppColors.blue,
          onTap: () => setState(() => _side = 'sell'),
        )),
      ],
    );
  }

  Widget _buildPriceInput() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.gray, fontSize: 18),
                isDense: true,
              ),
            ),
          ),
          const Text('원',
              style: TextStyle(color: AppColors.gray, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildQuantityRow() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('수량',
              style: TextStyle(color: AppColors.gray, fontSize: 13)),
          const Spacer(),
          _CounterButton(
            icon: Icons.remove,
            onTap: () {
              if (_quantity > 1) setState(() => _quantity--);
            },
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$_quantity주',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          _CounterButton(
            icon: Icons.add,
            onTap: () => setState(() => _quantity++),
          ),
        ],
      ),
    );
  }
}


// ─── Pending Alerts List (종목별 그룹화) ──────────────────────────────────────

class _PendingAlertsList extends StatefulWidget {
  @override
  State<_PendingAlertsList> createState() => _PendingAlertsListState();
}

class _PendingAlertsListState extends State<_PendingAlertsList> {
  final Set<String> _expanded = {};
  // 티커 코드 → 종목명 캐시
  final Map<String, String> _names = {};

  Future<String> _resolveName(String ticker) async {
    if (_names.containsKey(ticker)) return _names[ticker]!;
    final results = await SymbolDatabase.searchAsync(ticker, '주식');
    final match = results.where((s) => s.ticker == ticker).toList();
    final name = match.isNotEmpty ? match.first.name : ticker;
    if (mounted) setState(() => _names[ticker] = name);
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertProvider>(
      builder: (_, provider, __) {
        if (provider.loading) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.green, strokeWidth: 2));
        }
        if (provider.alerts.isEmpty) {
          return _emptyState(Icons.notifications_none, '등록된 예약이 없습니다',
              '위에서 예약을 추가하세요');
        }

        // 티커별 그룹화
        final Map<String, List<PriceAlertModel>> grouped = {};
        for (final a in provider.alerts) {
          grouped.putIfAbsent(a.ticker, () => []).add(a);
        }

        return Column(
          children: grouped.entries.map((entry) {
            final ticker = entry.key;
            final alerts = entry.value;
            final isExpanded = _expanded.contains(ticker);
            final name = _names[ticker] ?? ticker;
            // 이름이 아직 없으면 비동기 로드
            if (!_names.containsKey(ticker)) _resolveName(ticker);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TickerGroupCard(
                ticker: ticker,
                name: name,
                alerts: alerts,
                isExpanded: isExpanded,
                onToggle: () => setState(() {
                  if (isExpanded) { _expanded.remove(ticker); }
                  else { _expanded.add(ticker); }
                }),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TickerGroupCard extends StatelessWidget {
  final String ticker;
  final String name;
  final List<PriceAlertModel> alerts;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _TickerGroupCard({
    required this.ticker,
    required this.name,
    required this.alerts,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final buyCount  = alerts.where((a) => a.isBuy).length;
    final sellCount = alerts.where((a) => !a.isBuy).length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // ── 헤더 (항상 표시) ──
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        ticker.length > 3 ? ticker.substring(0, 3) : ticker,
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(children: [
                          if (buyCount > 0) ...[
                            _MiniTag('매수 $buyCount', AppColors.red),
                            const SizedBox(width: 4),
                          ],
                          if (sellCount > 0)
                            _MiniTag('매도 $sellCount', AppColors.blue),
                        ]),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.gray,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // ── 펼침 콘텐츠 ──
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFF252A34)),
            ...alerts.map((a) => _AlertRow(alert: a)),
          ],
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniTag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final PriceAlertModel alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final color = a.isBuy ? AppColors.red : AppColors.blue;
    final sideLabel = a.isBuy ? '매수' : '매도';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final price = a.effectiveTargetAt(now);

    // 추세선 좌표와 현재 ChartProvider의 라인 비교 (불일치 경고)
    final chartLines = context
        .watch<ChartProvider>()
        .getLinesForTicker(a.ticker);
    final hasMismatch = a.isTrendline && !chartLines.any((l) =>
        l.startTime == a.lineStartTime &&
        l.endTime == a.lineEndTime &&
        (l.startPrice - (a.lineStartPrice ?? 0)).abs() < 1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(sideLabel,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${_fmtNum(price)}원',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  if (a.isTrendline) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.timeline,
                        color: Color(0xFF6C63FF), size: 12),
                  ],
                  if (hasMismatch) ...[
                    const SizedBox(width: 4),
                    const Tooltip(
                      message: '차트의 추세선이 변경됐습니다.\n예약을 재등록하세요.',
                      child: Icon(Icons.warning_amber_rounded,
                          color: AppColors.yellow, size: 14),
                    ),
                  ],
                ]),
                Text('${a.quantity}주${a.triggered ? '  ✓ 체결됨' : ''}',
                    style: TextStyle(
                        color: a.triggered
                            ? AppColors.green
                            : AppColors.gray,
                        fontSize: 10)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _confirmDelete(context),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.close,
                  color: AppColors.red, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final a = alert;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('예약 삭제',
            style: TextStyle(color: Colors.white)),
        content: Text('${a.ticker} 종목의 모든 예약이 삭제됩니다.',
            style: const TextStyle(color: AppColors.gray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('취소', style: TextStyle(color: AppColors.gray)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AlertProvider>().deleteAlert(a.ticker);
            },
            child: const Text('삭제',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Running Jobs List ────────────────────────────────────────────────────────

class _RunningJobsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (_, provider, __) {
        if (provider.loading) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.green, strokeWidth: 2));
        }
        if (provider.jobs.isEmpty) {
          return _emptyState(
              Icons.auto_mode, '등록된 전략이 없습니다', '위에서 전략을 추가하세요');
        }
        return Column(
          children: provider.jobs
              .map((j) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _JobCard(job: j),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  final SchedulerJob job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<JobProvider>();
    final color = job.isPaused ? AppColors.gray : AppColors.green;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.strategyName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text('${job.ticker}  ·  ${job.scheduleLabel}',
                        style: const TextStyle(
                            color: AppColors.gray, fontSize: 11)),
                  ],
                ),
              ),
              _StatusBadge(isPaused: job.isPaused),
            ],
          ),
          if (job.nextRunTime != null) ...[
            const SizedBox(height: 6),
            Text('다음 실행: ${job.nextRunTime}',
                style: const TextStyle(
                    color: AppColors.gray, fontSize: 10)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _SmallBtn(
                icon: job.isPaused ? Icons.play_arrow : Icons.pause,
                label: job.isPaused ? '재개' : '일시정지',
                color: color,
                onTap: () => job.isPaused
                    ? provider.resumeJob(job.jobId)
                    : provider.pauseJob(job.jobId),
              ),
              const SizedBox(width: 8),
              _SmallBtn(
                icon: Icons.flash_on,
                label: '즉시 실행',
                color: AppColors.yellow,
                onTap: () => provider.runJobNow(job.jobId),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _confirmDelete(context, provider),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close,
                      color: AppColors.red, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, JobProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('전략 삭제',
            style: TextStyle(color: Colors.white)),
        content: Text('${job.ticker} · ${job.strategyName}\n삭제할까요?',
            style: const TextStyle(color: AppColors.gray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('취소', style: TextStyle(color: AppColors.gray)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteJob(job.jobId);
            },
            child: const Text('삭제',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Micro Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.gray,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4));
}

class _StatusBadge extends StatelessWidget {
  final bool isPaused;
  const _StatusBadge({required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final color = isPaused ? AppColors.gray : AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(isPaused ? '일시정지' : '실행 중',
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.green, size: 16),
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _SideButton(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? color : AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppColors.bg : AppColors.gray,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _ConditionalRegisterButton extends StatelessWidget {
  final String side;
  final bool loading;
  final int? totalAmount;
  final VoidCallback onTap;
  const _ConditionalRegisterButton(
      {required this.side, required this.loading, required this.onTap, this.totalAmount});

  @override
  Widget build(BuildContext context) {
    final isBuy = side == 'buy';
    final color = isBuy ? AppColors.red : AppColors.blue;
    final textColor = Colors.white;
    final action = isBuy ? '매수 예약 등록' : '매도 예약 등록';
    final label = totalAmount != null
        ? '${_fmtNum(totalAmount!.toDouble())}원  $action'
        : action;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: textColor, strokeWidth: 2))
              : Text(label,
                  style: TextStyle(
                      color: textColor, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

Widget _emptyState(IconData icon, String title, String sub) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.green, size: 26),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub,
              style:
                  const TextStyle(color: AppColors.gray, fontSize: 12)),
        ],
      ),
    ),
  );
}

// ─── Indicator metadata ───────────────────────────────────────────────────────

class _IndMeta {
  final String id, name, badge, buyDesc, sellDesc;
  final IconData icon;
  final Color color;
  const _IndMeta({
    required this.id,
    required this.name,
    required this.badge,
    required this.icon,
    required this.color,
    required this.buyDesc,
    required this.sellDesc,
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtNum(double v) {
  return v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');
}
