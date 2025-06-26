const { onDocumentCreated, onDocumentUpdated, onCall } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2/options');
const { HttpsError, onRequest } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
admin.initializeApp();

setGlobalOptions({ region: 'us-central1' });

// Trigger Firestore onCreate pada koleksi users
exports.sendVerificationEmailV2 = onDocumentCreated('users/{userId}', async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log('No data snapshot');
    return;
  }
  const userData = snap.data();
  const email = userData.email;
  const displayName = (userData.nama || 'Pengguna').split(' ')[0];
  const userId = event.params.userId;

  if (!email) {
    console.log('No email available');
    return null;
  }

  try {
    console.log('Generating verification link for:', email);
    // Generate verification link
    const actionCodeSettings = {
      url: 'https://fin-blood-2.web.app',
      handleCodeInApp: false,
    };

    const verificationLink = await admin.auth().generateEmailVerificationLink(
      email,
      actionCodeSettings
    );
    console.log('Verification link generated successfully');

    console.log('Sending email to:', email);
    // Kirim email menggunakan extension
    const mailData = {
      to: email,
      message: {
        subject: 'Verifikasi Email Finblood',
        html: `
          <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:20px;font-family:Arial,sans-serif;">
            <tr>
              <td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;padding:30px;border-radius:10px;">
                  <tr>
                    <td align="center" style="padding-bottom:20px;">
                      <img src="https://i.imgur.com/HUuWVrW.png" alt="Logo" width="150" style="margin-bottom:20px;" />
                      <h2 style="color:#6C1022;margin:0;">Verifikasi Email Anda</h2>
                    </td>
                  </tr>
                  <tr>
                    <td style="color:#555555;font-size:16px;line-height:1.5;padding-bottom:20px;">
                      Halo <strong>${displayName}</strong>,<br><br>
                      Terima kasih telah mendaftar di <strong>Finblood</strong>.<br>
                      Untuk memverifikasi email Anda <strong>${email}</strong>, silakan klik tombol di bawah ini:
                    </td>
                  </tr>
                  <tr>
                    <td align="center" style="padding:20px 0;">
                      <a href="${verificationLink}" style="background-color:#6C1022;color:#ffffff;text-decoration:none;padding:12px 24px;border-radius:6px;display:inline-block;font-weight:bold;">
                        Verifikasi Email
                      </a>
                    </td>
                  </tr>
                  <tr>
                    <td style="color:#555555;font-size:14px;line-height:1.5;">
                      Jika Anda tidak merasa mendaftar di Finblood, abaikan saja email ini.
                    </td>
                  </tr>
                  <tr>
                    <td style="padding-top:30px;color:#888888;font-size:14px;text-align:center;">
                      Terima kasih,<br>
                      Tim <strong>Finblood</strong>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>
        `,
      },
      from: 'Finblood <finbloodapp@gmail.com>',
    };

    console.log('Adding mail to Firestore collection');
    const mailRef = await admin.firestore().collection('mail').add(mailData);
    console.log('Mail document created with ID:', mailRef.id);

    // Update user document to indicate email verification sent
    await admin.firestore().collection('users').doc(userId).update({
      'verificationEmailSent': true,
      'verificationEmailSentAt': admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('User document updated with verification email status');

    return null;
  } catch (error) {
    console.error('Error in sendVerificationEmailV2:', error);
    console.error('Error details:', {
      code: error.code,
      message: error.message,
      stack: error.stack
    });

    // Update user document to indicate email verification failed
    try {
      await admin.firestore().collection('users').doc(userId).update({
        'verificationEmailError': error.message,
        'verificationEmailErrorAt': admin.firestore.FieldValue.serverTimestamp()
      });
      console.log('User document updated with verification email error');
    } catch (updateError) {
      console.error('Failed to update user document with error:', updateError);
    }

    throw new Error(error.message);
  }
});

