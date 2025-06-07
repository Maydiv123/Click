import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import '../services/map_service.dart';
import '../models/map_location.dart';

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
    int totalFields = 15; // Total number of required fields
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
        backgroundColor: Colors.grey[900],
        title: const Text('Import JSON Data', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter JSON data in the following format:',
          style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
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
                    color: Colors.white70,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _jsonController,
                style: const TextStyle(color: Colors.white),
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: 'Paste your JSON data here...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  filled: true,
                  fillColor: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _importFromJson();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Petrol Pump',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _isImporting ? null : _showJsonInputDialog,
            tooltip: 'Import from JSON',
          ),
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
          Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Color(0xFF121212),
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
                    // Import Progress
                    if (_isImporting)
                      Container(
                        padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
            ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                              _importStatus,
          style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: _totalItems > 0 ? _importProgress / _totalItems : 0,
                              backgroundColor: Colors.grey[800],
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
                          ],
          ),
        ),
        const SizedBox(height: 16),
        
                    // Form Fields
                    _buildTextField(_zoneController, 'Zone', Icons.terrain),
                    _buildTextField(_salesAreaController, 'Sales Area', Icons.business),
                    _buildTextField(_coClDoController, 'CO/CL/DO', Icons.category),
                    _buildTextField(_districtController, 'District', Icons.location_city),
                    _buildTextField(_sapCodeController, 'SAP Code', Icons.numbers),
                    _buildTextField(_customerNameController, 'Customer Name', Icons.business),
                    _buildTextField(_locationController, 'Location', Icons.location_on),
                    _buildTextField(_addressLine1Controller, 'Address Line 1', Icons.home),
                    _buildTextField(_addressLine2Controller, 'Address Line 2', Icons.home),
                    _buildTextField(_addressLine3Controller, 'Address Line 3', Icons.home),
                    _buildTextField(_addressLine4Controller, 'Address Line 4', Icons.home),
                    _buildTextField(_pincodeController, 'Pincode', Icons.pin),
                    _buildTextField(_dealerNameController, 'Dealer Name', Icons.person),
                    _buildTextField(_contactDetailsController, 'Contact Details', Icons.phone),
                    
                    // Location Fields
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
                  
                  // Get Current Location Button
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isGettingLocation 
                          ? Container(
                              width: 24,
                              height: 24,
                              padding: const EdgeInsets.all(2.0),
                              child: const CircularProgressIndicator(
                                color: Colors.black,
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
                    
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
        ],
      ),
      bottomNavigationBar: LinearProgressIndicator(
        value: _progressValue,
        backgroundColor: Colors.grey[800],
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 8,
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
          style: const TextStyle(color: Colors.white),
        keyboardType: keyboardType,
          decoration: InputDecoration(
          labelText: label,
            labelStyle: const TextStyle(color: Colors.white70),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white),
            ),
          prefixIcon: Icon(icon, color: Colors.white),
            filled: true,
            fillColor: Colors.grey[900],
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Help', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('How to add a petrol pump:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('1. Fill in all required fields', style: TextStyle(color: Colors.white70)),
              Text('2. Use the "Use Current Location" button to get coordinates', style: TextStyle(color: Colors.white70)),
              Text('3. Import bulk data using the JSON import feature', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 16),
              Text('JSON Import Format:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('The JSON file should contain an array of objects with the following fields:', style: TextStyle(color: Colors.white70)),
              Text('• zone\n• salesArea\n• coClDo\n• district\n• sapCode\n• customerName\n• location\n• addressLine1-4\n• pincode\n• dealerName\n• contactDetails\n• latitude\n• longitude', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
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
    super.dispose();
  }
} 