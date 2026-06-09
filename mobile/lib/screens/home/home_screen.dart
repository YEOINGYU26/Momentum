import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/chart_provider.dart';
import '../../services/market_data_service.dart';
import 'stock_search_screen.dart';
import 'mini_chart_sheet.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onGoToChart;
  const HomeScreen({super.key, this.onGoToChart});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<_WItem> _items = [
    _WItem(id: '1', section: '주가지수', ticker: 'KOSPI',  name: 'KOSPI Composite', sub: '코스피',               price: '2,650.50',   change: '+12.34',    pct: '+0.47%', up: true),
    _WItem(id: '2', section: '주가지수', ticker: 'KOSDAQ', name: 'KOSDAQ',           sub: '코스닥',               price: '870.20',     change: '-5.80',     pct: '-0.66%', up: false),
    _WItem(id: '3', section: '주가지수', ticker: 'SPX',    name: 'S&P 500',          sub: 'S&P 500 Index',        price: '5,308.15',   change: '+21.99',    pct: '+0.42%', up: true),
    _WItem(id: '4', section: '가상화폐', ticker: 'BTC',    name: 'BTCKRW',           sub: 'Bitcoin / KRW',        price: '94,200,000', change: '-936,000',  pct: '-0.99%', up: false),
    _WItem(id: '5', section: '가상화폐', ticker: 'ETH',    name: 'ETHKRW',           sub: 'Ethereum / KRW',       price: '5,120,000',  change: '+85,000',   pct: '+1.69%', up: true),
    _WItem(id: '6', section: '주식',    ticker: '005930', name: '삼성전자',          sub: 'Samsung Electronics', price: '73,200',     change: '+1,300',    pct: '+1.81%', up: true),
    _WItem(id: '7', section: '주식',    ticker: 'AAPL',   name: 'Apple',             sub: 'Apple Inc.',           price: '\$178.50',   change: '+0.62',     pct: '+0.35%', up: true),
  ];

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshPrices();
  }

  Future<void> _refreshPrices() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final updated = await Future.wait(
      _items.map((item) async {
        final res = await MarketDataService.fetchPrice(item.ticker);
        if (res == null) return item;
        return item.copyWith(
          price: res.price, change: res.change, pct: res.pct, up: res.isUp);
      }),
    );
    if (mounted) setState(() { _items = updated; _refreshing = false; });
  }

  void _remove(String id) {
    setState(() => _items.removeWhere((e) => e.id == id));
  }

  void _reorder(int old, int neu) {
    setState(() {
      if (neu > old) neu--;
      _items.insert(neu, _items.removeAt(old));
    });
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StockSearchScreen(
          alreadyAdded: _items.map((e) => e.ticker).toList(),
          onAdd: (symbol) {
            setState(() => _items.add(_WItem.fromSymbol(symbol)));
          },
          onRemove: (ticker) {
            setState(() => _items.removeWhere((e) => e.ticker == ticker));
          },
        ),
      ),
    );
  }

  void _openMiniChart(_WItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<ChartProvider>(),
        child: MiniChartSheet(
          ticker: item.ticker,
          name: item.name,
          price: item.price,
          change: item.change,
          pct: item.pct,
          isUp: item.up,
          onGoToChart: widget.onGoToChart ?? () {},
        ),
      ),
    );
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
              child: RefreshIndicator(
                color: AppColors.green,
                onRefresh: _refreshPrices,
                child: _items.isEmpty
                    ? _buildEmpty()
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        padding: const EdgeInsets.only(bottom: 8),
                        onReorder: _reorder,
                        proxyDecorator: (child, _, __) =>
                            Material(color: Colors.transparent, child: child),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          final showSection = i == 0 ||
                              _items[i - 1].section != item.section;
                          return _WatchRow(
                            key: ValueKey(item.id),
                            item: item,
                            index: i,
                            showSection: showSection,
                            onRemove: () => _remove(item.id),
                            onTap: () => _openMiniChart(item),
                          );
                        },
                      ),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
      child: Row(
        children: [
          const Text('왓치리스트',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_refreshing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: AppColors.green, strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.gray, size: 20),
              onPressed: _refreshPrices,
            ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _openSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF252A34))),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.green, size: 18),
              SizedBox(width: 6),
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
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(Icons.star_outline, size: 56, color: AppColors.gray),
              SizedBox(height: 12),
              Text('왓치리스트가 비어있습니다',
                  style: TextStyle(color: AppColors.gray, fontSize: 15)),
              SizedBox(height: 4),
              Text('+ 버튼으로 종목을 추가하세요',
                  style: TextStyle(color: AppColors.gray, fontSize: 12)),
            ],
          ),
        ),
      ],
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

  factory _WItem.fromSymbol(SymbolInfo s) => _WItem(
        id: '${s.ticker}_${DateTime.now().millisecondsSinceEpoch}',
        section: s.category,
        ticker: s.ticker,
        name: s.name,
        sub: s.sub,
        price: '-',
        change: '-',
        pct: '-',
        up: true,
      );

  _WItem copyWith({String? price, String? change, String? pct, bool? up}) =>
      _WItem(
        id: id, section: section, ticker: ticker, name: name, sub: sub,
        price: price ?? this.price,
        change: change ?? this.change,
        pct: pct ?? this.pct,
        up: up ?? this.up,
      );
}

