import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material never lives in git. Each field comes from a
// non-empty environment variable first, then from a key.properties file:
// $ANDROID_KEY_PROPERTIES when set (a path outside the repo), otherwise the
// untracked android/key.properties. A missing keyPassword falls back to
// storePassword (PKCS12 uses one password for both).
// - No material at all: release is signed with the debug key and a warning is
//   printed (CI only; never upload such a build).
// - Partial material: configuration fails.
// - ANDROID_REQUIRE_RELEASE_SIGNING=true or -PrequireReleaseSigning=true:
//   missing material fails configuration.
// See docs/release/BUILD.ar.md.
val keyPropertiesOverride = System.getenv("ANDROID_KEY_PROPERTIES")?.trim()?.takeIf { it.isNotEmpty() }
val keystorePropertiesFile =
    if (keyPropertiesOverride != null) file(keyPropertiesOverride) else rootProject.file("key.properties")
if (keyPropertiesOverride != null && !keystorePropertiesFile.isFile) {
    throw GradleException(
        "ANDROID_KEY_PROPERTIES points to '$keyPropertiesOverride', which is not a file.",
    )
}
val keystoreProperties = Properties()
if (keystorePropertiesFile.isFile) {
    keystorePropertiesFile.reader(Charsets.UTF_8).use { keystoreProperties.load(it) }
}

fun releaseCredential(envName: String, propertyName: String): String? {
    val fromEnv = System.getenv(envName)?.trim()?.takeIf { it.isNotEmpty() }
    if (fromEnv != null) {
        return fromEnv
    }
    return keystoreProperties.getProperty(propertyName)?.trim()?.takeIf { it.isNotEmpty() }
}

val releaseStoreFilePath = releaseCredential("ANDROID_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = releaseCredential("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = releaseCredential("ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPasswordExplicit = releaseCredential("ANDROID_KEY_PASSWORD", "keyPassword")
val releaseKeyPassword = releaseKeyPasswordExplicit ?: releaseStorePassword
// `file()` resolves a relative path from android/app. Absolute paths are unchanged.
val releaseStoreFile = releaseStoreFilePath?.let { path -> file(path) }

val releaseSigningMissing = buildList {
    if (releaseStoreFilePath == null) {
        add("keystore path (ANDROID_KEYSTORE_PATH or storeFile)")
    } else if (releaseStoreFile == null || !releaseStoreFile.isFile) {
        add("keystore file at '$releaseStoreFilePath' (not found; relative paths are from android/app)")
    }
    if (releaseStorePassword == null) {
        add("store password (ANDROID_KEYSTORE_PASSWORD or storePassword)")
    }
    if (releaseKeyAlias == null) {
        add("key alias (ANDROID_KEY_ALIAS or keyAlias)")
    }
    if (releaseKeyPassword == null) {
        add("key password (ANDROID_KEY_PASSWORD or keyPassword, or storePassword)")
    }
}

val releaseSigningReady = releaseSigningMissing.isEmpty()
val releaseSigningRequested =
    releaseStoreFilePath != null ||
        releaseStorePassword != null ||
        releaseKeyAlias != null ||
        releaseKeyPasswordExplicit != null
val requireReleaseSigning =
    System.getenv("ANDROID_REQUIRE_RELEASE_SIGNING")?.trim()?.equals("true", ignoreCase = true) == true ||
        providers.gradleProperty("requireReleaseSigning").orNull?.trim()?.equals("true", ignoreCase = true) == true

if (!releaseSigningReady && (releaseSigningRequested || requireReleaseSigning)) {
    // Names what is missing. Never prints a password value.
    throw GradleException(
        "Release signing is incomplete: ${releaseSigningMissing.joinToString("; ")}. " +
            "Set ANDROID_KEY_PROPERTIES or the ANDROID_KEYSTORE_* variables. " +
            "See docs/release/BUILD.ar.md.",
    )
}

android {
    namespace = "com.vip2100.vib"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Final application id chosen by Ali. Keep namespace on the same value.
        applicationId = "com.vip2100.vib"
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

    signingConfigs {
        if (releaseSigningReady) {
            create("release") {
                storeFile = releaseStoreFile!!
                storePassword = releaseStorePassword!!
                keyAlias = releaseKeyAlias!!
                keyPassword = releaseKeyPassword!!
            }
        }
    }

    buildTypes {
        release {
            // Debug key only when no release material exists at all (CI checks).
            signingConfig = if (releaseSigningReady) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

gradle.taskGraph.whenReady(
    object : org.gradle.api.Action<org.gradle.api.execution.TaskExecutionGraph> {
        override fun execute(graph: org.gradle.api.execution.TaskExecutionGraph) {
            val buildingRelease = graph.allTasks.any { task ->
                val name = task.name
                name.contains("Release") &&
                    (
                        name.startsWith("assemble") ||
                            name.startsWith("bundle") ||
                            name.startsWith("sign") ||
                            name.startsWith("package")
                        )
            }
            if (buildingRelease && !releaseSigningReady) {
                // println stays visible when Flutter invokes Gradle with -q.
                val banner = "=".repeat(72)
                println(banner)
                println(
                    "WARNING: Release signing is not configured. This release build is signed " +
                        "with the DEBUG keystore. Do not distribute or upload it. " +
                        "See docs/release/BUILD.ar.md.",
                )
                println(banner)
                logger.warn("WARNING: release build signed with the debug keystore.")
            }
        }
    },
)

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
