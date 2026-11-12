plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val formalAndroid = providers.gradleProperty("lumacraftAndroidRelease").orNull == "true"
val formalVersionName = providers.gradleProperty("lumacraftAndroidVersionName").orElse("0.21.0")
val formalVersionCode = providers.gradleProperty("lumacraftAndroidVersionCode").orElse("84")

val p612 = providers.gradleProperty("lumacraftP612").isPresent
val p611 = p612 || providers.gradleProperty("lumacraftP611").isPresent
val p610 = p611 || providers.gradleProperty("lumacraftP610").isPresent
val p69 = p610 || providers.gradleProperty("lumacraftP69").isPresent
val p68 = p69 || providers.gradleProperty("lumacraftP68").isPresent
val p67 = p68 || providers.gradleProperty("lumacraftP67").isPresent
val p66 = p67 || providers.gradleProperty("lumacraftP66").isPresent
val p65 = p66 || providers.gradleProperty("lumacraftP65").isPresent
val p64 = p65 || providers.gradleProperty("lumacraftP64").isPresent
val p63 = p64 || providers.gradleProperty("lumacraftP63").isPresent
val p6Patch = p63 || providers.gradleProperty("lumacraftP6Patch").isPresent
val p6Ui = p6Patch || providers.gradleProperty("lumacraftP6Ui").isPresent
val p5Patch = p6Ui || providers.gradleProperty("lumacraftP5Patch").isPresent
val p5 = p5Patch || providers.gradleProperty("lumacraftP5").isPresent
val betaUi = providers.gradleProperty("lumacraftP4Ui").isPresent
val beta = p5 || betaUi || providers.gradleProperty("lumacraftP4").isPresent
val alpha = beta || providers.gradleProperty("lumacraftP3").isPresent

android {
    namespace = "com.example.lumacraft"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (formalAndroid) "io.github.enderbull.lumacraft" else "com.example.lumacraft"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = if (formalAndroid || alpha) 31 else flutter.minSdkVersion
        manifestPlaceholders["appLabel"] = when {
            formalAndroid -> "框印工坊"
            beta -> "LumaCraft Beta"
            alpha -> "LumaCraft Alpha"
            else -> "lumacraft"
        }
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = if (formalAndroid) formalVersionCode.get().toInt() else flutter.versionCode + (if (p612) 16 else if (p611) 15 else if (p610) 14 else if (p69) 13 else if (p68) 12 else if (p67) 11 else if (p66) 10 else if (p65) 9 else if (p64) 8 else if (p63) 7 else if (p6Patch) 6 else if (p6Ui) 5 else if (p5Patch) 4 else if (p5) 3 else if (betaUi) 2 else if (beta) 1 else 0)
        versionName = if (formalAndroid) formalVersionName.get() else if (p612) "${flutter.versionName}-p6.12" else if (p611) "${flutter.versionName}-p6.11" else if (p610) "${flutter.versionName}-p6.10" else if (p69) "${flutter.versionName}-p6.9" else if (p68) "${flutter.versionName}-p6.8" else if (p67) "${flutter.versionName}-p6.7" else if (p66) "${flutter.versionName}-p6.6" else if (p65) "${flutter.versionName}-p6.5" else if (p64) "${flutter.versionName}-p6.4" else if (p63) "${flutter.versionName}-p6.3" else if (p6Patch) "${flutter.versionName}-p6.2" else if (p6Ui) "${flutter.versionName}-p6.1" else if (p5Patch) "${flutter.versionName}-p5.1" else if (p5) "${flutter.versionName}-p5" else if (betaUi) "${flutter.versionName}-p4.1" else if (beta) "${flutter.versionName}-p4" else flutter.versionName
    }

    buildTypes {
        if (alpha) {
            getByName("debug") { applicationIdSuffix = ".alpha" }
            maybeCreate("profile").apply {
                applicationIdSuffix = ".alpha"
                signingConfig = signingConfigs.getByName("debug")
                matchingFallbacks.add("debug")
            }
        } else if (providers.gradleProperty("lumacraftP2").isPresent) {
            getByName("debug") { applicationIdSuffix = ".p2" }
        } else if (providers.gradleProperty("lumacraftP1").isPresent) {
            getByName("debug") { applicationIdSuffix = ".p1" }
        }
        release {
            // Formal APKs are signed locally after Gradle finishes.
            signingConfig = if (formalAndroid) null else signingConfigs.getByName("debug")
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
