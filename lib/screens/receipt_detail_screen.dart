import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../models/receipt.dart';
import '../models/category.dart';
import '../services/category_matcher.dart';
import '../services/support_service.dart';
import '../l10n/app_strings.dart';
import '../utils/category_display.dart';
import '../services/category_service.dart';
import '../services/family_service.dart';
import '../services/receipt_service.dart';
import '../utils/receipt_numbers.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/currency_picker_sheet.dart';
import '../widgets/copyable_fiscal_id.dart';
import '../utils/currency_data.dart';
import '../services/supabase_access.dart';
import '../config/app_colors.dart';

// ── Editable item state ────────────────────────────────────────────────────────

class _ItemEdit {
  final String? id; // null if new
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final double lineTotal;
  String? categoryId;

  _ItemEdit({
    this.id,
    required String name,
    required double qty,
    required double price,
    required double totalPrice,
    String? categoryId,
  })  : nameCtrl = TextEditingController(text: name),
        lineTotal = totalPrice,
        qtyCtrl = TextEditingController(text: ReceiptNumbers.formatQuantity(qty)),
        priceCtrl = TextEditingController(text: ReceiptNumbers.formatUnitPrice(price)),
        categoryId = categoryId;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

// ── Screen ─────────────────────────────────────────────────────────────────────

class ReceiptDetailScreen extends StatefulWidget {
  final String receiptId;
  final Receipt receipt;

  const ReceiptDetailScreen({
    super.key,
    required this.receiptId,
    required this.receipt,
  });

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late Future<_DetailData> _future;
  _DetailData? _cachedData;

  // Edit mode state
  bool _editMode = false;
  bool _saving = false;
  bool _scopeUpdating = false;
  TextEditingController? _storeCtrl;
  TextEditingController? _dateCtrl;
  String? _editCurrency;
  List<_ItemEdit> _itemEdits = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _disposeEditControllers();
    super.dispose();
  }

  Future<_DetailData> _load() async {
    final row = await ReceiptService.fetchById(widget.receiptId);
    final cats = await CategoryService.fetchAll();
    final family = await FamilyService.fetchMyFamily();
    final data = _DetailData(
      row: row,
      categories: cats,
      hasFamily: family != null,
    );
    if (mounted) {
      setState(() => _cachedData = data);
    } else {
      _cachedData = data;
    }
    return data;
  }

  void _refresh() => setState(() => _future = _load());

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void _enterEditMode(_DetailData data) {
    final row = data.row;
    _storeCtrl = TextEditingController(text: row['store_name'] as String? ?? '');
    _dateCtrl = TextEditingController(text: row['purchase_date'] as String? ?? '');
    _editCurrency = row['currency'] as String? ?? widget.receipt.currency;
    final dbItems = (row['receipt_items'] as List? ?? []).cast<Map<String, dynamic>>();
    _itemEdits = dbItems
        .map((item) => _ItemEdit(
              id: item['id'] as String?,
              name: item['product_name'] as String? ??
                  item['name_raw'] as String? ??
                  item['name'] as String? ??
                  '',
              qty: (item['quantity'] as num?)?.toDouble() ?? 1.0,
              price: (item['unit_price'] as num?)?.toDouble() ?? 0.0,
              totalPrice: (item['total_price'] as num?)?.toDouble() ?? 0.0,
              categoryId: _resolveCategory(item, data.categories),
            ))
        .toList();
    setState(() => _editMode = true);
  }