// Tambahkan trigger Firestore onUpdate untuk pengiriman ulang email verifikasi
exports.resendVerificationEmail = onDocumentUpdated('users/{userId}', async (event) => {
  const beforeData = event.data.before.data();
  const afterData = event.data.after.data();
  const userId = event.params.userId;
  
  // Periksa apakah field resendVerification berubah menjadi true
  if (!beforeData.resendVerification && afterData.resendVerification === true) {
    const email = afterData.email;
    const displayName = (afterData.nama || 'Pengguna').split(' ')[0];
    
    if (!email) {
      console.log('No email available for resend');
      return null;
    }
    
    try {
      console.log('Generating verification link for resend:', email);
      // Generate verification link
      const actionCodeSettings = {
        url: 'https://fin-blood-2.web.app',
        handleCodeInApp: false,
      };

      const verificationLink = await admin.auth().generateEmailVerificationLink(
        email,
        actionCodeSettings
      );
      console.log('Verification link generated successfully for resend');

      console.log('Sending email to:', email);
      // Kirim email menggunakan extension
      const mailData = {
        to: email,
        message: {
          subject: 'Verifikasi Email Finblood',
          html: `
            <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;padding:20px;font-family:Arial,sans-serif;">
              <tr>
                <td align="center">
                  <table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;padding:30px;border-radius:10px;">
                    <tr>
                      <td align="center" style="padding-bottom:20px;">
                        <img src="https://i.imgur.com/HUuWVrW.png" alt="Logo" width="150" style="margin-bottom:20px;" />
                        <h2 style="color:#6C1022;margin:0;">Verifikasi Email Anda</h2>
                      </td>
                    </tr>
                    <tr>
                      <td style="color:#555555;font-size:16px;line-height:1.5;padding-bottom:20px;">
                        Halo <strong>${displayName}</strong>,<br><br>
                        Ini adalah email verifikasi ulang untuk akun <strong>Finblood</strong> Anda.<br>
                        Untuk memverifikasi email Anda <strong>${email}</strong>, silakan klik tombol di bawah ini:
                      </td>
                    </tr>
                    <tr>
                      <td align="center" style="padding:20px 0;">
                        <a href="${verificationLink}" style="background-color:#6C1022;color:#ffffff;text-decoration:none;padding:12px 24px;border-radius:6px;display:inline-block;font-weight:bold;">
                          Verifikasi Email
                        </a>
                      </td>
                    </tr>
                    <tr>
                      <td style="color:#555555;font-size:14px;line-height:1.5;">
                        Jika Anda tidak merasa mendaftar di Finblood, abaikan saja email ini.
                      </td>
                    </tr>
                    <tr>
                      <td style="padding-top:30px;color:#888888;font-size:14px;text-align:center;">
                        Terima kasih,<br>
                        Tim <strong>Finblood</strong>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          `,
        },
        from: 'Finblood <finbloodapp@gmail.com>',
      };

      console.log('Adding mail to Firestore collection for resend');
      const mailRef = await admin.firestore().collection('mail').add(mailData);
      console.log('Mail document created with ID for resend:', mailRef.id);

      // Update user document to indicate email verification sent
      await admin.firestore().collection('users').doc(userId).update({
        'verificationEmailSent': true,
        'verificationEmailSentAt': admin.firestore.FieldValue.serverTimestamp(),
        'resendVerification': false
      });
      console.log('User document updated with verification email status for resend');

      return null;
    } catch (error) {
      console.error('Error in resendVerificationEmail:', error);
      console.error('Error details:', {
        code: error.code,
        message: error.message,
        stack: error.stack
      });

      // Update user document to indicate email verification failed
      try {
        await admin.firestore().collection('users').doc(userId).update({
          'verificationEmailError': error.message,
          'verificationEmailErrorAt': admin.firestore.FieldValue.serverTimestamp(),
          'resendVerification': false
        });
        console.log('User document updated with verification email error for resend');
      } catch (updateError) {
        console.error('Failed to update user document with error for resend:', updateError);
      }

      throw new Error(error.message);
    }
  }
  
  return null;
});

