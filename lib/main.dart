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
import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:cached_network_image/cached_network_image.dart'; // Added for CachedNetworkImage
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // Added for DefaultCacheManager
import 'package:flutter/services.dart'; // Added for SystemUiOverlayStyle and AnnotatedRegion
// Impor untuk notifikasi
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Impor FCM
import 'notifikasi_page.dart'; // Impor halaman notifikasi

// Fungsi top-level untuk menangani tap notifikasi di background
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // handle action
  print('Notification tapped in background: ${notificationResponse.payload}');
  // Anda bisa menyimpan payload atau melakukan aksi lain di sini
  // yang akan diproses ketika aplikasi dibuka.
}

// GlobalKey untuk NavigatorState agar bisa navigasi dari luar Widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Handler untuk pesan FCM saat aplikasi di background/terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Jika Anda akan menggunakan plugin lain di sini (seperti Firebase.initializeApp), pastikan Flutter sudah terinisialisasi.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Mungkin perlu jika ada inisialisasi Firebase lain di sini
  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');
  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification}');
    // Di sini kita bisa menampilkan notifikasi lokal jika diperlukan,
    // tapi biasanya FCM menangani ini untuk background messages di Android.
    // Untuk iOS, atau jika ingin kustomisasi penuh, Anda bisa tampilkan notifikasi lokal.
  }
}

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
        print("Firebase berhasil di inisialisasikan");

        // Setup FCM
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        // (Opsional) Dapatkan token FCM - bagus untuk debug atau direct messaging
        // String? token = await FirebaseMessaging.instance.getToken();
        // print("FCM Token: $token");
      } catch (e) {
        print("Error initializing Firebase or FCM: $e");
        // Tetap lanjutkan aplikasi meskipun Firebase/FCM gagal
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
      navigatorKey: navigatorKey, // Set navigatorKey di sini
      title: 'Finblood',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        fontFamily: 'Poppins',
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Color(0xFFE88094),
          cursorColor: Color(0xFFCA4A63),
          selectionHandleColor: Color(0xFFCA4A63),
        ),
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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Menampilkan splash screen minimal 1 detik
      final stopwatch = Stopwatch()..start();

      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;

      // Jika onboarding belum selesai, langsung ke onboarding
      if (!onboardingCompleted) {
        // Pastikan splash screen tampil minimal 1 detik
        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed < 1000) {
          await Future.delayed(Duration(milliseconds: 1000 - elapsed));
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingPage()),
          );
        }
        return;
      }

      // Onboarding sudah selesai, lakukan authentication check
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final currentUser = FirebaseAuth.instance.currentUser;

      // Tentukan tujuan navigation berdasarkan status auth
      Widget targetPage;

      if (isLoggedIn && currentUser != null && currentUser.emailVerified) {
        // User sudah login dan email verified
        targetPage = const HomePage();
      } else if (isLoggedIn && currentUser == null) {
        // Ada saved login tapi tidak ada Firebase user (session expired)
        targetPage =
            const HomePage(); // Bisa tetap ke HomePage atau LoginPage sesuai preferensi
      } else {
        // User belum login atau email belum verified
        if (currentUser != null && !currentUser.emailVerified) {
          // Sign out jika email belum diverifikasi
          await FirebaseAuth.instance.signOut();
        }
        targetPage = const LoginPage();
      }

      // Pastikan splash screen tampil minimal 1 detik
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 1000) {
        await Future.delayed(Duration(milliseconds: 1000 - elapsed));
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (context) => targetPage));
      }
    } catch (e) {
      print("Error during app initialization: $e");

      // Jika ada error, tunggu minimal 1 detik lalu ke login
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
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
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        try {
          // Periksa jika ada kesalahan
          if (snapshot.hasError) {
            print("Kesalahan stream Auth: ${snapshot.error}");
            return Scaffold(
              backgroundColor: const Color(
                0xFF6C1022,
              ), // Background sama dengan splash
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Kesalahan otentikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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

          // Tampilkan loading dengan background yang sama dengan splash
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: const Color(
                0xFF6C1022,
              ), // Background sama dengan splash
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/logofinblood/logofinblood.png',
                      width: 200,
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ),
              ),
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
                backgroundColor: const Color(0xFF6C1022),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Email belum diverifikasi',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            () => Navigator.pushReplacement(
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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeLocalNotifications();
    _initializeFCM();
    _getUnreadCount();
  }

  Future<void> _getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpened = prefs.getInt('last_opened_notifikasi') ?? 0;
    final snapshot =
        await FirebaseFirestore.instance
            .collection('pendonor')
            .orderBy('timestamp', descending: true)
            .get();
    int count = 0;
    for (var doc in snapshot.docs) {
      final ts = doc['timestamp'];
      if (ts is Timestamp && ts.millisecondsSinceEpoch > lastOpened) {
        count++;
      }
    }
    setState(() {
      _unreadCount = count;
    });
  }

  Future<void> _initializeLocalNotifications() async {
    // Ganti nama fungsi agar lebih jelas
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (
        NotificationResponse notificationResponse,
      ) {
        // Modifikasi handler untuk notifikasi lokal
        print(
          'Local notification tapped with payload: ${notificationResponse.payload}',
        );
        if (notificationResponse.payload != null &&
            notificationResponse.payload!.isNotEmpty) {
          try {
            final Map<String, dynamic> payloadData = jsonDecode(
              notificationResponse.payload!,
            );
            _handleNavigationFromNotification(payloadData);
          } catch (e) {
            print(
              'Error decoding payload for local notification navigation: $e',
            );
          }
        }
      },
    );
  }

  void _handleNavigationFromNotification(Map<String, dynamic> data) {
    print("Handling navigation for data: $data");
    final screen = data['screen'];
    if (screen == 'DaftarPendonorListPage') {
      // Pastikan navigatorKey.currentContext tidak null
      if (navigatorKey.currentContext != null) {
        Navigator.push(
          navigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (context) => const DaftarPendonorListPage(),
          ),
        );
      } else {
        print("navigatorKey.currentContext is null, cannot navigate");
        // Anda bisa menyimpan data navigasi ini dan melakukannya saat context tersedia
      }
    }
    // Tambahkan kondisi lain jika ada halaman lain untuk dinavigasi
  }

  // Fungsi baru untuk inisialisasi FCM di HomePageState
  Future<void> _initializeFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Meminta izin notifikasi (iOS & Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission for FCM notifications');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission for FCM notifications');
    } else {
      print(
        'User declined or has not accepted permission for FCM notifications',
      );
    }

    // Subscribe ke topik untuk tes
    try {
      await FirebaseMessaging.instance.subscribeToTopic('pendonor_baru');
      print('Berhasil subscribe ke topik: pendonor_baru');
    } catch (e) {
      print('Gagal subscribe ke topik: pendonor_baru. Error: $e');
    }

    // (Opsional) Refresh token jika berubah
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('FCM Token refreshed: $newToken');
      // Kirim token baru ini ke server aplikasi Anda jika diperlukan
    });

    // Listener untuk pesan FCM saat aplikasi di foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null) {
        print(
          'Message also contained a notification: ${notification.title} - ${notification.body}',
        );
        // Tampilkan notifikasi lokal menggunakan flutter_local_notifications
        // agar konsisten dan bisa dikustomisasi
        flutterLocalNotificationsPlugin.show(
          notification.hashCode, // ID unik untuk notifikasi
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'finblood_fcm_channel', // ID channel baru untuk FCM
              'Finblood FCM Notifications',
              channelDescription: 'Notifikasi FCM dari aplikasi Finblood',
              icon:
                  'ic_stat_finblood_logo', // Menggunakan ikon notifikasi khusus
              importance: Importance.max,
              priority: Priority.high,
              color: const Color(0xFF6C1022), // Tambahkan warna ini
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data), // Kirim data pesan sebagai payload
        );
      }
    });

    // Listener untuk ketika pengguna membuka aplikasi dari notifikasi (saat background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      print('Message data: ${message.data}');
      _handleNavigationFromNotification(message.data);
    });

    // Periksa apakah aplikasi dibuka dari notifikasi yang di-tap saat terminated
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from a terminated state via FCM message!');
      print('Initial message data: ${initialMessage.data}');
      _handleNavigationFromNotification(initialMessage.data);
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
          tooltip: 'Notifikasi',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotifikasiPage()),
            );
          },
        ),
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
                bottomLeft: Radius.circular(25),
                bottomRight: Radius.circular(25),
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
          const CarouselSection(),
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
  const CarouselSection({super.key});

  @override
  State<CarouselSection> createState() => _CarouselSectionState();
}

