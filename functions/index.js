const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Cloud Function to send FCM push notifications when a push_notifications document is created
 */
exports.sendPushNotification = functions.firestore
  .document('push_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notification = snap.data();
      const userId = notification.userId;
      
      console.log(`Processing push notification for user: ${userId}`);

      // Get user's FCM tokens
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        console.log(`User ${userId} not found`);
        return null;
      }

      const userData = userDoc.data();
      const fcmTokens = userData.fcmTokens || [];

      if (fcmTokens.length === 0) {
        console.log(`No FCM tokens found for user ${userId}`);
        // Mark as sent anyway to avoid retry loops
        await snap.ref.update({
          isSent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: 'No FCM tokens registered'
        });
        return null;
      }

      // Prepare FCM message
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data || {},
        tokens: fcmTokens,
      };

      // Send to all tokens
      const response = await admin.messaging().sendEachForMulticast(message);

      console.log(`Successfully sent ${response.successCount} messages`);
      console.log(`Failed to send ${response.failureCount} messages`);

      // Remove invalid tokens
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.log(`Error sending to token ${fcmTokens[idx]}: ${resp.error}`);
          // Remove token if it's invalid or unregistered
          if (resp.error.code === 'messaging/invalid-registration-token' ||
              resp.error.code === 'messaging/registration-token-not-registered') {
            tokensToRemove.push(fcmTokens[idx]);
          }
        }
      });

      // Update user document to remove invalid tokens
      if (tokensToRemove.length > 0) {
        await admin.firestore().collection('users').doc(userId).update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
        });
        console.log(`Removed ${tokensToRemove.length} invalid tokens`);
      }

      // Mark notification as sent
      await snap.ref.update({
        isSent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        attempts: (notification.attempts || 0) + 1,
        lastError: response.failureCount > 0 ? `${response.failureCount} failures` : null
      });

      return null;
    } catch (error) {
      console.error('Error sending push notification:', error);
      
      // Update notification with error
      await snap.ref.update({
        attempts: (snap.data().attempts || 0) + 1,
        lastError: error.message
      });
      
      throw error;
    }
  });
