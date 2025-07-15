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
import 'package:flutter/services.dart';

class CapturedImage {
  final String originalPath; // Used as a key to find and update the item
  File watermarkedFile; // Starts as the raw file, gets replaced by the watermarked one
  bool isProcessing;
  final String type; // 'photo' or 'video'

  CapturedImage({
    required this.originalPath,
    required this.watermarkedFile,
    this.isProcessing = true,
    this.type = 'photo',
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
    // Check camera permission first
    final cameraStatus = await Permission.camera.status;
    if (cameraStatus.isDenied) {
      final cameraRequest = await Permission.camera.request();
      if (cameraRequest.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to take photos')),
        );
      }
      return;
      }
    }
    
    // Check microphone permission for video recording
    final microphoneStatus = await Permission.microphone.status;
    if (microphoneStatus.isDenied) {
      final microphoneRequest = await Permission.microphone.request();
      if (microphoneRequest.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required for video recording')),
          );
        }
        // Continue anyway as user might grant permission later
      }
    }
    
    // Check storage permissions for saving photos
    // For Android 10+ we need to check multiple permissions
    final photosStatus = await Permission.photos.status;
    final storageStatus = await Permission.storage.status;
    
    if (photosStatus.isDenied || storageStatus.isDenied) {
      // Only request if not already granted
      if (photosStatus.isDenied) {
        await Permission.photos.request();
      }
      if (storageStatus.isDenied) {
        await Permission.storage.request();
      }
      
      // Check again after requesting
      final finalPhotosStatus = await Permission.photos.status;
      final finalStorageStatus = await Permission.storage.status;
      
      if (finalPhotosStatus.isDenied && finalStorageStatus.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to save photos')),
        );
      }
      // Continue anyway as user might grant permission later
      }
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
      enableAudio: true, // Enable audio for video recording
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
    
    // Get company from location data
    String company = '';
    if (widget.location?.company.isNotEmpty == true) {
      company = widget.location!.company;
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

    // Prepare text styles with better visibility (white text with black shadow)
    final watermarkStyle = TextStyle(
      color: Colors.white,
      fontSize: imageWidth * 0.03,
      fontWeight: FontWeight.w500,
      shadows: [
        Shadow(
          offset: const Offset(1, 1),
          blurRadius: 2,
          color: Colors.black.withOpacity(0.8),
        ),
      ],
    );

    // Declare logoMargin and gap first
    final logoMargin = imageWidth * 0.03;
    final gap = imageWidth * 0.02;
    // Use a temporary infoWidth for initial layout (logoSize not known yet, use 0)
    final tempInfoStartX = logoMargin + 0 + gap;
    final tempInfoWidth = imageWidth - tempInfoStartX - logoMargin;

    // Layout and draw text with optimized spacing using tempInfoWidth
    final List<TextPainter> watermarkPainters = [];
    final List<double> lineSpacings = [];

    // First line: Before/Working/After on left, SAP code on right
    final firstLineText = '${widget.photoType}${sapCode.isNotEmpty ? '    SAP - $sapCode' : ''}';
    final firstLinePainter = TextPainter(
      text: TextSpan(text: firstLineText, style: watermarkStyle),
      textDirection: ui.TextDirection.ltr,
      maxLines: null, // Allow multi-line
      textAlign: TextAlign.left,
    )..layout(maxWidth: tempInfoWidth);
    watermarkPainters.add(firstLinePainter);
    lineSpacings.add(6);

    // Second line: Company-Regional Office Date/Time
    final secondLineParts = <String>[];
    if (company.isNotEmpty) {
      secondLineParts.add(company);
    }
    if (widget.location?.regionalOffice?.isNotEmpty == true) {
      secondLineParts.add(widget.location!.regionalOffice!);
    }
    if (secondLineParts.isNotEmpty) {
      secondLineParts.add(dateTimeStr);
      final secondLineText = secondLineParts.join('-').replaceAll('-$dateTimeStr', ' $dateTimeStr');
      final secondLinePainter = TextPainter(
        text: TextSpan(text: secondLineText, style: watermarkStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: null, // Allow multi-line
        textAlign: TextAlign.left,
      )..layout(maxWidth: tempInfoWidth);
      watermarkPainters.add(secondLinePainter);
      lineSpacings.add(6);
    }

    // Third line: customerName only
    if (customerName.isNotEmpty) {
      final thirdLinePainter = TextPainter(
        text: TextSpan(text: customerName, style: watermarkStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: null, // Allow multi-line
        textAlign: TextAlign.left,
      )..layout(maxWidth: tempInfoWidth);
      watermarkPainters.add(thirdLinePainter);
      lineSpacings.add(6);
    }

    // Fourth line: salesArea, district
    final locationParts = <String>[];
    if (salesArea.isNotEmpty) locationParts.add('SA: $salesArea');
    if (district.isNotEmpty) locationParts.add('Dist: $district');
    if (locationParts.isNotEmpty) {
      final fourthLineText = locationParts.join(', ');
      final fourthLinePainter = TextPainter(
        text: TextSpan(text: fourthLineText, style: watermarkStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: null, // Allow multi-line
        textAlign: TextAlign.left,
      )..layout(maxWidth: tempInfoWidth);
      watermarkPainters.add(fourthLinePainter);
      lineSpacings.add(6);
    }

    // Fifth line: first word of userName, teamName (if available) - CAPITALIZED with truncation
    final userParts = <String>[];
    if (userName.isNotEmpty) {
      final firstName = userName.split(' ').first.toUpperCase();
      userParts.add(firstName);
    }
    if (teamName.isNotEmpty) {
      userParts.add(teamName.toUpperCase());
    }
    if (userParts.isNotEmpty) {
      final fifthLineText = userParts.join(', ');
      final fifthLinePainter = TextPainter(
        text: TextSpan(text: fifthLineText, style: watermarkStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1, // Force single line
        textAlign: TextAlign.left,
      )..layout(maxWidth: tempInfoWidth);
      
      // Check if text was truncated and add ellipsis if needed
      String displayText = fifthLineText;
      if (fifthLinePainter.didExceedMaxLines) {
        // Find the last comma and truncate the team name part
        final lastCommaIndex = fifthLineText.lastIndexOf(',');
        if (lastCommaIndex > 0) {
          final beforeComma = fifthLineText.substring(0, lastCommaIndex + 1); // Include the comma
          final teamNamePart = fifthLineText.substring(lastCommaIndex + 1).trim();
          
          // Create a test painter to find where to truncate the team name
          final testPainter = TextPainter(
            text: TextSpan(text: teamNamePart, style: watermarkStyle),
            textDirection: ui.TextDirection.ltr,
            maxLines: 1,
            textAlign: TextAlign.left,
          )..layout(maxWidth: tempInfoWidth - 50); // Leave some space for ellipsis
          
          if (testPainter.didExceedMaxLines) {
            // Find the character position where it exceeds, accounting for "..." space
            int truncateIndex = teamNamePart.length;
            for (int i = teamNamePart.length - 1; i >= 0; i--) {
              final testText = teamNamePart.substring(0, i) + '...';
              final testPainter2 = TextPainter(
                text: TextSpan(text: testText, style: watermarkStyle),
                textDirection: ui.TextDirection.ltr,
                maxLines: 1,
                textAlign: TextAlign.left,
              )..layout(maxWidth: tempInfoWidth - 50);
              
              if (!testPainter2.didExceedMaxLines) {
                truncateIndex = i;
                break;
              }
            }
            
            // Final verification: test the complete line with ellipsis
            final finalTestText = '$beforeComma ${teamNamePart.substring(0, truncateIndex)}...';
            final finalTestPainter = TextPainter(
              text: TextSpan(text: finalTestText, style: watermarkStyle),
              textDirection: ui.TextDirection.ltr,
              maxLines: 1,
              textAlign: TextAlign.left,
            )..layout(maxWidth: tempInfoWidth);
            
            if (!finalTestPainter.didExceedMaxLines) {
              displayText = finalTestText;
            } else {
              // If still exceeds, truncate more aggressively
              for (int i = truncateIndex - 1; i >= 0; i--) {
                final aggressiveTestText = '$beforeComma ${teamNamePart.substring(0, i)}...';
                final aggressiveTestPainter = TextPainter(
                  text: TextSpan(text: aggressiveTestText, style: watermarkStyle),
                  textDirection: ui.TextDirection.ltr,
                  maxLines: 1,
                  textAlign: TextAlign.left,
                )..layout(maxWidth: tempInfoWidth);
                
                if (!aggressiveTestPainter.didExceedMaxLines) {
                  displayText = aggressiveTestText;
                  break;
                }
              }
            }
          }
        }
      }
      
      final finalFifthLinePainter = TextPainter(
        text: TextSpan(text: displayText, style: watermarkStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        textAlign: TextAlign.left,
      )..layout(maxWidth: tempInfoWidth);
      
      watermarkPainters.add(finalFifthLinePainter);
      // Extra spacing before branding
      lineSpacings.add(8);
    }

    // Calculate total height of all watermark lines (including spacing, except after last line)
    double totalWatermarkHeight = 0;
    for (int i = 0; i < watermarkPainters.length; i++) {
      totalWatermarkHeight += watermarkPainters[i].height;
      if (i < watermarkPainters.length - 1) {
        totalWatermarkHeight += lineSpacings[i];
      }
    }

    // Now that we know the height, calculate logoSize, infoStartX, and infoWidth
    final logoSize = totalWatermarkHeight;
    final infoStartX = logoMargin + logoSize + gap;
    final infoWidth = imageWidth - infoStartX - logoMargin;

    // Re-layout watermarkPainters with the final infoWidth
    for (final painter in watermarkPainters) {
      painter.layout(maxWidth: infoWidth);
    }
    // Recalculate totalWatermarkHeight with the final layout
    totalWatermarkHeight = 0;
    for (int i = 0; i < watermarkPainters.length; i++) {
      totalWatermarkHeight += watermarkPainters[i].height;
      if (i < watermarkPainters.length - 1) {
        totalWatermarkHeight += lineSpacings[i];
      }
    }
    // Add bottom padding equal to left padding (logoMargin)
    // totalWatermarkHeight += logoMargin;

    // Set logo size to match text block height (minimum size for logo)
    // final logoSize = totalWatermarkHeight; // This line is now redundant
    // final logoMargin = imageWidth * 0.03; // same as leftMargin
    // final gap = imageWidth * 0.02; // gap between logo and text
    final bottomMargin = logoMargin;
    // The bottom of the watermark block is always at imageHeight - bottomMargin
    // So the top (yBase) moves up as the watermark grows
    final yBase = imageHeight - bottomMargin - totalWatermarkHeight;

    // Draw logo (square, vertically aligned so its bottom is at imageHeight - bottomMargin)
    try {
      final brandingImageData = await rootBundle.load('assets/images/Branding.png');
      final brandingImage = await decodeImageFromList(brandingImageData.buffer.asUint8List());
      canvas.drawImageRect(
        brandingImage,
        Rect.fromLTWH(0, 0, brandingImage.width.toDouble(), brandingImage.height.toDouble()),
        Rect.fromLTWH(logoMargin, imageHeight - bottomMargin - logoSize, logoSize, logoSize),
        Paint()
          ..filterQuality = ui.FilterQuality.high
          ..color = Colors.white.withOpacity(0.4), // Reduce logo opacity to 60%
      );
    } catch (e) {
      debugPrint('Error loading branding logo for watermark: $e');
    }

    // Declare infoStartX and infoWidth before using them
    // final infoStartX = logoMargin + logoSize + gap; // This line is now redundant
    // final infoWidth = imageWidth - infoStartX - logoMargin; // This line is now redundant

    // Draw background shade behind watermark text block
    final double backgroundPadding = 16;
    final double backgroundHeight = totalWatermarkHeight + backgroundPadding;
    final double backgroundWidth = infoWidth + backgroundPadding;
    final double backgroundX = infoStartX - backgroundPadding / 2;
    // The background's bottom should also be fixed at imageHeight - bottomMargin
    final double backgroundY = imageHeight - bottomMargin - backgroundHeight;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(backgroundX, backgroundY, backgroundWidth, backgroundHeight),
        Radius.circular(12),
      ),
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    // Draw text block to the right of the logo
    double y = imageHeight - bottomMargin - totalWatermarkHeight;
    for (int i = 0; i < watermarkPainters.length; i++) {
      final textPainter = watermarkPainters[i];
      textPainter.paint(canvas, Offset(infoStartX, y));
      y += textPainter.height;
      if (i < watermarkPainters.length - 1) {
        y += lineSpacings[i];
      }
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
        type: 'photo',
      );
      
      setState(() {
        _capturedImages.add(newImage);
      });

      // Track the image upload
      await _trackImageUpload(tempFile);

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
        
        // Only show snackbar for failures, not success
        if (mounted && !result['isSuccess']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to save photo to gallery'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
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
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageReviewScreen(
            images: _capturedImages.map((e) => e.watermarkedFile).toList(),
          ),
        ),
      );
      
      // Handle the returned list of images from image review screen
      if (result != null && result is List<File>) {
        // Update the captured images list based on what's returned
        _updateCapturedImagesFromReview(result);
      }
    }
  }

  void _updateCapturedImagesFromReview(List<File> returnedImages) {
    // Create a set of returned image paths for efficient lookup
    final returnedPaths = returnedImages.map((file) => file.path).toSet();
    
    // Remove captured images that are no longer in the returned list
    setState(() {
      _capturedImages.removeWhere((capturedImage) => 
        !returnedPaths.contains(capturedImage.watermarkedFile.path)
      );
    });
  }

  Future<void> _trackImageUpload(File imageFile) async {
    try {
      // Track the upload
      final pumpId = 'image_upload';
      final Map<String, dynamic> metadata = {};
      
      final uploadSuccess = await _databaseService.addImageUpload(
        imageFile.path,
        pumpId,
        metadata,
      );
      
      // Track visit if this is from a petrol pump location
      // The database service will handle duplicate prevention for the same pump on the same day
      if (widget.location != null) {
        final Map<String, dynamic> pumpDetails = {
          'customerName': widget.location!.customerName,
          'addressLine1': widget.location!.addressLine1,
          'company': widget.location!.company,
        };
        
        // Use sapCode as pumpId for visit tracking
        final visitPumpId = widget.location!.sapCode.isNotEmpty 
            ? widget.location!.sapCode 
            : 'pump_${widget.location!.latitude}_${widget.location!.longitude}';
        
        await _databaseService.addPumpVisit(visitPumpId, pumpDetails);
      }
      
      if (uploadSuccess) {
        print('Successfully tracked image upload');
      } else {
        print('Failed to track image upload');
      }
    } catch (e) {
      print('Error tracking image upload: $e');
    }
  }

  @override
  void dispose() {
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
    final orientation = MediaQuery.of(context).orientation;
    
    // Get camera preview size
    final previewSize = _controller!.value.previewSize;
    
    if (previewSize == null) {
      // Fallback if preview size is not available
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            'Camera preview not available',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    
    // Calculate the aspect ratio of the camera preview
    final previewAspectRatio = previewSize.width / previewSize.height;
    
    // Debug information
    debugPrint('Screen size: ${size.width} x ${size.height}');
    debugPrint('Preview size: ${previewSize.width} x ${previewSize.height}');
    debugPrint('Preview aspect ratio: $previewAspectRatio');
    debugPrint('Screen aspect ratio: ${size.width / size.height}');
    debugPrint('Orientation: $orientation');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.width,
                height: previewSize.height,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Top Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side: Back button
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

                  // Right side: Photo count
                  Row(
                    children: [
                      Text(
                        '${_capturedImages.length} photos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                              // Debug logging
                              debugPrint('Original captured images count: ${_capturedImages.length}');
                              debugPrint('Remaining images count: ${result.length}');
                              
                              // If the returned list is shorter than our current list, 
                              // it means some images were deleted
                              if (result.length < _capturedImages.length) {
                                // Create a map of current watermarked file paths to their indices
                                final currentPaths = <String, int>{};
                                for (int i = 0; i < _capturedImages.length; i++) {
                                  currentPaths[_capturedImages[i].watermarkedFile.path] = i;
                                }
                                
                                // Create a set of remaining file paths
                                final remainingPaths = result.map((file) => file.path).toSet();
                                
                                // Find which images were removed
                                final removedIndices = <int>[];
                                for (int i = 0; i < _capturedImages.length; i++) {
                                  if (!remainingPaths.contains(_capturedImages[i].watermarkedFile.path)) {
                                    removedIndices.add(i);
                                    debugPrint('Image at index $i will be removed: ${_capturedImages[i].watermarkedFile.path}');
                                  }
                                }
                                
                                // Remove images in reverse order to maintain correct indices
                                removedIndices.sort((a, b) => b.compareTo(a));
                                for (final index in removedIndices) {
                                  _capturedImages.removeAt(index);
                                }
                                
                                debugPrint('Removed ${removedIndices.length} images');
                              }
                              
                              // Fallback: If the counts don't match after processing, 
                              // rebuild the list from the returned result
                              if (_capturedImages.length != result.length) {
                                debugPrint('Count mismatch detected. Rebuilding list from result.');
                                // This is a fallback - in normal cases this shouldn't happen
                                // but it ensures the state stays consistent
                                _capturedImages = result.map((file) => CapturedImage(
                                  originalPath: file.path,
                                  watermarkedFile: file,
                                  isProcessing: false,
                                  type: 'video',
                                )).toList();
                              }
                              
                              debugPrint('Final captured images count: ${_capturedImages.length}');
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
                            : const Opacity(
                                opacity: 0.5,
                                child: Icon(
                                  Icons.photo_library,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                        ),
                      ),

                      // Shutter Button
                      GestureDetector(
                        onTap: (_isCapturing) ? null : () async {
                          _takePicture();
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isCapturing ? Colors.grey : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isCapturing ? Colors.grey.withOpacity(0.3) : Colors.white.withOpacity(0.3),
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
                          child: Opacity(
                            opacity: 0.5,
                            child: Icon(
                              _isTorchOn ? Icons.flash_on : Icons.flash_off,
                              color: _isTorchOn ? const Color(0xFFFFD700) : Colors.white,
                              size: 24,
                            ),
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