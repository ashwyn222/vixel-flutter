# Vixel Error Logs Viewer

A simple local web interface to view error logs from Firestore.

## Setup

1. **Get Firebase Configuration**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project
   - Go to Project Settings (gear icon)
   - Scroll down to "Your apps" section
   - If you don't have a Web app, click "Add app" → Web (</> icon)
   - Copy the Firebase configuration object

2. **Configure Firebase**
   - Open `index.html`
   - Find the `firebaseConfig` object (around line 15)
   - Replace the placeholder values with your actual Firebase config:
     ```javascript
     const firebaseConfig = {
         apiKey: "YOUR_API_KEY",
         authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
         projectId: "YOUR_PROJECT_ID",
         storageBucket: "YOUR_PROJECT_ID.appspot.com",
         messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
         appId: "YOUR_APP_ID"
     };
     ```

3. **Set Firestore Security Rules**
   - Go to Firebase Console → Firestore Database → Rules
   - Add read access for the `error_logs` collection:
     ```
     match /error_logs/{document} {
       allow read: if true;
     }
     ```
   - Click "Publish"

## Running Locally

### Option 1: Simple HTTP Server (Recommended)

**Python 3:**
```bash
cd logs_viewer
python3 -m http.server 8000
```

**Python 2:**
```bash
cd logs_viewer
python -m SimpleHTTPServer 8000
```

**Node.js (http-server):**
```bash
npm install -g http-server
cd logs_viewer
http-server -p 8000
```

Then open: `http://localhost:8000`

### Option 2: VS Code Live Server

1. Install "Live Server" extension in VS Code
2. Right-click on `index.html`
3. Select "Open with Live Server"

### Option 3: Direct File (Limited)

Some browsers may block Firebase requests when opening directly. Use a local server instead.

## Features

- ✅ View all error logs from Firestore
- ✅ Filter by log level (Error/Warning)
- ✅ Filter by operation type
- ✅ Limit number of logs displayed
- ✅ View error messages, stack traces, and context
- ✅ See user and device information
- ✅ Real-time refresh
- ✅ Dark theme UI

## Troubleshooting

**"Firebase not initialized" error:**
- Check that you've replaced all placeholder values in `firebaseConfig`
- Make sure you're using a local server (not opening file directly)
- Check browser console for detailed errors

**"Permission denied" error:**
- Check Firestore security rules allow reading `error_logs` collection
- Make sure rules are published

**No logs showing:**
- Check that logs are actually being written to Firestore
- Verify the collection name is `error_logs`
- Check browser console for errors
