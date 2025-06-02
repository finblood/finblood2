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

// Fungsi baru untuk mengirim notifikasi ketika ada pendonor baru
exports.notifyNewDonor = onDocumentCreated("pendonor/{donorId}", async (event) => {
  const snap = event.data;
  if (!snap) {
    console.log("No data associated with the event");
    return;
  }
  const donorData = snap.data();

  const namaPendonor = donorData.nama || "Seseorang"; // Ambil nama, atau default "Seseorang"
  const golonganDarah = donorData.golongan_darah || "Tidak diketahui";
  const kampus = donorData.kampus || "Tidak diketahui";

  console.log(`Pendonor baru terdeteksi: ${namaPendonor} (${golonganDarah}) dari ${kampus}`);

  const topic = "pendonor_baru"; // Mengganti nama topik

  // Definisikan payload dan data dalam objek pesan tunggal
  const message = {
    notification: {
      title: "Pendonor Darah Baru!",
      body: `${namaPendonor} (${golonganDarah}) dari ${kampus} baru saja mendaftar menjadi pendonor.`,
      // imageUrl: "URL_TO_IMAGE_IF_ANY" // Jika ingin gambar besar
    },
    android: {
      notification: {
        icon: 'ic_stat_finblood_logo', // Menggunakan ikon notifikasi khusus
        color: '#6C1022', // Contoh warna (sesuaikan dengan branding Anda)
        // sound: 'default' // atau suara kustom
        // channelId: 'pendonor_baru_channel' // Opsional jika sudah dihandle klien atau ingin channel khusus dari server
      },
      priority: 'high' // Pastikan prioritas tinggi untuk pengiriman cepat
    },
    apns: { // Pengaturan untuk iOS jika diperlukan
      payload: {
        aps: {
          sound: 'default' // atau suara kustom iOS
          // badge: 1, // Contoh badge
        }
      }
    },
    data: {
      // Anda bisa mengirim data tambahan di sini yang bisa dihandle oleh aplikasi klien
      // Misalnya, ID pendonor atau layar yang akan dibuka
      click_action: "FLUTTER_NOTIFICATION_CLICK", // Standar untuk Flutter
      donorId: event.params.donorId, // Mengirim ID pendonor
      screen: "DaftarPendonorListPage" // Data untuk navigasi
    },
    topic: topic // Menambahkan properti topik di sini
  };

  try {
    console.log(`Mengirim notifikasi ke topik: ${topic} dengan pesan:`, JSON.stringify(message));
    // Gunakan admin.messaging().send(message) sebagai cara yang lebih modern dan direkomendasikan
    const response = await admin.messaging().send(message);
    console.log("Notifikasi berhasil dikirim:", response);
  } catch (error) {
    console.error("Gagal mengirim notifikasi:", error);
  }
}); 