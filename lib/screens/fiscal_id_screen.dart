import 'package:flutter/material.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/ekassa_service.dart';
import '../models/receipt.dart';
import 'receipt_result_sheet.dart';
import 'receipt_save_success_screen.dart';
import 'ekassa_qr_screen.dart';

class FiscalIdScreen extends StatefulWidget {
  const FiscalIdScreen({super.key});

  @override
  State<FiscalIdScreen> createState() => _FiscalIdScreenState();
}

class _FiscalIdScreenState extends State<FiscalIdScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final lang = currentLanguage.value;
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = AppStrings.get('fiscal_id_required', lang));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final receipt = await EkassaService.fetchAndParse(raw);
      if (!mounted) return;
      _showResult(receipt);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showResult(Receipt receipt) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptResultSheet(
        receipt: receipt,
        onRetake: () => Navigator.of(context).pop('retake'),
      ),
    );
    if (!mounted) return;
    if (result is ReceiptSaveResult) {
      await _showSaveSuccess();
    }
  }

  Future<void> _showSaveSuccess() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => ReceiptSaveSuccessScreen(
          onScanAnother: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop(true);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EkassaQrScreen()),
            );
          },
          onGoHome: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          AppStrings.get('enter_fiscal_id', lang),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.get('fiscal_document_id', lang),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.url,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: AppStrings.get('fiscal_id_hint', lang),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                errorText: _error,
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _ctrl.clear();
                          _error = null;
                        }),
                      )
                    : null,
              ),
              onSubmitted: (_) => _fetch(),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.get('fiscal_id_help', lang),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _fetch,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _loading
                      ? AppStrings.get('processing_receipt', lang)
                      : AppStrings.get('fetch_receipt', lang),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _EkassaNote(lang: lang),
          ],
        ),
      ),
    );
  }
}

class _EkassaNote extends StatelessWidget {
  final String lang;

  const _EkassaNote({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, color: Color(0xFF1B5E20), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.get('fiscal_ekassa_note', lang),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1B5E20),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
