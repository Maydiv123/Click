import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String userType,
    String? teamId,
  }) async {
    try {
      // Create the user in Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create the user document in Firestore
      await _userService.createUserDocument(
        uid: userCredential.user!.uid,
        firstName: firstName,
        lastName: lastName,
        dob: '', // These fields will be updated later
        address: '',
        aadharNo: '',
        mobile: phoneNumber,
        userType: UserType.values.firstWhere((e) => e.toString().split('.').last == userType),
        teamCode: teamId,
        preferredCompanies: [], // This will be updated later
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        throw 'An account already exists for that email.';
      }
      throw e.message ?? 'An error occurred during registration.';
    } catch (e) {
      throw 'An error occurred during registration.';
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        throw 'Firebase is not initialized. Please restart the app.';
      }
      
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in auth_service: ${e.code} - ${e.message}');
      if (e.code == 'user-not-found') {
        throw 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        throw 'Wrong password provided for that user.';
      } else if (e.code == 'invalid-email') {
        throw 'Invalid email format.';
      } else if (e.code == 'user-disabled') {
        throw 'This user account has been disabled.';
      } else if (e.code == 'operation-not-allowed') {
        throw 'Email/password sign-in is not enabled.';
      } else if (e.code == 'too-many-requests') {
        throw 'Too many failed login attempts. Try again later.';
      } else if (e.code == 'network-request-failed') {
        throw 'Network error. Check your internet connection.';
      } else if (e.code == 'app-not-authorized') {
        throw 'App not authorized to use Firebase Authentication.';
      } 
      throw e.message ?? 'An error occurred during sign in.';
    } on PlatformException catch (e) {
      print('PlatformException in auth_service: ${e.code} - ${e.message}');
      throw 'Platform error: [${e.code}] ${e.message}';
    } catch (e) {
      print('General error in auth_service: ${e.toString()} (${e.runtimeType})');
      throw 'Sign in error: ${e.toString()} (${e.runtimeType})';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'An error occurred during sign out.';
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'No user found for that email.';
      }
      throw e.message ?? 'An error occurred while sending password reset email.';
    } catch (e) {
      throw 'An error occurred while sending password reset email.';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.updatePhotoURL(photoURL);
    } catch (e) {
      throw 'An error occurred while updating profile.';
    }
  }

  // Update user email
  Future<void> updateUserEmail(String newEmail) async {
    try {
      await _auth.currentUser?.updateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign in again to update your email.';
      }
      throw e.message ?? 'An error occurred while updating email.';
    } catch (e) {
      throw 'An error occurred while updating email.';
    }
  }

  // Update user password
  Future<void> updateUserPassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign in again to update your password.';
      }
      throw e.message ?? 'An error occurred while updating password.';
    } catch (e) {
      throw 'An error occurred while updating password.';
    }
  }

  // Delete user account
  Future<void> deleteUserAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Please sign in again to delete your account.';
      }
      throw e.message ?? 'An error occurred while deleting account.';
    } catch (e) {
      throw 'An error occurred while deleting account.';
    }
  }

  // Get user token
  Future<String?> getUserToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      throw 'An error occurred while getting user token.';
    }
  }

  // Update last login timestamp
  Future<void> updateLastLogin(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }
} 