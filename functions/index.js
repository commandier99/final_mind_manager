const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

function stringifyDataPayload(payload) {
  if (!payload || typeof payload !== 'object') return {};
  const out = {};
  Object.entries(payload).forEach(([key, value]) => {
    if (value === null || value === undefined) return;
    out[key] = typeof value === 'string' ? value : JSON.stringify(value);
  });
  return out;
}

async function sendPushToUser({ userId, title, body, data = {} }) {
  console.log(`Processing push notification for user: ${userId}`);

  // Get user's FCM tokens
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  if (!userDoc.exists) {
    console.log(`User ${userId} not found`);
    return { successCount: 0, failureCount: 0, removedTokens: 0, skipped: 'user_not_found' };
  }

  const userData = userDoc.data() || {};
  const fcmTokens = userData.fcmTokens || [];

  if (!Array.isArray(fcmTokens) || fcmTokens.length === 0) {
    console.log(`No FCM tokens found for user ${userId}`);
    return { successCount: 0, failureCount: 0, removedTokens: 0, skipped: 'no_tokens' };
  }

  const message = {
    notification: { title, body },
    data: stringifyDataPayload(data),
    tokens: fcmTokens,
  };

  const response = await admin.messaging().sendEachForMulticast(message);

  console.log(`Successfully sent ${response.successCount} messages`);
  console.log(`Failed to send ${response.failureCount} messages`);

  // Remove invalid tokens
  const tokensToRemove = [];
  response.responses.forEach((resp, idx) => {
    if (!resp.success) {
      console.log(`Error sending to token ${fcmTokens[idx]}: ${resp.error}`);
      if (
        resp.error.code === 'messaging/invalid-registration-token' ||
        resp.error.code === 'messaging/registration-token-not-registered'
      ) {
        tokensToRemove.push(fcmTokens[idx]);
      }
    }
  });

  if (tokensToRemove.length > 0) {
    await admin.firestore().collection('users').doc(userId).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
    });
    console.log(`Removed ${tokensToRemove.length} invalid tokens`);
  }

  return {
    successCount: response.successCount,
    failureCount: response.failureCount,
    removedTokens: tokensToRemove.length,
  };
}

/**
 * Cloud Function to send FCM push notifications when a push_notifications document is created
 */
exports.sendPushNotification = functions.firestore
  .document('push_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notification = snap.data();
      const result = await sendPushToUser({
        userId: notification.userId,
        title: notification.title,
        body: notification.body,
        data: notification.data || {},
      });

      if (result.skipped === 'no_tokens') {
        // Mark as sent anyway to avoid retry loops
        await snap.ref.update({
          isSent: true,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: 'No FCM tokens registered'
        });
        return null;
      }

      // Mark notification as sent
      await snap.ref.update({
        isSent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        attempts: (notification.attempts || 0) + 1,
        lastError: result.failureCount > 0 ? `${result.failureCount} failures` : null
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

/**
 * Canonical flow: when an in-app notification is created, deliver push for it.
 */
exports.sendPushForInAppNotification = functions.firestore
  .document('in_app_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    try {
      const notification = snap.data() || {};
      const notificationId = context.params.notificationId;

      const userId = notification.userId;
      const title = notification.title;
      const body = notification.message;
      if (!userId || !title || !body) {
        console.log(`Skipping in-app ${notificationId}: missing required fields`);
        return null;
      }

      const metadata = notification.metadata || {};
      const relatedId = notification.relatedId || null;
      const payload = {
        notificationId,
        ...(relatedId ? { relatedId: String(relatedId) } : {}),
        ...metadata,
      };

      const result = await sendPushToUser({
        userId,
        title,
        body,
        data: payload,
      });

      await snap.ref.update({
        pushAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
        pushSent: true,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushAttempts: admin.firestore.FieldValue.increment(1),
        pushLastError: result.failureCount > 0 ? `${result.failureCount} failures` : null,
      });

      return null;
    } catch (error) {
      console.error('Error sending push for in-app notification:', error);
      await snap.ref.update({
        pushAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
        pushSent: false,
        pushAttempts: admin.firestore.FieldValue.increment(1),
        pushLastError: error.message || 'Unknown error',
      });
      throw error;
    }
  });

function normalizeAssignableRole(role) {
  const raw = (role || '').toString().trim().toLowerCase();
  return raw === 'supervisor' ? 'supervisor' : 'member';
}

/**
 * Applies approved recruitment requests (invite acceptance) to board membership.
 * This avoids client-side permission conflicts because board writes remain manager-only in rules.
 */
exports.applyApprovedRecruitment = functions.firestore
  .document('board_join_requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!before || !after) return null;
    if (before.boardReqStatus === 'approved' || after.boardReqStatus !== 'approved') {
      return null;
    }
    if ((after.boardReqType || '').toString().toLowerCase() !== 'recruitment') {
      return null;
    }
    if ((after.boardReqRespondedBy || '') !== (after.userId || '')) {
      console.log(
        `Skipping recruitment ${context.params.requestId}: responder is not invitee`,
      );
      return null;
    }

    const boardId = after.boardId;
    const userId = after.userId;
    if (!boardId || !userId) {
      console.log(`Skipping recruitment ${context.params.requestId}: missing boardId/userId`);
      return null;
    }

    const boardRef = admin.firestore().collection('boards').doc(boardId);

    try {
      await admin.firestore().runTransaction(async (tx) => {
        const boardSnap = await tx.get(boardRef);
        if (!boardSnap.exists) {
          console.log(`Skipping recruitment ${context.params.requestId}: board ${boardId} not found`);
          return;
        }

        const board = boardSnap.data() || {};
        const memberIds = Array.isArray(board.memberIds) ? [...board.memberIds] : [];
        if (memberIds.includes(userId)) {
          return;
        }

        const boardManagerId = board.boardManagerId || '';
        const requestManagerId = after.boardManagerId || '';
        if (boardManagerId !== requestManagerId) {
          console.log(
            `Skipping recruitment ${context.params.requestId}: manager mismatch (${boardManagerId} vs ${requestManagerId})`,
          );
          return;
        }

        memberIds.push(userId);
        const memberRoles = { ...(board.memberRoles || {}) };
        memberRoles[userId] = normalizeAssignableRole(after.boardReqRequestedRole);

        tx.update(boardRef, {
          memberIds,
          memberRoles,
          boardLastModifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          boardLastModifiedBy: userId,
        });
      });
    } catch (error) {
      console.error(`Failed to apply recruitment ${context.params.requestId}:`, error);
      throw error;
    }

    return null;
  });
