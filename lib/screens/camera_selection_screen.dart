import 'package:flutter/material.dart';
import 'camera_screen.dart';
import '../models/map_location.dart';

class CameraSelectionScreen extends StatefulWidget {
  final MapLocation? location;

  const CameraSelectionScreen({
    Key? key,
    this.location,
  }) : super(key: key);

  @override
  State<CameraSelectionScreen> createState() => _CameraSelectionScreenState();
}

class _CameraSelectionScreenState extends State<CameraSelectionScreen> {
  String? _selectedOption;

  final List<Map<String, dynamic>> _options = [
    {
      'title': 'Before',
      'icon': Icons.arrow_back,
      'description': 'Take photos before work',
      'color': Colors.orange,
    },
    {
      'title': 'Working',
      'icon': Icons.work,
      'description': 'Take photos during work',
      'color': Colors.blue,
    },
    {
      'title': 'After',
      'icon': Icons.arrow_forward,
      'description': 'Take photos after work',
      'color': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Select Photo Type',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose when you are taking photos:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will be displayed in your photo watermark',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            
            // Location info card
            // if (widget.location != null) ...[
            //   Container(
            //     width: double.infinity,
            //     padding: const EdgeInsets.all(16),
            //     decoration: BoxDecoration(
            //       color: const Color(0xFF35C2C1).withOpacity(0.1),
            //       borderRadius: BorderRadius.circular(12),
            //       border: Border.all(
            //         color: const Color(0xFF35C2C1).withOpacity(0.3),
            //       ),
            //     ),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Row(
            //           children: [
            //             Icon(
            //               Icons.location_on,
            //               color: const Color(0xFF35C2C1),
            //               size: 20,
            //             ),
            //             const SizedBox(width: 8),
            //             const Text(
            //               'Location',
            //               style: TextStyle(
            //                 fontWeight: FontWeight.bold,
            //                 color: Color(0xFF35C2C1),
            //               ),
            //             ),
            //           ],
            //         ),
            //         const SizedBox(height: 8),
            //         Text(
            //           widget.location!.customerName,
            //           style: const TextStyle(
            //             fontSize: 16,
            //             fontWeight: FontWeight.w600,
            //           ),
            //         ),
            //         if (widget.location!.addressLine1.isNotEmpty)
            //           Text(
            //             widget.location!.addressLine1,
            //             style: TextStyle(
            //               fontSize: 14,
            //               color: Colors.grey[600],
            //             ),
            //           ),
            //       ],
            //     ),
            //   ),
            //   const SizedBox(height: 24),
            // ],
            
            // Selection options and continue button
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var option in _options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedOption = option['title'] as String;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _selectedOption == option['title']
                              ? option['color'].withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedOption == option['title']
                                ? option['color']
                                : Colors.grey[300]!,
                            width: _selectedOption == option['title'] ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _selectedOption == option['title']
                                    ? option['color']
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                option['icon'] as IconData,
                                color: _selectedOption == option['title']
                                    ? Colors.white
                                    : Colors.grey[600],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option['title'] as String,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedOption == option['title']
                                          ? option['color']
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    option['description'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedOption == option['title'])
                              Icon(
                                Icons.check_circle,
                                color: option['color'],
                                size: 24,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Continue button just below the options
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedOption != null ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CameraScreen(
                            location: widget.location,
                            photoType: _selectedOption!,
                          ),
                        ),
                      );
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF35C2C1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue to Camera',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 