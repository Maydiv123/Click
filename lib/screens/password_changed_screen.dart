import 'package:flutter/material.dart';
import 'package:click/screens/login_screen.dart';

class PasswordChangedScreen extends StatelessWidget {
  const PasswordChangedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Placeholder for the success icon
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 100,
            ),
            SizedBox(height: 20),
            Text(
              'Password Changed!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Your password has been changed\n              successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                // Navigate back to Login screen
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false, // Remove all routes below Login
                );
              },
              child: Text('Back to Login'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(200, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 