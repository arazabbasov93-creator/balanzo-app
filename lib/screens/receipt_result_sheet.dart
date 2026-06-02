import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/receipt.dart';
import '../services/category_matcher.dart';
import '../services/category_service.dart';
import '../services/notification_service.dart';
import '../services/family_service.dart';
import '../services/receipt_service.dart';
import '../utils/icon_mapper.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/copyable_fiscal_id.dart';

/// Result returned when user saves from the preview sheet.
class ReceiptSaveResult {
  final String receiptId;
  const ReceiptSaveResult(this.receiptId);
}

/// Shared bottom sheet that previews a parsed receipt and saves it to Supabase.
class ReceiptResultSheet extends StatefulWidget {
  final Receipt receipt;
  final VoidCallback onRetake;

  const ReceiptResultSheet({
    super.key,
    required this.receipt,
    required this.onRetake,
  });

  @override
  State<ReceiptResultSheet> createState() => _ReceiptResultSheetState();
}

class _EditItem {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  String? categoryId;
  bool editing = false;

  _EditItem({
    required String name,
    required double qty,
    required double unitPrice,
    this.categoryId,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(
          text: qty == qty.roundToDouble()
              ? qty.toInt().toString()
              : qty.toStringAsFixed(2),
        ),
        priceCtrl = TextEditingController(text: unitPrice.toStringAsFixed(2));

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ReceiptResultSheetState extends State<ReceiptResultSheet> {
  bool _saving = false;
  bool _saveAsFamily = false;
  bool _hasFamily = false;
  late Receipt _receipt;
  late List<_EditItem> _editItems;
  late final TextEditingController _storeCtrl;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt.withCorrectedTotals();
    _storeCtrl = TextEditingController(text: _receipt.store ?? '');
    _editItems = [];
    _loadCategories();
    _checkFamily();
  }

  Future<void> _checkFamily() async {
    final family = await FamilyService.fetchMyFamily();
    if (mounted) setState(() => _hasFamily = family != null);
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.fetchAll();
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _editItems = _receipt.items.map((item) {
        final catId = item.categoryId ??
            CategoryMatcher.suggestCategoryId(item.name, cats);
        return _EditItem(
          name: item.name,
          qty: item.quantity,
          unitPrice: item.unitPrice,
          categoryId: catId,
        );
      }).toList();
    });
  }

  @override
  void dispose() {
    _storeCtrl.dispose();
    for (final e in _editItems) {
      e.dispose();
    }
    super.dispose();
  }

