import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_utils.dart'; // Import admin utilities

// Halaman Detail Pendonor
class DetailPendonorPage extends StatelessWidget {
  final Map<String, dynamic> donorData;
  final String donorId;

  const DetailPendonorPage({
    super.key,
    required this.donorData,
    required this.donorId,
  });

  // Fungsi untuk memanggil nomor telepon
  Future<void> _makePhoneCall(String phoneNumber, BuildContext context) async {
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

  // Fungsi untuk menambahkan riwayat donor (khusus admin)
  Future<void> _addDonationHistory(BuildContext context) async {
    final TextEditingController locationController = TextEditingController();
    final TextEditingController notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Center(
                child: Text(
                  'Tambah Riwayat Donor',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6C1022),
                    fontSize: 20,
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date picker
                    ListTile(
                      title: const Text(
                        'Tanggal Donor',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6C1022),
                          fontFamily: 'Poppins',
                        ),
                      ),
                      subtitle: Text(
                        '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF6C1022),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF6C1022),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null && picked != selectedDate) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Location input
                    TextFormField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'Lokasi Donor',
                        hintText: 'Contoh: PMI Denpasar, RS Sanglah',
                        labelStyle: const TextStyle(
                          color: Color(0xFF6C1022),
                          fontFamily: 'Poppins',
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.0,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 16),

                    // Notes input
                    TextFormField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Catatan tambahan tentang donasi...',
                        labelStyle: const TextStyle(
                          color: Color(0xFF6C1022),
                          fontFamily: 'Poppins',
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF6C1022),
                            width: 2.0,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Poppins'),
                    ),
                  ],
                ),
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
                  onPressed: () async {
                    if (locationController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lokasi donor harus diisi'),
                          backgroundColor: Color(0xFF6C1022),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text(
                    'Simpan',
                    style: TextStyle(
                      color: Color(0xFF6C1022),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      try {
        // Add donation history to Firestore
        await FirebaseFirestore.instance
            .collection('pendonor')
            .doc(donorId)
            .collection('riwayat_donor')
            .add({
              'tanggal_donor': Timestamp.fromDate(selectedDate),
              'lokasi': locationController.text.trim(),
              'catatan': notesController.text.trim(),
              'created_at': FieldValue.serverTimestamp(),
              'created_by': 'admin', // You can get actual admin ID here
            });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Riwayat donor berhasil ditambahkan!'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
      } catch (e) {
        print('Error adding donation history: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menambahkan riwayat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    // Dispose controllers
    locationController.dispose();
    notesController.dispose();
  }

  // Fungsi untuk menghapus riwayat donor
  Future<void> _deleteDonationHistory(
    BuildContext context,
    String historyId,
  ) async {
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
              'Apakah Anda yakin ingin menghapus riwayat donor ini?',
              style: TextStyle(fontFamily: 'Poppins'),
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
            .collection('riwayat_donor')
            .doc(historyId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Riwayat donor berhasil dihapus!'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
      } catch (e) {
        print('Error deleting donation history: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus riwayat: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String nama = donorData['nama'] ?? 'Tidak diketahui';
    final String nomorHP = donorData['nomor_hp'] ?? '-';
    final String kampus = donorData['kampus'] ?? 'Tidak diketahui';
    final String golonganDarah =
        donorData['golongan_darah'] ?? 'Tidak diketahui';
    final dynamic timestamp = donorData['timestamp'];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: const Text(
          'Detail Pendonor',
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
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header dengan nama dan golongan darah
                  const SizedBox(height: 5),

                  // Detail informasi
                  Card(
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
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informasi Detail',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 16),

                            _buildDetailRow('Nama Lengkap', nama),
                            const SizedBox(height: 12),

                            _buildDetailRow('Nomor HP', nomorHP),
                            const SizedBox(height: 12),

                            _buildDetailRow('Kampus', kampus),
                            const SizedBox(height: 12),

                            _buildDetailRow('Golongan Darah', golonganDarah),
                            const SizedBox(height: 12),

                            _buildDetailRow(
                              'Tanggal Daftar',
                              _formatTimestamp(timestamp),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tombol aksi
                  if (nomorHP != '-' && nomorHP.isNotEmpty)
                    Center(
                      child: SizedBox(
                        width: 272,
                        child: ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(nomorHP, context),
                          icon: const Icon(
                            Icons.phone,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            'Hubungi $nama',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(272, 51),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontFamily: 'Poppins',
                            ),
                            backgroundColor: const Color(0xFF6C1022),
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(50),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 5),

                  // Riwayat Donor Section
                  _buildDonationHistorySection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        const Text(
          ': ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Poppins',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ],
    );
  }

  // Widget untuk section riwayat donor
  Widget _buildDonationHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Donor',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontFamily: 'Poppins',
              ),
            ),
            // Tombol tambah riwayat (hanya untuk admin)
            FutureBuilder<bool>(
              future: AdminUtils.isCurrentUserAdmin(),
              builder: (context, snapshot) {
                final isAdmin = snapshot.data ?? false;
                if (!isAdmin) return const SizedBox.shrink();

                return IconButton(
                  onPressed: () => _addDonationHistory(context),
                  icon: const Icon(
                    Icons.add_circle,
                    color: Color(0xFF6C1022),
                    size: 28,
                  ),
                  tooltip: 'Tambah Riwayat Donor',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 5),

        // StreamBuilder untuk riwayat donor
        StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('pendonor')
                  .doc(donorId)
                  .collection('riwayat_donor')
                  .orderBy('tanggal_donor', descending: true)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Color(0xFF6C1022)),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.bloodtype_outlined,
                      size: 64,
                      color: Colors.grey[400],
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
                    FutureBuilder<bool>(
                      future: AdminUtils.isCurrentUserAdmin(),
                      builder: (context, snapshot) {
                        final isAdmin = snapshot.data ?? false;
                        if (!isAdmin) return const SizedBox.shrink();

                        return const Text(
                          'Klik tombol + untuk menambah riwayat donor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF999999),
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ],
                ),
              );
            }

            return Column(
              children:
                  docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final tanggalDonor = data['tanggal_donor'] as Timestamp?;
                    final lokasi = data['lokasi'] ?? 'Lokasi tidak diketahui';
                    final catatan = data['catatan'] ?? '';

                    return _buildDonationHistoryCard(
                      doc.id,
                      tanggalDonor,
                      lokasi,
                      catatan,
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  // Widget untuk card riwayat donor individual
  Widget _buildDonationHistoryCard(
    String historyId,
    Timestamp? tanggalDonor,
    String lokasi,
    String catatan,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF6C1022), Color(0xFFD21F42)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon dan tanggal
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(Icons.bloodtype, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),

            // Informasi donor
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTimestamp(tanggalDonor),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lokasi,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  if (catatan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      catatan,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tombol hapus (hanya untuk admin)
            FutureBuilder<bool>(
              future: AdminUtils.isCurrentUserAdmin(),
              builder: (context, snapshot) {
                final isAdmin = snapshot.data ?? false;
                if (!isAdmin) return const SizedBox.shrink();

                return IconButton(
                  onPressed: () => _deleteDonationHistory(context, historyId),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Hapus Riwayat',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
