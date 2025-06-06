import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserType { individual, teamMember, teamOwner }
enum TeamMemberStatus { pending, active, rejected }

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  final CollectionReference _usersCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference _teamsCollection = FirebaseFirestore.instance.collection('teams');
  final CollectionReference _teamRequestsCollection = FirebaseFirestore.instance.collection('teamRequests');

  // Create user document with type-specific fields
  Future<void> createUserDocument({
    required String uid,
    required String firstName,
    required String lastName,
    required String dob,
    required String address,
    required String aadharNo,
    required String mobile,
    required UserType userType,
    String? teamCode, // For team members
    String? referralCode, // For team members joining via referral
    String? teamName, // For team owners
    required List<String> preferredCompanies,
  }) async {
    try {
      // Start a batch write
      WriteBatch batch = _firestore.batch();

      // Common user data
      Map<String, dynamic> userData = {
        'firstName': firstName,
        'lastName': lastName,
        'dob': dob,
        'address': address,
        'aadharNo': aadharNo,
        'mobile': mobile,
        'userType': userType.toString(),
        'preferredCompanies': preferredCompanies,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'profileCompletion': 0,
        'stats': {
          'visits': 0,
          'uploads': 0,
          'teamChats': 0,
          'totalDistance': 0,
          'fuelConsumption': 0,
        },
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Add type-specific data
      switch (userType) {
        case UserType.teamOwner:
          // Generate unique team code
          String generatedTeamCode = await _generateUniqueTeamCode();
          
          // Create team document - Use the team code as the document ID
          DocumentReference teamRef = _teamsCollection.doc(generatedTeamCode);
          batch.set(teamRef, {
            'teamName': teamName,
            'ownerId': uid,
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

          // Add team owner specific data
          userData.addAll({
            'teamCode': generatedTeamCode,
            'isTeamOwner': true,
            'teamName': teamName,
          });
          break;

        case UserType.teamMember:
          if (referralCode != null) {
            // Create team join request
            DocumentReference requestRef = _teamRequestsCollection.doc();
            batch.set(requestRef, {
              'userId': uid,
              'teamCode': teamCode,
              'referralCode': referralCode,
              'status': TeamMemberStatus.pending.toString(),
              'createdAt': FieldValue.serverTimestamp(),
              'userData': {
                'firstName': firstName,
                'lastName': lastName,
                'mobile': mobile,
              },
            });

            // Update team's pending requests count
            DocumentReference teamRef = _teamsCollection.doc(teamCode);
            batch.update(teamRef, {
              'pendingRequests': FieldValue.increment(1),
            });
          }

          // Add team member specific data
          userData.addAll({
            'teamCode': teamCode,
            'isTeamOwner': false,
            'teamMemberStatus': TeamMemberStatus.pending.toString(),
            'joinedAt': FieldValue.serverTimestamp(),
          });
          break;

        case UserType.individual:
          // Add individual user specific data
          userData.addAll({
            'isTeamOwner': false,
            'teamCode': null,
          });
          break;
      }

      // Create user document
      DocumentReference userRef = _usersCollection.doc(uid);
      batch.set(userRef, userData);

      // Commit the batch
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Generate unique team code
  Future<String> _generateUniqueTeamCode() async {
    String code;
    bool isUnique = false;
    
    do {
      // Generate a 6-character alphanumeric code
      code = _generateRandomCode(6);
      
      // Check if code exists
      final docSnapshot = await _teamsCollection.doc(code).get();
      isUnique = !docSnapshot.exists;
      
    } while (!isUnique);
    
    return code;
  }

  // Generate random alphanumeric code
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[DateTime.now().microsecondsSinceEpoch % chars.length]).join();
  }

  // Handle team join request
  Future<void> handleTeamRequest({
    required String requestId,
    required String teamCode,
    required String userId,
    required bool accept,
  }) async {
    try {
      WriteBatch batch = _firestore.batch();

      // Update request status
      DocumentReference requestRef = _teamRequestsCollection.doc(requestId);
      batch.update(requestRef, {
        'status': accept ? TeamMemberStatus.active.toString() : TeamMemberStatus.rejected.toString(),
        'processedAt': FieldValue.serverTimestamp(),
      });

      // Update team document
      DocumentReference teamRef = _teamsCollection.doc(teamCode);
      if (accept) {
        batch.update(teamRef, {
          'memberCount': FieldValue.increment(1),
          'activeMembers': FieldValue.increment(1),
          'pendingRequests': FieldValue.increment(-1),
        });

        // Update user document
        DocumentReference userRef = _usersCollection.doc(userId);
        batch.update(userRef, {
          'teamMemberStatus': TeamMemberStatus.active.toString(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.update(teamRef, {
          'pendingRequests': FieldValue.increment(-1),
        });
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Get team members
  Future<QuerySnapshot> getTeamMembers(String teamCode) async {
    try {
      return await _usersCollection
          .where('teamCode', isEqualTo: teamCode)
          .where('teamMemberStatus', isEqualTo: TeamMemberStatus.active.toString())
          .get();
    } catch (e) {
      rethrow;
    }
  }

  // Get pending team requests
  Future<QuerySnapshot> getPendingTeamRequests(String teamCode) async {
    try {
      return await _teamRequestsCollection
          .where('teamCode', isEqualTo: teamCode)
          .where('status', isEqualTo: TeamMemberStatus.pending.toString())
          .orderBy('createdAt', descending: true)
          .get();
    } catch (e) {
      rethrow;
    }
  }

  // Get team details
  Future<DocumentSnapshot> getTeamDetails(String teamCode) async {
    try {
      return await _teamsCollection.doc(teamCode).get();
    } catch (e) {
      rethrow;
    }
  }

  // Update team stats
  Future<void> updateTeamStats(String teamCode, Map<String, dynamic> stats) async {
    try {
      await _teamsCollection.doc(teamCode).update({
        'teamStats': stats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Remove team member
  Future<void> removeTeamMember(String teamCode, String userId) async {
    try {
      print('Removing user $userId from team $teamCode');
      
      // First check if user exists and is in the team
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        throw 'User not found';
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['teamCode'] != teamCode) {
        throw 'User is not in this team';
      }
      
      WriteBatch batch = _firestore.batch();

      // Update team document
      DocumentReference teamRef = _teamsCollection.doc(teamCode);
      batch.update(teamRef, {
        'memberCount': FieldValue.increment(-1),
        'activeMembers': FieldValue.increment(-1),
      });

      // Update user document
      DocumentReference userRef = _usersCollection.doc(userId);
      batch.update(userRef, {
        'teamCode': null,
        'teamName': null,
        'isTeamOwner': false,
        'teamMemberStatus': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('Successfully removed user from team');
    } catch (e) {
      print('Error in removeTeamMember: $e');
      rethrow;
    }
  }

  // Get user by referral code
  Future<QuerySnapshot> getUserByReferralCode(String referralCode) async {
    try {
      return await _usersCollection
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();
    } catch (e) {
      rethrow;
    }
  }

  // Get user document
  Future<DocumentSnapshot> getUserDocument(String uid) async {
    try {
      return await _usersCollection.doc(uid).get();
    } catch (e) {
      rethrow;
    }
  }

  // Update user document
  Future<void> updateUserDocument(String uid, Map<String, dynamic> data) async {
    try {
      await _usersCollection.doc(uid).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update profile completion
  Future<void> updateProfileCompletion(String uid, int completion) async {
    try {
      await _usersCollection.doc(uid).update({
        'profileCompletion': completion,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update user stats
  Future<void> updateUserStats(String uid, Map<String, dynamic> stats) async {
    try {
      await _usersCollection.doc(uid).update({
        'stats': stats,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update team information
  Future<void> updateTeamInfo(String uid, Map<String, dynamic> teamInfo) async {
    try {
      await _usersCollection.doc(uid).update({
        'teamInfo': teamInfo,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update last login
  Future<void> updateLastLogin(String uid) async {
    try {
      await _usersCollection.doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get user by team code
  Future<QuerySnapshot> getUsersByTeamCode(String teamCode) async {
    try {
      return await _usersCollection
          .where('teamCode', isEqualTo: teamCode)
          .get();
    } catch (e) {
      rethrow;
    }
  }

  // Delete user document
  Future<void> deleteUserDocument(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
    } catch (e) {
      rethrow;
    }
  }
}