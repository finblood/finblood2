const admin = require('firebase-admin');
const serviceAccount = require('./fin-blood-2-firebase-adminsdk-fbsvc-93a8aa26b1.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function checkDoc() {
  try {
    const doc = await admin.firestore().collection('notifications').doc('ct21ERiUcImdcRXDGAQA').get();
    const data = doc.data();
    console.log('Document status:', { 
      processed: data.processed, 
      processedAt: data.processedAt,
      processedBy: data.processedBy 
    });
    
    if (data.processed === true) {
      console.log('✅ SUCCESS: Document was processed by Cloud Function!');
    } else {
      console.log('❌ FAILED: Document was not processed');
    }
  } catch (error) {
    console.error('Error:', error);
  }
  process.exit(0);
}

checkDoc(); 