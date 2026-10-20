# Android release

This document is the release path for the Android app. It covers upload-key signing, the GitHub Actions workflow, version numbers, Play App Signing, rollback, and the application id rename. The rename is documented here and is not done yet.

No upload keystore is stored in this repository. `*.jks`, `*.keystore`, and `android/key.properties` are gitignored.

## Decisions still open

These block the first Play upload. The signing path can be exercised before they are settled. Keep every artifact off Play until they are.

1. **Application id.** The id is still `com.example.vib_abdo_company_mobile`. Ali chooses the final id. The first Play upload locks it for the life of the listing. The file list is below.
2. **Upload-key custodian.** Who generates the upload keystore, who keeps the offline copies, and who can recover them if the primary person is unavailable.
3. **GitHub secrets.** Which repository admin adds `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`.
4. **Play Console owner.** Who creates the app, enrolls in Play App Signing, and uploads the AAB. Enrollment should happen before the first production upload. See below.
5. **Branch protection.** Who applies `docs/BRANCH_PROTECTION.md` on `main` after CI has run once. This repository does not change GitHub settings.

## How a release build is signed

`android/app/build.gradle.kts` resolves four fields. For each field, a non-empty environment variable wins. Otherwise the same field is read from `android/key.properties` (UTF-8).

| Field | Environment variable | `key.properties` key |
| --- | --- | --- |
| Keystore file | `ANDROID_KEYSTORE_PATH` | `storeFile` |
| Store password | `ANDROID_KEYSTORE_PASSWORD` | `storePassword` |
| Key alias | `ANDROID_KEY_ALIAS` | `keyAlias` |
| Key password | `ANDROID_KEY_PASSWORD` | `keyPassword` |

`storeFile` is an absolute path, or a path relative to `android/app`. `~` is not expanded. `ANDROID_KEYSTORE_BASE64` is used only by the GitHub workflow to recreate the file. Gradle does not read that variable.

There are three outcomes:

1. **Nothing is set.** No `android/key.properties` and no `ANDROID_KEYSTORE_*` values. The release build type is signed with the debug keystore. Debug and profile builds always use the debug keystore. `flutter analyze`, `flutter test`, `flutter build apk --debug`, and pull-request CI keep working. Gradle prints a warning when a release task is in the task graph. Keep that APK or AAB off Play.
2. **Partial material.** Any field is set, but the set is incomplete or the keystore file is missing. Configuration fails and names the missing fields. Passwords are not printed. A half-written `android/key.properties` fails debug builds as well, because Gradle configures every build type up front. Finish the file or delete it.
3. **Complete material.** All four fields are set and the file exists. The release build type uses that keystore.

`ANDROID_REQUIRE_RELEASE_SIGNING=true` demands outcome 3. The same switch as a Gradle property is `-PrequireReleaseSigning=true`, which Flutter accepts as `--android-project-arg=requireReleaseSigning=true`. The release workflow sets the environment variable so a debug-signed file cannot be uploaded as a release artifact. Set that variable only for the release command. The Gradle daemon keeps the environment it was started with. After changing signing environment variables, stop the daemon (`cd android && ./gradlew --stop`) before the next build. Edits to `android/key.properties` are read from disk on the next build.

`android/key.properties.example` shows the file shape. Copy it to `android/key.properties`. The example itself is not read.

## Create the upload keystore

Run this on a trusted machine. It creates the **upload** key. With Play App Signing, Google holds the app signing key. This file is the key you use to upload.

