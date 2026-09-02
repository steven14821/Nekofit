/**
 * NekoFit — Scheduled Cloud Functions
 *
 * 1. purgeOldImages  — Daily (03:00 UTC). Deletes Storage blobs older than
 *    30 days under users/{uid}/ so the free tier (5 GB) never overflows.
 *
 * Deploy:   firebase deploy --only functions
 * Test:     firebase functions:call purgeOldImages
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getStorage } = require("firebase-admin/storage");
const { logger } = require("firebase-functions/v2");

initializeApp();

/** Maximum age in days before a blob is eligible for deletion. */
const MAX_AGE_DAYS = 30;

/**
 * List all blobs under a given prefix and delete those older than MAX_AGE_DAYS.
 * Returns the number of deleted items for logging.
 */
async function purgePrefix(bucket, prefix) {
  let deleted = 0;
  let pageToken;

  do {
    const [files, nextPageToken] = await bucket.getFiles({
      prefix,
      maxResults: 1000,
      pageToken,
    });
    pageToken = nextPageToken;

    const now = Date.now();
    const cutoff = now - MAX_AGE_DAYS * 24 * 60 * 60 * 1000;

    // Process in parallel batches of 50 to stay under Firebase quotas.
    const batch = [];
    for (const file of files) {
      const [meta] = await file.getMetadata();
      const created = new Date(meta.timeCreated).getTime();
      if (created < cutoff) {
        batch.push(file.delete().then(() => deleted++).catch(() => {}));
      }
      if (batch.length >= 50) {
        await Promise.all(batch);
        batch.length = 0;
      }
    }
    if (batch.length > 0) await Promise.all(batch);
  } while (pageToken);

  return deleted;
}

/**
 * Scheduled function: runs daily at 03:00 UTC.
 *
 * Strategy:
 * 1. List all top-level directories under users/ in Storage.
 * 2. For each user, purge blobs under users/{uid}/pantry/ and users/{uid}/meals/
 *    that are older than 30 days.
 *
 * Storage layout (from image_service.dart):
 *   users/{uid}/pantry/{productId}.jpg
 *   users/{uid}/meals/{timestamp}.jpg   (if/when meal photos are stored)
 */
exports.purgeOldImages = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "America/Bogota",
    region: "us-central1",
    retryConfig: { maxAttempts: 2, minBackoffSeconds: 60 },
    memory: "256MiB",
    timeoutSeconds: 300,
  },
  async (event) => {
    const bucket = getStorage().bucket();
    const [files] = await bucket.getFiles({ maxResults: 1 });

    if (files.length === 0) {
      logger.info("Storage bucket is empty, nothing to purge.");
      return;
    }

    // Discover user prefixes by listing the root.
    // Storage structure: users/{uid}/pantry/*.jpg
    // We iterate users/ to find all uid directories.
    let userDirs = [];
    let pageToken;

    do {
      const [dirs, nextToken] = await bucket.getFiles({
        prefix: "users/",
        delimiter: "/",
        maxResults: 1000,
        pageToken,
      });
      pageToken = nextToken;

      // prefixes are like "users/abc123/"
      if (dirs.prefixes) {
        userDirs.push(...dirs.prefixes);
      }
    } while (pageToken);

    let totalDeleted = 0;

    for (const userPrefix of userDirs) {
      // userPrefix = "users/abc123/"
      const d1 = await purgePrefix(bucket, userPrefix);
      totalDeleted += d1;
    }

    logger.info(
      `Purge complete. Deleted ${totalDeleted} blobs older than ${MAX_AGE_DAYS} days.`
    );
  }
);
