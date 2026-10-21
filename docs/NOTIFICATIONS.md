# Android notifications

Local alerts for this Android app. The in-app notification list and the push-token boundary (`AppPushService`) are unchanged. This document is the platform setup: permission, channel, icon, badge, and optional Firebase.

There is no `docs/RELEASE.md`. Release builds that must reject the fake API are described in [TESTING.md](TESTING.md). That page links here for the optional Firebase file.

## Permission

`android.permission.POST_NOTIFICATIONS` is in the manifest. On API 33 and newer the app asks with `flutter_local_notifications` (`requestNotificationsPermission`) after the first frame. On API 32 and older, including Android 10 (API 29), the permission is implicit and the plugin is not asked.

Alerts are not scheduled. `RECEIVE_BOOT_COMPLETED`, exact-alarm permissions, and the boot receivers are not added.

## Channel

| | |
| --- | --- |
| Id | `vib_collections_alerts` |
| Name | `تنبيهات VIB` |
| Description | `تنبيهات عامة وتنبيهات التحصيل` |
| Importance | high |
| Badge | `setShowBadge(true)` |

The name uses the manifest display name `VIB` (`android:label`). The id is the same in Dart, `res/values/strings.xml`, and the FCM default-channel meta-data. Do not rename it after a release; Android keeps the old channel.

The small icon is `res/drawable/ic_stat_notification.xml`, a white-on-transparent vector. It is the default icon for local notifications and the FCM meta-data `com.google.firebase.messaging.default_notification_icon`.

Launcher badges use the channel flag and, when a count is passed, `NotificationCompat.setNumber`. Launchers that do not show numbers ignore that value. There is no ShortcutBadger-style plugin; those crash on some launchers.

## SDK

Flutter 3.47.7 sets `minSdk` 24, `compileSdk` 36, and `targetSdk` 36. The app keeps the Flutter compile and target SDK (36 is the current value for this toolchain, above the 34/35 floor). `minSdk` is `minOf(flutter.minSdkVersion, 29)`, which stays 24 and cannot rise above Android 10.

The application id is still `com.example.vib_abdo_company_mobile`. This work does not change it.

## Firebase is optional

The Google Services Gradle plugin is on the classpath, and it is **applied only when** `android/app/google-services.json` exists, or when `enableGoogleServices=true` (`-P` or `gradle.properties`) or `ENABLE_GOOGLE_SERVICES=true` is set. If the flag is set and the file is missing, the build fails. Fake mode and CI do not set the flag and do not commit the file, so they build without Firebase.

`google-services.json` is in `.gitignore`. Do not commit one.

The Firebase Messaging SDK is **not** a dependency. The manifest meta-data is there for the day that SDK is added. Until then it is unused.

`tool/decode_google_services_json.sh` writes `android/app/google-services.json` from the environment variable below. An empty variable is a no-op. The script prints the Android package name and does not print the file. The release job `Release build rejects fake API` runs it only after the fake-API rejection check, and only when the secret is present.

### Secret names

Names only. No values belong in git, in logs, or in this file.

| Name | Where it is read |
| --- | --- |
| `GOOGLE_SERVICES_JSON_BASE64` | Release job in `.github/workflows/ci.yml`, via `tool/decode_google_services_json.sh` |
| `GOOGLE_SERVICES_JSON_STAGING_BASE64` | Not read by CI. Use it if staging and production files are stored separately, and copy the one you are shipping into `GOOGLE_SERVICES_JSON_BASE64` for that release. |
| `GOOGLE_SERVICES_JSON_PROD_BASE64` | Not read by CI. Same as the staging name. |

`GOOGLE_SERVICES_JSON_BASE64` is base64 of one `google-services.json`. The decoded `package_name` must be `com.example.vib_abdo_company_mobile` until the application id changes. A mismatch deletes the file and fails the step.

## What this app does not hold

- **APNs.** There is no iOS target. Apple push keys are not used.
- **FCM server key or service account.** Those belong to the backend that sends messages. They do not go in the app repo, the APK, or GitHub Actions for this client.
- **A Firebase project.** Nobody has created one in this repo.

The API contract still says the server speaks web push, not FCM. `AppPushService` stays a no-op until that changes.

## Emulator workflow

`.github/workflows/android-notifications-emulator.yml` (`Android notification emulator`) runs on `workflow_dispatch` and nightly at 03:00 UTC. It does not run on pull requests.

Matrix: API 29, 33, and 34, `google_apis` / `x86_64`, KVM, AVD cache. Debug builds pass `USE_FAKE_API=true`.

- API 29: notifications are allowed without a prompt, and a local alert is posted.
- API 33 and 34: `adb shell pm revoke` then the denied path (nothing is posted), then `adb shell pm grant` and the granted path (an alert is posted). The plugin permission call runs only when the permission is already granted, so the test does not sit on the system dialog.

Dispatch it from the branch:

```bash
gh workflow run android-notifications-emulator.yml --ref <branch>
```

## Decisions Ali still has to make

1. **Who owns the Firebase project** (create it, billing, who has IAM). This repo does not.
2. **Staging and production Firebase apps.** Separate `google-services.json` files, or one shared project. The secret names above are the split; CI reads only `GOOGLE_SERVICES_JSON_BASE64`.
3. **Final application id.** `google-services.json` is bound to `package_name`. It must match `com.example.vib_abdo_company_mobile` until Ali changes the id. A new id needs a new Firebase Android app and a new file. This change does not pick the id.
4. **Whether FCM is in scope.** The server contract is still web push. Turning FCM on means adding the Messaging SDK and a backend sender. The Gradle hook and the manifest meta-data are the only client pieces in place.
5. **Where the service account lives.** On the backend. Not in this app.
6. **Channel importance and extra channels.** One high-importance channel covers general and collections alerts. A quieter channel is a product choice.
7. **Scheduled local reminders.** Not built. Boot and exact-alarm permissions stay off until someone asks for them.
8. **Numeric badges on vendor launchers.** The channel badge is on. A badge-count plugin is not, because unsupported launchers crash.
9. **When to show the permission prompt.** It runs on the first frame. Moving it to after sign-in is a product choice.