```bash
keytool -genkeypair -v \
  -storetype PKCS12 \
  -keystore upload-keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

`keytool` asks for the store password, the key password, and a distinguished name. The distinguished name is public once an app signed with this key is installed. Use the organization name. Prefer an ASCII password. A PKCS12 keystore has one password: when `keytool` asks for the key password, reuse the store password (a different `-keypass` is ignored, and Gradle then fails to unlock the key). Put that same password in both `storePassword` and `keyPassword`, and in both `ANDROID_KEYSTORE_PASSWORD` and `ANDROID_KEY_PASSWORD`. Store it in a password manager before closing the terminal.

Keep `upload-keystore.jks` outside the clone. A second offline copy lives with the backup custodian. GitHub secrets are a third copy for CI, not the only copy. Send neither the file nor the passwords through chat or email.

Point `android/key.properties` at the file:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

Confirm the certificate:

```bash
keytool -list -v -keystore /absolute/path/to/upload-keystore.jks -alias upload
```

Local release builds:

```bash
flutter build appbundle --release
flutter build apk --release
```

Outputs:

- `build/app/outputs/bundle/release/app-release.aab` (this is what Play consumes)
- `build/app/outputs/flutter-apk/app-release.apk` (sideload check)

Confirm the signer is the upload key. The subject must not be `CN=Android Debug`.

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

`jarsigner` prints a self-signed warning for an upload key. That warning is expected. The certificate subject is the check. A one-year test key also warns about expiry. A real upload key uses the 10000-day validity from the `keytool` command above.

To prove the guard works on a machine with no signing material:

```bash
ANDROID_REQUIRE_RELEASE_SIGNING=true flutter build appbundle --release
```

That command fails until the four fields resolve.

## GitHub Actions

`.github/workflows/android-release.yml` is named `Android release`. It runs on **Run workflow** (`workflow_dispatch`) and on tags that match `v*.*.*` (for example `v1.2.3` or `v1.2.3+15`). It does not run on pull requests, so a fork cannot read the secrets.

When none of the four secrets are set, the job succeeds, writes a notice, explains the skip in the step summary, and uploads nothing. When some of the four are set and some are missing, the job fails and names the missing secrets. It does not print secret values.

When all four are set, the job:

1. Checks the tag against `pubspec.yaml` (tag pushes only).
2. Decodes `ANDROID_KEYSTORE_BASE64` into `$RUNNER_TEMP` (mode `0600`), outside the workspace.
3. Builds a release AAB and one universal APK with `ANDROID_REQUIRE_RELEASE_SIGNING=true`.
4. Fails if either artifact is signed by the Android debug certificate.
5. Uploads both files as one artifact retained for 90 days.
6. Deletes the decoded keystore.

The workflow does not create a GitHub Release and does not call the Play API. Download the AAB and upload it in Play Console.

While `applicationId` still contains `com.example.vib_abdo_company_mobile`, the job emits a warning. Those artifacts are for the signing path only.

Keystore passwords are passed as environment variables on the build step. They are not passed into `actions/checkout`, `actions/setup-java`, `subosito/flutter-action`, or `actions/upload-artifact`.

Optional later hardening: move the four secrets into a GitHub Environment that requires a reviewer before a tag push can use them. That environment is not configured here.

### Secrets to add

Repository admin: **Settings → Secrets and variables → Actions → Repository secrets**.

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Standard base64 of `upload-keystore.jks`. Line breaks are fine. URL-safe base64 (`-` and `_`) is not. |
| `ANDROID_KEYSTORE_PASSWORD` | Store password. |
| `ANDROID_KEY_ALIAS` | Key alias. `upload` matches the `keytool` command above. |
| `ANDROID_KEY_PASSWORD` | Key password. |

Encode the file:

```bash
# Linux
base64 -w 0 upload-keystore.jks

