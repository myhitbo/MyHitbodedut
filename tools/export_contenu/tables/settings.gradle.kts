// Projet autonome, hors de android/ : le code Kotlin de l'app sur la JVM seule
// (ios/PORTAGE.md § 4.2, étape 3 ; ios/ROADMAP.md, tâches 6 et 11).
pluginManagement { repositories { gradlePluginPortal(); mavenCentral() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { mavenCentral(); google() }
}
rootProject.name = "tables"
