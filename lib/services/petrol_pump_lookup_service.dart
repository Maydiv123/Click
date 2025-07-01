import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/map_location.dart';
import 'map_service.dart';
import 'dart:math' as math;

class PetrolPumpLookupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MapService _mapService = MapService();
  
  // Find petrol pump by coordinates with a small radius search
  Future<MapLocation?> findPetrolPumpByCoordinates(double latitude, double longitude) async {
    try {
      // Get nearby pumps within a small radius (100 meters)
      final nearbyPumps = await _mapService.getMapLocationsWithinRadius(
        latitude, 
        longitude, 
        0.1 // 100 meters in km
      );
      
      if (nearbyPumps.isNotEmpty) {
        // Return the closest one
        return nearbyPumps.first;
      }
      
      return null;
    } catch (e) {
      // print('Error finding petrol pump by coordinates: $e');
      return null;
    }
  }
  
  // Find petrol pump by pincode
  Future<List<MapLocation>> findPetrolPumpsByPincode(String pincode) async {
    try {
      // print('DEBUG: Finding pumps by pincode: $pincode');
      
      // Try with uppercase field name first
      QuerySnapshot snapshotUpper = await _firestore
          .collection('petrolPumps')
          .where('Pincode', isEqualTo: pincode)
          .limit(5)
          .get();
      
      // print('DEBUG: Found ${snapshotUpper.docs.length} pumps with Pincode field');
      
      if (snapshotUpper.docs.isNotEmpty) {
        return snapshotUpper.docs
            .map((doc) => MapLocation.fromMap(doc.data() as Map<String, dynamic>))
            .toList();
      }
      
      // Try with lowercase field name if upper case didn't work
      final QuerySnapshot snapshotLower = await _firestore
          .collection('petrolPumps')
          .where('pincode', isEqualTo: pincode)
          .limit(5)
          .get();
      
      // print('DEBUG: Found ${snapshotLower.docs.length} pumps with pincode field');
      
      return snapshotLower.docs
          .map((doc) => MapLocation.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // print('Error finding petrol pumps by pincode: $e');
      return [];
    }
  }
  
  // Get address details from coordinates using HTTP API as a fallback
  Future<Map<String, dynamic>> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      try {
        // Try using geocoding package if available
        List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
        
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          
          return {
            'addressLine1': '${place.street ?? ''}, ${place.subLocality ?? ''}',
            'addressLine2': '${place.locality ?? ''}, ${place.administrativeArea ?? ''}',
            'pincode': place.postalCode ?? '',
            'district': place.subAdministrativeArea ?? '',
            'location': place.locality ?? '',
            'zone': '', // This would need to be determined based on your business logic
            'salesArea': '', // This would need to be determined based on your business logic
          };
        }
      } catch (e) {
        // print('Geocoding package error: $e - Using fallback method');
        // If geocoding package fails, use HTTP API as fallback
      }
      
      // Fallback to using a free geocoding API
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&zoom=18&addressdetails=1'),
        headers: {'User-Agent': 'Click App'}
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        
        return {
          'addressLine1': '${address['road'] ?? ''}, ${address['suburb'] ?? ''}',
          'addressLine2': '${address['city'] ?? ''}, ${address['state'] ?? ''}',
          'pincode': address['postcode'] ?? '',
          'district': address['county'] ?? '',
          'location': address['city'] ?? address['town'] ?? address['village'] ?? '',
          'zone': '', // This would need to be determined based on your business logic
          'salesArea': '', // This would need to be determined based on your business logic
        };
      }
      
      return {};
    } catch (e) {
      // print('Error getting address from coordinates: $e');
      return {};
    }
  }
  
  // Find petrol pumps by company name (HPCL, IOCL, BPCL, etc.)
  Future<List<MapLocation>> findPetrolPumpsByCompany(String company, double latitude, double longitude, double radiusKm) async {
    try {
      // print('DEBUG: Finding pumps by company: $company within $radiusKm km radius');
      // First get all pumps within radius
      final pumpsWithinRadius = await _mapService.getMapLocationsWithinRadius(
        latitude,
        longitude,
        radiusKm
      );
      
      // print('DEBUG: Found ${pumpsWithinRadius.length} pumps within radius');
      
      // Then filter by company name
      final filteredPumps = pumpsWithinRadius.where((pump) {
        // Check if the customer name or address contains the company name
        return pump.customerName.toUpperCase().contains(company.toUpperCase()) ||
               pump.addressLine1.toUpperCase().contains(company.toUpperCase()) ||
               pump.company.toUpperCase() == company.toUpperCase();
      }).toList();
      
      // print('DEBUG: After filtering by company, found ${filteredPumps.length} pumps');
      
      return filteredPumps;
    } catch (e) {
      // print('Error finding petrol pumps by company: $e');
      return [];
    }
  }
  
  // Get petrol pump details by SAP code
  Future<MapLocation?> getPetrolPumpBySapCode(String sapCode) async {
    try {
      // Try with uppercase field name first
      QuerySnapshot snapshotUpper = await _firestore
          .collection('petrolPumps')
          .where('SAP Code', isEqualTo: sapCode)
          .limit(1)
          .get();
      
      if (snapshotUpper.docs.isNotEmpty) {
        return MapLocation.fromMap(snapshotUpper.docs.first.data() as Map<String, dynamic>);
      }
      
      // Try with lowercase field name if upper case didn't work
      final QuerySnapshot snapshotLower = await _firestore
          .collection('petrolPumps')
          .where('sapCode', isEqualTo: sapCode)
          .limit(1)
          .get();
      
      if (snapshotLower.docs.isNotEmpty) {
        return MapLocation.fromMap(snapshotLower.docs.first.data() as Map<String, dynamic>);
      }
      
      return null;
    } catch (e) {
      // print('Error finding petrol pump by SAP code: $e');
      return null;
    }
  }
  
  // Find petrol pumps by company and pincode
  Future<List<MapLocation>> findPetrolPumpsByCompanyAndPincode(String company, String pincode) async {
    try {
      // print('LOOKUP: Searching for $company pumps with pincode $pincode in Firestore');
      
      // First try to find by explicit company field with uppercase field names
      // print('LOOKUP: Trying query with Pincode=$pincode and Company=$company (uppercase fields)');
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('petrolPumps')
            .where('Pincode', isEqualTo: pincode)
            .where('Company', isEqualTo: company)
            .limit(5)
            .get();
        
        // print('LOOKUP: First query returned ${snapshot.docs.length} results');
        
        if (snapshot.docs.isNotEmpty) {
          // print('LOOKUP: Found ${snapshot.docs.length} results with uppercase fields');
          
          // Debug the first document found
          final firstDoc = snapshot.docs.first.data() as Map<String, dynamic>;
          // print('LOOKUP DOCUMENT FIELDS:');
          // firstDoc.forEach((key, value) {
          //   // print('  $key: $value');
          // });
          
          List<MapLocation> results = [];
          for (var doc in snapshot.docs) {
            try {
              MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
              results.add(location);
            } catch (e) {
              // print('LOOKUP ERROR: Failed to parse document: $e');
            }
          }
          
          if (results.isNotEmpty) {
            return results;
          }
        }
      } catch (e) {
        // print('LOOKUP ERROR in uppercase query: $e');
      }
      
      // Try with lowercase field names
      // print('LOOKUP: Trying query with pincode=$pincode and company=$company (lowercase fields)');
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('petrolPumps')
            .where('pincode', isEqualTo: pincode)
            .where('company', isEqualTo: company)
            .limit(5)
            .get();
            
        // print('LOOKUP: Second query returned ${snapshot.docs.length} results');
        
        if (snapshot.docs.isNotEmpty) {
          // print('LOOKUP: Found ${snapshot.docs.length} results with lowercase fields');
          
          // Debug the first document found
          final firstDoc = snapshot.docs.first.data() as Map<String, dynamic>;
          // print('LOOKUP DOCUMENT FIELDS:');
          // firstDoc.forEach((key, value) {
          //   print('  $key: $value');
          // });
          
          List<MapLocation> results = [];
          for (var doc in snapshot.docs) {
            try {
              MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
              results.add(location);
            } catch (e) {
              // print('LOOKUP ERROR: Failed to parse document: $e');
            }
          }
          
          if (results.isNotEmpty) {
            return results;
          }
        }
      } catch (e) {
        // print('LOOKUP ERROR in lowercase query: $e');
      }
          
      // If still no results, try to find by pincode only and then filter by company name
      // print('LOOKUP: No direct matches found, trying pincode-only search');
      
      // Try uppercase pincode field
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('petrolPumps')
            .where('Pincode', isEqualTo: pincode)
            .get();
            
        // print('LOOKUP: Uppercase pincode query returned ${snapshot.docs.length} results');
        
        if (snapshot.docs.isNotEmpty) {
          // Convert to MapLocation objects
          List<MapLocation> allPumps = [];
          for (var doc in snapshot.docs) {
            try {
              MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
              allPumps.add(location);
            } catch (e) {
              // print('LOOKUP ERROR: Failed to parse document: $e');
            }
          }
          
          // Filter by company
          List<MapLocation> results = allPumps
              .where((pump) => _isPumpOfCompany(pump, company))
              .toList();
          
          // print('LOOKUP: After filtering by company name, found ${results.length} $company pumps with pincode $pincode');
          
          if (results.isNotEmpty) {
            return results;
          }
        }
      } catch (e) {
        // print('LOOKUP ERROR in uppercase pincode query: $e');
      }
      
      // Try lowercase pincode field
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('petrolPumps')
            .where('pincode', isEqualTo: pincode)
            .get();
            
        // print('LOOKUP: Lowercase pincode query returned ${snapshot.docs.length} results');
        
        if (snapshot.docs.isNotEmpty) {
          // Convert to MapLocation objects
          List<MapLocation> allPumps = [];
          for (var doc in snapshot.docs) {
            try {
              MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
              allPumps.add(location);
            } catch (e) {
              // print('LOOKUP ERROR: Failed to parse document: $e');
            }
          }
          
          // Filter by company
          List<MapLocation> results = allPumps
              .where((pump) => _isPumpOfCompany(pump, company))
              .toList();
          
          // print('LOOKUP: After filtering by company name, found ${results.length} $company pumps with pincode $pincode');
          
          if (results.isNotEmpty) {
            return results;
          }
        }
      } catch (e) {
        // print('LOOKUP ERROR in lowercase pincode query: $e');
      }
      
      // Try direct query by pincode as a number
      try {
        int pincodeNum = int.tryParse(pincode) ?? 0;
        if (pincodeNum > 0) {
          // print('LOOKUP: Trying query with pincode as number: $pincodeNum');
          QuerySnapshot snapshot = await _firestore
              .collection('petrolPumps')
              .where('Pincode', isEqualTo: pincodeNum)
              .get();
              
          // print('LOOKUP: Pincode as number query returned ${snapshot.docs.length} results');
          
          if (snapshot.docs.isNotEmpty) {
            // Convert to MapLocation objects
            List<MapLocation> allPumps = [];
            for (var doc in snapshot.docs) {
              try {
                MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
                allPumps.add(location);
              } catch (e) {
                // print('LOOKUP ERROR: Failed to parse document: $e');
              }
            }
            
            // Filter by company
            List<MapLocation> results = allPumps
                .where((pump) => _isPumpOfCompany(pump, company))
                .toList();
            
            // print('LOOKUP: After filtering by company name, found ${results.length} $company pumps with pincode $pincodeNum');
            
            if (results.isNotEmpty) {
              return results;
            }
          }
        }
      } catch (e) {
        // print('LOOKUP ERROR in pincode as number query: $e');
      }
      
      // If we still haven't found any results, try a broader search without pincode
      // print('LOOKUP: No pumps found with pincode $pincode, trying broader search');
      
      // Get all pumps and filter by company
      try {
        QuerySnapshot snapshot = await _firestore
            .collection('petrolPumps')
            .limit(100) // Limit to avoid loading too much data
            .get();
        
        // print('LOOKUP: Broad query found ${snapshot.docs.length} total pumps');
        
        if (snapshot.docs.isNotEmpty) {
          // Convert to MapLocation objects
          List<MapLocation> allPumps = [];
          for (var doc in snapshot.docs) {
            try {
              MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
              allPumps.add(location);
              
              // Debug each document to see if pincode matches
              // if (location.pincode == pincode) {
              //   print('LOOKUP: Found pump with matching pincode: ${location.customerName}');
              //   print('LOOKUP: Company: ${location.company}');
              // }
            } catch (e) {
              // print('LOOKUP ERROR: Failed to parse document: $e');
              // Print the problematic document
              try {
                final docData = doc.data() as Map<String, dynamic>;
                // print('LOOKUP: Problematic document:');
                // docData.forEach((key, value) {
                //   print('  $key: $value (${value.runtimeType})');
                // });
              } catch (e2) {
                // print('LOOKUP ERROR: Could not print document: $e2');
              }
            }
          }
          
          // Filter by company and pincode
          List<MapLocation> results = allPumps
              .where((pump) => _isPumpOfCompany(pump, company) && pump.pincode == pincode)
              .toList();
          
          // print('LOOKUP: After filtering broad search, found ${results.length} $company pumps with pincode $pincode');
          
          if (results.isNotEmpty) {
            return results;
          }
        }
      } catch (e) {
        // print('LOOKUP ERROR in broad query: $e');
      }
      
      // print('LOOKUP: No pumps found in database with pincode $pincode and company $company');
      return [];
    } catch (e) {
      // print('Error finding petrol pumps by company and pincode: $e');
      return [];
    }
  }
  
  // Helper method to check if a pump belongs to a specific company
  bool _isPumpOfCompany(MapLocation pump, String company) {
    print('DEBUG: Checking if pump "${pump.customerName}" belongs to $company');
    
    // First check if company field exists and matches
    if (pump.company.isNotEmpty) {
      if (pump.company.toUpperCase() == company.toUpperCase()) {
        print('DEBUG: ✓ Direct company field match');
        return true;
      }
    }
    
    // For HPCL detection
    if (company.toUpperCase() == "HPCL") {
      // Check for HP or HPCL in various fields
      if (pump.customerName.toUpperCase().contains("HP ") || 
          pump.customerName.toUpperCase().contains("HPCL") ||
          pump.customerName.toUpperCase().contains("HPC ") ||
          pump.customerName.toUpperCase().contains("HINDUSTAN PETROLEUM") ||
          pump.customerName.toUpperCase().contains("HP PETROL") ||
          pump.customerName.toUpperCase().contains("H.P.")) {
        print('DEBUG: ✓ Matched HPCL in customerName: ${pump.customerName}');
        return true;
      }
      
      if (pump.addressLine1.toUpperCase().contains("HP ") || 
          pump.addressLine1.toUpperCase().contains("HPCL") ||
          pump.addressLine1.toUpperCase().contains("HPC ") ||
          pump.addressLine1.toUpperCase().contains("HINDUSTAN PETROLEUM") ||
          pump.addressLine1.toUpperCase().contains("HP PETROL") ||
          pump.addressLine1.toUpperCase().contains("H.P.")) {
        print('DEBUG: ✓ Matched HPCL in addressLine1: ${pump.addressLine1}');
        return true;
      }
    }
    
    // For BPCL detection
    if (company.toUpperCase() == "BPCL") {
      // Check for BP or BPCL in various fields
      if (pump.customerName.toUpperCase().contains("BP ") || 
          pump.customerName.toUpperCase().contains("BPCL") || 
          pump.customerName.toUpperCase().contains("BHARAT") ||
          pump.customerName.toUpperCase().contains("B.P.")) {
        print('DEBUG: ✓ Matched BPCL in customerName: ${pump.customerName}');
        return true;
      }
      
      if (pump.addressLine1.toUpperCase().contains("BP ") || 
          pump.addressLine1.toUpperCase().contains("BPCL") ||
          pump.addressLine1.toUpperCase().contains("BHARAT") ||
          pump.addressLine1.toUpperCase().contains("B.P.")) {
        print('DEBUG: ✓ Matched BPCL in addressLine1: ${pump.addressLine1}');
        return true;
      }
    }
    
    // For IOCL detection
    if (company.toUpperCase() == "IOCL") {
      // Check for IO or IOCL in various fields
      if (pump.customerName.toUpperCase().contains("INDIAN OIL") || 
          pump.customerName.toUpperCase().contains("IOCL") || 
          pump.customerName.toUpperCase().contains("IOC") ||
          pump.customerName.toUpperCase().contains("I.O.C.")) {
        print('DEBUG: ✓ Matched IOCL in customerName: ${pump.customerName}');
        return true;
      }
      
      if (pump.addressLine1.toUpperCase().contains("INDIAN OIL") || 
          pump.addressLine1.toUpperCase().contains("IOCL") ||
          pump.addressLine1.toUpperCase().contains("IOC") ||
          pump.addressLine1.toUpperCase().contains("I.O.C.")) {
        print('DEBUG: ✓ Matched IOCL in addressLine1: ${pump.addressLine1}');
        return true;
      }
    }
    
    return false;
  }
  
  // Find nearest petrol pump by company and coordinates
  Future<MapLocation?> findNearestPetrolPumpByCompany(String company, double latitude, double longitude, double radiusKm) async {
    try {
      // print('DEBUG: Finding nearest $company pump at coordinates: $latitude, $longitude with radius: $radiusKm km');
      // Get all pumps within radius
      final pumpsWithinRadius = await _mapService.getMapLocationsWithinRadius(
        latitude,
        longitude,
        radiusKm
      );
      
      // print('DEBUG: Found ${pumpsWithinRadius.length} pumps within radius');
      
      // Filter by company
      final companyPumps = pumpsWithinRadius.where((pump) => _isPumpOfCompany(pump, company)).toList();
      
      // print('DEBUG: After filtering by company, found ${companyPumps.length} $company pumps');
      
      if (companyPumps.isEmpty) {
        return null;
      }
      
      // Sort by distance (closest first)
      companyPumps.sort((a, b) {
        final distanceA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distanceB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });
      
      // print('DEBUG: Nearest pump is ${companyPumps.first.customerName} at distance ${_calculateDistance(latitude, longitude, companyPumps.first.latitude, companyPumps.first.longitude).toStringAsFixed(2)}km');
      
      return companyPumps.first;
    } catch (e) {
      // print('Error finding nearest petrol pump by company: $e');
      return null;
    }
  }
  
  // Find nearest petrol pump by company and pincode
  Future<MapLocation?> findNearestPetrolPumpByCompanyAndPincode(
    String company, 
    String pincode, 
    double latitude, 
    double longitude
  ) async {
    try {
      // print('LOOKUP: Searching for $company pump with pincode $pincode at coordinates: $latitude, $longitude');
      
      // First, try to find pumps with matching company and pincode
      final pumpsByCompanyAndPincode = await findPetrolPumpsByCompanyAndPincode(company, pincode);
      
      if (pumpsByCompanyAndPincode.isEmpty) {
        // print('LOOKUP: No $company pumps found with pincode $pincode');
        
        // We should NOT return pumps with different pincodes
        // print('LOOKUP: NOT searching for pumps with different pincodes');
        return null;
      } else {
        // print('LOOKUP: Found ${pumpsByCompanyAndPincode.length} $company pumps with pincode $pincode');
        
        // Verify all pumps have the correct pincode
        bool allMatchPincode = pumpsByCompanyAndPincode.every((pump) => 
          pump.pincode == pincode
        );
        
        if (!allMatchPincode) {
          // print('LOOKUP WARNING: Some pumps have incorrect pincodes!');
          
          // Filter to only include pumps with matching pincode
          final filteredPumps = pumpsByCompanyAndPincode
              .where((pump) => pump.pincode == pincode)
              .toList();
              
          if (filteredPumps.isEmpty) {
            // print('LOOKUP: No pumps match the exact pincode $pincode');
            return null;
          }
          
          // Print data for each pump found
          for (int i = 0; i < filteredPumps.length; i++) {
            // print('LOOKUP PUMP #${i+1}: ${_formatPumpData(filteredPumps[i])}');
            // print('LOOKUP PUMP #${i+1} FULL DATA:');
            // print('  Regional Office: ${filteredPumps[i].regionalOffice}');
            // print('  CO/CL/DO: ${filteredPumps[i].coClDo}');
          }
          
          // If we have pumps with matching pincode, find the nearest one
          if (filteredPumps.length == 1) {
            // print('LOOKUP: Only one pump found, returning it:');
            // print('  Regional Office: ${filteredPumps[0].regionalOffice}');
            // print('  CO/CL/DO: ${filteredPumps[0].coClDo}');
            return filteredPumps.first;
          }
          
          // Sort by distance (closest first)
          filteredPumps.sort((a, b) {
            final distanceA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
            final distanceB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
            return distanceA.compareTo(distanceB);
          });
          
          // print('LOOKUP: Returning nearest pump: ${filteredPumps.first.customerName}');
          // print('  Regional Office: ${filteredPumps[0].regionalOffice}');
          // print('  CO/CL/DO: ${filteredPumps[0].coClDo}');
          return filteredPumps.first;
        }
        
        // Print data for each pump found
        for (int i = 0; i < pumpsByCompanyAndPincode.length; i++) {
          // print('LOOKUP PUMP #${i+1}: ${_formatPumpData(pumpsByCompanyAndPincode[i])}');
          // print('LOOKUP PUMP #${i+1} FULL DATA:');
          // print('  Regional Office: ${pumpsByCompanyAndPincode[i].regionalOffice}');
          // print('  CO/CL/DO: ${pumpsByCompanyAndPincode[i].coClDo}');
        }
      }
      
      // If we have pumps with matching pincode, find the nearest one
      if (pumpsByCompanyAndPincode.length == 1) {
        // print('LOOKUP: Only one pump found, returning it:');
        // print('  Regional Office: ${pumpsByCompanyAndPincode[0].regionalOffice}');
        // print('  CO/CL/DO: ${pumpsByCompanyAndPincode[0].coClDo}');
        return pumpsByCompanyAndPincode.first;
      }
      
      // Sort by distance (closest first)
      pumpsByCompanyAndPincode.sort((a, b) {
        final distanceA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distanceB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });
      
      // print('LOOKUP: Returning nearest pump: ${pumpsByCompanyAndPincode.first.customerName}');
      // print('  Regional Office: ${pumpsByCompanyAndPincode[0].regionalOffice}');
      // print('  CO/CL/DO: ${pumpsByCompanyAndPincode[0].coClDo}');
      return pumpsByCompanyAndPincode.first;
    } catch (e) {
      // print('Error finding nearest petrol pump by company and pincode: $e');
      return null;
    }
  }
  
  // Helper method to format pump data for debugging
  String _formatPumpData(MapLocation pump) {
    return '''
    Company: ${pump.company}
    Customer Name: ${pump.customerName}
    Zone: ${pump.zone}
    District: ${pump.district}
    Sales Area: ${pump.salesArea}
    Regional Office: ${pump.regionalOffice}
    CO/CL/DO: ${pump.coClDo}
    Location: ${pump.location}
    Pincode: ${pump.pincode}
    Coordinates: ${pump.latitude}, ${pump.longitude}
    ''';
  }
  
  // Extract only the required fields from a petrol pump
  Map<String, dynamic> extractRequiredFields(MapLocation pump) {
    return {
      'district': pump.district,
      'regionalOffice': pump.regionalOffice, // Make sure to use the regionalOffice field
      'salesArea': pump.salesArea,
      'zone': pump.zone,
      'coClDo': pump.coClDo, // Added coClDo field
      // Fields NOT included here will need to be filled by the user:
      // - customerName
      // - dealerName
      // - contactDetails
      // - sapCode
      // - location
      // - addressLine1
      // - addressLine2
      // - All images (banner, board, bill slip, government doc)
    };
  }
  
  // Calculate distance between two coordinates (in km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 - 
        math.cos((lat2 - lat1) * p) / 2 + 
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }
  
  // Find petrol pumps by company and district
  Future<List<MapLocation>> findPetrolPumpsByCompanyAndDistrict(String company, String district) async {
    try {
      // print('DEBUG: Finding $company pumps in district: $district');
      
      // Try direct district fetch with case-insensitive check
      try {
        // print('DEBUG: Trying case-insensitive district search for $district');
        QuerySnapshot districtSnapshot = await _firestore
            .collection('petrolPumps')
            .get();

        // print('DEBUG: Full collection query returned ${districtSnapshot.docs.length} results');

        // Convert to MapLocation objects
        List<MapLocation> allPumps = [];
        for (var doc in districtSnapshot.docs) {
          try {
            MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
            allPumps.add(location);
          } catch (e) {
            print('DEBUG: Error parsing document: $e');
          }
        }

        // print('DEBUG: Successfully parsed ${allPumps.length} total pumps');

        // Filter by company and district (case-insensitive)
        List<MapLocation> results = allPumps
            .where((pump) => 
                _isPumpOfCompany(pump, company) && 
                pump.district.toLowerCase() == district.toLowerCase())
            .toList();
        
        // print('DEBUG: After case-insensitive filtering, found ${results.length} $company pumps in district $district');
        
        // If we still have no results, try more flexible district matching
        if (results.isEmpty) {
          // print('DEBUG: Trying more flexible district matching');
          results = allPumps
              .where((pump) => 
                  _isPumpOfCompany(pump, company) && 
                  pump.district.toLowerCase().contains(district.toLowerCase()))
              .toList();
              
          // print('DEBUG: After flexible district matching, found ${results.length} $company pumps');
        }
        
        if (results.isNotEmpty) {
          return results;
        }
      } catch (e) {
        print('DEBUG: Error in case-insensitive district search: $e');
      }
      
      // Original approach as fallback
      // Try with uppercase field name first
      // print('DEBUG: Trying query with District=$district and Company=$company (uppercase fields)');
      QuerySnapshot snapshotUpper = await _firestore
          .collection('petrolPumps')
          .where('District', isEqualTo: district)
          .where('Company', isEqualTo: company)
          .get();
      
      // print('DEBUG: Uppercase query returned ${snapshotUpper.docs.length} results');
      
      if (snapshotUpper.docs.isNotEmpty) {
        List<MapLocation> results = [];
        for (var doc in snapshotUpper.docs) {
          try {
            MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
            results.add(location);
            // print('DEBUG: Added pump: ${location.customerName} at ${location.latitude}, ${location.longitude}');
          } catch (e) {
            print('DEBUG: Error parsing document: $e');
          }
        }
        
        if (results.isNotEmpty) {
          // print('DEBUG: Found ${results.length} pumps with uppercase fields');
          return results;
        }
      }
      
      // Try with lowercase field names
      // print('DEBUG: Trying query with district=$district and company=$company (lowercase fields)');
      QuerySnapshot snapshotLower = await _firestore
          .collection('petrolPumps')
          .where('district', isEqualTo: district)
          .where('company', isEqualTo: company)
          .get();
          
      // print('DEBUG: Lowercase query returned ${snapshotLower.docs.length} results');
      
      if (snapshotLower.docs.isNotEmpty) {
        List<MapLocation> results = [];
        for (var doc in snapshotLower.docs) {
          try {
            MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
            results.add(location);
            // print('DEBUG: Added pump: ${location.customerName} at ${location.latitude}, ${location.longitude}');
          } catch (e) {
            print('DEBUG: Error parsing document: $e');
          }
        }
        
        if (results.isNotEmpty) {
          // print('DEBUG: Found ${results.length} pumps with lowercase fields');
          return results;
        }
      }
      
      // If still no results, try to find by district only and then filter by company name
      // Try uppercase district field
      // print('DEBUG: Trying query with District=$district (uppercase district only)');
      QuerySnapshot districtSnapshot = await _firestore
          .collection('petrolPumps')
          .where('District', isEqualTo: district)
          .get();
          
      // print('DEBUG: District query (uppercase) returned ${districtSnapshot.docs.length} results');
      
      if (districtSnapshot.docs.isNotEmpty) {
        // Convert to MapLocation objects
        List<MapLocation> allPumps = [];
        for (var doc in districtSnapshot.docs) {
          try {
            MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
            allPumps.add(location);
          } catch (e) {
            print('DEBUG: Error parsing document: $e');
          }
        }
        
        // print('DEBUG: Found ${allPumps.length} total pumps in district $district (uppercase)');
        
        // Filter by company
        List<MapLocation> results = allPumps
            .where((pump) => _isPumpOfCompany(pump, company))
            .toList();
        
        // print('DEBUG: After filtering by company, found ${results.length} $company pumps');
        
        if (results.isNotEmpty) {
          return results;
        }
      }
      
      // Try lowercase district field
      // print('DEBUG: Trying query with district=$district (lowercase district only)');
      QuerySnapshot districtSnapshotLower = await _firestore
          .collection('petrolPumps')
          .where('district', isEqualTo: district)
          .get();
          
      // print('DEBUG: District query (lowercase) returned ${districtSnapshotLower.docs.length} results');
      
      if (districtSnapshotLower.docs.isNotEmpty) {
        // Convert to MapLocation objects
        List<MapLocation> allPumps = [];
        for (var doc in districtSnapshotLower.docs) {
          try {
            MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
            allPumps.add(location);
          } catch (e) {
            print('DEBUG: Error parsing document: $e');
          }
        }
        
        // print('DEBUG: Found ${allPumps.length} total pumps in district $district (lowercase)');
        
        // Filter by company
        List<MapLocation> results = allPumps
            .where((pump) => _isPumpOfCompany(pump, company))
            .toList();
        
        // print('DEBUG: After filtering by company, found ${results.length} $company pumps');
        
        if (results.isNotEmpty) {
          return results;
        }
      }
      
      // print('DEBUG: No $company pumps found in district $district');
      return [];
    } catch (e) {
      print('ERROR in findPetrolPumpsByCompanyAndDistrict: $e');
      return [];
    }
  }
  
  // Find nearest petrol pump by company and district
  Future<MapLocation?> findNearestPetrolPumpByCompanyAndDistrict(
    String company, 
    String district, 
    double latitude, 
    double longitude
  ) async {
    try {
      // print('DEBUG: Finding nearest $company pump in district $district at coordinates: $latitude, $longitude');
      
      // First, try to find pumps with matching company and district
      final pumpsByCompanyAndDistrict = await findPetrolPumpsByCompanyAndDistrict(company, district);
      
      if (pumpsByCompanyAndDistrict.isEmpty) {
        // print('DEBUG: No $company pumps found in district $district');
        return null;
      }
      
      // print('DEBUG: Found ${pumpsByCompanyAndDistrict.length} $company pumps in district $district');
      
      // If we have pumps with matching district, find the nearest one
      if (pumpsByCompanyAndDistrict.length == 1) {
        // print('DEBUG: Only one pump found, returning it: ${pumpsByCompanyAndDistrict.first.customerName}');
        return pumpsByCompanyAndDistrict.first;
      }
      
      // Sort by distance (closest first)
      pumpsByCompanyAndDistrict.sort((a, b) {
        final distanceA = _calculateDistance(latitude, longitude, a.latitude, a.longitude);
        final distanceB = _calculateDistance(latitude, longitude, b.latitude, b.longitude);
        return distanceA.compareTo(distanceB);
      });
      
      final nearestPump = pumpsByCompanyAndDistrict.first;
      final distance = _calculateDistance(latitude, longitude, nearestPump.latitude, nearestPump.longitude);
      
      // print('DEBUG: Nearest pump is ${nearestPump.customerName} at distance ${distance.toStringAsFixed(2)} km');
      // print('DEBUG: Nearest pump details:');
      // print('DEBUG:   - District: ${nearestPump.district}');
      // print('DEBUG:   - Regional Office: ${nearestPump.regionalOffice}');
      // print('DEBUG:   - Zone: ${nearestPump.zone}');
      // print('DEBUG:   - Sales Area: ${nearestPump.salesArea}');
      // print('DEBUG:   - CO/CL/DO: ${nearestPump.coClDo}');
      
      return nearestPump;
    } catch (e) {
      print('ERROR in findNearestPetrolPumpByCompanyAndDistrict: $e');
      return null;
    }
  }
} 