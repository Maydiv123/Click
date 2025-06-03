import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome package
import 'package:click/screens/login_screen.dart'; // Import Login screen for navigation

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  // Password visibility states
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Form controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _teamCodeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // Checkbox states
  bool _ioclChecked = false;
  bool _hpclChecked = false;
  bool _bpclChecked = false;

  // Add a variable to track password match status
  String? _passwordMatchError;

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _aadharController.dispose();
    _mobileController.dispose();
    _teamCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  // Add a method to check password match
  void _checkPasswordMatch(String confirmPassword) {
    if (confirmPassword.isEmpty) {
      setState(() {
        _passwordMatchError = null;
      });
    } else if (_passwordController.text != confirmPassword) {
      setState(() {
        _passwordMatchError = 'Passwords do not match';
      });
    } else {
      setState(() {
        _passwordMatchError = null;
      });
    }
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
                      // First Name
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Enter your first name',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
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
                      
                      // Last Name
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Enter your last name',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
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
                      
                      // DOB
                      TextField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        decoration: InputDecoration(
                          labelText: 'Date of Birth',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Select your date of birth',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Address
                      TextField(
                        controller: _addressController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Enter your complete address',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
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
                      
                      // Aadhar No
                      TextField(
                        controller: _aadharController,
                        keyboardType: TextInputType.number,
                        maxLength: 12,
                        decoration: InputDecoration(
                          labelText: 'Aadhar No',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Enter your 12-digit Aadhar number',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Mobile No
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: InputDecoration(
                          labelText: 'Mobile No',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Enter your 10-digit mobile number',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Team Code
                      TextField(
                        controller: _teamCodeController,
                        decoration: InputDecoration(
                          labelText: 'Team Code',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Enter your team code',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
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
                      
                      // Oil Company Checkboxes
                      const Text(
                        'Select Oil Company',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      CheckboxListTile(
                        title: const Text('IOCL'),
                        value: _ioclChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            _ioclChecked = value ?? false;
                          });
                        },
                        activeColor: Colors.blue,
                        checkColor: Colors.white,
                      ),
                      CheckboxListTile(
                        title: const Text('HPCL'),
                        value: _hpclChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            _hpclChecked = value ?? false;
                          });
                        },
                        activeColor: Colors.blue,
                        checkColor: Colors.white,
                      ),
                      CheckboxListTile(
                        title: const Text('BPCL'),
                        value: _bpclChecked,
                        onChanged: (bool? value) {
                          setState(() {
                            _bpclChecked = value ?? false;
                          });
                        },
                        activeColor: Colors.blue,
                        checkColor: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      
                      // Password Field
                      TextField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Enter your password',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
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

                      // Confirm Password Field
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: !_isConfirmPasswordVisible,
                        onChanged: _checkPasswordMatch,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          hintText: 'Re-enter your password',
                          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          labelStyle: const TextStyle(fontSize: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          fillColor: Colors.grey[200],
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          errorText: _passwordMatchError,
                          errorStyle: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30), // Spacing before Register button
                      ElevatedButton(
                        onPressed: () {
                          // Password validation
                          if (_passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a password')),
                            );
                            return;
                          }
                          if (_confirmPasswordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please confirm your password')),
                            );
                            return;
                          }
                          if (_passwordMatchError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fix the password mismatch')),
                            );
                            return;
                          }
                          // Continue with registration logic
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
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
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