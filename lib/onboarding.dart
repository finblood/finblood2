import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final int _numPages = 2;

  @override
  void initState() {
    super.initState();
    // Mengatur warna status bar menjadi transparan dan ikon status bar menjadi putih
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    // Mengembalikan warna status bar ke default
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  final List<Map<String, String>> _onboardingData = [
    {'title': 'Selamat Datang di Finblood'},
    {'title': 'Daftar Sebagai Pendonor'},
  ];

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
    );
  }

  void _completeOnboarding() async {
    // Menyimpan status onboarding sudah selesai
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (context.mounted) {
      // Navigasi ke halaman login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Memperluas body ke belakang appBar
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white, // Warna background default
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _numPages,
                itemBuilder: (context, index) {
                  return OnboardingItem(
                    title: _onboardingData[index]['title']!,
                    onNextPage: _nextPage,
                    onPreviousPage: _previousPage,
                    onComplete: _completeOnboarding,
                    isSecondSlide: index == 1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingItem extends StatelessWidget {
  final String title;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onComplete;
  final bool isSecondSlide;

  const OnboardingItem({
    super.key,
    required this.title,
    required this.onNextPage,
    required this.onPreviousPage,
    required this.onComplete,
    this.isSecondSlide = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFirstSlide = !isSecondSlide;

    return Stack(
      children: [
        // Background merah
        Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color(0xFF6C1022),
        ),

        // Konten utama
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bagian atas dengan padding
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.067,
                      ),
                    ),
                    SizedBox(height: isFirstSlide ? 52 : 63),
                    isFirstSlide
                        ? Image.asset(
                          'assets/onboarding/onboarding3d1.png',
                          height: 305,
                          fit: BoxFit.contain,
                        )
                        : Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20.0),
                            child: Image.asset(
                              'assets/onboarding/onboarding3d2.png',
                              height: 294,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),

            // Container box di bagian bawah
            Container(
              height: 262,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Text(
                      isFirstSlide
                          ? "Finblood adalah aplikasi yang memudahkan pengguna untuk mencari pendonor darah yang sesuai dengan kebutuhan pengguna"
                          : "Pengguna juga dapat mendaftarkan diri sebagai pendonor di aplikasi Finblood",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color.fromARGB(255, 0, 0, 0),
                        height: 1.2,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),

                  // Tombol next (kanan bawah)
                  Padding(
                    padding: const EdgeInsets.only(right: 40, bottom: 48),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 74,
                            height: 74,
                            child: ElevatedButton(
                              onPressed:
                                  isSecondSlide ? onComplete : onNextPage,
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                backgroundColor: const Color(0xFF6C1022),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                          // Hanya tampilkan teks 'Mulai' pada slide kedua
                          if (isSecondSlide) const SizedBox(height: 0),
                          if (isSecondSlide)
                            const Text(
                              "Mulai",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Tombol previous (kiri bawah) - hanya untuk slide kedua
                  if (isSecondSlide)
                    Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 50),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 74,
                              height: 74,
                              alignment: Alignment.center,
                              child: IconButton(
                                onPressed: onPreviousPage,
                                icon: const Icon(
                                  Icons.chevron_left,
                                  color: Color(0xFF6C1022),
                                  size: 36,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                            const SizedBox(height: 26),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
