import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<_WItem> _items = [
    _WItem(id: '1', section: '주가지수', ticker: 'KOSPI',  name: 'KOSPI',    sub: '코스피',               price: '2,650.50',    change: '+12.34',   pct: '+0.47%', up: true),
    _WItem(id: '2', section: '주가지수', ticker: 'KOSDAQ', name: 'KOSDAQ',   sub: '코스닥',               price: '870.20',      change: '-5.80',    pct: '-0.66%', up: false),
    _WItem(id: '3', section: '주가지수', ticker: 'SPX',    name: 'S&P 500',  sub: 'S&P 500 Index',        price: '5,308.15',    change: '+21.99',   pct: '+0.42%', up: true),
    _WItem(id: '4', section: '가상화폐', ticker: 'BTC',    name: 'BTCKRW',   sub: 'Bitcoin / KRW',        price: '94,200,000',  change: '-936,000', pct: '-0.99%', up: false),
    _WItem(id: '5', section: '가상화폐', ticker: 'ETH',    name: 'ETHKRW',   sub: 'Ethereum / KRW',       price: '5,120,000',   change: '+85,000',  pct: '+1.69%', up: true),
    _WItem(id: '6', section: '주식',    ticker: '005930', name: '삼성전자',  sub: 'Samsung Electronics',  price: '73,200',      change: '+1,300',   pct: '+1.81%', up: true),
    _WItem(id: '7', section: '주식',    ticker: 'AAPL',   name: 'AAPL',     sub: 'Apple Inc.',            price: '\$178.50',    change: '+0.62',    pct: '+0.35%', up: true),
    _WItem(id: '8', section: '주식',    ticker: 'TSLA',   name: 'TSLA',     sub: 'Tesla Inc.',            price: '\$248.20',    change: '+7.80',    pct: '+3.25%', up: true),
  ];

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      _items.insert(newIndex, _items.removeAt(oldIndex));
    });
  }

  void _remove(String id) {
    setState(() => _items.removeWhere((e) => e.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _items.isEmpty
                  ? _buildEmpty()
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      onReorder: _reorder,
                      itemCount: _items.length,
                      proxyDecorator: (child, index, animation) => Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        final showSection =
                            i == 0 || _items[i - 1].section != item.section;
                        return _WatchRow(
                          key: ValueKey(item.id),
                          item: item,
                          index: i,
                          showSection: showSection,
                          onRemove: () => _remove(item.id),
                        );
                      },
                    ),
            ),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          const Text('왓치리스트',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _showAddSheet,
      child: Container(
        width: double.infinity,
        height: 52,
        color: AppColors.bg,
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.green, size: 20),
              SizedBox(width: 8),
              Text('즐겨찾기 추가',
                  style: TextStyle(
                      color: AppColors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline, size: 56, color: AppColors.gray),
          SizedBox(height: 12),
          Text('왓치리스트가 비어있습니다',
              style: TextStyle(color: AppColors.gray, fontSize: 15)),
          SizedBox(height: 4),
          Text('하단 버튼으로 종목을 추가하세요',
              style: TextStyle(color: AppColors.gray, fontSize: 12)),
        ],
      ),
    );
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddSheet(
        onAdd: (item) => setState(() => _items.add(item)),
      ),
    );
  }
}

// ─── Data model ──────────────────────────────────────────────────────────────

class _WItem {
  final String id, section, ticker, name, sub, price, change, pct;
  final bool up;
  const _WItem({
    required this.id,
    required this.section,
    required this.ticker,
    required this.name,
    required this.sub,
    required this.price,
    required this.change,
    required this.pct,
    required this.up,
  });
}

// ─── Watch row (section header + dismissible item) ───────────────────────────

class _WatchRow extends StatelessWidget {
  final _WItem item;
  final int index;
  final bool showSection;
  final VoidCallback onRemove;

  const _WatchRow({
    super.key,
    required this.item,
    required this.index,
    required this.showSection,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSection)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(item.section,
                style: const TextStyle(
                    color: AppColors.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        Dismissible(
          key: ValueKey('dismiss_${item.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            color: AppColors.red,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ),
          onDismissed: (_) => onRemove(),
          child: _ItemTile(item: item, index: index),
        ),
        const Divider(height: 1, color: Color(0xFF252A34), indent: 20, endIndent: 20),
      ],
    );
  }
}

// ─── Item tile ───────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final _WItem item;
  final int index;
  const _ItemTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final changeColor = item.up ? AppColors.green : AppColors.red;

    return Container(
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // Avatar circle
          _AvatarCircle(ticker: item.ticker),
          const SizedBox(width: 14),
          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.sub,
                    style: const TextStyle(color: AppColors.gray, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Price + change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(item.price,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${item.change}  ${item.pct}',
                  style: TextStyle(
                      color: changeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(width: 8),
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: AppColors.gray, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar circle ────────────────────────────────────────────────────────────

class _AvatarCircle extends StatelessWidget {
  final String ticker;
  const _AvatarCircle({required this.ticker});

  static const _colors = [
    Color(0xFF1565C0), // blue
    Color(0xFFE65100), // orange
    Color(0xFFC62828), // red
    Color(0xFF2E7D32), // green
    Color(0xFF6A1B9A), // purple
    Color(0xFF00695C), // teal
    Color(0xFF37474F), // blue-grey
    Color(0xFF558B2F), // light green
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[ticker.hashCode.abs() % _colors.length];
    final label = ticker.length > 4 ? ticker.substring(0, 4) : ticker;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─── Add sheet ───────────────────────────────────────────────────────────────

class _AddSheet extends StatefulWidget {
  final void Function(_WItem) onAdd;
  const _AddSheet({required this.onAdd});

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _tickerCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _section = '주식';

  static const _sections = ['주가지수', '주식', '가상화폐', '외환'];

  @override
  void dispose() {
    _tickerCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final ticker = _tickerCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    if (ticker.isEmpty) return;
    widget.onAdd(_WItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      section: _section,
      ticker: ticker,
      name: name.isEmpty ? ticker : name,
      sub: _section,
      price: '-',
      change: '-',
      pct: '-',
      up: true,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('즐겨찾기 추가',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _tickerCtrl,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: '종목 코드 (예: 005930, AAPL)',
              labelStyle: TextStyle(color: AppColors.gray),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gray)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.green)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: '표시 이름 (선택)',
              labelStyle: TextStyle(color: AppColors.gray),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gray)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.green)),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _sections
                .map((s) => ChoiceChip(
                      label: Text(s),
                      selected: _section == s,
                      onSelected: (_) => setState(() => _section = s),
                      selectedColor: AppColors.green.withValues(alpha: 0.2),
                      backgroundColor: AppColors.bg,
                      labelStyle: TextStyle(
                        color: _section == s ? AppColors.green : AppColors.gray,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: _section == s ? AppColors.green : AppColors.gray.withValues(alpha: 0.3),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _add,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: AppColors.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
