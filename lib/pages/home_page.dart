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
  final WooApi api = WooApi();

  final ScrollController _scroll = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _banners = [];

  bool _loading = false;
  bool _loadingHeader = true;
  bool _hasMore = true;
  bool _showOnlyInStock = false;

  int _page = 1;
  int? _selectedCategory;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scroll.addListener(_maybeMore);
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeMore);
    _scroll.dispose();
    super.dispose();
  }

  // ================= LOAD =================

  Future<void> _loadAll() async {
    try {
      await _loadProducts(refresh: true);
      await _loadCategories();
      await _loadBanners();
    } catch (_) {}

    if (mounted) setState(() => _loadingHeader = false);
  }

  Future<void> _loadCategories() async {
    final data = await api.categories();
    if (mounted) setState(() => _categories = data);
  }

  Future<void> _loadBanners() async {
    final data = await api.banners();
    if (mounted) setState(() => _banners = data);
  }

  Future<void> _loadProducts({bool refresh = false}) async {
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
        category: _selectedCategory,
        search: _search.isEmpty ? null : _search,
      );

      if (!mounted) return;

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

  Future<void> _refreshAll() async {
    _page = 1;
    _hasMore = true;
    _items.clear();
    await _loadAll();
  }

  void _maybeMore() {
    if (!_scroll.hasClients || _loading || !_hasMore) return;

    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 300) {
      _loadProducts();
    }
  }

  // ================= HELPERS =================

  bool _isOut(Map<String, dynamic> p) {
    final s = (p['stock_status'] ?? '').toString().toLowerCase();
    return p['is_out'] == true ||
        s == 'outofstock' ||
        s == 'out_of_stock' ||
        p['is_in_stock'] == false;
  }

  List<Map<String, dynamic>> _visibleItems() {
    final list = List<Map<String, dynamic>>.from(_items);

    list.sort((a, b) {
      final ao = _isOut(a);
      final bo = _isOut(b);
      if (ao == bo) return 0;
      return ao ? 1 : -1;
    });

    if (_showOnlyInStock) {
      return list.where((e) => !_isOut(e)).toList();
    }

    return list;
  }

  void _selectCategory(int? id) {
    setState(() => _selectedCategory = id);
    _loadProducts(refresh: true);
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eram Yadak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'جستجو...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (v) {
                _search = v.trim();
                _loadProducts(refresh: true);
              },
            ),
          ),
        ),
      ),

      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          controller: _scroll,
          children: [

            if (_loadingHeader)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),

            // ===== SINGLE BANNER =====
            if (_banners.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    _banners.last, // 👈 فقط آخرین بنر
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // ===== CATEGORIES =====
            if (_categories.isNotEmpty)
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _chip(
                        "همه",
                        _selectedCategory == null,
                        () => _selectCategory(null),
                      );
                    }

                    final c = _categories[i - 1];

                    return _chip(
                      c['name'],
                      _selectedCategory == c['id'],
                      () => _selectCategory(c['id']),
                    );
                  },
                ),
              ),

            // ===== FILTER =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text("فقط موجودها"),
                  Switch(
                    value: _showOnlyInStock,
                    onChanged: (v) =>
                        setState(() => _showOnlyInStock = v),
                  )
                ],
              ),
            ),

            // ===== PRODUCTS =====
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              padding: const EdgeInsets.all(12),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) {
                final p = items[i];

                return ProductCard(
                  p: p,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetail(product: p),
                    ),
                  ),
                  onCartUpdated: () async {},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}