  String? _resolveCategory(Map<String, dynamic> item, List<Category> categories) {
    final id = item['category_id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    final label = item['category'] as String?;
    if (label == null || label.isEmpty) return null;
    try {
      return categories.firstWhere(
        (c) => c.name.trim().toLowerCase() == label.trim().toLowerCase(),
      ).id;
    } catch (_) {
      return null;
    }
  }

  void _disposeEditControllers() {
    _storeCtrl?.dispose();
    _storeCtrl = null;
    _dateCtrl?.dispose();
    _dateCtrl = null;
    _editCurrency = null;
    for (final e in _itemEdits) {
      e.dispose();
    }
    _itemEdits = [];
  }

  void _cancelEdit() {
    _disposeEditControllers();
    setState(() => _editMode = false);
  }

  Future<void> _saveEdit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final supabase = SupabaseAccess.client;

      // Update receipt header
      await supabase.from('receipts').update({
        'store_name': _storeCtrl!.text.trim(),
        'purchase_date': _dateCtrl!.text.trim().isEmpty ? null : _dateCtrl!.text.trim(),
      }).eq('id', widget.receiptId);

      final savedCurrency =
          _cachedData?.row['currency'] as String? ?? widget.receipt.currency;
      if (_editCurrency != savedCurrency) {
        await ReceiptService.updateCurrency(widget.receiptId, _editCurrency);
      }

      // Determine which DB item IDs are still present
      final keptIds = _itemEdits.where((e) => e.id != null).map((e) => e.id!).toSet();
      final dbItems = (_cachedData?.row['receipt_items'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final dbIds = dbItems.map((i) => i['id'] as String).toSet();

      // Delete removed items
      for (final removedId in dbIds.difference(keptIds)) {
        await supabase.from('receipt_items').delete().eq('id', removedId);
      }

      // Update existing / insert new items
      for (final edit in _itemEdits) {
        final qty = double.tryParse(edit.qtyCtrl.text) ?? 1.0;
        final unitPrice = double.tryParse(edit.priceCtrl.text) ?? 0.0;
        final name = edit.nameCtrl.text.trim().isEmpty ? 'Unknown' : edit.nameCtrl.text.trim();
        final payload = {
          'product_name': name,
          'name_raw': name,
          'quantity': qty,
          'unit_price': unitPrice,
          'total_price': edit.lineTotal,
          'category_id': edit.categoryId,
        };
        if (edit.id != null) {
          await supabase.from('receipt_items').update(payload).eq('id', edit.id!);
        } else {
          await supabase.from('receipt_items').insert({
            ...payload,
            'purchase_id': widget.receiptId,
            'category': 'Other',
            'unit': 'pcs',
          });
        }
      }

      _disposeEditControllers();
      setState(() {
        _editMode = false;
        _saving = false;
      });
      _refresh();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  Future<void> _setFamilyScope(bool asFamily) async {
    if (_scopeUpdating) return;
    setState(() => _scopeUpdating = true);
    try {
      await ReceiptService.setFamilyScope(widget.receiptId, asFamily: asFamily);
      notifyReceiptsChanged();
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _scopeUpdating = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.receipt.store ?? 'Receipt'),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: _editMode
            ? [
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  )
                else ...[
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  TextButton(
                    onPressed: _saveEdit,
                    child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: AppStrings.get('report_receipt', currentLanguage.value),
                  onPressed: _cachedData == null
                      ? null
                      : () => _reportReceipt(_cachedData!),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy as text',
                  onPressed: () => _copyReceipt(context),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit',
                  onPressed: () {
                    final data = _cachedData;
                    if (data != null) _enterEditMode(data);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context),
                ),
              ],
      ),
      body: _editMode ? _buildEditBody() : _buildViewBody(),
    );
  }

  // ── View body ──────────────────────────────────────────────────────────────

  Widget _buildViewBody() {
    return FutureBuilder<_DetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ReceiptBody(
            receipt: widget.receipt,
            fiscalId: null,
            items: const [],
            categories: const [],
            onCategoryChanged: (itemId, catId) {},
          );
        }
        final data = snapshot.data!;
        final rowItems =
            (data.row['receipt_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final currency = data.row['currency'] as String?;
        return _ReceiptBody(
          receipt: widget.receipt,
          currency: currency,
          fiscalId: data.row['fiscal_id'] as String?,
          sequenceNumber: (data.row['sequence_number'] as num?)?.toInt() ??
              widget.receipt.sequenceNumber,
          items: rowItems,
          categories: data.categories,
          hasFamily: data.hasFamily,
          isFamilyScope: data.isFamilyScope,
          scopeUpdating: _scopeUpdating,
          onScopeChanged: _setFamilyScope,
          onCurrencyChanged: (code) => _updateCurrency(code),
          onCategoryChanged: (itemId, catId) =>
              _assignCategory(itemId, catId, data.categories),
        );
      },
    );
  }

