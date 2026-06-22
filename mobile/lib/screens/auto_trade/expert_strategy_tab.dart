import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class ExpertStrategy {
  final String id;
  final String name;
  final String ticker;
  final String tickerName;
  final Color tickerColor;
  final String strategyType;
  final String riskLevel;       // 안전 | 보통 | 위험
  final double recentReturn;    // 최근 6개월 수익률 %
  final double maxDrawdown;     // MDD % (음수)
  final double cagr;
  final double cumulativeReturn;
  final double sharpe;
  final double winRate;
  final double avgHoldingDays;
  final double dailyTrades;
  final int currentInvestors;
  final int maxInvestors;
  final double minAmount;       // 만원 단위
  final double maxAmount;
  final double totalVolume;     // 누적 거래대금 (원)
  final String period;
  final String marketReturn;    // 단순 보유 수익률 (문자열)
  final double marketMDD;
  final String description;
  final List<String> recommendations;
  final List<String> cautions;
  final List<String> keyPoints;

  const ExpertStrategy({
    required this.id,
    required this.name,
    required this.ticker,
    required this.tickerName,
    required this.tickerColor,
    required this.strategyType,
    required this.riskLevel,
    required this.recentReturn,
    required this.maxDrawdown,
    required this.cagr,
    required this.cumulativeReturn,
    required this.sharpe,
    required this.winRate,
    required this.avgHoldingDays,
    required this.dailyTrades,
    required this.currentInvestors,
    required this.maxInvestors,
    required this.minAmount,
    required this.maxAmount,
    required this.totalVolume,
    required this.period,
    required this.marketReturn,
    required this.marketMDD,
    required this.description,
    required this.recommendations,
    required this.cautions,
    required this.keyPoints,
  });
}

// ── Strategy definitions ───────────────────────────────────────────────────────

