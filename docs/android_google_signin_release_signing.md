# Fire Safety BD — permanent Android release signing and Google Login

## Why this is necessary

Previously `android/app/build.gradle.kts` used `signingConfigs.debug` for
**release** APKs. Codemagic build machines may generate different debug keys,
so the Android certificate SHA-1 can change between builds. A successful APK
build does not prove Google Sign-In works. A
`GoogleSignInExceptionCode.canceled` may also mean the picker was dismissed;
it does **not**, by itself, prove a SHA-1 mismatch.

The package/application ID is **`com.firesafetybd`**. The app initializes
`google_sign_in` with a **Web OAuth Client ID** in `AuthService`.
Android OAuth registration must be configured for the same Google Cloud
project as that Web Client ID.

## One-time owner setup — DO THIS BEFORE THE NEXT CODEMAGIC BUILD

1. **Create a permanent keystore locally**, on a trusted computer with a
   JDK installed. Example command (run in a terminal or PowerShell):

   ```sh
   keytool -genkeypair -v -keystore fire-safety-bd-release.jks -storetype JKS -keyalg RSA -keysize 3072 -validity 10000 -alias fire_safety_bd
   ```

   Choose strong keystore and key passwords. **Do not send the file or either
   password in ChatGPT, GitHub, screenshots or support tickets.** Keep a
   secure offline backup of the `.jks` and credentials. Losing the key
   prevents installing updates over APKs signed with it.

2. In **Codemagic > Team settings > codemagic.yaml settings >
   Code signing identities > Android keystores**, upload that JKS. Enter
   keystore password, key alias `fire_safety_bd`, key password, and set
   **Reference name exactly `fire_safety_bd_release`**.

3. Start a new Codemagic build on branch
   `feature/marketplace-cart-checkout-bookings`. The workflow requires
   that signing identity and verifies the resulting APK certificate.
   Open build logs > **Verify Actual APK SHA-1** and copy only the
   `Signer #1 certificate SHA-1 digest` value.

4. Open **Google Cloud Console > APIs & Services > Credentials** in the
   Google Cloud project that owns the app's **Web Client ID**.
   Create/edit an **Android OAuth 2.0 Client ID** with:
   - Android package name: `com.firesafetybd`
   - SHA-1 certificate fingerprint: value from the **new signed APK**
   - Verify the app's `serverClientId` is a **Web application** OAuth
     client ID from that same project (do not put the Android client ID
     in the Dart `serverClientId` field).

5. Wait for Google OAuth changes to propagate, install the newly signed APK
   and test Google account selection, registration, session restoration and
   logout/relogin. Repeat the same build once more and confirm SHA-1 is
   **identical**. Do not change keystores for later builds.

## Important compatibility warning

Old APKs signed by the ephemeral Codemagic debug certificate and new APKs
signed by the permanent release certificate have different signatures.
Android generally refuses in-place installation of the new APK over the old
one. Back up any local app data, uninstall the old APK and then install the
new one. Server-side account/cart/order records should remain on the
backend; local-only data may be lost.

The signing identity is an **external prerequisite** and cannot be created
safely in the GitHub source repository. Until it is uploaded to Codemagic,
the new workflow will fail intentionally rather than silently produce a
debug-signed release APK.

## Troubleshooting if sign-in still returns canceled

- Confirm the **actual installed APK** certificate fingerprint matches
  the registered Android OAuth SHA-1, not an old Codemagic log.
- Confirm `com.firesafetybd` exactly matches the Android OAuth package.
- Confirm the Web Client ID is in the same Cloud project.
- Check Google Play services/account picker and device network.
- Capture sanitized `adb logcat` around the failure; do not share ID
  tokens, access tokens, keystore credentials or user email addresses.
- Check Google Sign-In plugin compatibility and native platform errors.

Source: https://docs.codemagic.io/yaml-code-signing/signing-android/
