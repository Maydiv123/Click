import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_auth_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CustomAuthService _authService = CustomAuthService();

  // Get user data
  Stream<Map<String, dynamic>> getUserData() async* {
    final userId = await _authService.getCurrentUserId();
    print('Current user ID: $userId'); // Debug print
    if (userId == null) {
      print('No user ID found, returning empty map'); // Debug print
      yield {};
      return;
    }

    // Get the document once and convert to a stream
    final doc = await _firestore.collection('user_data').doc(userId).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      print('User data received: $data'); // Debug print
      yield data;
    } else {
      print('No user data found for ID: $userId');
      yield {};
    }
  }

  // Update user location (legacy method)
  @Deprecated('Use updateUserLocationWithDetails instead')
  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    await updateUserLocationWithDetails(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );
  }
  
  // Simplified update user location method
  Future<void> updateSimpleUserLocation(double latitude, double longitude) async {
    await updateUserLocationWithDetails(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
    );
  }
  
  // Update user location with details
  Future<void> updateUserLocationWithDetails({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null) {
      print('No user ID found, cannot update location');
      return;
    }

    try {
      // Get user data to check last location and last login date
      final userDoc = await _firestore.collection('user_data').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      // Update location in user document
      await _firestore.collection('user_data').doc(userId).update({
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': Timestamp.fromDate(timestamp),
        },
        'lastLocationUpdate': Timestamp.fromDate(timestamp),
      });
      print('User location updated successfully');
      
      // Check if this is first login of the day
      await _trackDailyDistance(userId, latitude, longitude, timestamp, userData);
      
      // Also log this as an activity
      await _firestore.collection('activities').add({
        'userId': userId,
        'type': 'location_update',
        'details': {
          'latitude': latitude,
          'longitude': longitude,
        },
        'timestamp': Timestamp.fromDate(timestamp),
      });
    } catch (e) {
      print('Error updating user location: $e');
      throw e;
    }
  }
  
  // Track daily distance
  Future<void> _trackDailyDistance(
    String userId, 
    double latitude, 
    double longitude, 
    DateTime timestamp,
    Map<String, dynamic> userData
  ) async {
    try {
      final today = DateTime(timestamp.year, timestamp.month, timestamp.day);
      final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      
      // Check if we have a daily tracking document for today
      final dailyTrackingRef = _firestore
          .collection('user_data')
          .doc(userId)
          .collection('dailyTracking')
          .doc(todayStr);
      
      final dailyDoc = await dailyTrackingRef.get();
      
      if (!dailyDoc.exists) {
        // First login of the day - initialize tracking with 0 km
        await dailyTrackingRef.set({
          'date': Timestamp.fromDate(today),
          'firstLocation': {
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': Timestamp.fromDate(timestamp),
          },
          'lastLocation': {
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': Timestamp.fromDate(timestamp),
          },
          'distanceTraveled': 0.0, // in kilometers
          'checkpoints': [
            {
              'latitude': latitude,
              'longitude': longitude,
              'timestamp': Timestamp.fromDate(timestamp),
            }
          ]
        });
        
        print('First login of the day, initialized tracking');
      } else {
        // Not first login - calculate distance from last position
        final dailyData = dailyDoc.data() ?? {};
        final lastLocation = dailyData['lastLocation'] as Map<String, dynamic>;
        
        // Calculate distance between last location and current location
        final double lastLat = lastLocation['latitude'];
        final double lastLng = lastLocation['longitude'];
        
        // Use Geolocator to calculate distance in meters
        final distanceInMeters = Geolocator.distanceBetween(
          lastLat, lastLng, latitude, longitude
        );
        
        // Convert to kilometers
        final distanceInKm = distanceInMeters / 1000;
        
        // If distance is reasonable (not a GPS error or teleportation)
        if (distanceInKm > 0.01 && distanceInKm < 100) { // Between 10m and 100km
          // Update daily tracking with new distance
          final currentDistance = (dailyData['distanceTraveled'] as num?)?.toDouble() ?? 0.0;
          final newTotalDistance = currentDistance + distanceInKm;
          
          await dailyTrackingRef.update({
            'lastLocation': {
              'latitude': latitude,
              'longitude': longitude,
              'timestamp': Timestamp.fromDate(timestamp),
            },
            'distanceTraveled': newTotalDistance,
            'checkpoints': FieldValue.arrayUnion([
              {
                'latitude': latitude,
                'longitude': longitude,
                'timestamp': Timestamp.fromDate(timestamp),
              }
            ])
          });
          
          // Update user's total stats
          final currentStats = userData['stats'] as Map<String, dynamic>? ?? {};
          final totalDistance = (currentStats['totalDistance'] as num?)?.toDouble() ?? 0.0;
          final newTotalStats = totalDistance + distanceInKm;
          
          await _firestore.collection('user_data').doc(userId).update({
            'stats.totalDistance': newTotalStats,
            'stats.lastUpdated': Timestamp.fromDate(timestamp),
          });
          
          print('Updated daily distance: +$distanceInKm km, total: $newTotalDistance km');
        } else {
          print('Ignoring distance update: $distanceInKm km (too small or too large)');
        }
      }
    } catch (e) {
      print('Error tracking daily distance: $e');
    }
  }

  // Get team data
  Stream<Map<String, dynamic>> getTeamData(String teamCode) {
    print('Fetching team data for code: $teamCode'); // Debug print
    return _firestore
        .collection('teams')
        .doc(teamCode)
        .snapshots()
        .map((doc) {
          print('Team data received: ${doc.data()}'); // Debug print
          return doc.data() ?? {};
        });
  }

  // Get today's visits
  Stream<List<Map<String, dynamic>>> getTodayVisits() {
    final userId = _auth.currentUser?.uid;
    print('Fetching today\'s visits for user: $userId'); // Debug print
    if (userId == null) return Stream.value([]);

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return _firestore
        .collection('visits')
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          print('Today\'s visits received: ${snapshot.docs.length}'); // Debug print
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  // Get today's distance traveled
  Future<double> getTodaysDistance() async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null) return 0.0;

    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    
    try {
      final doc = await _firestore
          .collection('user_data')
          .doc(userId)
          .collection('dailyTracking')
          .doc(todayStr)
          .get();
      
      if (!doc.exists) return 0.0;
      
      return (doc.data()?['distanceTraveled'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      print('Error getting today\'s distance: $e');
      return 0.0;
    }
  }

  // Get upcoming tasks
  Stream<List<Map<String, dynamic>>> getUpcomingTasks() async* {
    final userId = await _authService.getCurrentUserId();
    print('Fetching upcoming tasks for user: $userId'); // Debug print
    if (userId == null) {
      yield [];
      return;
    }

    final now = DateTime.now();

    final snapshot = await _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('dueDate', isGreaterThanOrEqualTo: now)
        .orderBy('dueDate')
        .limit(5)
        .get();
    
    print('Upcoming tasks received: ${snapshot.docs.length}'); // Debug print
    yield snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get user statistics
  Stream<Map<String, dynamic>> getUserStats() {
    final userId = _auth.currentUser?.uid;
    print('Fetching user stats for user: $userId'); // Debug print
    if (userId == null) return Stream.value({});

    return _firestore
        .collection('statistics')
        .doc(userId)
        .snapshots()
        .map((doc) {
          print('User stats received: ${doc.data()}'); // Debug print
          return doc.data() ?? {};
        });
  }

  // Get real-time user stats from user_data collection
  Stream<Map<String, dynamic>> getRealTimeUserStats() async* {
    final userId = await _authService.getCurrentUserId();
    print('Fetching real-time user stats for user: $userId'); // Debug print
    if (userId == null) {
      yield {};
      return;
    }

    yield* _firestore
        .collection('user_data')
        .doc(userId)
        .snapshots()
        .map((doc) {
          print('Real-time user stats received: ${doc.data()}'); // Debug print
          final data = doc.data() ?? {};
          return data['stats'] as Map<String, dynamic>? ?? {};
        });
  }

  // Get frequent visits
  Stream<List<Map<String, dynamic>>> getFrequentVisits() {
    final userId = _auth.currentUser?.uid;
    print('Fetching frequent visits for user: $userId'); // Debug print
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('visits')
        .where('userId', isEqualTo: userId)
        .orderBy('count', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
          print('Frequent visits received: ${snapshot.docs.length}'); // Debug print
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  // Get recent activities
  Stream<List<Map<String, dynamic>>> getRecentActivities() async* {
    final userId = await _authService.getCurrentUserId();
    print('Fetching recent activities for user: $userId'); // Debug print
    if (userId == null) {
      yield [];
      return;
    }

    final snapshot = await _firestore
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();
    
    print('Recent activities received: ${snapshot.docs.length}'); // Debug print
    yield snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get daily tracking history
  Future<List<Map<String, dynamic>>> getDailyTrackingHistory({int limit = 7}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final querySnapshot = await _firestore
          .collection('user_data')
          .doc(userId)
          .collection('dailyTracking')
          .orderBy('date', descending: true)
          .limit(limit)
          .get();
      
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting daily tracking history: $e');
      return [];
    }
  }
  
  // Get daily tracking data by date
  Future<Map<String, dynamic>> getDailyTrackingByDate(DateTime date) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    try {
      final doc = await _firestore
          .collection('user_data')
          .doc(userId)
          .collection('dailyTracking')
          .doc(dateStr)
          .get();
      
      if (!doc.exists) return {};
      
      return doc.data() ?? {};
    } catch (e) {
      print('Error getting daily tracking for date $dateStr: $e');
      return {};
    }
  }

  // Get location history
  Future<List<Map<String, dynamic>>> getLocationHistory(int days) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null) return [];

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    
    try {
      // Get all daily tracking documents for the specified period
      final querySnapshot = await _firestore
          .collection('user_data')
          .doc(userId)
          .collection('dailyTracking')
          .where('date', isGreaterThanOrEqualTo: startDate)
          .orderBy('date', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting location history: $e');
      return [];
    }
  }

  // Get most visited petrol pumps
  Future<List<Map<String, dynamic>>> getMostVisitedPumps() async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null) return [];
    
    try {
      // Get user's visits
      final visitsSnapshot = await _firestore
          .collection('visits')
          .where('userId', isEqualTo: userId)
          .get();
      
      // Count visits per petrol pump
      final Map<String, int> pumpVisits = {};
      final Map<String, Map<String, dynamic>> pumpDetails = {};
      
      for (var doc in visitsSnapshot.docs) {
        final data = doc.data();
        final pumpId = data['pumpId'] as String?;
        
        if (pumpId != null) {
          pumpVisits[pumpId] = (pumpVisits[pumpId] ?? 0) + 1;
          pumpDetails[pumpId] = data['pumpDetails'] as Map<String, dynamic>? ?? {};
        }
      }
      
      // Convert to list and sort by visit count
      final result = pumpDetails.entries.map((entry) {
        final pumpId = entry.key;
        final details = entry.value;
        
        return {
          ...details,
          'pumpId': pumpId,
          'visitCount': pumpVisits[pumpId] ?? 0,
        };
      }).toList();
      
      // Sort by visit count (descending)
      result.sort((a, b) => (b['visitCount'] as int).compareTo(a['visitCount'] as int));
      
      return result;
    } catch (e) {
      print('Error getting most visited pumps: $e');
      return [];
    }
  }

  // Add a petrol pump visit
  Future<bool> addPumpVisit(String pumpId, Map<String, dynamic> pumpDetails) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null) return false;
    
    try {
      // Check if user has already visited this pump today
      final hasVisitedToday = await _checkIfVisitedToday(userId, pumpId);
      
      if (!hasVisitedToday) {
        // Only increment visit count if this is the first visit to this pump today
        await _firestore.collection('user_data').doc(userId).update({
          'stats.visits': FieldValue.increment(1),
        });
        
        // Record this visit to prevent duplicates
        await _recordPumpVisit(userId, pumpId);
      }
      
      return true;
    } catch (e) {
      print('Error adding pump visit: $e');
      return false;
    }
  }

  // Check if user has already visited this pump today
  Future<bool> _checkIfVisitedToday(String userId, String pumpId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final snapshot = await _firestore
          .collection('user_data')
          .doc(userId)
          .collection('dailyVisits')
          .where('pumpId', isEqualTo: pumpId)
          .where('visitDate', isGreaterThanOrEqualTo: startOfDay)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if visited today: $e');
      return false;
    }
  }

  // Record a pump visit to prevent duplicates
  Future<void> _recordPumpVisit(String userId, String pumpId) async {
    try {
      await _firestore
          .collection('user_data')
          .doc(userId)
          .collection('dailyVisits')
          .add({
        'pumpId': pumpId,
        'visitDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error recording pump visit: $e');
    }
  }

  // Add image upload
  Future<bool> addImageUpload(String imageUrl, String pumpId, Map<String, dynamic> metadata) async {
    final userId = await _authService.getCurrentUserId();
    if (userId == null) return false;
    
    try {
      // Only update user stats - no need to store upload details
      await _firestore.collection('user_data').doc(userId).update({
        'stats.uploads': FieldValue.increment(1),
      });
      
      return true;
    } catch (e) {
      print('Error adding image upload: $e');
      return false;
    }
  }
} 