const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { setGlobalOptions } = require('firebase-functions/v2');
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');

admin.initializeApp();
setGlobalOptions({ maxInstances: 10 });

const DIGEST_TIMEZONE = 'Asia/Kolkata';

function asString(value) {
  return typeof value === 'string' ? value : '';
}

async function getUserTokens(uid) {
  if (!uid) {
    return [];
  }

  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  if (!userDoc.exists) {
    return [];
  }

  const tokens = userDoc.data().fcmTokens;
  if (!Array.isArray(tokens)) {
    return [];
  }

  return tokens.filter((token) => typeof token === 'string' && token.length > 0);
}

async function sendNotificationToUser({ uid, title, body, data }) {
  const tokens = await getUserTokens(uid);
  if (tokens.length === 0) {
    logger.info('Skipping notification because no FCM tokens were found.', { uid, title });
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  await removeInvalidTokens(uid, tokens, response);
}

async function sendNotificationToUsers({ uids, title, body, data }) {
  const tokenMap = await Promise.all(
    uids.map(async (uid) => ({
      uid,
      tokens: await getUserTokens(uid),
    })),
  );

  const tokens = tokenMap.flatMap((entry) => entry.tokens);
  if (tokens.length === 0) {
    return;
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  let cursor = 0;
  for (const entry of tokenMap) {
    const scopedResponses = response.responses.slice(cursor, cursor + entry.tokens.length);
    cursor += entry.tokens.length;
    await removeInvalidTokens(entry.uid, entry.tokens, { responses: scopedResponses });
  }
}

async function removeInvalidTokens(uid, tokens, response) {
  const invalidTokens = [];
  response.responses.forEach((result, index) => {
    if (
      !result.success &&
      result.error &&
      (result.error.code === 'messaging/registration-token-not-registered' ||
        result.error.code === 'messaging/invalid-registration-token')
    ) {
      invalidTokens.push(tokens[index]);
    }
  });

  if (invalidTokens.length > 0) {
    await admin.firestore().collection('users').doc(uid).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
    });
  }
}

function getDatePartsInTimeZone(date, timeZone) {
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });

  const values = {};
  for (const part of formatter.formatToParts(date)) {
    if (part.type !== 'literal') {
      values[part.type] = Number(part.value);
    }
  }

  return values;
}

function getTimeZoneOffset(date, timeZone) {
  const parts = getDatePartsInTimeZone(date, timeZone);
  const asUtc = Date.UTC(
    parts.year,
    parts.month - 1,
    parts.day,
    parts.hour,
    parts.minute,
    parts.second,
  );
  return asUtc - date.getTime();
}

function zonedTimeToUtc({
  year,
  month,
  day,
  hour = 0,
  minute = 0,
  second = 0,
  timeZone,
}) {
  const utcGuess = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  const offset = getTimeZoneOffset(utcGuess, timeZone);
  return new Date(utcGuess.getTime() - offset);
}

function getDayRangeInTimeZone(timeZone) {
  const now = new Date();
  const today = getDatePartsInTimeZone(now, timeZone);
  const start = zonedTimeToUtc({
    year: today.year,
    month: today.month,
    day: today.day,
    timeZone,
  });
  const end = zonedTimeToUtc({
    year: today.year,
    month: today.month,
    day: today.day + 1,
    timeZone,
  });

  return { start, end, today };
}

function weekIdForDateParts({ year, month, day }) {
  const date = new Date(Date.UTC(year, month - 1, day));
  const weekday = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
  date.setUTCDate(date.getUTCDate() - (weekday - 1));
  const weekYear = date.getUTCFullYear();
  const weekMonth = String(date.getUTCMonth() + 1).padStart(2, '0');
  const weekDay = String(date.getUTCDate()).padStart(2, '0');
  return `${weekYear}-${weekMonth}-${weekDay}`;
}

function weekdayKey({ year, month, day }) {
  const keys = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
  const date = new Date(Date.UTC(year, month - 1, day));
  return keys[date.getUTCDay()];
}

exports.onTaskAssigned = onDocumentCreated(
  'households/{householdId}/tasks/{taskId}',
  async (event) => {
    const task = event.data?.data();
    if (!task) {
      return;
    }

    const assignedToId = asString(task.assignedToId);
    const createdById = asString(task.createdById);
    if (!assignedToId || assignedToId === createdById) {
      return;
    }

    const title = asString(task.title) || 'New task';
    const assignerName =
      asString(task.createdBy?.displayName) ||
      asString(task.createdByName) ||
      'Someone';

    try {
      await sendNotificationToUser({
        uid: assignedToId,
        title: 'New Task Assigned',
        body: `${assignerName} assigned "${title}" to you`,
        data: {
          householdId: asString(event.params.householdId),
          taskId: asString(event.params.taskId),
          type: 'task_assigned',
        },
      });
    } catch (error) {
      logger.error('Failed to send task assignment notification.', error);
    }
  },
);

