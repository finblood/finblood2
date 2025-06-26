import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'main.dart' show DaftarPendonorListPage;
import 'konfirmasi_bersedia_page.dart';
import 'admin_utils.dart';

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage>
    with WidgetsBindingObserver {
  final Map<String, bool> _responseCache = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up periodic refresh to catch any missed responses
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _responseCache.clear();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Clear cache when app resumes to ensure fresh response detection
    if (state == AppLifecycleState.resumed) {
      _responseCache.clear();
      // Force rebuild to trigger fresh response detection
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          toolbarHeight: 66,
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
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh Notifikasi',
              onPressed: () {
                _responseCache.clear();
                setState(() {});
              },
            ),
          ],
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
            const Expanded(child: Center(child: Text('Pengguna belum login'))),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh Notifikasi',
            onPressed: () {
              _responseCache.clear();
              setState(() {});
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: false,
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => _showDeleteAllNotificationsDialog(context, currentUser.uid),
        backgroundColor: const Color(0xFF6C1022),
        foregroundColor: Colors.white,
        tooltip: 'Hapus Semua Notifikasi',
        shape: const CircleBorder(),
        child: const Icon(Icons.delete_sweep, size: 24),
      ),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .collection('notifications')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
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
                          'assets/images/emptybw.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum ada notifikasi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Notifikasi akan muncul di sini ketika ada\npermintaan donor dari admin',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                            fontFamily: 'Poppins',
                          ),
                          textAlign: TextAlign.center,
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
                    final Timestamp? timestamp =
                        data['timestamp'] as Timestamp?;
                    final notificationId = docs[i].id;
                    final notificationType = data['type'] ?? 'admin_message';

                    return _buildNotificationCard(
                      context,
                      data,
                      timestamp,
                      notificationId,
                      notificationType,
                      currentUser.uid,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    Map<String, dynamic> data,
    Timestamp? timestamp,
    String notificationId,
    String notificationType,
    String userId,
  ) {
    // Check immediate response status from notification data
    final directlyResponded = data['responded'] == true;

    if (directlyResponded) {
      // If directly marked as responded, show immediately
      return _buildCardWidget(
        context,
        data,
        timestamp,
        notificationId,
        notificationType,
        true, // hasResponded = true
      );
    }

    // For donor requests, check response status with StreamBuilder for realtime updates
    if (notificationType == 'donor_request') {
      return StreamBuilder<bool>(
        stream: _getResponseStatusStream(notificationId, userId),
        initialData: _responseCache[notificationId] ?? false,
        builder: (context, responseSnapshot) {
          final hasResponded = responseSnapshot.data ?? false;

          // Update cache
          _responseCache[notificationId] = hasResponded;

          return _buildCardWidget(
            context,
            data,
            timestamp,
            notificationId,
            notificationType,
            hasResponded,
          );
        },
      );
    }

    // For admin messages, no response checking needed
    return _buildCardWidget(
      context,
      data,
      timestamp,
      notificationId,
      notificationType,
      false, // hasResponded = false for admin messages
    );
  }

  Widget _buildCardWidget(
    BuildContext context,
    Map<String, dynamic> data,
    Timestamp? timestamp,
    String notificationId,
    String notificationType,
    bool hasResponded,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          gradient:
              hasResponded
                  ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF6C1022).withOpacity(0.5),
                      const Color(0xFFD21F42).withOpacity(0.5),
                    ],
                  )
                  : const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF6C1022), Color(0xFFD21F42)],
                  ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap:
              hasResponded
                  ? null
                  : () async {
                    // Check notification type and navigate accordingly
                    if (notificationType == 'donor_request') {
                      // Navigate to konfirmasi bersedia page for donor requests
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => KonfirmasiBersediaPage(
                                golonganDarah: data['filter_golongan_darah'],
                                notificationId: notificationId,
                              ),
                        ),
                      );

                      // Clear cache for this notification when returning
                      // to ensure fresh response detection
                      _responseCache.remove(notificationId);

                      // Force refresh this specific notification by clearing all cache
                      // This ensures all notifications are re-evaluated for their response status
                      _responseCache.clear();

                      // Force refresh this specific notification
                      if (mounted) {
                        setState(() {});
                      }
                    } else {
                      // For admin messages, check if user is admin
                      final isAdmin = await AdminUtils.isCurrentUserAdmin();
                      if (isAdmin) {
                        // Admin can navigate to donor list page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const DaftarPendonorListPage(),
                          ),
                        );
                      } else {
                        // For regular users, show info message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ini adalah pesan informasi dari admin',
                            ),
                            backgroundColor: Color(0xFF6C1022),
                          ),
                        );
                      }
                    }
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
                          data['type'] == 'donor_request'
                              ? Icons.volunteer_activism
                              : Icons.notifications_rounded,
                          color:
                              hasResponded
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 14,
                          ),
                          decoration: BoxDecoration(
                            color:
                                data['type'] == 'donor_request'
                                    ? (hasResponded
                                        ? const Color(
                                          0xFFCA4A63,
                                        ).withOpacity(0.7)
                                        : const Color(0xFFCA4A63))
                                    : (hasResponded
                                        ? const Color(
                                          0xFFCA4A63,
                                        ).withOpacity(0.7)
                                        : const Color(0xFFCA4A63)),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            data['type'] == 'donor_request'
                                ? 'Permintaan Donor'
                                : 'Pesan Admin',
                            style: TextStyle(
                              color:
                                  hasResponded
                                      ? Colors.white.withOpacity(0.8)
                                      : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasResponded && notificationType == 'donor_request'
                          ? 'Anda sudah mengkonfirmasi'
                          : (data['type'] == 'donor_request'
                              ? 'Permintaan donor darah darurat. Apakah Anda bersedia untuk mendonor?'
                              : data['message'] ?? 'Pesan tidak tersedia'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color:
                            hasResponded
                                ? Colors.white.withOpacity(0.8)
                                : Colors.white,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            hasResponded
                                ? Colors.white.withOpacity(0.6)
                                : Colors.white70,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasResponded)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 13.0),
                      child: Transform.rotate(
                        angle: 3.1416,
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              if (hasResponded && notificationType == 'donor_request')
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Stream<bool> _getResponseStatusStream(String notificationId, String userId) {
    // Simplified stream that only monitors the notification document itself
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .snapshots()
        .asyncMap((notificationSnapshot) async {
          try {
            // First check if notification is directly marked as responded
            if (notificationSnapshot.exists) {
              final notificationData = notificationSnapshot.data();
              if (notificationData?['responded'] == true) {
                _responseCache[notificationId] = true;
                return true;
              }
            }

            // If not directly marked, do a simple check without complex queries
            // Check pendonor_bersedia for exact notification_id match only
            final bersediaQuery =
                await FirebaseFirestore.instance
                    .collection('pendonor_bersedia')
                    .where('user_id', isEqualTo: userId)
                    .where('notification_id', isEqualTo: notificationId)
                    .limit(1)
                    .get();

            if (bersediaQuery.docs.isNotEmpty) {
              await _markNotificationAsRespondedFromStream(
                notificationSnapshot,
                'bersedia',
              );
              _responseCache[notificationId] = true;
              return true;
            }

            // Check donor_responses for exact notification_id match only
            final responsesQuery =
                await FirebaseFirestore.instance
                    .collection('donor_responses')
                    .where('user_id', isEqualTo: userId)
                    .where('notification_id', isEqualTo: notificationId)
                    .limit(1)
                    .get();

            if (responsesQuery.docs.isNotEmpty) {
              final response =
                  responsesQuery.docs.first.data()['response'] ??
                  'tidak_bersedia';
              await _markNotificationAsRespondedFromStream(
                notificationSnapshot,
                response,
              );
              _responseCache[notificationId] = true;
              return true;
            }

            // No response found
            _responseCache[notificationId] = false;
            return false;
          } catch (e) {
            print('Error in response status stream for $notificationId: $e');
            return _responseCache[notificationId] ?? false;
          }
        })
        .distinct(); // Only emit when value changes
  }

  // Helper function to mark notification as responded from stream
  Future<void> _markNotificationAsRespondedFromStream(
    DocumentSnapshot notificationSnapshot,
    String response,
  ) async {
    try {
      if (notificationSnapshot.exists) {
        await notificationSnapshot.reference.update({
          'responded': true,
          'response': response,
          'response_timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error auto-marking notification: $e');
    }
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

  // Fungsi untuk menampilkan dialog konfirmasi hapus semua notifikasi
  Future<void> _showDeleteAllNotificationsDialog(
    BuildContext context,
    String userId,
  ) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Center(
              child: Text(
                'Hapus Semua Notifikasi',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C1022),
                  fontSize: 20,
                ),
              ),
            ),
            content: const Text(
              'Apakah Anda yakin ingin menghapus semua notifikasi? Tindakan ini tidak dapat dibatalkan.',
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
        // Hapus semua dokumen di collection notifications user
        final batch = FirebaseFirestore.instance.batch();
        final querySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('notifications')
                .get();

        for (var doc in querySnapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Semua notifikasi berhasil dihapus!'),
              backgroundColor: Color(0xFF6C1022),
            ),
          );
        }
      } catch (e) {
        print('Error deleting all notifications: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus notifikasi: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
