import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart' show DaftarPendonorListPage;

class NotifikasiPage extends StatelessWidget {
  const NotifikasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('pendonor')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Gagal memuat notifikasi.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/listempty.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada notifikasi',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: docs.length,
            separatorBuilder: (context, i) => const SizedBox(height: 7),
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final Timestamp? timestamp = data['timestamp'] as Timestamp?;
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
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DaftarPendonorListPage(),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 13,
                            horizontal: 16.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.notifications_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCA4A63),
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: const Text(
                                      'Pendonor Baru',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: (data['nama'] ?? '-') + ' - ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    TextSpan(
                                      text: data['golongan_darah'] ?? '-',
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
                              const SizedBox(height: 6),
                              Text(
                                _formatTimestamp(timestamp),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 13.0),
                              child: Transform.rotate(
                                angle: 3.1416,
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Baru saja';
    final DateTime notificationTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(notificationTime);
    if (difference.inSeconds < 5) {
      return 'Baru saja';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds} detik lalu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} menit lalu';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} jam lalu';
    } else {
      return '${difference.inDays} hari lalu';
    }
  }
}
