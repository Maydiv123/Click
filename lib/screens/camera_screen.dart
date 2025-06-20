import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'image_review_screen.dart';
import '../models/map_location.dart';
import '../services/custom_auth_service.dart';
import '../services/database_service.dart';

class CameraScreen extends StatefulWidget {
  final MapLocation? location;
  final String photoType;

  const CameraScreen({
    Key? key,
    this.location,
    required this.photoType,
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
  final List<double> _zoomLevels = [1.0, 2.0];
  bool _isTorchOn = false;
  
  // User data for watermark
  Map<String, dynamic> _userData = {};
  final CustomAuthService _authService = CustomAuthService();
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadUserData();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to take photos')),
        );
      }
      return;
    }
    
    // Request storage permission for saving photos
    // For Android 10+ we need to request multiple permissions
    final storageStatus = await Permission.photos.request();
    final mediaStatus = await Permission.storage.request();
    
    if (storageStatus.isDenied || mediaStatus.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to save photos')),
        );
      }
      // Continue anyway as user might grant permission later
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

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
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
    
    // Process address line 1 - extract first word and add "cl"
    String processedAddress = '';
    if (widget.location?.addressLine1.isNotEmpty == true) {
      final firstWord = widget.location!.addressLine1.split(' ').first;
      processedAddress = '${firstWord}cl';
    }
    
    // Location information
    final customerName = widget.location?.customerName ?? 'Unknown Location';
    final sapCode = widget.location?.sapCode ?? '';
    final zone = widget.location?.zone ?? '';
    final salesArea = widget.location?.salesArea ?? '';
    final district = widget.location?.district ?? '';
    
    // User information
    final userName = '${_userData['firstName'] ?? ''} ${_userData['lastName'] ?? ''}'.trim();
    final teamName = _userData['teamName'] ?? '';
    
    // Enhanced card dimensions for new layout
    final double cardWidth = imageWidth * 0.94;
    final double cardPadding = 16;
    final double cardHeight = imageHeight * 0.25; // Optimized height
    final double cardLeft = (imageWidth - cardWidth) / 2;
    final double cardTop = imageHeight - cardHeight - imageHeight * 0.02;
    final double borderRadius = 16;

    // Draw card background (semi-transparent black with rounded corners)
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withOpacity(0.85),
    );

    // Prepare text styles
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: imageWidth * 0.045,
      fontWeight: FontWeight.bold,
    );
    final subtitleStyle = TextStyle(
      color: Colors.white.withOpacity(0.9),
      fontSize: imageWidth * 0.035,
      fontWeight: FontWeight.w500,
    );
    final detailStyle = TextStyle(
      color: Colors.white.withOpacity(0.8),
      fontSize: imageWidth * 0.028,
      fontWeight: FontWeight.w400,
    );
    final smallStyle = TextStyle(
      color: Colors.white.withOpacity(0.7),
      fontSize: imageWidth * 0.025,
      fontWeight: FontWeight.w400,
    );

    // Layout and draw text
    double y = cardTop + cardPadding;
    
    // First line: Before/Working/After
    final firstLinePainter = TextPainter(
      text: TextSpan(text: widget.photoType, style: titleStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cardWidth - 2 * cardPadding);
    firstLinePainter.paint(canvas, Offset(cardLeft + cardPadding, y));
    y += firstLinePainter.height + 8;
    
    // Second line: processedAddress date and time
    final secondLineParts = <String>[];
    if (processedAddress.isNotEmpty) {
      secondLineParts.add(processedAddress);
    }
    secondLineParts.add(dateTimeStr);
    
    final secondLineText = secondLineParts.join(' ');
    final secondLinePainter = TextPainter(
      text: TextSpan(text: secondLineText, style: subtitleStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cardWidth - 2 * cardPadding);
    secondLinePainter.paint(canvas, Offset(cardLeft + cardPadding, y));
    y += secondLinePainter.height + 8;
    
    // Third line: customerName - sapCode
    if (customerName.isNotEmpty || sapCode.isNotEmpty) {
      final thirdLineText = sapCode.isNotEmpty ? '$customerName - $sapCode' : customerName;
      final thirdLinePainter = TextPainter(
        text: TextSpan(text: thirdLineText, style: subtitleStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      thirdLinePainter.paint(canvas, Offset(cardLeft + cardPadding, y));
      y += thirdLinePainter.height + 8;
    }
    
    // Fourth line: zone, salesArea, district
    final locationParts = <String>[];
    if (zone.isNotEmpty) locationParts.add(zone);
    if (salesArea.isNotEmpty) locationParts.add(salesArea);
    if (district.isNotEmpty) locationParts.add(district);
    
    if (locationParts.isNotEmpty) {
      final fourthLineText = locationParts.join(', ');
      final fourthLinePainter = TextPainter(
        text: TextSpan(text: fourthLineText, style: detailStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      fourthLinePainter.paint(canvas, Offset(cardLeft + cardPadding, y));
      y += fourthLinePainter.height + 8;
    }
    
    // Fifth line: userName, teamName (if available)
    final userParts = <String>[];
    if (userName.isNotEmpty) userParts.add(userName);
    if (teamName.isNotEmpty) userParts.add(teamName);
    
    if (userParts.isNotEmpty) {
      final fifthLineText = userParts.join(', ');
      final fifthLinePainter = TextPainter(
        text: TextSpan(text: fifthLineText, style: smallStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      fifthLinePainter.paint(canvas, Offset(cardLeft + cardPadding, y));
    }

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
      
      // Automatically save to gallery
      try {
        final result = await ImageGallerySaver.saveFile(
          watermarkedFile.path,
          name: "click_${DateTime.now().millisecondsSinceEpoch}"
        );
        
        if (result['isSuccess']) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photo captured and saved to gallery'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo captured but failed to save to gallery: ${result['errorMessage'] ?? 'Unknown error'}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo captured but failed to save to gallery: ${e.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
      setState(() {
        _capturedImages.add(watermarkedFile);
      });
      
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking picture: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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

  Future<void> _turnOffTorch() async {
    if (_controller != null && _controller!.value.isInitialized && _isTorchOn) {
      await _controller!.setFlashMode(FlashMode.off);
      setState(() {
        _isTorchOn = false;
      });
    }
  }

  void _navigateToImageReview() async {
    // Turn off torch before navigating
    await _turnOffTorch();
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageReviewScreen(
            images: _capturedImages,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Turn off torch before disposing
    _turnOffTorch();
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
                    onTap: _navigateToImageReview,
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