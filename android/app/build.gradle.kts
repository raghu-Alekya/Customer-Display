plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.alekta.pinakapos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    /* ✅ IMPORTANT PART */
    repositories {
        flatDir {
            dirs("libs")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.alekta.pinakapos"
        minSdk = 30
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use debug signing for now
            signingConfig = signingConfigs.getByName("debug")

            // Disable code shrinking/obfuscation so R8 missing class errors
            // do not block building a release APK.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}


dependencies {

    implementation(fileTree("libs") {
        include("*.jar")
    })

    implementation(files("libs/cloud-commerce-sdk-mtf-5.3.1.aar"))

    implementation("com.jakewharton.timber:timber:5.0.1")


    // 🔥 ADD THESE TWO LINES
    implementation("org.slf4j:slf4j-api:1.7.36")
    implementation("org.slf4j:slf4j-android:1.7.36")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // SQLCipher for Android (provides net.zetetic.database.sqlcipher.* classes used by ChipDnaMobile)
    implementation("net.zetetic:sqlcipher-android:4.9.0")
    implementation("androidx.sqlite:sqlite:2.3.1")

    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("com.google.android.material:material:1.13.0")

    implementation("com.google.code.gson:gson:2.10.1")

    // ✅ Correct Networking Versions
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.retrofit2:converter-scalars:2.9.0")
    implementation("com.squareup.okhttp3:okhttp:4.9.3")
    implementation("io.reactivex.rxjava3:rxjava:3.1.5")
    implementation("com.squareup.retrofit2:adapter-rxjava3:2.9.0")
    implementation("com.squareup.okhttp3:okhttp-urlconnection:4.9.3")   // ✅ ADD THIS

    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("com.google.android.play:integrity:1.6.0")
}

flutter {
    source = "../.."
}