  Receipt _buildEditedReceipt() {
    final items = _editItems.map((e) {
      final qty = double.tryParse(e.qtyCtrl.text) ?? 1.0;
      final unitPrice = double.tryParse(e.priceCtrl.text) ?? 0.0;
      return ReceiptItem(
        name: e.nameCtrl.text.trim().isEmpty ? '?' : e.nameCtrl.text.trim(),
        quantity: qty,
        unitPrice: unitPrice,
        totalPrice: qty * unitPrice,
        categoryId: e.categoryId,
      );
    }).toList();
    final subtotal = items.fold(0.0, (s, i) => s + i.totalPrice);
    final storeName = _storeCtrl.text.trim();
    return Receipt(
      store: storeName.isEmpty ? null : storeName,
      date: _receipt.date,
      items: items,
      subtotal: subtotal,
      serviceCharge: _receipt.serviceCharge,
      vat: _receipt.vat,
      total: items.isEmpty
          ? _receipt.total
          : subtotal + (_receipt.serviceCharge ?? 0),
      currency: _receipt.currency,
      isGovernmentVerified: _receipt.isGovernmentVerified,
      documentId: _receipt.documentId,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      NotificationService.requestIfNotAsked();
      final edited = _buildEditedReceipt();
      final receiptId = await ReceiptService.save(
        edited,
        categories: _categories,
        saveAsFamily: _saveAsFamily,
      );
      if (!mounted) return;
      Navigator.of(context).pop(ReceiptSaveResult(receiptId));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            msg.contains('sign in') ? msg : 'Save failed: $msg',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<void> _pickCategory(int index) async {
    if (_categories.isEmpty) return;
    final edit = _editItems[index];
    final selected = await showCategoryPickerSheet(
      context,
      categories: _categories,
      selectedId: edit.categoryId,
    );
    if (selected != edit.categoryId && mounted) {
      setState(() => edit.categoryId = selected);
    }
  }

  Category? _categoryFor(String? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (receipt.isGovernmentVerified)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              color: Color(0xFF1B5E20), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Government Verified · e-kassa',
                            style: TextStyle(
                              color: Color(0xFF1B5E20),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (receipt.documentId != null &&
                        receipt.documentId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CopyableFiscalIdRow(
                        fiscalId: receipt.documentId!,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STORE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.black45,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TextField(
                          controller: _storeCtrl,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Tap to enter store name',
                            hintStyle: TextStyle(
                              fontSize: 20,
                              color: Colors.black38,
                              fontWeight: FontWeight.bold,
                            ),
                            suffixIcon: Icon(Icons.edit, size: 14, color: Colors.black38),
                          ),
                        ),
                        if (receipt.date != null)
                          Text(
                            '${receipt.date!.day}.${receipt.date!.month.toString().padLeft(2, '0')}.${receipt.date!.year}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${receipt.total.toStringAsFixed(2)} ${receipt.currency}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: _editItems.isEmpty
                  ? const Center(
                      child: Text(
                        'No items detected',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _editItems.length,
                      itemBuilder: (_, i) => _buildItemRow(i),
                    ),
            ),
            if (receipt.serviceCharge != null && receipt.serviceCharge! > 0) ...[
              const Divider(color: Colors.black12, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                    Text('${receipt.subtotal.toStringAsFixed(2)} AZN',
                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Service charge',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                    Text('+${receipt.serviceCharge!.toStringAsFixed(2)} AZN',
                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  ],
                ),
              ),
              const Divider(color: Colors.black12, height: 1),
              const SizedBox(height: 4),
            ],
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasFamily) ...[
                      const Text(
                        'Save as',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _SaveScopeChip(
                              label: 'Personal',
                              icon: Icons.person_outline,
                              selected: !_saveAsFamily,
                              onTap: () =>
                                  setState(() => _saveAsFamily = false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SaveScopeChip(
                              label: 'Family',
                              icon: Icons.family_restroom_outlined,
                              selected: _saveAsFamily,
                              onTap: () =>
                                  setState(() => _saveAsFamily = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : widget.onRetake,
                            icon: const Icon(Icons.refresh_outlined, size: 18),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade700,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: Text(_saving ? 'Saving…' : 'Save receipt'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B5E20),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int i) {
    final edit = _editItems[i];
    if (edit.editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            TextField(
              controller: edit.nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: edit.qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: edit.priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unit price',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Color(0xFF1B5E20)),
                  onPressed: () => setState(() => edit.editing = false),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final qty = double.tryParse(edit.qtyCtrl.text) ?? 1.0;
    final unitPrice = double.tryParse(edit.priceCtrl.text) ?? 0.0;
    final totalPrice = qty * unitPrice;
    final cat = _categoryFor(edit.categoryId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  edit.nameCtrl.text,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                if (qty != 1.0)
                  Text(
                    '$qty × ${unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _pickCategory(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cat != null
                          ? Color(cat.color).withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat != null)
                          Icon(
                            iconForName(cat.icon),
                            size: 12,
                            color: Color(cat.color),
                          )
                        else
                          const Icon(Icons.category_outlined,
                              size: 12, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(
                          cat?.name ?? 'Category',
                          style: TextStyle(
                            fontSize: 11,
                            color: cat != null
                                ? Color(cat.color)
                                : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more, size: 14, color: Colors.black38),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            totalPrice.toStringAsFixed(2),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.black54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => edit.editing = true),
          ),
        ],
      ),
    );
  }
}

class _SaveScopeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SaveScopeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF1B5E20) : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? const Color(0xFF1B5E20) : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? const Color(0xFF1B5E20) : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
