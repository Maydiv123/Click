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
      // Take picture with optimized settings
      final XFile photo = await _controller!.takePicture();
      
      // Add to captured images immediately for better UX
      setState(() {
        _capturedImages.add(File(photo.path));
      });

      // Process watermark in background
      _processWatermarkInBackground(photo.path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured'),
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

  Future<void> _processWatermarkInBackground(String photoPath) async {
    try {
      final watermarkedFile = await _addWatermark(File(photoPath));
      
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
                content: Text('Photo saved to gallery'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Photo captured but failed to save: ${result['errorMessage'] ?? 'Unknown error'}'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo captured but failed to save: ${e.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      // Update the image in the list with watermarked version
      if (mounted) {
        setState(() {
          final index = _capturedImages.indexWhere((file) => file.path == photoPath);
          if (index != -1) {
            _capturedImages[index] = watermarkedFile;
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing watermark: $e');
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
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'Initializing camera...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          CameraPreview(_controller!),

          // Top Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // Photo count badge
                  if (_capturedImages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_capturedImages.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                  // Settings/More button
                  GestureDetector(
                    onTap: () {
                      // TODO: Add settings or more options
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Zoom Controls
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _zoomLevels.map((zoom) {
                        final isSelected = _currentZoom == zoom;
                        return GestureDetector(
                          onTap: () => _setZoom(zoom),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              zoom == 1.0 ? '1x' : '${zoom.toInt()}x',
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Main Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery/Preview button
                      GestureDetector(
                        onTap: _capturedImages.isNotEmpty ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageReviewScreen(
                                images: _capturedImages,
                              ),
                            ),
                          );
                        } : null,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: _capturedImages.isNotEmpty 
                              ? Colors.white.withOpacity(0.9)
                              : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: _capturedImages.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _capturedImages.last,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 24,
                              ),
                        ),
                      ),

                      // Shutter Button
                      GestureDetector(
                        onTap: _isCapturing ? null : _takePicture,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isCapturing
                              ? Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          ),
                        ),
                      ),

                      // Flash/Torch button
                      GestureDetector(
                        onTap: _toggleTorch,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: _isTorchOn ? const Color(0xFFFFD700) : Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Bottom indicator
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 