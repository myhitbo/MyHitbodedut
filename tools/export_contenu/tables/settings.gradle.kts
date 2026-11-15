// Projet autonome, hors de android/ (ios/PORTAGE.md § 4.2, étape 3) : il compile des fichiers
// Kotlin purs de l'app sur la JVM, sans SDK Android, et écrit les tables. Lancé par export.py.
pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
}
dependencyResolutionManagement {
    repositories {
        mavenCentral()
    }
}
rootProject.name = "tables"
