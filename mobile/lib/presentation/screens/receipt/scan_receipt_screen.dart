import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/services/ocr_service.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key, required this.hangoutId});

  final String hangoutId;

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isProcessing = false;
  String? _errorMessage;

  final _ocr = OcrService();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController(_cameras.first);
    }
  }

  // ── Camera init ───────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera found on this device.';
          _isInitializing = false;
        });
        return;
      }
      await _initCameraController(_cameras.first);
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not access camera.\nCheck permissions in Settings.';
        _isInitializing = false;
      });
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      if (mounted) setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Camera error: ${e.runtimeType}';
          _isInitializing = false;
        });
      }
    }
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  Future<void> _captureAndProcess() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final xFile = await controller.takePicture();
      await _processImage(xFile.path);
    } catch (e) {
      _showError('Failed to capture photo. Please try again.');
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;

    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (xFile == null) return;

    setState(() => _isProcessing = true);
    await _processImage(xFile.path);
  }

  Future<void> _processImage(String imagePath) async {
    try {
      final result = await _ocr.recognizeFromPath(imagePath);
      if (!mounted) return;

      if (result.items.isEmpty) {
        _showError(
          'No items detected on this receipt.\nTry a clearer photo or add items manually.',
        );
        setState(() => _isProcessing = false);
        return;
      }

      // Navigate to review screen with parsed data.
      context.push(
        '/hangout/${widget.hangoutId}/review',
        extra: _ScanPayload(imagePath: imagePath, result: result),
      );
    } catch (e) {
      if (mounted) {
        _showError('OCR failed. Try again or add items manually.');
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera preview ──────────────────────────────────────────────
          _buildCameraLayer(),

          // ── Viewfinder overlay ──────────────────────────────────────────
          if (!_isInitializing && _errorMessage == null)
            const _ViewfinderOverlay(),

          // ── Top bar ─────────────────────────────────────────────────────
          SafeArea(child: _buildTopBar()),

          // ── Bottom controls ─────────────────────────────────────────────
          if (!_isInitializing && _errorMessage == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomControls(),
            ),

          // ── Processing overlay ──────────────────────────────────────────
          if (_isProcessing) const _ProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white54, size: 56),
              const SizedBox(height: AppSpacing.base),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined,
                    color: Colors.white),
                label: Text('Pick from gallery',
                    style: AppTypography.button.copyWith(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
          ),
          const Spacer(),
          Text(
            'Scan receipt',
            style: AppTypography.h3.copyWith(color: Colors.white),
          ),
          const Spacer(),
          // Placeholder to balance layout
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Align receipt within the frame',
            style: AppTypography.caption.copyWith(color: Colors.white70),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gallery
              _CircleIconButton(
                icon: Icons.photo_library_outlined,
                size: 48,
                onTap: _pickFromGallery,
                label: 'Gallery',
              ),

              // Capture
              _CaptureButton(onTap: _captureAndProcess),

              // Manual entry (placeholder for Part 4)
              _CircleIconButton(
                icon: Icons.edit_outlined,
                size: 48,
                onTap: () => context.push(
                  '/hangout/${widget.hangoutId}/review',
                  extra: _ScanPayload(imagePath: null, result: null),
                ),
                label: 'Manual',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ViewfinderPainter());
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const margin = 40.0;
    const cornerLen = 24.0;
    final rect = Rect.fromLTRB(margin, size.height * 0.15,
        size.width - margin, size.height * 0.78);

    // Dim everything outside the rect
    final dimPaint = Paint()..color = Colors.black45;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);

    // Corner brackets
    for (final corner in [
      [rect.topLeft, 1.0, 1.0],
      [rect.topRight, -1.0, 1.0],
      [rect.bottomLeft, 1.0, -1.0],
      [rect.bottomRight, -1.0, -1.0],
    ]) {
      final o = corner[0] as Offset;
      final dx = (corner[1] as double) * cornerLen;
      final dy = (corner[2] as double) * cornerLen;
      canvas.drawLine(o, Offset(o.dx + dx, o.dy), paint);
      canvas.drawLine(o, Offset(o.dx, o.dy + dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white30),
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(
              label!,
              style: AppTypography.label.copyWith(color: Colors.white70),
            ),
          ],
        ],
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
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: AppSpacing.base),
            Text(
              'Reading receipt…',
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

// ── Payload passed to review screen ──────────────────────────────────────────

class ScanPayload {
  const ScanPayload({this.imagePath, this.result});
  final String? imagePath;
  final OcrResult? result;
}

// Private alias used inside this file only
typedef _ScanPayload = ScanPayload;
