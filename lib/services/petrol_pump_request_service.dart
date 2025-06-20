import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/petrol_pump_request.dart';
import '../models/map_location.dart';
import 'map_service.dart';

class PetrolPumpRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MapService _mapService = MapService();
  final String _collection = 'petrol_pump_requests';

  // Add a new petrol pump request
  Future<String> addPetrolPumpRequest(PetrolPumpRequest request, {String? userId}) async {
    try {
      Map<String, dynamic> requestData = request.toMap();
      
      // First try to use the provided userId (from custom auth)
      if (userId != null) {
        requestData['requestedByUserId'] = userId;
      } 
      // If not provided, try Firebase Auth (fallback)
      else {
        final user = _auth.currentUser;
        if (user != null) {
          requestData['requestedByUserId'] = user.uid;
        }
      }

      // Add to petrol_pump_requests collection
      final docRef = await _firestore.collection(_collection).add(requestData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add petrol pump request: $e');
    }
  }

  // Get all petrol pump requests
  Stream<List<PetrolPumpRequest>> getPetrolPumpRequests() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PetrolPumpRequest.fromMap(doc.data()))
            .toList());
  }

  // Get petrol pump requests by status
  Stream<List<PetrolPumpRequest>> getPetrolPumpRequestsByStatus(String status) {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PetrolPumpRequest.fromMap(doc.data()))
            .toList());
  }

  // Get petrol pump requests by user ID
  Stream<List<PetrolPumpRequest>> getPetrolPumpRequestsByUserId(String userId) {
    return _firestore
        .collection(_collection)
        .where('requestedByUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PetrolPumpRequest.fromMap(doc.data()))
            .toList());
  }

  // Update petrol pump request status
  Future<void> updatePetrolPumpRequestStatus(String requestId, String status) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update petrol pump request status: $e');
    }
  }

  // Approve petrol pump request and add to map_locations
  Future<void> approvePetrolPumpRequest(String requestId) async {
    try {
      // Get the request
      final requestSnapshot = await _firestore.collection(_collection).doc(requestId).get();
      
      if (!requestSnapshot.exists) {
        throw Exception('Request not found');
      }
      
      final requestData = requestSnapshot.data()!;
      
      // Update request status to 'approved'
      await updatePetrolPumpRequestStatus(requestId, 'approved');
      
      // Convert to MapLocation and add to map_locations
      final mapLocation = MapLocation(
        zone: requestData['zone'] ?? '',
        salesArea: requestData['salesArea'] ?? '',
        coClDo: requestData['coClDo'] ?? '',
        district: requestData['district'] ?? '',
        sapCode: requestData['sapCode'] ?? '',
        customerName: requestData['customerName'] ?? '',
        location: requestData['location'] ?? '',
        addressLine1: requestData['addressLine1'] ?? '',
        addressLine2: requestData['addressLine2'] ?? '',
        pincode: requestData['pincode'] ?? '',
        dealerName: requestData['dealerName'] ?? '',
        contactDetails: requestData['contactDetails'] ?? '',
        latitude: (requestData['latitude'] ?? 0.0).toDouble(),
        longitude: (requestData['longitude'] ?? 0.0).toDouble(),
      );
      
      // Add to map_locations
      await _mapService.addMapLocation(mapLocation);
    } catch (e) {
      throw Exception('Failed to approve petrol pump request: $e');
    }
  }

  // Reject petrol pump request
  Future<void> rejectPetrolPumpRequest(String requestId, {String? reason}) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to reject petrol pump request: $e');
    }
  }

  // Delete petrol pump request
  Future<void> deletePetrolPumpRequest(String requestId) async {
    try {
      await _firestore.collection(_collection).doc(requestId).delete();
    } catch (e) {
      throw Exception('Failed to delete petrol pump request: $e');
    }
  }

  // Get petrol pump request by ID
  Future<PetrolPumpRequest?> getPetrolPumpRequestById(String requestId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(requestId).get();
      if (doc.exists) {
        return PetrolPumpRequest.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get petrol pump request: $e');
    }
  }
} 