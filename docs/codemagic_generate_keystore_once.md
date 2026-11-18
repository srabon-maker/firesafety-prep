# Fire Safety BD — generate a permanent Android keystore in Codemagic (one time)

**No Java/JDK installation on the office PC is required.** This generator runs
only on Codemagic's build machine. It does **not** build an APK.

## Before starting

- Confirm you control the Codemagic project and have permission to download
  private build artifacts. Limit project/build access to trusted people.
- Use a trusted private device or approved secure storage to save the key.
  Do not store signing keys on an office device against its security policy.
- **Never commit** a keystore or password to GitHub; never send it in chat.
- Do **not** run this generator more than once after adopting the key. Each run
  creates a different certificate, so using a second one breaks APK update
  continuity and can break Android Google OAuth registration.

## Step 1: create one Codemagic secret

1. Open Codemagic > your Fire Safety BD app > **Environment variables**.
2. Add a variable:
   - **Name:** `FSBD_KEYSTORE_PASSWORD`
   - **Group:** `fsbd_keystore_generator`
   - **Value:** a unique strong password of **at least 16 characters**
   - **Secret:** enabled
3. Save. The workflow imports this group automatically. Do not put the
   password in YAML, GitHub, build logs, screenshots or chat.

## Step 2: run the generator once

1. Click **Start new build** in Codemagic.
2. Choose branch **`feature/codemagic-one-time-keystore-generator`**.
3. Choose workflow **`ONE TIME ONLY - Generate Fire Safety BD Release Keystore`**
   (ID: `fire-safety-generate-keystore-once`).
4. Start the build **manually**. It checks that it was manually started and
   on the expected branch. It will fail if the secret is missing or weak.
5. When successful, open **Artifacts**. The JKS file is named
   `fire-safety-bd-release.jks`; Codemagic may place nonstandard artifact
   types inside an artifacts ZIP. Download and extract it securely.
6. Securely back up the JKS **and the password** in separate protected
   locations. Anyone who obtains both can sign APKs as your app.

The generated key alias is **`fire_safety_bd`**. Its key password is the
**same** as `FSBD_KEYSTORE_PASSWORD`. The build log prints only public
certificate fingerprints, not the password.

## Step 3: register permanent signing identity in Codemagic

In Codemagic **Team settings > Code signing identities > Android keystores**,
upload the generated JKS with:

| Field | Value |
| --- | --- |
| Keystore file | `fire-safety-bd-release.jks` |
| Keystore password | Your saved `FSBD_KEYSTORE_PASSWORD` |
| Key alias | `fire_safety_bd` |
| Key password | Same saved password |
| Reference name | **`fire_safety_bd_release`** |

The regular APK workflow `fire-safety-job-prep` requires this exact
reference name. Do not run it until upload succeeds.

## Step 4: verify SHA-1 and Google Login

1. Start the regular APK workflow from your intended branch.
2. Under **Verify Actual APK SHA-1**, find the APK signer certificate SHA-1.
3. In the Google Cloud project owning the app's Web OAuth Client ID,
   register an **Android OAuth client** with:
   - Package: `com.firesafetybd`
   - SHA-1: the **actual release APK signer SHA-1**
4. Check that the Dart Google Sign-In `serverClientId` is the **Web** OAuth
   client ID in that same project.
5. Test Google Login on the newly signed APK and confirm a second APK build
   has the same SHA-1.

A `GoogleSignInExceptionCode.canceled` message does not itself prove a
certificate problem; if the error persists, inspect sanitized device logs.

**APK update warning:** Old debug-signed APKs may need to be uninstalled
before installing the permanently signed APK. Back up any local-only data.

## Step 5: cleanup sensitive temporary material

After verifying the JKS backup and uploading it as a Codemagic signing
identity, delete the **one-time generator build/artifact** if Codemagic allows
it, and remove the generator-only secret variable/group. Restrict access to
existing build artifacts until deletion. **Do not delete the permanent signing
identity** or your secure JKS backup.

## Notes

- This workflow deliberately has no automatic triggers.
- It is separate from the normal APK build workflow.
- The private key is temporarily available as a downloadable build artifact:
  treat that artifact as a sensitive credential.
- This change stays in a feature branch and should not be merged into
  `main` before setup and review.
- The assistant cannot access your Codemagic UI or safely hold the password.

Reference: https://docs.codemagic.io/yaml-basic-configuration/configuring-environment-variables/
