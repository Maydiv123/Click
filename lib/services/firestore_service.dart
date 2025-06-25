import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a document to a collection
  Future<DocumentReference> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      return await _firestore.collection(collection).add(data);
    } catch (e) {
      rethrow;
    }
  }

  // Get a document from a collection
  Future<DocumentSnapshot> getDocument(String collection, String documentId) async {
    try {
      return await _firestore.collection(collection).doc(documentId).get();
    } catch (e) {
      rethrow;
    }
  }

  // Update a document
  Future<void> updateDocument(
      String collection, String documentId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a document
  Future<void> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get all documents from a collection
  Stream<QuerySnapshot> getCollectionStream(String collection) {
    return _firestore.collection(collection).snapshots();
  }
  
  // Get ad images from Firestore
  Future<List<String>> getAdImageUrls() async {
    try {
      final snapshot = await _firestore.collection('adImages')
          .orderBy('order')
          .get();
      
      if (snapshot.docs.isEmpty) {
        // Return default ad images if no custom images are set
        return [
          'https://www.shutterstock.com/image-vector/engine-oil-advertising-banner-3d-260nw-2419747347.jpg',
          'https://exchange4media.gumlet.io/news-photo/1530600458_Sj56qH_Indian-Oil_Car-creative_final.jpg',
          'https://pbs.twimg.com/media/E3l4p85VEAA0ZhW.jpg:large',
          'https://beast-of-traal.s3.ap-south-1.amazonaws.com/2022/05/hero-pleasureplus-hindi-ad.jpeg'
        ];
      }
      
      return snapshot.docs
          .map((doc) => doc['imageUrl'] as String)
          .toList();
    } catch (e) {
      print('Error fetching ad images: $e');
      // Return default images on error
      return [
        'https://www.shutterstock.com/image-vector/engine-oil-advertising-banner-3d-260nw-2419747347.jpg',
        'https://exchange4media.gumlet.io/news-photo/1530600458_Sj56qH_Indian-Oil_Car-creative_final.jpg',
        'https://pbs.twimg.com/media/E3l4p85VEAA0ZhW.jpg:large',
        'https://beast-of-traal.s3.ap-south-1.amazonaws.com/2022/05/hero-pleasureplus-hindi-ad.jpeg'
      ];
    }
  }
  
  // Get special offer ad details
  Future<Map<String, dynamic>> getSpecialOfferAd() async {
    try {
      final docRef = _firestore.collection('settings').doc('specialOffer');
      final doc = await docRef.get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        // Create default special offer if it doesn't exist
        final defaultOffer = {
          'title': 'Special Offer',
          'subtitle': 'Limited time promotion',
          'description': 'Check out our latest promotions and discounts on fuel and services.',
          'imageUrl': 'https://img.freepik.com/free-vector/gradient-oil-company-banner-template_23-2149414899.jpg',
          'actionText': 'Learn More',
          'actionUrl': 'https://www.example.com/offers',
          'active': true,
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        await docRef.set(defaultOffer);
        return defaultOffer;
      }
    } catch (e) {
      print('Error fetching special offer ad: $e');
      // Return default values on error
      return {
        'title': 'Special Offer',
        'subtitle': 'Limited time promotion',
        'description': 'Check out our latest promotions and discounts on fuel and services.',
        'imageUrl': 'https://img.freepik.com/free-vector/gradient-oil-company-banner-template_23-2149414899.jpg',
        'actionText': 'Learn More',
        'actionUrl': '',
        'active': true,
      };
    }
  }
  
  // Update special offer ad
  Future<void> updateSpecialOfferAd(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('settings').doc('specialOffer').set(data, SetOptions(merge: true));
    } catch (e) {
      print('Error updating special offer ad: $e');
      rethrow;
    }
  }
} 