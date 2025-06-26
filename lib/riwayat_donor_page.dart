import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class RiwayatDonorPage extends StatefulWidget {
  const RiwayatDonorPage({super.key});

  @override
  State<RiwayatDonorPage> createState() => _RiwayatDonorPageState();
}

class _RiwayatDonorPageState extends State<RiwayatDonorPage> {
  String? _currentUserDonorId;
  bool _isLoadingDonorId = true;
  int? _selectedYear; // Filter tahun yang dipilih

  @override
  void initState() {
    super.initState();
    _getCurrentUserDonorId();
  }

  // Fungsi untuk mendapatkan donor ID dari user yang sedang login
  Future<void> _getCurrentUserDonorId() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoadingDonorId = false;
        });
        return;
      }

      // Cari dokumen pendonor berdasarkan user_id
      final donorQuery =
          await FirebaseFirestore.instance
              .collection('pendonor')
              .where('user_id', isEqualTo: currentUser.uid)
              .limit(1)
              .get();

      if (donorQuery.docs.isNotEmpty) {
        setState(() {
          _currentUserDonorId = donorQuery.docs.first.id;
          _isLoadingDonorId = false;
        });
      } else {
        setState(() {
          _currentUserDonorId = null;
          _isLoadingDonorId = false;
        });
      }
    } catch (e) {
      print('Error getting donor ID: $e');
      setState(() {
        _currentUserDonorId = null;
        _isLoadingDonorId = false;
      });
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Tidak diketahui';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Format tanggal tidak valid';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Format tanggal tidak valid';
    }
  }

  Widget _buildDonationHistoryCard(
    Timestamp? tanggalDonor,
    String lokasi,
    String catatan,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 3,
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
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon donor
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.bloodtype,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),

                // Informasi donor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTimestamp(tanggalDonor),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lokasi,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (catatan.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          catatan,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/emptybw.png',
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada riwayat donor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF757575),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Riwayat donor Anda akan muncul di sini\nsetelah admin menambahkannya.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF999999),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotRegisteredState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/emptybw.png',
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 16),
          const Text(
            'Anda belum memiliki riwayat donor darah',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF757575),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Silahkan lakukan donor darah terlebih dahulu untuk melihat riwayat donor',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF999999),
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: const Text(
          'Riwayat Donor Saya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'Poppins',
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
      body: Column(
        children: [
          // Background container
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

          // Content
          Expanded(
            child:
                _isLoadingDonorId
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C1022),
                      ),
                    )
                    : _currentUserDonorId == null
                    ? _buildNotRegisteredState()
                    : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header info
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C1022).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFF6C1022).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: const Color(0xFF6C1022),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Riwayat donor hanya dapat ditambahkan oleh admin. Hubungi admin jika ada riwayat yang belum tercatat.',
                                    style: TextStyle(
                                      color: const Color(0xFF6C1022),
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Year Filter Dropdown
                          StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('pendonor')
                                    .doc(_currentUserDonorId)
                                    .collection('riwayat_donor')
                                    .snapshots(),
                            builder: (context, yearSnapshot) {
                              if (!yearSnapshot.hasData ||
                                  yearSnapshot.data!.docs.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              // Get available years for dropdown
                              final Set<int> availableYears = {};
                              for (var doc in yearSnapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final tanggalDonor =
                                    data['tanggal_donor'] as Timestamp?;
                                if (tanggalDonor != null) {
                                  availableYears.add(
                                    tanggalDonor.toDate().year,
                                  );
                                }
                              }

                              final sortedYears =
                                  availableYears.toList()
                                    ..sort((a, b) => b.compareTo(a));

                              return Column(
                                children: [
                                  DropdownButtonFormField2<int>(
                                    value: _selectedYear,
                                    isExpanded: true,
                                    style: const TextStyle(
                                      color: Color(0xFF6C1022),
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                    items: [
                                      const DropdownMenuItem<int>(
                                        value: null,
                                        child: Text(
                                          'Semua Tahun',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                      ),
                                      ...sortedYears.map(
                                        (year) => DropdownMenuItem<int>(
                                          value: year,
                                          child: Text(
                                            'Tahun $year',
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
                                      setState(() {
                                        _selectedYear = val;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      labelText: 'Filter Tahun',
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
                                    ),
                                    dropdownStyleData: DropdownStyleData(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    menuItemStyleData: const MenuItemStyleData(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            },
                          ),

                          // List riwayat donor
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('pendonor')
                                      .doc(_currentUserDonorId)
                                      .collection('riwayat_donor')
                                      .orderBy(
                                        'tanggal_donor',
                                        descending: true,
                                      )
                                      .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF6C1022),
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 60,
                                            color: Colors.red[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Terjadi kesalahan saat memuat riwayat donor',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.red[600],
                                              fontFamily: 'Poppins',
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                var docs = snapshot.data?.docs ?? [];

                                // Filter berdasarkan tahun yang dipilih
                                if (_selectedYear != null) {
                                  docs =
                                      docs.where((doc) {
                                        final data =
                                            doc.data() as Map<String, dynamic>;
                                        final tanggalDonor =
                                            data['tanggal_donor'] as Timestamp?;
                                        if (tanggalDonor != null) {
                                          return tanggalDonor.toDate().year ==
                                              _selectedYear;
                                        }
                                        return false;
                                      }).toList();
                                }

                                if (docs.isEmpty) {
                                  return _buildEmptyState();
                                }

                                return ListView.builder(
                                  itemCount: docs.length,
                                  itemBuilder: (context, index) {
                                    final data =
                                        docs[index].data()
                                            as Map<String, dynamic>;
                                    final tanggalDonor =
                                        data['tanggal_donor'] as Timestamp?;
                                    final lokasi =
                                        data['lokasi'] ??
                                        'Lokasi tidak diketahui';
                                    final catatan = data['catatan'] ?? '';

                                    return _buildDonationHistoryCard(
                                      tanggalDonor,
                                      lokasi,
                                      catatan,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
