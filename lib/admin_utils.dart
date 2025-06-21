import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUtils {
  // Check if current user is admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] == 'admin';
      }
      return false;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Check if specific user is admin by UID
  static Future<bool> isUserAdmin(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] == 'admin';
      }
      return false;
    } catch (e) {
      print('Error checking admin status for user $uid: $e');
      return false;
    }
  }

  // Get current user role
  static Future<String> getCurrentUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'guest';

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['role'] ?? 'user';
      }
      return 'user';
    } catch (e) {
      print('Error getting user role: $e');
      return 'user';
    }
  }

  // Stream for checking admin status in real-time
  static Stream<bool> isCurrentUserAdminStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            final userData = snapshot.data() as Map<String, dynamic>;
            return userData['role'] == 'admin';
          }
          return false;
        });
  }

  // Make user admin
  static Future<bool> makeUserAdmin(String email) async {
    try {
      // Find user by email
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('User dengan email tersebut tidak ditemukan');
      }

      final userDoc = querySnapshot.docs.first;
      final userData = userDoc.data();

      // Check if already admin
      if (userData['role'] == 'admin') {
        throw Exception('User sudah menjadi admin');
      }

      // Update role to admin
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .update({'role': 'admin', 'updatedAt': FieldValue.serverTimestamp()});

      return true;
    } catch (e) {
      print('Error making user admin: $e');
      rethrow;
    }
  }

  // Remove admin role
  static Future<bool> removeAdminRole(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.uid == userId) {
        throw Exception(
          'Anda tidak dapat menghapus diri sendiri sebagai admin',
        );
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': 'user',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error removing admin role: $e');
      rethrow;
    }
  }

  // Get all admins
  static Stream<QuerySnapshot> getAllAdminsStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .snapshots();
  }

  // Check if there's at least one admin in the system
  static Future<bool> hasAtLeastOneAdmin() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .limit(1)
              .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking for admins: $e');
      return false;
    }
  }
}
