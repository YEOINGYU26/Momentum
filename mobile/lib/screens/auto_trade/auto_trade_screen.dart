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
import '../../providers/job_provider.dart';
import '../../providers/alert_provider.dart';
import '../../providers/chart_provider.dart';
import '../../providers/condition_provider.dart';
import '../../models/compound_condition_model.dart';
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
      context.read<ConditionProvider>().fetchRules();
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
  // 거래 방향
  String _side = 'buy';

  // 조건 토글
  bool _useLineTrigger = false;
  bool _useRsi         = false;
  bool _useMaCross     = false;
  bool _useBollinger   = false;
  bool _useIchimoku    = false;

  // RSI 기준값
  int _rsiBuyThr  = 30;
  int _rsiSellThr = 70;

  // 공통 설정
  String _timeframe   = 'D';
  int    _qty         = 10;
  int    _intervalSec = 60;
  bool   _submitting  = false;

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
  static const _rsiBuyOpts  = [20, 25, 30, 35];
  static const _rsiSellOpts = [65, 70, 75, 80];

  bool get _isBuy => _side == 'buy';
  Color get _sideColor => _isBuy ? const Color(0xFF26A69A) : AppColors.red;

  int get _activeCount {
    int n = 0;
    if (_useLineTrigger) n++;
    if (_useRsi)         n++;
    if (_useMaCross)     n++;
    if (_useBollinger)   n++;
    return n;
  }

  void _snack(String msg, {bool success = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.green : AppColors.red,
        behavior: SnackBarBehavior.floating,
      ));

  String _linePriceLabel(ChartLineInfo l) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final p = l.priceAt(now);
    return l.isHorizontal ? '${_fmtNum(p)}원' : '약 ${_fmtNum(p)}원';
  }

  Future<void> _submit(List<ChartLineInfo> triggerLines) async {
    final s = widget.selected;
    if (s == null) { _snack('종목을 선택하세요'); return; }
    if (_activeCount == 0) { _snack('조건을 하나 이상 선택하세요'); return; }
    setState(() => _submitting = true);
    try {
      await context.read<ConditionProvider>().addRule(
        ticker: s.ticker,
        side: _side,
        quantity: _qty,
        intervalSeconds: _intervalSec,
        timeframe: _timeframe,
        lineConditions: _useLineTrigger ? triggerLines : [],
        useRsi: _useRsi,
        rsiBuyThr: _rsiBuyThr,
        rsiSellThr: _rsiSellThr,
        useMaCross: _useMaCross,
        useBollinger: _useBollinger,
      );
      if (mounted) _snack('조건 규칙이 등록됐습니다', success: true);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = widget.selected;
    final allLines = sym != null
        ? context.watch<ChartProvider>().getLinesForTicker(sym.ticker)
        : <ChartLineInfo>[];
    final triggerLines = allLines
        .where((l) => l.role == (_isBuy ? LineRole.buyTrigger : LineRole.sellTrigger))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── 종목 미선택 힌트 ──
        if (sym == null) ...[
          _buildNoSymbolHint(),
          const SizedBox(height: 20),
        ],

        // ── 방향 선택 ──
        _SectionLabel('거래 방향'),
        const SizedBox(height: 8),
        _buildSideToggle(),
        const SizedBox(height: 20),

        // ── AND 조건 설명 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(children: [
            Icon(Icons.join_inner, color: AppColors.green, size: 14),
            SizedBox(width: 6),
            Expanded(child: Text(
              '선택한 모든 조건이 동시에 충족될 때 주문이 실행됩니다 (AND)',
              style: TextStyle(color: AppColors.green, fontSize: 11),
            )),
          ]),
        ),
        const SizedBox(height: 16),

        // ── 조건 카드들 ──
        _buildLineToggleCard(sym, triggerLines),
        const SizedBox(height: 8),
        _buildRsiToggleCard(),
        const SizedBox(height: 8),
        _buildSimpleToggleCard(
          label: '골든크로스',
          badge: 'MA 5/20',
          icon: Icons.trending_up,
          color: const Color(0xFFF2B41E),
          desc: _isBuy ? '단기MA(5)가 장기MA(20)를 상향 돌파' : '단기MA(5)가 장기MA(20)를 하향 돌파',
          enabled: _useMaCross,
          onToggle: (v) => setState(() => _useMaCross = v),
        ),
        const SizedBox(height: 8),
        _buildSimpleToggleCard(
          label: '볼린저밴드',
          badge: 'BB(20,2)',
          icon: Icons.speed,
          color: const Color(0xFF6C63FF),
          desc: _isBuy ? '볼린저 하단(−2σ) 이탈 감지' : '볼린저 상단(+2σ) 도달 감지',
          enabled: _useBollinger,
          onToggle: (v) => setState(() => _useBollinger = v),
        ),
        const SizedBox(height: 8),
        _buildSimpleToggleCard(
          label: '이치모쿠',
          badge: 'Ichimoku',
          icon: Icons.layers_outlined,
          color: const Color(0xFF00BCD4),
          desc: _isBuy ? '구름대 하단 지지선 근접' : '구름대 상단 저항선 도달',
          enabled: _useIchimoku,
          onToggle: (v) => setState(() => _useIchimoku = v),
          wip: true,
        ),

        const SizedBox(height: 20),

        // ── 봉 주기 ──
        _SectionLabel('봉 주기'),
        const SizedBox(height: 8),
        _buildChips(_timeframes.map((tf) => (tf.label, tf.value)).toList(),
            _timeframe, (v) => setState(() => _timeframe = v), AppColors.green),

        const SizedBox(height: 16),

        // ── 수량 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Text('수량', style: TextStyle(color: AppColors.gray, fontSize: 13)),
            const Spacer(),
            _CounterButton(icon: Icons.remove, onTap: () { if (_qty > 1) setState(() => _qty--); }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$_qty주', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            _CounterButton(icon: Icons.add, onTap: () => setState(() => _qty++)),
          ]),
        ),

        const SizedBox(height: 14),

        // ── 실행 간격 ──
        _SectionLabel('실행 간격'),
        const SizedBox(height: 8),
        _buildChips(_intervals.map((iv) => (iv.label, iv.sec.toString())).toList(),
            _intervalSec.toString(), (v) => setState(() => _intervalSec = int.parse(v)),
            AppColors.green),

        const SizedBox(height: 20),

        // ── 등록 버튼 ──
        GestureDetector(
          onTap: (sym == null || _submitting || _activeCount == 0)
              ? null
              : () => _submit(triggerLines),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 54,
            decoration: BoxDecoration(
              color: (_activeCount > 0 && sym != null) ? _sideColor : AppColors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.bolt, color: (_activeCount > 0 && sym != null) ? Colors.white : AppColors.gray, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        _activeCount == 0
                            ? '조건을 선택하세요'
                            : '${_isBuy ? '매수' : '매도'} 조건 $_activeCount개 AND 등록',
                        style: TextStyle(
                          color: (_activeCount > 0 && sym != null) ? Colors.white : AppColors.gray,
                          fontSize: 14, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ]),
            ),
          ),
        ),

        const SizedBox(height: 28),
        _SectionLabel('등록된 조건 규칙'),
        const SizedBox(height: 12),
        _CompoundRulesList(),
      ],
    );
  }

  Widget _buildNoSymbolHint() => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
    decoration: BoxDecoration(
      color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12),
    ),
    child: const Row(children: [
      Icon(Icons.info_outline, color: AppColors.gray, size: 16),
      SizedBox(width: 8),
      Text('위 검색창에서 종목을 선택하세요', style: TextStyle(color: AppColors.gray, fontSize: 13)),
    ]),
  );

  Widget _buildSideToggle() {
    return Row(children: [
      Expanded(child: _SideButton(label: '매수', selected: _isBuy,  color: const Color(0xFF26A69A), onTap: () => setState(() => _side = 'buy'))),
      const SizedBox(width: 8),
      Expanded(child: _SideButton(label: '매도', selected: !_isBuy, color: AppColors.red,           onTap: () => setState(() => _side = 'sell'))),
    ]);
  }

  // 매매선 조건 카드 (토글 + 라인 목록)
  Widget _buildLineToggleCard(SymbolInfo? sym, List<ChartLineInfo> lines) {
    final noLines = lines.isEmpty;
    final label = _isBuy ? '매수선 터치' : '매도선 터치';
    final color = _sideColor;

    return _ConditionCard(
      icon: _isBuy ? Icons.arrow_upward : Icons.arrow_downward,
      label: label,
      badge: _isBuy ? 'buyTrigger' : 'sellTrigger',
      color: color,
      enabled: _useLineTrigger,
      disabled: sym == null || noLines,
      onToggle: (v) => setState(() => _useLineTrigger = v),
      expandedContent: noLines
          ? _buildNoLineHint()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('감지된 ${_isBuy ? '매수' : '매도'}선 ${lines.length}개',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...lines.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(width: 16, height: 16,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Center(child: Text('${e.key + 1}', style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 6),
                  Text('${e.value.isHorizontal ? '수평선' : '추세선'}  ${_linePriceLabel(e.value)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              )),
            ]),
    );
  }

  Widget _buildNoLineHint() => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      const Icon(Icons.draw_outlined, color: AppColors.gray, size: 13),
      const SizedBox(width: 6),
      Expanded(child: Text(
        '차트 탭에서 추세선을 그리고 ${_isBuy ? '매수' : '매도'}선으로 지정하세요',
        style: const TextStyle(color: AppColors.gray, fontSize: 11),
      )),
    ]),
  );

  // RSI 조건 카드 (토글 + 기준값 칩)
  Widget _buildRsiToggleCard() => _ConditionCard(
    icon: Icons.show_chart,
    label: 'RSI',
    badge: 'RSI(14)',
    color: AppColors.green,
    enabled: _useRsi,
    onToggle: (v) => setState(() => _useRsi = v),
    expandedContent: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        _isBuy ? 'RSI < $_rsiBuyThr  일 때 매수' : 'RSI > $_rsiSellThr  일 때 매도',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: (
        _isBuy ? _rsiBuyOpts : _rsiSellOpts
      ).map((v) {
        final sel = _isBuy ? _rsiBuyThr == v : _rsiSellThr == v;
        return GestureDetector(
          onTap: () => setState(() {
            if (_isBuy) { _rsiBuyThr = v; } else { _rsiSellThr = v; }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? AppColors.green : AppColors.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sel ? AppColors.green : AppColors.gray.withValues(alpha: 0.3)),
            ),
            child: Text('$v', style: TextStyle(color: sel ? AppColors.bg : AppColors.gray, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      }).toList()),
    ]),
  );

  // 단순 토글 카드 (설명만 표시)
  Widget _buildSimpleToggleCard({
    required String label,
    required String badge,
    required IconData icon,
    required Color color,
    required String desc,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    bool wip = false,
  }) => _ConditionCard(
    icon: icon, label: label, badge: badge, color: color,
    enabled: enabled, onToggle: onToggle,
    expandedContent: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
      if (wip) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.yellow.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.construction_outlined, color: AppColors.yellow, size: 11),
            SizedBox(width: 4),
            Text('백엔드 구현 예정', style: TextStyle(color: AppColors.yellow, fontSize: 10)),
          ]),
        ),
      ],
    ]),
  );

  Widget _buildChips(List<(String, String)> items, String selected, ValueChanged<String> onTap, Color activeColor) {
    return Wrap(spacing: 8, runSpacing: 6, children: items.map((it) {
      final sel = selected == it.$2;
      return GestureDetector(
        onTap: () => onTap(it.$2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? activeColor : AppColors.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(it.$1, style: TextStyle(
            color: sel ? AppColors.bg : AppColors.gray, fontSize: 13, fontWeight: FontWeight.w600,
          )),
        ),
      );
    }).toList());
  }
}

