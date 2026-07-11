allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some plugins (e.g. audioplayers_android 4.0.3) hardcode an old compileSdk (33)
// that is incompatible with their own transitive AndroidX dependencies under the
// release AAR-metadata check. Force every Android subproject to compile against a
// modern SDK. This only affects compile-time APIs, not minSdk/targetSdk.
// Reflection keeps this resilient across Android Gradle Plugin DSL changes.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        val target = 36
        val setCompileSdk = android.javaClass.methods.firstOrNull { m ->
            m.name == "setCompileSdk" && m.parameterCount == 1 &&
                m.parameterTypes[0] == Integer::class.java
        }
        if (setCompileSdk != null) {
            setCompileSdk.invoke(android, target)
        } else {
            android.javaClass.methods.firstOrNull { m ->
                m.name == "setCompileSdkVersion" && m.parameterCount == 1 &&
                    m.parameterTypes[0] == Int::class.javaPrimitiveType
            }?.invoke(android, target)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
