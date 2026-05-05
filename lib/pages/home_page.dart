import 'dart:async';
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
  final PageController _pageController = PageController(viewportFraction: 0.92);

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _banners = [];

  bool _loading = false;
  bool _loadingHeader = true;
  bool _hasMore = true;
  bool _showOnlyInStock = false;

  int _page = 1;
  int _currentBanner = 0;
  int? _selectedCategory;
  String _search = '';

  Timer? _autoSlide;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scroll.addListener(_maybeMore);
    _startAutoSlide();
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeMore);
    _scroll.dispose();
    _pageController.dispose();
    _autoSlide?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadProducts(refresh: true),
      _loadCategories(),
      _loadBanners(),
    ]);
    if (mounted) setState(() => _loadingHeader = false);
  }

  Future<void> _loadCategories() async {
    try {
      final data = await api.categories();
      if (mounted) setState(() => _categories = data);
    } catch (_) {
      if (mounted) setState(() => _categories = []);
    }
  }

  Future<void> _loadBanners() async {
    try {
      final data = await api.banners();
      if (mounted) setState(() => _banners = data);
    } catch (_) {
      if (mounted) setState(() => _banners = []);
    }
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

    if (mounted) setState(() => _loading = true);

    try {
      final data = await api.products(
        page: _page,
        per: 12,
        category: _selectedCategory,
        search: _search.isEmpty ? null : _search,
        forceRefresh: refresh,
      );

      if (!mounted) return;

      setState(() {
        if (data.isEmpty) {
          _hasMore = false;
        } else {
          _page++;
          _items.addAll(data);
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshAll() async {
    _page = 1;
    _hasMore = true;
    _items.clear();

    await Future.wait([
      _loadProducts(refresh: true),
      _loadCategories(),
      _loadBanners(),
    ]);
  }

  void _maybeMore() {
    if (!_scroll.hasClients || _loading || !_hasMore) return;

    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
      _loadProducts();
    }
  }

  bool _isOut(Map<String, dynamic> p) {
    final stock = (p['stock_status'] ?? '').toString().toLowerCase();
    return p['is_out'] == true ||
        stock == 'outofstock' ||
        stock == 'out_of_stock' ||
        p['is_in_stock'] == false;
  }

  List<Map<String, dynamic>> _visibleItems() {
    final list = List<Map<String, dynamic>>.from(_items);

    list.sort((a, b) {
      final aOut = _isOut(a);
      final bOut = _isOut(b);
      if (aOut == bOut) return 0;
      return aOut ? 1 : -1;
    });

    if (_showOnlyInStock) {
      return list.where((e) => !_isOut(e)).toList();
    }

    return list;
  }

  void _startAutoSlide() {
    _autoSlide?.cancel();
    _autoSlide = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _banners.isEmpty || !_pageController.hasClients) return;

      final next = (_currentBanner + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _selectCategory(int? categoryId) {
    setState(() => _selectedCategory = categoryId);
    _loadProducts(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eram Yadak'),
        actions: [
          IconButton(
            tooltip: 'بروزرسانی',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'جستجوی محصول...',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
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
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            if (_loadingHeader)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (_banners.isNotEmpty) _buildSlider(),

            if (_categories.isNotEmpty) _buildCategories(),

            _buildFilterRow(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length + (_loading ? 2 : 0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (_, i) {
                  if (i >= items.length) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final p = items[i];

                  return ProductCard(
                    p: p,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetail(product: p),
                      ),
                    ),
                    onCartUpdated: () async {
                      return;
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider() {
    return Column(
      children: [
        SizedBox(
          height: 185,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (_, i) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 8,
                      offset: Offset(0, 3),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: Image.network(
                  _banners[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF1F1F1),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              width: _currentBanner == i ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBanner == i
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _categories.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final selected = _selectedCategory == null;
            return _CategoryChip(
              title: 'همه',
              selected: selected,
              onTap: () => _selectCategory(null),
            );
          }

          final c = _categories[i - 1];
          final id = c['id'] is int ? c['id'] as int : int.tryParse('${c['id']}');
          final name = (c['name'] ?? '').toString();
          final selected = _selectedCategory == id;

          return _CategoryChip(
            title: name,
            selected: selected,
            onTap: () => _selectCategory(id),
          );
        },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          const Text(
            'جدیدترین محصولات',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          const Text('فقط موجودها'),
          Switch(
            value: _showOnlyInStock,
            onChanged: (v) => setState(() => _showOnlyInStock = v),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
