group = "com.wesleymoy.telegram_login_oidc_flutter"
version = "1.0-SNAPSHOT"

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.wesleymoy.telegram_login_oidc_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 23
        // Seed the custom-scheme placeholder so consuming apps don't need to set
        // it unless they want a scheme other than their package name.
        manifestPlaceholders["telegramAndroidScheme"] = "\${applicationId}"
    }


}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("org.telegram:login-sdk:1.0.0")
}
