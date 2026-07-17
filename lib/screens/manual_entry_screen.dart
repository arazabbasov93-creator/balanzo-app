import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../models/receipt.dart';
import '../models/category.dart';
import '../services/category_service.dart';
import '../services/receipt_service.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/currency_picker_sheet.dart';
import '../utils/currency_data.dart';
import '../utils/icon_mapper.dart';
import 'receipt_detail_screen.dart';
import '../config/app_colors.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _storeCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _currency = 'AZN';
  String? _categoryId;
  final List<_ItemRow> _items = [_ItemRow()];
  bool _saving = false;

  @override
  void dispose() {
    _storeCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Category? get _selectedCategory {
    if (_categoryId == null) return null;
    for (final c in CategoryService.cached) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreenDark),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickCurrency() async {
    final selected = await showCurrencyPickerSheet(context, initialCurrency: _currency);
    if (selected != null) setState(() => _currency = selected);
  }

  Future<void> _pickCategory() async {
    await CategoryService.fetchAll();
    if (!mounted) return;
    final selected = await showCategoryPickerSheet(
      context,
      categories: CategoryService.cached,
      selectedId: _categoryId,
    );
    if (selected != null) setState(() => _categoryId = selected);
  }

  void _addItem() {
    setState(() => _items.add(_ItemRow()));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    final item = _items.removeAt(index);
    item.dispose();
    setState(() {});
  }

  double get _total => _items.fold(0, (sum, item) {
        final qty = double.tryParse(item.qtyCtrl.text) ?? 1;
        final price = double.tryParse(item.priceCtrl.text) ?? 0;
        return sum + qty * price;
      });

  Future<void> _save() async {
    final store = _storeCtrl.text.trim();
    if (store.isEmpty) {
      _snack('Please enter a store name', error: true);
      return;
    }
    final hasItems = _items.any((i) => i.nameCtrl.text.trim().isNotEmpty);
    if (!hasItems) {
      _snack('Please add at least one item', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await CategoryService.fetchAll();
      final cat = _selectedCategory;
      final catName = cat?.name;

      final items = _items
          .where((i) => i.nameCtrl.text.trim().isNotEmpty)
          .map((i) {
        final qty = double.tryParse(i.qtyCtrl.text) ?? 1;
        final price = double.tryParse(i.priceCtrl.text) ?? 0;
        return ReceiptItem(
          name: i.nameCtrl.text.trim(),
          quantity: qty,
          unitPrice: price,
          totalPrice: qty * price,
          categoryId: _categoryId,
          categoryName: catName,
        );
      }).toList();

      final total = items.fold(0.0, (s, i) => s + i.totalPrice);

      final receipt = Receipt(
        store: store,
        date: _date,
        items: items,
        subtotal: total,
        vat: 0,
        total: total,
        currency: _currency,
      );

      final id = await ReceiptService.save(receipt);
      notifyReceiptsChanged();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReceiptDetailScreen(receiptId: id, receipt: receipt),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Save failed: $e', error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : AppColors.primaryGreenDark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    final cat = _selectedCategory;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(AppStrings.get('manual_entry', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(AppStrings.get('store_name', lang)),
                const SizedBox(height: 6),
                TextField(
                  controller: _storeCtrl,
                  decoration: _inputDecoration('e.g. Bravo Supermarket'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                _Label(AppStrings.get('date_label', lang)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        Text(
                          '${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Label('Currency'),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickCurrency,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 18, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            currencyDisplayLabel(_currency),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Label(AppStrings.get('categories', lang)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickCategory,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        if (cat != null) ...[
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(cat.color).withValues(alpha: 0.15),
                            child: Icon(iconForName(cat.icon), size: 16, color: Color(cat.color)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(cat.name, style: const TextStyle(fontSize: 15))),
                        ] else
                          Expanded(
                            child: Text(
                              AppStrings.get('select_category', lang),
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                            ),
                          ),
                        const Icon(Icons.expand_more, size: 20, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.get('items_label', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(AppStrings.get('add_item', lang)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreenDark),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Item',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: Text(
                          'Qty',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 72,
                        child: Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                ..._items.asMap().entries.map((e) => _ItemInputRow(
                      key: ValueKey(e.key),
                      row: e.value,
                      canRemove: _items.length > 1,
                      onRemove: () => _removeItem(e.key),
                      onChanged: () => setState(() {}),
                    )),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppStrings.get('total_label', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      formatMoney(_total, _currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primaryGreenDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 20),
              label: Text(_saving ? AppStrings.get('saving', lang) : AppStrings.get('save_receipt', lang)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen(
                  Theme.of(context).brightness,
                ),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ItemRow {
  final nameCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final priceCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ItemInputRow extends StatelessWidget {
  final _ItemRow row;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemInputRow({
    super.key,
    required this.row,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextField(
              controller: row.nameCtrl,
              decoration: _inputDecoration('Item name'),
              onChanged: (_) => onChanged(),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: TextField(
              controller: row.qtyCtrl,
              decoration: _inputDecoration('1'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              controller: row.priceCtrl,
              decoration: _inputDecoration('0.00'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: (_) => onChanged(),
            ),
          ),
          SizedBox(
            width: 32,
            child: canRemove
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600));
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
