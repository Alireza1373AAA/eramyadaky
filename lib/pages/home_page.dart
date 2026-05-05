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
    _scroll.removeListener(_maybeMore);
    _scroll.dispose();
    super.dispose();
  }

  bool _isOut(Map<String, dynamic> p) {
    final stock = (p['stock_status'] ?? '').toString().toLowerCase();
    return stock == 'outofstock' || p['is_in_stock'] == false;
  }

  List<Map<String, dynamic>> _visibleItems() {
    final result = List<Map<String, dynamic>>.from(_items);

    result.sort((a, b) {
      final aOut = _isOut(a);
      final bOut = _isOut(b);
      if (aOut == bOut) return 0;
      return aOut ? 1 : -1;
    });

    return _showOnlyInStock
        ? result.where((p) => !_isOut(p)).toList()
        : result;
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
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28),
            const SizedBox(width: 8),
            const Text('Eram Yadak'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _load(refresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'جستجوی محصول',
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _search = v.trim();
                _load(refresh: true);
              },
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'جدیدترین محصولات',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  const Text('فقط موجودها'),
                  Switch(
                    value: _showOnlyInStock,
                    onChanged: (v) =>
                        setState(() => _showOnlyInStock = v),
                  ),
                ],
              ),
            ),

            /// 🔥 لیست محصولات
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.48,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length + (_loading ? 2 : 0),
              itemBuilder: (ctx, i) {
                if (i >= items.length) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

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

                    /// 🔥 لایه عدم موجودی (بدون خطای const)
                    if (out)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0x8C000000),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'عدم موجودی',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
