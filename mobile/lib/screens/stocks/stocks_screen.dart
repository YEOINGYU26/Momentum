import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});

  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  final _searchCtrl = TextEditingController();

  final _watchlist = const [
    _StockItem(name: '삼성전자',   code: '005930', price: '73,200',    change: '+1.80%', up: true),
    _StockItem(name: 'SK하이닉스', code: '000660', price: '186,500',   change: '-0.53%', up: false),
    _StockItem(name: 'AAPL',       code: 'NASDAQ', price: '\$178.50',  change: '+0.34%', up: true),
    _StockItem(name: 'TSLA',       code: 'NASDAQ', price: '\$248.20',  change: '+3.21%', up: true),
    _StockItem(name: 'BTC/KRW',    code: 'Upbit',  price: '94,200,000', change: '-1.12%', up: false),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('종목',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildSearchBar(),
              const SizedBox(height: 20),
              const Text('즐겨찾기',
                  style: TextStyle(color: AppColors.gray, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: _watchlist.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _StockCard(item: _watchlist[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
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
                hintText: '종목 검색...',
                hintStyle: TextStyle(color: AppColors.gray),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockItem {
  final String name, code, price, change;
  final bool up;
  const _StockItem({
    required this.name,
    required this.code,
    required this.price,
    required this.change,
    required this.up,
  });
}

class _StockCard extends StatelessWidget {
  final _StockItem item;
  const _StockCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final changeColor = item.up ? AppColors.green : AppColors.red;
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.code, style: const TextStyle(color: AppColors.gray, fontSize: 11)),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.price,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(item.change,
                  style: TextStyle(color: changeColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
