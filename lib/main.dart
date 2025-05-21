import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Ini akan dibuat otomatis oleh CLI Firebase
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

Future<void> main() async {
  // Menangkap semua error yang tidak tertangani
  runZonedGuarded(
    () async {
      // Inisialisasi Flutter
      WidgetsFlutterBinding.ensureInitialized();

      try {
        // Inisialisasi Firebase dengan error handling
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Menghapus pemanggilan signOut untuk mempertahankan status otentikasi pengguna

        print("Firebase berhasil di inisialisasikan");
      } catch (e) {
        print("Error initializing Firebase: $e");
        // Tetap lanjutkan aplikasi meskipun Firebase gagal
      }

      // Jalankan aplikasi
      runApp(const MyApp());
    },
    (error, stackTrace) {
      // Log semua error yang tidak tertangani
      print('ERROR TIDAK TERTANGANI: $error');
      print('STACK TRACE: $stackTrace');
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finblood',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        fontFamily: 'Poppins',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  Future<void> _checkFirstRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;

      await Future.delayed(
        const Duration(seconds: 1),
      ); // Menampilkan splash screen selama 1 detik

      if (mounted) {
        if (!onboardingCompleted) {
          // Pertama kali menjalankan aplikasi, tampilkan onboarding
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingPage()),
          );
        } else {
          // Onboarding sudah selesai, periksa otentikasi
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
          );
        }
      }
    } catch (e) {
      print("Error checking first run: $e");
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C1022),
      body: Center(
        child: Image.asset('assets/logofinblood/logofinblood.png', width: 200),
      ),
    );
  }
}

// Widget untuk mengelola otentikasi
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checkingPrefs = true;
  bool _foundSavedUser = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkSavedLogin();
  }

  Future<void> _checkSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (isLoggedIn && FirebaseAuth.instance.currentUser == null) {
        // Menemukan detail login tersimpan tetapi Firebase tidak memiliki pengguna saat ini
        // Ini berarti persistensi Firebase mungkin mengalami masalah
        print(
          "Menemukan login tersimpan tetapi tidak ada pengguna Firebase Auth - mencoba memulihkan sesi",
        );
        if (mounted) {
          setState(() {
            _foundSavedUser = true;
          });
        }
      }
    } catch (e) {
      print("Error checking saved login: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error while checking login status: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingPrefs = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Jika ada kesalahan, tampilkan
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Terjadi kesalahan pada aplikasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('Kembali ke Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Jika masih memeriksa preferensi, tampilkan loading
    if (_checkingPrefs) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Jika SharedPreferences mengatakan pengguna telah login tetapi Firebase Auth tidak memiliki pengguna saat ini,
    // kita dapat langsung mengirim pengguna ke halaman Beranda daripada ke halaman Login lagi
    if (_foundSavedUser) {
      print(
        "SharedPreferences menyatakan pengguna telah login, menampilkan HomePage",
      );
      return const HomePage();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        try {
          print(
            "Status auth berubah: hasData=${snapshot.hasData}, connectionState=${snapshot.connectionState}",
          );

          // Periksa jika ada kesalahan
          if (snapshot.hasError) {
            print("Kesalahan stream Auth: ${snapshot.error}");
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Kesalahan otentikasi: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Text('Kembali ke Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Tampilkan loading saat menunggu status otentikasi
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Jika ada user yang sudah login
          if (snapshot.hasData && snapshot.data != null) {
            User user = snapshot.data!;
            print(
              "Pengguna terautentikasi: ${user.email}, emailVerified=${user.emailVerified}",
            );

            // Pastikan email sudah diverifikasi
            if (user.emailVerified) {
              print("Navigasi ke HomePage");
              return const HomePage();
            } else {
              print("Email belum diverifikasi, keluar");
              // Sign out jika email belum diverifikasi
              FirebaseAuth.instance.signOut();
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Email belum diverifikasi'),
                      ElevatedButton(
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            ),
                        child: const Text('Kembali ke Login'),
                      ),
                    ],
                  ),
                ),
              );
            }
          }

          // Jika tidak ada user yang login
          print(
            "Tidak ada pengguna yang terautentikasi, menampilkan LoginPage",
          );
          return const LoginPage();
        } catch (e) {
          print("Kesalahan di AuthWrapper: $e");
          // Jika terjadi kesalahan selama rendering, tampilkan halaman login
          return const LoginPage();
        }
      },
    );
  }
}

