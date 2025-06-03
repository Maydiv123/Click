import 'package:flutter/material.dart';
import 'package:click/screens/otp_verification_screen.dart';
import 'package:click/screens/login_screen.dart'; // Import login screen for navigation

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black), // Set back icon color to black
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Forgot Password?'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // Increased horizontal padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40), // Spacing from top
              const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black), // Set text color to black
              ),
              const SizedBox(height: 10), // Spacing after title
              Text(
                'Don\'t worry! It occurs. Please enter the email address linked with your account.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]), // Grey text color
              ),
              const SizedBox(height: 40), // Increased spacing
              TextField(
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(color: Colors.grey[600]), // Darker hint text
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: Colors.grey[200], // Light grey background
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Adjust padding
                ),
              ),
              const SizedBox(height: 40), // Spacing before button
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch button horizontally
                    children: [
                      ElevatedButton(
                        onPressed: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const OtpVerificationScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56), // Increased height
                          backgroundColor: Colors.black, // Black background
                          foregroundColor: Colors.white, // White text
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10), // Rounded corners
                          ),
                          elevation: 0, // No shadow
                        ),
                        child: const Text('Send Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Button text style
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40), // Increased spacing
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Remember Password?",
                    style: TextStyle(fontSize: 16, color: Colors.black54), // Adjusted text color
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Go back to Login screen
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF35C2C1), // Use accent color for Login
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 