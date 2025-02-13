// Firebase Functions v2
const {
  onDocumentDeleted,
  onDocumentCreated,
  onDocumentUpdated
} = require("firebase-functions/v2/firestore");
// Import global options setter from the v2 API
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Initialize the Admin SDK
admin.initializeApp();

// Set your desired region (change if needed)
setGlobalOptions({ region: "europe-west9" });

/**
 * 1) When a conversation doc is deleted, remove all message docs in 'messages' subcollection.
 */
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

// Helper: recursively delete docs in batch
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
  // Recurse
  return deleteQueryBatch(query);
}

async function deleteCollection(collectionRef, batchSize) {
  const query = collectionRef.orderBy("__name__").limit(batchSize);
  return deleteQueryBatch(query);
}

/**
 * 2) Send push notifications for new messages.
 *    Triggered by doc creation in 'conversations/{conversationId}/messages/{messageId}'.
 */
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

    // 1. Load the conversation doc.
    const convoRef = admin.firestore().collection("conversations").doc(conversationId);
    const convoSnap = await convoRef.get();
    if (!convoSnap.exists) return;

    const convo = convoSnap.data() || {};
    const participants = convo.participants || [];

    // 2. Exclude the sender.
    const recipientIds = participants.filter((uid) => uid !== senderId);
    if (recipientIds.length === 0) return;

    // 3. Fetch tokens for each recipient.
    const tokens = [];
    for (const uid of recipientIds) {
      const userDoc = await admin.firestore().collection("users").doc(uid).get();
      if (!userDoc.exists) continue;
      const userData = userDoc.data();
      if (userData.fcmToken) {
        tokens.push(userData.fcmToken);
      }
    }
    if (tokens.length === 0) return;

    // 3.5 Fetch sender's username to use as the notification title.
    let senderName = "New Message";
    const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
    if (senderDoc.exists) {
      const senderData = senderDoc.data();
      senderName = senderData.username || senderName;
    }

    // 4. Prepare the multicast message with APNs options.
    const multicastMessage = {
      tokens, // array of FCM tokens
      notification: {
        title: senderName, // now shows sender’s username
        body: text || "You have a new message.",
      },
      data: {
        conversationId, // for deep linking
        senderId,
      },
      apns: {
        headers: {
          "apns-collapse-id": conversationId // collapses notifications for this conversation
        }
      }
    };

    // 5. Send the message.
    try {
      const response = await admin.messaging().sendEachForMulticast(multicastMessage);
      console.log("sendMessageNotification response:", response);
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`Error sending to token[${idx}]:`, resp.error);
        }
      });
    } catch (err) {
      console.error("Error sending message push:", err);
    }
  }
);

/**
 * 3) Detect newly added friend requests in 'users/{userId}' doc updates.
 */
exports.onFriendRequestsUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data?.before?.data() || {};
  const afterData = event.data?.after?.data() || {};
  const userId = event.params.userId;

  const oldRequests = beforeData.friend_requests || [];
  const newRequests = afterData.friend_requests || [];

  // Identify newly added requests
  const addedRequests = newRequests.filter((r) => !oldRequests.includes(r));
  if (addedRequests.length === 0) return;

  // The userId doc is receiving these new requests
  const userSnap = await admin.firestore().collection("users").doc(userId).get();
  if (!userSnap.exists) return;
  const userData = userSnap.data();
  const userToken = userData.fcmToken;
  if (!userToken) return;

  // We'll handle the first newly added request
  const requesterId = addedRequests[0];
  let requesterName = requesterId;
  const reqDoc = await admin.firestore().collection("users").doc(requesterId).get();
  if (reqDoc.exists) {
    const rData = reqDoc.data();
    requesterName = rData.username || requesterName;
  }

  // Build a single "multicast" message (even though it's just 1 token)
  const multicastMessage = {
    tokens: [userToken],
    notification: {
      title: "New Friend Request",
      body: `${requesterName} sent you a friend request.`,
    },
    data: {
      requestFrom: requesterId,
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(multicastMessage);
    console.log("onFriendRequestsUpdate response:", response);
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        console.error(`Error sending friend request push[${idx}]:`, resp.error);
      }
    });
  } catch (err) {
    console.error("Error sending friend request push:", err);
  }
});

/**
 * 4) Detect newly accepted friends in 'users/{userId}' doc updates.
 */
exports.onFriendsUpdate = onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data?.before?.data() || {};
  const afterData = event.data?.after?.data() || {};
  const userId = event.params.userId; // user who accepted

  const oldFriends = beforeData.friends || [];
  const newFriends = afterData.friends || [];

  // Newly accepted friend IDs
  const addedFriends = newFriends.filter((f) => !oldFriends.includes(f));
  if (addedFriends.length === 0) return;

  // We'll handle just the first newly added friend
  const acceptedUid = addedFriends[0];

  // The user doc for the acceptor
  const acceptorSnap = await admin.firestore().collection("users").doc(userId).get();
  if (!acceptorSnap.exists) return;
  const acceptorData = acceptorSnap.data();
  const acceptorName = acceptorData.username || userId;

  // The user doc for the accepted
  const acceptedSnap = await admin.firestore().collection("users").doc(acceptedUid).get();
  if (!acceptedSnap.exists) return;
  const acceptedData = acceptedSnap.data();
  const acceptedToken = acceptedData.fcmToken;
  if (!acceptedToken) return;

  // Single multicast message
  const multicastMessage = {
    tokens: [acceptedToken],
    notification: {
      title: "Friend Request Accepted",
      body: `${acceptorName} accepted your friend request!`,
    },
    data: {
      friendId: userId,
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(multicastMessage);
    console.log("onFriendsUpdate response:", response);
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        console.error(`Error sending friend acceptance push[${idx}]:`, resp.error);
      }
    });
  } catch (err) {
    console.error("Error sending acceptance notification:", err);
  }
});