// Halaman Beranda
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<List<Map<String, dynamic>>> getRankKampus() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('pendonor').get();
      final kampusCount = <String, int>{};
      for (var doc in snapshot.docs) {
        final kampus = doc['kampus'] ?? '';
        if (kampus.isNotEmpty) {
          kampusCount[kampus] = (kampusCount[kampus] ?? 0) + 1;
        }
      }

      final list =
          kampusCount.entries
              .map((e) => {'kampus': e.key, 'jumlah': e.value})
              .toList();

      list.sort(
        (a, b) => ((b['jumlah'] is int ? b['jumlah'] : 0) as int).compareTo(
          (a['jumlah'] is int ? a['jumlah'] : 0) as int,
        ),
      );

      return list;
    } catch (e) {
      print('Error getRankKampus: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> imgList = [
      'assets/images/slides1.png',
      'assets/images/slides2.png',
      'assets/images/slides3.png',
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Image.asset(
          'assets/logofinblood/logofinblood.png',
          height: 40,
          fit: BoxFit.contain,
        ),
        backgroundColor: const Color(0xFF6C1022),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              try {
                // Tampilkan dialog konfirmasi
                final bool confirmLogout =
                    await showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Center(
                              child: Text(
                                'Konfirmasi Keluar',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6C1022),
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            content: const Text(
                              'Apakah Anda yakin ingin keluar dari aplikasi?',
                            ),
                            actions: [
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(false),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(color: Color(0xFF6C1022)),
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    () => Navigator.of(context).pop(true),
                                child: const Text(
                                  'Keluar',
                                  style: TextStyle(
                                    color: Color(0xFF6C1022),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    ) ??
                    false;

                if (!confirmLogout) return;

                // Hapus shared preferences
                SharedPreferences prefs = await SharedPreferences.getInstance();
                // Pertahankan flag onboarding untuk menghindari menampilkan onboarding lagi
                bool onboardingCompleted =
                    prefs.getBool('onboarding_completed') ?? false;
                await prefs.clear(); // Hapus semua data, bukan hanya flag login
                await prefs.setBool(
                  'onboarding_completed',
                  onboardingCompleted,
                ); // Kembalikan flag onboarding
                print(
                  "Data login dihapus dari SharedPreferences tetapi status onboarding dipertahankan",
                );

                // Keluar dari Firebase
                await FirebaseAuth.instance.signOut();
                print("Pengguna keluar dari Firebase");

                // Untuk pembersihan yang lebih menyeluruh, buat ulang instance Firebase
                try {
                  await Firebase.initializeApp(
                    options: DefaultFirebaseOptions.currentPlatform,
                  );
                  print("Menginisialisasi ulang aplikasi Firebase");
                } catch (reinitError) {
                  print(
                    "Kesalahan saat menginisialisasi ulang Firebase: $reinitError",
                  );
                  // Lanjutkan meskipun inisialisasi ulang gagal
                }

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (Route<dynamic> route) => false,
                  );
                }
              } catch (e) {
                print("Kesalahan saat logout: $e");
                // Bahkan jika ada kesalahan, coba navigasi kembali ke login
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (Route<dynamic> route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bagian atas yang tidak dapat di-scroll
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF6C1022),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FutureBuilder<User?>(
                  future: Future.value(FirebaseAuth.instance.currentUser),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    // Nama default
                    String nama = 'Pengguna';

                    return FutureBuilder<SharedPreferences>(
                      future: SharedPreferences.getInstance(),
                      builder: (context, prefsSnapshot) {
                        if (prefsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildWelcomeText('Pengguna');
                        }

                        if (prefsSnapshot.hasData) {
                          // Coba dapatkan nama dari SharedPreferences terlebih dahulu
                          String? savedName = prefsSnapshot.data!.getString(
                            'userName',
                          );
                          if (savedName != null && savedName.isNotEmpty) {
                            nama =
                                savedName.split(
                                  ' ',
                                )[0]; // Ambil nama depan saja
                            return _buildWelcomeText(nama);
                          }
                        }

                        // Jika tidak ada nama di SharedPreferences, coba Firebase Auth
                        if (snapshot.hasData) {
                          final user = snapshot.data!;

                          // Coba dapatkan dari displayName Firebase Auth
                          if (user.displayName != null &&
                              user.displayName!.isNotEmpty) {
                            nama = user.displayName!.split(' ')[0];
                            return _buildWelcomeText(nama);
                          } else {
                            // Jika tidak ada di Auth, coba dapatkan dari Firestore
                            return FutureBuilder<DocumentSnapshot>(
                              future:
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .get(),
                              builder: (context, userSnapshot) {
                                if (userSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return _buildWelcomeText(
                                    'Pengguna',
                                  ); // Sementara tampilkan "Pengguna"
                                }

                                if (userSnapshot.hasData &&
                                    userSnapshot.data!.exists) {
                                  final userData =
                                      userSnapshot.data!.data()
                                          as Map<String, dynamic>?;
                                  if (userData != null &&
                                      userData['nama'] != null) {
                                    final namaLengkap =
                                        userData['nama'].toString();
                                    // Ambil nama depan saja
                                    nama = namaLengkap.split(' ')[0];
                                  }
                                }

                                return _buildWelcomeText(nama);
                              },
                            );
                          }
                        }

                        return _buildWelcomeText(nama);
                      },
                    );
                  },
                ),
                const SizedBox(height: 0),
                SizedBox(
                  width: 272,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DaftarPendonorListPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Lihat Daftar Pendonor',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(272, 51),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                      ),
                      backgroundColor: const Color(0xFFCA4A63),
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: 272,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DaftarPendonorPage(),
                        ),
                      );
                    },
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: const Text(
                        'Daftar Menjadi Pendonor',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(272, 51),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                      ),
                      backgroundColor: const Color(0xFFCA4A63),
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(50)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Bagian carousel yang tidak dapat di-scroll
          CarouselSection(imgList: imgList),
          const SizedBox(height: 10),

          // Header bagian ranking kampus
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Kampus Pendonor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Hanya bagian ranking kampus yang dapat di-scroll
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: getRankKampus(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Gagal memuat data rangking kampus: ${snapshot.error}',
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                    );
                  }
                  final data = snapshot.data ?? [];
                  if (data.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/images/listempty.png',
                              height: 150,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'Belum ada pendonor.',
                              style: TextStyle(fontFamily: 'Poppins'),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: data.length,
                    itemBuilder: (context, i) {
                      return CardRankKampus(
                        namaKampus: data[i]['kampus'],
                        jumlahPendonor: data[i]['jumlah'],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeText(String nama) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Text(
          'Selamat Datang $nama!',
          textAlign: TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class CarouselSection extends StatefulWidget {
  final List<String> imgList;
  const CarouselSection({super.key, required this.imgList});

  @override
  State<CarouselSection> createState() => _CarouselSectionState();
}

class _CarouselSectionState extends State<CarouselSection> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 352,
          height: 155,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CarouselSlider(
              items:
                  widget.imgList
                      .map(
                        (item) => Image.asset(
                          item,
                          fit: BoxFit.cover,
                          width: 352,
                          height: 155,
                        ),
                      )
                      .toList(),
              options: CarouselOptions(
                height: 155,
                viewportFraction: 1.0,
                enlargeCenterPage: false,
                onPageChanged: (index, reason) {
                  setState(() {
                    _current = index;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              widget.imgList.asMap().entries.map((entry) {
                return Container(
                  width: 12.0,
                  height: 12.0,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _current == entry.key
                            ? const Color(0xFF6C1022)
                            : Colors.grey[300],
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }
}

class CardRankKampus extends StatelessWidget {
  final String namaKampus;
  final int jumlahPendonor;

  const CardRankKampus({
    super.key,
    required this.namaKampus,
    required this.jumlahPendonor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF6C1022),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/logokampus/$namaKampus.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) =>
                        const Icon(Icons.school, size: 40, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                namaKampus,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  jumlahPendonor.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'pendonor',
                  style: TextStyle(fontSize: 13, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Kelas ini dibutuhkan untuk referensi di kode
class DaftarPendonorListPage extends StatefulWidget {
  const DaftarPendonorListPage({super.key});

  @override
  State<DaftarPendonorListPage> createState() => _DaftarPendonorListPageState();
}

class _DaftarPendonorListPageState extends State<DaftarPendonorListPage> {
  String _filterKampus = '__ALL__';
  String _filterGolongan = '__ALL__';

  final List<String> kampusList = [
    'Universitas Udayana',
    'Universitas Pendidikan Ganesha',
    'Institut Seni Indonesia Denpasar',
    'Politeknik Negeri Bali',
    'Universitas Mahendradatta',
    'Universitas Ngurah Rai',
    'Universitas Mahasaraswati Denpasar',
    'Universitas Pendidikan Nasional',
    'Universitas Dwijendra',
    'Universitas Tabanan',
    'Universitas Warmadewa',
    'Universitas Panji Sakti',
    'Universitas Hindu Indonesia',
    'Universitas Teknologi Indonesia',
    'Universitas Dhyana Pura',
    'Universitas Bali Dwipa',
    'Universitas Triatma Mulya',
    'Universitas Bali Internasional',
    'Universitas PGRI Mahadewa Indonesia',
  ];

  final List<String> golonganList = ['A', 'B', 'O', 'AB'];

  // Fungsi untuk memanggil nomor telepon
  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri telUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        print("Tidak dapat melakukan panggilan ke nomor: $phoneNumber");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat melakukan panggilan ke $phoneNumber'),
            ),
          );
        }
      }
    } catch (e) {
      print("Error saat memanggil: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: const Text(
          'Daftar Pendonor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF6C1022),
        centerTitle: true,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      extendBodyBehindAppBar: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF6C1022),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField2<String>(
                    value: _filterKampus,
                    isExpanded: true,
                    style: const TextStyle(
                      color: Color(0xFF6C1022),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '__ALL__',
                        child: Text(
                          'Semua Kampus',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      ),
                      ...kampusList.map(
                        (kampus) => DropdownMenuItem(
                          value: kampus,
                          child: Text(
                            kampus,
                            style: const TextStyle(
                              color: Color(0xFF6C1022),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged:
                        (val) =>
                            setState(() => _filterKampus = val ?? '__ALL__'),
                    decoration: InputDecoration(
                      labelText: 'Filter Kampus',
                      labelStyle: const TextStyle(
                        color: Color(0xFF6C1022),
                        fontFamily: 'Poppins',
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Color(0xFF6C1022),
                          width: 2.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Color(0xFF6C1022),
                          width: 2.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2.0,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2.5,
                        ),
                      ),
                      errorStyle: const TextStyle(color: Colors.red),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      maxHeight: 500,
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField2<String>(
                    value: _filterGolongan,
                    isExpanded: true,
                    style: const TextStyle(
                      color: Color(0xFF6C1022),
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Poppins',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '__ALL__',
                        child: Text(
                          'Semua Golongan',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                      ),
                      ...golonganList.map(
                        (gol) => DropdownMenuItem(
                          value: gol,
                          child: Text(
                            gol,
                            style: const TextStyle(
                              color: Color(0xFF6C1022),
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged:
                        (val) =>
                            setState(() => _filterGolongan = val ?? '__ALL__'),
                    decoration: InputDecoration(
                      labelText: 'Filter Golongan Darah',
                      labelStyle: const TextStyle(
                        color: Color(0xFF6C1022),
                        fontFamily: 'Poppins',
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Color(0xFF6C1022),
                          width: 2.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Color(0xFF6C1022),
                          width: 2.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2.0,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(15),
                        ),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2.5,
                        ),
                      ),
                      errorStyle: const TextStyle(color: Colors.red),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      maxHeight: 300,
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pendonor',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(
                    height:
                        600, // Tinggi yang cukup untuk menampilkan beberapa item
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('pendonor')
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Terjadi error: ${snapshot.error}',
                              style: const TextStyle(fontFamily: 'Poppins'),
                            ),
                          );
                        }
                        var docs = snapshot.data?.docs ?? [];
                        // Filter di memory
                        if (_filterKampus != '__ALL__') {
                          docs =
                              docs
                                  .where(
                                    (doc) => doc['kampus'] == _filterKampus,
                                  )
                                  .toList();
                        }
                        if (_filterGolongan != '__ALL__') {
                          docs =
                              docs
                                  .where(
                                    (doc) =>
                                        doc['golongan_darah'] ==
                                        _filterGolongan,
                                  )
                                  .toList();
                        }
                        if (docs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 60.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Center(
                                  child: Image.asset(
                                    'assets/images/listempty.png',
                                    height: 150,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Center(
                                  child: Text(
                                    'Belum ada pendonor',
                                    style: TextStyle(fontFamily: 'Poppins'),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder:
                              (context, i) => const SizedBox(height: 7),
                          itemBuilder: (context, i) {
                            final data = docs[i].data();
                            final String nomorHP = data['nomor_hp'] ?? '-';
                            return Card(
                              color: const Color(0xFF6C1022),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.white,
                                                fontFamily: 'Poppins',
                                              ),
                                              children: [
                                                TextSpan(
                                                  text:
                                                      (data['nama'] ?? '-') +
                                                      ' - ',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                                TextSpan(
                                                  text:
                                                      data['golongan_darah'] ??
                                                      '-',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                    fontFamily: 'Poppins',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 0),
                                          Text(
                                            data['kampus'] ?? '-',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
                                              fontFamily: 'Poppins',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Tombol telepon
                                    nomorHP != '-'
                                        ? IconButton(
                                          icon: const Icon(
                                            Icons.phone,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                          onPressed:
                                              () => _makePhoneCall(nomorHP),
                                        )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Kelas ini tidak digunakan sekarang tetapi diperlukan untuk _DaftarPendonorPageState
class DaftarPendonorPage extends StatefulWidget {
  const DaftarPendonorPage({super.key});

  @override
  State<DaftarPendonorPage> createState() => _DaftarPendonorPageState();
}

class _DaftarPendonorPageState extends State<DaftarPendonorPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _hpController = TextEditingController();
  String? _selectedKampus;
  String? _selectedGolongan;

  final List<String> kampusList = [
    'Universitas Udayana',
    'Universitas Pendidikan Ganesha',
    'Institut Seni Indonesia Denpasar',
    'Politeknik Negeri Bali',
    'Universitas Mahendradatta',
    'Universitas Ngurah Rai',
    'Universitas Mahasaraswati Denpasar',
    'Universitas Pendidikan Nasional',
    'Universitas Dwijendra',
    'Universitas Tabanan',
    'Universitas Warmadewa',
    'Universitas Panji Sakti',
    'Universitas Hindu Indonesia',
    'Universitas Teknologi Indonesia',
    'Universitas Dhyana Pura',
    'Universitas Bali Dwipa',
    'Universitas Triatma Mulya',
    'Universitas Bali Internasional',
    'Universitas PGRI Mahadewa Indonesia',
  ];

  final List<String> golonganList = ['A', 'B', 'O', 'AB'];

  @override
  void dispose() {
    _namaController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
      // Validasi tambahan untuk mencegah nilai null atau kosong
      final nama = _namaController.text.trim();
      final nomorHP = _hpController.text.trim();
      final kampus = _selectedKampus;
      final golonganDarah = _selectedGolongan;

      if (nama.isEmpty ||
          nomorHP.isEmpty ||
          kampus == null ||
          golonganDarah == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua field harus diisi dengan benar'),
            ),
          );
        }
        return;
      }

      await FirebaseFirestore.instance.collection('pendonor').add({
        'nama': nama,
        'nomor_hp': nomorHP,
        'kampus': kampus,
        'golongan_darah': golonganDarah,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pendaftaran berhasil!')));
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error _submitForm: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mendaftar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: const Text(
          'Daftar Menjadi Pendonor',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF6C1022),
        centerTitle: true,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      extendBodyBehindAppBar: false,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF6C1022),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Lengkap',
                      style: TextStyle(
                        color: Color(0xFF6C1022),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _namaController,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.0,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.5,
                          ),
                        ),
                        errorStyle: const TextStyle(color: Colors.red),
                      ),
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Nama wajib diisi'
                                  : null,
                      style: const TextStyle(
                        color: Color(0xFF6C1022),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nomor HP',
                      style: TextStyle(
                        color: Color(0xFF6C1022),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _hpController,
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.0,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.5,
                          ),
                        ),
                        errorStyle: const TextStyle(color: Colors.red),
                      ),
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Nomor HP wajib diisi'
                                  : null,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        color: Color(0xFF6C1022),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih Kampus',
                      style: TextStyle(
                        color: Color(0xFF6C1022),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField2<String>(
                      value: _selectedKampus,
                      items:
                          kampusList
                              .map(
                                (kampus) => DropdownMenuItem(
                                  value: kampus,
                                  child: Text(
                                    kampus,
                                    style: const TextStyle(
                                      color: Color(0xFF6C1022),
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => _selectedKampus = val),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.0,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.5,
                          ),
                        ),
                        errorStyle: const TextStyle(color: Colors.red),
                      ),
                      validator:
                          (value) =>
                              value == null ? 'Kampus wajib dipilih' : null,
                      dropdownStyleData: DropdownStyleData(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        maxHeight: 400,
                      ),
                      menuItemStyleData: const MenuItemStyleData(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF6C1022),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih Golongan Darah',
                      style: TextStyle(
                        color: Color(0xFF6C1022),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField2<String>(
                      value: _selectedGolongan,
                      items:
                          golonganList
                              .map(
                                (gol) => DropdownMenuItem(
                                  value: gol,
                                  child: Text(
                                    gol,
                                    style: const TextStyle(
                                      color: Color(0xFF6C1022),
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged:
                          (val) => setState(() => _selectedGolongan = val),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.0,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2.5,
                          ),
                        ),
                        errorStyle: const TextStyle(color: Colors.red),
                      ),
                      validator:
                          (value) =>
                              value == null
                                  ? 'Golongan darah wajib dipilih'
                                  : null,
                      dropdownStyleData: DropdownStyleData(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        maxHeight: 300,
                      ),
                      menuItemStyleData: const MenuItemStyleData(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF6C1022),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 36),
                    Center(
                      child: SizedBox(
                        width: 183,
                        height: 51,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C1022),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          child: const Text(
                            'DAFTAR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
