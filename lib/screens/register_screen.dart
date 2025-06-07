import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome package
import 'login_screen.dart'; // Import Login screen for navigation
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserService();
  final _authService = AuthService();
  bool _isLoading = false;
  UserType _selectedUserType = UserType.individual;
  
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
  final TextEditingController _teamNameController = TextEditingController();
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
    _teamNameController.dispose();
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordMatchError != null) return;

    setState(() => _isLoading = true);

    try {
      // Get selected companies
      List<String> preferredCompanies = [];
      if (_ioclChecked) preferredCompanies.add('IOCL');
      if (_hpclChecked) preferredCompanies.add('HPCL');
      if (_bpclChecked) preferredCompanies.add('BPCL');

      // Create user with Firebase Auth
      UserCredential userCredential = await _authService.createUserWithEmailAndPassword(
        email: _mobileController.text + '@click.com', // Using mobile as email
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phoneNumber: _mobileController.text,
        userType: _selectedUserType.toString().split('.').last,
        teamId: _selectedUserType == UserType.teamMember ? _teamCodeController.text : null,
      );

      // Update user document with additional details
      await _userService.updateUserDocument(
        userCredential.user!.uid,
        {
          'dob': _dobController.text,
          'address': _addressController.text,
          'aadharNo': _aadharController.text,
          'preferredCompanies': preferredCompanies,
          if (_selectedUserType == UserType.teamOwner) 'teamName': _teamNameController.text,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful!')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select User Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildUserTypeCard(
                UserType.individual,
                'Individual',
                Icons.person,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildUserTypeCard(
                UserType.teamMember,
                'Team Member',
                Icons.group,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildUserTypeCard(
                UserType.teamOwner,
                'Team Owner',
                Icons.admin_panel_settings,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserTypeCard(UserType type, String title, IconData icon) {
    bool isSelected = _selectedUserType == type;
    return InkWell(
      onTap: () => setState(() => _selectedUserType = type),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
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
                const SizedBox(height: 20),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Join our community today',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserTypeSelector(),
                        const SizedBox(height: 30),
                        
                        // First Name
                        TextFormField(
                          controller: _firstNameController,
                          validator: (value) => value?.isEmpty ?? true ? 'Please enter your first name' : null,
                          decoration: _buildInputDecoration(
                            'First Name',
                            'Enter your first name',
                            Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Last Name
                        TextFormField(
                          controller: _lastNameController,
                          validator: (value) => value?.isEmpty ?? true ? 'Please enter your last name' : null,
                          decoration: _buildInputDecoration(
                            'Last Name',
                            'Enter your last name',
                            Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // DOB
                        TextFormField(
                          controller: _dobController,
                          readOnly: true,
                          validator: (value) => value?.isEmpty ?? true ? 'Please select your date of birth' : null,
                          onTap: () => _selectDate(context),
                          decoration: _buildInputDecoration(
                            'Date of Birth',
                            'Select your date of birth',
                            Icons.calendar_today,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Address
                        TextFormField(
                          controller: _addressController,
                          validator: (value) => value?.isEmpty ?? true ? 'Please enter your address' : null,
                          maxLines: 3,
                          decoration: _buildInputDecoration(
                            'Address',
                            'Enter your complete address',
                            Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Aadhar No
                        TextFormField(
                          controller: _aadharController,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter your Aadhar number';
                            if (value!.length != 12) return 'Aadhar number must be 12 digits';
                            return null;
                          },
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          decoration: _buildInputDecoration(
                            'Aadhar No',
                            'Enter your 12-digit Aadhar number',
                            Icons.credit_card,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Mobile No
                        TextFormField(
                          controller: _mobileController,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter your mobile number';
                            if (value!.length != 10) return 'Mobile number must be 10 digits';
                            return null;
                          },
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          decoration: _buildInputDecoration(
                            'Mobile No',
                            'Enter your 10-digit mobile number',
                            Icons.phone_android,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Team Code (for team members)
                        if (_selectedUserType == UserType.teamMember)
                          TextFormField(
                            controller: _teamCodeController,
                            validator: (value) => value?.isEmpty ?? true ? 'Please enter team code' : null,
                            decoration: _buildInputDecoration(
                              'Team Code',
                              'Enter your team code',
                              Icons.group_work,
                            ),
                          ),

                        // Team Name (for team owners)
                        if (_selectedUserType == UserType.teamOwner)
                          TextFormField(
                            controller: _teamNameController,
                            validator: (value) => value?.isEmpty ?? true ? 'Please enter team name' : null,
                            decoration: _buildInputDecoration(
                              'Team Name',
                              'Enter your team name',
                              Icons.business,
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
                        _buildCompanyCheckbox('IOCL', _ioclChecked, (value) => setState(() => _ioclChecked = value ?? false)),
                        _buildCompanyCheckbox('HPCL', _hpclChecked, (value) => setState(() => _hpclChecked = value ?? false)),
                        _buildCompanyCheckbox('BPCL', _bpclChecked, (value) => setState(() => _bpclChecked = value ?? false)),
                        const SizedBox(height: 20),
                        
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter a password';
                            if (value!.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                          obscureText: !_isPasswordVisible,
                          decoration: _buildInputDecoration(
                            'Password',
                            'Enter your password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey[600],
                              ),
                              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password Field
                        TextFormField(
                          controller: _confirmPasswordController,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please confirm your password';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                          obscureText: !_isConfirmPasswordVisible,
                          onChanged: _checkPasswordMatch,
                          decoration: _buildInputDecoration(
                            'Confirm Password',
                            'Re-enter your password',
                            Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.grey[600],
                              ),
                              onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                            ),
                            errorText: _passwordMatchError,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Register',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Or Register with
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
                        const SizedBox(height: 20),

                        // Social Login Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildSocialButton(
                              onPressed: () {},
                              icon: FontAwesomeIcons.google,
                              color: Colors.red,
                            ),
                            _buildSocialButton(
                              onPressed: () {},
                              icon: FontAwesomeIcons.apple,
                              color: Colors.black,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginScreen()),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
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

  InputDecoration _buildInputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[600]),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
    );
  }

  Widget _buildCompanyCheckbox(String title, bool value, Function(bool?) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: CheckboxListTile(
        title: Text(title),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue,
        checkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5.0),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: FaIcon(icon, color: color),
        ),
      ),
    );
  }
} 