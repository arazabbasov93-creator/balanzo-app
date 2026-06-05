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

/// 2D symbologies used on e-kassa receipts — excludes linear product barcodes.
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
                border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
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
                  const CircularProgressIndicator(color: Color(0xFF4CAF50)),
                ],
                if (!_processing) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openFiscalId,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(AppStrings.get('enter_fiscal_manually', lang)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF81C784)),
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
