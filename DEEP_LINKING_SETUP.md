# Deep Linking Setup Guide

This guide will help you complete the setup for native deep linking in your Music Keyboard app.

## What's Been Done (Automatically)

✅ Removed deprecated `firebase_dynamic_links` package  
✅ Added `app_links` package for native deep linking  
✅ Updated `DynamicLinkService` to generate simple deep link URLs  
✅ Configured Android App Links in `AndroidManifest.xml`  
✅ Added deep link handling logic in the app (Wrapper widget)  
✅ Created `assetlinks.json` template  

## What You Need to Do

### Step 1: Set Up Firebase Hosting

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase Hosting** in your project:
   ```bash
   firebase init hosting
   ```
   
   - Select your Firebase project
   - Set the public directory to `public` (or any directory you prefer)
   - Configure as a single-page app: **No**
   - Don't overwrite index.html if asked

4. **Create the `.well-known` directory**:
   ```bash
   mkdir -p public/.well-known
   ```

### Step 2: Get Your App's SHA-256 Fingerprint

You need to get the SHA-256 fingerprint of your app's signing certificate.

#### For Debug Build (Testing):
```bash
cd android
./gradlew signingReport
```
Or on Windows:
```bash
cd android
gradlew signingReport
```

Look for the **SHA-256** fingerprint under the `debug` variant. It will look like:
```
SHA-256: A1:B2:C3:D4:E5:F6:...
```

#### For Release Build (Production):
If you're using a release keystore, use:
```bash
keytool -list -v -keystore path/to/your/keystore.jks -alias your-key-alias
```

### Step 3: Update assetlinks.json

1. Open the `assetlinks.json` file in your project root
2. Replace `YOUR_SHA256_FINGERPRINT_HERE` with your actual SHA-256 fingerprint
3. **Remove the colons** from the fingerprint (e.g., `A1:B2:C3` becomes `A1B2C3`)

Example:
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.music_keyboard",
    "sha256_cert_fingerprints": [
      "A1B2C3D4E5F6789012345678901234567890ABCDEFABCDEFABCDEFABCDEF0123"
    ]
  }
}]
```

### Step 4: Set Up Your Domain

You need to choose and configure your domain. You have two options:

#### Option A: Use Firebase Hosting Default Domain
After deploying to Firebase Hosting, you'll get a domain like:
- `https://your-project-id.web.app`
- `https://your-project-id.firebaseapp.com`

#### Option B: Use a Custom Domain
Set up a custom domain in Firebase Hosting:
1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Follow the instructions to verify and connect your domain

### Step 5: Update Your App Code

1. Open `lib/src/services/dynamic_link_service.dart`
2. Replace the `_baseUrl` constant with your actual domain:
   ```dart
   static const String _baseUrl = 'https://your-actual-domain.com';
   ```

3. Open `android/app/src/main/AndroidManifest.xml`
4. Replace `musicnotation.page.link` with your actual domain:
   ```xml
   <data android:scheme="https" android:host="your-actual-domain.com"/>
   ```

### Step 6: Deploy assetlinks.json to Firebase Hosting

1. **Copy the assetlinks.json file** to your Firebase Hosting public directory:
   ```bash
   cp assetlinks.json public/.well-known/assetlinks.json
   ```

2. **Create a simple index.html** in the public directory (if it doesn't exist):
   ```bash
   echo "<html><body><h1>Music Keyboard</h1></body></html>" > public/index.html
   ```

3. **Optional: Create a redirect page** at `public/sheet.html` for fallback:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
       <title>Music Keyboard - Sheet</title>
       <meta charset="UTF-8">
   </head>
   <body>
       <h1>Music Keyboard</h1>
       <p>To view this sheet, please install the Music Keyboard app.</p>
       <script>
           // Try to open the app
           const urlParams = new URLSearchParams(window.location.search);
           const sheetId = urlParams.get('id');
           if (sheetId) {
               window.location.href = `musicnotation://sheet?id=${sheetId}`;
           }
       </script>
   </body>
   </html>
   ```

4. **Deploy to Firebase**:
   ```bash
   firebase deploy --only hosting
   ```

### Step 7: Verify the Setup

1. **Check if assetlinks.json is accessible**:
   Visit: `https://your-domain.com/.well-known/assetlinks.json`
   
   You should see your assetlinks.json content.

2. **Verify with Google's Tool**:
   Go to: https://developers.google.com/digital-asset-links/tools/generator
   
   - Enter your domain
   - Enter your package name: `com.example.music_keyboard`
   - Verify the link

### Step 8: Test Deep Linking

1. **Install your app** on a test device

2. **Test with ADB**:
   ```bash
   adb shell am start -W -a android.intent.action.VIEW -d "https://your-domain.com/sheet?id=123" com.example.music_keyboard
   ```

3. **Test by clicking a link**:
   - Send yourself an email with the link: `https://your-domain.com/sheet?id=123`
   - Click the link on your phone
   - The app should open and navigate to the sheet

### Step 9: Get Dependencies

Run this command to get the new packages:
```bash
flutter pub get
```

### Step 10: Rebuild Your App

```bash
flutter clean
flutter build apk --release
```

## Troubleshooting

### Deep Links Not Working

1. **Verify assetlinks.json is accessible** at `https://your-domain.com/.well-known/assetlinks.json`
2. **Check SHA-256 fingerprint** matches (debug vs release builds have different fingerprints)
3. **Clear app data** and reinstall
4. **Wait 24-48 hours** for Android to cache the assetlinks.json file (or reset Android's link handling)

### Reset Android's Link Handling

On your test device:
1. Go to Settings → Apps → Music Keyboard
2. Go to "Open by default" or "Set as default"
3. Clear defaults
4. Reinstall the app

### Test Without Domain Verification

You can also test using custom URL schemes (these don't require domain verification):
- Add to AndroidManifest.xml:
  ```xml
  <data android:scheme="musicnotation"/>
  ```
- Test with: `musicnotation://sheet?id=123`

## Additional Notes

- **Android 12+**: App Links are verified automatically by the system
- **Multiple Fingerprints**: You can add multiple SHA-256 fingerprints to support both debug and release builds
- **iOS**: Similar setup needed using Associated Domains (not included in this guide)
- **Testing**: Use `adb logcat` to see deep link handling logs

## Resources

- [Android App Links Documentation](https://developer.android.com/training/app-links)
- [Firebase Hosting Documentation](https://firebase.google.com/docs/hosting)
- [app_links Package](https://pub.dev/packages/app_links)
