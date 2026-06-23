import firestore from '@react-native-firebase/firestore';

/**
 * Ported from lib/services/notification_service.dart (verified against source on
 * 2026-06-23) — scoped to ONLY `sendToUser()`, the single method
 * create_delivery_screen.dart actually calls (queues a notification document for a
 * Cloud Function to deliver, per the Dart source's own comment that real sending is
 * server-side).
 *
 * Deliberately NOT ported here: FCM device-token registration/refresh, permission
 * requests, foreground/background message handlers, and tap-to-navigate routing. That's
 * real native push-notification infrastructure (would need index.js background-handler
 * wiring, not just a repository function) — it's Phase 6 cross-cutting scope per the
 * vault Phase Checklist ("offline queue, push notifications, ..."), not something to
 * half-build as a side effect of unblocking this one screen.
 */

/** Mirrors NotificationService.sendToUser(). */
export async function sendNotificationToUser(params: {
  userId: string;
  title: string;
  body: string;
  data: Record<string, string>;
}): Promise<void> {
  await firestore().collection('notifications').add({
    userId: params.userId,
    title: params.title,
    body: params.body,
    data: params.data,
    createdAt: firestore.FieldValue.serverTimestamp(),
    status: 'pending',
  });
}
