import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// مفاتيح التوقيع تُقرأ من android/key.properties (مستثنى من git)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.layanchargex.app.layan_chargex"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.layanchargex.app.layan_chargex"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // .trim() ضروري: أي مسافة في آخر السطر داخل key.properties تجعل
                // كلمة السر «خاطئة» ويفشل التوقيع بخط keystore password was incorrect
                val prop: (String) -> String = { key ->
                    (keystoreProperties[key] as String).trim()
                }
                keyAlias = prop("keyAlias")
                keyPassword = prop("keyPassword")
                // مسار نسبي لمجلد android/ أو مسار مطلق
                storeFile = rootProject.file(prop("storeFile"))
                storePassword = prop("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // بدون key.properties يعود البناء لمفتاح debug كي لا يتعطل `flutter run --release`
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
