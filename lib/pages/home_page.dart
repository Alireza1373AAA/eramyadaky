import 'package:flutter/material.dart';
import '../data/woocommerce_api.dart';
import '../widgets/product_card.dart';
import 'product_detail.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api = WooApi();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _items = [];

  bool _loading = false;
  bool _hasMore = true;
  bool _showOnlyInStock = false;
  int _page = 1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_maybeMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool _isOut(Map<String, dynamic> p) {
    final stock = (p['stock_status'] ?? '').toString().toLowerCase();
    return stock == 'outofstock' || p['is_in_stock'] == false;
  }

  List<Map<String, dynamic>> _visibleItems() {
    final list = List<Map<String, dynamic>>.from(_items);

    list.sort((a, b) {
      final ao = _isOut(a);
      final bo = _isOut(b);
      if (ao == bo) return 0;
      return ao ? 1 : -1;
    });

    return _showOnlyInStock
        ? list.where((e) => !_isOut(e)).toList()
        : list;
  }

  void _maybeMore() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >
            _scroll.position.maxScrollExtent - 300) {
      _load();
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;

    if (refresh) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      if (mounted) setState(() {});
    }

    if (!_hasMore) return;

    setState(() => _loading = true);

    try {
      final data = await api.products(
        page: _page,
        per: 12,
        search: _search.isEmpty ? null : _search,
      );

      if (data.isEmpty) {
        _hasMore = false;
      } else {
        _page++;
        _items.addAll(data);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eram Yadak'), // 🔥 بدون Image (safe)
        actions: [
          IconButton(
            onPressed: () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'جستجو',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (v) {
                _search = v;
                _load(refresh: true);
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Row(
            children: [
              const Text("فقط موجودها"),
              Switch(
                value: _showOnlyInStock,
                onChanged: (v) =>
                    setState(() => _showOnlyInStock = v),
              )
            ],
          ),
          Expanded(
            child: GridView.builder(
              itemCount: items.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemBuilder: (c, i) {
                final p = items[i];
                final out = _isOut(p);

                return Stack(
                  children: [
                    ProductCard(
                      p: p,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetail(product: p),
                        ),
                      ),
                      onCartUpdated: () {},
                    ),

                    if (out)
                      Positioned.fill(
                        child: Container(
                          color: const Color(0x8C000000),
                          child: const Center(
                            child: Text(
                              "عدم موجودی",
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