// Cloud Function untuk menghapus user secara otomatis
exports.deleteUserAccount = onRequest(async (req, res) => {
  try {
    // Tambahkan basic auth atau autentikasi lain sesuai kebutuhan
    // Untuk pengujian, kita menggunakan request sederhana
    
    const { uid, secretKey } = req.query;
    
    // Basic validation
    if (!uid) {
      return res.status(400).json({ 
        success: false, 
        error: 'UID parameter is required' 
      });
    }
    
    // Security validation (ganti dengan kunci rahasia yang kuat di produksi)
    // Ini hanya untuk pengujian
    const APP_SECRET_KEY = 'finblood-dev-key-2024';
    if (secretKey !== APP_SECRET_KEY) {
      return res.status(403).json({ 
        success: false, 
        error: 'Invalid authorization' 
      });
    }
    
    // Coba hapus user dari Firebase Auth
    await admin.auth().deleteUser(uid);
    
    // Log penghapusan user
    console.log(`User ${uid} successfully deleted from Firebase Auth`);
    
    // Periksa dan hapus data user dari Firestore jika masih ada
    try {
      const userDoc = await admin.firestore().collection('users').doc(uid).get();
      if (userDoc.exists) {
        await admin.firestore().collection('users').doc(uid).delete();
        console.log(`User ${uid} data deleted from Firestore`);
      }
    } catch (firestoreError) {
      console.error(`Error deleting Firestore data: ${firestoreError.message}`);
      // Lanjutkan meskipun gagal menghapus dari Firestore
    }
    
    return res.status(200).json({
      success: true,
      message: `User ${uid} successfully deleted`
    });
    
  } catch (error) {
    console.error(`Error deleting user: ${error.message}`);
    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Add HTTP function to update user display name directly in Firebase Auth
exports.updateUserDisplayName = onRequest({
  cors: true,
  maxInstances: 10,
}, async (req, res) => {
  try {
    // Check if this is a POST request
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // Get request data
    const { email, displayName, secretKey } = req.body;

    // Validate inputs
    if (!email || !displayName || !secretKey) {
      console.error('Missing required fields:', { email, displayName, secretKeyProvided: !!secretKey });
      res.status(400).send({ success: false, error: 'Missing required fields' });
      return;
    }

    // Verify secret key
    if (secretKey !== 'finblood-dev-key-2024') {
      console.error('Invalid secret key');
      res.status(403).send({ success: false, error: 'Unauthorized' });
      return;
    }

    console.log(`Updating displayName for ${email} to "${displayName}"`);

    // Get the user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    if (!userRecord) {
      console.error('User not found:', email);
      res.status(404).send({ success: false, error: 'User not found' });
      return;
    }

    // Update the display name
    await admin.auth().updateUser(userRecord.uid, {
      displayName: displayName
    });

    console.log(`Successfully updated displayName for ${email}`);
    res.status(200).send({ success: true, message: 'Display name updated successfully' });
  } catch (error) {
    console.error('Error updating displayName:', error);
    res.status(500).send({ 
      success: false, 
      error: error.message,
      code: error.code
    });
  }
});

// DISABLED: Fungsi baru untuk mengirim notifikasi ketika ada pendonor baru
// exports.notifyNewDonor = onDocumentCreated("pendonor/{donorId}", async (event) => {
//   const snap = event.data;
//   if (!snap) {
//     console.log("No data associated with the event");
//     return;
//   }
//   const donorData = snap.data();

//   const namaPendonor = donorData.nama || "Seseorang"; // Ambil nama, atau default "Seseorang"
//   const golonganDarah = donorData.golongan_darah || "Tidak diketahui";
//   const kampus = donorData.kampus || "Tidak diketahui";

//   console.log(`Pendonor baru terdeteksi: ${namaPendonor} (${golonganDarah}) dari ${kampus}`);

//   const topic = "pendonor_baru"; // Mengganti nama topik

//   // Definisikan payload dan data dalam objek pesan tunggal
//   const message = {
//     notification: {
//       title: "Pendonor Darah Baru!",
//       body: `${namaPendonor} (${golonganDarah}) dari ${kampus} baru saja mendaftar menjadi pendonor.`,
//       // imageUrl: "URL_TO_IMAGE_IF_ANY" // Jika ingin gambar besar
//     },
//     android: {
//       notification: {
//         icon: 'ic_stat_finblood_logo', // Menggunakan ikon notifikasi khusus
//         color: '#6C1022', // Contoh warna (sesuaikan dengan branding Anda)
//         // sound: 'default' // atau suara kustom
//         // channelId: 'pendonor_baru_channel' // Opsional jika sudah dihandle klien atau ingin channel khusus dari server
//       },
//       priority: 'high' // Pastikan prioritas tinggi untuk pengiriman cepat
//     },
//     apns: { // Pengaturan untuk iOS jika diperlukan
//       payload: {
//         aps: {
//           sound: 'default' // atau suara kustom iOS
//           // badge: 1, // Contoh badge
//         }
//       }
//     },
//     data: {
//       // Anda bisa mengirim data tambahan di sini yang bisa dihandle oleh aplikasi klien
//       // Misalnya, ID pendonor atau layar yang akan dibuka
//       click_action: "FLUTTER_NOTIFICATION_CLICK", // Standar untuk Flutter
//       donorId: event.params.donorId, // Mengirim ID pendonor
//       screen: "DaftarPendonorListPage" // Data untuk navigasi
//     },
//     topic: topic // Menambahkan properti topik di sini
//   };

//   try {
//     console.log(`Mengirim notifikasi ke topik: ${topic} dengan pesan:`, JSON.stringify(message));
//     // Gunakan admin.messaging().send(message) sebagai cara yang lebih modern dan direkomendasikan
//     const response = await admin.messaging().send(message);
//     console.log("Notifikasi berhasil dikirim:", response);
//   } catch (error) {
//     console.error("Gagal mengirim notifikasi:", error);
//   }
// }); 

// Fungsi HTTP untuk mengirim notifikasi manual oleh admin
exports.sendAdminNotification = onRequest({
  cors: true,
  maxInstances: 10,
}, async (req, res) => {
  try {
    // Check if this is a POST request
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    // Get request data - removed message field
    const { kampus, golonganDarah, secretKey } = req.body;

    // Validate inputs - removed message validation
    if (!secretKey) {
      console.error('Missing required fields:', { secretKeyProvided: !!secretKey });
      res.status(400).send({ success: false, error: 'Missing required fields' });
      return;
    }

    // Verify secret key
    if (secretKey !== 'finblood-dev-key-2024') {
      console.error('Invalid secret key');
      res.status(403).send({ success: false, error: 'Unauthorized' });
      return;
    }

    console.log(`Admin sending donor request notification with filters - Kampus: ${kampus}, Golongan Darah: ${golonganDarah}`);

    // Query pendonor berdasarkan filter
    let query = admin.firestore().collection('pendonor');
    
    if (kampus && kampus !== 'Semua Kampus') {
      query = query.where('kampus', '==', kampus);
    }
    
    if (golonganDarah && golonganDarah !== 'Semua Golongan Darah') {
      query = query.where('golongan_darah', '==', golonganDarah);
    }

    const snapshot = await query.get();
    
    if (snapshot.empty) {
      console.log('No donors found matching the criteria');
      res.status(404).send({ success: false, error: 'No donors found matching the criteria' });
      return;
    }

    // Ambil user_id dari pendonor yang sesuai filter
    const userIds = [];
    snapshot.forEach(doc => {
      const donorData = doc.data();
      console.log(`Donor document: ${doc.id}, user_id: ${donorData.user_id}`);
      if (donorData.user_id) {
        userIds.push(donorData.user_id);
      }
    });

    if (userIds.length === 0) {
      console.log('No valid user IDs found');
      res.status(404).send({ success: false, error: 'No valid user IDs found' });
      return;
    }

    // CRITICAL FIX: Filter out admin users from receiving notifications
    console.log(`Found ${userIds.length} user IDs before admin filtering`);
    
    const filteredUserIds = [];
    for (const userId of userIds) {
      try {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          const userRole = userData.role || 'user';
          
          if (userRole === 'admin') {
            console.log(`⚠️ ADMIN FILTER: Excluding admin user ${userId} from notifications`);
          } else {
            filteredUserIds.push(userId);
            console.log(`✅ USER FILTER: Including regular user ${userId} for notifications`);
          }
        } else {
          console.log(`⚠️ USER NOT FOUND: User document ${userId} does not exist`);
        }
      } catch (filterError) {
        console.error(`Error checking user role for ${userId}: ${filterError}`);
        // If we can't determine role, include them (safer to send than not send)
        filteredUserIds.push(userId);
      }
    }

    // Update userIds to use filtered list
    const finalUserIds = filteredUserIds;
    
    if (finalUserIds.length === 0) {
      console.log('No valid non-admin user IDs found after filtering');
      res.status(404).send({ 
        success: false, 
        error: 'No valid non-admin users found matching the criteria',
        originalCount: userIds.length,
        filteredCount: finalUserIds.length
      });
      return;
    }

    console.log(`Final user count after admin filtering: ${finalUserIds.length} (filtered out ${userIds.length - finalUserIds.length} admin users)`);
    console.log(`Final User IDs: ${finalUserIds.join(', ')}`);

    // Buat filter description untuk notifikasi SEBELUM digunakan
    let filterDesc = '';
    if (kampus && kampus !== 'Semua Kampus' && golonganDarah && golonganDarah !== 'Semua Golongan Darah') {
      filterDesc = ` dengan golongan darah ${golonganDarah} dari ${kampus}`;
    } else if (kampus && kampus !== 'Semua Kampus') {
      filterDesc = ` dari ${kampus}`;
    } else if (golonganDarah && golonganDarah !== 'Semua Golongan Darah') {
      filterDesc = ` dengan golongan darah ${golonganDarah}`;
    }

    // Standard donor request message
    const standardMessage = `Permintaan donor darah darurat${filterDesc}. Apakah Anda bersedia untuk mendonor?`;

    // SELALU simpan notifikasi ke in-app terlebih dahulu (ini yang paling penting)
    try {
      const notificationData = {
        message: standardMessage,
        filter_kampus: kampus || null,
        filter_golongan_darah: golonganDarah || null,
        filter_description: filterDesc || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sent_by: 'admin',
        type: 'donor_request'
      };

      // Simpan notifikasi ke sub-koleksi 'notifications' untuk setiap user (menggunakan finalUserIds)
      const savePromises = finalUserIds.map(userId => {
        return admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);
      });

      await Promise.all(savePromises);
      console.log(`Individual notifications saved for ${finalUserIds.length} users - IN-APP NOTIFICATIONS READY`);

    } catch (saveError) {
      console.error('CRITICAL ERROR: Failed to save in-app notifications:', saveError);
      res.status(500).send({
        success: false,
        error: 'Failed to save notifications to app'
      });
    return;
  }

    // Enhanced FCM token validation and refresh
    let totalSuccess = 0;
    let totalFailure = 0;
    let pushNotificationAttempted = false;
    let tokensRefreshed = 0;

    try {
      // Ambil FCM tokens dari user yang sesuai dengan enhanced validation
      const usersQuery = admin.firestore().collection('users').where(admin.firestore.FieldPath.documentId(), 'in', finalUserIds);
      const usersSnapshot = await usersQuery.get();
      
      console.log(`Users query returned ${usersSnapshot.docs.length} documents`);
      
      const validTokens = [];
      const validUsers = [];
      const tokensToValidate = [];
      
      // Enhanced token validation with app state consideration
      usersSnapshot.forEach(doc => {
        const userData = doc.data();
        const userId = doc.id;
        const token = userData.fcmToken;
        const tokenUpdatedAt = userData.tokenUpdatedAt;
        const lastAppResume = userData.lastAppResume;
        const appState = userData.appState;
        
        console.log(`User ${userId}: FCM token exists: ${!!token}, App state: ${appState || 'unknown'}`);
        
        if (token) {
          // More lenient token validation - don't immediately mark as invalid
          const now = Date.now();
          const tokenAge = tokenUpdatedAt ? now - tokenUpdatedAt.toDate().getTime() : now;
          const lastResumeAge = lastAppResume ? now - lastAppResume.toDate().getTime() : now;
          
          // Only mark for validation if token is very old (48 hours) AND app hasn't been active recently
          const isTokenVeryOld = tokenAge > (48 * 60 * 60 * 1000); // 48 hours
          const isAppInactive = lastResumeAge > (6 * 60 * 60 * 1000); // 6 hours since last resume
          
          if (isTokenVeryOld && isAppInactive) {
            console.log(`User ${userId}: Token is very old (${Math.round(tokenAge / (60 * 60 * 1000))} hours) and app inactive - will validate carefully`);
            tokensToValidate.push({ userId, token });
          } else {
            console.log(`User ${userId}: Token appears valid (age: ${Math.round(tokenAge / (60 * 60 * 1000))} hours, last resume: ${Math.round(lastResumeAge / (60 * 60 * 1000))} hours ago)`);
          }
          
          validTokens.push(token);
          validUsers.push(userId);
          console.log(`Added FCM token for user ${userId}: ${token.substring(0, 20)}...`);
        } else {
          console.log(`User ${userId} has no FCM token in document`);
        }
      });

      console.log(`Found ${validTokens.length} FCM tokens for ${validUsers.length} users`);
      if (tokensToValidate.length > 0) {
        console.log(`${tokensToValidate.length} tokens marked for careful validation`);
      }

      if (validTokens.length > 0) {
        pushNotificationAttempted = true;

        // Buat pesan notifikasi
        const notificationPayload = {
    notification: {
            title: "Permintaan Donor Darah",
            body: standardMessage,
    },
    android: {
      notification: {
              icon: 'ic_stat_finblood_logo',
              color: '#6C1022',
      },
            priority: 'high'
    },
          apns: {
      payload: {
        aps: {
                sound: 'default'
        }
      }
    },
    data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            screen: "KonfirmasiBersediaPage",
            type: "donor_request",
            golonganDarah: golonganDarah || "semua",
            notificationId: Date.now().toString(), // Generate unique notification ID
          }
        };

        // Kirim notifikasi dalam batch dengan enhanced error handling
        const batchSize = 500;
        const responses = [];
        
        for (let i = 0; i < validTokens.length; i += batchSize) {
          const batchTokens = validTokens.slice(i, i + batchSize);
          
          const batchMessage = {
            ...notificationPayload,
            tokens: batchTokens
          };
          
          try {
            const response = await admin.messaging().sendEachForMulticast(batchMessage);
            responses.push(response);
            console.log(`Batch ${Math.floor(i/batchSize) + 1} sent. Success: ${response.successCount}, Failed: ${response.failureCount}`);
            
            // Enhanced error handling with conservative token invalidation
            if (response.failureCount > 0) {
              response.responses.forEach((resp, index) => {
                if (!resp.success) {
                  const token = batchTokens[index];
                  const error = resp.error;
                  const userIndex = validTokens.indexOf(token);
                  const userId = userIndex >= 0 ? validUsers[userIndex] : 'unknown';
                  
                  console.error(`Failed to send notification to user ${userId} with token ${token.substring(0, 20)}...: ${error?.code} - ${error?.message}`);
                  
                  // More conservative error handling - only cleanup on specific errors
                  if (error?.code === 'messaging/registration-token-not-registered') {
                    console.log(`Token genuinely not registered for user ${userId} - scheduling removal`);
                    
                    // Mark for removal but give user chance to refresh
                    admin.firestore().collection('users')
                      .doc(userId)
                      .update({
                        fcmToken: admin.firestore.FieldValue.delete(),
                        tokenRemovedAt: admin.firestore.FieldValue.serverTimestamp(),
                        tokenRemovalReason: `${error?.code}: ${error?.message}`,
                        needsTokenRefresh: true, // Signal app to refresh on next startup
                      })
                      .then(() => {
                        console.log(`Token marked for refresh for user ${userId}`);
                        tokensRefreshed++;
                      })
                      .catch(cleanupError => {
                        console.error(`Error marking token for refresh for user ${userId}: ${cleanupError}`);
                      });
                      
                  } else if (error?.code === 'messaging/invalid-registration-token') {
                    console.log(`Token format invalid for user ${userId} - but may be temporary`);
                    
                    // Don't immediately delete - just mark for validation
                    admin.firestore().collection('users')
                      .doc(userId)
                      .update({
                        lastTokenError: admin.firestore.FieldValue.serverTimestamp(),
                        lastErrorCode: error?.code,
                        needsTokenValidation: true,
                      })
                      .catch(updateError => {
                        console.error(`Error updating token validation flag for user ${userId}: ${updateError}`);
                      });
                      
                  } else {
                    console.log(`Temporary error for user ${userId}: ${error?.code} - token preserved`);
                    
                    // For other errors (network, quota, etc.), don't invalidate token
                    admin.firestore().collection('users')
                      .doc(userId)
                      .update({
                        lastTemporaryError: admin.firestore.FieldValue.serverTimestamp(),
                        lastErrorCode: error?.code,
                      })
                      .catch(updateError => {
                        console.error(`Error logging temporary error for user ${userId}: ${updateError}`);
                      });
                  }
                }
              });
            }
            
          } catch (error) {
            console.error(`Error sending batch ${Math.floor(i/batchSize) + 1}:`, error);
          }
        }

        // Hitung total berhasil dan gagal
        responses.forEach(response => {
          totalSuccess += response.successCount;
          totalFailure += response.failureCount;
        });

        console.log(`Push notification sending complete. Total Success: ${totalSuccess}, Total Failed: ${totalFailure}, Tokens Refreshed: ${tokensRefreshed}`);
      } else {
        console.log('No FCM tokens found for push notifications - relying on in-app notifications only');
      }

    } catch (pushError) {
      console.error('Error with push notifications (continuing with in-app only):', pushError);
      // Tidak throw error karena in-app notifications sudah berhasil disimpan
    }

    // Simpan log global admin untuk statistik (opsional)
    try {
      await admin.firestore().collection('admin_notification_logs').add({
        message: standardMessage,
        filter_kampus: kampus || null,
        filter_golongan_darah: golonganDarah || null,
        filter_description: filterDesc || null,
        recipient_count: finalUserIds.length,
        successful_push_sends: totalSuccess,
        failed_push_sends: totalFailure,
        tokens_refreshed: tokensRefreshed,
        push_notification_attempted: pushNotificationAttempted,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sent_by: 'admin'
      });
      console.log('Admin notification log saved with token refresh stats');
    } catch (logError) {
      console.error('Error saving admin log (non-critical):', logError);
    }

    // RESPONSE SUKSES - karena in-app notifications sudah pasti tersimpan
    const responseMessage = pushNotificationAttempted 
      ? `Donor request notifications sent successfully. Push notifications: ${totalSuccess} sent, ${totalFailure} failed, ${tokensRefreshed} tokens refreshed. In-app notifications: ${finalUserIds.length} saved.`
      : `Donor request notifications saved to app successfully. No push notifications sent (no valid FCM tokens). In-app notifications: ${finalUserIds.length} saved.`;

    res.status(200).send({
      success: true,
      message: responseMessage,
      totalSent: totalSuccess,
      totalFailed: totalFailure,
      tokensRefreshed: tokensRefreshed,
      recipientCount: finalUserIds.length,
      inAppNotificationsSaved: finalUserIds.length,
      pushNotificationAttempted: pushNotificationAttempted,
      originalDonorCount: userIds.length,
      adminUsersFiltered: userIds.length - finalUserIds.length
    });

  } catch (error) {
    console.error('Error sending admin notification:', error);
    res.status(500).send({
      success: false,
      error: error.message
    });
  }
});

