# Google Sign-In Error - Fix Guide

## Error: `PlatformException(network_error, com.google.android.gms.common.api.ApiException: 7:)`

This error typically indicates a configuration issue rather than an actual network problem.

## Common Causes

### 1. **SHA-1 Fingerprint Mismatch** (Most Common)
The certificate hash in your `google-services.json` doesn't match the one you're signing the app with.

### 2. **Google Play Services Configuration**
Google Play Services not properly installed or configured on the test device.

### 3. **Network Connectivity**
Actually a network issue (least common with this error code).

---

## Solution Steps

### Step 1: Get Your Current SHA-1 Fingerprint

Run this command from your project root:

**Windows (PowerShell):**
```powershell
cd android
./gradlew signingReport
```

**Windows (Command Prompt):**
```cmd
cd android
gradlew signingReport
```

This will output something like:
```
Variant: debugAndroidTest
Config: debug
Store: C:\Users\{username}\.android\debug.keystore
Alias: AndroidDebugKey
MD5: ...
SHA1: 9FD62167EE42A1AC88D564586C12B108B73D21F8
SHA-256: ...
```

**Copy the SHA1 value** (the one in your output, not this example).

### Step 2: Update google-services.json

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **final-mind-manager**
3. Go to **Project Settings** → **Your Apps**
4. Select your Android app
5. Scroll to **SHA certificate fingerprints**
6. Click **Add fingerprint**
7. Paste your SHA1 value from Step 1
8. Click **Save**
9. Download the updated `google-services.json`
10. Replace the one in your project: `android/app/google-services.json`

### Step 3: Check Build Variants

Make sure you're building with the correct keystore:

```bash
flutter run --debug
```

This uses the debug keystore. If you're building a release version, you need the release SHA-1 in Firebase.

### Step 4: Clean and Rebuild

```bash
# Navigate to project root
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run
```

### Step 5: Verify on Device

1. Make sure the test device has **Google Play Services** updated to the latest version
2. Go to Settings → Google → Manage your Google Account → Security
3. Verify the device is properly authenticated with a Google account

---

## Additional Checks

### Verify AndroidManifest.xml has Internet Permission

In `android/app/src/main/AndroidManifest.xml`, ensure:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### Check pubspec.yaml Dependencies

Ensure you have the correct versions:
```yaml
google_sign_in: ^6.2.0
firebase_auth: ^5.0.0
firebase_core: ^3.0.0
```

### Update Flutter and Dependencies

```bash
flutter upgrade
flutter pub get
flutter pub upgrade
```

---

## If Error Persists

1. **Try on a different device** - to rule out device-specific issues
2. **Use an emulator with Google Play Services** - some emulators have limited Google Play support
3. **Check Firebase Console logs** - look for authentication errors
4. **Verify API Enabled in Google Cloud Console**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Select your project
   - Go to APIs & Services → Enabled APIs
   - Ensure "Google+ API" and "Identity Toolkit API" are enabled

---

## Current Configuration

Your project is configured with:
- **Package Name:** `com.example.mind_manager_final`
- **Project ID:** `final-mind-manager`
- **Current SHA-1 Hashes in firebase:**
  - `9fd62167ee42a1ac88d564586c12b108b73d21f8`
  - `e13ca3c6704f2d56b90b05d1a60774638425c610`

If your current debug SHA-1 doesn't match these, that's likely the issue.

---

## Testing

After fixing the configuration, test with:
```bash
flutter run -v
```

Look for these log messages indicating success:
```
🔵 [AuthenticationProvider] Starting Google Sign-In...
🔵 [AuthenticationProvider] Getting Google authentication...
🔵 [AuthenticationProvider] Creating Firebase credential...
✅ [AuthenticationProvider] Firebase sign-in complete.
```

If you still see the error, the app will show a detailed error dialog with troubleshooting information.
