import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/balance_provider.dart';
import '../../models/balance.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BalanceProvider>().fetchBalance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Consumer<BalanceProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: provider.fetchBalance,
              color: AppColors.green,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('잔고',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: provider.fetchBalance,
                              child: const Icon(Icons.refresh, color: AppColors.gray, size: 22),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                  ),
                  if (provider.loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppColors.green)),
                    )
                  else if (provider.error != null)
                    SliverFillRemaining(
                      child: _ErrorView(
                          message: provider.error!, onRetry: provider.fetchBalance),
                    )
                  else if (provider.balance == null)
                    const SliverFillRemaining(
                      child: Center(
                          child: Text('데이터 없음', style: TextStyle(color: AppColors.gray))),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _buildContent(provider.balance!),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(BalanceData balance) {
    return [
      _TotalCard(balance: balance),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _StatCard(label: '주식 평가금액', value: '${_fmt(balance.totalEvalAmount)}원')),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: '예수금', value: '${_fmt(balance.cashBalance)}원')),
        ],
      ),
      const SizedBox(height: 24),
      const Text('보유 종목',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      if (balance.holdings.isEmpty)
        Container(
          height: 80,
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
          child: const Center(
              child: Text('보유 종목 없음', style: TextStyle(color: AppColors.gray))),
        )
      else
        ...balance.holdings.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HoldingCard(holding: h),
            )),
    ];
  }
}

class _TotalCard extends StatelessWidget {
  final BalanceData balance;
  const _TotalCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isProfit = !balance.totalProfitLoss.startsWith('-');
    final profitColor = isProfit ? AppColors.green : AppColors.red;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('총 자산', style: TextStyle(color: AppColors.gray, fontSize: 12)),
          const SizedBox(height: 6),
          Text('${_fmt(balance.totalEvalAmount)}원',
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '${isProfit ? '+' : ''}${_fmt(balance.totalProfitLoss)}원 (${balance.totalProfitRate}%) 평가손익',
            style: TextStyle(color: profitColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HoldingCard extends StatelessWidget {
  final Holding holding;
  const _HoldingCard({required this.holding});

  @override
  Widget build(BuildContext context) {
    final profitColor = holding.isProfit ? AppColors.green : AppColors.red;
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(holding.name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${holding.quantity}주 · 평균 ${_fmt(holding.avgPrice)}원',
                    style: const TextStyle(color: AppColors.gray, fontSize: 11)),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fmt(holding.evalAmount)}원',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                '${holding.isProfit ? '+' : ''}${_fmt(holding.profitLoss)}원',
                style: TextStyle(color: profitColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.red),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.gray)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green, foregroundColor: AppColors.bg),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

String _fmt(String value) {
  final clean = value.replaceAll(',', '').replaceAll('-', '').trim();
  final n = int.tryParse(clean);
  if (n == null) return value;
  final prefix = value.startsWith('-') ? '-' : '';
  return '$prefix${n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  )}';
}
