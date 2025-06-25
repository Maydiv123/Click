import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome package
import 'login_screen.dart'; // Import Login screen for navigation
import '../services/custom_auth_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final CustomAuthService _authService = CustomAuthService();
  bool _isLoading = false;
  String _selectedUserType = '';
  
  // Password visibility states
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Form controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
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
  String? _errorMessage;
  String? _userTypeError;

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
    _mobileController.dispose();
    _teamCodeController.dispose();
    _teamNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
    // Clear previous errors
    setState(() {
      _userTypeError = null;
      _passwordMatchError = null;
      _errorMessage = null;
    });

    // Validate user type selection
    if (_selectedUserType.isEmpty) {
      setState(() {
        _userTypeError = 'Please select your user type';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_passwordMatchError != null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get selected companies
      List<String> preferredCompanies = [];
      if (_ioclChecked) preferredCompanies.add('IOCL');
      if (_hpclChecked) preferredCompanies.add('HPCL');
      if (_bpclChecked) preferredCompanies.add('BPCL');

      // Use custom auth service instead of Firebase
      final result = await _authService.registerUser(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        mobile: _mobileController.text.trim(),
        password: _passwordController.text,
        userType: _selectedUserType,
        teamCode: _selectedUserType == 'member' ? _teamCodeController.text.trim() : null,
        teamName: _selectedUserType == 'leader' ? _teamNameController.text.trim() : null,
        preferredCompanies: preferredCompanies,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful!')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage ?? 'Registration failed')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.toString()}";
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  Widget _buildUserTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'I am',
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
                'user', // Internal user type value
                'Individual',
                Icons.person,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildUserTypeCard(
                'member', // Internal user type value
                'Team Member',
                Icons.group,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildUserTypeCard(
                'leader', // Internal user type value
                'Organization',
                Icons.admin_panel_settings,
              ),
            ),
          ],
        ),
        if (_userTypeError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _userTypeError!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserTypeCard(String type, String title, IconData icon) {
    bool isSelected = _selectedUserType == type;
    return InkWell(
      onTap: () => setState(() {
        _selectedUserType = type;
      }),
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

  bool get _showTeamCode => _selectedUserType == 'member';
  bool get _showTeamName => _selectedUserType == 'leader';

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
                        if (_showTeamCode)
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
                        if (_showTeamName)
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
                        
                        // Oil Company Selection
                        const Text(
                          'Select Your Company',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCompanyCard(
                                'IOCL',
                                _ioclChecked,
                                () => setState(() => _ioclChecked = !_ioclChecked),
                              ),
                              _buildCompanyCard(
                                'HPCL',
                                _hpclChecked,
                                () => setState(() => _hpclChecked = !_hpclChecked),
                              ),
                              _buildCompanyCard(
                                'BPCL',
                                _bpclChecked,
                                () => setState(() => _bpclChecked = !_bpclChecked),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildCompanyCard(String companyName, bool isSelected, VoidCallback onTap) {
    if (companyName == 'IOCL') {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 100,
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              isSelected
                ? 'assets/images/IOCL Color.png'
                : 'assets/images/IOCL B&W.png',
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    if (companyName == 'HPCL') {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 100,
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              isSelected
                ? 'assets/images/HPCL Color.png'
                : 'assets/images/HPCL B&W1.png',
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    if (companyName == 'BPCL') {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 100,
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              isSelected
                ? 'assets/images/BPCL Color.png'
                : 'assets/images/BPCL B&W1.png',
              width: 100,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    // For other companies, keep the existing design
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
      decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  companyName.substring(0, 1),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              companyName,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
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