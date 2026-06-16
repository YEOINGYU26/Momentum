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
  static const _sectionOrder = ['주식', '암호화폐', '해외주식', '기타'];

  final Map<String, List<_WItem>> _sections = {
    '주식': [
      _WItem(id: '1', section: '주식', ticker: '005930', name: '삼성전자',   sub: 'Samsung Electronics', price: '-', change: '-', pct: '-', up: true),
      _WItem(id: '2', section: '주식', ticker: '000660', name: 'SK하이닉스', sub: 'SK Hynix Inc',         price: '-', change: '-', pct: '-', up: true),
      _WItem(id: '3', section: '주식', ticker: '035420', name: '네이버',     sub: 'NAVER Corp',           price: '-', change: '-', pct: '-', up: true),
      _WItem(id: '4', section: '주식', ticker: '035720', name: '카카오',     sub: 'Kakao Corp',           price: '-', change: '-', pct: '-', up: true),
      _WItem(id: '5', section: '주식', ticker: '005380', name: '현대차',     sub: 'Hyundai Motor',        price: '-', change: '-', pct: '-', up: true),
      _WItem(id: '6', section: '주식', ticker: '051910', name: 'LG화학',     sub: 'LG Chem',              price: '-', change: '-', pct: '-', up: true),
    ],
    '암호화폐': [
      _WItem(id: '7',  section: '암호화폐', ticker: 'BTC', name: 'Bitcoin',  sub: 'Bitcoin / KRW',  price: '-', change: '-', pct: '-', up: true),
      _WItem(id: '8',  section: '암호화폐', ticker: 'ETH', name: 'Ethereum', sub: 'Ethereum / KRW', price: '-', change: '-', pct: '-', up: true),
    ],
  };

  bool _refreshing = false;

  Iterable<_WItem> get _allItems =>
      _sectionOrder.expand((s) => _sections[s] ?? []);

  List<String> get _activeSections =>
      _sectionOrder.where((s) => (_sections[s] ?? []).isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _refreshPrices();
  }

  Future<void> _refreshPrices() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    final futures = _allItems.map((item) async {
      final res = await MarketDataService.fetchPrice(item.ticker);
      if (res == null) return item;
      return item.copyWith(price: res.price, change: res.change, pct: res.pct, up: res.isUp);
    });
    final updated = await Future.wait(futures);

    if (!mounted) return;
    setState(() {
      int idx = 0;
      for (final section in _sectionOrder) {
        final list = _sections[section];
        if (list == null) continue;
        for (int i = 0; i < list.length; i++) {
          list[i] = updated[idx++];
        }
      }
      _refreshing = false;
    });
  }

  void _remove(String section, String id) {
    setState(() => _sections[section]?.removeWhere((e) => e.id == id));
  }

  void _reorderSection(String section, int oldIndex, int newIndex) {
    setState(() {
      final list = _sections[section]!;
      list.insert(newIndex, list.removeAt(oldIndex));
    });
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => StockSearchScreen(
          alreadyAdded: _allItems.map((e) => e.ticker).toList(),
          onGoToChart: widget.onGoToChart,
          onAdd: (symbol) {
            final section = _sections.containsKey(symbol.category)
                ? symbol.category
                : '기타';
            setState(() {
              _sections.putIfAbsent(section, () => []);
              _sections[section]!.add(_WItem.fromSymbol(symbol));
            });
            MarketDataService.fetchPrice(symbol.ticker).then((res) {
              if (!mounted || res == null) return;
              setState(() {
                final list = _sections[section];
                if (list == null) return;
                final i = list.indexWhere((e) => e.ticker == symbol.ticker);
                if (i >= 0) {
                  list[i] = list[i].copyWith(
                    price: res.price, change: res.change, pct: res.pct, up: res.isUp);
                }
              });
            });
          },
          onRemove: (ticker) {
            setState(() {
              for (final list in _sections.values) {
                list.removeWhere((e) => e.ticker == ticker);
              }
            });
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
    final hasItems = _activeSections.isNotEmpty;
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
                child: hasItems ? _buildList() : _buildEmpty(),
              ),
            ),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        for (final section in _activeSections) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(section,
                  style: const TextStyle(
                      color: AppColors.gray,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),
          ),
          SliverReorderableList(
            itemCount: _sections[section]!.length,
            proxyDecorator: (child, _, __) =>
                Material(color: Colors.transparent, child: child),
            onReorderItem: (old, neu) => _reorderSection(section, old, neu),
            itemBuilder: (_, i) {
              final item = _sections[section]![i];
              return _WatchRow(
                key: ValueKey(item.id),
                item: item,
                index: i,
                onRemove: () => _remove(section, item.id),
                onTap: () => _openMiniChart(item),
              );
            },
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
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
              width: 18, height: 18,
              child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2),
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
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _WatchRow({
    super.key,
    required this.item,
    required this.index,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slidable(
          key: ValueKey('slide_${item.id}'),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.52,
            children: [
              SlidableAction(
                onPressed: (_) => _showAlertDialog(context),
                backgroundColor: AppColors.yellow,
                foregroundColor: Colors.white,
                icon: Icons.notifications_outlined,
                label: '알림',
              ),
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
        const Divider(height: 1, color: Color(0xFF252A34), indent: 72, endIndent: 16),
      ],
    );
  }

  void _showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('${item.name} 알림',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
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
              width: 42, height: 42,
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
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(width: 8),
            // Drag handle (section-scoped)
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
