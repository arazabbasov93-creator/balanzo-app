import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models/category.dart';
import '../models/receipt.dart';
import '../services/category_assignment_service.dart';
import '../services/category_matcher.dart';
import '../services/category_service.dart';
import '../services/notification_service.dart';
import '../services/family_service.dart';
import '../services/receipt_service.dart';
import '../models/fiscal_duplicate.dart';
import '../l10n/app_strings.dart';
import 'receipt_detail_screen.dart';
import '../utils/icon_mapper.dart';
import '../utils/receipt_numbers.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/currency_picker_sheet.dart';
import '../widgets/copyable_fiscal_id.dart';
import '../utils/currency_data.dart';
import '../config/app_colors.dart';

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
  final double lineTotal;
  String? categoryId;
  bool editing = false;

  _EditItem({
    required String name,
    required double qty,
    required double unitPrice,
    required double totalPrice,
    this.categoryId,
  })  : nameCtrl = TextEditingController(text: name),
        lineTotal = totalPrice,
        qtyCtrl = TextEditingController(text: ReceiptNumbers.formatQuantity(qty)),
        priceCtrl = TextEditingController(
          text: ReceiptNumbers.formatUnitPrice(unitPrice),
        );

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
  bool _skipSoftDuplicateCheck = false;
  late Receipt _receipt;
  DateTime? _purchaseDate;
  late List<_EditItem> _editItems;
  late final TextEditingController _storeCtrl;
  List<Category> _categories = [];
  bool _categoriesReady = false;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt.withCorrectedTotals();
    _purchaseDate = _receipt.date;
    _storeCtrl = TextEditingController(text: _receipt.store ?? '');
    _editItems = _receipt.items
        .map(
          (item) => _EditItem(
            name: item.name,
            qty: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
            categoryId: item.categoryId,
          ),
        )
        .toList();
    _loadCategories();
    _checkFamily();
    _checkDuplicate();
  }

  Future<void> _checkDuplicate() async {
    final fiscalId = _receipt.documentId?.trim();
    if (fiscalId != null && fiscalId.isNotEmpty) {
      final hit = await ReceiptService.findDuplicateByFiscalId(fiscalId);
      if (hit != null && mounted) {
        await _showDuplicateDialog(hit);
      }
      return;
    }
    final hash = ReceiptService.generateContentHash(_buildEditedReceipt());
    if (hash == null) return;
    final softHit = await ReceiptService.findDuplicateByContentHash(hash);
    if (softHit != null && mounted) {
      await _showSoftDuplicateDialog(softHit);
    }
  }

  Future<void> _checkFamily() async {
    final family = await FamilyService.fetchMyFamily();
    if (mounted) setState(() => _hasFamily = family != null);
  }

  Future<void> _loadCategories() async {
    final cats = await CategoryService.fetchAll();
    if (!mounted) return;
    final assigned = await CategoryAssignmentService.assignItems(
      _receipt.items,
      cats,
      storeName: _receipt.store,
    );
    setState(() {
      _categories = cats;
      _categoriesReady = true;
      for (var i = 0; i < _editItems.length && i < assigned.length; i++) {
        _editItems[i].categoryId ??= assigned[i].categoryId;
      }
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

  void _removeItem(int index) {
    setState(() {
      _editItems[index].dispose();
      _editItems.removeAt(index);
    });
  }

  double get _itemsSubtotal =>
      _editItems.fold(0.0, (s, e) => s + e.lineTotal);

  double get _displayTotal {
    final header = _receipt.total;
    final ekassa = _receipt.isGovernmentVerified ||
        (_receipt.documentId != null && _receipt.documentId!.isNotEmpty);
    if (_editItems.isEmpty) return header;
    if (ekassa && header > _itemsSubtotal + 0.5 && header < _itemsSubtotal * 3) {
      return header;
    }
    return _itemsSubtotal + (_receipt.serviceCharge ?? 0);
  }

  Receipt _buildEditedReceipt() {
    final items = _editItems.map((e) {
      final qty = double.tryParse(e.qtyCtrl.text) ?? 1.0;
      final unitPrice = double.tryParse(e.priceCtrl.text) ?? 0.0;
      return ReceiptItem(
        name: e.nameCtrl.text.trim().isEmpty ? '?' : e.nameCtrl.text.trim(),
        quantity: qty,
        unitPrice: unitPrice,
        totalPrice: e.lineTotal,
        categoryId: e.categoryId,
      );
    }).toList();
    final subtotal = items.fold(0.0, (s, i) => s + i.totalPrice);
    final storeName = _storeCtrl.text.trim();
    final headerTotal = _receipt.total;
    final ekassaReceipt = _receipt.isGovernmentVerified ||
        (_receipt.documentId != null && _receipt.documentId!.isNotEmpty);
    final useHeaderTotal = ekassaReceipt &&
        headerTotal > subtotal + 0.5 &&
        headerTotal < subtotal * 3;
    return Receipt(
      store: storeName.isEmpty ? null : storeName,
      date: _purchaseDate,
      items: items,
      subtotal: subtotal,
      serviceCharge: _receipt.serviceCharge,
      vat: _receipt.vat,
      total: items.isEmpty
          ? headerTotal
          : useHeaderTotal
              ? headerTotal
              : subtotal + (_receipt.serviceCharge ?? 0),
      currency: _receipt.currency,
      isGovernmentVerified: _receipt.isGovernmentVerified,
      documentId: _receipt.documentId,
    );
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData(
          colorScheme: const ColorScheme.light(primary: AppColors.primaryGreenDark),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_purchaseDate == null) {
      _snack('Please select the purchase date.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await NotificationService.requestIfNotAsked();
      final edited = await CategoryAssignmentService.assignReceipt(
        _buildEditedReceipt(),
        _categories,
      );
      final receiptId = await ReceiptService.save(
        edited,
        categories: _categories,
        saveAsFamily: _saveAsFamily,
        skipSoftDuplicateCheck: _skipSoftDuplicateCheck,
      );
      if (!mounted) return;
      notifyReceiptsChanged();
      Navigator.of(context).pop(ReceiptSaveResult(receiptId));
    } catch (e) {
      if (e is FiscalDuplicateException) {
        if (mounted) {
          setState(() => _saving = false);
          await _showDuplicateDialog(e.hit);
        }
        return;
      }
      if (e is SoftDuplicateException) {
        if (mounted) {
          setState(() => _saving = false);
          await _showSoftDuplicateDialog(e.hit);
        }
        return;
      }
      if (mounted) {
        setState(() => _saving = false);
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            msg.contains('sign in') ? msg : 'Save failed: $msg',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _pickCategory(int index) async {
    var cats = _categories;
    if (cats.isEmpty) {
      cats = List<Category>.from(CategoryService.cached);
      if (cats.isEmpty) {
        cats = await CategoryService.fetchAll();
      }
      if (mounted) {
        setState(() => _categories = cats);
      }
    }
    if (!mounted || cats.isEmpty) return;
    final edit = _editItems[index];
    final selected = await showCategoryPickerSheet(
      context,
      categories: cats,
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

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : AppColors.primaryGreenDark,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickCurrency() async {
    final selected = await showCurrencyPickerSheet(
      context,
      initialCurrency: _receipt.currency,
    );
    if (!mounted) return;
    setState(() => _receipt = Receipt(
          store: _receipt.store,
          date: _receipt.date,
          items: _receipt.items,
          subtotal: _receipt.subtotal,
          serviceCharge: _receipt.serviceCharge,
          vat: _receipt.vat,
          total: _receipt.total,
          currency: selected,
          isGovernmentVerified: _receipt.isGovernmentVerified,
          documentId: _receipt.documentId,
        ));
  }

  Future<void> _showSoftDuplicateDialog(FiscalDuplicateHit hit) async {
    final lang = currentLanguage.value;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(AppStrings.get('soft_duplicate_title', lang)),
        content: Text(
          AppStrings.softDuplicateBody(hit.storeName, lang),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReceiptDetailScreen(
                    receiptId: hit.receiptId,
                    receipt: Receipt(
                      store: hit.storeName,
                      date: hit.purchaseDate != null
                          ? DateTime.tryParse(hit.purchaseDate!)
                          : null,
                      items: const [],
                      subtotal: 0,
                      vat: 0,
                      total: 0,
                      currency: null,
                      documentId: null,
                    ),
                  ),
                ),
              );
            },
            child: Text(AppStrings.get('view_existing', lang)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _skipSoftDuplicateCheck = true);
              _save();
            },
            child: Text(AppStrings.get('save_anyway', lang)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDuplicateDialog(FiscalDuplicateHit hit) async {
    final lang = currentLanguage.value;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('duplicate_receipt_title', lang)),
        content: Text(
          AppStrings.duplicateReceiptBody(hit.scannerLabel, hit.storeName, lang),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.get('cancel', lang)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReceiptDetailScreen(
                    receiptId: hit.receiptId,
                    receipt: Receipt(
                      store: hit.storeName,
                      date: hit.purchaseDate != null
                          ? DateTime.tryParse(hit.purchaseDate!)
                          : null,
                      items: const [],
                      subtotal: 0,
                      vat: 0,
                      total: 0,
                      currency: null,
                      documentId: null,
                    ),
                  ),
                ),
              );
            },
            child: Text(AppStrings.get('view_receipt', lang)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                        color: AppColors.green100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified,
                              color: AppColors.primaryGreenDark, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Government Verified · e-kassa',
                            style: TextStyle(
                              color: AppColors.primaryGreenDark,
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
                        InkWell(
                          onTap: _pickPurchaseDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _purchaseDate != null
                                      ? _formatDate(_purchaseDate!)
                                      : 'Select purchase date *',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _purchaseDate != null
                                        ? Colors.black54
                                        : Colors.orange.shade800,
                                    fontWeight: _purchaseDate == null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.calendar_today_outlined,
                                    size: 14, color: Colors.black38),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatMoney(_displayTotal, receipt.currency),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreenDark,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: InkWell(
                onTap: _pickCurrency,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.payments_outlined,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currencyDisplayLabel(receipt.currency),
                          style: TextStyle(
                            fontSize: 13,
                            color: receipt.currency != null
                                ? Colors.black87
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const Icon(Icons.expand_more, size: 18, color: Colors.black38),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: !_categoriesReady
                  ? const Center(child: CircularProgressIndicator())
                  : _editItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_sweep_outlined,
                              size: 40, color: Colors.black38),
                          const SizedBox(height: 8),
                          const Text(
                            'All items removed',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap Save to keep receipt total only, or Retake',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
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
                    Text(formatMoney(receipt.subtotal, receipt.currency),
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
                    Text('+${formatMoney(receipt.serviceCharge!, receipt.currency)}',
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
                              backgroundColor: AppColors.primaryGreen(
                                Theme.of(context).brightness,
                              ),
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
                  icon: const Icon(Icons.check_circle, color: AppColors.primaryGreenDark),
                  onPressed: () => setState(() => edit.editing = false),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: 'Remove item',
                  onPressed: () => _removeItem(i),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final qty = double.tryParse(edit.qtyCtrl.text) ?? 1.0;
    final unitPrice = double.tryParse(edit.priceCtrl.text) ?? 0.0;
    final totalPrice = edit.lineTotal;
    final cat = _categoryFor(edit.categoryId) ??
        _categoryFor(CategoryMatcher.otherCategoryId(_categories));

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
                    '${ReceiptNumbers.formatQuantity(qty)} × ${ReceiptNumbers.formatUnitPrice(unitPrice)}',
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
                          cat?.name ?? 'Other',
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
            ReceiptNumbers.formatLineTotal(totalPrice),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Remove item',
            onPressed: () => _removeItem(i),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.black54),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
      color: selected ? AppColors.green100 : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryGreenDark : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primaryGreenDark : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primaryGreenDark : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
