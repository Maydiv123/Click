import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import '../widgets/profile_completion_indicator.dart';
import '../widgets/bottom_navigation_bar_widget.dart';
import '../widgets/app_drawer.dart';
import '../services/database_service.dart';
import '../services/user_service.dart';
import '../services/custom_auth_service.dart';
import 'login_screen.dart';
import 'openstreet_map_screen.dart';
import 'search_petrol_pumps_screen.dart';
import 'nearest_petrol_pumps_screen.dart';
import '../widgets/modern_app_features.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final UserService _userService = UserService();
  final CustomAuthService _authService = CustomAuthService();
  
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  // Validation regex patterns
  final RegExp _nameRegex = RegExp(r'^[a-zA-Z\s]+$');
  final RegExp _phoneRegex = RegExp(r'^[0-9]+$');
  final RegExp _aadharRegex = RegExp(r'^[0-9]+$');

  // Country code variables
  String _selectedCountryCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  // Profession variables
  String? _selectedProfession;
  final List<String> _professions = [
    'Plumber',
    'Electrician', 
    'Supervisor',
    'Field boy',
    'Officer',
    'Site engineer',
    'Co-worker',
    'Mason',
    'Welder',
    'Carpenter',
  ];
  List<String> _filteredProfessions = [];
  final TextEditingController _professionSearchController = TextEditingController();

  // Date picker function
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    // Try to parse the current text as a date
    DateTime? initialDate;
    String currentText = controller.text;
    
    if (currentText.isNotEmpty && RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(currentText)) {
      try {
        final parts = currentText.split('/');
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        
        initialDate = DateTime(year, month, day);
        final currentDate = DateTime.now();
        
        // Check if the date is valid and not in the future
        if (initialDate.isAfter(currentDate) || year < 1900 || year > currentDate.year) {
          initialDate = DateTime.now().subtract(const Duration(days: 6570)); // Default to 18 years ago
        }
      } catch (e) {
        initialDate = DateTime.now().subtract(const Duration(days: 6570)); // Default to 18 years ago
      }
    } else {
      initialDate = DateTime.now().subtract(const Duration(days: 6570)); // Default to 18 years ago
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF35C2C1),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
    }
  }

  // Validate and set date from manual input
  void _validateAndSetDate(TextEditingController controller) {
    String text = controller.text;
    if (text.isNotEmpty && RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(text)) {
      try {
        final parts = text.split('/');
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        
        final enteredDate = DateTime(year, month, day);
        final currentDate = DateTime.now();
        
        if (enteredDate.isAfter(currentDate)) {
          // Show warning for future date
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Date of birth cannot be in the future'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          controller.clear();
        } else if (year < 1900 || year > currentDate.year) {
          // Show warning for invalid year
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please enter a valid year between 1900 and current year'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          controller.clear();
        }
      } catch (e) {
        // Show warning for invalid date
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Invalid date format. Please use DD/MM/YYYY'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        controller.clear();
      }
    }
  }

  void _showCompanySelectionDialog(String company, bool isSelected, Function() onConfirm) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isSelected ? Icons.remove_circle : Icons.add_circle,
                color: isSelected ? Colors.orange : const Color(0xFF35C2C1),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isSelected ? 'Remove Company' : 'Add Company',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            isSelected 
                ? 'Are you sure you want to remove $company from your preferred companies?'
                : 'You selected $company. Add it to your preferred companies?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.orange : const Color(0xFF35C2C1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'OK',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProfessionDialog(String? currentProfession, Function(String?) onProfessionSelected) {
    String searchQuery = '';
    List<String> filteredProfessions = List.from(_professions);
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Select Profession',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search TextField
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search professions...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value.toLowerCase();
                          filteredProfessions = _professions
                              .where((profession) => 
                                  profession.toLowerCase().contains(searchQuery))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Clear selection option
                    ListTile(
                      leading: const Icon(Icons.clear, color: Colors.grey),
                      title: const Text(
                        'Clear selection',
                        style: TextStyle(color: Colors.grey),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        onProfessionSelected(null);
                      },
                    ),
                    
                    const Divider(),
                    
                    // Filtered professions list
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredProfessions.length,
                        itemBuilder: (context, index) {
                          final profession = filteredProfessions[index];
                          final isSelected = currentProfession == profession;
                          
                          return ListTile(
                            leading: Icon(
                              Icons.work,
                              color: isSelected ? const Color(0xFF35C2C1) : Colors.grey,
                            ),
                            title: Text(
                              profession,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? const Color(0xFF35C2C1) : Colors.black,
                              ),
                            ),
                            trailing: isSelected 
                                ? const Icon(Icons.check, color: Color(0xFF35C2C1))
                                : null,
                            onTap: () {
                              Navigator.of(context).pop();
                              onProfessionSelected(profession);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
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
            borderSide: BorderSide(color: const Color(0xFF35C2C1).withOpacity(0.3)),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountryCode = '+${country.phoneCode}';
          _selectedCountryFlag = country.flagEmoji;
        });
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _professionSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get user data from CustomAuthService
      final userData = await _authService.getCurrentUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEditProfileModal(Map<String, dynamic> userData) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController firstNameController = TextEditingController(text: userData['firstName'] ?? '');
    final TextEditingController lastNameController = TextEditingController(text: userData['lastName'] ?? '');
    final TextEditingController dobController = TextEditingController(text: userData['dob'] ?? '');
    final TextEditingController addressController = TextEditingController(text: userData['address'] ?? '');
    final TextEditingController aadharController = TextEditingController(text: userData['aadharNo'] ?? '');
    
    // Extract phone number and country code from stored mobile
    String storedMobile = userData['mobile'] ?? '';
    String phoneNumber = '';
    String countryCode = '+91';
    String countryFlag = '🇮🇳';
    
    if (storedMobile.isNotEmpty) {
      if (storedMobile.startsWith('+91')) {
        countryCode = '+91';
        countryFlag = '🇮🇳';
        phoneNumber = storedMobile.substring(3); // Remove +91
      } else if (storedMobile.startsWith('+')) {
        // Handle other country codes
        int plusIndex = storedMobile.indexOf('+');
        int spaceIndex = storedMobile.indexOf(' ', plusIndex);
        if (spaceIndex != -1) {
          countryCode = storedMobile.substring(plusIndex, spaceIndex);
          phoneNumber = storedMobile.substring(spaceIndex + 1);
        } else {
          // Try to extract country code (assuming 2-3 digits after +)
          for (int i = 1; i <= 3; i++) {
            if (storedMobile.length > i) {
              String potentialCode = storedMobile.substring(0, i + 1);
              if (potentialCode.startsWith('+')) {
                countryCode = potentialCode;
                phoneNumber = storedMobile.substring(i + 1);
                break;
              }
            }
          }
        }
      } else {
        // No country code, assume it's just the phone number
        phoneNumber = storedMobile;
      }
    }
    
    final TextEditingController mobileController = TextEditingController(text: phoneNumber);
    
    // Initialize profession
    String? currentProfession = userData['profession'];
    
    // Convert to Set to remove duplicates, then back to List
    List<String> oilCompanies = userData['preferredCompanies'] != null 
        ? List<String>.from(Set<String>.from(userData['preferredCompanies'] as List))
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Set the country code and flag for this modal
            _selectedCountryCode = countryCode;
            _selectedCountryFlag = countryFlag;
            // Initialize profession
            _selectedProfession = currentProfession;
            
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: firstNameController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                        ],
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'First name is required';
                          }
                          if (!_nameRegex.hasMatch(value)) {
                            return 'First name can only contain letters';
                          }
                          if (value.length < 2) {
                            return 'First name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: lastNameController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                        ],
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Last name is required';
                          }
                          if (!_nameRegex.hasMatch(value)) {
                            return 'Last name can only contain letters';
                          }
                          if (value.length < 2) {
                            return 'Last name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _selectDate(context, dobController),
                        child: TextFormField(
                          controller: dobController,
                          readOnly: true,
                              decoration: InputDecoration(
                              labelText: 'Date of Birth (DD/MM/YYYY)',
                              filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                              onPressed: () => _selectDate(context, dobController),
                            ),
                          ),
                          // Removed validator to make it optional
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: 'Address',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        // Removed validator to make it optional
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: aadharController,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                          LengthLimitingTextInputFormatter(14), // 12 digits + 2 spaces
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final text = newValue.text.replaceAll(' ', '');
                            if (text.length <= 12) {
                              String formatted = '';
                              for (int i = 0; i < text.length; i++) {
                                if (i > 0 && i % 4 == 0) {
                                  formatted += ' ';
                                }
                                formatted += text[i];
                              }
                              return TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(offset: formatted.length),
                              );
                            }
                            return oldValue;
                          }),
                        ],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Aadhar No (XXXX XXXX XXXX)',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final digitsOnly = value.replaceAll(' ', '');
                            if (!_aadharRegex.hasMatch(digitsOnly)) {
                              return 'Aadhar number can only contain digits';
                            }
                            if (digitsOnly.length != 12) {
                              return 'Aadhar number must be exactly 12 digits';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Mobile Number with Country Code
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
                              borderRadius: BorderRadius.circular(12),
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
                                // Phone Number Input
                                Expanded(
                                  child: TextFormField(
                                    controller: mobileController,
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
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Mobile number is required';
                                      }
                                      if (!_phoneRegex.hasMatch(value)) {
                                        return 'Mobile number can only contain digits';
                                      }
                                      if (_selectedCountryCode == '+91') {
                                        if (value.length != 10) return 'Indian phone number must be exactly 10 digits';
                                        if (!value.startsWith(RegExp(r'[6-9]'))) {
                                          return 'Mobile number should start with 6, 7, 8, or 9';
                                        }
                                      } else {
                                        if (value.length < 6) return 'Phone number must be at least 6 digits';
                                        if (value.length > 15) return 'Phone number is too long';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Profession Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profession',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              _showProfessionDialog(_selectedProfession, (String? profession) {
                                setModalState(() {
                                  _selectedProfession = profession;
                                });
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedProfession ?? 'Select your profession',
                                      style: TextStyle(
                                        color: _selectedProfession != null ? Colors.black : Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Preferred Oil Companies', style: TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['IOCL', 'HPCL', 'BPCL'].map((company) {
                          final isSelected = oilCompanies.contains(company);
                          return GestureDetector(
                            onTap: () {
                              if (isSelected) {
                                // Check if this is the last selected company
                                if (oilCompanies.length > 1) {
                                  _showCompanySelectionDialog(company, true, () {
                                    setModalState(() {
                                      oilCompanies.remove(company);
                                    });
                                  });
                                } else {
                                  // Show warning when trying to deselect the last company
                                  _showCompanySelectionDialog(company, true, () {
                                    // Don't remove the last company
                                  });
                                }
                              } else {
                                _showCompanySelectionDialog(company, false, () {
                                  setModalState(() {
                                    oilCompanies.add(company);
                                  });
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF35C2C1) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                company,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              // Validate that at least one oil company is selected
                              if (oilCompanies.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚠️ Please select at least one oil company'),
                                    backgroundColor: Colors.orange,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                                return;
                              }
                              
                              final userId = await _authService.getCurrentUserId();
                              if (userId == null) return;
                              final data = {
                                'firstName': firstNameController.text.trim(),
                                'lastName': lastNameController.text.trim(),
                                'dob': dobController.text.trim(),
                                'address': addressController.text.trim(),
                                'aadharNo': aadharController.text.trim(),
                                'mobile': _selectedCountryCode + mobileController.text.trim(),
                                'profession': _selectedProfession,
                                'preferredCompanies': oilCompanies,
                              };
                              await _authService.updateUserProfile(userId, data);
                              
                              // Refresh user data immediately
                              final updatedUserData = await _authService.getCurrentUserData();
                              if (mounted) {
                                setState(() {
                                  _userData = updatedUserData;
                                });
                              }
                              
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully!'),
                                  backgroundColor: Color(0xFF35C2C1),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF35C2C1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }

  double _calculateProfileCompletion(Map<String, dynamic> userData) {
    int totalFields = 5; // Removed Aadhar from required fields
    int completedFields = 0;
    if (userData['firstName'] != null && userData['firstName'].toString().isNotEmpty) completedFields++;
    if (userData['lastName'] != null && userData['lastName'].toString().isNotEmpty) completedFields++;
    if (userData['mobile'] != null && userData['mobile'].toString().isNotEmpty) completedFields++;
    if (userData['dob'] != null && userData['dob'].toString().isNotEmpty) completedFields++;
    if (userData['address'] != null && userData['address'].toString().isNotEmpty) completedFields++;
    return (completedFields / totalFields) * 100;
  }

  void _signOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const AppDrawer(currentScreen: 'profile'),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings will be available in the next update!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: _databaseService.getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF35C2C1)));
          }
          final userData = snapshot.data!;
          final completionPercentage = _calculateProfileCompletion(userData);
          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF35C2C1), const Color(0xFF35C2C1).withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              backgroundImage: userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty
                                ? NetworkImage(userData['profileImage'])
                                : null,
                              child: (userData['profileImage'] == null || userData['profileImage'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 50, color: Colors.white)
                                : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile photo upload will be available in the next update!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: const Icon(Icons.camera_alt, color: Color(0xFF35C2C1), size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "${userData["firstName"] ?? ''} ${userData["lastName"] ?? ''}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        userData["mobile"] ?? 'No mobile number',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          userData['userType']?.toString().replaceAll('UserType.', '') ?? 'User',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Profile Completion',
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${completionPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: completionPercentage / 100,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              color: Colors.white,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showEditProfileModal(userData),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF35C2C1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Personal Information
                _buildSectionCard(
                  title: 'Personal Information',
                  icon: Icons.person,
                  children: [
                    _buildInfoItem('Date of Birth', userData["dob"] ?? 'Not provided', Icons.cake),
                    const Divider(height: 24),
                    _buildInfoItem('Address', userData["address"] ?? 'Not provided', Icons.location_on),
                    const Divider(height: 24),
                    _buildInfoItem('Profession', userData["profession"] ?? 'Not provided', Icons.work),
                    const Divider(height: 24),
                    _buildInfoItem('Aadhar No', userData["aadharNo"] ?? 'Not provided', Icons.badge),
                  ],
                ),

                // Team Information
                _buildSectionCard(
                  title: 'Team Information',
                  icon: Icons.group,
                  children: [
                    _buildInfoItem('Team Name', userData["teamName"] ?? 'Not in a team', Icons.groups),
                    if (userData["teamCode"] != null) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tag, size: 20, color: Color(0xFF35C2C1)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Team Code',
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                ),
                                Text(
                                  userData["teamCode"] ?? '',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.copy, size: 20, color: Color(0xFF35C2C1)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Team code copied to clipboard!'))
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),
                    _buildInfoItem(
                      'Team Role', 
                      userData["userType"]?.toString().replaceAll('UserType.', '') ?? 'Member', 
                      Icons.badge
                    ),
                  ],
                ),

                // Preferred Oil Companies
                _buildSectionCard(
                  title: 'Preferred Oil Companies',
                  icon: Icons.local_gas_station,
                  children: [
                    if ((userData["preferredCompanies"] as List?)?.isNotEmpty == true)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: (userData["preferredCompanies"] as List).map<Widget>((company) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF35C2C1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF35C2C1).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_gas_station, size: 16, color: Color(0xFF35C2C1)),
                                const SizedBox(width: 6),
                                Text(
                                  company,
                                  style: const TextStyle(color: Color(0xFF35C2C1), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.info_outline, size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No preferred companies selected',
                                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _showEditProfileModal(userData),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Companies'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF35C2C1),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Logout button
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final shouldLogout = await LogoutConfirmationDialog.show(context);
                        if (shouldLogout) {
                          _signOut();
                        }
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NearestPetrolPumpsScreen()),
          );
        },
        backgroundColor: const Color(0xFF35C2C1),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 4, // Profile index
        onTap: (index) {
          switch (index) {
            case 0: // Home
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1: // Map
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const OpenStreetMapScreen()),
              );
              break;
            case 3: // Search
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SearchPetrolPumpsScreen()),
              );
              break;
            case 4: // Profile
              // Already on profile screen, do nothing
              break;
          }
        },
        showFloatingActionButton: true,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35C2C1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF35C2C1), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF35C2C1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF35C2C1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 