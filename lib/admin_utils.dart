import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminUtils {
  // In-memory cache
  static bool? _cachedAdminStatus;
  static String? _cachedUserId;

  // SharedPreferences keys
  static const String _adminRoleKey = 'is_admin_role';
  static const String _userIdKey = 'cached_user_id';

  // Check if current user is admin with caching
  static Future<bool> isCurrentUserAdmin({bool useCache = true}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _clearInMemoryCache();
        return false;
      }

      // Return in-memory cache if available and valid
      if (useCache && _cachedAdminStatus != null && _cachedUserId == user.uid) {
        return _cachedAdminStatus!;
      }

      // Try SharedPreferences cache first
      if (useCache) {
        final cachedRole = await _getCachedRole(user.uid);
        if (cachedRole != null) {
          _cachedAdminStatus = cachedRole;
          _cachedUserId = user.uid;

          // Verify in background without blocking UI
          _verifyRoleInBackground(user.uid);

          return cachedRole;
        }
      }

      // Fresh query to Firestore
      return await _queryAdminRole(user.uid);
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  // Query admin role from Firestore and cache result
  static Future<bool> _queryAdminRole(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      bool isAdmin = false;
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        isAdmin = userData['role'] == 'admin';
      }

      // Cache the result
      _cachedAdminStatus = isAdmin;
      _cachedUserId = userId;
      await _cacheRole(userId, isAdmin);

      return isAdmin;
    } catch (e) {
      print('Error querying admin role: $e');
      return false;
    }
  }

  // Background verification without blocking UI
  static void _verifyRoleInBackground(String userId) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      bool actualRole = false;
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        actualRole = userData['role'] == 'admin';
      }

      // Update cache if there's a difference
      if (_cachedAdminStatus != actualRole) {
        _cachedAdminStatus = actualRole;
        await _cacheRole(userId, actualRole);
      }
    } catch (e) {
      print('Background role verification failed: $e');
    }
  }

  // Cache role in SharedPreferences
  static Future<void> _cacheRole(String userId, bool isAdmin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      await prefs.setBool(_adminRoleKey, isAdmin);
    } catch (e) {
      print('Error caching role: $e');
    }
  }

  // Get cached role from SharedPreferences
  static Future<bool?> _getCachedRole(String currentUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString(_userIdKey);

      // Validate if cache is for the same user
      if (cachedUserId != currentUserId) {
        await _clearCache();
        return null;
      }

      return prefs.getBool(_adminRoleKey);
    } catch (e) {
      print('Error getting cached role: $e');
      return null;
    }
  }

  // Clear all caches
  static Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_adminRoleKey);
      await prefs.remove(_userIdKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  // Clear in-memory cache
  static void _clearInMemoryCache() {
    _cachedAdminStatus = null;
    _cachedUserId = null;
  }

  // Clear all caches (public method)
  static Future<void> clearCache() async {
    _clearInMemoryCache();
    await _clearCache();
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
