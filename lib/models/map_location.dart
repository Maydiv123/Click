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
  final String pincode;
  final String dealerName;
  final String contactDetails;
  final double latitude;
  final double longitude;

  MapLocation({
    required this.zone,
    required this.salesArea,
    required this.coClDo,
    required this.district,
    required this.sapCode,
    required this.customerName,
    required this.location,
    required this.addressLine1,
    required this.addressLine2,
    required this.pincode,
    required this.dealerName,
    required this.contactDetails,
    required this.latitude,
    required this.longitude,
  });

  // Convert MapLocation to Map for Firestore
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
      'pincode': pincode,
      'dealerName': dealerName,
      'contactDetails': contactDetails,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create MapLocation from Firestore document
  factory MapLocation.fromMap(Map<String, dynamic> map) {
    return MapLocation(
      zone: map['zone'] ?? '',
      salesArea: map['salesArea'] ?? '',
      coClDo: map['coClDo'] ?? '',
      district: map['district'] ?? '',
      sapCode: map['sapCode'] ?? '',
      customerName: map['customerName'] ?? '',
      location: map['location'] ?? '',
      addressLine1: map['addressLine1'] ?? '',
      addressLine2: map['addressLine2'] ?? '',
      pincode: map['pincode'] ?? '',
      dealerName: map['dealerName'] ?? '',
      contactDetails: map['contactDetails'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
    );
  }
} 