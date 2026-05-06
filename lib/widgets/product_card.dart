// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../data/store_api.dart' as store;
import '../utils/price.dart';

const Color _navyBlue = Color(0xFF1A237E);

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> p;
  final VoidCallback? onTap;
  final Future<void> Function()? onCartUpdated;

  const ProductCard({
    super.key,
    required this.p,
    this.onTap,
    this.onCartUpdated,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final store.StoreApi _api = store.StoreApi();
  bool _loading = false;
  int _quantity = 1;

  bool _isOut() {
    final stock = (widget.p['stock_status'] ?? '').toString().toLowerCase();
    return stock == 'outofstock' || widget.p['is_in_stock'] == false;
  }

  int? _stockQuantity() {
    final raw = widget.p['stock_quantity'] ?? widget.p['stock']?['quantity'];
    if (raw is num) return raw.floor();
    return int.tryParse(raw?.toString() ?? '');
  }

  bool get _canIncrease {
    final stockQuantity = _stockQuantity();
    return !_loading && (stockQuantity == null || _quantity < stockQuantity);
  }

  void _decreaseQuantity() {
    if (_loading || _quantity <= 1) return;
    setState(() => _quantity--);
  }

  void _increaseQuantity() {
    if (!_canIncrease) return;
    setState(() => _quantity++);
  }

  int? _readUnitToman(Map<String, dynamic> item) {
    final possible = [
      item['unit_price'],
      item['price'],
      item['prices']?['price'],
    ];
    for (final v in possible) {
      final t = Price.toTomanNullable(v);
      if (t != null) return t;
    }
    return null;
  }

  Future<void> _addToCart() async {
    if (_isOut()) return; // ❌ جلوگیری از افزودن ناموجود

    setState(() => _loading = true);
    try {
      final id = int.parse(widget.p['id'].toString());
      await _api.ensureSession();
      await _api.addToCart(productId: id, quantity: _quantity);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_quantity عدد اضافه شد')),
      );

      if (widget.onCartUpdated != null) {
        await widget.onCartUpdated!();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = (widget.p["images"] != null &&
            widget.p["images"].isNotEmpty)
        ? widget.p["images"][0]["src"]
        : "";

    final name = widget.p["name"]?.toString() ?? "";
    final price = _readUnitToman(widget.p);

    final isOut = _isOut();

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Expanded(
                  child: image.isNotEmpty
                      ? Image.network(
                          image,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: Center(child: Icon(Icons.image)),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (price != null)
                  Text(
                    Price.formatToman(price),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 6),
                _QuantitySelector(
                  quantity: _quantity,
                  enabled: !isOut && !_loading,
                  canDecrease: !_loading && _quantity > 1,
                  canIncrease: !isOut && _canIncrease,
                  onDecrease: _decreaseQuantity,
                  onIncrease: _increaseQuantity,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: (isOut || _loading) ? null : _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOut ? Colors.grey : _navyBlue,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(isOut ? "ناموجود" : "افزودن $_quantity به سبد"),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // 🔥 برچسب عدم موجودی
        if (isOut)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Text(
                  "عدم موجودی",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.enabled,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool enabled;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = enabled ? _navyBlue : Colors.grey;

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF4F6FF) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: enabled ? _navyBlue.withOpacity(0.18) : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            icon: Icons.remove,
            tooltip: 'کم کردن تعداد',
            color: foregroundColor,
            onPressed: canDecrease ? onDecrease : null,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add,
            tooltip: 'زیاد کردن تعداد',
            color: foregroundColor,
            onPressed: canIncrease ? onIncrease : null,
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tooltip: tooltip,
        icon: Icon(icon, size: 18),
        color: color,
        disabledColor: Colors.grey.shade400,
        onPressed: onPressed,
      ),
    );
  }
}
