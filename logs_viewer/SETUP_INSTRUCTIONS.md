# Logs Viewer Setup Instructions

## Step 1: Get Firebase Web App Config

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (`vixel-18b4b`)
3. Click the **gear icon** (⚙️) → **Project Settings**
4. Scroll down to **"Your apps"** section
5. If you don't have a **Web app**, click **"Add app"** → Select **Web** (</> icon)
6. Register the app (you can name it "Logs Viewer")
7. Copy the `firebaseConfig` object that looks like:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSy...",
  authDomain: "vixel-18b4b.firebaseapp.com",
  projectId: "vixel-18b4b",
  storageBucket: "vixel-18b4b.appspot.com",
  messagingSenderId: "946439763516",
  appId: "1:946439763516:web:..."
};
```

## Step 2: Update index.html

1. Open `logs_viewer/index.html`
2. Find the `firebaseConfig` object (around line 14)
3. Replace ALL the placeholder values with your actual config from Step 1
4. Save the file

## Step 3: Set Firestore Security Rules

1. Go to **Firebase Console → Firestore Database → Rules**
2. Add this rule:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /error_logs/{document} {
      allow read, write: if true;
    }
  }
}
```

3. Click **"Publish"**

## Step 4: Run the Logs Viewer

```bash
cd logs_viewer
python3 -m http.server 8000
```

Then open: `http://localhost:8000`

## Troubleshooting

**Error: "YOUR_PROJECT_ID" or "permission-denied"**
- ✅ Make sure you completed Step 1 and Step 2 (Firebase config)
- ✅ Make sure you completed Step 3 (Firestore rules)
- ✅ Check browser console for specific error messages

**Error: "Firebase not initialized"**
- ✅ Make sure Firebase config is correct
- ✅ Check browser console for initialization errors
- ✅ Make sure you're running via HTTP server (not file://)

**No logs showing:**
- ✅ Check Firestore Console to verify logs exist
- ✅ Check browser console for query errors
- ✅ Verify collection name is exactly `error_logs`
