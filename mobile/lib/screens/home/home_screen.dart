import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/price_provider.dart';
import '../../providers/auth_provider.dart' as app_auth;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();

  void _search(PriceProvider provider) {
    final ticker = _controller.text.trim().toUpperCase();
    if (ticker.isEmpty) return;
    provider.connectWs(ticker);
    provider.fetchPrice(ticker);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('실시간 시세'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () =>
                context.read<app_auth.AuthProvider>().signOut(),
          ),
        ],
      ),
      body: Consumer<PriceProvider>(
        builder: (context, provider, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchBar(controller: _controller, onSearch: () => _search(provider)),
                const SizedBox(height: 24),
                if (provider.loading)
                  const Center(child: CircularProgressIndicator())
                else if (provider.error != null)
                  _ErrorCard(message: provider.error!)
                else if (provider.price != null)
                  _PriceCard(provider: provider)
                else
                  const _EmptyState(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '종목 코드 입력 (예: 005930)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => onSearch(),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onSearch,
          child: const Text('조회'),
        ),
      ],
    );
  }
}

class _PriceCard extends StatelessWidget {
  final PriceProvider provider;
  const _PriceCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider.price!;
    final color = p.isUp ? Colors.red : Colors.blue;
    final sign = p.isUp ? '+' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(p.ticker, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                _WsStatusChip(connected: provider.isConnected),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${_fmt(p.price)}원',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              '$sign${_fmt(p.change)}원  ($sign${p.changeRate}%)',
              style: TextStyle(fontSize: 16, color: color),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Text('거래량', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 8),
                Text(_fmt(p.volume)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String value) {
    final n = int.tryParse(value.replaceAll(',', '').replaceAll('-', '').trim());
    if (n == null) return value;
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _WsStatusChip extends StatelessWidget {
  final bool connected;
  const _WsStatusChip({required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: connected ? Colors.green.withValues(alpha:0.2) : Colors.grey.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: connected ? Colors.green : Colors.grey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: connected ? Colors.green : Colors.grey),
          const SizedBox(width: 4),
          Text(connected ? 'LIVE' : 'OFF', style: TextStyle(fontSize: 12, color: connected ? Colors.green : Colors.grey)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.withValues(alpha:0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          SizedBox(height: 60),
          Icon(Icons.search, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('종목 코드를 입력해 실시간 시세를 조회하세요', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
