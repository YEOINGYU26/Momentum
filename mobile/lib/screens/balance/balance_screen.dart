import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      appBar: AppBar(
        title: const Text('잔고'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<BalanceProvider>().fetchBalance(),
          ),
        ],
      ),
      body: Consumer<BalanceProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return _ErrorView(message: provider.error!, onRetry: provider.fetchBalance);
          }
          if (provider.balance == null) {
            return const Center(child: Text('데이터 없음'));
          }
          return RefreshIndicator(
            onRefresh: provider.fetchBalance,
            child: _BalanceView(balance: provider.balance!),
          );
        },
      ),
    );
  }
}

class _BalanceView extends StatelessWidget {
  final BalanceData balance;
  const _BalanceView({required this.balance});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCard(balance: balance),
        const SizedBox(height: 16),
        const Text('보유 종목', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (balance.holdings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('보유 종목 없음', style: TextStyle(color: Colors.grey))),
            ),
          )
        else
          ...balance.holdings.map((h) => _HoldingTile(holding: h)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final BalanceData balance;
  const _SummaryCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isProfit = !balance.totalProfitLoss.startsWith('-');
    final profitColor = isProfit ? Colors.red : Colors.blue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('총 평가금액', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              '${_fmt(balance.totalEvalAmount)}원',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _Row(label: '매입금액', value: '${_fmt(balance.totalPurchaseAmount)}원'),
            _Row(
              label: '평가손익',
              value: '${_fmt(balance.totalProfitLoss)}원 (${balance.totalProfitRate}%)',
              valueColor: profitColor,
            ),
            _Row(label: '예수금', value: '${_fmt(balance.cashBalance)}원'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(color: valueColor)),
        ],
      ),
    );
  }
}

class _HoldingTile extends StatelessWidget {
  final Holding holding;
  const _HoldingTile({required this.holding});

  @override
  Widget build(BuildContext context) {
    final color = holding.isProfit ? Colors.red : Colors.blue;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${holding.name} (${holding.ticker})'),
        subtitle: Text('${holding.quantity}주 · 평균 ${_fmt(holding.avgPrice)}원'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${_fmt(holding.evalAmount)}원', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${holding.isProfit ? '+' : ''}${_fmt(holding.profitLoss)}원 (${holding.profitRate}%)',
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
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
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

String _fmt(String value) {
  final n = int.tryParse(value.replaceAll(',', '').replaceAll('-', '').trim());
  if (n == null) return value;
  final prefix = value.startsWith('-') ? '-' : '';
  return '$prefix${n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