  // ── Edit body ──────────────────────────────────────────────────────────────

  Widget _buildEditBody() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Store name
        TextField(
          controller: _storeCtrl,
          decoration: const InputDecoration(
            labelText: 'Store name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Purchase date
        TextField(
          controller: _dateCtrl,
          decoration: const InputDecoration(
            labelText: 'Purchase date (YYYY-MM-DD)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final selected = await showCurrencyPickerSheet(
              context,
              initialCurrency: _editCurrency,
            );
            if (selected != null) setState(() => _editCurrency = selected);
          },
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Currency',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: Text(
              currencyDisplayLabel(_editCurrency),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Divider(),
        Row(
          children: [
            Text('Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _itemEdits.add(_ItemEdit(name: '', qty: 1, price: 0, totalPrice: 0));
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryGreenDark),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._itemEdits.asMap().entries.map((entry) {
          final i = entry.key;
          final edit = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: edit.nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => setState(() => _itemEdits.removeAt(i)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                        flex: 2,
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final selected = await showCategoryPickerSheet(
                        context,
                        categories: _cachedData!.categories,
                        selectedId: edit.categoryId,
                      );
                      setState(() => edit.categoryId = selected);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        edit.categoryId == null
                            ? AppStrings.get('cat_other', currentLanguage.value)
                            : displayCategoryNameById(
                                edit.categoryId,
                                _cachedData!.categories,
                                currentLanguage.value,
                              ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _copyReceipt(BuildContext context) {
    final r = widget.receipt;
    final data = _cachedData;
    final sb = StringBuffer();
    sb.writeln(r.store ?? 'Receipt');
    if (r.date != null) {
      sb.writeln(
          '${r.date!.day.toString().padLeft(2, '0')}.${r.date!.month.toString().padLeft(2, '0')}.${r.date!.year}');
    }
    final fiscalId = data?.row['fiscal_id'] as String?;
    if (fiscalId != null && fiscalId.isNotEmpty) {
      sb.writeln('Fiscal ID: $fiscalId');
    }
    sb.writeln('---');
    if (data != null) {
      final dbItems =
          (data.row['receipt_items'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      for (final item in dbItems) {
        final name = item['product_name'] as String? ??
            item['name_raw'] as String? ??
            item['name'] as String? ??
            'Item';
        final total = (item['total_price'] as num?)?.toDouble() ??
            (item['price'] as num?)?.toDouble() ??
            0.0;
        sb.writeln('$name  ${total.toStringAsFixed(2)} ${r.currency}');
      }
    } else {
      for (final item in r.items) {
        sb.writeln('${item.name}  ${item.totalPrice.toStringAsFixed(2)} ${r.currency}');
      }
    }
    sb.writeln('---');
    sb.writeln('Total: ${r.total.toStringAsFixed(2)} ${r.currency}');
    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Receipt copied to clipboard'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _updateCurrency(String? code) async {
    await ReceiptService.updateCurrency(widget.receiptId, code);
    if (mounted) _refresh();
  }

  Future<void> _assignCategory(
    String itemId,
    String? catId,
    List<Category> categories,
  ) async {
    await ReceiptService.updateItemCategory(
      itemId: itemId,
      categoryId: catId,
      categoryLabel: CategoryMatcher.categoryLabel(catId, categories),
    );
    if (mounted) _refresh();
  }

  Future<void> _reportReceipt(_DetailData data) async {
    final lang = currentLanguage.value;
    final seq = (data.row['sequence_number'] as num?)?.toInt() ??
        widget.receipt.sequenceNumber;

    final existing = await SupportService.fetchExistingReport(
      sequenceNumber: seq,
      receiptId: widget.receiptId,
    );
    if (!mounted) return;

    if (existing != null) {
      final status = existing['status'] as String? ?? 'open';
      final statusLabel = status == 'resolved'
          ? AppStrings.get('support_status_resolved', lang)
          : AppStrings.get('support_status_open', lang);
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.get('report_already_reported', lang)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (seq != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${AppStrings.get('receipt_number', lang)}$seq',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              Text(
                '${AppStrings.get('report_existing_status', lang)}: $statusLabel',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(existing['description'] as String? ?? ''),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.get('cancel', lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.get('report_something_else', lang)),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final ctrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing != null
              ? AppStrings.get('report_new_title', lang)
              : AppStrings.get('report_receipt_title', lang),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (seq != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${AppStrings.get('receipt_number', lang)}$seq',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: AppStrings.get('report_receipt_hint', lang),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.get('cancel', lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.get('report_receipt_submit', lang)),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;
    try {
      await SupportService.submitReceiptReport(
        description: ctrl.text,
        receiptId: widget.receiptId,
        sequenceNumber: seq,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.get('report_receipt_success', lang))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text('This receipt will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await ReceiptService.delete(widget.receiptId);
        notifyReceiptsChanged();
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red.shade700,
          ));
        }
      }
    }
  }
}

class _DetailData {
  final Map<String, dynamic> row;
  final List<Category> categories;
  final bool hasFamily;

  bool get isFamilyScope => row['family_id'] != null;

  _DetailData({
    required this.row,
    required this.categories,
    required this.hasFamily,
  });
}

// ── Read-only body ─────────────────────────────────────────────────────────────

class _ReceiptBody extends StatelessWidget {
  final Receipt receipt;
  final String? currency;
  final String? fiscalId;
  final int? sequenceNumber;
  final List<Map<String, dynamic>> items;
  final List<Category> categories;
  final bool hasFamily;
  final bool isFamilyScope;
  final bool scopeUpdating;
  final void Function(bool asFamily)? onScopeChanged;
  final void Function(String? code)? onCurrencyChanged;
  final void Function(String itemId, String? catId) onCategoryChanged;

  const _ReceiptBody({
    required this.receipt,
    this.currency,
    this.fiscalId,
    this.sequenceNumber,
    required this.items,
    required this.categories,
    this.hasFamily = false,
    this.isFamilyScope = false,
    this.scopeUpdating = false,
    this.onScopeChanged,
    this.onCurrencyChanged,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(receipt: receipt, currency: currency, sequenceNumber: sequenceNumber),
        if (onCurrencyChanged != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final selected = await showCurrencyPickerSheet(
                context,
                initialCurrency: currency,
              );
              onCurrencyChanged!(selected);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currencyDisplayLabel(currency),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(Icons.expand_more,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
        if (onScopeChanged != null) ...[
          const SizedBox(height: 16),
          _FamilyScopeToggle(
            isFamily: isFamilyScope,
            updating: scopeUpdating,
            onChanged: onScopeChanged!,
          ),
          if (!hasFamily)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Create a family in Profile to share this receipt.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
        if (fiscalId != null && fiscalId!.isNotEmpty) ...[
          const SizedBox(height: 12),
          CopyableFiscalIdRow(fiscalId: fiscalId!),
        ],
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 4),
        if (items.isEmpty && receipt.items.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No items',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else if (items.isNotEmpty)
          ...items.map(
            (item) => _DbItemRow(
              item: item,
              categories: categories,
              onCategoryChanged: onCategoryChanged,
            ),
          )
        else
          ...receipt.items.map((item) => _SimpleItemRow(item: item)),
        const Divider(height: 32),
        _TotalsSection(receipt: receipt, currency: currency),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.green100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.primaryGreenDark, size: 18),
              SizedBox(width: 8),
              Text(
                'Receipt saved successfully',
                style: TextStyle(color: AppColors.primaryGreenDark, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilyScopeToggle extends StatelessWidget {
  final bool isFamily;
  final bool updating;
  final ValueChanged<bool> onChanged;

  const _FamilyScopeToggle({
    required this.isFamily,
    required this.updating,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cost scope',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ScopeChip(
                label: 'Personal',
                icon: Icons.person_outline,
                selected: !isFamily,
                onTap: updating || !isFamily ? null : () => onChanged(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ScopeChip(
                label: 'Family',
                icon: Icons.family_restroom_outlined,
                selected: isFamily,
                onTap: updating || isFamily ? null : () => onChanged(true),
              ),
            ),
          ],
        ),
        if (updating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}

class _ScopeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _ScopeChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedFg = scheme.onSurfaceVariant;
    final bg = selected
        ? (isDark ? scheme.primaryContainer : AppColors.green100)
        : (isDark ? scheme.surfaceContainerHighest : Colors.grey.shade100);
    final border = selected
        ? AppColors.primaryGreen(Theme.of(context).brightness)
        : scheme.outlineVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? AppColors.primaryGreen(Theme.of(context).brightness)
                    : unselectedFg,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? AppColors.primaryGreen(Theme.of(context).brightness)
                      : unselectedFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Receipt receipt;
  final String? currency;
  final int? sequenceNumber;
  const _Header({required this.receipt, this.currency, this.sequenceNumber});

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.green100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long, color: AppColors.primaryGreenDark, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                receipt.store ?? 'Unknown Store',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (sequenceNumber != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${AppStrings.get('receipt_number', currentLanguage.value)}$sequenceNumber',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (receipt.date != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDate(receipt.date!),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Text(
          formatMoney(receipt.total, currency ?? receipt.currency),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreenDark,
          ),
        ),
      ],
    );
  }
}

class _DbItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Category> categories;
  final void Function(String itemId, String? catId) onCategoryChanged;

  const _DbItemRow({
    required this.item,
    required this.categories,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final id = item['id'] as String;
    final name = item['product_name'] as String? ??
        item['name_raw'] as String? ??
        item['name'] as String? ??
        '';
    final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final totalPrice = (item['total_price'] as num?)?.toDouble() ?? 0.0;
    final catId = item['category_id'] as String?;
    final catLabel = item['category'] as String?;
    final cat = catId != null
        ? categories.where((c) => c.id == catId).firstOrNull
        : (catLabel != null
            ? categories
                .where((c) => c.name.toLowerCase() == catLabel.toLowerCase())
                .firstOrNull
            : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (qty != 1.0)
                  Text(
                    '$qty × ${unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                GestureDetector(
                  onTap: () => _pickCategory(context, id, catId),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat != null ? Icons.label : Icons.label_outline,
                          size: 13,
                          color: cat != null
                              ? Color(cat.color)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          cat?.name ?? 'Add category',
                          style: TextStyle(
                            fontSize: 11,
                            color: cat != null
                                ? Color(cat.color)
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            totalPrice.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCategory(
      BuildContext context, String itemId, String? currentCatId) async {
    final selected = await showCategoryPickerSheet(
      context,
      categories: categories,
      selectedId: currentCatId,
    );
    if (selected != currentCatId) {
      onCategoryChanged(itemId, selected);
    }
  }
}

class _SimpleItemRow extends StatelessWidget {
  final ReceiptItem item;
  const _SimpleItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (item.quantity != 1.0)
                  Text(
                    '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            item.totalPrice.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsSection extends StatelessWidget {
  final Receipt receipt;
  final String? currency;
  const _TotalsSection({required this.receipt, this.currency});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (receipt.subtotal > 0 && receipt.subtotal != receipt.total)
          _TotalRow(label: 'Subtotal', value: receipt.subtotal, currency: currency ?? receipt.currency),
        // VAT TRACKER: Hidden — requires government ƏDV
        // API integration. Do not delete.
        // Re-enable when API is available.
        // HIDDEN: VAT tracker disabled — requires government DVX API (Phase 2). Do not delete.
        // VAT TRACKER: Hidden — requires government ƏDV
        // API integration. Do not delete.
        // Re-enable when API is available.
        // if (receipt.vat > 0) _TotalRow(label: 'VAT', value: receipt.vat, currency: receipt.currency),
        _TotalRow(label: 'Total', value: receipt.total, currency: currency ?? receipt.currency, bold: true),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final String? currency;
  final bool bold;
  const _TotalRow({
    required this.label,
    required this.value,
    required this.currency,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            formatMoney(value, currency),
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold
                  ? AppColors.primaryGreenDark
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
