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
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class CapturedImage {
  final String originalPath; // Used as a key to find and update the item
  File watermarkedFile; // Starts as the raw file, gets replaced by the watermarked one
  bool isProcessing;

  CapturedImage({
    required this.originalPath,
    required this.watermarkedFile,
    this.isProcessing = true,
  });
}

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
  List<CapturedImage> _capturedImages = [];
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  final GlobalKey _previewKey = GlobalKey();
  double _currentZoom = 1.0;
  final List<double> _zoomLevels = [1.0, 2.0];
  bool _isTorchOn = false;
  
  // Video recording state
  bool _isVideoMode = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  
  // User data for watermark
  Map<String, dynamic> _userData = {};
  final CustomAuthService _authService = CustomAuthService();
  final DatabaseService _databaseService = DatabaseService();
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    
    // Request microphone permission for video recording
    final microphoneStatus = await Permission.microphone.request();
    if (microphoneStatus.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required for video recording')),
        );
      }
      // Continue anyway as user might grant permission later
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
      enableAudio: true,
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

  Future<void> _playShutterSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/shutter_sound.mp3'));
    } catch (e) {
      // Silently fail if sound can't be played
      debugPrint('Error playing shutter sound: $e');
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
      await _playShutterSound();
      final XFile photo = await _controller!.takePicture();
      final tempFile = File(photo.path);

      final newImage = CapturedImage(
        originalPath: photo.path,
        watermarkedFile: tempFile, // Show raw file temporarily
        isProcessing: true,
      );

      setState(() {
        _capturedImages.add(newImage);
      });

      // Process watermark and save in background
      _processWatermarkInBackground(newImage);

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

  Future<void> _processWatermarkInBackground(CapturedImage imageToProcess) async {
    try {
      // The file to be watermarked is the initial (raw) file.
      final watermarkedFile = await _addWatermark(imageToProcess.watermarkedFile);

      // Automatically save to gallery
      try {
        final result = await ImageGallerySaver.saveFile(
          watermarkedFile.path,
          name: "click_${DateTime.now().millisecondsSinceEpoch}"
        );
        
        if (mounted) {
          // Clear any existing snackbars first
          ScaffoldMessenger.of(context).clearSnackBars();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['isSuccess'] ? 'Photo saved to gallery' : 'Failed to save photo'),
              backgroundColor: result['isSuccess'] ? Colors.green : Colors.red,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Clear any existing snackbars first
          ScaffoldMessenger.of(context).clearSnackBars();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save photo: ${e.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      // Update the image in the list with the watermarked version
      if (mounted) {
        setState(() {
          final index = _capturedImages.indexWhere((img) => img.originalPath == imageToProcess.originalPath);
          if (index != -1) {
            _capturedImages[index].watermarkedFile = watermarkedFile;
            _capturedImages[index].isProcessing = false;
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

  Future<void> _toggleVideoMode() async {
    setState(() {
      _isVideoMode = !_isVideoMode;
    });
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized || _isRecording) {
      return;
    }

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start timer to track recording duration
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        }
      });

      // Play shutter sound for video start
      await _playShutterSound();

    } catch (e) {
      debugPrint('Error starting video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting video recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_isRecording) {
      return;
    }

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      
      // Stop the recording timer
      _recordingTimer?.cancel();
      _recordingTimer = null;

      setState(() {
        _isRecording = false;
        _recordingDuration = Duration.zero;
      });

      // Play shutter sound for video stop
      await _playShutterSound();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video saved: ${_formatDuration(_recordingDuration)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping video recording: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _navigateToImageReview() async {
    // Turn off torch before navigating
    await _turnOffTorch();
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageReviewScreen(
            images: _capturedImages.map((e) => e.watermarkedFile).toList(),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Stop recording if active
    if (_isRecording) {
      _controller?.stopVideoRecording();
    }
    
    // Cancel recording timer
    _recordingTimer?.cancel();
    
    // Turn off torch before disposing
    _turnOffTorch();
    _controller?.dispose();
    _audioPlayer.dispose();
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

    final size = MediaQuery.of(context).size;
    // calculate scale to fill screen
    var scale = size.aspectRatio * _controller!.value.aspectRatio;

    // to prevent scaling down, make sure scale is > 1
    if (scale < 1) scale = 1 / scale;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),

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

                  // Center: Mode indicator and recording timer
                  Column(
                    children: [
                      // Mode indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isVideoMode ? 'VIDEO' : 'PHOTO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      
                      // Recording timer
                      if (_isRecording)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(_recordingDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Right side: Photo count and video mode toggle
                  Row(
                    children: [
                      // Photo count badge
                      if (_capturedImages.isNotEmpty && !_isVideoMode)
                        Container(
                          margin: const EdgeInsets.only(right: 12),
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

                      // Video mode toggle
                      GestureDetector(
                        onTap: _toggleVideoMode,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _isVideoMode 
                              ? const Color(0xFF35C2C1).withOpacity(0.8)
                              : Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isVideoMode ? Icons.videocam : Icons.videocam_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
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
                        onTap: _capturedImages.isNotEmpty ? () async {
                          if (_capturedImages.last.isProcessing) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Still processing image...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            return;
                          }
                          
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageReviewScreen(
                                images: _capturedImages.map((e) => e.watermarkedFile).toList(),
                              ),
                            ),
                          );
                          
                          // Handle the returned list of images (with deleted ones removed)
                          if (result != null && result is List<File>) {
                            setState(() {
                              // Create a map of file paths to CapturedImage objects for easy lookup
                              final imageMap = <String, CapturedImage>{};
                              for (final capturedImage in _capturedImages) {
                                imageMap[capturedImage.watermarkedFile.path] = capturedImage;
                              }
                              
                              // Filter the captured images to only include those that are still in the result list
                              _capturedImages = _capturedImages.where((capturedImage) {
                                return result.any((file) => file.path == capturedImage.watermarkedFile.path);
                              }).toList();
                            });
                          }
                        } : null,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: _capturedImages.isNotEmpty
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _capturedImages.last.watermarkedFile,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (_capturedImages.last.isProcessing)
                                    Container(
                                      color: Colors.black.withOpacity(0.6),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
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
                        onTap: _isCapturing || _isRecording ? null : () {
                          if (_isVideoMode) {
                            if (_isRecording) {
                              _stopVideoRecording();
                            } else {
                              _startVideoRecording();
                            }
                          } else {
                            _takePicture();
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isRecording ? Colors.red : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording 
                                ? Colors.red.withOpacity(0.3)
                                : Colors.white.withOpacity(0.3),
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
                              : _isRecording
                                ? Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.stop,
                                      color: Colors.white,
                                      size: 30,
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