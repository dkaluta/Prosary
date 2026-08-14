import java.util.Properties

plugins {
    // AGP 9's built-in Kotlin support means org.jetbrains.kotlin.android is neither needed nor
    // allowed here (it registers a duplicate 'kotlin' extension) — only the Compose compiler
    // plugin still needs to be applied explicitly.
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    // Publishes straight to Play (./gradlew publishReleaseBundle) with a service-account JSON —
    // configured below only when the credentials file exists, so clones and CI build fine
    // without it.
    alias(libs.plugins.play.publisher)
    alias(libs.plugins.ksp)
}

// Upload-key credentials for the Play Store release build. Kept out of git entirely (see
// keystore/keystore.properties in .gitignore) — absent on a fresh clone or in CI without the
// secret provisioned, which is fine for debug work; only signing a release build needs it.
val keystorePropertiesFile = rootProject.file("keystore/keystore.properties")
// Play publishing: service-account JSON at ~/.local/share/keystore/play-publisher.json
// (gitignored, like the upload keystore) and grant that service account access to this app in
// Play Console -> Users & permissions. Then: ./gradlew publishReleaseBundle
val playCredentials = file("${System.getProperty("user.home")}/.local/share/keystore/play-publisher.json")
    .takeIf { it.exists() } ?: rootProject.file("keystore/play-publisher.json")
play {
    enabled.set(playCredentials.exists())
    if (playCredentials.exists()) {
        serviceAccountCredentials.set(playCredentials)
    }
    // The track your testers live on. "alpha" is Play's closed testing track — where the
    // Mission of St. Gamaliel reviewers read the Hebrew; "internal" is the smaller circle,
    // "beta"/"production" come later (or promote in Play Console).
    track.set("alpha")
    defaultToAppBundles.set(true)
}

val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.dkaluta.prosary"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.dkaluta.prosary"
        minSdk = 24
        targetSdk = 36
        versionCode = 26
        versionName = "0.9.2"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = rootProject.file("keystore/${keystoreProperties["storeFile"]}")
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }
}

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.core.ktx)
    implementation(libs.material)
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)
    // Used only by content/prayerpack/PrayerPackLoader.kt to parse .prosaryprayer manifest/content
    // JSON. org.json (already used for PresetEntity's reminder column) can't substitute here: its
    // android.jar unit-test stubs throw "Stub!" without Robolectric, which this module doesn't
    // use, and PrayerPackLoaderTest needs real parsing in a plain JVM test.
    implementation(libs.kotlinx.serialization.json)

    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)

    testImplementation(libs.junit)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.ui.test.junit4)
}