# macOS
base64 -i upload-keystore.jks | tr -d '\n'
```

Paste the text into `ANDROID_KEYSTORE_BASE64`. After the secrets exist, run the workflow once from the Actions tab and confirm the artifact's certificate matches `keytool -list`.

Flutter in both workflows is pinned to 3.47.7, the version recorded in `README.md`. The build JDK is 21. App source and target remain Java 17.

## Versioning

`pubspec.yaml` is the source of truth:

```yaml
version: 1.2.3+15
```

`1.2.3` is `versionName` (the string users see). `15` is `versionCode` (the integer Play compares). `android/app/build.gradle.kts` assigns `flutter.versionName` and `flutter.versionCode`. Leave the numbers out of Gradle.

Rules:

- `versionName` is `MAJOR.MINOR.PATCH`.
- `versionCode` is an integer from 1 to 2100000000 with no leading zero.
- Every upload of this application id to Play, including internal testing, uses a `versionCode` higher than any `versionCode` already uploaded. Play rejects a repeat or a decrease.
- A hotfix increments the patch `versionName` and increments `versionCode`.
- A rebuild of the same `versionName` still increments `versionCode`.
- Leave `versionCode` in the repo. Derive it neither from the date nor from the GitHub run number.

Tag the release commit on `main`:

- `v1.2.3` must match `versionName` in that commit. `versionCode` stays the `+` number.
- `v1.2.3+15` must match both numbers.

The workflow rejects a tag that does not match. Tag pushes ignore the `build_name` and `build_number` inputs. Move a tag only when the tag was wrong. A second upload of the same `versionName` needs a new `versionCode` and a **Run workflow** dispatch, because the tag already points at the first commit.

`workflow_dispatch` inputs:

| Input | Effect |
| --- | --- |
| `build_name` | Replaces `versionName`. Format `MAJOR.MINOR.PATCH`. |
| `build_number` | Replaces `versionCode`. Integer `>= 1`. |

After an override ships, commit those numbers back into `pubspec.yaml` so the next increment starts from what Play received. The workflow flags a `build_number` lower than the pubspec `versionCode`. It still builds. Play will refuse the upload if that code is not higher than the last accepted one.

The release workflow builds one universal APK and one AAB. It does not pass `--split-per-abi`. Split APKs add `1000 * ABI_VERSION` to `versionCode`, which skips integers and can collide with a later upload. Play generates ABI splits from the AAB.

A local one-off, when you need numbers other than the pubspec:

```bash
flutter build appbundle --release --build-name=1.2.3 --build-number=16
flutter build apk --release --build-name=1.2.3 --build-number=16
```

## Play App Signing

Enroll when the Play app is created, before the first production upload.

- Choose Google’s generated app signing key. Google holds that key and signs what users install.
- The keystore from this document is the **upload** key. Play records it when the first AAB is uploaded, or when you register the upload certificate:

  ```bash
  keytool -export -rfc \
    -keystore /absolute/path/to/upload-keystore.jks \
    -alias upload \
    -file upload_certificate.pem
  ```

  The PEM is a public certificate. Keep it out of git unless a later change has a reason to vendor it.

- Upload the AAB. The APK from the workflow is the sideload check, not the Play artifact.
- Keep the upload keystore. Losing it is recoverable after enrollment: Play Console can reset the upload key, and users keep updating because the app signing key did not change. Losing a key you used as the app signing key yourself ends updates to that listing.

The SHA-1 and SHA-256 from `keytool -list -v` are what API consoles ask for later. Those fingerprints are public. The passwords and the `.jks` file are not.

## Rollback

1. In Play Console, halt the rollout.
2. Restore the previous release from that track’s release history when Play still offers it. That is a Play operation on an artifact Google already has. It does not require a lower `versionCode`.
3. A fixed build uses a new, higher `versionCode`. The same `versionName` can be reused. Reusing or lowering `versionCode` is rejected.
4. Download the last good AAB from the Actions artifact. Artifacts are deleted after 90 days, so copy anything you may need to roll forward from into the team’s release archive. That archive is not this git repository.
5. Roll the code back with a new commit on a pull request. `main` does not get a force push. See `docs/BRANCH_PROTECTION.md`.
6. Lost upload key, Play App Signing already enrolled: request an upload key reset in Play Console, put the new keystore in the password manager and in the four GitHub secrets, and ship a higher `versionCode`.
7. Upload key suspected compromised: reset it with Google the same way, replace the GitHub secrets, and retire the old file. The app signing key stays with Google.
8. A bad build that exists only on an internal track: halt that track. The same `versionCode` rule applies to the next upload.

## Replacing the application id

Do this in one pull request after Ali picks the id, and before any Play upload (including internal testing). An upload with `com.example.vib_abdo_company_mobile` creates a listing that cannot change its id. Installed builds of the old id do not update to the new id. Users would reinstall.

Use a reverse-DNS id the organization controls. Lowercase letters, digits, and underscores. At least two segments. The string is permanent.

Today one value feeds both `namespace` and `applicationId`. Keep them equal so `android:name=".MainActivity"` still resolves.

Files and settings that must change:

| Location | Change |
| --- | --- |
| `android/app/build.gradle.kts` | `configuredApplicationId`. It sets both `namespace` and `applicationId`. |
| `android/app/src/main/kotlin/com/example/vib_abdo_company_mobile/MainActivity.kt` | `package` on line 1. Move the file so the directory matches the new package, one segment per folder (`com/example/vib_abdo_company_mobile` becomes the new segments). Remove the old directory. |
| `README.md` | The placeholder id in the Android section. |
| `docs/RELEASE.md` | This section, once the id is real. |
| `.github/workflows/android-release.yml` | The step that greps for `com.example.vib_abdo_company_mobile` and warns. After the rename the warning stops on its own. Update the step if you still want a guard. |

These files do not carry the id and stay as they are, provided `namespace` changes together with the Kotlin package:

- `android/app/src/main/AndroidManifest.xml` uses `.MainActivity`, which is relative to `namespace`.
- `android/app/src/debug/AndroidManifest.xml` and `android/app/src/profile/AndroidManifest.xml` only add the debug INTERNET permission.
- Method channels in `MainActivity` are `app/screen_security` and `app/connectivity`. They are not the application id.

There is no `google-services.json`, no product flavor, and no iOS project. If any of those appear before the rename, update them in the same pull request.

After the change, search the repo for `com.example.vib_abdo_company_mobile`. Uninstall the old debug app (`adb uninstall com.example.vib_abdo_company_mobile`) and install the new id. Confirm `applicationId` in the merged manifest or with `aapt dump badging` on a debug APK before the first Play upload.

## What CI checks

`.github/workflows/ci.yml` runs on pull requests and on `main`. It has three jobs: `analyze`, `test`, and `build`. `build` is `flutter build apk --debug`. It does not need signing secrets and does not produce a Play artifact. `test` also runs `tool/android_release_preflight_test.sh`.

`tool/check.sh` runs analyze, test, and that preflight script locally.
