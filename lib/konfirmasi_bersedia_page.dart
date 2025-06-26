import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KonfirmasiBersediaPage extends StatefulWidget {
  final String? golonganDarah;
  final String? notificationId;

  const KonfirmasiBersediaPage({
    super.key,
    this.golonganDarah,
    this.notificationId,
  });

  @override
  State<KonfirmasiBersediaPage> createState() => _KonfirmasiBersediaPageState();
}

class _KonfirmasiBersediaPageState extends State<KonfirmasiBersediaPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _donorData;

  @override
  void initState() {
    super.initState();
    _loadDonorData();
  }

  Future<void> _loadDonorData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get donor data from pendonor collection
      final snapshot =
          await FirebaseFirestore.instance
              .collection('pendonor')
              .where('user_id', isEqualTo: user.uid)
              .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _donorData = snapshot.docs.first.data();
        });
      }
    } catch (e) {
      print('Error loading donor data: $e');
    }
  }

  Future<void> _handleResponse(bool isBersedia) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User tidak terautentikasi');
      }

      // Get donor data first
      final donorSnapshot =
          await FirebaseFirestore.instance
              .collection('pendonor')
              .where('user_id', isEqualTo: user.uid)
              .get();

      if (donorSnapshot.docs.isEmpty) {
        throw Exception('Data pendonor tidak ditemukan');
      }

      final donorDoc = donorSnapshot.docs.first;
      final donorData = donorDoc.data();
      final donorId = donorDoc.id;

      // Use notificationId if provided, otherwise generate a unique response ID
      final responseNotificationId =
          widget.notificationId ??
          '${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      if (isBersedia) {
        // Add to pendonor_bersedia collection
        await FirebaseFirestore.instance.collection('pendonor_bersedia').add({
          'donor_id': donorId,
          'user_id': user.uid,
          'nama': donorData['nama'],
          'nomor_hp': donorData['nomor_hp'],
          'kampus': donorData['kampus'],
          'golongan_darah': donorData['golongan_darah'],
          'timestamp_bersedia': FieldValue.serverTimestamp(),
          'notification_id': responseNotificationId,
          'status': 'bersedia',
        });

        // Update user document to mark as currently willing
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'current_donor_status': 'bersedia',
              'last_availability_response': FieldValue.serverTimestamp(),
            });
      } else {
        // Record the decline response
        await FirebaseFirestore.instance.collection('donor_responses').add({
          'donor_id': donorId,
          'user_id': user.uid,
          'notification_id': responseNotificationId,
          'response': 'tidak_bersedia',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'current_donor_status': 'tidak_bersedia',
              'last_availability_response': FieldValue.serverTimestamp(),
            });
      }

      // ALWAYS mark notification as responded - regardless of access method
      await _markNotificationAsResponded(
        user.uid,
        widget.notificationId,
        isBersedia ? 'bersedia' : 'tidak_bersedia',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBersedia
                  ? 'Terima kasih! Anda sudah dikonfirmasi sebagai pendonor yang bersedia.'
                  : 'Terima kasih atas responsnya.',
            ),
            backgroundColor: const Color(0xFF6C1022),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Navigate back after response
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error handling response: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Enhanced function to mark notification as responded in the user's notification collection
  Future<void> _markNotificationAsResponded(
    String userId,
    String? notificationId,
    String response,
  ) async {
    try {
      bool marked = false;

      // If we have a specific notificationId, try to mark it directly first
      if (notificationId != null) {
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId);

        final notificationDoc = await notificationRef.get();

        if (notificationDoc.exists) {
          // Direct match found, update it
          await notificationRef.update({
            'responded': true,
            'response': response,
            'response_timestamp': FieldValue.serverTimestamp(),
          });
          print(
            'Notification $notificationId marked as responded with: $response',
          );
          marked = true;
        }
      }

      // Only if direct marking failed, try to find and mark the most recent unresponded notification
      // This handles cases where notification ID might not match (e.g., push notification scenarios)
      if (!marked) {
        await _markMostRecentUnrespondedNotification(userId, response);
      }
    } catch (e) {
      print('Error marking notification as responded: $e');
      // Non-critical error, don't throw
    }
  }

  // Function to mark only the MOST RECENT unresponded donor notification
  Future<void> _markMostRecentUnrespondedNotification(
    String userId,
    String response,
  ) async {
    try {
      // Get all notifications (simple query, no complex index needed)
      final allNotifications =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .get();

      if (allNotifications.docs.isNotEmpty) {
        // Find the most recent unresponded donor_request notification
        DocumentSnapshot? mostRecentUnresponded;
        DateTime? mostRecentTime;

        for (var notificationDoc in allNotifications.docs) {
          final notificationData =
              notificationDoc.data() as Map<String, dynamic>;
          final notificationType = notificationData['type'];
          final hasResponded = notificationData['responded'] == true;
          final timestamp = notificationData['timestamp'] as Timestamp?;

          // Only consider donor_request notifications that haven't been responded to
          if (notificationType == 'donor_request' &&
              !hasResponded &&
              timestamp != null) {
            final notificationTime = timestamp.toDate();

            // Check if this is the most recent one
            if (mostRecentTime == null ||
                notificationTime.isAfter(mostRecentTime)) {
              mostRecentTime = notificationTime;
              mostRecentUnresponded = notificationDoc;
            }
          }
        }

        // Mark only the most recent unresponded notification
        if (mostRecentUnresponded != null) {
          await mostRecentUnresponded.reference.update({
            'responded': true,
            'response': response,
            'response_timestamp': FieldValue.serverTimestamp(),
          });
          print(
            'Marked most recent unresponded notification ${mostRecentUnresponded.id} as responded',
          );
        }
      }
    } catch (e) {
      print('Error finding most recent unresponded notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final golonganDarah =
        widget.golonganDarah ??
        _donorData?['golongan_darah'] ??
        'tidak diketahui';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        title: const Text(
          'Konfirmasi Kesediaan Donor',
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
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon donor darah
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C1022).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(60),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism,
                      size: 60,
                      color: Color(0xFF6C1022),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Pesan utama
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFF6C1022), Color(0xFFD21F42)],
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Permintaan Donor Darah',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text:
                                      'Seseorang membutuhkan darah dengan golongan darah ',
                                ),
                                TextSpan(
                                  text: golonganDarah.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Apakah kamu bersedia untuk melakukan donor darah saat ini?',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Tombol respons
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        // Tombol Bersedia
                        SizedBox(
                          width: 272,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleResponse(true),
                            icon: const Icon(Icons.check_circle),
                            label: const Text(
                              'Ya, Saya Bersedia',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(272, 51),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontFamily: 'Poppins',
                              ),
                              backgroundColor: const Color(0xFF4CAF50),
                              foregroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(50),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Tombol Tidak Bersedia
                        SizedBox(
                          width: 272,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleResponse(false),
                            icon: const Icon(Icons.cancel),
                            label: const Text(
                              'Tidak Bisa Saat Ini',
                              style: TextStyle(fontWeight: FontWeight.w500),
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
                      ],
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
