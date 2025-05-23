import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Konstanta
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

  // HELPER NAVIGASI

  /// Navigasi kembali ke layar login setelah sign out dengan aman
  Future<void> _navigateBackToLogin(BuildContext context) async {
    print('[REGISTER] Navigasi kembali ke layar login');
    if (context.mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.of(context).pop(); // Tutup dialog jika terbuka
      await Future.delayed(const Duration(milliseconds: 100));
      Navigator.pop(context); // Kembali ke halaman login
    }
  }

  /// Sign out pengguna dan navigasi kembali ke layar login
  Future<void> _signOutAndNavigateBack(BuildContext context) async {
    print('[REGISTER] Keluar dan navigasi kembali');
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      print('[REGISTER] Kesalahan selama sign out: $e');
    } finally {
      await _navigateBackToLogin(context);
    }
  }

  // HELPER DIALOG

  /// Menampilkan dialog sukses verifikasi email
  void _showVerificationDialog(BuildContext context, String email) {
    print('[REGISTER] Menampilkan dialog verifikasi sukses');
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

  /// Menampilkan dialog kesalahan registrasi dan membersihkan akun pengguna
  void _showErrorRegistrationDialog(
    BuildContext context,
    String email,
    String uid,
  ) {
    print('[REGISTER] Menampilkan dialog kesalahan registrasi');
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

  // HELPER PEMBERSIHAN AKUN

  /// Memanggil cloud function untuk menghapus akun pengguna
  Future<bool> _callDeleteUserCloudFunction(String uid) async {
    try {
      print(
        '[REGISTER] Memanggil cloud function untuk menghapus pengguna: $uid',
      );
      final Uri uri = Uri.parse(
        '$_cloudFunctionUrl?uid=$uid&secretKey=$_secretKey',
      );

      final response = await http
          .get(uri)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('[REGISTER] Waktu memanggil cloud function habis');
              return http.Response('{"success":false,"error":"Timeout"}', 408);
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['success'] == true;
      }

      print(
        '[REGISTER] Gagal menghapus pengguna via cloud function: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      print('[REGISTER] Kesalahan saat memanggil cloud function: $e');
      return false;
    }
  }

  /// Membersihkan data pengguna dan akun setelah kegagalan pendaftaran
  Future<void> _deleteUserAndNavigateBack(
    BuildContext context,
    String uid,
  ) async {
    print('[REGISTER] Membersihkan data dan akun pengguna');
    try {
      // Hapus data pengguna di Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete()
          .then((_) => print('[REGISTER] Data pengguna dihapus dari Firestore'))
          .catchError(
            (e) =>
                print('[REGISTER] Kesalahan saat menghapus dari Firestore: $e'),
          );

      // Coba gunakan cloud function terlebih dahulu
      bool deleted = await _callDeleteUserCloudFunction(uid);

      // Gunakan penghapusan langsung jika diperlukan
      if (!deleted) {
        print('[REGISTER] Beralih ke penghapusan pengguna langsung');
        final User? currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await currentUser
              .delete()
              .then(
                (_) => print('[REGISTER] Pengguna dihapus dari Firebase Auth'),
              )
              .catchError(
                (e) => print(
                  '[REGISTER] Kesalahan saat menghapus dari Firebase Auth: $e',
                ),
              );
        }
      }
    } catch (e) {
      print('[REGISTER] Kesalahan selama pembersihan pengguna: $e');
    } finally {
      // Selalu sign out terlepas dari keberhasilan penghapusan
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        print('[REGISTER] Kesalahan selama sign out setelah pembersihan: $e');
      }
      await _navigateBackToLogin(context);
    }
  }

  // MAIN REGISTRATION FLOW

  /// Menangani proses pendaftaran secara lengkap
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    print('[REGISTER] Memulai proses pendaftaran');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    UserCredential? credential;
    try {
      // Periksa apakah email sudah terdaftar
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
        print('[REGISTER] Kesalahan memeriksa email: $e');
        // Lanjutkan meskipun ada kesalahan pengecekan email
      }

      // Buat akun pengguna
      print('[REGISTER] Membuat akun pengguna');
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Failed to create user: User object is null');
      }

      final String uid = credential.user!.uid;
      print('[REGISTER] Pengguna dibuat dengan UID: $uid');

      // Penundaan kecil untuk mencegah kondisi race
      await Future.delayed(const Duration(milliseconds: 300));

      // Perbarui nama tampilan
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          await credential.user?.updateDisplayName(nama);
          print('[REGISTER] Nama tampilan diperbarui');
        }
      } catch (e) {
        print('[REGISTER] Kesalahan memperbarui nama tampilan: $e');
        // Lanjutkan meskipun ada kesalahan pembaruan nama tampilan
      }

      // Simpan data pengguna ke Firestore
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
        print('[REGISTER] Data pengguna disimpan ke Firestore');

        // Simpan nama pengguna ke SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', nama);
          print(
            '[REGISTER] Nama pengguna disimpan ke SharedPreferences: $nama',
          );
        } catch (e) {
          print(
            '[REGISTER] Kesalahan menyimpan nama pengguna ke SharedPreferences: $e',
          );
          // Lanjutkan meskipun ada kesalahan SharedPreferences
        }

        // Tunggu cloud function untuk menangani verifikasi email
        await Future.delayed(const Duration(seconds: 1));

        if (context.mounted) {
          _showVerificationDialog(context, email);
        }
      } catch (firestoreError) {
        print(
          '[REGISTER] Kesalahan menyimpan data ke Firestore: $firestoreError',
        );
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
      print('[REGISTER] Kesalahan umum: $e');

      // Handle akun yang dibuat sebagian
      if (credential != null && credential.user != null) {
        final String errorUid = credential.user!.uid;
        final String email = _emailController.text.trim();

        if (context.mounted) {
          _showErrorRegistrationDialog(context, email, errorUid);
        } else {
          // Jika context tidak dimounted, masih coba untuk membersihkan
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(errorUid)
                .delete();
            await FirebaseAuth.instance.signOut();
          } catch (cleanupError) {
            print('[REGISTER] Kesalahan selama pembersihan: $cleanupError');
          }
        }
      } else {
        // Tampilkan pesan kesalahan umum
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

  // KOMPONEN UI

  /// Membuat field teks dengan tampilan yang konsisten
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
          borderSide: BorderSide(color: Color(0xFF6C1022), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B6B6B)),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(50)),
          borderSide: BorderSide(color: Color(0xFF6C1022), width: 2.5),
        ),
      ),
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
    );
  }

  /// Membuat container pesan kesalahan dengan tampilan yang sesuai
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