class _CarouselSectionState extends State<CarouselSection> {
  int _current = 0;
  List<Map<String, dynamic>> _carouselItems = [];
  bool _isLoading =
      true; // Initially true until cache or Firestore load finishes
  String? _error;
  Timestamp? _localLastUpdated; // To store the timestamp of the cached data

  static const String _carouselCacheKey = 'carousel_data_cache';
  static const String _carouselTimestampKey = 'carousel_timestamp_cache';

  @override
  void initState() {
    super.initState();
    _loadCarouselData();
  }

  Future<void> _loadCarouselData() async {
    await _loadCarouselFromPrefs(); // Try to load from cache first
    _checkForCarouselUpdates(); // Then check Firestore for updates
  }

  Future<void> _loadCarouselFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedDataJson = prefs.getString(_carouselCacheKey);
      final int? cachedTimestampMillis = prefs.getInt(_carouselTimestampKey);

      if (cachedDataJson != null && cachedTimestampMillis != null) {
        final List<dynamic> decodedList = jsonDecode(cachedDataJson);
        final List<Map<String, dynamic>> cachedItems =
            decodedList.map((item) => item as Map<String, dynamic>).toList();

        if (mounted) {
          setState(() {
            _carouselItems = cachedItems;
            _localLastUpdated = Timestamp(
              cachedTimestampMillis ~/ 1000,
              (cachedTimestampMillis % 1000) * 1000000,
            );
            _isLoading =
                false; // Loaded from cache, no longer "initial" loading
            if (_carouselItems.isNotEmpty) {
              _initiateImageDownloads(_carouselItems);
            }
          });
          print("Carousel data loaded from cache.");
        }
      } else {
        print("No carousel data found in cache.");
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
        // If no cache, ensure isLoading remains true or is set true if called separately
        if (mounted && _carouselItems.isEmpty) {
          // only set isLoading if we truly have nothing
          setState(() {
            _isLoading = true;
          });
        }
      }
    } catch (e) {
      print("Error loading carousel from prefs: $e");
      // If cache loading fails, proceed to fetch from Firestore
      if (mounted && _carouselItems.isEmpty) {
        setState(() {
          _isLoading = true;
        });
      }
    }
  }

  Future<void> _saveCarouselToPrefs(
    List<Map<String, dynamic>> items,
    Timestamp firestoreTimestamp,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(items);
      await prefs.setString(_carouselCacheKey, jsonString);
      await prefs.setInt(
        _carouselTimestampKey,
        firestoreTimestamp.millisecondsSinceEpoch,
      );
      print("Carousel data saved to cache.");
      if (mounted) {
        setState(() {
          _localLastUpdated = firestoreTimestamp;
        });
      }
    } catch (e) {
      print("Error saving carousel to prefs: $e");
    }
  }

  Future<void> _checkForCarouselUpdates() async {
    try {
      // Fetch the lastUpdated timestamp from Firestore metadata
      print(
        "[FIRESTORE CHECK] Current _localLastUpdated (from cache): $_localLastUpdated",
      );

      final metadataDoc =
          await FirebaseFirestore.instance
              .collection('carousel_metadata')
              .doc('version_info')
              .get();

      Timestamp? firestoreLastUpdated;
      if (metadataDoc.exists &&
          metadataDoc.data() != null &&
          metadataDoc.data()!.containsKey('lastUpdated')) {
        firestoreLastUpdated = metadataDoc.data()!['lastUpdated'] as Timestamp?;
      }

      print(
        "[FIRESTORE CHECK] Fetched firestoreLastUpdated: $firestoreLastUpdated",
      );

      if (firestoreLastUpdated == null) {
        print(
          "[FIRESTORE CHECK] Carousel version_info document or lastUpdated field not found in Firestore.",
        );
        // If no version info, and no cache, show error or handle as "no data"
        if (_carouselItems.isEmpty && mounted) {
          setState(() {
            _error = 'Carousel configuration missing.';
            _isLoading = false;
          });
        } else if (mounted) {
          // If we have cached items, we'll just use them.
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      bool needsUpdate =
          _localLastUpdated == null ||
          firestoreLastUpdated.compareTo(_localLastUpdated!) > 0;

      print("[FIRESTORE CHECK] Does it need update? $needsUpdate");
      if (_localLastUpdated == null) {
        print("[FIRESTORE CHECK] Reason: Local cache timestamp is null.");
      } else if (firestoreLastUpdated.compareTo(_localLastUpdated!) > 0) {
        print(
          "[FIRESTORE CHECK] Reason: Firestore timestamp (${firestoreLastUpdated.toDate()}) is newer than local cache (${_localLastUpdated!.toDate()}).",
        );
      } else {
        print(
          "[FIRESTORE CHECK] Reason: Local cache timestamp (${_localLastUpdated!.toDate()}) is current or newer than Firestore (${firestoreLastUpdated.toDate()}).",
        );
      }

      if (needsUpdate) {
        print(
          "[FIRESTORE CHECK] Carousel update found or no local cache. Fetching from Firestore...",
        );
        await _fetchCarouselImagesFromFirestore(firestoreLastUpdated);
      } else {
        print(
          "[FIRESTORE CHECK] Carousel data is up to date (from cache or confirmed with Firestore).",
        );
        if (mounted) {
          setState(() {
            _isLoading = false; // Data is up-to-date, stop loading
            if (_carouselItems.isEmpty && _error == null) {
              // If cache was empty but firestore says up-to-date
              _error =
                  'No images found.'; // This implies Firestore has no items either
            }
          });
        }
      }
    } catch (e) {
      print("Error checking for carousel updates: $e");
      if (mounted) {
        setState(() {
          // If an error occurs, and we don't have cached items, show error.
          // Otherwise, rely on potentially stale cache.
          if (_carouselItems.isEmpty) {
            _error = 'Failed to check for updates.';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCarouselImagesFromFirestore(
    Timestamp newFirestoreTimestamp,
  ) async {
    if (mounted) {
      setState(() {
        _isLoading = true; // Explicitly set loading true when fetching
      });
    }
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('carousel_images')
              .orderBy('order')
              .get();

      List<Map<String, dynamic>> fetchedItems = [];
      if (snapshot.docs.isNotEmpty) {
        fetchedItems =
            snapshot.docs
                .map((doc) {
                  final data = doc.data();
                  return {
                    'url': data['url'] as String?,
                    'actionType': data['actionType'] as String?,
                    'actionValue': data['actionValue'] as String?,
                  };
                })
                .where((item) => item['url'] != null && item['url']!.isNotEmpty)
                .toList()
                .cast<Map<String, dynamic>>();
      }

      if (mounted) {
        setState(() {
          _carouselItems = fetchedItems;
          _error = fetchedItems.isEmpty ? 'No images found.' : null;
          _isLoading = false;
        });
        await _saveCarouselToPrefs(fetchedItems, newFirestoreTimestamp);
        if (fetchedItems.isNotEmpty) {
          _initiateImageDownloads(fetchedItems);
        }
      }
    } catch (e) {
      print('Error fetching carousel images from Firestore: $e');
      if (mounted) {
        setState(() {
          if (_carouselItems.isEmpty) {
            // Only set error if we couldn't fall back to cache
            _error = 'Failed to load images.';
          }
          _isLoading = false;
        });
      }
    }
  }

  // New method to initiate downloads using DefaultCacheManager
  Future<void> _initiateImageDownloads(
    List<Map<String, dynamic>> itemsToDownload,
  ) async {
    if (!mounted || itemsToDownload.isEmpty) return;

    print(
      "[CacheManager] Initiating background downloads for ${_carouselItems.length} images.",
    );
    List<Future<void>> downloadFutures = [];

    for (var itemData in itemsToDownload) {
      final String? imageUrl = itemData['url'];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Using try-catch for individual downloads to prevent one failure from stopping others
        downloadFutures.add(
          DefaultCacheManager()
              .downloadFile(imageUrl)
              .then((_) {
                print(
                  "[CacheManager] Successfully initiated download (or file exists) for: $imageUrl",
                );
              })
              .catchError((e, s) {
                print(
                  "[CacheManager] Error initiating download for $imageUrl: $e",
                );
              }),
        );
      }
    }
    // We can wait for all to complete if we want, but not strictly necessary for just starting them
    // await Future.wait(downloadFutures);
    // print("[CacheManager] All image download initiations complete.");
  }

  Future<void> _handleCarouselTap(Map<String, dynamic> item) async {
    final String? actionType = item['actionType'];
    final String? actionValue = item['actionValue'];

    if (actionType == null || actionValue == null) {
      print("No action defined for this carousel item.");
      return;
    }

    if (actionType == 'url') {
      final Uri? uri = Uri.tryParse(actionValue);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch $actionValue');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tidak dapat membuka link: $actionValue'),
              backgroundColor: const Color(0xFF6C1022),
            ),
          );
        }
      }
    } else if (actionType == 'route') {
      if (!mounted) return;
      Widget? page;
      if (actionValue == 'DaftarPendonorListPage') {
        page = const DaftarPendonorListPage();
      } else if (actionValue == 'DaftarPendonorPage') {
        page = const DaftarPendonorPage();
      }

      if (page != null) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page!));
      } else {
        print('Unknown route: $actionValue');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Halaman tidak ditemukan: $actionValue'),
            backgroundColor: const Color(0xFF6C1022),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: 352,
        height: 155, // Reverted height, was 180 for debug text
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _carouselItems.isEmpty) {
      return Container(
        width: 352,
        height: 155,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey[300],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _error ?? 'No images available.',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      );
    } else {
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
                    _carouselItems
                        .map(
                          (item) => GestureDetector(
                            onTap: () => _handleCarouselTap(item),
                            child: CachedNetworkImage(
                              imageUrl: item['url']! as String,
                              fit: BoxFit.cover,
                              width: 352,
                              height: 155,
                              fadeInDuration: const Duration(milliseconds: 300),
                              placeholder:
                                  (context, url) => Container(
                                    width: 352,
                                    height: 155,
                                    color: Colors.grey[200],
                                  ),
                              errorWidget: (context, url, error) {
                                print(
                                  'Error loading image with CachedNetworkImage: $url, error: $error',
                                );
                                return Container(
                                  width: 352,
                                  height: 155,
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      color: Colors.red[400],
                                      size: 40,
                                    ),
                                  ),
                                );
                              },
                            ),
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
                _carouselItems.asMap().entries.map((entry) {
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
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFF6C1022), Color(0xFFD21F42)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 16.0),
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
                      (context, error, stackTrace) => const Icon(
                        Icons.school,
                        size: 40,
                        color: Colors.grey,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  namaKampus,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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
              backgroundColor: const Color(0xFF6C1022),
            ),
          );
        }
      }
    } catch (e) {
      print("Error saat memanggil: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFF6C1022),
          ),
        );
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
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
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
                      scrollbarTheme: ScrollbarThemeData(
                        thumbVisibility: MaterialStateProperty.all(true),
                        thickness: MaterialStateProperty.all(6),
                        radius: const Radius.circular(8),
                        thumbColor: MaterialStateProperty.all(
                          const Color(0xFF6C1022),
                        ),
                      ),
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
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFF6C1022),
                                      Color(0xFFD21F42),
                                    ],
                                  ),
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                      fontFamily: 'Poppins',
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text:
                                                        data['golongan_darah'] ??
                                                        '-',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
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

  // Local cache untuk optimasi initial render
  bool?
  _cachedRegistrationStatus; // null = unknown, true = registered, false = not registered
  Map<String, dynamic>? _cachedDonorData;
  String? _cachedDonorId;

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
  void initState() {
    super.initState();
    _loadCachedRegistrationStatus();
  }

  Future<void> _loadCachedRegistrationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final isRegistered = prefs.getBool(
          'donor_registered_${currentUser.uid}',
        );
        final cachedDataString = prefs.getString(
          'donor_data_${currentUser.uid}',
        );
        final cachedId = prefs.getString('donor_id_${currentUser.uid}');

        if (mounted) {
          setState(() {
            _cachedRegistrationStatus = isRegistered;
            if (cachedDataString != null) {
              _cachedDonorData = Map<String, dynamic>.from(
                jsonDecode(cachedDataString) as Map,
              );
            }
            _cachedDonorId = cachedId;
          });
        }
      }
    } catch (e) {
      print('Error loading cached registration status: $e');
    }
  }

  Future<void> _saveRegistrationStatus({
    required bool isRegistered,
    Map<String, dynamic>? donorData,
    String? donorId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        await prefs.setBool(
          'donor_registered_${currentUser.uid}',
          isRegistered,
        );

        if (isRegistered && donorData != null && donorId != null) {
          await prefs.setString(
            'donor_data_${currentUser.uid}',
            jsonEncode(donorData),
          );
          await prefs.setString('donor_id_${currentUser.uid}', donorId);
        } else if (!isRegistered) {
          // Clear cache jika status tidak terdaftar
          await prefs.remove('donor_data_${currentUser.uid}');
          await prefs.remove('donor_id_${currentUser.uid}');
        }
      }
    } catch (e) {
      print('Error saving registration status: $e');
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  Future<void> _deleteDonor(String donorId) async {
    // Tampilkan dialog konfirmasi
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Center(
              child: Text(
                'Konfirmasi Hapus',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C1022),
                  fontSize: 20,
                ),
              ),
            ),
            content: const Text(
              'Apakah Anda yakin ingin menghapus data pendonor Anda?',
              textAlign: TextAlign.left,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Color(0xFF6C1022)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Hapus',
                  style: TextStyle(
                    color: Color(0xFF6C1022),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('pendonor')
            .doc(donorId)
            .delete();

        // Update local cache setelah berhasil hapus
        await _saveRegistrationStatus(isRegistered: false);

        if (mounted) {
          setState(() {
            _cachedRegistrationStatus = false;
            _cachedDonorData = null;
            _cachedDonorId = null;
          });
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data pendonor berhasil dihapus!'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
      } catch (e) {
        print('Error deleting donor: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus data: $e'),
              backgroundColor: const Color(0xFF6C1022),
            ),
          );
        }
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengguna belum login'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
        return;
      }

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
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
        return;
      }

      // Tampilkan dialog konfirmasi
      final bool confirmRegister =
          await showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Center(
                    child: Text(
                      'Konfirmasi Daftar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C1022),
                        fontSize: 20,
                      ),
                    ),
                  ),
                  content: const Text(
                    'Apakah Anda yakin ingin mendaftar menjadi pendonor darah?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Batal',
                        style: TextStyle(color: Color(0xFF6C1022)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Daftar',
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

      if (!confirmRegister) return;

      final docRef = await FirebaseFirestore.instance.collection('pendonor').add(
        {
          'nama': nama,
          'nomor_hp': nomorHP,
          'kampus': kampus,
          'golongan_darah': golonganDarah,
          'user_id':
              user.uid, // Tambahkan user_id untuk menghubungkan dengan pengguna
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      // Data yang baru ditambahkan
      final newDonorData = {
        'nama': nama,
        'nomor_hp': nomorHP,
        'kampus': kampus,
        'golongan_darah': golonganDarah,
        'user_id': user.uid,
      };

      // Update local cache setelah berhasil mendaftar
      await _saveRegistrationStatus(
        isRegistered: true,
        donorData: newDonorData,
        donorId: docRef.id,
      );

      // Update UI state
      if (mounted) {
        setState(() {
          _cachedRegistrationStatus = true;
          _cachedDonorData = newDonorData;
          _cachedDonorId = docRef.id;
        });
      }

      // Clear form setelah berhasil mendaftar
      _namaController.clear();
      _hpController.clear();
      setState(() {
        _selectedKampus = null;
        _selectedGolongan = null;
      });

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pendaftaran berhasil!'),
            backgroundColor: Color(0xFF6C1022),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error _submitForm: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendaftar: $e'),
            backgroundColor: const Color(0xFF6C1022),
          ),
        );
      }
    }
  }

  Widget _buildDonorDataView(Map<String, dynamic> donorData, String donorId) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anda Sudah Mendaftar',
            style: TextStyle(
              color: Color(0xFF6C1022),
              fontWeight: FontWeight.bold,
              fontSize: 18,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 7),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF6C1022), Color(0xFFD21F42)],
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama Lengkap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    donorData['nama'] ?? '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nomor HP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    donorData['nomor_hp'] ?? '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kampus',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    donorData['kampus'] ?? '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Golongan Darah',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    donorData['golongan_darah'] ?? '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 183,
              height: 51,
              child: ElevatedButton(
                onPressed: () => _deleteDonor(donorId),
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
                  'HAPUS',
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
    );
  }

  Widget _buildRegistrationForm() {
    return Padding(
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
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.5),
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
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.5),
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
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.5),
                ),
                errorStyle: const TextStyle(color: Colors.red),
              ),
              validator:
                  (value) => value == null ? 'Kampus wajib dipilih' : null,
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                maxHeight: 400,
                scrollbarTheme: ScrollbarThemeData(
                  thumbVisibility: MaterialStateProperty.all(true),
                  thickness: MaterialStateProperty.all(6),
                  radius: const Radius.circular(8),
                  thumbColor: MaterialStateProperty.all(
                    const Color(0xFF6C1022),
                  ),
                ),
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
              onChanged: (val) => setState(() => _selectedGolongan = val),
              decoration: InputDecoration(
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(
                    color: Color(0xFF6C1022),
                    width: 2.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(15)),
                  borderSide: const BorderSide(color: Colors.red, width: 2.5),
                ),
                errorStyle: const TextStyle(color: Colors.red),
              ),
              validator:
                  (value) =>
                      value == null ? 'Golongan darah wajib dipilih' : null,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

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
            bottomLeft: Radius.circular(25),
            bottomRight: Radius.circular(25),
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
            // Hybrid approach: Cache untuk initial render + StreamBuilder untuk sync
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('pendonor')
                      .where('user_id', isEqualTo: currentUser.uid)
                      .snapshots(),
              builder: (context, snapshot) {
                // Update cache berdasarkan data stream untuk akurasi
                if (snapshot.hasData) {
                  final docs = snapshot.data!.docs;
                  final bool streamIsRegistered = docs.isNotEmpty;

                  // Sync cache dengan data terbaru dari Firestore
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (streamIsRegistered && docs.isNotEmpty) {
                      final doc = docs.first;
                      final donorData = doc.data();
                      final donorId = doc.id;

                      // Update cache jika ada perbedaan
                      if (_cachedRegistrationStatus != true ||
                          _cachedDonorId != donorId) {
                        await _saveRegistrationStatus(
                          isRegistered: true,
                          donorData: donorData,
                          donorId: donorId,
                        );

                        if (mounted) {
                          setState(() {
                            _cachedRegistrationStatus = true;
                            _cachedDonorData = donorData;
                            _cachedDonorId = donorId;
                          });
                        }
                      }
                    } else if (!streamIsRegistered &&
                        _cachedRegistrationStatus == true) {
                      // Data dihapus di Firestore, update cache
                      await _saveRegistrationStatus(isRegistered: false);

                      if (mounted) {
                        setState(() {
                          _cachedRegistrationStatus = false;
                          _cachedDonorData = null;
                          _cachedDonorId = null;
                        });
                      }
                    }
                  });
                }

                // Handle error dari Firestore
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(50.0),
                    child: Center(
                      child: Text(
                        'Terjadi error: ${snapshot.error}',
                        style: const TextStyle(fontFamily: 'Poppins'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Prioritas rendering:
                // 1. Cache data (untuk instant render)
                // 2. Stream data (untuk akurasi)
                // 3. Fallback ke form (jika tidak ada data)

                // Jika ada cache data, gunakan untuk instant render
                if (_cachedRegistrationStatus == true &&
                    _cachedDonorData != null &&
                    _cachedDonorId != null) {
                  return _buildDonorDataView(
                    _cachedDonorData!,
                    _cachedDonorId!,
                  );
                }

                // Jika stream sudah ada data, gunakan stream data
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final doc = snapshot.data!.docs.first;
                  final donorData = doc.data();
                  final donorId = doc.id;
                  return _buildDonorDataView(donorData, donorId);
                }

                // Jika cache menunjukkan tidak terdaftar, atau tidak ada data
                // langsung tampilkan form (no loading)
                return _buildRegistrationForm();
              },
            ),
          ],
        ),
      ),
    );
  }
}
