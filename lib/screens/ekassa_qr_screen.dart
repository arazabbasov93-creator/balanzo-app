import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/ekassa_service.dart';
import '../models/receipt.dart';
import 'receipt_result_sheet.dart';
import 'receipt_save_success_screen.dart';

class EkassaQrScreen extends StatefulWidget {
  const EkassaQrScreen({super.key});

  @override
  State<EkassaQrScreen> createState() => _EkassaQrScreenState();
}

class _EkassaQrScreenState extends State<EkassaQrScreen> {
  final _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _processing = false;
  String? _status;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;

    final docId = EkassaService.extractDocumentId(raw);
    if (docId == null) {
      setState(() => _status = 'Not an e-kassa QR — try again');
      return;
    }

    setState(() {
      _processing = true;
      _status = 'Fetching receipt $docId…';
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan e-kassa QR'),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
