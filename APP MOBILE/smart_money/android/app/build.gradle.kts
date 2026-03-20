plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin phải đặt SAU Android và Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_money"
    // Để Flutter tự quản lý compileSdk và ndkVersion — tránh conflict
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // Bắt buộc bật vì minSdk = 23 (Android 6.0).
        // Dù compile bằng Java 21, thiết bị chạy Android API 23-25
        // không có sẵn Java 8+ APIs trong runtime của chúng.
        // flutter_local_notifications dùng Java 8+ APIs
        // → Desugaring "dịch" các API đó để chạy được trên API 23-25.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Đồng bộ Kotlin với Java 21 — tránh warning version mismatch
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        applicationId = "com.example.smart_money"
        // Đặt cứng minSdk = 23 vì flutter_secure_storage yêu cầu tối thiểu API 23
        // flutter.minSdkVersion đôi khi trả về null ở Gradle mới → lỗi build
        minSdk = flutter.minSdkVersion
        // Project yêu cầu targetSdk = 30 (Android 11)
        // Lưu ý: Google Play yêu cầu targetSdk >= 34 nếu muốn publish lên store
        targetSdk = 30
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Tạm dùng debug key cho release build trong giai đoạn phát triển
            // TODO: Thay bằng signing key thật trước khi publish lên store
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Bắt buộc khi isCoreLibraryDesugaringEnabled = true ở trên.
    // Cung cấp các API Java 8+ cho thiết bị Android chạy API 23-25.
    // Dùng cho package: flutter_local_notifications (khai báo trong pubspec.yaml)
    // Vai trò: Khi Firebase gửi notification về, package này chịu trách nhiệm
    // HIỂN THỊ notification trên màn hình khi app đang MỞ (foreground).
    // Nếu thiếu → app đang mở sẽ không thấy thông báo nhắc nợ, vượt ngân sách...
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
