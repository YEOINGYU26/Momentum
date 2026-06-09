import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_colors.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: PageView(
        controller: _ctrl,
        onPageChanged: (i) => setState(() => _page = i),
        children: [
          _Page1(page: _page, onSkip: _finish, onNext: _next),
          _Page2(page: _page, onSkip: _finish, onNext: _next),
          _Page3(page: _page, onSkip: _finish, onStart: _finish),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 56,
      right: 24,
      child: GestureDetector(
        onTap: onTap,
        child: const Text(
          '건너뛰기',
          style: TextStyle(color: AppColors.gray, fontSize: 14),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int current;
  const _DotsIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.green
                : AppColors.gray.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: AppColors.bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─── Page 1 — 실시간 시세 모니터링 ──────────────────────────────────────────────

class _Page1 extends StatelessWidget {
  final int page;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  const _Page1({required this.page, required this.onSkip, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _SkipButton(onTap: onSkip),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 100),
                // Chart illustration
                _ChartIllustration(),
                const SizedBox(height: 32),
                // Ticker chips
                Row(
                  children: ['005930', 'AAPL', 'BTC'].map((t) => _TickerChip(t)).toList(),
                ),
                const SizedBox(height: 28),
                const Text(
                  '실시간 시세 모니터링',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'KIS WebSocket으로 체결가를 실시간 수신\n주요 종목의 호가 변동을 즉시 파악하세요',
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                _DotsIndicator(current: page),
                const SizedBox(height: 24),
                _PrimaryButton(label: '다음', onTap: onNext),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TickerChip extends StatelessWidget {
  final String label;
  const _TickerChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.green,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChartIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const bars = [0.72, 0.55, 0.88, 0.45, 0.66, 0.38, 0.80, 0.52];
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          // Price tag
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '▲ +2.34%',
                style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Bar chart
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.asMap().entries.map((e) {
                final isGreen = e.key % 3 != 2;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isGreen
                          ? AppColors.green.withValues(alpha: 0.7)
                          : AppColors.red.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                    height: e.value * 80,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 2 — 자동 전략 실행 ────────────────────────────────────────────────────

class _Page2 extends StatelessWidget {
  final int page;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  const _Page2({required this.page, required this.onSkip, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _SkipButton(onTap: onSkip),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '⚡ 3가지 전략 지원',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _StrategyCard(
                  accentColor: AppColors.green,
                  title: 'RSI 전략',
                  subtitle: '과매도 구간 자동 매수',
                  badge: 'BUY',
                  badgeColor: AppColors.green,
                ),
                const SizedBox(height: 10),
                _StrategyCard(
                  accentColor: AppColors.yellow,
                  title: 'MA 골든크로스',
                  subtitle: '이동평균 교차 감지',
                  badge: 'HOLD',
                  badgeColor: AppColors.yellow,
                ),
                const SizedBox(height: 10),
                _StrategyCard(
                  accentColor: AppColors.red,
                  title: '볼린저 밴드',
                  subtitle: '스캘핑 자동 실행',
                  badge: 'SELL',
                  badgeColor: AppColors.red,
                ),
                const SizedBox(height: 28),
                const Text(
                  '자동 전략 실행',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'RSI · 이동평균 · 볼린저 밴드\nAPScheduler로 24시간 자동 실행됩니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                _DotsIndicator(current: page),
                const SizedBox(height: 24),
                _PrimaryButton(label: '다음', onTap: onNext),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrategyCard extends StatelessWidget {
  final Color accentColor;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;

  const _StrategyCard({
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.gray, fontSize: 12)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 3 — 실시간 알림 ────────────────────────────────────────────────────────

class _Page3 extends StatelessWidget {
  final int page;
  final VoidCallback onSkip;
  final VoidCallback onStart;
  const _Page3({required this.page, required this.onSkip, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _SkipButton(onTap: onSkip),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 100),
                _NotificationCard(
                  emoji: '📈',
                  title: '매수 신호 감지',
                  subtitle: '삼성전자(005930) RSI 28.4',
                  time: '09:15',
                ),
                const SizedBox(height: 10),
                _NotificationCard(
                  emoji: '🔔',
                  title: '지정가 도달',
                  subtitle: 'AAPL \$178.50 목표가 달성',
                  time: '14:32',
                ),
                const SizedBox(height: 10),
                _NotificationCard(
                  emoji: '⚠️',
                  title: '전략 오류 알림',
                  subtitle: '잔고 부족으로 주문 실패',
                  time: '16:07',
                ),
                const SizedBox(height: 28),
                const Text(
                  '실시간 알림',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '매수·매도 신호, 지정가 도달, 오류 발생 시\n즉시 알림을 받으세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.gray,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                _DotsIndicator(current: page),
                const SizedBox(height: 24),
                _PrimaryButton(label: '시작하기', onTap: onStart),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onStart,
                  child: const Text(
                    '이미 계정이 있어요',
                    style: TextStyle(color: AppColors.gray, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String time;

  const _NotificationCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.gray, fontSize: 11)),
              ],
            ),
          ),
          Text(time,
              style: const TextStyle(color: AppColors.gray, fontSize: 11)),
        ],
      ),
    );
  }
}
