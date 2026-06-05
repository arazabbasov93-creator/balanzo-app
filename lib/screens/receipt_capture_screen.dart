import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../models/receipt.dart';
import '../services/analytics_service.dart';
import '../services/receipt_ocr_pipeline.dart';
import 'ekassa_qr_screen.dart';
import 'fiscal_id_screen.dart';
import 'manual_entry_screen.dart';
import 'receipt_result_sheet.dart';

class ReceiptCaptureScreen extends StatefulWidget {
  final bool isGuestMode;
  const ReceiptCaptureScreen({super.key, this.isGuestMode = false});

  @override
  State<ReceiptCaptureScreen> createState() => _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends State<ReceiptCaptureScreen>
    with WidgetsBindingObserver {
  bool _qrProcessing = false;

  // Photo camera
  CameraController? _cam;
  bool _camReady = false;
  final List<String> _paths = [];
  bool _processing = false;

  static const _maxPhotos = 10;

  static const _photoHints = [
    'Start at the top of the receipt',
    'Overlap slightly — capture the middle',
    'Capture the bottom of the receipt',
    'Add more sections or tap Process.',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _cam?.dispose();
      _cam = null;
      if (mounted) setState(() => _camReady = false);
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (Platform.isAndroid) {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          _snack('Camera permission is required to scan receipts.', error: true);
        }
        return;
      }
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
      _cam = ctrl;
      _camReady = true;
    });
  }

  Future<void> _switchToPhotoMode() async {
    await _initCamera();
  }


  Future<void> _capture() async {
    if (!_camReady || _cam == null || _processing || _paths.length >= _maxPhotos) return;
    try {
      final file = await _cam!.takePicture();
      setState(() => _paths.add(file.path));
    } catch (e) {
      _snack('Capture failed: $e', error: true);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_paths.length >= _maxPhotos || _processing) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    // Reinit camera after gallery, regardless of result
    await _cam?.dispose();
    _cam = null;
    if (mounted) setState(() => _camReady = false);
    await _initCamera();

    if (file == null || !mounted) return;
    setState(() => _paths.add(file.path));
  }

  Future<void> _process() async {
    if (_paths.isEmpty || _processing) return;
    setState(() => _processing = true);
    try {
      final receipt = await ReceiptOcrPipeline.parseImages(_paths);
      debugPrint('=== PARSED RECEIPT ===\n${receipt.toJson()}\n=====================');
      debugPrint('=== PARSED RECEIPT ===\n${receipt.toJson()}\n=====================');
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('first_scan_done') ?? false)) {
        await AnalyticsService.log(
          'first_scan_completed',
          {'store': (receipt.store ?? 'unknown') as Object},
        );
        await prefs.setBool('first_scan_done', true);
      }
      _showReceiptResult(receipt);
    } catch (e) {
      debugPrint('Process error: $e');
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('Could not read text')) {
        _snack('No text detected. Try better lighting or use the gallery button.', error: true);
      } else {
        _snack('Processing failed: $msg', error: true);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showReceiptResult(Receipt receipt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptResultSheet(
        receipt: receipt,
        onRetake: () {
          Navigator.of(context).pop();
          setState(() {
            _paths.clear();
            _qrProcessing = false;
          });
        },
      ),
    ).then((result) {
      if (result is ReceiptSaveResult && mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  void _removePhoto(int index) => setState(() => _paths.removeAt(index));

  Future<void> _openEkassaQrScanner() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const EkassaQrScreen()),
    );
  }

  Future<void> _enterFiscalId() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const FiscalIdScreen()),
    );
  }

  Future<void> _openManualEntry() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // HIDDEN: DVX API Phase 2 — _buildQrView() reserved; do not delete.
          _buildCameraView(),
          _buildOverlay(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 6),
                Center(child: _buildGuideBanner()),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            // HIDDEN: DVX API Phase 2 — _buildQrControls() reserved; do not delete.
            child: _buildPhotoControls(),
          ),
          if (_processing || _qrProcessing) _ProcessingOverlay(),
        ],
      ),
    );
  }

  // HIDDEN: DVX API Phase 2 — reserved; do not delete.
  // ignore: unused_element
  Widget _buildQrView() {
    // QR scanning removed — requires government DVX API (Phase 2). See ekassa_service.dart.
    return const SizedBox.shrink();
  }

  Widget _buildCameraView() {
    if (!_camReady || _cam == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cam!.value.previewSize?.height ?? 1,
          height: _cam!.value.previewSize?.width ?? 1,
          child: CameraPreview(_cam!),
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final scanW = w * 0.88;
      final scanH = scanW * 1.55;
      final scanRect = Rect.fromCenter(
        center: Offset(w / 2, h * 0.43),
        width: scanW,
        height: scanH,
      );
      return CustomPaint(painter: _OverlayPainter(scanRect: scanRect));
    });
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Text(
            AppStrings.get('scan_receipt', currentLanguage.value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4)],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            tooltip: AppStrings.get('scan_ekassa_qr', currentLanguage.value),
            onPressed: _openEkassaQrScanner,
          ),
        ],
      ),
    );
  }

  Widget _buildGuideBanner() {
    // HIDDEN: QR scanning disabled — requires government DVX API (Phase 2). Do not delete.
    // if (_qrMode) { return Container(QR hint banner); }
    final hintIndex = _paths.length.clamp(0, _photoHints.length - 1);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.white70, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _photoHints[hintIndex],
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${_paths.length}/$_maxPhotos',
            style: const TextStyle(
              color: Color(0xFF81C784),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // HIDDEN: DVX API Phase 2 — reserved; do not delete.
  // ignore: unused_element
  Widget _buildQrControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _qrProcessing ? null : _switchToPhotoMode,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(AppStrings.get('scan_photo_instead', currentLanguage.value)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoControls() {
    final lang = currentLanguage.value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_paths.isNotEmpty) ...[
              _buildPhotoStrip(),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _openEkassaQrScanner,
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: Text(AppStrings.get('scan_ekassa_qr', lang)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF81C784)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _enterFiscalId,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      AppStrings.get('enter_fiscal_id', lang),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : _openManualEntry,
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: Text(
                      AppStrings.get('manual_entry', lang),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_paths.length < _maxPhotos && !_processing && _camReady) ? _capture : null,
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: Text(AppStrings.get('take_photo', lang)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(AppStrings.get('upload_from_gallery', lang)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
              ),
            ),
            if (_paths.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _process,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(AppStrings.get('process_receipt', currentLanguage.value)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoStrip() {
    final totalSlots = _paths.length < _maxPhotos ? _paths.length + 1 : _paths.length;
    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: totalSlots,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: i < _paths.length
              ? _FilledSlot(path: _paths[i], index: i, onRemove: _removePhoto)
              : _EmptySlot(index: i),
        ),
      ),
    );
  }
}

// ── Photo strip slots ──────────────────────────────────────────────────────────

class _FilledSlot extends StatelessWidget {
  final String path;
  final int index;
  final ValueChanged<int> onRemove;

  const _FilledSlot({
    required this.path,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(path),
            width: 58,
            height: 68,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => onRemove(index),
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
        Positioned(
          bottom: 3,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySlot extends StatelessWidget {
  final int index;
  const _EmptySlot({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(color: Colors.white38, fontSize: 18),
        ),
      ),
    );
  }
}

// ── Overlay painter ────────────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final Rect scanRect;
  const _OverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scanRect, const Radius.circular(6)),
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    final paint = Paint()
      ..color = const Color(0xFF4CAF50)
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
  bool shouldRepaint(_OverlayPainter old) => old.scanRect != scanRect;
}

// ── Processing overlay ─────────────────────────────────────────────────────────

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            Text(
              AppStrings.get('processing_receipt', currentLanguage.value),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
