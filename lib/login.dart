import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showResendButton = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Fungsi untuk mengirim ulang email verifikasi
  Future<void> _resendVerificationEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Coba login kembali untuk mendapatkan user
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _errorMessage =
              'Masukkan email dan kata sandi untuk mengirim ulang verifikasi';
          _isLoading = false;
        });
        return;
      }

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;
      if (user != null) {
        // Alih-alih menggunakan sendEmailVerification(), update Firestore document
        // untuk memicu cloud function yang mengirim email kustom
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'verificationEmailSent': false,
              'verificationEmailSentAt': null,
              'resendVerification': true,
              'resendVerificationAt': FieldValue.serverTimestamp(),
            });

        // Tunggu sebentar untuk memastikan data tersimpan dan cloud function terpicu
        await Future.delayed(const Duration(seconds: 1));

        // Logout setelah mengirim email verifikasi
        await FirebaseAuth.instance.signOut();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email verifikasi telah dikirim ulang. Silakan periksa inbox Anda.',
              ),
              duration: Duration(seconds: 5),
              backgroundColor: Color(0xFFCA4A63),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengirim email: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat mengirim email verifikasi';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk reset password
  Future<void> _resetPassword(BuildContext context) async {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;
    // Isi awal field email jika sudah dimasukkan di form login
    if (_emailController.text.isNotEmpty) {
      emailController.text = _emailController.text.trim();
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text(
                'Atur Ulang Kata Sandi',
                style: TextStyle(
                  color: Color(0xFF6C1022),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Masukkan email akun Anda untuk menerima tautan atur ulang kata sandi.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                          borderSide: BorderSide(color: Color(0xFF6C1022)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                          borderSide: BorderSide(
                            color: Color(0xFF6C1022),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        labelStyle: TextStyle(color: Color(0xFF6B6B6B)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                          borderSide: BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.5,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Color(0xFF6C1022)),
                  ),
                  onPressed:
                      isLoading
                          ? null
                          : () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child:
                      isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF6C1022),
                              ),
                              strokeWidth: 2,
                            ),
                          )
                          : const Text(
                            'Kirim',
                            style: TextStyle(
                              color: Color(0xFF6C1022),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            final email = emailController.text.trim();
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email wajib diisi'),
                                  backgroundColor: Color(0xFFCA4A63),
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isLoading = true);
                            print(
                              '[RESET_PASSWORD] Mengirim tautan reset ke: $email',
                            );

                            try {
                              // Kirim email reset kata sandi - menggunakan template default Firebase
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: email);

                              if (context.mounted) {
                                Navigator.of(dialogContext).pop();

                                // Tampilkan pesan sukses yang lebih detail
                                showDialog(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text(
                                          'Reset Kata Sandi',
                                          style: TextStyle(
                                            color: Color(0xFF6C1022),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Tautan reset kata sandi telah dikirim ke email Anda jika terdaftar dalam sistem.',
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Petunjuk:',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '1. Periksa email Anda (termasuk folder spam)',
                                            ),
                                            Text(
                                              '2. Klik tautan di email dan buat kata sandi baru',
                                            ),
                                            Text(
                                              '3. Buka kembali aplikasi dan login dengan kata sandi baru',
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            child: const Text(
                                              'OK',
                                              style: TextStyle(
                                                color: Color(0xFF6C1022),
                                              ),
                                            ),
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                          ),
                                        ],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                      ),
                                );
                              }
                            } on FirebaseAuthException catch (e) {
                              print(
                                '[RESET_PASSWORD] Kesalahan Firebase: ${e.code} - ${e.message}',
                              );
                              setDialogState(() => isLoading = false);

                              // Untuk kasus user-not-found, tutup dialog tanpa pesan error
                              // Ini agar UX tetap baik dan tidak mengungkapkan info keamanan
                              if (e.code == 'user-not-found') {
                                Navigator.of(dialogContext).pop();
                              } else {
                                // Untuk error lain, tampilkan pesan error
                                String errorMessage =
                                    e.message ?? 'Terjadi kesalahan';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: const Color(0xFF6C1022),
                                  ),
                                );
                              }
                            } catch (e) {
                              print('[RESET_PASSWORD] Kesalahan umum: $e');
                              setDialogState(() => isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Terjadi kesalahan saat mengirim email reset',
                                  ),
                                  backgroundColor: Color(0xFF6C1022),
                                ),
                              );
                            }
                          },
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showResendButton = false;
    });

    try {
      // Login
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      print('[LOGIN] Mencoba masuk dengan email: $email');
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // Reload user untuk mendapatkan status emailVerified terbaru
      User? user = userCredential.user;
      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        if (!user!.emailVerified) {
          // Email belum diverifikasi
          await FirebaseAuth.instance.signOut();

          if (mounted) {
            setState(() {
              _errorMessage =
                  'Email belum diverifikasi. Silakan verifikasi email Anda terlebih dahulu.';
              _showResendButton = true;
              _isLoading = false;
            });
          }
          return;
        }

        // Email sudah diverifikasi, simpan status login
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('email', user.email ?? '');
          await prefs.setString('uid', user.uid);

          // Ambil data pengguna dari Firestore untuk mendapatkan nama
          try {
            DocumentSnapshot userDoc =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();

            if (userDoc.exists) {
              Map<String, dynamic> userData =
                  userDoc.data() as Map<String, dynamic>;
              String userName = userData['nama'] ?? '';
              String userRole =
                  userData['role'] ?? 'user'; // Default to 'user' if no role

              // Simpan nama pengguna ke SharedPreferences untuk persistensi
              await prefs.setString('userName', userName);
              await prefs.setString(
                'userRole',
                userRole,
              ); // Simpan role pengguna
              print(
                '[LOGIN] Nama pengguna disimpan ke SharedPreferences: $userName',
              );
              print(
                '[LOGIN] Role pengguna disimpan ke SharedPreferences: $userRole',
              );

              // Perbarui Firebase Auth displayName jika kosong atau berbeda
              if (userName.isNotEmpty &&
                  (user.displayName == null ||
                      user.displayName!.isEmpty ||
                      user.displayName != userName)) {
                await user.updateDisplayName(userName);
                print(
                  '[LOGIN] Firebase Auth displayName diperbarui menjadi: $userName',
                );

                // Muat ulang pengguna untuk memastikan perubahan tercermin
                await user.reload();
                print(
                  '[LOGIN] Pengguna dimuat ulang setelah pembaruan displayName',
                );
              }
            }
          } catch (firestoreError) {
            print(
              '[LOGIN] Kesalahan mengambil data pengguna dari Firestore: $firestoreError',
            );
          }

          print('[LOGIN] Berhasil menyimpan status login ke SharedPreferences');
        } catch (e) {
          print("[LOGIN] Kesalahan menyimpan ke SharedPreferences: $e");
          // Lanjutkan meskipun gagal menyimpan ke SharedPreferences
        }

        // Navigasi ke HomePage
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }

        // Refresh FCM token after successful login to ensure fresh token
        print('[LOGIN] Refreshing FCM token after successful login');
        try {
          // Import FirebaseMessaging to call token refresh
          final fcmToken = await FirebaseMessaging.instance.getToken(
            vapidKey: null,
          );
          if (fcmToken != null) {
            // Update token in Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
                  'fcmToken': fcmToken,
                  'tokenUpdatedAt': FieldValue.serverTimestamp(),
                  'tokenValidatedAt': FieldValue.serverTimestamp(),
                  'needsTokenRefresh': false,
                });
            print(
              '[LOGIN] ✅ FCM token refreshed and saved after login: ${fcmToken.substring(0, 20)}...',
            );
          }
        } catch (tokenError) {
          print(
            '[LOGIN] ⚠️ Failed to refresh FCM token after login: $tokenError',
          );
          // Don't block login flow if token refresh fails
        }
      }
    } on FirebaseAuthException catch (e) {
      print('[LOGIN] Kesalahan FirebaseAuth: ${e.code} - ${e.message}');

      String displayMessage;

      // Tangani kode kesalahan tertentu
      switch (e.code) {
        case 'invalid-credential':
        case 'invalid-email':
        case 'user-not-found':
        case 'wrong-password':
          displayMessage = 'Email atau kata sandi tidak valid.';
          break;
        case 'user-disabled':
          displayMessage = 'Akun ini telah dinonaktifkan.';
          break;
        case 'too-many-requests':
          displayMessage =
              'Terlalu banyak percobaan login. Silakan coba lagi nanti.';
          break;
        default:
          displayMessage = e.message ?? 'Terjadi kesalahan. Coba lagi.';
      }

      if (mounted) {
        setState(() {
          _errorMessage = displayMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[LOGIN] Kesalahan umum: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan. Coba lagi.';
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
      body: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                MediaQuery.of(context).size.height -
                AppBar().preferredSize.height -
                MediaQuery.of(context).padding.top,
          ),
          child: IntrinsicHeight(
            child: Column(
              children: [
                // Bagian atas dengan logo dan teks sambutan
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 60),
                      Image.asset('assets/images/login3d.png', height: 185),
                      const SizedBox(height: 32),
                      const Text(
                        'Selamat Datang di Finblood',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C1022),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Masuk untuk memulai',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Container dengan form login
                Flexible(
                  fit: FlexFit.tight,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF6C1022),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        24.0,
                        30.0,
                        24.0,
                        24.0,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                labelStyle: TextStyle(color: Colors.white),
                                errorStyle: TextStyle(color: Colors.white),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
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
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Kata Sandi',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(color: Colors.white),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                labelStyle: TextStyle(color: Colors.white),
                                errorStyle: TextStyle(color: Colors.white),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(50),
                                  ),
                                  borderSide: BorderSide(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                              ),
                              style: const TextStyle(color: Colors.white),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Kata Sandi wajib diisi';
                                }
                                if (value.length < 6) {
                                  return 'Kata Sandi minimal 6 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            if (_showResendButton)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextButton(
                                  onPressed:
                                      _isLoading
                                          ? null
                                          : _resendVerificationEmail,
                                  child: const Text(
                                    'Kirim ulang email verifikasi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            // Tambahkan tombol lupa password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _resetPassword(context),
                                child: const Text(
                                  'Lupa Kata Sandi?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isLoading
                                          ? const Color(0xFFCA4A63)
                                          : Theme.of(
                                            context,
                                          ).scaffoldBackgroundColor,
                                  disabledBackgroundColor: const Color(
                                    0xFFCA4A63,
                                  ),
                                  foregroundColor: const Color(0xFF6C1022),
                                  textStyle: const TextStyle(fontSize: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  elevation: 5,
                                  shadowColor: const Color(0xFF000000),
                                ),
                                child:
                                    _isLoading
                                        ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                        : const Text(
                                          'Masuk',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(color: Colors.white),
                                  children: [
                                    TextSpan(
                                      text: 'Belum punya akun? ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Daftar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
