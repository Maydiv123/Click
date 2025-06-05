import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user data
  Stream<Map<String, dynamic>> getUserData() {
    final userId = _auth.currentUser?.uid;
    print('Current user ID: $userId'); // Debug print
    if (userId == null) {
      print('No user ID found, returning empty map'); // Debug print
      return Stream.value({});
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
          print('User data received: ${doc.data()}'); // Debug print
          return doc.data() ?? {};
        });
  }

  // Update user location
  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('No user ID found, cannot update location');
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': Timestamp.fromDate(timestamp),
        },
        'lastLocationUpdate': Timestamp.fromDate(timestamp),
      });
      print('User location updated successfully');
      
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

  // Get upcoming tasks
  Stream<List<Map<String, dynamic>>> getUpcomingTasks() {
    final userId = _auth.currentUser?.uid;
    print('Fetching upcoming tasks for user: $userId'); // Debug print
    if (userId == null) return Stream.value([]);

    final now = DateTime.now();

    return _firestore
        .collection('tasks')
        .where('userId', isEqualTo: userId)
        .where('dueDate', isGreaterThanOrEqualTo: now)
        .orderBy('dueDate')
        .snapshots()
        .map((snapshot) {
          print('Upcoming tasks received: ${snapshot.docs.length}'); // Debug print
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
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
  Stream<List<Map<String, dynamic>>> getRecentActivities() {
    final userId = _auth.currentUser?.uid;
    print('Fetching recent activities for user: $userId'); // Debug print
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .map((snapshot) {
          print('Recent activities received: ${snapshot.docs.length}'); // Debug print
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }
} 