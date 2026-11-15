// Projet autonome, hors de android/ : le code Kotlin de l'app sur la JVM seule, oracle des tests
// Swift de ios/Paquets/Coeur (ios/ROADMAP.md, tâche 7 et suivantes).
pluginManagement { repositories { gradlePluginPortal(); mavenCentral() } }
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { mavenCentral(); google() }
}
rootProject.name = "vecteurs_ios"
