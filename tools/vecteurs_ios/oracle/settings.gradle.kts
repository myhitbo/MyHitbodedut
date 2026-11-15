// Projet autonome, hors de android/ : le code Kotlin de l'app sur la JVM seule
// (ios/PORTAGE.md § 3.9 et § 4.2 ; ios/ROADMAP.md, tâche 7).
pluginManagement { repositories { gradlePluginPortal(); mavenCentral() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { mavenCentral(); google() }
}
rootProject.name = "oracle"
