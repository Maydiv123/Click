import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/map_location.dart';
import 'dart:math' as math;

class MapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new location to the database
  Future<void> addMapLocation(MapLocation location) async {
    try {
      await _firestore.collection('petrolPumps').add(location.toMap());
    } catch (e) {
      print('Error adding map location: $e');
      throw e;
    }
  }

  // Get all map locations
  Future<List<MapLocation>> getAllMapLocations() async {
    try {
      final QuerySnapshot snapshot = await _firestore.collection('petrolPumps').get();
      
      List<MapLocation> locations = [];
      for (var doc in snapshot.docs) {
        try {
          MapLocation location = MapLocation.fromMap(doc.data() as Map<String, dynamic>);
          locations.add(location);
        } catch (e) {
          print('Error parsing map location: $e');
          // Continue to the next document
        }
      }
      
      return locations;
    } catch (e) {
      print('Error getting all map locations: $e');
      return [];
    }
  }

  // Get map locations within a radius
  Future<List<MapLocation>> getMapLocationsWithinRadius(
    double latitude, 
    double longitude, 
    double radiusKm
  ) async {
    try {
      // First get all locations (this could be optimized with geofirestore)
      final allLocations = await getAllMapLocations();
      
      // Filter locations within the radius
      return allLocations.where((location) {
        final distance = _calculateDistance(
          latitude, 
          longitude, 
          location.latitude, 
          location.longitude
        );
        return distance <= radiusKm;
      }).toList();
    } catch (e) {
      print('Error getting map locations within radius: $e');
      return [];
    }
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Math.PI / 180
    final double a = 0.5 - 
        math.cos((lat2 - lat1) * p) / 2 + 
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a)); // 2 * R; R = 6371 km
  }

  // Update a map location
  Future<void> updateMapLocation(String id, MapLocation location) async {
    try {
      await _firestore.collection('petrolPumps').doc(id).update(location.toMap());
    } catch (e) {
      print('Error updating map location: $e');
      throw e;
    }
  }

  // Delete a map location
  Future<void> deleteMapLocation(String id) async {
    try {
      await _firestore.collection('petrolPumps').doc(id).delete();
    } catch (e) {
      print('Error deleting map location: $e');
      throw e;
    }
  }

  // Get all map locations
  Stream<List<MapLocation>> getMapLocations() {
    return _firestore
        .collection('petrolPumps')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Get map locations by zone
  Stream<List<MapLocation>> getMapLocationsByZone(String zone) {
    return _firestore
        .collection('petrolPumps')
        .where('zone', isEqualTo: zone)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Get map locations by district
  Stream<List<MapLocation>> getMapLocationsByDistrict(String district) {
    return _firestore
        .collection('petrolPumps')
        .where('district', isEqualTo: district)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Get map locations by sales area
  Stream<List<MapLocation>> getMapLocationsBySalesArea(String salesArea) {
    return _firestore
        .collection('petrolPumps')
        .where('salesArea', isEqualTo: salesArea)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }

  // Search map locations by customer name
  Stream<List<MapLocation>> searchMapLocations(String query) {
    return _firestore
        .collection('petrolPumps')
        .where('customerName', isGreaterThanOrEqualTo: query)
        .where('customerName', isLessThanOrEqualTo: query + '\uf8ff')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MapLocation.fromMap(doc.data()))
            .toList());
  }
} 