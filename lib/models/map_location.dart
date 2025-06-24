import 'package:cloud_firestore/cloud_firestore.dart';

class MapLocation {
  final String zone;
  final String salesArea;
  final String coClDo;
  final String district;
  final String sapCode;
  final String customerName;
  final String location;
  final String addressLine1;
  final String addressLine2;
  final String addressLine3;
  final String addressLine4;
  final String pincode;
  final String dealerName;
  final String contactDetails;
  final double latitude;
  final double longitude;
  final String company; // HPCL, BPCL, IOCL
  final bool active;
  final bool verified;
  final DateTime? importedAt;
  final Map<String, dynamic>? locationGeoPoint;
  final String regionalOffice;

  MapLocation({
    this.zone = '',
    this.salesArea = '',
    this.coClDo = '',
    this.district = '',
    this.sapCode = '',
    this.customerName = '',
    this.location = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.addressLine3 = '',
    this.addressLine4 = '',
    this.pincode = '',
    this.dealerName = '',
    this.contactDetails = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.company = '',
    this.active = true,
    this.verified = false,
    this.importedAt,
    this.locationGeoPoint,
    this.regionalOffice = '',
  });

  // Factory constructor to create a MapLocation from a Firestore document
  factory MapLocation.fromMap(Map<String, dynamic> map) {
    // Helper function to safely convert field values to strings
    String safeString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    // Helper function to safely convert field values to doubles
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        try {
          return double.parse(value);
        } catch (e) {
          return 0.0;
        }
      }
      return 0.0;
    }

    // Handle location field which might be a GeoPoint, Map, or null
    Map<String, dynamic>? locationMap;
    double lat = 0.0;
    double long = 0.0;

    if (map['location'] != null) {
      if (map['location'] is Map) {
        locationMap = Map<String, dynamic>.from(map['location']);
        
        // Handle different formats of location data
        if (locationMap.containsKey('latitude') && locationMap.containsKey('longitude')) {
          lat = safeDouble(locationMap['latitude']);
          long = safeDouble(locationMap['longitude']);
        } else if (locationMap.containsKey('lat') && locationMap.containsKey('lng')) {
          lat = safeDouble(locationMap['lat']);
          long = safeDouble(locationMap['lng']);
        }
      } else if (map['location'] is GeoPoint) {
        final GeoPoint geoPoint = map['location'] as GeoPoint;
        lat = geoPoint.latitude;
        long = geoPoint.longitude;
        locationMap = {
          'latitude': lat,
          'longitude': long,
        };
      }
    }

    // Use explicit Lat/Long fields if available, otherwise use location map
    final latitude = map.containsKey('Lat') ? safeDouble(map['Lat']) : 
                     map.containsKey('latitude') ? safeDouble(map['latitude']) : lat;
    
    final longitude = map.containsKey('Long') ? safeDouble(map['Long']) : 
                      map.containsKey('longitude') ? safeDouble(map['longitude']) : long;

    // Handle importedAt timestamp
    DateTime? importedAt;
    if (map['importedAt'] != null) {
      if (map['importedAt'] is Timestamp) {
        importedAt = (map['importedAt'] as Timestamp).toDate();
      } else if (map['importedAt'] is DateTime) {
        importedAt = map['importedAt'] as DateTime;
      }
    }

    return MapLocation(
      zone: safeString(map['Zone'] ?? map['zone'] ?? ''),
      salesArea: safeString(map['Sales Area'] ?? map['salesArea'] ?? ''),
      coClDo: safeString(map['CO/CL/DO'] ?? map['coClDo'] ?? ''),
      district: safeString(map['District'] ?? map['district'] ?? ''),
      sapCode: safeString(map['SAP Code'] ?? map['sapCode'] ?? ''),
      customerName: safeString(map['Customer Name'] ?? map['customerName'] ?? ''),
      location: safeString(map['Location'] ?? map['location'] ?? ''),
      addressLine1: safeString(map['Address Line1'] ?? map['addressLine1'] ?? ''),
      addressLine2: safeString(map['Address Line2'] ?? map['addressLine2'] ?? ''),
      addressLine3: safeString(map['Address Line3'] ?? map['addressLine3'] ?? ''),
      addressLine4: safeString(map['Address Line4'] ?? map['addressLine4'] ?? ''),
      pincode: safeString(map['Pincode'] ?? map['pincode'] ?? ''),
      dealerName: safeString(map['Dealer Name'] ?? map['dealerName'] ?? ''),
      contactDetails: safeString(map['Contact details'] ?? map['contactDetails'] ?? ''),
      latitude: latitude,
      longitude: longitude,
      company: safeString(map['Company'] ?? map['company'] ?? ''),
      active: map['active'] ?? true,
      verified: map['verified'] ?? false,
      importedAt: importedAt,
      locationGeoPoint: locationMap,
      regionalOffice: safeString(map['Regional office'] ?? map['Regional Office'] ?? map['regionalOffice'] ?? ''),
    );
  }

  // Convert MapLocation to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'zone': zone,
      'salesArea': salesArea,
      'coClDo': coClDo,
      'district': district,
      'sapCode': sapCode,
      'customerName': customerName,
      'location': location,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'addressLine3': addressLine3,
      'addressLine4': addressLine4,
      'pincode': pincode,
      'dealerName': dealerName,
      'contactDetails': contactDetails,
      'latitude': latitude,
      'longitude': longitude,
      'company': company,
      'active': active,
      'verified': verified,
      'importedAt': importedAt ?? FieldValue.serverTimestamp(),
      'locationGeoPoint': locationGeoPoint ?? {
        'latitude': latitude,
        'longitude': longitude,
      },
      'regionalOffice': regionalOffice,
    };
  }
} 