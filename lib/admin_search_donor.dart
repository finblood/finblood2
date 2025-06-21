import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:url_launcher/url_launcher.dart';

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

  void _resetFilters() {
    setState(() {
      selectedKampus = null;
      selectedGolDarah = null;
    });
  }

  void _showNotificationDialog(int count) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Kirim Notifikasi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Akan mengirim notifikasi ke $count pendonor:'),
              const SizedBox(height: 8),
              if (selectedKampus != null) Text('• Kampus: $selectedKampus'),
              if (selectedGolDarah != null)
                Text('• Golongan Darah: $selectedGolDarah'),
              if (selectedKampus == null && selectedGolDarah == null)
                const Text('• Semua pendonor'),
              const SizedBox(height: 16),
              const Text(
                'Fitur ini masih dalam pengembangan.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifikasi berhasil dikirim! (Demo)'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C1022),
                foregroundColor: Colors.white,
              ),
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
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
          const SizedBox(height: 16),

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
                child: ElevatedButton.icon(
                  onPressed:
                      docs.isEmpty
                          ? null
                          : () => _showNotificationDialog(docs.length),
                  icon: const Icon(Icons.notifications_active),
                  label: Text('Kirim Notifikasi (${docs.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCA4A63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF757575),
                                fontFamily: 'Poppins',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
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
