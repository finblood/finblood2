import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'pendonor_bersedia_page.dart';

class AdminSearchDonorPage extends StatefulWidget {
  const AdminSearchDonorPage({super.key});

  @override
  State<AdminSearchDonorPage> createState() => _AdminSearchDonorPageState();
}

class _AdminSearchDonorPageState extends State<AdminSearchDonorPage> {
  String? selectedKampus;
  String? selectedGolDarah;

  List<String> kampusList = [];
  List<String> golDarahList = ['A', 'B', 'AB', 'O'];

  @override
  void initState() {
    super.initState();
    _loadKampusList();
  }

  Future<void> _loadKampusList() async {
    try {
      // Use the same kampus list as DaftarPendonorListPage
      final List<String> predefinedKampusList = [
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

      setState(() {
        kampusList = predefinedKampusList;
      });
    } catch (e) {
      print('Error loading kampus list: $e');
    }
  }

  void _showNotificationDialog(int count) {
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Kirim Permintaan Donor',
                style: TextStyle(
                  color: Color(0xFF6C1022),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aplikasi akan mengirim permintaan donor darah ke $count pendonor:',
                  ),
                  const SizedBox(height: 8),
                  if (selectedKampus != null) Text('• Kampus: $selectedKampus'),
                  if (selectedGolDarah != null)
                    Text('• Golongan Darah: $selectedGolDarah'),
                  if (selectedKampus == null && selectedGolDarah == null)
                    const Text('• Semua pendonor'),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Color(0xFF6C1022)),
                  ),
                ),
                TextButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            setState(() {
                              isLoading = true;
                            });

                            try {
                              await _sendNotificationToBackend(
                                selectedKampus,
                                selectedGolDarah,
                              );

                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Permintaan donor berhasil dikirim ke $count pendonor!',
                                    ),
                                    backgroundColor: Color(0xFF6C1022),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setState(() {
                                  isLoading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                  child: const Text(
                    'Kirim Permintaan',
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
            );
          },
        );
      },
    );
  }

  Future<void> _sendNotificationToBackend(
    String? kampus,
    String? golonganDarah,
  ) async {
    try {
      // URL Cloud Function - ganti dengan URL Firebase Functions Anda
      // Format: https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net/sendAdminNotification
      const String cloudFunctionUrl =
          'https://us-central1-fin-blood-2.cloudfunctions.net/sendAdminNotification';

      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kampus': kampus,
          'golonganDarah': golonganDarah,
          'secretKey': 'finblood-dev-key-2024',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Donor request sent successfully: $responseData');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to send donor request');
      }
    } catch (e) {
      print('Error sending donor request: $e');
      throw Exception('Gagal mengirim permintaan donor: $e');
    }
  }

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
          'Cari Pendonor',
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
      body: Column(
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
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField2<String>(
                  value: selectedKampus,
                  isExpanded: true,
                  style: const TextStyle(
                    color: Color(0xFF6C1022),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
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
                  onChanged: (val) {
                    setState(() => selectedKampus = val);
                  },
                  decoration: InputDecoration(
                    labelText: 'Filter Kampus',
                    labelStyle: const TextStyle(
                      color: Color(0xFF6C1022),
                      fontFamily: 'Poppins',
                    ),
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
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2.0,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(15)),
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
                  value: selectedGolDarah,
                  isExpanded: true,
                  style: const TextStyle(
                    color: Color(0xFF6C1022),
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'Semua Golongan',
                        style: TextStyle(fontFamily: 'Poppins'),
                      ),
                    ),
                    ...golDarahList.map(
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
                  onChanged: (val) {
                    setState(() => selectedGolDarah = val);
                  },
                  decoration: InputDecoration(
                    labelText: 'Filter Golongan Darah',
                    labelStyle: const TextStyle(
                      color: Color(0xFF6C1022),
                      fontFamily: 'Poppins',
                    ),
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
                      borderSide: const BorderSide(
                        color: Colors.red,
                        width: 2.0,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(Radius.circular(15)),
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
              ],
            ),
          ),
          const SizedBox(height: 1),

          // Send Notification Button - moved here after filters
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance.collection('pendonor').snapshots(),
            builder: (context, snapshot) {
              var docs = snapshot.data?.docs ?? [];

              // Apply same filters as the main list
              if (selectedKampus != null) {
                docs =
                    docs
                        .where((doc) => doc['kampus'] == selectedKampus)
                        .toList();
              }
              if (selectedGolDarah != null) {
                docs =
                    docs
                        .where(
                          (doc) => doc['golongan_darah'] == selectedGolDarah,
                        )
                        .toList();
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Tombol Kirim Permintaan Donor
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            docs.isEmpty
                                ? null
                                : () => _showNotificationDialog(docs.length),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Kirim Permintaan Donor (${docs.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 51),
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
                    // Tombol Pendonor Yang Bersedia
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const PendonorBersediaPage(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volunteer_activism, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Pendonor Yang Bersedia',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 51),
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
              );
            },
          ),

          // Header bagian pendonor
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pendonor',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: Colors.black,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ),

          // Results Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection('pendonor')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
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
                  if (selectedKampus != null) {
                    docs =
                        docs
                            .where((doc) => doc['kampus'] == selectedKampus)
                            .toList();
                  }
                  if (selectedGolDarah != null) {
                    docs =
                        docs
                            .where(
                              (doc) =>
                                  doc['golongan_darah'] == selectedGolDarah,
                            )
                            .toList();
                  }

                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/emptybw.png',
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum ada pendonor',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF757575),
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 7),
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
                              colors: [Color(0xFF6C1022), Color(0xFFD21F42)],
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
                                                  (data['nama'] ?? '-') + ' - ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                fontFamily: 'Poppins',
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  data['golongan_darah'] ?? '-',
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
                                      onPressed: () => _makePhoneCall(nomorHP),
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
          ),
        ],
      ),
    );
  }
}
