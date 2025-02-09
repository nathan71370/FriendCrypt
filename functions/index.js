// Import the Firestore trigger from the v2 API
const { onDocumentDeleted } = require("firebase-functions/v2/firestore");
// Import global options setter from the v2 API
const { setGlobalOptions } = require("firebase-functions/v2");

const admin = require("firebase-admin");
admin.initializeApp();

// Set global options for all v2 functions (including region)
setGlobalOptions({ region: "europe-west9" });

/**
 * This function triggers when a document in the 'conversations' collection is deleted.
 * It recursively deletes all documents in the associated 'messages' subcollection.
 */
exports.deleteMessagesOnConversationDelete = onDocumentDeleted(
  "conversations/{conversationId}",
  async (event) => {
    // Note: In the v2 API, the event parameter contains "params" for route parameters.
    const conversationId = event.params.conversationId;
    const messagesRef = admin.firestore()
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
 * Recursively deletes documents in batches using the provided query.
 * @param {FirebaseFirestore.Query} query - The Firestore query.
 */
async function deleteQueryBatch(query) {
  const snapshot = await query.get();
  if (snapshot.empty) {
    return; // No more documents to delete.
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
 * @param {FirebaseFirestore.CollectionReference} collectionRef - Reference to the collection.
 * @param {number} batchSize - Maximum number of documents to delete per batch.
 */
async function deleteCollection(collectionRef, batchSize) {
  const query = collectionRef.orderBy("__name__").limit(batchSize);
  return deleteQueryBatch(query);
}