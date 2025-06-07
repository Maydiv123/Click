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

    // Prepare watermark text
    final now = DateTime.now();
    final dateTimeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
    final pumpName = widget.location?.customerName ?? 'Unknown Location';
    final pumpAddress = widget.location?.addressLine1 ?? '';
    final coordinates = widget.location != null 
        ? 'Lat: ${widget.location!.latitude.toStringAsFixed(6)}\nLong: ${widget.location!.longitude.toStringAsFixed(6)}'
        : '';

    // Create text style for watermark
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: imageWidth * 0.025, // Slightly smaller font size for better readability
      fontWeight: FontWeight.w500,
      height: 1.2, // Line height for better readability
    );

    // Create text painter for watermark
    final textPainter = TextPainter(
      text: TextSpan(
        text: '📍 $pumpName\n'
              '🏢 $pumpAddress\n'
              '🕒 $dateTimeStr\n'
              '🌍 $coordinates',
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    );

    // Layout the text
    textPainter.layout(
      minWidth: 0,
      maxWidth: imageWidth * 0.7, // Slightly narrower for better readability
    );

    // Draw semi-transparent background for watermark
    final watermarkRect = Rect.fromLTWH(
      imageWidth * 0.03, // 3% from left
      imageHeight * 0.03, // 3% from top
      textPainter.width + 24, // More padding
      textPainter.height + 24,
    );

    // Draw gradient background for better readability
    final gradient = ui.Gradient.linear(
      Offset(watermarkRect.left, watermarkRect.top),
      Offset(watermarkRect.right, watermarkRect.bottom),
      [
        Colors.black.withOpacity(0.7),
        Colors.black.withOpacity(0.5),
      ],
    );

    canvas.drawRect(
      watermarkRect,
      Paint()
        ..shader = gradient
        ..style = PaintingStyle.fill,
    );

    // Draw border around watermark
    canvas.drawRect(
      watermarkRect,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Draw the watermark text
    textPainter.paint(
      canvas,
      Offset(
        imageWidth * 0.03 + 12, // 3% from left + padding
        imageHeight * 0.03 + 12, // 3% from top + padding
      ),
    );

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
          
          // Captured Images Preview
          if (_capturedImages.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              child: Container(
                height: 80,
                width: 80,
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
            ),
          
          // Image Count Badge
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_capturedImages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FloatingActionButton(
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
                backgroundColor: Colors.white,
                child: const Icon(Icons.photo_library, color: Color(0xFF35C2C1)),
              ),
            ),
          FloatingActionButton(
            onPressed: _isCapturing ? null : _takePicture,
            backgroundColor: const Color(0xFF35C2C1),
            child: _isCapturing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.camera, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
} 