// ── 조건 카드 공통 위젯 ───────────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  final IconData icon;
  final String label, badge;
  final Color color;
  final bool enabled;
  final bool disabled;
  final ValueChanged<bool> onToggle;
  final Widget? expandedContent;

  const _ConditionCard({
    required this.icon,
    required this.label,
    required this.badge,
    required this.color,
    required this.enabled,
    required this.onToggle,
    this.expandedContent,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? color.withValues(alpha: 0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── 헤더 (항상 표시) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: enabled ? 0.2 : 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: enabled ? color : AppColors.gray, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(
                    color: enabled ? Colors.white : AppColors.gray,
                    fontSize: 13, fontWeight: FontWeight.w600)),
                Text(badge, style: TextStyle(
                    color: enabled ? color.withValues(alpha: 0.8) : AppColors.gray,
                    fontSize: 10)),
              ]),
            ),
            Switch(
              value: enabled,
              onChanged: disabled ? null : onToggle,
              activeThumbColor: color,
              inactiveThumbColor: AppColors.gray,
              inactiveTrackColor: AppColors.bg,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),

        // ── 펼침 영역 (enabled 시) ──
        if (enabled && expandedContent != null) ...[
          const Divider(height: 1, color: Color(0xFF252A34)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: expandedContent!,
          ),
        ],
      ]),
    );
  }
}