const _kStrategies = <ExpertStrategy>[
  ExpertStrategy(
    id: 'samsung_dual_momentum',
    name: '삼성 듀얼 모멘텀',
    ticker: '005930',
    tickerName: '삼성전자',
    tickerColor: Color(0xFF1C6EF2),
    strategyType: '듀얼 모멘텀',
    riskLevel: '안전',
    recentReturn: 18.4,
    maxDrawdown: -9.2,
    cagr: 16.3,
    cumulativeReturn: 287.4,
    sharpe: 1.82,
    winRate: 63.5,
    avgHoldingDays: 4.2,
    dailyTrades: 0.8,
    currentInvestors: 24,
    maxInvestors: 50,
    minAmount: 50,
    maxAmount: 500,
    totalVolume: 52340000000,
    period: '2020-01 ~ 2026-06',
    marketReturn: '+12.3%',
    marketMDD: -29.6,
    description:
        '삼성전자를 대상으로 듀얼 모멘텀 전략을 자동 운용합니다. '
        '절대 모멘텀(추세 방향)과 상대 모멘텀(시장 대비 강도)을 동시에 확인해 '
        '두 신호가 모두 긍정적일 때만 매수에 진입합니다. '
        '신호가 약해지거나 반전되면 즉시 포지션을 청산해 손실을 제한합니다.',
    recommendations: [
      '삼성전자에 장기 투자하고 싶지만 타이밍이 고민인 분',
      '단순 보유보다 나은 수익률을 원하는 분',
      '최대 손실을 10% 이내로 관리하고 싶은 분',
    ],
    cautions: [
      '강한 횡보장에서 신호가 잦아 수수료 비용이 증가할 수 있습니다',
      '삼성전자 급락 시 절대 모멘텀 청산 전 손실이 발생할 수 있습니다',
    ],
    keyPoints: [
      '12개월 수익률로 절대 모멘텀 판단 — 마이너스면 현금 보유',
      '코스피200 대비 초과 수익 구간에서만 매수 진입',
      '월 1회 리밸런싱으로 매매 횟수 최소화',
    ],
  ),
  ExpertStrategy(
    id: 'hynix_rsi',
    name: '하이닉스 RSI 역추세',
    ticker: '000660',
    tickerName: 'SK하이닉스',
    tickerColor: Color(0xFFFF6B35),
    strategyType: 'RSI 역추세',
    riskLevel: '보통',
    recentReturn: 31.7,
    maxDrawdown: -18.4,
    cagr: 28.9,
    cumulativeReturn: 542.1,
    sharpe: 2.14,
    winRate: 71.2,
    avgHoldingDays: 1.8,
    dailyTrades: 2.4,
    currentInvestors: 18,
    maxInvestors: 30,
    minAmount: 100,
    maxAmount: 800,
    totalVolume: 78920000000,
    period: '2021-06 ~ 2026-06',
    marketReturn: '-8.1%',
    marketMDD: -45.3,
    description:
        'SK하이닉스의 단기 과매도 구간을 RSI(14)로 포착해 분할 매수하고, '
        '과매수 반등 시 일괄 정리하는 역추세 전략입니다. '
        '반도체 사이클 특성상 급락 이후 빠른 회복이 잦아 '
        '역추세 접근이 높은 승률로 이어집니다.',
    recommendations: [
      'SK하이닉스 단기 스윙 투자에 관심 있는 분',
      '승률을 최우선으로 보는 분',
      '반도체 업황 사이클을 활용하고 싶은 분',
    ],
    cautions: [
      '반도체 업황 악화 시 RSI 바닥이 깊어져 손실이 확대될 수 있습니다',
      '하루 평균 2~3회 매매로 수수료 관리가 필요합니다',
      'MDD -18.4%를 감수할 수 있는지 사전 확인 필수',
    ],
    keyPoints: [
      'RSI 30 이하 진입 — 4단계 분할 매수',
      'RSI 65 도달 또는 보유 3일 초과 시 전량 청산',
      '전일 거래량 평균 대비 150% 이상일 때만 신호 유효',
    ],
  ),
  ExpertStrategy(
    id: 'kospi_golden_cross',
    name: 'KOSPI 황금법칙',
    ticker: '069500',
    tickerName: 'KODEX 200',
    tickerColor: Color(0xFF26A69A),
    strategyType: '골든크로스 추세추종',
    riskLevel: '안전',
    recentReturn: 12.8,
    maxDrawdown: -7.1,
    cagr: 11.4,
    cumulativeReturn: 198.3,
    sharpe: 1.56,
    winRate: 58.3,
    avgHoldingDays: 12.6,
    dailyTrades: 0.3,
    currentInvestors: 41,
    maxInvestors: 100,
    minAmount: 30,
    maxAmount: 1000,
    totalVolume: 124500000000,
    period: '2018-01 ~ 2026-06',
    marketReturn: '+34.7%',
    marketMDD: -38.2,
    description:
        'KODEX 200(코스피200 ETF)을 5일·20일 이동평균 골든/데드크로스로 '
        '추세를 추종하는 장기 전략입니다. '
        '시장 전체를 추종해 개별 종목 리스크를 분산하면서 '
        '하락 추세에서는 현금을 보유해 MDD를 크게 줄입니다.',
    recommendations: [
      '처음 자동매매를 시작하는 분',
      '안전하게 시장 수익을 추구하는 분',
      '장기 투자를 선호하고 잦은 매매를 원하지 않는 분',
    ],
    cautions: [
      '단기 급등 장세에서 진입이 늦어 일부 수익을 놓칩니다',
      '박스권에서 크로스가 반복되며 손절이 잦을 수 있습니다',
    ],
    keyPoints: [
      'MA 5 > MA 20 골든크로스 → 매수 진입',
      'MA 5 < MA 20 데드크로스 → 전량 청산, 현금 보유',
      '일봉 기준 적용 — 월 평균 0.3회 매매',
    ],
  ),
  ExpertStrategy(
    id: 'kakao_bollinger',
    name: '카카오 볼린저 스캘핑',
    ticker: '035720',
    tickerName: '카카오',
    tickerColor: Color(0xFFFFD700),
    strategyType: '볼린저밴드 스캘핑',
    riskLevel: '위험',
    recentReturn: 47.3,
    maxDrawdown: -28.6,
    cagr: 41.2,
    cumulativeReturn: 1247.5,
    sharpe: 2.31,
    winRate: 76.8,
    avgHoldingDays: 0.4,
    dailyTrades: 6.3,
    currentInvestors: 15,
    maxInvestors: 30,
    minAmount: 85,
    maxAmount: 800,
    totalVolume: 109497032000,
    period: '2023-07 ~ 2026-06',
    marketReturn: '-8.69%',
    marketMDD: -64.46,
    description:
        '카카오 주가가 볼린저밴드 하단을 이탈할 때 분할 매수하고 '
        '중심선 또는 상단 도달 시 분할 청산하는 고빈도 스캘핑 전략입니다. '
        '시장 분위기(TRIX, 12시간 볼린저 위치)를 여섯 가지 레짐으로 나눠 '
        '각 국면마다 분할 횟수와 청산 규칙을 다르게 적용합니다.',
    recommendations: [
      '높은 수익률과 함께 리스크를 감수할 수 있는 분',
      '승률을 최우선으로 보는 분',
      '카카오 한 종목에 집중 투자하고 싶은 분',
    ],
    cautions: [
      'MDD -28.6%로 변동성이 크며 연도별로 편차가 큽니다',
      '하루 평균 6회 이상 매매 — 수수료 최적화 계좌 필요',
      '카카오 뉴스·이슈에 민감하여 예측 불가한 급락 리스크 존재',
    ],
    keyPoints: [
      '볼린저밴드(20, 2) 하단 이탈 → 레짐별 최대 8회 분할 매수',
      'TRIX 추세(일봉) + 12시간 볼린저 위치로 6가지 시장 국면 분류',
      '국면이 바뀌면 정해진 규칙대로 전량 청산 후 재진입',
    ],
  ),
  ExpertStrategy(
    id: 'naver_macd',
    name: '네이버 MACD 추세',
    ticker: '035420',
    tickerName: 'NAVER',
    tickerColor: Color(0xFF03C75A),
    strategyType: 'MACD 추세추종',
    riskLevel: '보통',
    recentReturn: 22.1,
    maxDrawdown: -14.3,
    cagr: 19.7,
    cumulativeReturn: 378.6,
    sharpe: 1.74,
    winRate: 65.9,
    avgHoldingDays: 3.1,
    dailyTrades: 1.2,
    currentInvestors: 29,
    maxInvestors: 50,
    minAmount: 70,
    maxAmount: 600,
    totalVolume: 63180000000,
    period: '2020-06 ~ 2026-06',
    marketReturn: '-18.4%',
    marketMDD: -52.7,
    description:
        'NAVER 주가의 MACD(12, 26, 9) 신호선 교차를 이용해 중기 추세에 올라타는 전략입니다. '
        'MACD 히스토그램 방향과 거래량 필터를 결합해 '
        '가짜 신호를 걸러내고 실질 추세 전환점에서 진입합니다. '
        '수익 실현은 단계적 분할 매도로 수익을 극대화합니다.',
    recommendations: [
      'NAVER의 중기 상승 구간을 포착하고 싶은 분',
      '주 1~2회 거래 빈도를 선호하는 분',
      '시장 대비 안정적으로 초과 수익을 원하는 분',
    ],
    cautions: [
      '강한 하락 추세에서 MACD 반전 신호가 늦어 손실이 발생할 수 있습니다',
      '인터넷·플랫폼 규제 이슈에 민감하게 반응합니다',
    ],
    keyPoints: [
      'MACD 신호선 상향 돌파 + 히스토그램 양전환 → 분할 매수',
      '거래량 20일 평균 대비 120% 이상 확인 후 진입',
      '목표가 3단계 분할 매도(+5%, +10%, +15%)로 수익 고정',
    ],
  ),
];

