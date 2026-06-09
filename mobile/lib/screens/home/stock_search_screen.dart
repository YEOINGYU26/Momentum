import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/market_data_service.dart';

class StockSearchScreen extends StatefulWidget {
  final List<String> alreadyAdded;
  final void Function(SymbolInfo) onAdd;
  final void Function(String) onRemove;

  const StockSearchScreen({
    super.key,
    required this.alreadyAdded,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends State<StockSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  String _category = '전체';

  static const _categories = ['전체', '주식', '지수', '암호화폐', '외환'];

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<SymbolInfo> get _results => SymbolDatabase.search(_query, _category);

  bool _isAdded(String ticker) => widget.alreadyAdded.contains(ticker);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildCategoryBar(),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.gray, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: '종목, 심볼 검색...',
                        hintStyle: TextStyle(color: AppColors.gray),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() => _query = '');
                      },
                      child: const Icon(Icons.close, color: AppColors.gray, size: 16),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('닫기',
                style: TextStyle(color: AppColors.green, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = _category == cat;
          return GestureDetector(
            onTap: () => setState(() => _category = cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.green : AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(cat,
                  style: TextStyle(
                    color: selected ? AppColors.bg : AppColors.gray,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResults() {
    final results = _results;
    if (results.isEmpty) {
      return const Center(
        child: Text('검색 결과가 없습니다', style: TextStyle(color: AppColors.gray)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(
          height: 1, color: Color(0xFF252A34), indent: 72, endIndent: 16),
      itemBuilder: (_, i) {
        final s = results[i];
        final added = _isAdded(s.ticker);
        return _SearchResultTile(
          symbol: s,
          isAdded: added,
          onToggle: () {
            if (added) {
              widget.onRemove(s.ticker);
            } else {
              widget.onAdd(s);
            }
            setState(() {});
          },
        );
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SymbolInfo symbol;
  final bool isAdded;
  final VoidCallback onToggle;
  const _SearchResultTile({
    required this.symbol,
    required this.isAdded,
    required this.onToggle,
  });

  static const _avatarColors = [
    Color(0xFF1565C0), Color(0xFFE65100), Color(0xFFC62828),
    Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFF00695C),
    Color(0xFF37474F), Color(0xFF558B2F), Color(0xFFAD1457),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[symbol.ticker.hashCode.abs() % _avatarColors.length];
    final label = symbol.ticker.length > 4 ? symbol.ticker.substring(0, 4) : symbol.ticker;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            // Name + sub
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(symbol.ticker,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(symbol.sub,
                      style: const TextStyle(color: AppColors.gray, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Exchange + category
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(symbol.exchange,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(symbol.category,
                    style: const TextStyle(color: AppColors.gray, fontSize: 11)),
              ],
            ),
            const SizedBox(width: 12),
            // Add/check button
            GestureDetector(
              onTap: onToggle,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isAdded
                      ? AppColors.green.withValues(alpha: 0.15)
                      : AppColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isAdded ? AppColors.green : AppColors.gray.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  isAdded ? Icons.check : Icons.add,
                  size: 16,
                  color: isAdded ? AppColors.green : AppColors.gray,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
