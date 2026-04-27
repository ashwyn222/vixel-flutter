# Firestore Security Rules for Vixel

Go to **Firebase Console → Firestore Database → Rules** and replace the rules
with the production set below. Click **Publish** after pasting.

## Production rules (recommended)

Substitute `<YOUR_ADMIN_UID>` with **your own** Firebase UID. You can find it
in **Firebase Console → Authentication → Users**. Only this UID will be able
to read the `error_logs` collection (used by `logs_viewer/`).

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---------------------------------------------------------------------
    // error_logs : write-only for end users, read-only for the developer.
    // ---------------------------------------------------------------------
    match /error_logs/{doc} {
      // Only you (the developer) can read logs from the viewer.
      allow read: if request.auth != null
                  && request.auth.uid == "<YOUR_ADMIN_UID>";

      // Any signed-in user may add a new error log, but only with their own uid.
      allow create: if request.auth != null
                    && request.resource.data.userId == request.auth.uid;

      // Logs are immutable once written.
      allow update: if false;

      // The owner of the log entry may delete it (used by "Delete account").
      // The developer may also delete any entry.
      allow delete: if request.auth != null
                    && (resource.data.userId == request.auth.uid
                        || request.auth.uid == "<YOUR_ADMIN_UID>");
    }

    // ---------------------------------------------------------------------
    // users/{uid} : per-user operation quota tracker.
    // ---------------------------------------------------------------------
    match /users/{userId} {
      allow read, write, delete: if request.auth != null
                                  && request.auth.uid == userId;

      match /operations/{doc} {
        allow read, write, delete: if request.auth != null
                                    && request.auth.uid == userId;
      }
    }

    // Deny everything else by default.
  }
}
```

## TTL policy

Set up automatic deletion of old logs:

1. Firebase Console → Firestore → **TTL**.
2. Add policy on collection group `error_logs`, field `timestamp`, e.g. 60 days.

This caps your retention exposure and Firestore storage cost.

## One-time historical cleanup

Logs written by older builds of the app contain `userEmail`. To wipe them:

1. Firebase Console → Firestore → `error_logs`.
2. Either delete every document in the collection, or run a one-shot script
   that removes only the `userEmail` field from existing documents.
