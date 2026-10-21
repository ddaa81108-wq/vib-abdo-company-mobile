plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.vib_abdo_company_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.vib_abdo_company_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Android 10 (API 29) must stay installable. Flutter 3.47.7's default is
        // 24, which is already under 29. minOf keeps that default.
        minSdk = minOf(flutter.minSdkVersion, 29)
        // Flutter 3.47.7 sets both to 36 (current for this toolchain).
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // NotificationCompat.setPublicVersion. The local-notifications plugin
    // cannot set a lock-screen public version, so MainActivity posts it.
    implementation("androidx.core:core-ktx:1.15.0")
}

flutter {
    source = "../.."
}

// Firebase is optional. A fake-mode or CI build has no json and skips this.
val googleServicesJson = file("google-services.json")
val googleServicesRequested =
    findProperty("enableGoogleServices")?.toString() == "true" ||
        System.getenv("ENABLE_GOOGLE_SERVICES") == "true"
if (googleServicesJson.exists() || googleServicesRequested) {
    if (!googleServicesJson.exists()) {
        throw GradleException(
            "Google services was requested (enableGoogleServices or ENABLE_GOOGLE_SERVICES) " +
                "but android/app/google-services.json is missing.",
        )
    }
    apply(plugin = "com.google.gms.google-services")
}
