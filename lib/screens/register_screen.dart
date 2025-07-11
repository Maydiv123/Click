import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Import Font Awesome package
import 'package:country_picker/country_picker.dart'; // Import country picker
import 'login_screen.dart'; // Import Login screen for navigation
import '../services/custom_auth_service.dart';
import 'home_screen.dart';
import 'package:flutter/services.dart';

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
  String? _companySelectionError;

  // Country code variables
  String _selectedCountryCode = '+91';
  String _selectedCountryName = 'India';
  String _selectedCountryFlag = '🇮🇳';

  // Input formatters for validation
  final RegExp _nameRegex = RegExp(r'^[a-zA-Z\s]+$');
  final RegExp _phoneRegex = RegExp(r'^[0-9]+$');
  final RegExp _mpinRegex = RegExp(r'^[0-9]{6}$');

  // Get full phone number with country code
  String get _fullPhoneNumber => '$_selectedCountryCode${_mobileController.text}';

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
        _passwordMatchError = 'MPINs do not match';
      });
    } else {
      setState(() {
        _passwordMatchError = null;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF35C2C1),
                  const Color(0xFF35C2C1).withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon with Animation
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Success Title
                const Text(
                  'Registration Successful!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                // Success Message
                const Text(
                  'Welcome to our community! Your account has been created successfully.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF35C2C1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  Future<void> _register() async {
    // Clear previous errors
    setState(() {
      _userTypeError = null;
      _passwordMatchError = null;
      _errorMessage = null;
      _companySelectionError = null;
    });

    // Collect all validation errors
    List<String> validationErrors = [];

    // Validate user type selection
    if (_selectedUserType.isEmpty) {
      validationErrors.add('Please select your user type');
    }

    // Validate company selection
    if (!_ioclChecked && !_hpclChecked && !_bpclChecked) {
      validationErrors.add('Please select at least one company');
    }

    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      // Form validation will show individual field errors
      // We don't need to add them to our list since they're shown inline
    }

    // Validate password match
    if (_passwordMatchError != null) {
      validationErrors.add(_passwordMatchError!);
    }

    // Validate MPIN format
    if (!_mpinRegex.hasMatch(_passwordController.text)) {
      validationErrors.add('MPIN must be exactly 6 digits');
    }

    // If there are any validation errors, show them all and return
    if (validationErrors.isNotEmpty) {
      setState(() {
        _userTypeError = validationErrors.contains('Please select your user type') ? 'Please select your user type' : null;
        _companySelectionError = validationErrors.contains('Please select at least one company') ? 'Please select at least one company' : null;
        _passwordMatchError = validationErrors.contains('MPINs do not match') ? 'MPINs do not match' : null;
        _errorMessage = validationErrors.contains('MPIN must be exactly 6 digits') ? 'MPIN must be exactly 6 digits' : null;
      });
      
      // Show all validation errors in a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please fix the following errors:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...validationErrors.map((error) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $error'),
              )),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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
        mobile: _fullPhoneNumber,
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
          _showSuccessDialog();
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
          'I Am',
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
      child: SizedBox(
        width: 60, // Reduced width for each box
        child: Container(
          padding: const EdgeInsets.all(10),
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
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12, // Smaller font size to fit in narrower box
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter your first name';
                            }
                            if (!_nameRegex.hasMatch(value!)) {
                              return 'First name can only contain letters';
                            }
                            if (value.length < 2) {
                              return 'First name must be at least 2 characters';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                          ],
                          textCapitalization: TextCapitalization.words,
                          decoration: _buildInputDecoration(
                            'First Name',
                            'e.g., John',
                            Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Last Name
                        TextFormField(
                          controller: _lastNameController,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter your last name';
                            }
                            if (!_nameRegex.hasMatch(value!)) {
                              return 'Last name can only contain letters';
                            }
                            if (value.length < 2) {
                              return 'Last name must be at least 2 characters';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                          ],
                          textCapitalization: TextCapitalization.words,
                          decoration: _buildInputDecoration(
                            'Last Name',
                            'e.g., Smith',
                            Icons.person_outline,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Mobile No
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mobile Number',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.transparent),
                              ),
                              child: Row(
                                children: [
                                  // Country Code Selector
                                  GestureDetector(
                                    onTap: _showCountryPicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _selectedCountryFlag,
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _selectedCountryCode,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Colors.grey[600],
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _mobileController,
                                      validator: (value) {
                                        if (value?.isEmpty ?? true) {
                                          return 'Please enter your mobile number';
                                        }
                                        if (!_phoneRegex.hasMatch(value!)) {
                                          return 'Mobile number can only contain digits';
                                        }
                                        if (_selectedCountryCode == '+91') {
                                          if (value.length != 10) return 'Indian phone number must be exactly 10 digits';
                                        } else {
                                          if (value.length < 6) return 'Phone number must be at least 6 digits';
                                          if (value.length > 15) return 'Phone number is too long';
                                        }
                                        return null;
                                      },
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                                        LengthLimitingTextInputFormatter(_selectedCountryCode == '+91' ? 10 : 15),
                                      ],
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter mobile number',
                                        border: InputBorder.none,
                                        filled: false,
                                        contentPadding: EdgeInsets.only(left: 4, right: 16, top: 16, bottom: 16),
                                        errorStyle: TextStyle(color: Colors.red, fontSize: 12),
                                        counterText: "",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          'Select Your Company *',
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
                        if (_companySelectionError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _companySelectionError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Please enter your MPIN';
                            if (!_mpinRegex.hasMatch(value!)) return 'MPIN must be exactly 6 digits';
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          keyboardType: TextInputType.number,
                          obscureText: !_isPasswordVisible,
                          decoration: _buildInputDecoration(
                            'MPIN',
                            'Enter New 6-digit MPIN',
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
                            if (value?.isEmpty ?? true) return 'Please confirm your MPIN';
                            if (!_mpinRegex.hasMatch(value!)) return 'MPIN must be exactly 6 digits';
                            if (value != _passwordController.text) return 'MPINs do not match';
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                            LengthLimitingTextInputFormatter(6),
                          ],
                          keyboardType: TextInputType.number,
                          obscureText: !_isConfirmPasswordVisible,
                          onChanged: _checkPasswordMatch,
                          decoration: _buildInputDecoration(
                            'Confirm MPIN',
                            'Re-enter New 6-digit MPIN',
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
                              backgroundColor: const Color(0xFF010269),
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
                                  color: Color(0xFF010269),
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

  void _showCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      showSearch: true,
      searchAutofocus: true,
      countryListTheme: CountryListThemeData(
        flagSize: 25,
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 16, color: Colors.black),
        bottomSheetHeight: 500,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        searchTextStyle: const TextStyle(fontSize: 16, color: Colors.black),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          hintText: 'Start typing to search',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderSide: BorderSide(
              color: const Color(0xFF8C98A8).withOpacity(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade300),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountryCode = '+${country.phoneCode}';
          _selectedCountryName = country.name;
          _selectedCountryFlag = country.flagEmoji;
        });
      },
    );
  }
} 