// ── Main tab widget ───────────────────────────────────────────────────────────

class ExpertStrategyTab extends StatefulWidget {
  const ExpertStrategyTab({super.key});

  @override
  State<ExpertStrategyTab> createState() => _ExpertStrategyTabState();
}

class _ExpertStrategyTabState extends State<ExpertStrategyTab> {
  String _filter = '전체';

  List<ExpertStrategy> get _filtered => _filter == '전체'
      ? _kStrategies
      : _kStrategies.where((s) => s.riskLevel == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterRow(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _StrategyCard(strategy: _filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    const options = ['전체', '안전', '보통', '위험'];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        children: options.map((o) {
          final selected = _filter == o;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? AppColors.green : AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.green : Colors.white12,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    color: selected ? AppColors.bg : AppColors.gray,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Strategy card ─────────────────────────────────────────────────────────────

class _StrategyCard extends StatelessWidget {
  final ExpertStrategy strategy;
  const _StrategyCard({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final s = strategy;
    final isProfit = s.recentReturn >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _StrategyDetailPage(strategy: s)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TickerChip(ticker: s.ticker, color: s.tickerColor),
                const Spacer(),
                _RiskBadge(level: s.riskLevel),
              ],
            ),
            const SizedBox(height: 10),
            Text(s.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(s.strategyType,
                style: const TextStyle(color: AppColors.gray, fontSize: 12)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('최근 수익률',
                          style:
                              TextStyle(color: AppColors.gray, fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(
                        '${isProfit ? '+' : ''}${s.recentReturn.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isProfit ? AppColors.green : AppColors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('최근 최대손실률',
                          style:
                              TextStyle(color: AppColors.gray, fontSize: 11)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${s.maxDrawdown.toStringAsFixed(2)}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          _RiskBadge(level: s.riskLevel, small: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.currentInvestors / s.maxInvestors,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.green),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('투자 가능',
                      style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(
                  '${s.currentInvestors} / ${s.maxInvestors} 명',
                  style:
                      const TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Strategy detail page ───────────────────────────────────────────────────────

class _StrategyDetailPage extends StatefulWidget {
  final ExpertStrategy strategy;
  const _StrategyDetailPage({required this.strategy});

  @override
  State<_StrategyDetailPage> createState() => _StrategyDetailPageState();
}

class _StrategyDetailPageState extends State<_StrategyDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strategy;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildHeader(s),
          _buildInnerTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _KeyMetricsTab(strategy: s),
                _DescriptionTab(strategy: s),
                _HistoricalTab(strategy: s),
              ],
            ),
          ),
          _buildBottomBar(s),
        ],
      ),
    );
  }

  Widget _buildHeader(ExpertStrategy s) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(height: 12),
            _TickerChip(ticker: s.ticker, color: s.tickerColor),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [s.tickerColor, s.tickerColor.withValues(alpha: 0.6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(s.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: s.currentInvestors / s.maxInvestors,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.green),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.tickerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${s.tickerName}  100%',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildInnerTabBar() {
    return Container(
      color: AppColors.bg,
      child: TabBar(
        controller: _tab,
        indicatorColor: AppColors.green,
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.gray,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        dividerColor: Colors.white12,
        tabs: const [
          Tab(text: '필수 지표'),
          Tab(text: '전략 설명'),
          Tab(text: '과거 성과'),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ExpertStrategy s) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: Colors.white12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.currentInvestors / s.maxInvestors,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.green),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('투자 가능',
                      style: TextStyle(
                          color: AppColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(
                  '${s.currentInvestors} / ${s.maxInvestors} 명',
                  style:
                      const TextStyle(color: AppColors.gray, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('전략 투자 기능은 준비 중입니다'),
                  backgroundColor: AppColors.card,
                ));
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('투자하기',
                      style: TextStyle(
                          color: AppColors.bg,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: 필수 지표 ─────────────────────────────────────────────────────────────

class _KeyMetricsTab extends StatelessWidget {
  final ExpertStrategy strategy;
  const _KeyMetricsTab({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final s = strategy;
    final aiSummary =
        '단순 보유 대비 ${(s.recentReturn - double.parse(s.marketReturn.replaceAll('%', '').replaceAll('+', ''))).abs().toStringAsFixed(0)}% 이상 높은 수익률을 기록했어요. '
        '시장보다 약 ${(s.maxDrawdown.abs() / s.marketMDD.abs()).toStringAsFixed(1)}배 더 안전하게 리스크를 관리한 전략이에요.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('6개월 전에 이 전략을 썼다면?',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${s.tickerName} 시장에 이렇게 대응했어요',
            style: const TextStyle(color: AppColors.gray, fontSize: 13)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AI 성과 요약',
                        style: TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(aiSummary,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _CompareCard(
              title: '단순 보유했다면',
              returnStr: s.marketReturn,
              returnPositive: s.marketReturn.startsWith('+'),
              mdd: s.marketMDD,
              riskBadge: '위험',
            )),
            const SizedBox(width: 12),
            Expanded(child: _CompareCard(
              title: '이 전략을 썼다면',
              returnStr: '+${s.recentReturn.toStringAsFixed(2)}%',
              returnPositive: true,
              mdd: s.maxDrawdown,
              riskBadge: s.riskLevel,
            )),
          ],
        ),
        const SizedBox(height: 24),
        const Text('투자 전, 꼭 확인!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _InfoCard(
              label: '투자 가능 금액',
              value:
                  '${s.minAmount.toInt()}~${s.maxAmount.toInt()}만 원',
            )),
            const SizedBox(width: 12),
            Expanded(child: _InfoCard(
              label: '누적 거래대금',
              value: _fmtVolume(s.totalVolume),
            )),
          ],
        ),
        const SizedBox(height: 24),
        const Text('포트폴리오 전략 이용 시 유의사항',
            style: TextStyle(color: AppColors.gray, fontSize: 12)),
        const SizedBox(height: 8),
        ...[
          '포트폴리오 내 전략별 비중은 투자 효율성과 시장 상황에 따라 조정될 수 있어요.',
          '구성된 전략(종목)은 시장 급변 등 리스크 대응이 불가피한 경우에 한해 일부 전략이 교체될 수 있어요.',
        ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ',
                      style:
                          TextStyle(color: AppColors.gray, fontSize: 12)),
                  Expanded(
                    child: Text(t,
                        style: const TextStyle(
                            color: AppColors.gray, fontSize: 12)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Tab: 전략 설명 ─────────────────────────────────────────────────────────────

class _DescriptionTab extends StatelessWidget {
  final ExpertStrategy strategy;
  const _DescriptionTab({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final s = strategy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text('전략 한눈에 보기',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(s.description,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14, height: 1.6)),
        const SizedBox(height: 24),
        _BulletSection(
          emoji: '✅',
          title: '이런 분께 추천드립니다',
          items: s.recommendations,
          color: AppColors.green,
        ),
        const SizedBox(height: 20),
        _BulletSection(
          emoji: '⚠️',
          title: '이런 분은 신중하게',
          items: s.cautions,
          color: const Color(0xFFFFB74D),
        ),
        const SizedBox(height: 24),
        const Text('📋  개요',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _TableCard(rows: [
          ('종목', s.tickerName),
          ('전략 유형', s.strategyType),
          ('투자 성향', s.riskLevel == '안전' ? '안정형' : s.riskLevel == '보통' ? '중립형' : '공격형'),
          ('검증 기간', s.period),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB74D).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFFFB74D).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚠️  투자 기간 유의',
                  style: TextStyle(
                      color: Color(0xFFFFB74D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...['종목·전략마다 검증 시작일이 다르므로 타 전략과 기간을 단순 비교할 수 없습니다.',
                  '과거 성과는 미래를 보장하지 않습니다.']
                  .map((t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                            Expanded(
                              child: Text(t,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ),
                          ],
                        ),
                      )),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('🎯  전략 핵심 개념',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...s.keyPoints.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.value,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Tab: 과거 성과 ─────────────────────────────────────────────────────────────

class _HistoricalTab extends StatelessWidget {
  final ExpertStrategy strategy;
  const _HistoricalTab({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final s = strategy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('투자 성과 요약 (${s.period})',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _PerformanceTable(strategy: s),
        const SizedBox(height: 12),
        Text(
          '같은 기간 ${s.tickerName} 단순 보유는 연평균 ${s.marketReturn}·최대손실률 '
          '${s.marketMDD.toStringAsFixed(1)}% 구간이었으나, 전략은 승률 '
          '${s.winRate.toStringAsFixed(1)}%·Sharpe ${s.sharpe.toStringAsFixed(2)}의 과거 사례입니다.',
          style: const TextStyle(
              color: Colors.white60, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text('📊  리스크 조정 수익률',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _TableCard(rows: [
          ('Sharpe 비율', '${s.sharpe.toStringAsFixed(2)}  vs  시장 0.21'),
        ]),
        const SizedBox(height: 24),
        const Text('💬  투자자를 위한 핵심 코멘트',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...[
          'CAGR 약 ${s.cagr.toStringAsFixed(1)}%, 누적수익률 약 ${s.cumulativeReturn.toStringAsFixed(0)}%, 동기간 단순 보유 ${s.marketReturn}',
          'MDD 약 ${s.maxDrawdown.toStringAsFixed(1)}%, 시장 MDD 약 ${s.marketMDD.toStringAsFixed(1)}%',
          '승률 약 ${s.winRate.toStringAsFixed(1)}%, Sharpe ${s.sharpe.toStringAsFixed(2)} — 검증 구간 결과',
        ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style:
                          TextStyle(color: AppColors.green, fontSize: 14)),
                  Expanded(
                    child: Text(t,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5)),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 24),
        const Text('💰  투자 정보',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _TableCard(rows: [
          ('투자 성향', s.riskLevel == '안전' ? '안정형' : s.riskLevel == '보통' ? '중립형' : '공격형'),
          ('평균 보유 일수', '약 ${s.avgHoldingDays}일'),
          ('일평균 거래(체결)', '약 ${s.dailyTrades}회'),
          ('승률', '${s.winRate.toStringAsFixed(1)}%'),
        ]),
        const SizedBox(height: 24),
        _LegalDisclaimer(),
      ],
    );
  }
}

// ── Reusable sub-widgets ───────────────────────────────────────────────────────

class _TickerChip extends StatelessWidget {
  final String ticker;
  final Color color;
  const _TickerChip({required this.ticker, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.currency_exchange, color: color, size: 12),
          const SizedBox(width: 4),
          Text(ticker,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String level;
  final bool small;
  const _RiskBadge({required this.level, this.small = false});

  Color get _color {
    switch (level) {
      case '안전': return const Color(0xFF26A69A);
      case '위험': return AppColors.red;
      default: return const Color(0xFFFFB74D);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 10.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(level,
          style: TextStyle(
              color: _color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _CompareCard extends StatelessWidget {
  final String title;
  final String returnStr;
  final bool returnPositive;
  final double mdd;
  final String riskBadge;
  const _CompareCard({
    required this.title,
    required this.returnStr,
    required this.returnPositive,
    required this.mdd,
    required this.riskBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: AppColors.gray, fontSize: 12)),
          const Divider(color: Colors.white12, height: 16),
          const Text('수익률은',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 2),
          Text(returnStr,
              style: TextStyle(
                  color: returnPositive ? AppColors.green : AppColors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('최대손실률은',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text('${mdd.toStringAsFixed(2)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              _RiskBadge(level: riskBadge, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.gray, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  final List<(String, String)> rows;
  const _TableCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.value.$1,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 13)),
                    ),
                    Text(e.value.$2,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (!isLast) const Divider(color: Colors.white10, height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  final String emoji;
  final String title;
  final List<String> items;
  final Color color;
  const _BulletSection({
    required this.emoji,
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('$emoji  ', style: const TextStyle(fontSize: 15)),
          Text(title,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        ...items.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style: TextStyle(color: color, fontSize: 14)),
                  Expanded(
                    child: Text(t,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5)),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _PerformanceTable extends StatelessWidget {
  final ExpertStrategy strategy;
  const _PerformanceTable({required this.strategy});

  @override
  Widget build(BuildContext context) {
    final s = strategy;
    final rows = [
      ('누적수익률', '${s.cumulativeReturn.toStringAsFixed(0)}%',
          s.marketReturn),
      ('CAGR (연평균)', '${s.cagr.toStringAsFixed(1)}%', '-'),
      ('최대낙폭 (MDD)', '${s.maxDrawdown.toStringAsFixed(1)}%',
          '${s.marketMDD.toStringAsFixed(1)}%'),
      ('승률', '${s.winRate.toStringAsFixed(1)}%', '—'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: const [
                Expanded(
                    child: Text('지표',
                        style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 80,
                    child: Text('전략',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                SizedBox(
                    width: 80,
                    child: Text('시장',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.gray,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            final row = e.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(row.$1,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                      SizedBox(
                          width: 80,
                          child: Text(row.$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))),
                      SizedBox(
                          width: 80,
                          child: Text(row.$3,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.red, fontSize: 13))),
                    ],
                  ),
                ),
                if (!isLast)
                  const Divider(color: Colors.white10, height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _LegalDisclaimer extends StatelessWidget {
  const _LegalDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚖️  법적 고지',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.warning_amber,
                      color: Color(0xFFFFB74D), size: 15),
                  SizedBox(width: 6),
                  Text('투자 위험 고지',
                      style: TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 8),
                ...['과거 성과 ≠ 미래 수익 보장',
                    '최대 손실 가능성: 원금 전액',
                    '투자 전 충분한 이해와 리스크 감수 능력 확인 필수',
                    '본 서비스는 투자 자문이 아닌 알고리즘 제공입니다.']
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('•  ',
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12)),
                              Expanded(
                                child: Text(t,
                                    style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtVolume(double v) {
  if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(1)}조원';
  if (v >= 1e8) return '${(v / 1e8).toStringAsFixed(0)}억원';
  return '${(v / 1e4).toStringAsFixed(0)}만원';
}
