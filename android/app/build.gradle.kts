import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material stays out of git. Each field uses a non-empty
// environment variable when one is set, and otherwise android/key.properties.
// Absent material signs release with the debug keystore. Partial material
// fails configuration. See docs/RELEASE.md.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
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
val releaseKeyPassword = releaseCredential("ANDROID_KEY_PASSWORD", "keyPassword")
// `file()` resolves a relative path from android/app. Absolute paths are unchanged.
val releaseStoreFile = releaseStoreFilePath?.let { path -> file(path) }

val releaseSigningMissing = buildList {
    if (releaseStoreFilePath.isNullOrEmpty()) {
        add("keystore path (ANDROID_KEYSTORE_PATH or storeFile in android/key.properties)")
    } else if (releaseStoreFile == null || !releaseStoreFile.isFile) {
        add("keystore file at '$releaseStoreFilePath' (not found; relative paths are from android/app)")
    }
    if (releaseStorePassword.isNullOrEmpty()) {
        add("store password (ANDROID_KEYSTORE_PASSWORD or storePassword)")
    }
    if (releaseKeyAlias.isNullOrEmpty()) {
        add("key alias (ANDROID_KEY_ALIAS or keyAlias)")
    }
    if (releaseKeyPassword.isNullOrEmpty()) {
        add("key password (ANDROID_KEY_PASSWORD or keyPassword)")
    }
}

val releaseSigningReady = releaseSigningMissing.isEmpty()
val releaseSigningRequested =
    !releaseStoreFilePath.isNullOrEmpty() ||
        !releaseStorePassword.isNullOrEmpty() ||
        !releaseKeyAlias.isNullOrEmpty() ||
        !releaseKeyPassword.isNullOrEmpty()
val requireReleaseSigning =
    System.getenv("ANDROID_REQUIRE_RELEASE_SIGNING")?.equals("true", ignoreCase = true) == true ||
        providers.gradleProperty("requireReleaseSigning").orNull?.equals("true", ignoreCase = true) == true

if (!releaseSigningReady && (releaseSigningRequested || requireReleaseSigning)) {
    error(
        "Release signing is incomplete: ${releaseSigningMissing.joinToString("; ")}. " +
            "See docs/RELEASE.md.",
    )
}

// Placeholder until the Play application id is chosen. The rename file list is
// in docs/RELEASE.md. Keep namespace and applicationId on the same value.
val configuredApplicationId = "com.example.vib_abdo_company_mobile"

android {
    namespace = configuredApplicationId
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = configuredApplicationId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionName and versionCode come from pubspec.yaml (`version: name+code`).
        // Split APKs add 1000 * ABI_VERSION on top of versionCode. The release
        // workflow builds one universal APK and one AAB and does not split.
        // See docs/RELEASE.md.
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
            if (!buildingRelease) {
                return
            }
            if (configuredApplicationId.startsWith("com.example.")) {
                // println stays visible when Flutter invokes Gradle with -q.
                println(
                    "WARNING: applicationId '$configuredApplicationId' is a placeholder. " +
                        "Do not upload this build to Play. See docs/RELEASE.md.",
                )
            }
            if (!releaseSigningReady) {
                println(
                    "WARNING: Release signing is not configured. This release build is signed " +
                        "with the debug keystore. Do not upload it to Play. See docs/RELEASE.md.",
                )
            }
        }
    },
)

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
