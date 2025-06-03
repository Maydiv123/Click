import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome package
import 'package:click/screens/login_screen.dart'; // Import Login screen for navigation

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  bool _isPasswordVisible = false;
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
        title: const Text(''), // Empty title to match the screenshot
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
                'Hello! Register to get\nstarted',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black), // Set text color to black
              ),
              const SizedBox(height: 40), // Increased spacing
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Email',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                       TextField(
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                               color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                       TextField(
                        decoration: InputDecoration(
                          hintText: 'Aadhar No',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                       TextField(
                        decoration: InputDecoration(
                          hintText: 'Company',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                       TextField(
                        decoration: InputDecoration(
                          hintText: 'Role',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 30), // Spacing before Register button
                      ElevatedButton(
                        onPressed: () {
                          // Register logic
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
                        child: const Text('Register', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), // Button text style
                      ),
                      const SizedBox(height: 30), // Increased spacing
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Colors.grey)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'Or Register with',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ),
                          const Expanded(child: Divider(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 20), // Spacing after separator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Social login buttons (Google, Apple)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12), // Adjust padding
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10), // Rounded corners
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300), // Light grey border
                                ),
                                child: const FaIcon(FontAwesomeIcons.google, color: Colors.red), // Google Icon
                              ),
                            ),
                          ),
                           Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5.0),
                              child: OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12), // Adjust padding
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10), // Rounded corners
                                  ),
                                  side: BorderSide(color: Colors.grey.shade300), // Light grey border
                                ),
                                child: const FaIcon(FontAwesomeIcons.apple, color: Colors.black), // Apple Icon
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40), // Increased spacing
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account?",
                            style: TextStyle(fontSize: 16, color: Colors.black54), // Adjusted text color
                          ),
                          TextButton(
                            onPressed: () {
                               Navigator.pushReplacement(
                                 context,
                                 MaterialPageRoute(builder: (context) => const LoginScreen()), // Navigate to Login screen
                               );
                            },
                            child: Text(
                              'Login Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF35C2C1), // Use accent color for Login Now
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40), // Added padding below the text
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 