// ── 등록된 복합 조건 목록 ─────────────────────────────────────────────────────

class _CompoundRulesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ConditionProvider>(builder: (_, provider, _) {
      if (provider.loading) {
        return const Center(child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2));
      }
      if (provider.rules.isEmpty) {
        return _emptyState(Icons.rule_outlined, '등록된 조건 규칙이 없습니다', '위에서 조건을 조합해 등록하세요');
      }
      return Column(
        children: provider.rules.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CompoundRuleCard(rule: r),
        )).toList(),
      );
    });
  }
}

class _CompoundRuleCard extends StatelessWidget {
  final CompoundConditionModel rule;
  const _CompoundRuleCard({required this.rule});

  @override
  Widget build(BuildContext context) {
    final color = rule.isBuy ? const Color(0xFF26A69A) : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 3, height: 40,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${rule.ticker}  ${rule.isBuy ? '매수' : '매도'}  ${rule.quantity}주',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(rule.conditionSummary.isEmpty ? '조건 없음' : rule.conditionSummary,
              style: const TextStyle(color: AppColors.gray, fontSize: 11)),
          if (rule.triggeredCount > 0) ...[
            const SizedBox(height: 2),
            Text('${rule.triggeredCount}회 실행됨', style: const TextStyle(color: AppColors.green, fontSize: 10)),
          ],
        ])),
        GestureDetector(
          onTap: () => _confirmDelete(context),
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.close, color: AppColors.red, size: 14),
          ),
        ),
      ]),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('조건 삭제', style: TextStyle(color: Colors.white)),
        content: Text('${rule.ticker} 조건 규칙을 삭제할까요?',
            style: const TextStyle(color: AppColors.gray)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: AppColors.gray))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ConditionProvider>().deleteRule(rule.ruleId);
            },
            child: const Text('삭제', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
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
      builder: (_, provider, _) {
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtNum(double v) {
  return v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');
}
