import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/ekassa_service.dart';
import '../models/receipt.dart';
import 'fiscal_id_screen.dart';
import 'manual_entry_screen.dart';
import 'receipt_result_sheet.dart';
import 'receipt_save_success_screen.dart';
import '../config/app_colors.dart';

/// 2D symbologies used on e-kassa receipts — excludes linear product barcodes.
enum _EkassaMode { qr, fiscalId, manual }

const _ekassa2dFormats = <BarcodeFormat>[
  BarcodeFormat.qrCode,
  BarcodeFormat.dataMatrix,
  BarcodeFormat.aztec,
  BarcodeFormat.pdf417,
];

class EkassaQrScreen extends StatefulWidget {
  const EkassaQrScreen({super.key});

  @override
  State<EkassaQrScreen> createState() => _EkassaQrScreenState();
}

class _EkassaQrScreenState extends State<EkassaQrScreen> {
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: _ekassa2dFormats,
  );
  bool _processing = false;
  String? _status;
  _EkassaMode _mode = _EkassaMode.qr;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  String? _pickEkassaPayload(BarcodeCapture capture) {
    bool is2d(BarcodeFormat f) => _ekassa2dFormats.contains(f);

    final barcodes = capture.barcodes
        .where((b) => b.rawValue?.trim().isNotEmpty ?? false)
        .toList()
      ..sort((a, b) {
        final a2d = is2d(a.format);
        final b2d = is2d(b.format);
        if (a2d != b2d) return a2d ? -1 : 1;
        return 0;
      });

    return EkassaService.pickDocumentIdFromRawValues(
      barcodes.map((b) => b.rawValue!),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = _pickEkassaPayload(capture);
    if (raw == null) return;

    final docId = EkassaService.extractDocumentId(raw)!;
    setState(() {
      _processing = true;
      _status = AppStrings.get('fetching_receipt', currentLanguage.value)
          .replaceFirst('{id}', docId);
    });
    await _scannerCtrl.stop();

    try {
      final receipt = await EkassaService.fetchAndParse(raw);
      if (!mounted) return;
      await _showResult(receipt);
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = e.toString().replaceFirst('Exception: ', '');
          _processing = false;
        });
        await _scannerCtrl.start();
      }
    }
  }

  Future<void> _openFiscalId() async {
    await _scannerCtrl.stop();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const FiscalIdScreen()),
    );
    if (mounted && !_processing) await _scannerCtrl.start();
  }

  Future<void> _openManualEntry() async {
    await _scannerCtrl.stop();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
    );
    if (mounted && !_processing) await _scannerCtrl.start();
  }

  Future<void> _showResult(Receipt receipt) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptResultSheet(
        receipt: receipt,
        onRetake: () => Navigator.of(context).pop('retake'),
      ),
    );
    if (!mounted) return;

    if (result is ReceiptSaveResult) {
      await _showSaveSuccess();
      return;
    }

    setState(() {
      _processing = false;
      _status = null;
    });
    await _scannerCtrl.start();
  }

  Future<void> _showSaveSuccess() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => ReceiptSaveSuccessScreen(
          onScanAnother: () {
            Navigator.of(ctx).pop();
            if (!mounted) return;
            setState(() {
              _processing = false;
              _status = null;
            });
            _scannerCtrl.start();
          },
          onGoHome: () {
            Navigator.of(ctx).pop();
            if (mounted) Navigator.of(context).pop(true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = currentLanguage.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(AppStrings.get('scan_ekassa_qr', lang)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.green400, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            top: 72,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ModeChip(
                  label: AppStrings.get('scan_qr_code', lang),
                  selected: _mode == _EkassaMode.qr,
                  onTap: () => setState(() => _mode = _EkassaMode.qr),
                ),
                const SizedBox(width: 8),
                _ModeChip(
                  label: AppStrings.get('enter_fiscal_id', lang),
                  selected: _mode == _EkassaMode.fiscalId,
                  onTap: () => setState(() => _mode = _EkassaMode.fiscalId),
                ),
                const SizedBox(width: 8),
                _ModeChip(
                  label: AppStrings.get('manual_entry', lang),
                  selected: _mode == _EkassaMode.manual,
                  onTap: () => setState(() => _mode = _EkassaMode.manual),
                ),
              ],
            ),
          ),
          if (_mode == _EkassaMode.qr)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: Text(
                AppStrings.get('scan_qr_hint', lang),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          if (_mode == _EkassaMode.qr)
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_status != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _status!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  if (_processing) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: AppColors.green400),
                  ],
                  if (!_processing) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openFiscalId,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(AppStrings.get('enter_fiscal_manually', lang)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.green300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _openManualEntry,
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text(AppStrings.get('manual_entry', lang)),
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryGreenDark : Colors.white24,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
