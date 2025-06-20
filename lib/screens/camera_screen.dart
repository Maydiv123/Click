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

    // Prepare enhanced watermark content
    final now = DateTime.now();
    final dateTimeStr = DateFormat('dd/MM/yyyy hh:mm a').format(now);
    final locationName = widget.location?.customerName ?? widget.location?.location ?? 'Unknown Location';
    final address = widget.location?.addressLine1 ?? '';
    final district = widget.location?.district ?? '';
    final zone = widget.location?.zone ?? '';
    final coordinates = widget.location != null
        ? 'Lat ${widget.location!.latitude.toStringAsFixed(6)}  Long ${widget.location!.longitude.toStringAsFixed(6)}'
        : '';
    final zoomStr = _currentZoom == 1.0 ? '1x' : '${_currentZoom}x';
    
    // User information
    final userName = '${_userData['firstName'] ?? ''} ${_userData['lastName'] ?? ''}'.trim();
    final userMobile = _userData['mobile'] ?? '';
    final userType = _userData['userType']?.toString().replaceAll('UserType.', '') ?? 'User';
    final teamName = _userData['teamName'] ?? '';
    final teamCode = _userData['teamCode'] ?? '';

    // Enhanced card dimensions for more content
    final double cardWidth = imageWidth * 0.94;
    final double cardPadding = 16;
    final double cardHeight = imageHeight * 0.28; // Increased height for more content
    final double cardLeft = (imageWidth - cardWidth) / 2;
    final double cardTop = imageHeight - cardHeight - imageHeight * 0.02;
    final double borderRadius = 20;

    // Draw card background (semi-transparent black with rounded corners)
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withOpacity(0.8),
    );

    // Prepare enhanced text styles
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: imageWidth * 0.042,
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
    final badgeStyle = TextStyle(
      color: Colors.black,
      fontSize: imageWidth * 0.025,
      fontWeight: FontWeight.bold,
    );

    // Layout and draw text
    double y = cardTop + cardPadding;
    
    // Location name (main title)
    final locationPainter = TextPainter(
      text: TextSpan(text: locationName, style: titleStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cardWidth - 2 * cardPadding);
    locationPainter.paint(canvas, Offset(cardLeft + cardPadding, y));
    y += locationPainter.height + 6;
    
    // Address and district
    final addressText = address.isNotEmpty && district.isNotEmpty ? '$address, $district' : address.isNotEmpty ? address : district;
    if (addressText.isNotEmpty) {
      final addressPainter = TextPainter(
        text: TextSpan(text: addressText, style: subtitleStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      addressPainter.paint(canvas, Offset(cardLeft + cardPadding, y));
      y += addressPainter.height + 4;
    }
    
    // Zone information
    if (zone.isNotEmpty) {
      final zonePainter = TextPainter(
        text: TextSpan(text: 'Zone: $zone', style: detailStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      zonePainter.paint(canvas, Offset(cardLeft + cardPadding, y));
      y += zonePainter.height + 4;
    }
    
    // Coordinates
    if (coordinates.isNotEmpty) {
      final coordPainter = TextPainter(
        text: TextSpan(text: coordinates, style: detailStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      coordPainter.paint(canvas, Offset(cardLeft + cardPadding, y));
      y += coordPainter.height + 8;
    }
    
    // User information section
    if (userName.isNotEmpty) {
      final userPainter = TextPainter(
        text: TextSpan(text: 'Captured by: $userName', style: subtitleStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      userPainter.paint(canvas, Offset(cardLeft + cardPadding, y));
      y += userPainter.height + 4;
    }
    
    // User details row
    final userDetailsRow = <String>[];
    if (userType.isNotEmpty) userDetailsRow.add('Type: $userType');
    if (userMobile.isNotEmpty) userDetailsRow.add('Mobile: $userMobile');
    if (teamName.isNotEmpty) userDetailsRow.add('Team: $teamName');
    if (teamCode.isNotEmpty) userDetailsRow.add('Code: $teamCode');
    
    if (userDetailsRow.isNotEmpty) {
      final userDetailsText = userDetailsRow.join(' | ');
      final userDetailsPainter = TextPainter(
        text: TextSpan(text: userDetailsText, style: smallStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: cardWidth - 2 * cardPadding);
      userDetailsPainter.paint(canvas, Offset(cardLeft + cardPadding, y));
      y += userDetailsPainter.height + 8;
    }
    
    // Bottom row with zoom badge, date/time, and app info
    final bottomRowY = cardTop + cardHeight - 32;
    
    // Zoom badge
    final badgeWidth = 50.0;
    final badgeHeight = 24.0;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft + cardPadding, bottomRowY, badgeWidth, badgeHeight),
      Radius.circular(6),
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
      Offset(cardLeft + cardPadding + (badgeWidth - badgePainter.width) / 2, bottomRowY + (badgeHeight - badgePainter.height) / 2),
    );
    
    // Date/time
    final datePainter = TextPainter(
      text: TextSpan(text: dateTimeStr, style: detailStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: cardWidth - 2 * cardPadding - badgeWidth - 20);
    datePainter.paint(canvas, Offset(cardLeft + cardPadding + badgeWidth + 12, bottomRowY + (badgeHeight - datePainter.height) / 2));
    
    // App watermark
    final appWatermark = 'Click App';
    final appPainter = TextPainter(
      text: TextSpan(text: appWatermark, style: TextStyle(
        color: Colors.white.withOpacity(0.6),
        fontSize: imageWidth * 0.022,
        fontWeight: FontWeight.w400,
      )),
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: cardWidth - 2 * cardPadding);
    appPainter.paint(canvas, Offset(cardLeft + cardWidth - cardPadding - appPainter.width, bottomRowY + (badgeHeight - appPainter.height) / 2));

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
      
      // Don't save to gallery automatically - user will save on image review screen
      
      setState(() {
        _capturedImages.add(watermarkedFile);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
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