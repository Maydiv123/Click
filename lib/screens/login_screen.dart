import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'map_screen.dart';
import '../services/auth_service.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget { 
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isPasswordVisible = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _authService = AuthService();

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
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = "Starting login process...";
    });
    
    try {
      final email = _phoneController.text + '@click.com';
      
      setState(() {
        _errorMessage = "Direct login attempt with Firebase...";
      });
      await Future.delayed(Duration(milliseconds: 300));
      
      try {
        // Use Firebase Auth directly for debugging
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
        
        final uid = userCredential.user?.uid;
        setState(() {
          _errorMessage = "Auth successful! UID: $uid";
        });
        await Future.delayed(Duration(milliseconds: 300));
        
        // Only proceed if we have a user
        if (userCredential.user == null) {
          setState(() {
            _errorMessage = "ERROR: User is null after successful auth";
            _isLoading = false;
          });
          return;
        }
        
        // Check Firestore user document
        setState(() {
          _errorMessage = "Checking Firestore user document...";
        });
        await Future.delayed(Duration(milliseconds: 300));
        
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
              
          if (!userDoc.exists) {
            setState(() {
              _errorMessage = "ERROR: No user document found for UID: $uid";
              _isLoading = false;
            });
            return;
          }
          
          // Show user data briefly
          Map<String, dynamic>? data = userDoc.data();
          String dataStr = "User document exists";
          if (data != null) {
            List<String> fields = [];
            if (data['firstName'] != null) fields.add("firstName: ${data['firstName']}");
            if (data['lastName'] != null) fields.add("lastName: ${data['lastName']}");
            if (data['mobile'] != null) fields.add("mobile: ${data['mobile']}");
            if (fields.isNotEmpty) {
              dataStr = fields.join(", ");
            }
          }
          
          setState(() {
            _errorMessage = "User data: $dataStr";
          });
          await Future.delayed(Duration(milliseconds: 500));
          
          // Try updating last login
          setState(() {
            _errorMessage = "Updating last login...";
          });
          
          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).update({
              'lastLogin': FieldValue.serverTimestamp(),
            });
            
            setState(() {
              _errorMessage = "Last login updated successfully";
            });
            await Future.delayed(Duration(milliseconds: 300));
            
            // Success! Navigate to home
            setState(() {
              _errorMessage = "Login successful! Redirecting...";
            });
            
            // Navigate with delay to show message
            await Future.delayed(Duration(milliseconds: 500));
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          } catch (updateError) {
            setState(() {
              _errorMessage = "ERROR updating lastLogin: ${updateError.toString()}";
              _isLoading = false;
            });
          }
          
        } catch (firestoreError) {
          setState(() {
            _errorMessage = "Firestore error: ${firestoreError.toString()}";
            _isLoading = false;
          });
        }
      } catch (authError) {
        if (authError is FirebaseAuthException) {
          String message = "Firebase Auth Error: [${authError.code}] ${authError.message}";
          setState(() {
            _errorMessage = message;
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = "Auth error: ${authError.toString()}";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Unexpected error: [${e.runtimeType}] ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(''),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Welcome back! Glad\n to see you, Again!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      // margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '+91',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: 'Enter your Mobile Number',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    fillColor: Colors.grey[200],
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    counterText: "",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your phone number';
                    if (value.length != 10) return 'Phone number must be 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
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
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your password';
                    if (value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                       Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                      );
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 30),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account?",
                              style: TextStyle(fontSize: 16, color: Colors.black54),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                );
                              },
                              child: Text(
                                'Register Now',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF35C2C1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 