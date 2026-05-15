allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        android?.apply {
            if (namespace == null) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val manifestXml = manifestFile.readText()
                    val packageMatch = Regex("package=\"([^\"]+)\"").find(manifestXml)
                    if (packageMatch != null) {
                        namespace = packageMatch.groupValues[1]
                        val newXml = manifestXml.replace(Regex("package=\"[^\"]+\""), "")
                        manifestFile.writeText(newXml)
                    }
                }
                if (namespace == null) {
                    val group = project.group.toString()
                    if (group.isNotEmpty() && group != "unspecified") {
                        namespace = group
                    } else {
                        namespace = "com.alekta.pinakapos.${project.name.replace("-", ".")}"
                    }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
