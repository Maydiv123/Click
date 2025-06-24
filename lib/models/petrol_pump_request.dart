import 'package:cloud_firestore/cloud_firestore.dart';

class PetrolPumpRequest {
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
  final String status;  // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? requestedByUserId;
  final String? bannerImageUrl;
  final String? boardImageUrl;
  final String? billSlipImageUrl;
  final String? governmentDocImageUrl;
  final String regionalOffice;
  final String company;

  PetrolPumpRequest({
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
    required this.status,
    required this.createdAt,
    this.requestedByUserId,
    this.bannerImageUrl,
    this.boardImageUrl,
    this.billSlipImageUrl,
    this.governmentDocImageUrl,
    required this.regionalOffice,
    required this.company,
  });

  // Convert to Map for Firestore
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
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'requestedByUserId': requestedByUserId,
      'bannerImageUrl': bannerImageUrl,
      'boardImageUrl': boardImageUrl,
      'billSlipImageUrl': billSlipImageUrl,
      'governmentDocImageUrl': governmentDocImageUrl,
      'regionalOffice': regionalOffice,
      'company': company,
    };
  }

  // Create from Firestore document
  factory PetrolPumpRequest.fromMap(Map<String, dynamic> map) {
    return PetrolPumpRequest(
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
      longitude: map['longitude'] ?? 0.0,
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requestedByUserId: map['requestedByUserId'],
      bannerImageUrl: map['bannerImageUrl'],
      boardImageUrl: map['boardImageUrl'],
      billSlipImageUrl: map['billSlipImageUrl'],
      governmentDocImageUrl: map['governmentDocImageUrl'],
      regionalOffice: map['regionalOffice'] ?? '',
      company: map['company'] ?? '',
    );
  }

  // Convert PetrolPumpRequest to MapLocation
  Map<String, dynamic> toMapLocationMap() {
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
} 