import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../services/map_service.dart';
import '../services/petrol_pump_request_service.dart';
import '../services/custom_auth_service.dart';
import '../services/petrol_pump_lookup_service.dart';
import '../models/map_location.dart';
import '../models/petrol_pump_request.dart';
import '../widgets/app_drawer.dart';
import '../services/storage_service.dart';

class AddPetrolPumpScreen extends StatefulWidget {
  const AddPetrolPumpScreen({Key? key}) : super(key: key);

  @override
  State<AddPetrolPumpScreen> createState() => _AddPetrolPumpScreenState();
}

class _AddPetrolPumpScreenState extends State<AddPetrolPumpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapService = MapService();
  final _requestService = PetrolPumpRequestService();
  final _storageService = StorageService();
  final _authService = CustomAuthService();
  final _jsonController = TextEditingController();
  final _petrolPumpLookupService = PetrolPumpLookupService();
  
  // Form controllers
  final _zoneController = TextEditingController();
  final _salesAreaController = TextEditingController();
  final _coClDoController = TextEditingController();
  final _districtController = TextEditingController();
  final _sapCodeController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();
  final _pincodeController = TextEditingController();
  final _dealerNameController = TextEditingController();
  final _contactDetailsController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _regionalOfficeController = TextEditingController();
  
  // Company selection
  final List<String> _companies = ['HPCL', 'BPCL', 'IOCL'];
  String _selectedCompany = 'HPCL';
  bool _isLoading = false;
  
  // Image pickers
  final ImagePicker _picker = ImagePicker();
  XFile? _bannerImage;
  XFile? _boardImage;
  XFile? _billSlipImage;
  XFile? _governmentDocImage;
  
  // Progress tracking
  double _progressValue = 0.0;
  
  // Location variables
  bool _isGettingLocation = false;
  String _locationError = '';
  
  // Import progress
  bool _isImporting = false;
  int _importProgress = 0;
  int _totalItems = 0;
  String _importStatus = '';
  
  @override
  void initState() {
    super.initState();
    // Initialize location controller with empty string since it's hidden
    _locationController.text = "";
    
    _updateProgress();
    
    // Add listener to pincode field to auto-fetch details when pincode is entered
    _pincodeController.addListener(_onPincodeChanged);
  }
  
  @override
  void dispose() {
    _pincodeController.removeListener(_onPincodeChanged);
    
    _jsonController.dispose();
    _zoneController.dispose();
    _salesAreaController.dispose();
    _coClDoController.dispose();
    _districtController.dispose();
    _sapCodeController.dispose();
    _customerNameController.dispose();
    _locationController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    _pincodeController.dispose();
    _dealerNameController.dispose();
    _contactDetailsController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _regionalOfficeController.dispose();
    
    // Clean up image files if needed
    _bannerImage = null;
    _boardImage = null;
    _billSlipImage = null;
    _governmentDocImage = null;
    
    super.dispose();
  }
  
  // Listener for pincode changes
  void _onPincodeChanged() {
    final pincode = _pincodeController.text.trim();
    if (pincode.length == 6) {
      // Only trigger lookup when a complete 6-digit pincode is entered
      _fetchPetrolPumpByPincodeAndLocation();
    }
  }

  void _updateProgress() {
    // Update total fields count (removed optional fields from required count and location field)
    int totalFields = 13; // Reduced from 14 to 13 (removed location field as it's hidden now)
    int filledFields = 0;
    
    // Required fields
    if (_zoneController.text.isNotEmpty) filledFields++;
    if (_salesAreaController.text.isNotEmpty) filledFields++;
    if (_coClDoController.text.isNotEmpty) filledFields++;
    if (_districtController.text.isNotEmpty) filledFields++;
    if (_regionalOfficeController.text.isNotEmpty) filledFields++;
    if (_customerNameController.text.isNotEmpty) filledFields++;
    // Location field is hidden and not counted
    if (_addressLine1Controller.text.isNotEmpty) filledFields++;
    if (_pincodeController.text.isNotEmpty) filledFields++;
    if (_dealerNameController.text.isNotEmpty) filledFields++;
    if (_contactDetailsController.text.isNotEmpty) filledFields++;
    if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty) filledFields++;
    if (_bannerImage != null) filledFields++;
    if (_boardImage != null) filledFields++;
    
    // Optional fields - these contribute to progress but aren't required
    // We'll give them half weight compared to required fields
    int optionalFieldsCount = 0;
    int optionalFieldsFilled = 0;
    
    if (_sapCodeController.text.isNotEmpty) optionalFieldsFilled++;
    if (_addressLine2Controller.text.isNotEmpty) optionalFieldsFilled++;
    if (_billSlipImage != null) optionalFieldsFilled++;
    if (_governmentDocImage != null) optionalFieldsFilled++;
    
    optionalFieldsCount = 4; // Total optional fields
    
    // Calculate progress including optional fields with reduced weight
    double requiredProgress = filledFields / totalFields;
    double optionalProgress = (optionalFieldsFilled / optionalFieldsCount) * 0.1; // Optional fields contribute up to 10% extra
    
    setState(() {
      _progressValue = requiredProgress + optionalProgress;
      // Cap at 1.0 in case optional fields push it over 100%
      if (_progressValue > 1.0) _progressValue = 1.0;
    });
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = '';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = 'Location permission denied';
            _isGettingLocation = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permissions permanently denied';
          _isGettingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
        _isGettingLocation = false;
      });
      
      // After getting coordinates, try to fetch petrol pump details
      if (_pincodeController.text.isNotEmpty && _pincodeController.text.length == 6) {
        _fetchPetrolPumpByPincodeAndLocation();
      }
      
      _updateProgress();
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isGettingLocation = false;
      });
    }
  }

  // Fetch petrol pump details based on selected company, pincode, and coordinates
  Future<void> _fetchPetrolPumpByPincodeAndLocation() async {
    // Check if we have both pincode and coordinates
    if (_pincodeController.text.isEmpty || _latitudeController.text.isEmpty || _longitudeController.text.isEmpty) {
      // We need both pincode and coordinates to proceed
      return;
    }
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final pincode = _pincodeController.text.trim();
      final latitude = double.parse(_latitudeController.text);
      final longitude = double.parse(_longitudeController.text);
      
      // Find nearest petrol pump based on company, pincode, and coordinates
      final nearestPump = await _petrolPumpLookupService.findNearestPetrolPumpByCompanyAndPincode(
        _selectedCompany,
        pincode,
        latitude,
        longitude
      );
      
      if (nearestPump != null) {
        // Auto-fill only the specific fields (District, Regional office, Sales Area, Zone, CO/CL/DO)
        // Leave all other fields for the user to fill in
        setState(() {
          _districtController.text = nearestPump.district;
          _salesAreaController.text = nearestPump.salesArea;
          _zoneController.text = nearestPump.zone;
          _regionalOfficeController.text = nearestPump.regionalOffice; // Use regionalOffice directly
          _coClDoController.text = nearestPump.coClDo; // Auto-fill CO/CL/DO field
          
          // Note: The following fields are intentionally NOT auto-filled:
          // - customerName
          // - dealerName
          // - contactDetails
          // - sapCode
          // - location
          // - addressLine1
          // - addressLine2
          // - All images (banner, board, bill slip, government doc)
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-filled administrative fields from nearest ${_selectedCompany} petrol pump'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No ${_selectedCompany} petrol pump found with pincode $pincode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching petrol pump details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      _updateProgress();
    }
  }

  Future<void> _importFromJson() async {
    try {
      final jsonString = _jsonController.text.trim();
      if (jsonString.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter JSON data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isImporting = true;
        _importProgress = 0;
        _importStatus = 'Parsing JSON...';
      });

      final List<dynamic> jsonData = json.decode(jsonString);

      setState(() {
        _totalItems = jsonData.length;
        _importStatus = 'Importing data...';
      });

      for (int i = 0; i < jsonData.length; i++) {
        final data = jsonData[i];
        try {
          final location = MapLocation(
            zone: data['Zone']?.toString() ?? '',
            salesArea: data['Sales Area']?.toString() ?? '',
            coClDo: data['CO/CL/DO']?.toString() ?? '',
            district: data['District']?.toString() ?? '',
            sapCode: data['SAP Code']?.toString() ?? '',
            customerName: data['Customer Name']?.toString() ?? '',
            location: data['Location']?.toString() ?? '',
            addressLine1: data['Address Line1']?.toString() ?? '',
            addressLine2: data['Address Line2']?.toString() ?? '',
            pincode: data['Pincode']?.toString() ?? '',
            dealerName: data['Dealer Name']?.toString() ?? '',
            contactDetails: data['Contact details']?.toString() ?? '',
            latitude: (data['Lat'] ?? 0.0).toDouble(),
            longitude: (data['Long'] ?? 0.0).toDouble(),
          );

          await _mapService.addMapLocation(location);
          
          setState(() {
            _importProgress = i + 1;
            _importStatus = 'Imported ${i + 1} of $_totalItems items';
          });
        } catch (e) {
          // Error handling
          continue;
        }
      }

      setState(() {
        _isImporting = false;
        _importStatus = 'Import completed!';
        _jsonController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data imported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _importStatus = 'Error: $e';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showJsonInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Import JSON Data', style: TextStyle(color: Color(0xFF35C2C1), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter JSON data in the following format:',
                style: TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text(
                  '''[
  {
    "Zone": "NORTH WEST FRONTIER ZONE",
    "Sales Area": "UDAIPUR RETAIL SA",
    "CO/CL/DO": "CO",
    "District": "UDAIPUR",
    "SAP Code": 41049691,
    "Customer Name": "M/s.MODERN SERVICE STATION",
    "Location": "UDAIPUR",
    "Address Line1": "HP PETROL PUMP",
    "Address Line2": "HOSPITAL ROAD",
    "Address Line3": "UDAIPUR",
    "Address Line4": "UDAIPUR",
    "Pincode": 313001,
    "Dealer Name": "Surendra Kumar Nahar",
    "Contact details": 8949495349,
    "Lat": 24.589795,
    "Long": 73.695265
  }
]''',
                  style: TextStyle(
                    color: Colors.black87,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jsonController,
                style: const TextStyle(color: Colors.black87),
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Paste your JSON data here...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF35C2C1), width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _importFromJson();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF35C2C1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Check if the form is at least 70% complete based on required fields only
      // We've already adjusted the progress calculation to handle optional fields
      if (_progressValue < 0.7) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please complete at least 70% of the required fields before submitting'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text('Submitting your request...'),
                ],
              ),
            ),
          );
        },
      );
      
      try {
        // Upload images to Firebase Storage
        String bannerImageUrl = '';
        String boardImageUrl = '';
        String billSlipImageUrl = '';
        String governmentDocImageUrl = '';
        
        // Check if we're on a platform that supports File operations
        bool canUploadFiles = true;
        try {
          // This will throw an exception on platforms that don't support it (e.g. web)
          if (!identical(0, 0.0)) File(''); // Just to check platform support
        } catch (e) {
          canUploadFiles = false;
          // Handle platform exception
        }
        
        if (canUploadFiles) {
          try {
            if (_bannerImage != null) {
              bannerImageUrl = await _storageService.uploadFile(
                'petrol_pump_requests/banner_${DateTime.now().millisecondsSinceEpoch}.jpg',
                File(_bannerImage!.path)
              );
            }
            
            if (_boardImage != null) {
              boardImageUrl = await _storageService.uploadFile(
                'petrol_pump_requests/board_${DateTime.now().millisecondsSinceEpoch}.jpg',
                File(_boardImage!.path)
              );
            }
            
            if (_billSlipImage != null) {
              billSlipImageUrl = await _storageService.uploadFile(
                'petrol_pump_requests/bill_${DateTime.now().millisecondsSinceEpoch}.jpg',
                File(_billSlipImage!.path)
              );
            }
            
            if (_governmentDocImage != null) {
              governmentDocImageUrl = await _storageService.uploadFile(
                'petrol_pump_requests/government_${DateTime.now().millisecondsSinceEpoch}.jpg',
                File(_governmentDocImage!.path)
              );
            }
          } catch (e) {
            // Handle upload error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading images: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        // Create petrol pump request object
        final request = PetrolPumpRequest(
          zone: _zoneController.text,
          salesArea: _salesAreaController.text,
          coClDo: _coClDoController.text,
          district: _districtController.text,
          sapCode: _sapCodeController.text,
          customerName: _customerNameController.text,
          location: "", // Location field is hidden, setting to empty string
          addressLine1: _addressLine1Controller.text,
          addressLine2: _addressLine2Controller.text,
          pincode: _pincodeController.text,
          dealerName: _dealerNameController.text,
          contactDetails: _contactDetailsController.text,
          latitude: double.parse(_latitudeController.text),
          longitude: double.parse(_longitudeController.text),
          status: 'pending',
          createdAt: DateTime.now(),
          bannerImageUrl: bannerImageUrl,
          boardImageUrl: boardImageUrl,
          billSlipImageUrl: billSlipImageUrl,
          governmentDocImageUrl: governmentDocImageUrl,
          regionalOffice: _regionalOfficeController.text,
          company: _selectedCompany,
        );
        
        // Get the current user ID from custom auth service
        final userId = await _authService.getCurrentUserId();
        
        // Add request to Firestore with user ID
        final requestId = await _requestService.addPetrolPumpRequest(request, userId: userId);
        
        // Close the loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Petrol pump request submitted successfully. Waiting for admin approval.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        // Close the loading dialog
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting petrol pump request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  Future<void> _pickImage(ImageSource source, int imageType) async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedImage != null) {
        setState(() {
          switch (imageType) {
            case 0:
              _bannerImage = pickedImage;
              break;
            case 1:
              _boardImage = pickedImage;
              break;
            case 2:
              _billSlipImage = pickedImage;
              break;
            case 3:
              _governmentDocImage = pickedImage;
              break;
          }
        });
        _updateProgress();
      }
    } catch (e) {
      // Handle image picking error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showImageSourceDialog(String imageType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Image',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPickerOption(
                      icon: Icons.camera_alt,
                      title: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera, imageType == 'banner' ? 0 : imageType == 'board' ? 1 : imageType == 'bill' ? 2 : 3);
                      },
                    ),
                    _buildPickerOption(
                      icon: Icons.photo_library,
                      title: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery, imageType == 'banner' ? 0 : imageType == 'board' ? 1 : imageType == 'bill' ? 2 : 3);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentScreen: 'add_pump'),
      appBar: AppBar(
        title: const Text(
          'Add Petrol Pump',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF35C2C1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Commented out JSON import button
          // IconButton(
          //   icon: const Icon(Icons.upload_file),
          //   onPressed: _isImporting ? null : _showJsonInputDialog,
          //   tooltip: 'Import from JSON',
          // ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Progress indicator
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completion: ${(_progressValue * 100).toInt()}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Company Selection Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Company',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            mainAxisSize: MainAxisSize.max, // Ensure row takes full width
                            children: _companies.map((company) {
                              final isSelected = _selectedCompany == company;
                              // Get the appropriate image path for each company
                              String imagePath = '';
                              if (company == 'HPCL') {
                                imagePath = 'assets/images/HPCL Color.png';
                              } else if (company == 'BPCL') {
                                imagePath = 'assets/images/BPCL Color.png';
                              } else if (company == 'IOCL') {
                                imagePath = 'assets/images/IOCL Color.png';
                              }
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCompany = company;
                                  });
                                  // Try to fetch details if pincode and coordinates are available
                                  if (_pincodeController.text.isNotEmpty && 
                                      _latitudeController.text.isNotEmpty && 
                                      _longitudeController.text.isNotEmpty) {
                                    _fetchPetrolPumpByPincodeAndLocation();
                                  }
                                },
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  padding: const EdgeInsets.all(6), // Even padding all around
                                                                      decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF35C2C1).withOpacity(0.1) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF35C2C1) : Colors.grey.shade300,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected 
                                          ? const Color(0xFF35C2C1).withOpacity(0.4)
                                          : Colors.grey.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      imagePath,
                                      height: 55, // Increased height to fill the container
                                      width: 55, // Increased width to fill the container
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Location and Pincode Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Pincode field
                          TextFormField(
                            controller: _pincodeController,
                            decoration: InputDecoration(
                              labelText: 'Pincode *',
                              hintText: 'Enter 6-digit pincode',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: _pincodeController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _pincodeController.clear();
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter pincode';
                              }
                              if (value.length != 6) {
                                return 'Pincode must be 6 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Coordinates section
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latitudeController,
                                  decoration: InputDecoration(
                                    labelText: 'Latitude *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: _longitudeController,
                                  decoration: InputDecoration(
                                    labelText: 'Longitude *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Get current location button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isGettingLocation ? null : _getCurrentLocation,
                              icon: const Icon(Icons.my_location),
                              label: _isGettingLocation
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('Getting Location...'),
                                      ],
                                    )
                                  : const Text('Get Current Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF35C2C1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          if (_locationError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _locationError,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Auto-filled fields section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Auto-filled Fields',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isLoading)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // District field
                          TextFormField(
                            controller: _districtController,
                            decoration: InputDecoration(
                              labelText: 'District *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            readOnly: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter district';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Regional Office field
                          TextFormField(
                            controller: _regionalOfficeController,
                            decoration: InputDecoration(
                              labelText: 'Regional Office *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            readOnly: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter regional office';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Sales Area field
                          TextFormField(
                            controller: _salesAreaController,
                            decoration: InputDecoration(
                              labelText: 'Sales Area *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            readOnly: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter sales area';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Zone field
                          TextFormField(
                            controller: _zoneController,
                            decoration: InputDecoration(
                              labelText: 'Zone *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            readOnly: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter zone';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // CO/CL/DO field
                          TextFormField(
                            controller: _coClDoController,
                            decoration: InputDecoration(
                              labelText: 'CO/CL/DO *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter CO/CL/DO';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // User Input Fields section - Adding the missing fields
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Petrol Pump Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // SAP Code field (optional)
                          TextFormField(
                            controller: _sapCodeController,
                            decoration: InputDecoration(
                              labelText: 'SAP Code (Optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'Enter SAP Code if available',
                            ),
                            // No validation since it's optional
                            onChanged: (_) => _updateProgress(),
                          ),
                          const SizedBox(height: 16),
                          
                          // Customer Name field
                          TextFormField(
                            controller: _customerNameController,
                            decoration: InputDecoration(
                              labelText: 'Petrol Pump Name *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter Customer Name';
                              }
                              return null;
                            },
                            onChanged: (_) => _updateProgress(),
                          ),
                          const SizedBox(height: 16),
                          
                          // Location field is hidden from the user
                          // We'll set it to an empty string in the backend
                          const SizedBox(height: 16),
                          
                          // Address Line 1 field
                          TextFormField(
                            controller: _addressLine1Controller,
                            decoration: InputDecoration(
                              labelText: 'Address Line 1 *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter Address Line 1';
                              }
                              return null;
                            },
                            onChanged: (_) => _updateProgress(),
                          ),
                          const SizedBox(height: 16),
                          
                          // Address Line 2 field (optional)
                          TextFormField(
                            controller: _addressLine2Controller,
                            decoration: InputDecoration(
                              labelText: 'Address Line 2 (Optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'Additional address details if needed',
                            ),
                            // No validation since it's optional
                            onChanged: (_) => _updateProgress(),
                          ),
                          const SizedBox(height: 16),
                          
                          // Dealer Name field
                          TextFormField(
                            controller: _dealerNameController,
                            decoration: InputDecoration(
                              labelText: 'Dealer Name *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter Dealer Name';
                              }
                              return null;
                            },
                            onChanged: (_) => _updateProgress(),
                          ),
                          const SizedBox(height: 16),
                          
                          // Contact Details field (10-digit mobile number)
                          TextFormField(
                            controller: _contactDetailsController,
                                                          decoration: InputDecoration(
                              labelText: 'Mobile Number *',
                              hintText: 'Enter 10-digit mobile number',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              prefixText: '+91 ',
                              // Remove the static counterText since maxLength will show a counter automatically
                            ),
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter mobile number';
                              }
                              if (value.length != 10 || !RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                                return 'Please enter valid 10-digit mobile number';
                              }
                              return null;
                            },
                            onChanged: (_) => _updateProgress(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Images section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Required Images',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Banner Image
                          ListTile(
                            title: const Text('Banner Image *'),
                            subtitle: _bannerImage != null
                                ? Text('Selected: ${_bannerImage!.name}')
                                : const Text('No image selected'),
                            trailing: ElevatedButton(
                              onPressed: () => _showImageSourceDialog('banner'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF35C2C1),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Select'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Board Image
                          ListTile(
                            title: const Text('Board Image *'),
                            subtitle: _boardImage != null
                                ? Text('Selected: ${_boardImage!.name}')
                                : const Text('No image selected'),
                            trailing: ElevatedButton(
                              onPressed: () => _showImageSourceDialog('board'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF35C2C1),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Select'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Bill Slip Image (optional)
                          ListTile(
                            title: const Text('Bill Slip Image (Optional)'),
                            subtitle: _billSlipImage != null
                                ? Text('Selected: ${_billSlipImage!.name}')
                                : const Text('No image selected'),
                            trailing: ElevatedButton(
                              onPressed: () => _showImageSourceDialog('bill'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF35C2C1),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Select'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Government Document Image (optional)
                          ListTile(
                            title: const Text('Government Document (Optional)'),
                            subtitle: _governmentDocImage != null
                                ? Text('Selected: ${_governmentDocImage!.name}')
                                : const Text('No image selected'),
                            trailing: ElevatedButton(
                              onPressed: () => _showImageSourceDialog('doc'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF35C2C1),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Select'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Submit button
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF35C2C1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Help', style: TextStyle(color: Color(0xFF35C2C1), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('How to add a petrol pump:', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('1. Fill in all required fields', style: TextStyle(color: Colors.black54)),
              Text('2. Use the "Use Current Location" button to get coordinates', style: TextStyle(color: Colors.black54)),
              Text('3. Upload required documents and images', style: TextStyle(color: Colors.black54)),
              SizedBox(height: 16),
              Text('Required Documents:', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Petrol pump banner image', style: TextStyle(color: Colors.black54)),
              Text('• Petrol pump board image', style: TextStyle(color: Colors.black54)),
              Text('• Bill slip (Optional)', style: TextStyle(color: Colors.black54)),
              Text('• Legal government document (Optional)', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF35C2C1),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF35C2C1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF35C2C1),
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      readOnly: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
} 