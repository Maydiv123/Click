import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreInitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize Firestore collections
  Future<void> initializeCollections() async {
    try {
      // Create users collection if it doesn't exist
      await _createCollectionIfNotExists('users');
      
      // Create teams collection if it doesn't exist
      await _createCollectionIfNotExists('teams');
      
      // Create teamRequests collection if it doesn't exist
      await _createCollectionIfNotExists('teamRequests');

      // Create visits collection if it doesn't exist
      await _createCollectionIfNotExists('visits');

      // Create tasks collection if it doesn't exist
      await _createCollectionIfNotExists('tasks');

      // Create statistics collection if it doesn't exist
      await _createCollectionIfNotExists('statistics');

      // Create activities collection if it doesn't exist
      await _createCollectionIfNotExists('activities');
      
      // Create a test team with code 666666 if it doesn't exist
      await _createTestTeam();
    } catch (e) {
      rethrow;
    }
  }

  // Helper method to create a collection if it doesn't exist
  Future<void> _createCollectionIfNotExists(String collectionName) async {
    try {
      // Try to get a document from the collection
      final QuerySnapshot snapshot = await _firestore.collection(collectionName).limit(1).get();
      
      // If the collection doesn't exist, create it by adding a dummy document
      if (snapshot.docs.isEmpty) {
        await _firestore.collection(collectionName).add({
          'createdAt': FieldValue.serverTimestamp(),
          'isDummy': true,
        });
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Create a test team with code 666666 for testing
  Future<void> _createTestTeam() async {
    try {
      // Check if test team already exists
      final docRef = _firestore.collection('teams').doc('666666');
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('Creating test team with code 666666');
        await docRef.set({
          'teamName': 'Test Team',
          'ownerId': 'system',
          'createdAt': FieldValue.serverTimestamp(),
          'memberCount': 1,
          'activeMembers': 1,
          'pendingRequests': 0,
          'teamStats': {
            'totalVisits': 0,
            'totalUploads': 0,
            'totalDistance': 0,
            'totalFuelConsumption': 0,
          },
        });
        print('Test team created successfully');
      } else {
        print('Test team 666666 already exists');
      }
    } catch (e) {
      print('Error creating test team: $e');
    }
  }
} 