exports.onTaskCompleted = onDocumentUpdated(
  'households/{householdId}/tasks/{taskId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) {
      return;
    }

    const wasComplete = Boolean(before.isComplete ?? before.isCompleted);
    const isComplete = Boolean(after.isComplete ?? after.isCompleted);
    if (wasComplete || !isComplete) {
      return;
    }

    const createdById = asString(after.createdById);
    const assignedToId = asString(after.assignedToId);
    const completedById = asString(after.completedById);

    if (!createdById || createdById === completedById || createdById === assignedToId) {
      return;
    }

    const taskTitle = asString(after.title) || 'Task';
    const completerName =
      asString(after.assignedToName) ||
      asString(after.assignedTo?.displayName) ||
      'A household member';

    try {
      await sendNotificationToUser({
        uid: createdById,
        title: 'Task Completed',
        body: `${completerName} completed "${taskTitle}"`,
        data: {
          householdId: asString(event.params.householdId),
          taskId: asString(event.params.taskId),
          type: 'task_completed',
        },
      });
    } catch (error) {
      logger.error('Failed to send task completion notification.', error);
    }
  },
);

exports.onNewMessage = onDocumentCreated(
  'households/{householdId}/messages/{messageId}',
  async (event) => {
    const message = event.data?.data();
    if (!message) {
      return;
    }

    const householdId = asString(event.params.householdId);
    const senderId = asString(message.senderId);
    const senderName = asString(message.senderName) || 'Household member';

    try {
      const householdDoc = await admin.firestore().collection('households').doc(householdId).get();
      if (!householdDoc.exists) {
        return;
      }

      const members = Array.isArray(householdDoc.data().members)
        ? householdDoc.data().members.filter((uid) => uid !== senderId)
        : [];

      if (members.length === 0) {
        return;
      }

      await sendNotificationToUsers({
        uids: members,
        title: `${senderName} sent a message`,
        body: asString(message.type) === 'image'
          ? 'Shared a photo'
          : (asString(message.text) || 'New chat message'),
        data: {
          type: 'new_message',
          householdId,
          messageId: asString(event.params.messageId),
        },
      });
    } catch (error) {
      logger.error('Failed to send new-message notification.', { householdId, error });
    }
  },
);

exports.sendMorningDigest = onSchedule(
  {
    schedule: '0 7 * * *',
    timeZone: DIGEST_TIMEZONE,
  },
  async () => {
    const firestore = admin.firestore();
    const households = await firestore.collection('households').get();
    const { start, end, today } = getDayRangeInTimeZone(DIGEST_TIMEZONE);
    const weekId = weekIdForDateParts(today);
    const dayKey = weekdayKey(today);

    for (const household of households.docs) {
      const householdId = household.id;
      const members = Array.isArray(household.data().members) ? household.data().members : [];
      if (members.length === 0) {
        continue;
      }

      const [eventsSnapshot, tasksSnapshot, mealPlanDoc] = await Promise.all([
        firestore
          .collection('households')
          .doc(householdId)
          .collection('events')
          .where('startTime', '>=', admin.firestore.Timestamp.fromDate(start))
          .where('startTime', '<', admin.firestore.Timestamp.fromDate(end))
          .get()
          .catch(() => ({ docs: [] })),
        firestore
          .collection('households')
          .doc(householdId)
          .collection('tasks')
          .where('dueDate', '>=', admin.firestore.Timestamp.fromDate(start))
          .where('dueDate', '<', admin.firestore.Timestamp.fromDate(end))
          .where('isComplete', '==', false)
          .get()
          .catch(() => ({ docs: [] })),
        firestore.collection('households').doc(householdId).collection('mealPlan').doc(weekId).get(),
      ]);

      const todaysMeals = mealPlanDoc.exists ? mealPlanDoc.data().meals?.[dayKey] ?? {} : {};
      const cookingAssignments = Object.values(todaysMeals)
        .map((meal) => meal?.preparedByName)
        .filter(Boolean);

      const bodyParts = [
        `${eventsSnapshot.docs.length} events`,
        `${tasksSnapshot.docs.length} tasks due`,
      ];
      if (cookingAssignments.length > 0) {
        bodyParts.push(`Cooking: ${cookingAssignments.join(', ')}`);
      }

      try {
        await sendNotificationToUsers({
          uids: members,
          title: 'Nestkin Morning Digest',
          body: bodyParts.join(' - '),
          data: {
            type: 'morning_digest',
            householdId,
          },
        });
      } catch (error) {
        logger.error('Failed to send morning digest.', { householdId, error });
      }
    }
  },
);

exports.resetWeeklyPoints = onSchedule(
  {
    schedule: '0 0 * * 1',
    timeZone: DIGEST_TIMEZONE,
  },
  async () => {
    const firestore = admin.firestore();
    const membersSnapshot = await firestore.collection('householdMembers').get();

    let batch = firestore.batch();
    let operations = 0;

    for (const doc of membersSnapshot.docs) {
      const badges = Array.isArray(doc.data().badges) ? [...doc.data().badges] : [];
      if ((doc.data().weeklyPoints ?? 0) >= 50 && !badges.includes('Perfect Week')) {
        badges.push('Perfect Week');
      }

      batch.update(doc.ref, {
        weeklyPoints: 0,
        badges,
      });
      operations += 1;

      if (operations === 400) {
        await batch.commit();
        batch = firestore.batch();
        operations = 0;
      }
    }

    if (operations > 0) {
      await batch.commit();
    }
  },
);

// TODO: deploy after Blaze activation
// exports.missedDoseAlert = onSchedule(...);

// TODO: deploy after Blaze activation
// exports.onSOSTrigger = onDocumentWritten(
//   "households/{householdId}/sos/{uid}",
//   ...
// );

// TODO: deploy after Blaze activation
// exports.autoResolveSOS = onSchedule("every 30 minutes", ...);
