// Firebase v2 Functions
const { onDocumentDeleted, onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
// Import global options setter from the v2 API
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
admin.initializeApp();

// Global options (region is from your existing code)
setGlobalOptions({ region: "europe-west9" });

// 1) Delete message subcollection when conversation is deleted (existing logic).
exports.deleteMessagesOnConversationDelete = onDocumentDeleted(
  "conversations/{conversationId}",
  async (event) => {
    const conversationId = event.params.conversationId;
    const messagesRef = admin
      .firestore()
      .collection("conversations")
      .doc(conversationId)
      .collection("messages");

    try {
      await deleteCollection(messagesRef, 500);
      console.log(`Deleted messages for conversation ${conversationId}`);
    } catch (error) {
      console.error("Error deleting messages:", error);
    }
  }
);

/**
 * Recursively deletes the documents from the provided query in batches.
 */
async function deleteQueryBatch(query) {
  const snapshot = await query.get();
  if (snapshot.empty) {
    return;
  }

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();

  // Recursively process the next batch.
  return deleteQueryBatch(query);
}

/**
 * Initiates deletion of a collection using a batched approach.
 */
async function deleteCollection(collectionRef, batchSize) {
  const query = collectionRef.orderBy("__name__").limit(batchSize);
  return deleteQueryBatch(query);
}

// 2) Send push notifications on new messages in "conversations/{conversationId}/messages/{messageId}"
exports.sendMessageNotification = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) {
      console.log("No message data found.");
      return;
    }
    const { senderId, text } = messageData;
    const conversationId = event.params.conversationId;

    // 1. Get conversation doc to see participants
    const convoRef = admin.firestore().collection("conversations").doc(conversationId);
    const convoSnap = await convoRef.get();
    if (!convoSnap.exists) return;
    const convo = convoSnap.data();
    const participants = convo.participants || [];
    
    // 2. Filter out the sender
    const recipients = participants.filter((uid) => uid !== senderId);
    if (recipients.length === 0) return;

    // 3. Get each recipient's fcmToken
    const tokens = [];
    for (const uid of recipients) {
      const userDoc = await admin.firestore().collection("users").doc(uid).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData.fcmToken) {
          tokens.push(userData.fcmToken);
        }
      }
    }
    if (tokens.length === 0) return;

    // 4. Build notification payload
    const payload = {
      notification: {
        title: "New Message",
        body: text || "You have a new message.",
      },
      data: {
        conversationId,
        senderId,
      },
    };

    // 5. Send push
    try {
      const response = await admin.messaging().sendToDevice(tokens, payload);
      console.log("Sent message push:", response);
    } catch (err) {
      console.error("Error sending push:", err);
    }
  }
);

// 3) Send push notifications for new friend requests
//    We detect newly added IDs in "friend_requests" array in user doc updates.
exports.onFriendRequestsUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data?.before?.data() || {};
  const afterData = event.data?.after?.data() || {};
  const userId = event.params.userId;

  const oldRequests = beforeData.friend_requests || [];
  const newRequests = afterData.friend_requests || [];

  // Identify newly added friend request IDs
  const addedRequests = newRequests.filter((uid) => !oldRequests.includes(uid));
  if (addedRequests.length === 0) return;

  // The userId is the one who received these friend requests
  // We fetch userId's doc to get their fcmToken
  const userSnap = await admin.firestore().collection("users").doc(userId).get();
  if (!userSnap.exists) return;
  const userData = userSnap.data();
  const userToken = userData.fcmToken;
  if (!userToken) return;

  // For simplicity, handle only the first newly added request:
  const requesterId = addedRequests[0];

  // Optionally fetch the requester's username
  let requesterName = requesterId;
  const requesterDoc = await admin.firestore().collection("users").doc(requesterId).get();
  if (requesterDoc.exists) {
    const rData = requesterDoc.data();
    requesterName = rData.username || requesterName;
  }

  // Build notification
  const payload = {
    notification: {
      title: "New Friend Request",
      body: `${requesterName} sent you a friend request.`,
    },
    data: {
      requestFrom: requesterId,
    },
  };

  // Send push
  try {
    const response = await admin.messaging().sendToDevice(userToken, payload);
    console.log("Sent friend request notification:", response);
  } catch (err) {
    console.error("Error sending friend request notification:", err);
  }
});

// 4) Send push notifications when a friend request is accepted
//    We detect newly added friend IDs in "friends" array. For each new friend, notify them.
exports.onFriendsUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data?.before?.data() || {};
  const afterData = event.data?.after?.data() || {};
  const userId = event.params.userId; // the user who accepted a friend request

  const oldFriends = beforeData.friends || [];
  const newFriends = afterData.friends || [];

  // Identify newly added friend IDs
  const addedFriends = newFriends.filter((uid) => !oldFriends.includes(uid));
  if (addedFriends.length === 0) return;

  // We'll assume the first newly added ID is the friend who was accepted
  const acceptedUid = addedFriends[0];

  // Load the user who accepted
  const userSnap = await admin.firestore().collection("users").doc(userId).get();
  if (!userSnap.exists) return;
  const userData = userSnap.data();
  const acceptingUsername = userData.username || userId;

  // We want to notify the acceptedUid
  const acceptedSnap = await admin.firestore().collection("users").doc(acceptedUid).get();
  if (!acceptedSnap.exists) return;
  const acceptedUserData = acceptedSnap.data();
  const acceptedToken = acceptedUserData.fcmToken;
  if (!acceptedToken) return;

  const payload = {
    notification: {
      title: "Friend Request Accepted",
      body: `${acceptingUsername} accepted your friend request!`,
    },
    data: {
      friendId: userId,
    },
  };

  try {
    const response = await admin.messaging().sendToDevice(acceptedToken, payload);
    console.log("Sent friend acceptance notification:", response);
  } catch (err) {
    console.error("Error sending friend acceptance notification:", err);
  }
});