// Debug function untuk testing FCM functionality
exports.debugFCM = onRequest({
  cors: true,
  maxInstances: 5,
}, async (req, res) => {
  try {
    console.log('=== FCM DEBUG FUNCTION STARTED ===');
    
    const { userId, secretKey } = req.body;
    
    if (secretKey !== 'finblood-dev-key-2024') {
      res.status(403).send({ success: false, error: 'Unauthorized' });
      return;
    }
    
    if (!userId) {
      res.status(400).send({ success: false, error: 'User ID required' });
      return;
    }
    
    console.log(`Debug FCM for user: ${userId}`);
    
    // Get user data
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      console.log(`User ${userId} not found`);
      res.status(404).send({ success: false, error: 'User not found' });
      return;
    }
    
    const userData = userDoc.data();
    const token = userData.fcmToken;
    const role = userData.role || 'user';
    const tokenUpdatedAt = userData.tokenUpdatedAt;
    
    console.log(`User found: ${userId}, Role: ${role}, Has token: ${!!token}`);
    
    if (!token) {
      console.log('No FCM token found for user');
      res.status(200).send({
        success: true,
        debug: {
          userId: userId,
          hasToken: false,
          role: role,
          message: 'User has no FCM token'
        }
      });
      return;
    }
    
    console.log(`FCM Token: ${token.substring(0, 30)}..., Updated: ${tokenUpdatedAt}`);
    
    // Test send notification
    const testMessage = {
      notification: {
        title: "FCM Debug Test",
        body: `Test notification for user ${userId} at ${new Date().toISOString()}`,
      },
      android: {
        notification: {
          icon: 'ic_stat_finblood_logo',
          color: '#6C1022',
        },
        priority: 'high'
      },
      data: {
        type: "debug_test",
        timestamp: Date.now().toString(),
      },
      token: token
  };

  try {
      console.log('Attempting to send test notification...');
      const response = await admin.messaging().send(testMessage);
      console.log('Test notification sent successfully:', response);
      
      res.status(200).send({
        success: true,
        debug: {
          userId: userId,
          hasToken: true,
          tokenLength: token.length,
          tokenPrefix: token.substring(0, 30),
          tokenUpdatedAt: tokenUpdatedAt,
          role: role,
          messagingResponse: response,
          message: 'Test notification sent successfully'
        }
      });
      
    } catch (sendError) {
      console.error('Failed to send test notification:', sendError);
      
      res.status(200).send({
        success: false,
        debug: {
          userId: userId,
          hasToken: true,
          tokenLength: token.length,
          tokenPrefix: token.substring(0, 30),
          error: sendError.message,
          errorCode: sendError.code,
          message: 'Test notification failed'
        }
      });
    }
    
  } catch (error) {
    console.error('Error in debug FCM function:', error);
    res.status(500).send({
      success: false,
      error: error.message
    });
  }
}); 