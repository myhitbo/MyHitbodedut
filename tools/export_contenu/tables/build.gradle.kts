// Les tables écrites dans le Kotlin d'Android, rendues en JSON pour iOS (ios/PORTAGE.md § 4.1 C,
// § 4.2 étape 3). Les fichiers de l'app sont compilés tels quels depuis android/, avec des bouchons
// pour ce qu'Android fournirait (R, annotations, Context) ; rien n'est recopié à la main.
//
// Propriétés passées par export.py :
//   -Pconstruction=<dossier>  la construction, hors du dépôt
//   -Pgenere=<dossier>        R.kt, généré d'après res/ (identifiants → noms de ressources)
//   -Pjava=<dossier>          les sources Kotlin de l'app (android/app/src/main/java/com/myhitbodedut)
plugins {
    kotlin("jvm") version "2.0.21"
    application
}

val construction = providers.gradleProperty("construction").orNull
if (construction != null) layout.buildDirectory.set(file(construction))
val java = file(providers.gradleProperty("java").getOrElse("../../../android/app/src/main/java/com/myhitbodedut"))
val genere = file(providers.gradleProperty("genere").getOrElse("build/genere"))

// Les fichiers de l'app qui portent une table (§ 4.1 C) ou la recherche (étape 8), et ce qu'ils
// appellent. Un fichier qui importe android.* au-delà de Context n'y entre pas : il a son bouchon.
val FICHIERS = listOf(
    // Tables.
    "Hitbodedut", "Paliers", "Trophees", "Tehilim", "Tikkun", "Tefilot", "Theme", "QuestionsBlocage",
    "Onboarding", "Tips", "YalkutYosef", "Halakha", "CalendrierJuif", "Zmanim", "Reference", "SaisieVol",
    "TerritoireIsrael", "DirectionJerusalem", "Character", "MusiquePlay",
    // La recherche.
    "RechercheGlobale", "Siddur", "Hilloulot", "LivresBruts",
    // Ce qu'ils appellent.
    "Json", "Chizuk", "Library", "Vol", "Aeroports", "RouteVol", "SuiviVol",
)

val sourcesApp = tasks.register<Sync>("sourcesApp") {
    from(java) { include(FICHIERS.map { "$it.kt" }) }
    into(layout.buildDirectory.dir("sources/app"))
    doLast {
        val manquants = FICHIERS.filter { !File(java, "$it.kt").exists() }
        if (manquants.isNotEmpty()) throw GradleException("fichiers de l'app introuvables : $manquants")
    }
}

kotlin {
    sourceSets.main {
        kotlin.srcDir(sourcesApp)
        kotlin.srcDir("src")
        kotlin.srcDir("bouchons")
        kotlin.srcDir(genere)
    }
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}
java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    // Les mêmes versions qu'android/app/build.gradle.kts.
    implementation("com.kosherjava:zmanim:2.5.0")
    // org.json : celui d'Android (AOSP), que la fondation Apache republie avec Geode (licence Apache 2.0).
    // Il garde l'ordre des clés du fichier, comme sur l'appareil ; org.json:json, celui des tests
    // d'Android sur la JVM, les mélange (HashMap), et l'ordre décide des 30 premiers résultats.
    implementation("org.apache.geode:geode-json:1.6.0")
}

application {
    mainClass.set("com.myhitbodedut.TablesKt")
    applicationDefaultJvmArgs = listOf("-Dfile.encoding=UTF-8", "-Dstdout.encoding=UTF-8")
}