// ─── Watch row ────────────────────────────────────────────────────────────────

class _WatchRow extends StatelessWidget {
  final _WItem item;
  final int index;
  final bool showSection;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _WatchRow({
    super.key,
    required this.item,
    required this.index,
    required this.showSection,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSection)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Text(item.section,
                style: const TextStyle(
                    color: AppColors.gray,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
        Slidable(
          key: ValueKey('slide_${item.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.52,
            children: [
              // 알림
              SlidableAction(
                onPressed: (_) => _showAlertDialog(context),
                backgroundColor: AppColors.yellow,
                foregroundColor: Colors.white,
                icon: Icons.notifications_outlined,
                label: '알림',
              ),
              // 순서 변경 (drag handle hint)
              SlidableAction(
                onPressed: (_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('≡ 아이콘을 드래그해서 순서를 변경하세요'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF3A3F4B),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF3A3F4B),
                foregroundColor: Colors.white,
                icon: Icons.swap_vert,
                label: '순서',
              ),
              // 삭제
              SlidableAction(
                onPressed: (_) => onRemove(),
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete_outline,
                label: '삭제',
              ),
            ],
          ),
          child: _ItemTile(item: item, index: index, onTap: onTap),
        ),
        const Divider(
            height: 1, color: Color(0xFF252A34), indent: 72, endIndent: 16),
      ],
    );
  }

  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('${item.name} 알림', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('가격 알림 기능은 자동매매 탭에서 설정할 수 있습니다.',
            style: TextStyle(color: AppColors.gray, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: AppColors.green)),
          ),
        ],
      ),
    );
  }
}

// ─── Item tile ────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final _WItem item;
  final int index;
  final VoidCallback onTap;
  const _ItemTile({required this.item, required this.index, required this.onTap});

  static const _avatarColors = [
    Color(0xFF1565C0), Color(0xFFE65100), Color(0xFFC62828),
    Color(0xFF2E7D32), Color(0xFF6A1B9A), Color(0xFF00695C),
    Color(0xFF37474F), Color(0xFF558B2F), Color(0xFFAD1457),
  ];

  @override
  Widget build(BuildContext context) {
    final color = item.up ? AppColors.green : AppColors.red;
    final avatarColor = _avatarColors[item.ticker.hashCode.abs() % _avatarColors.length];
    final label = item.ticker.length > 4 ? item.ticker.substring(0, 4) : item.ticker;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: AppColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
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
                  Text(item.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${item.change}  ${item.pct}',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
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
      ),
    );
  }
}
