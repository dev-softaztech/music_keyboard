# Deep Linking Quick Start

## ✅ What's Been Implemented

The app-side changes for native deep linking are **complete**! Here's what was done:

1. ✅ Removed `firebase_dynamic_links` (deprecated)
2. ✅ Added `app_links` package for native deep linking
3. ✅ Updated link generation to create simple URLs
4. ✅ Configured Android App Links in AndroidManifest.xml
5. ✅ Added deep link handling in the app
6. ✅ Dependencies downloaded successfully

## 🔧 Your Next Steps (Required for Deep Links to Work)

### Quick Setup (5 Steps):

1. **Get your SHA-256 fingerprint:**
   ```bash
   cd android
   gradlew signingReport
   ```
   Look for "SHA-256" under the debug variant.

2. **Update `assetlinks.json`:**
   - Open `assetlinks.json`
   - Replace `YOUR_SHA256_FINGERPRINT_HERE` with your SHA-256 (remove colons)

3. **Set up Firebase Hosting:**
   ```bash
   firebase init hosting
   mkdir -p public/.well-known
   cp assetlinks.json public/.well-known/assetlinks.json
   firebase deploy --only hosting
   ```

4. **Update your domain in the code:**
   - In `lib/src/services/dynamic_link_service.dart`: Update `_baseUrl`
   - In `android/app/src/main/AndroidManifest.xml`: Update the `android:host`
   - Use your Firebase Hosting URL (e.g., `your-project.web.app`)

5. **Rebuild your app:**
   ```bash
   flutter clean
   flutter build apk
   ```

## 📱 How to Test

Once setup is complete, test with ADB:
```bash
adb shell am start -W -a android.intent.action.VIEW -d "https://your-domain.com/sheet?id=123" com.example.music_keyboard
```

Or send yourself a link via email/messaging and click it on your phone!

## 📚 Detailed Documentation

See **`DEEP_LINKING_SETUP.md`** for:
- Complete step-by-step instructions
- Troubleshooting guide
- Testing strategies
- Advanced configuration

## 🔗 How Share Links Will Work

When users share a sheet:
1. App generates URL: `https://your-domain.com/sheet?id=123`
2. User shares the link
3. When clicked on Android, your app opens automatically
4. App navigates to the shared sheet

## ⚠️ Important Notes

- **Domain verification required**: Android needs to verify you own the domain
- **SHA-256 must match**: Use debug fingerprint for testing, release for production
- **Can take 24-48 hours**: Android caches domain verification
- **Testing tip**: Use custom URL scheme (`musicnotation://`) for instant testing without domain verification

## Need Help?

Check `DEEP_LINKING_SETUP.md` for detailed troubleshooting and resources!
