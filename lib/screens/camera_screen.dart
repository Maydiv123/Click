import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'image_review_screen.dart';
import '../models/map_location.dart';

class CameraScreen extends StatefulWidget {
  final MapLocation? location;

  const CameraScreen({
    Key? key,
    this.location,
  }) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<File> _capturedImages = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  final GlobalKey _previewKey = GlobalKey();
  double _currentZoom = 1.0;
  final List<double> _zoomLevels = [0.6, 1.0, 2.0];
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to take photos')),
        );
      }
      return;
    }

    // Get available cameras
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cameras available')),
        );
      }
      return;
    }

    // Initialize camera controller
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error initializing camera')),
        );
      }
    }
  }

  Future<File> _addWatermark(File imageFile) async {
    // Create a temporary directory for the watermarked image
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final watermarkedPath = '$tempPath/watermarked_$timestamp.jpg';

    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Load the original image
    final image = await decodeImageFromList(await imageFile.readAsBytes());
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    // Draw the original image
    canvas.drawImage(image, Offset.zero, Paint());

    // Prepare watermark content
    final now = DateTime.now();
    final dateTimeStr = DateFormat('dd/MM/yyyy hh:mm a').format(now);
    final locationName = widget.location?.location ?? 'Unknown Location';
    final address = widget.location?.addressLine1 ?? '';
    final coordinates = widget.location != null
        ? 'Lat ${widget.location!.latitude.toStringAsFixed(6)}  Long ${widget.location!.longitude.toStringAsFixed(6)}'
        : '';
    final zoomStr = _currentZoom == 1.0 ? '1x' : '${_currentZoom}x';

    // Card dimensions
    final double cardWidth = imageWidth * 0.92;
    final double cardPadding = 18;
    final double cardHeight = imageHeight * 0.19;
    final double cardLeft = (imageWidth - cardWidth) / 2;
    final double cardTop = imageHeight - cardHeight - imageHeight * 0.025;
    final double borderRadius = 24;

    // Draw card background (semi-transparent black with rounded corners)
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withOpacity(0.75),
    );

    // Prepare text styles
    final locationStyle = TextStyle(
      color: Colors.white,
      fontSize: imageWidth * 0.045,
      fontWeight: FontWeight.bold,
    );
    final addressStyle = TextStyle(
      color: Colors.white.withOpacity(0.85),
      fontSize: imageWidth * 0.032,
      fontWeight: FontWeight.w400,
    );
    final coordStyle = TextStyle(
      color: Colors.white.withOpacity(0.85),
      fontSize: imageWidth * 0.032,
      fontWeight: FontWeight.w400,
    );
    final dateStyle = TextStyle(
      color: Colors.white.withOpacity(0.85),
      fontSize: imageWidth * 0.032,
      fontWeight: FontWeight.w400,
    );
    final badgeStyle = TextStyle(
      color: Colors.black,
      fontSize: imageWidth * 0.032,
      fontWeight: FontWeight.bold,
    );

    // Layout text
    final textPainter1 = TextPainter(
      text: TextSpan(text: locationName, style: locationStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cardWidth - 2 * cardPadding);
    final textPainter2 = TextPainter(
      text: TextSpan(text: address, style: addressStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: cardWidth - 2 * cardPadding);
    final textPainter3 = TextPainter(
      text: TextSpan(text: coordinates, style: coordStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cardWidth - 2 * cardPadding);
    final textPainter4 = TextPainter(
      text: TextSpan(text: dateTimeStr, style: dateStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cardWidth - 2 * cardPadding - 60);

    // Draw text
    double y = cardTop + cardPadding;
    textPainter1.paint(canvas, Offset(cardLeft + cardPadding, y));
    y += textPainter1.height + 4;
    textPainter2.paint(canvas, Offset(cardLeft + cardPadding, y));
    y += textPainter2.height + 2;
    textPainter3.paint(canvas, Offset(cardLeft + cardPadding, y));
    y += textPainter3.height + 10;

    // Draw zoom badge and date/time in a row
    final badgeWidth = 48.0;
    final badgeHeight = 28.0;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft + cardPadding, y, badgeWidth, badgeHeight),
      Radius.circular(8),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xFFFFD600),
    );
    final badgePainter = TextPainter(
      text: TextSpan(text: zoomStr, style: badgeStyle),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: badgeWidth);
    badgePainter.paint(
      canvas,
      Offset(cardLeft + cardPadding + (badgeWidth - badgePainter.width) / 2, y + (badgeHeight - badgePainter.height) / 2),
    );
    // Date/time to the right of badge
    textPainter4.paint(canvas, Offset(cardLeft + cardPadding + badgeWidth + 12, y + (badgeHeight - textPainter4.height) / 2));

    // Convert the canvas to an image
    final picture = recorder.endRecording();
    final img = await picture.toImage(imageWidth.toInt(), imageHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // Save the watermarked image
    final watermarkedFile = File(watermarkedPath);
    await watermarkedFile.writeAsBytes(pngBytes);

    return watermarkedFile;
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile photo = await _controller!.takePicture();
      final watermarkedFile = await _addWatermark(File(photo.path));
      
      setState(() {
        _capturedImages.add(watermarkedFile);
      });
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error taking picture')),
        );
      }
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setZoomLevel(zoom);
      setState(() {
        _currentZoom = zoom;
      });
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.setFlashMode(_isTorchOn ? FlashMode.off : FlashMode.torch);
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
              ),
              const SizedBox(height: 20),
              Text(
                'Initializing camera...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Take Photos (${_capturedImages.length})',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_capturedImages.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageReviewScreen(
                      images: _capturedImages,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF35C2C1)),
              label: const Text(
                'Done',
                style: TextStyle(
                  color: Color(0xFF35C2C1),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_controller!),

          // Zoom Controls (above capture button)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _zoomLevels.map((zoom) {
                final isSelected = _currentZoom == zoom;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                    onTap: () => _setZoom(zoom),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF222222) : Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF35C2C1) : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        zoom == 1.0 ? '1X' : zoom.toString(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Bottom controls row
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Image preview (bottom left)
                if (_capturedImages.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageReviewScreen(
                            images: _capturedImages,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 60,
                      width: 60,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          _capturedImages.last,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 60),

                // Capture button (bottom center)
                GestureDetector(
                  onTap: _isCapturing ? null : _takePicture,
                  child: Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF35C2C1), width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const CircularProgressIndicator(color: Color(0xFF35C2C1))
                          : const Icon(Icons.camera_alt, color: Color(0xFF35C2C1), size: 36),
                    ),
                  ),
                ),

                // Torch button (bottom right)
                IconButton(
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? const Color(0xFF35C2C1) : Colors.white,
                    size: 36,
                  ),
                  onPressed: _toggleTorch,
                  splashRadius: 28,
                  tooltip: 'Toggle Flash',
                ),
              ],
            ),
          ),

          // Image Count Badge (top right)
          if (_capturedImages.isNotEmpty)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF35C2C1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_capturedImages.length} photos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 