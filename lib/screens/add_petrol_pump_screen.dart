import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AddPetrolPumpScreen extends StatefulWidget {
  const AddPetrolPumpScreen({Key? key}) : super(key: key);

  @override
  State<AddPetrolPumpScreen> createState() => _AddPetrolPumpScreenState();
}

class _AddPetrolPumpScreenState extends State<AddPetrolPumpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _openingTimeController = TextEditingController();
  final _closingTimeController = TextEditingController();
  final _emailController = TextEditingController();
  final _ownerNameController = TextEditingController();
  
  // Progress tracking
  double _progressValue = 0.0;
  
  // Company selection
  bool _isIOCL = false;
  bool _isHPCL = false;
  bool _isBPCL = false;

  // Fuel types
  final Map<String, bool> _fuelTypes = {
    'Petrol': false,
    'Diesel': false,
    'CNG': false,
    'LPG': false,
    'Premium Petrol': false,
    'Premium Diesel': false,
    'Electric Charging': false,
  };

  // Amenities
  final Map<String, bool> _amenities = {
    'ATM': false,
    'Air Pump': false,
    'Car Wash': false,
    'Restroom': false,
    'Shop': false,
    'Restaurant': false,
    'Pharmacy': false,
    'Free WiFi': false,
    'EV Charging': false,
  };
  
  // Payment methods
  final Map<String, bool> _paymentMethods = {
    'Cash': false,
    'Credit Card': false,
    'Debit Card': false,
    'UPI': false,
    'Mobile Wallet': false,
    'RFID Card': false,
  };
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  
  // Current step
  int _currentStep = 0;
  
  // Location variables
  bool _isGettingLocation = false;
  String _locationError = '';
  
  @override
  void initState() {
    super.initState();
    _updateProgress();
  }

  void _updateProgress() {
    int totalFields = 9; // Total number of major fields
    int filledFields = 0;
    
    if (_nameController.text.isNotEmpty) filledFields++;
    if (_addressController.text.isNotEmpty) filledFields++;
    if (_phoneController.text.isNotEmpty) filledFields++;
    if (_descriptionController.text.isNotEmpty) filledFields++;
    if (_latitudeController.text.isNotEmpty && _longitudeController.text.isNotEmpty) filledFields++;
    if (_openingTimeController.text.isNotEmpty && _closingTimeController.text.isNotEmpty) filledFields++;
    if (_isIOCL || _isHPCL || _isBPCL) filledFields++;
    if (_fuelTypes.values.any((selected) => selected)) filledFields++;
    if (_amenities.values.any((selected) => selected)) filledFields++;
    
    setState(() {
      _progressValue = filledFields / totalFields;
    });
  }
  
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _updateProgress();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error picking image'), backgroundColor: Colors.red),
      );
    }
  }
  
  Future<void> _selectTime(BuildContext context, bool isOpeningTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isOpeningTime) {
          _openingTimeController.text = picked.format(context);
        } else {
          _closingTimeController.text = picked.format(context);
        }
        _updateProgress();
      });
    }
  }

  // Add this method to get the current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = '';
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isGettingLocation = false;
            _locationError = 'Location permission denied';
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        // Show dialog to open app settings
        _showLocationPermissionDialog();
        setState(() {
          _isGettingLocation = false;
          _locationError = 'Location permission permanently denied';
        });
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitudeController.text = position.latitude.toString();
        _longitudeController.text = position.longitude.toString();
        _isGettingLocation = false;
        _updateProgress();
      });
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
        _locationError = 'Error getting location: ${e.toString()}';
      });
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Location Permission Required', 
          style: TextStyle(color: Colors.white)),
        content: const Text(
          'We need location permission to get your current coordinates. Please enable location in app settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: Container(
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
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            setState(() {
              if (_currentStep < 5) {
                _currentStep += 1;
              } else {
                _submitForm();
              }
            });
          },
          onStepCancel: () {
            setState(() {
              if (_currentStep > 0) {
                _currentStep -= 1;
              }
            });
          },
          onStepTapped: (int index) {
            setState(() {
              _currentStep = index;
            });
          },
          controlsBuilder: (context, details) {
            return Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('BACK'),
                    ),
                  ),
                if (_currentStep > 0)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(_currentStep < 5 ? 'NEXT' : 'SUBMIT'),
                  ),
                ),
              ],
            );
          },
          steps: [
            Step(
              title: const Text('Pump Information', style: TextStyle(color: Colors.white)),
              content: _buildBasicInfoCard(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Location & Contact', style: TextStyle(color: Colors.white)),
              content: _buildLocationCard(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Operating Hours', style: TextStyle(color: Colors.white)),
              content: _buildOperatingHoursCard(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Fuel & Companies', style: TextStyle(color: Colors.white)),
              content: _buildFuelAndCompanyCard(),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Amenities', style: TextStyle(color: Colors.white)),
              content: _buildAmenitiesCard(),
              isActive: _currentStep >= 4,
              state: _currentStep > 4 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Additional Details', style: TextStyle(color: Colors.white)),
              content: _buildAdditionalDetailsCard(),
              isActive: _currentStep >= 5,
              state: _currentStep > 5 ? StepState.complete : StepState.indexed,
            ),
          ],
        ),
      ),
      bottomNavigationBar: LinearProgressIndicator(
        value: _progressValue,
        backgroundColor: Colors.grey[800],
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 8,
      ),
    );
  }

  Widget _buildBasicInfoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Selection
        GestureDetector(
          onTap: () => _showImageSourceDialog(),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 50,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add Petrol Pump Image',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Petrol Pump Name',
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
            prefixIcon: const Icon(Icons.local_gas_station, color: Colors.white),
            filled: true,
            fillColor: Colors.grey[900],
          ),
          onChanged: (_) => _updateProgress(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the petrol pump name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ownerNameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Owner Name',
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
            prefixIcon: const Icon(Icons.person, color: Colors.white),
            filled: true,
            fillColor: Colors.grey[900],
          ),
          onChanged: (_) => _updateProgress(),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _addressController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Address',
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
            prefixIcon: const Icon(Icons.location_on, color: Colors.white),
            filled: true,
            fillColor: Colors.grey[900],
          ),
          maxLines: 2,
          onChanged: (_) => _updateProgress(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // Location Coordinates with Get Current Location button
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latitudeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Latitude',
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
                            prefixIcon: const Icon(Icons.location_searching, color: Colors.white),
                            filled: true,
                            fillColor: Colors.grey[900],
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _updateProgress(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _longitudeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Longitude',
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
                            prefixIcon: const Icon(Icons.location_searching, color: Colors.white),
                            filled: true,
                            fillColor: Colors.grey[900],
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => _updateProgress(),
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
                  
                  // Error message if location retrieval failed
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
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Phone Number',
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
            prefixIcon: const Icon(Icons.phone, color: Colors.white),
            filled: true,
            fillColor: Colors.grey[900],
          ),
          keyboardType: TextInputType.phone,
          onChanged: (_) => _updateProgress(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Email Address',
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
            prefixIcon: const Icon(Icons.email, color: Colors.white),
            filled: true,
            fillColor: Colors.grey[900],
          ),
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _updateProgress(),
        ),
      ],
    );
  }

  Widget _buildOperatingHoursCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _openingTimeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Opening Time',
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
                  prefixIcon: const Icon(Icons.sunny, color: Colors.white),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
                readOnly: true,
                onTap: () => _selectTime(context, true),
                onChanged: (_) => _updateProgress(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _closingTimeController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Closing Time',
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
                  prefixIcon: const Icon(Icons.nightlight_round, color: Colors.white),
                  filled: true,
                  fillColor: Colors.grey[900],
                ),
                readOnly: true,
                onTap: () => _selectTime(context, false),
                onChanged: (_) => _updateProgress(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Days Open',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDayChip('Mon'),
                  _buildDayChip('Tue'),
                  _buildDayChip('Wed'),
                  _buildDayChip('Thu'),
                  _buildDayChip('Fri'),
                  _buildDayChip('Sat'),
                  _buildDayChip('Sun'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFuelAndCompanyCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Oil Companies',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildCompanyChip('IOCL', _isIOCL, (value) => setState(() => _isIOCL = value)),
            _buildCompanyChip('HPCL', _isHPCL, (value) => setState(() => _isHPCL = value)),
            _buildCompanyChip('BPCL', _isBPCL, (value) => setState(() => _isBPCL = value)),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Available Fuel Types',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _fuelTypes.entries.map((entry) {
            return _buildFuelTypeChip(entry.key, entry.value);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAmenitiesCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Amenities',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _amenities.entries.map((entry) {
            return _buildAmenityChip(entry.key, entry.value);
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Methods',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paymentMethods.entries.map((entry) {
            return _buildPaymentMethodChip(entry.key, entry.value);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAdditionalDetailsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Additional Information',
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
            prefixIcon: const Icon(Icons.info_outline, color: Colors.white),
            filled: true,
            fillColor: Colors.grey[900],
          ),
          maxLines: 5,
          onChanged: (_) => _updateProgress(),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Verification Notice',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'All information provided will be verified before the petrol pump is listed.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayChip(String day) {
    bool isSelected = true; // Default to selected
    return FilterChip(
      label: Text(day),
      selected: isSelected,
      // backgroundColor: Colors.grey[100],
      // selectedColor: Colors.white24,
      // checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white10,
      ),
      onSelected: (bool value) {
        setState(() {
          // Toggle selection
          isSelected = value;
        });
      },
    );
  }

  Widget _buildCompanyChip(String label, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.white24,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
      ),
      onSelected: (bool value) {
        onSelected(value);
        _updateProgress();
      },
    );
  }

  Widget _buildFuelTypeChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.white24,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
      ),
      onSelected: (bool value) {
        setState(() {
          _fuelTypes[label] = value;
          _updateProgress();
        });
      },
    );
  }

  Widget _buildAmenityChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.white24,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
      ),
      onSelected: (bool value) {
        setState(() {
          _amenities[label] = value;
          _updateProgress();
        });
      },
    );
  }
  
  Widget _buildPaymentMethodChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      backgroundColor: Colors.grey[800],
      selectedColor: Colors.white24,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
      ),
      onSelected: (bool value) {
        setState(() {
          _paymentMethods[label] = value;
        });
      },
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Select Image Source', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_isIOCL && !_isHPCL && !_isBPCL) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one oil company'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Show success message with animation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Success', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Petrol Pump Added Successfully',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your request has been submitted and is pending verification.',
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Return to previous screen
              },
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
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
              Text('2. Add petrol pump image', style: TextStyle(color: Colors.white70)),
              Text('3. Provide accurate location coordinates', style: TextStyle(color: Colors.white70)),
              Text('4. Select at least one oil company', style: TextStyle(color: Colors.white70)),
              Text('5. Set operating hours and days', style: TextStyle(color: Colors.white70)),
              Text('6. Select available fuel types', style: TextStyle(color: Colors.white70)),
              Text('7. Choose available amenities', style: TextStyle(color: Colors.white70)),
              Text('8. Add payment methods accepted', style: TextStyle(color: Colors.white70)),
              Text('9. Include any additional information', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 16),
              Text('Verification Process:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('After submission, our team will verify the information before listing the petrol pump.',
                  style: TextStyle(color: Colors.white70)),
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
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _emailController.dispose();
    _ownerNameController.dispose();
    super.dispose();
  }
} 