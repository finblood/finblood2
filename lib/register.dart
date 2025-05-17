import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Constants
const String _cloudFunctionUrl =
    'https://us-central1-fin-blood-2.cloudfunctions.net/deleteUserAccount';
const String _secretKey = 'finblood-dev-key-2024';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  // NAVIGATION HELPERS

  /// Safely navigate back to login screen after sign out
  Future<void> _navigateBackToLogin(BuildContext context) async {
    print('[REGISTER] Navigating back to login screen');
    if (context.mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.of(context).pop(); // Close dialog if open
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.pop(context); // Return to login page
    }
  }

  /// Sign out user and navigate back to login screen
  Future<void> _signOutAndNavigateBack(BuildContext context) async {
    print('[REGISTER] Signing out and navigating back');
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      print('[REGISTER] Error during sign out: $e');
    } finally {
      await _navigateBackToLogin(context);
    }
  }

  // DIALOG HELPERS

  /// Show email verification success dialog
  void _showVerificationDialog(BuildContext context, String email) {
    print('[REGISTER] Showing verification success dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Verifikasi Email',
              style: TextStyle(
                color: Color(0xFF6C1022),
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kami telah mengirim email verifikasi ke alamat email Anda. Silakan periksa inbox (dan folder spam) untuk memverifikasi email Anda.',
                ),
                const SizedBox(height: 12),
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Anda harus memverifikasi email sebelum dapat login.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _signOutAndNavigateBack(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFF6C1022),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
    );
  }

  /// Show registration error dialog and clean up user account
  void _showErrorRegistrationDialog(
    BuildContext context,
    String email,
    String uid,
  ) {
    print('[REGISTER] Showing registration error dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text(
              'Pendaftaran Gagal',
              style: TextStyle(
                color: Color(0xFF6C1022),
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Terjadi kesalahan saat mendaftarkan akun Anda. Data Anda akan dihapus secara otomatis agar Anda dapat mencoba mendaftar kembali.',
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _deleteUserAndNavigateBack(context, uid),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFF6C1022),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
    );
  }

  // ACCOUNT CLEANUP HELPERS

  /// Call cloud function to delete user account
  Future<bool> _callDeleteUserCloudFunction(String uid) async {
    try {
      print('[REGISTER] Calling cloud function to delete user: $uid');
      final Uri uri = Uri.parse(
        '$_cloudFunctionUrl?uid=$uid&secretKey=$_secretKey',
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('[REGISTER] Timeout calling cloud function');
              return http.Response('{"success":false,"error":"Timeout"}', 408);
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      }

      print(
        '[REGISTER] Failed to delete user via cloud function: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      print('[REGISTER] Error calling cloud function: $e');
      return false;
    }
  }

  /// Clean up user data and account after registration failure
  Future<void> _deleteUserAndNavigateBack(
    BuildContext context,
    String uid,
  ) async {
    print('[REGISTER] Cleaning up user data and account');
    try {
      // Delete Firestore user data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete()
          .then((_) => print('[REGISTER] User data deleted from Firestore'))
          .catchError(
            (e) => print('[REGISTER] Error deleting from Firestore: $e'),
          );

      // Try cloud function first
      bool deleted = await _callDeleteUserCloudFunction(uid);

      // Fall back to direct deletion if needed
      if (!deleted) {
        print('[REGISTER] Falling back to direct user deletion');
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await currentUser
              .delete()
              .then((_) => print('[REGISTER] User deleted from Firebase Auth'))
              .catchError(
                (e) =>
                    print('[REGISTER] Error deleting from Firebase Auth: $e'),
              );
        }
      }
    } catch (e) {
      print('[REGISTER] Error during user cleanup: $e');
    } finally {
      // Always sign out regardless of deletion success
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        print('[REGISTER] Error during sign out after cleanup: $e');
      }
      await _navigateBackToLogin(context);
    }
  }

  // MAIN REGISTRATION FLOW

  /// Handles the complete registration process
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    print('[REGISTER] Starting registration process');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    UserCredential? credential;
    try {
      // Check if email is already registered
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String nama = _namaController.text.trim();

      try {
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
          email,
        );
        if (methods.isNotEmpty) {
          setState(() {
            _errorMessage =
                'Email sudah terdaftar. Silakan gunakan email lain atau login.';
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        print('[REGISTER] Error checking email: $e');
        // Continue despite email check error
      }

      // Create user account
      print('[REGISTER] Creating user account');
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Failed to create user: User object is null');
      }

      final String uid = credential.user!.uid;
      print('[REGISTER] User created with UID: $uid');

      // Small delay to prevent race conditions
      await Future.delayed(const Duration(milliseconds: 300));

      // Update display name
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          await credential.user?.updateDisplayName(nama);
          print('[REGISTER] Display name updated');
        }
      } catch (e) {
        print('[REGISTER] Error updating display name: $e');
        // Continue despite display name update error
      }

      // Save user data to Firestore
      try {
        final userData = {
          'nama': nama,
          'email': email,
          'emailVerified': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'uid': uid,
          'displayName': nama,
          'verificationEmailSent': false,
          'verificationEmailSentAt': null,
          'registrationCompleted': true,
          'registrationMethod': 'email',
          'lastLoginAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(userData);
        print('[REGISTER] User data saved to Firestore');

        // Save username to SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', nama);
          print('[REGISTER] User name saved to SharedPreferences: $nama');
        } catch (e) {
          print('[REGISTER] Error saving user name to SharedPreferences: $e');
          // Continue despite SharedPreferences error
        }

        // Wait for cloud function to handle email verification
        await Future.delayed(const Duration(seconds: 1));

        if (context.mounted) {
          _showVerificationDialog(context, email);
        }
      } catch (firestoreError) {
        print('[REGISTER] Error saving data to Firestore: $firestoreError');
        throw firestoreError;
      }
    } on FirebaseAuthException catch (e) {
      print('[REGISTER] FirebaseAuthException: ${e.code} - ${e.message}');

      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage =
              'Email sudah terdaftar. Silakan gunakan email lain atau login.';
          break;
        case 'invalid-email':
          errorMessage = 'Format email tidak valid.';
          break;
        case 'weak-password':
          errorMessage =
              'Kata sandi terlalu lemah. Gunakan kata sandi yang lebih kuat.';
          break;
        case 'operation-not-allowed':
          errorMessage =
              'Operasi tidak diizinkan. Silakan hubungi administrator.';
          break;
        default:
          errorMessage = e.message ?? 'Terjadi kesalahan. Coba lagi.';
      }

      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      print('[REGISTER] General error: $e');

      // Handle partially created accounts
      if (credential != null && credential.user != null) {
        final String errorUid = credential.user!.uid;
        final String email = _emailController.text.trim();

        if (context.mounted) {
          _showErrorRegistrationDialog(context, email, errorUid);
        } else {
          // If context is not mounted, still try to clean up
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(errorUid)
                .delete();
            await FirebaseAuth.instance.signOut();
          } catch (cleanupError) {
            print('[REGISTER] Error during cleanup: $cleanupError');
          }
        }
      } else {
        // Show general error message
        setState(() {
          _errorMessage =
              'Terjadi kesalahan saat mendaftar. Silakan coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/logofinblood/logomaroon.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/register3d.png', height: 208),
                const SizedBox(height: 20),
                const Text(
                  'Buat Akun Baru',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6C1022),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Daftar untuk memulai',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _namaController,
                  labelText: 'Nama Lengkap',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama lengkap wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!value.contains('@')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  labelText: 'Kata Sandi',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kata sandi wajib diisi';
                    }
                    if (value.length < 6) {
                      return 'Kata sandi minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _confirmController,
                  labelText: 'Konfirmasi Kata Sandi',
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Konfirmasi kata sandi wajib diisi';
                    }
                    if (value != _passwordController.text) {
                      return 'Kata sandi tidak sama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) _buildErrorMessage(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C1022),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2.5,
                              ),
                            )
                            : const Text(
                              'Daftar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // UI COMPONENTS

  /// Create a styled text field with consistent appearance
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(50)),
          borderSide: BorderSide(color: Color(0xFF6C1022)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(50)),
          borderSide: BorderSide(color: Color(0xFF6C1022)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B6B6B)),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(50)),
          borderSide: BorderSide(color: Color(0xFF6C1022), width: 2),
        ),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
    );
  }

  /// Create a styled error message container
  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
