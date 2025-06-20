import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../services/map_service.dart';
import '../models/map_location.dart';
import '../widgets/app_drawer.dart';

class AddPetrolPumpScreen extends StatefulWidget {
  const AddPetrolPumpScreen({Key? key}) : super(key: key);

  @override
  State<AddPetrolPumpScreen> createState() => _AddPetrolPumpScreenState();
}

class _AddPetrolPumpScreenState extends State<AddPetrolPumpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapService = MapService();
  final _jsonController = TextEditingController();
  
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
  final _addressLine3Controller = TextEditingController();
  final _addressLine4Controller = TextEditingController();
  final _pincodeController = TextEditingController();
  final _dealerNameController = TextEditingController();
  final _contactDetailsController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  
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
    _updateProgress();
  }

  void _updateProgress() {
    int totalFields = 19; // Total number of required fields including images
    int filledFields = 0;
    
    if (_zoneController.text.isNotEmpty) filledFields++;
    if (_salesAreaController.text.isNotEmpty) filledFields++;
    if (_coClDoController.text.isNotEmpty) filledFields++;
    if (_districtController.text.isNotEmpty) filledFields++;
    if (_sapCodeController.text.isNotEmpty) filledFields++;
    if (_customerNameController.text.isNotEmpty) filledFields++;
    if (_locationController.text.isNotEmpty) filledFields++;
    if (_addressLine1Controller.text.isNotEmpty) filledFields++;
    if (_addressLine2Controller.text.isNotEmpty) filledFields++;
    if (_addressLine3Controller.text.isNotEmpty) filledFields++;
    if (_addressLine4Controller.text.isNotEmpty) filledFields++;
    if (_pincodeController.text.isNotEmpty) filledFields++;
    if (_dealerNameController.text.isNotEmpty) filledFields++;
    if (_contactDetailsController.text.isNotEmpty) filledFields++;
    if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty) filledFields++;
    if (_bannerImage != null) filledFields++;
    if (_boardImage != null) filledFields++;
    if (_billSlipImage != null) filledFields++;
    if (_governmentDocImage != null) filledFields++;
    
    setState(() {
      _progressValue = filledFields / totalFields;
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
      
      _updateProgress();
    } catch (e) {
      setState(() {
        _locationError = 'Error getting location: $e';
        _isGettingLocation = false;
      });
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
            addressLine3: data['Address Line3']?.toString() ?? '',
            addressLine4: data['Address Line4']?.toString() ?? '',
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
          print('Error importing item $i: $e');
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
      // Check if images are uploaded
      if (_bannerImage == null || _boardImage == null || _billSlipImage == null || _governmentDocImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please upload all required documents'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      try {
        final location = MapLocation(
          zone: _zoneController.text,
          salesArea: _salesAreaController.text,
          coClDo: _coClDoController.text,
          district: _districtController.text,
          sapCode: _sapCodeController.text,
          customerName: _customerNameController.text,
          location: _locationController.text,
          addressLine1: _addressLine1Controller.text,
          addressLine2: _addressLine2Controller.text,
          addressLine3: _addressLine3Controller.text,
          addressLine4: _addressLine4Controller.text,
          pincode: _pincodeController.text,
          dealerName: _dealerNameController.text,
          contactDetails: _contactDetailsController.text,
          latitude: double.parse(_latitudeController.text),
          longitude: double.parse(_longitudeController.text),
        );

        // TODO: Upload images to Firebase Storage and get URLs
        // This would be implemented with Firebase Storage
        // final bannerImageUrl = await _uploadImage(_bannerImage!);
        // final boardImageUrl = await _uploadImage(_boardImage!);
        // final billSlipImageUrl = await _uploadImage(_billSlipImage!);
        // final governmentDocImageUrl = await _uploadImage(_governmentDocImage!);
        
        await _mapService.addMapLocation(location);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Petrol pump added successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding petrol pump: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedImage != null) {
        setState(() {
          switch (type) {
            case 'banner':
              _bannerImage = pickedImage;
              break;
            case 'board':
              _boardImage = pickedImage;
              break;
            case 'bill':
              _billSlipImage = pickedImage;
              break;
            case 'government':
              _governmentDocImage = pickedImage;
              break;
          }
        });
        _updateProgress();
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }
  
  void _showImagePickerOptions(String type, String title) {
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
                  'Select $title',
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
                        _pickImage(ImageSource.camera, type);
                      },
                    ),
                    _buildPickerOption(
                      icon: Icons.photo_library,
                      title: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery, type);
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
      body: Column(
        children: [
          // Progress bar at the top
          Container(
            height: 30,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(_progressValue * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF35C2C1),
                  ),
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF35C2C1),
                    Colors.white,
                  ],
                ),
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Card at the top
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
                                'Location Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      _latitudeController,
                                      'Latitude',
                                      Icons.location_searching,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      _longitudeController,
                                      'Longitude',
                                      Icons.location_searching,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF35C2C1),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: _isGettingLocation 
                                      ? Container(
                                          width: 24,
                                          height: 24,
                                          padding: const EdgeInsets.all(2.0),
                                          child: const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Icon(Icons.my_location),
                                  label: Text(_isGettingLocation ? 'Getting Location...' : 'Use Current Location'),
                                ),
                              ),
                              if (_locationError.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _locationError,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Import Progress
                      if (_isImporting)
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
                                Text(
                                  _importStatus,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _totalItems > 0 ? _importProgress / _totalItems : 0,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF35C2C1)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Basic Information Card
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
                                'Basic Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(_customerNameController, 'Customer Name', Icons.business),
                              _buildTextField(_dealerNameController, 'Dealer Name', Icons.person),
                              _buildTextField(_contactDetailsController, 'Contact Details', Icons.phone),
                              _buildTextField(_sapCodeController, 'SAP Code', Icons.numbers),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Address Card
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
                                'Address Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(_locationController, 'Location', Icons.location_on),
                              _buildTextField(_addressLine1Controller, 'Address Line 1', Icons.home),
                              _buildTextField(_addressLine2Controller, 'Address Line 2', Icons.home),
                              _buildTextField(_addressLine3Controller, 'Address Line 3', Icons.home),
                              _buildTextField(_addressLine4Controller, 'Address Line 4', Icons.home),
                              _buildTextField(_pincodeController, 'Pincode', Icons.pin),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Administrative Card
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
                                'Administrative Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(_zoneController, 'Zone', Icons.terrain),
                              _buildTextField(_salesAreaController, 'Sales Area', Icons.business),
                              _buildTextField(_coClDoController, 'CO/CL/DO', Icons.category),
                              _buildTextField(_districtController, 'District', Icons.location_city),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Documents Upload Card
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
                                'Required Documents',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Banner Image
                              _buildImageUploadItem(
                                title: 'Petrol Pump Banner',
                                icon: Icons.image,
                                image: _bannerImage,
                                onTap: () => _showImagePickerOptions('banner', 'Banner Image'),
                              ),
                              
                              const Divider(),
                              
                              // Board Image
                              _buildImageUploadItem(
                                title: 'Petrol Pump Board',
                                icon: Icons.image_outlined,
                                image: _boardImage,
                                onTap: () => _showImagePickerOptions('board', 'Board Image'),
                              ),
                              
                              const Divider(),
                              
                              // Bill Slip Image
                              _buildImageUploadItem(
                                title: 'Bill Slip',
                                icon: Icons.receipt,
                                image: _billSlipImage,
                                onTap: () => _showImagePickerOptions('bill', 'Bill Slip'),
                              ),
                              
                              const Divider(),
                              
                              // Government Document Image
                              _buildImageUploadItem(
                                title: 'Government Document',
                                icon: Icons.description,
                                image: _governmentDocImage,
                                onTap: () => _showImagePickerOptions('government', 'Government Document'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF35C2C1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add Petrol Pump',
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.black87),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF35C2C1), width: 2),
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF35C2C1)),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (_) => _updateProgress(),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildImageUploadItem({
    required String title,
    required IconData icon,
    required XFile? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF35C2C1), size: 24),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (image != null)
              const Icon(Icons.check, color: Colors.green),
          ],
        ),
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
              Text('• Bill slip', style: TextStyle(color: Colors.black54)),
              Text('• Legal government document', style: TextStyle(color: Colors.black54)),
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

  @override
  void dispose() {
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
    _addressLine3Controller.dispose();
    _addressLine4Controller.dispose();
    _pincodeController.dispose();
    _dealerNameController.dispose();
    _contactDetailsController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    
    // Clean up image files if needed
    _bannerImage = null;
    _boardImage = null;
    _billSlipImage = null;
    _governmentDocImage = null;
    
    super.dispose();
  }
} 