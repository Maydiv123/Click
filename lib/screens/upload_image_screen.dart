import 'package:flutter/material.dart';

class UploadImageScreen extends StatelessWidget {
  const UploadImageScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Upload Image'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Placeholder for the captured image
            Expanded(
              child: Container(
                color: Colors.grey[300], // Represents the image area
                child: Center(
                  child: Text(
                    'Captured Image Placeholder',
                    style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            // User and location details
            Row(
              children: [
                CircleAvatar(
                  radius: 30, // Placeholder for user profile picture
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, size: 30, color: Colors.white),
                ),
                SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cameron Williamson', // Placeholder user name
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Agent', // Placeholder user role
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.redAccent), // Placeholder location icon
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text(
                        '2972 Westheimer Rd. Santa Ana, Illinois 85486', // Placeholder location
                        style: TextStyle(fontSize: 16),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
             Row(
              children: [
                Icon(Icons.access_time, color: Colors.blueGrey), // Placeholder time icon
                SizedBox(width: 10),
                Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text('Current Date & Time', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text(
                      '9 May 2025, 03:00PM', // Placeholder date and time
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Upload image logic
              },
              child: Text('Upload Image'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                 backgroundColor: Colors.blue, // Example button color
                 foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 