allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
subprojects {
    val subproject = this
    subproject.afterEvaluate {
        if (subproject.hasProperty("android")) {
            val androidExt = subproject.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            if (androidExt.namespace == null) {
                val groupId = subproject.group.toString()
                if (groupId.isNotEmpty()) {
                    androidExt.namespace = groupId
                }
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


