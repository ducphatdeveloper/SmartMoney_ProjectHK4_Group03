plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_money"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Chuyển sang Java 17 để tránh cảnh báo "obsolete" của Java 8
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Đồng bộ jvmTarget với Java 17
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.smart_money"
        minSdk = flutter.minSdkVersion
        // Nâng lên 34 để theo chuẩn Google Play mới nhất và tối ưu hóa build
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Thư viện hỗ trợ các tính năng Java 8+ cho các thiết bị Android cũ
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
