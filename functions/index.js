const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onTaskCreated = functions.firestore
  .document('tasks/{taskId}')
  .onCreate(async (snap) => {
    const task = snap.data();
    const { assignedTo, title, taskId, groupId } = task;

    if (!assignedTo) return null;

    const userDoc = await admin.firestore()
      .collection('users').doc(assignedTo).get();

    if (!userDoc.exists) return null;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return null;

    const message = {
      token: fcmToken,
      notification: {
        title: 'New Task Assigned',
        body: title,
      },
      data: { taskId, groupId },
    };

    try {
      await admin.messaging().send(message);
      console.log('Notification sent to', assignedTo);
    } catch (e) {
      console.error('FCM error:', e);
    }

    return null;
  });
