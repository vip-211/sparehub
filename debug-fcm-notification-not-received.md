# Debug Session: fcm-notification-not-received

## Status: [CLOSED - ROOT CAUSE FOUND]

## Root Cause

**FCM tokens in database are stale/invalid**

Firebase Console shows "Sent but not Delivered" - FCM accepted messages but couldn't deliver.

This happens when the mobile app was reinstalled or token was refreshed - the old token in the database is no longer valid, and topic subscriptions tied to that token are also invalid.

## Hypotheses Results

1. **Firebase Not Initialized** - ❌ REJECTED - Firebase IS initialized
2. **FCM Token Not Stored in DB** - ❌ REJECTED - Token IS stored
3. **Topic Subscription Missing** - ❌ REJECTED - App IS subscribed to all-users
4. **SENDER_ID_MISMATCH** - ❌ REJECTED - Same project confirmed
5. **Channel Not Configured** - ❌ REJECTED - Channel exists

## Solution

Mobile app needs to:
1. Get fresh token: `FirebaseMessaging.instance.getToken()`
2. Send new token to backend via `/api/auth/update-fcm-token`
3. Re-subscribe to topics: `subscribeToTopic("all-users")`

## Evidence
- Firebase Console: Sent but not delivered
- Server logs show success with message ID
- All configuration checks passed
