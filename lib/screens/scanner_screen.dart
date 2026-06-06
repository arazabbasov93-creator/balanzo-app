import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ocr_service.dart';
import '../services/ekassa_service.dart';
import 'receipt_result_sheet.dart';
import '../config/app_colors.dart';
// HIDDEN: Disabled — requires government DVX API (Phase 2). Do not delete.
// import 'fiscal_id_screen.dart';

// QR mode removed — DVX API Phase 2. fiscal_id_screen.dart preserved for future use.
enum _ScanMode { receipt }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  _ScanMode _mode = _ScanMode.receipt;

  CameraController? _camCtrl;
  bool _camReady = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camCtrl?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_camCtrl == null) return;
    if (state == AppLifecycleState.inactive) {
      _camCtrl!.dispose();
      _camCtrl = null;
      if (mounted) setState(() => _camReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (Platform.isAndroid) {
      final status = await Permission.camera.request();
      if (!status.isGranted) return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty || !mounted) return;

    final ctrl = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await ctrl.initialize();
    if (!mounted) {
      ctrl.dispose();
      return;
    }
    setState(() {
      _camCtrl = ctrl;
      _camReady = true;
    });
  }

  // HIDDEN: DVX API Phase 2 — reserved; do not delete.
  // ignore: unused_element
  Future<void> _switchMode(_ScanMode mode) async {
    if (mode == _mode) return;
    setState(() => _camReady = false);
    await _initCamera();
    if (mounted) setState(() => _mode = mode);
  }

  // T38: capture from live camera → ML Kit OCR → print to console
  Future<void> _captureAndOcr() async {
    if (!_camReady || _camCtrl == null || _processing) return;
    setState(() => _processing = true);
    try {
      final file = await _camCtrl!.takePicture();
      final text = await OcrService.recognizeText(file.path);
      debugPrint('=== OCR RESULT ===\n$text\n==================');
      _showResult(text);
    } catch (e) {
      debugPrint('OCR capture error: $e');
      _showSnack('OCR failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // T39: pick from gallery → ML Kit OCR → print to console
  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;
    setState(() => _processing = true);
    try {
      final text = await OcrService.recognizeText(file.path);
      debugPrint('=== OCR RESULT (gallery) ===\n$text\n==================');
      _showResult(text);
    } catch (e) {
      debugPrint('OCR gallery error: $e');
      _showSnack('OCR failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // HIDDEN: DVX API Phase 2 — reserved; do not delete.
  // ignore: unused_element
  Future<void> _handleQrValue(String value) async {
    final docId = EkassaService.extractDocumentId(value);
    if (docId == null) {
      // Not an e-kassa QR — just show the raw value
      _showSnack('QR: $value');
      return;
    }

    // e-kassa fiscal QR detected
    _showSnack('e-kassa QR detected — fetching receipt…');
    if (mounted) setState(() => _processing = true);
    try {
      final receipt = await EkassaService.fetchAndParse(docId);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ReceiptResultSheet(
          receipt: receipt,
          onRetake: () {
            Navigator.of(context).pop();
          },
        ),
      );
    } catch (e) {
      debugPrint('e-kassa fetch error: $e');
      if (mounted) {
        _showSnack(
          'Could not fetch receipt: ${e.toString().replaceFirst('Exception: ', '')}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showResult(String text) {
    if (!mounted) return;
    final lines = text.trim().split('\n').where((l) => l.trim().isNotEmpty).length;
    _showSnack(text.isEmpty ? 'No text found' : 'Extracted $lines lines of text');
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : AppColors.primaryGreenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraView(),
          _buildOverlay(),
          _buildTopBar(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
          if (_processing) const _ProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    if (!_camReady || _camCtrl == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _camCtrl!.value.previewSize?.height ?? 1,
          height: _camCtrl!.value.previewSize?.width ?? 1,
          child: CameraPreview(_camCtrl!),
        ),
      ),
    );
  }

  // T36: semi-transparent overlay with corner markers
  Widget _buildOverlay() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final scanW = w * 0.82;
      final scanH = scanW * 1.45;
      final scanRect = Rect.fromCenter(
        center: Offset(w / 2, h * 0.44),
        width: scanW,
        height: scanH,
      );
      return CustomPaint(
        painter: _ScannerOverlayPainter(scanRect: scanRect),
      );
    });
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            const Text(
              'Scan Receipt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white),
              tooltip: 'Pick from gallery',
              onPressed: _processing ? null : _pickFromGallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _processing ? null : _captureAndOcr,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.black87, size: 34),
                  ),
                ),
                // HIDDEN: Disabled — requires government DVX API (Phase 2). Do not delete.
                // TextButton.icon(onPressed: () => Navigator.push FiscalIdScreen),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Overlay painter (T36) ──────────────────────────────────────────────────────

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;

  const _ScannerOverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay with transparent cutout
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha:0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(6)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    // Corner markers
    final paint = Paint()
      ..color = AppColors.green400
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 22.0;

    void corner(Offset pt, double dx, double dy) {
      canvas.drawLine(pt, pt.translate(dx * arm, 0), paint);
      canvas.drawLine(pt, pt.translate(0, dy * arm), paint);
    }

    corner(scanRect.topLeft, 1, 1);
    corner(scanRect.topRight, -1, 1);
    corner(scanRect.bottomLeft, 1, -1);
    corner(scanRect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) => old.scanRect != scanRect;
}

// ── Supporting widgets ─────────────────────────────────────────────────────────

// HIDDEN: DVX API Phase 2 — reserved; do not delete.
// ignore: unused_element
class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: selected ? Colors.black87 : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black87 : Colors.white,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Processing...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
