plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "cn.campus.campus_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.campus.campus_mobile"
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
    // 微信 OpenSDK：路线 A（WXLaunchMiniProgram）需要的唯一原生依赖。
    // 它只提供"拉起小程序"的能力；**是否真的能用取决于开放平台的移动应用 AppID 与包名/签名
    // 备案**，因此原生侧把注册结果如实上报：注册没通过就说没接入，而不是让用户点了没反应。
    // 坐标来自 Maven Central 的 com.tencent.mm.opensdk。
    //
    // The WeChat OpenSDK, the one native dependency route A needs. It only provides the ability
    // to launch; whether that works depends on the Open Platform mobile-app AppID plus the
    // package name and signature registration, so the native side reports the registration
    // result upwards honestly instead of letting a tap do nothing.
    implementation("com.tencent.mm.opensdk:wechat-sdk-android:6.8.40")
}

flutter {
    source = "../.."
}
