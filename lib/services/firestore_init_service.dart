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
} 