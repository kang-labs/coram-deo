import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play 스토어 업로드 키 (보안 파일은 git 밖 작업 폴더의 Security에만 둬요: Documents/Security/Android_upload_key)
// 환경 변수 CORAM_UPLOAD_SIGN=1 일 때만 이 키로 서명해요(Play에 올릴 AAB용).
// 그 밖의 빌드(GitHub APK, 기기 설치)는 지금처럼 debug 키라서, 이미 깔린 앱 위에 덮어 설치가 돼요.
val uploadKeyDir = rootProject.file("../../../../Security/Android_upload_key")
val uploadKeyFile = uploadKeyDir.resolve("coram-deo-upload.jks")
val uploadKeyProps = uploadKeyDir.resolve("coram-deo-key.properties")
val useUploadKey = System.getenv("CORAM_UPLOAD_SIGN") == "1"
if (useUploadKey && !(uploadKeyFile.exists() && uploadKeyProps.exists())) {
    // 키 없이 debug 서명 AAB가 만들어져 Play에 잘못 올라가는 일을 막아요
    throw GradleException("업로드 키가 없어요: ${uploadKeyDir.path} 에 coram-deo-upload.jks 와 coram-deo-key.properties 가 있어야 해요.")
}
val uploadKeyValues = Properties().apply { if (useUploadKey) uploadKeyProps.inputStream().use { load(it) } }

android {
    namespace = "kr.biblekang.coram_deo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.biblekang.coram_deo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (useUploadKey) {
            create("upload") {
                storeFile = uploadKeyFile
                storePassword = uploadKeyValues.getProperty("storePassword")
                keyAlias = uploadKeyValues.getProperty("keyAlias") ?: "upload"
                keyPassword = uploadKeyValues.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (useUploadKey) "upload" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
