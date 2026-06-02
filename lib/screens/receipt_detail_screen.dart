import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/receipt.dart';
import '../models/category.dart';
import '../services/receipt_service.dart';
import '../services/category_service.dart';
import '../widgets/category_picker_sheet.dart';
import '../widgets/copyable_fiscal_id.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Editable item state ────────────────────────────────────────────────────────

class _ItemEdit {
  final String? id; // null if new
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _ItemEdit({
    this.id,
    required String name,
    required double qty,
    required double price,
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(
            text: qty == qty.roundToDouble()
                ? qty.toInt().toString()
                : qty.toStringAsFixed(2)),
        priceCtrl = TextEditingController(text: price.toStringAsFixed(2));

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
  bool _refreshing = false;
  TextEditingController? _storeCtrl;
  TextEditingController? _dateCtrl;
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
    final data = _DetailData(row: row, categories: cats);
    _cachedData = data;
    return data;
  }

  void _refresh() => setState(() => _future = _load());

  // ── Edit mode ──────────────────────────────────────────────────────────────

  void _enterEditMode(_DetailData data) {
    final row = data.row;
    _storeCtrl = TextEditingController(text: row['store_name'] as String? ?? '');
    _dateCtrl = TextEditingController(text: row['purchase_date'] as String? ?? '');
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
            ))
        .toList();
    setState(() => _editMode = true);
  }

  void _disposeEditControllers() {
    _storeCtrl?.dispose();
    _storeCtrl = null;
    _dateCtrl?.dispose();
    _dateCtrl = null;
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
      final supabase = Supabase.instance.client;

      // Update receipt header
      await supabase.from('receipts').update({
        'store_name': _storeCtrl!.text.trim(),
        'purchase_date': _dateCtrl!.text.trim().isEmpty ? null : _dateCtrl!.text.trim(),
      }).eq('id', widget.receiptId);

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
          'total_price': qty * unitPrice,
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.receipt.store ?? 'Receipt'),
        backgroundColor: const Color(0xFF1B5E20),
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
                if (_cachedData?.row['fiscal_id'] != null)
                  IconButton(
                    icon: _refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.sync),
                    tooltip: 'Refresh from e-kassa',
                    onPressed: _refreshing || _cachedData == null
                        ? null
                        : () => _confirmRefreshFromEkassa(_cachedData!),
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
        return _ReceiptBody(
          receipt: widget.receipt,
          fiscalId: data.row['fiscal_id'] as String?,
          items: rowItems,
          categories: data.categories,
          onCategoryChanged: (itemId, catId) => _assignCategory(itemId, catId),
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
        const SizedBox(height: 20),
        const Divider(),
        Row(
          children: [
            Text('Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _itemEdits.add(_ItemEdit(name: '', qty: 1, price: 0));
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B5E20)),
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
              borderRadius: BorderRadius.circular(10),
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

  Future<void> _assignCategory(String itemId, String? catId) async {
    await Supabase.instance.client
        .from('receipt_items')
        .update({'category_id': catId})
        .eq('id', itemId);
    if (mounted) _refresh();
  }

  Future<void> _confirmRefreshFromEkassa(_DetailData data) async {
    final fiscalId = data.row['fiscal_id'] as String?;
    if (fiscalId == null || fiscalId.isEmpty) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refresh from e-kassa'),
        content: const Text(
          'Re-download the official receipt and re-parse line items.\n\n'
          'Cost: free (government API + on-device OCR). '
          'Your category edits are kept when item names match.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    setState(() => _refreshing = true);
    try {
      await ReceiptService.refreshFromFiscalId(widget.receiptId);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt refreshed from e-kassa'),
            backgroundColor: Color(0xFF1B5E20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
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
  _DetailData({required this.row, required this.categories});
}

// ── Read-only body ─────────────────────────────────────────────────────────────

class _ReceiptBody extends StatelessWidget {
  final Receipt receipt;
  final String? fiscalId;
  final List<Map<String, dynamic>> items;
  final List<Category> categories;
  final void Function(String itemId, String? catId) onCategoryChanged;

  const _ReceiptBody({
    required this.receipt,
    this.fiscalId,
    required this.items,
    required this.categories,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Header(receipt: receipt),
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
        _TotalsSection(receipt: receipt),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF1B5E20), size: 18),
              SizedBox(width: 8),
              Text(
                'Receipt saved successfully',
                style: TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Receipt receipt;
  const _Header({required this.receipt});

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
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.receipt_long, color: Color(0xFF1B5E20), size: 30),
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
          '${receipt.total.toStringAsFixed(2)} ${receipt.currency}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
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
    final cat = catId != null
        ? categories.where((c) => c.id == catId).firstOrNull
        : null;

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
  const _TotalsSection({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (receipt.subtotal > 0 && receipt.subtotal != receipt.total)
          _TotalRow(label: 'Subtotal', value: receipt.subtotal, currency: receipt.currency),
        // HIDDEN: VAT tracker disabled — requires government DVX API (Phase 2). Do not delete.
        // if (receipt.vat > 0) _TotalRow(label: 'VAT', value: receipt.vat, currency: receipt.currency),
        _TotalRow(label: 'Total', value: receipt.total, currency: receipt.currency, bold: true),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
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
            '${value.toStringAsFixed(2)} $currency',
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold
                  ? const Color(0xFF1B5E20)
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
