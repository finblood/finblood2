import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'detail_pendonor_page.dart'; // Import detail pendonor page

class PendonorBersediaPage extends StatefulWidget {
  const PendonorBersediaPage({super.key});

  @override
  State<PendonorBersediaPage> createState() => _PendonorBersediaPageState();
}

class _PendonorBersediaPageState extends State<PendonorBersediaPage> {
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

  // Fungsi untuk navigasi ke detail pendonor
  Future<void> _navigateToDetailPendonor(Map<String, dynamic> donorData) async {
    try {
      // Cari dokumen pendonor berdasarkan user_id
      final String? userId = donorData['user_id'];
      if (userId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data pendonor tidak lengkap'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
        return;
      }

      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('pendonor')
              .where('user_id', isEqualTo: userId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        final donorDoc = querySnapshot.docs.first;
        final donorId = donorDoc.id;
        final mainDonorData = donorDoc.data();

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => DetailPendonorPage(
                    donorData: mainDonorData,
                    donorId: donorId,
                  ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data pendonor tidak ditemukan'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
      }
    } catch (e) {
      print('Error navigating to detail pendonor: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Fungsi untuk menampilkan dialog konfirmasi hapus semua list
  Future<void> _showDeleteAllDialog() async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Center(
              child: Text(
                'Hapus Semua List',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C1022),
                  fontSize: 20,
                ),
              ),
            ),
            content: const Text(
              'Apakah Anda yakin ingin menghapus semua pendonor yang bersedia? Tindakan ini tidak dapat dibatalkan.',
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
                  'Hapus Semua',
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
        // Hapus semua dokumen di collection pendonor_bersedia
        final batch = FirebaseFirestore.instance.batch();
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('pendonor_bersedia')
                .get();

        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua list pendonor bersedia berhasil dihapus!'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
      } catch (e) {
        print('Error deleting all pendonor bersedia: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus list: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: const Text(
          'Pendonor Yang Bersedia',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDeleteAllDialog(),
        backgroundColor: const Color(0xFF6C1022),
        foregroundColor: Colors.white,
        tooltip: 'Hapus Semua List',
        shape: const CircleBorder(),
        child: const Icon(Icons.delete_sweep, size: 24),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pendonor Yang Bersedia',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Daftar pendonor yang bersedia memberikan darah saat ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // StreamBuilder untuk menampilkan data pendonor bersedia
                  SizedBox(
                    height:
                        600, // Tinggi yang cukup untuk menampilkan beberapa item
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('pendonor_bersedia')
                              .orderBy('timestamp_bersedia', descending: true)
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
                                    'Belum Ada Pendonor yang Bersedia',
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
                                    'Kirim notifikasi kepada pendonor untuk\nmelihat siapa yang bersedia melakukan donor.',
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
                            final Timestamp? timestamp =
                                data['timestamp_bersedia'];

                            String timeAgo = '';
                            if (timestamp != null) {
                              final now = DateTime.now();
                              final responseTime = timestamp.toDate();
                              final difference = now.difference(responseTime);

                              if (difference.inMinutes < 60) {
                                timeAgo =
                                    '${difference.inMinutes} menit yang lalu';
                              } else if (difference.inHours < 24) {
                                timeAgo = '${difference.inHours} jam yang lalu';
                              } else {
                                timeAgo = '${difference.inDays} hari yang lalu';
                              }
                            }

                            return InkWell(
                              onTap: () => _navigateToDetailPendonor(data),
                              borderRadius: BorderRadius.circular(15),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
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
                                        Color(0xFF1A5319),
                                        Color(0xFF4CAF50),
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
                                        // Status icon
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.volunteer_activism,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
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
                                                          (data['nama'] ??
                                                              '-') +
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
                                              const SizedBox(height: 2),
                                              Text(
                                                data['kampus'] ?? '-',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontFamily: 'Poppins',
                                                ),
                                              ),
                                              if (timeAgo.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Bersedia $timeAgo',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white70,
                                                    fontFamily: 'Poppins',
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
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
