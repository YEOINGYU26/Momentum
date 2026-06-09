import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildPortfolioCard(),
              const SizedBox(height: 24),
              _SectionHeader(title: "활성 전략", badge: "3개 실행 중", badgeColor: AppColors.green),
              const SizedBox(height: 12),
              const _StrategyCard(name: 'RSI 전략',      ticker: '삼성전자', signal: 'BUY',  color: AppColors.green),
              const SizedBox(height: 10),
              const _StrategyCard(name: 'MA 골든크로스', ticker: 'AAPL',    signal: 'HOLD', color: AppColors.yellow),
              const SizedBox(height: 10),
              const _StrategyCard(name: '볼린저 밴드',   ticker: 'BTC',     signal: 'SELL', color: AppColors.red),
              const SizedBox(height: 24),
              const _SectionHeader(title: "최근 알림"),
              const SizedBox(height: 12),
              const _AlertCard(icon: '📈', message: '삼성전자 RSI 28.4 — 매수 신호', time: '09:15'),
              const SizedBox(height: 10),
              const _AlertCard(icon: '🔔', message: 'AAPL \$178.50 목표가 도달', time: '14:32'),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('안녕하세요 👋',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('오늘도 성공적인 매매 되세요',
            style: TextStyle(color: AppColors.gray, fontSize: 13)),
      ],
    );
  }

  Widget _buildPortfolioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('총 평가금액', style: TextStyle(color: AppColors.gray, fontSize: 12)),
          const SizedBox(height: 6),
          const Text('₩ 12,480,000',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('+₩ 248,000  +2.03%',
                    style: TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('예수금', style: TextStyle(color: AppColors.gray, fontSize: 11)),
                  SizedBox(height: 2),
                  Text('₩ 4,520,000',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  final Color? badgeColor;
  const _SectionHeader({required this.title, this.badge, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        if (badge != null)
          Text(badge!, style: TextStyle(color: badgeColor ?? AppColors.gray, fontSize: 12)),
      ],
    );
  }
}

class _StrategyCard extends StatelessWidget {
  final String name, ticker, signal;
  final Color color;
  const _StrategyCard({
    required this.name,
    required this.ticker,
    required this.signal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(2)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(ticker, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(signal,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String icon, message, time;
  const _AlertCard({required this.icon, required this.message, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          Text(time, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
        ],
      ),
    );
  }
}
