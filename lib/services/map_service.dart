import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/map_location.dart';
import 'dart:math' as math;

class MapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'map_locations';

  // Add a new map location
  Future<void> addMapLocation(MapLocation location) async {
    try {
      await _firestore.collection(_collection).add(location.toMap());
    } catch (e) {
      throw Exception('Failed to add map location: $e');
    }
  }

  // Get all map locations
  Stream<List<MapLocation>> getMapLocations() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Get map locations by zone
  Stream<List<MapLocation>> getMapLocationsByZone(String zone) {
    return _firestore
        .collection(_collection)
        .where('zone', isEqualTo: zone)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Get map locations by district
  Stream<List<MapLocation>> getMapLocationsByDistrict(String district) {
    return _firestore
        .collection(_collection)
        .where('district', isEqualTo: district)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Get map locations by sales area
  Stream<List<MapLocation>> getMapLocationsBySalesArea(String salesArea) {
    return _firestore
        .collection(_collection)
        .where('salesArea', isEqualTo: salesArea)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Search map locations by customer name
  Stream<List<MapLocation>> searchMapLocations(String query) {
    return _firestore
        .collection(_collection)
        .where('customerName', isGreaterThanOrEqualTo: query)
        .where('customerName', isLessThanOrEqualTo: query + '\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Get map locations within a radius (in kilometers)
  Future<List<MapLocation>> getMapLocationsWithinRadius(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    try {
      // Get a single snapshot of the locations
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();
      List<MapLocation> locations = snapshot.docs
          .map((doc) => MapLocation.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Filter locations within radius
      return locations.where((location) {
        final distance = _calculateDistance(
          centerLat,
          centerLng,
          location.latitude,
          location.longitude,
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      print('Error getting locations within radius: $e');
      return [];
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double lat1Rad = _toRadians(lat1);
    final double lat2Rad = _toRadians(lat2);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLon / 2) * math.sin(dLon / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  // Update a map location
  Future<void> updateMapLocation(String docId, MapLocation location) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(docId)
          .update(location.toMap());
    } catch (e) {
      throw Exception('Failed to update map location: $e');
    }
  }

  // Delete a map location
  Future<void> deleteMapLocation(String docId) async {
    try {
      await _firestore.collection(_collection).doc(docId).delete();
    } catch (e) {
      throw Exception('Failed to delete map location: $e');
    }
  }
} 