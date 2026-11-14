// Le code Kotlin de l'app Android, compilé et exécuté sur la JVM seule, sans SDK ni appareil,
// pour qu'iOS se mesure à ce qu'Android répond vraiment (ios/PORTAGE.md § 4.2 étape 3 et § 5.1).
//
//   vecteurs  écrit ios/Paquets/Coeur/Tests/Vecteurs/*.json : ce que répond le code d'Android,
//             cas par cas ; les tests Swift de Coeur doivent rendre la même chose
//   (tables.json, les tables écrites dans le Kotlin, viendra ici avec la tâche 6 de ROADMAP.md)
//
// Les sources d'Android sont lues en place, jamais copiées ni modifiées.
// Les sources d'Android compilées sont celles de fichiers.txt : les règles, pas les écrans.
// Quatre bouchons : la classe R, engendrée d'après res/ ; android.jar rendu docile (ses méthodes
// rendent zéro, faux ou null au lieu de lever « Stub! », comme le fait Android Gradle Plugin pour
// les tests unitaires) ; un Context de théâtre (préférences en mémoire, vraies ressources) ; des
// coquilles pour ce que les règles nomment d'androidx et des écrans (bouchons/coquilles).

import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest
import java.util.TreeSet
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import org.objectweb.asm.ClassReader
import org.objectweb.asm.ClassWriter
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type
import org.objectweb.asm.tree.ClassNode
import org.objectweb.asm.tree.InsnNode

buildscript {
    repositories { mavenCentral() }
    dependencies { classpath("org.ow2.asm:asm-tree:9.7.1") }
}

plugins { kotlin("jvm") version "2.0.21" }

val depot: File = rootDir.resolve("../../..").canonicalFile
val appAndroid: File = depot.resolve("android/app/src/main")
val sourcesAndroid: File = appAndroid.resolve("java")
val res: File = appAndroid.resolve("res")
val vecteursIos: File = depot.resolve("tools/vecteurs_ios")
val sortieVecteurs: File = depot.resolve("ios/Paquets/Coeur/Tests/Vecteurs")

// -PseulVecteur=Nom : ne compile et ne lance que tools/vecteurs_ios/Nom.kt (essai d'un générateur
// sans dépendre des autres) ; -Psortie=dossier : écrit ailleurs que dans le dépôt.
val seul: String? = (findProperty("seulVecteur") as String?)?.takeIf { it.isNotBlank() }
val sortie: String = (findProperty("sortie") as String?) ?: sortieVecteurs.path
if (seul != null) layout.buildDirectory.set(layout.projectDirectory.dir("build/seul-$seul"))

// --- android.jar : les signatures d'Android 36, celles de compileSdk -------------------------
val androidJar: File = run {
    val candidats = listOfNotNull(
        System.getenv("ANDROID_JAR"),
        System.getenv("ANDROID_HOME")?.let { "$it/platforms/android-36/android.jar" },
        System.getenv("ANDROID_SDK_ROOT")?.let { "$it/platforms/android-36/android.jar" },
    ).map(::File)
    candidats.firstOrNull { it.isFile } ?: rootDir.resolve("build/android-36/android.jar")
}
val telechargerAndroidJar by tasks.registering {
    description = "Télécharge android.jar (plateforme 36) s'il n'est fourni ni par ANDROID_JAR ni par ANDROID_HOME."
    val cible = androidJar
    outputs.file(cible)
    onlyIf { !cible.isFile }
    doLast {
        val adresse = "https://dl.google.com/android/repository/platform-36_r02.zip"
        val attendu = "37607369a28c5b640b3a7998868d45898ebcb777565a0e85f9acf36f29631d2e"
        val zip = File(temporaryDir, "platform.zip")
        uri(adresse).toURL().openStream().use { entree -> zip.outputStream().use { entree.copyTo(it) } }
        val empreinte = MessageDigest.getInstance("SHA-256").digest(zip.readBytes()).joinToString("") { "%02x".format(it) }
        check(empreinte == attendu) { "platform-36_r02.zip : empreinte $empreinte, attendue $attendu" }
        cible.parentFile.mkdirs()
        ZipFile(zip).use { z ->
            z.getInputStream(z.getEntry("android-36/android.jar")).use { entree -> cible.outputStream().use { entree.copyTo(it) } }
        }
        zip.delete()
    }
}

// --- android.jar docile : mêmes signatures, mais plus rien n'y lève « Stub! » ------------------
// Ce que fait MockableJarGenerator d'Android Gradle Plugin (unitTests.isReturnDefaultValues) :
// classes et méthodes ne sont plus finales, chaque méthode rend la valeur par défaut de son type,
// chaque constructeur s'arrête après l'appel de son parent. Les énumérations restent intactes.
val androidDocile: File = rootDir.resolve("build/android-36/android-docile.jar")

fun rendreDocile(octets: ByteArray): ByteArray {
    val classe = ClassNode()
    ClassReader(octets).accept(classe, 0)
    val enumeration = classe.access and Opcodes.ACC_ENUM != 0
    classe.access = classe.access and Opcodes.ACC_FINAL.inv()
    for (m in classe.methods) {
        if (m.name == "<clinit>") continue
        if (enumeration && (m.name == "<init>" || m.name == "values" || m.name == "valueOf")) continue
        m.access = m.access and Opcodes.ACC_FINAL.inv()
        if (m.access and (Opcodes.ACC_NATIVE or Opcodes.ACC_ABSTRACT) != 0) continue
        m.tryCatchBlocks?.clear()
        m.localVariables?.clear()
        if (m.name == "<init>") {
            var apresParent = false
            for (instruction in m.instructions.toArray()) {
                if (apresParent) m.instructions.remove(instruction)
                else if (instruction.opcode == Opcodes.INVOKESPECIAL) {
                    m.instructions.insert(instruction, InsnNode(Opcodes.RETURN))
                    apresParent = true
                }
            }
        } else {
            m.instructions.clear()
            val rendu = Type.getReturnType(m.desc)
            when (rendu.sort) {
                Type.VOID -> {}
                Type.BOOLEAN, Type.BYTE, Type.CHAR, Type.SHORT, Type.INT -> m.instructions.add(InsnNode(Opcodes.ICONST_0))
                Type.LONG -> m.instructions.add(InsnNode(Opcodes.LCONST_0))
                Type.FLOAT -> m.instructions.add(InsnNode(Opcodes.FCONST_0))
                Type.DOUBLE -> m.instructions.add(InsnNode(Opcodes.DCONST_0))
                else -> m.instructions.add(InsnNode(Opcodes.ACONST_NULL))
            }
            m.instructions.add(InsnNode(rendu.getOpcode(Opcodes.IRETURN)))
        }
    }
    val ecrivain = ClassWriter(ClassWriter.COMPUTE_MAXS)
    classe.accept(ecrivain)
    return ecrivain.toByteArray()
}

val androidJarDocile by tasks.registering {
    description = "Écrit android-docile.jar : android.jar dont les méthodes rendent une valeur par défaut."
    dependsOn(telechargerAndroidJar)
    val source = androidJar
    val cible = androidDocile
    inputs.property("source", source.path)
    outputs.file(cible)
    doLast {
        cible.parentFile.mkdirs()
        val provisoire = File(cible.parentFile, "${cible.name}.${System.nanoTime()}.tmp")
        ZipInputStream(source.inputStream().buffered()).use { entree ->
            ZipOutputStream(provisoire.outputStream().buffered()).use { sortie ->
                while (true) {
                    val e = entree.nextEntry ?: break
                    if (e.isDirectory) continue
                    val octets = entree.readBytes()
                    sortie.putNextEntry(ZipEntry(e.name).apply { time = 0L })
                    sortie.write(if (e.name.endsWith(".class")) rendreDocile(octets) else octets)
                    sortie.closeEntry()
                }
            }
        }
        Files.move(provisoire.toPath(), cible.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
    }
}

// --- org.json comme sur un téléphone --------------------------------------------------------------
// Le org.json d'Android (AOSP), que l'artefact android-json reprend dans son état de 2013 : mêmes
// conversions de opt* et mêmes échappements que sur un téléphone, ce que n'a pas le org.json de
// json.org qu'emploient les tests unitaires d'Android. Depuis, Android range les clés d'un objet dans
// l'ordre où elles sont écrites (LinkedHashMap) : la classe JSONObject est retouchée pour faire de même.
val jsonAosp: Configuration by configurations.creating
val jsonAndroid: File = rootDir.resolve("build/android-36/android-json-ordonne.jar")
val jsonCommeAndroid by tasks.registering {
    description = "Écrit android-json-ordonne.jar : le org.json d'Android, clés gardées dans l'ordre d'écriture."
    val source = jsonAosp
    val cible = jsonAndroid
    inputs.files(source)
    outputs.file(cible)
    doLast {
        cible.parentFile.mkdirs()
        val provisoire = File(cible.parentFile, "${cible.name}.${System.nanoTime()}.tmp")
        var retouches = 0
        ZipInputStream(source.singleFile.inputStream().buffered()).use { entree ->
            ZipOutputStream(provisoire.outputStream().buffered()).use { sortie ->
                while (true) {
                    val e = entree.nextEntry ?: break
                    if (e.isDirectory) continue
                    var octets = entree.readBytes()
                    if (e.name == "org/json/JSONObject.class") {
                        val classe = ClassNode()
                        ClassReader(octets).accept(classe, 0)
                        for (m in classe.methods) for (i in m.instructions) {
                            if (i is org.objectweb.asm.tree.TypeInsnNode && i.opcode == Opcodes.NEW && i.desc == "java/util/HashMap") {
                                i.desc = "java/util/LinkedHashMap"; retouches++
                            }
                            if (i is org.objectweb.asm.tree.MethodInsnNode && i.owner == "java/util/HashMap" && i.name == "<init>") {
                                i.owner = "java/util/LinkedHashMap"
                            }
                        }
                        val ecrivain = ClassWriter(0)
                        classe.accept(ecrivain)
                        octets = ecrivain.toByteArray()
                    }
                    sortie.putNextEntry(ZipEntry(e.name).apply { time = 0L })
                    sortie.write(octets)
                    sortie.closeEntry()
                }
            }
        }
        check(retouches > 0) { "JSONObject : aucune table de hachage à remplacer, l'artefact a changé" }
        Files.move(provisoire.toPath(), cible.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE)
    }
}

// --- R : les identifiants de ressources, engendrés d'après res/ --------------------------------
val dossierR = layout.buildDirectory.dir("engendre/r")
val engendrerR by tasks.registering {
    description = "Engendre com.myhitbodedut.R et la table identifiant → nom d'après android/app/src/main/res."
    inputs.dir(res)
    outputs.dir(dossierR)
    doLast {
        val noms = sortedMapOf<String, TreeSet<String>>()
        fun ajoute(type: String, nom: String) { noms.getOrPut(type) { TreeSet() }.add(nom.replace('.', '_')) }
        val declare = Regex("""<(string|plurals|string-array|integer-array|array|color|dimen|style|integer|bool|attr|declare-styleable|item)\b([^>]*)>""")
        val nomAttr = Regex("""\bname="([^"]+)"""")
        val typeAttr = Regex("""\btype="([^"]+)"""")
        val idNeuf = Regex("""@\+id/(\w+)""")
        res.listFiles()!!.filter { it.isDirectory }.sortedBy { it.name }.forEach { dossier ->
            val type = dossier.name.substringBefore('-')
            dossier.listFiles()!!.filter { it.isFile }.sortedBy { it.name }.forEach { f ->
                if (type == "values") {
                    val xml = f.readText().replace(Regex("<!--.*?-->", RegexOption.DOT_MATCHES_ALL), "")
                    for (m in declare.findAll(xml)) {
                        val nom = nomAttr.find(m.groupValues[2])?.groupValues?.get(1) ?: continue
                        when (val balise = m.groupValues[1]) {
                            "string-array", "integer-array" -> ajoute("array", nom)
                            "declare-styleable" -> ajoute("styleable", nom)
                            "item" -> typeAttr.find(m.groupValues[2])?.groupValues?.get(1)?.let { ajoute(it, nom) }
                            else -> ajoute(balise, nom)
                        }
                    }
                } else {
                    ajoute(type, f.name.substringBefore('.'))
                    if (f.extension == "xml") idNeuf.findAll(f.readText()).forEach { ajoute("id", it.groupValues[1]) }
                }
            }
        }
        val java = StringBuilder("package com.myhitbodedut;\n\n/** Engendré par tools/export_contenu/tables : ne pas modifier. */\npublic final class R {\n")
        val table = StringBuilder()
        noms.entries.forEachIndexed { t, (type, liste) ->
            java.append("    public static final class ").append(type.replace('-', '_')).append(" {\n")
            liste.forEachIndexed { i, nom ->
                val id = 0x7f000000 or ((t + 1) shl 16) or (i + 1)
                java.append("        public static final int ").append(nom).append(" = 0x").append(Integer.toHexString(id)).append(";\n")
                table.append(type).append('\t').append(nom).append('\t').append(id).append('\n')
            }
            java.append("    }\n")
        }
        java.append("}\n")
        val racine = dossierR.get().asFile
        racine.resolve("java/com/myhitbodedut").apply { mkdirs() }.resolve("R.java").writeText(java.toString())
        racine.resolve("ressources").apply { mkdirs() }.resolve("r_noms.tsv").writeText(table.toString())
    }
}

// --- Ce qui se compile ---------------------------------------------------------------------------
// La liste des fichiers d'Android compilés ici : fichiers.txt, un nom par ligne (« # » : commentaire).
val compiles: Set<String> = file("fichiers.txt").readLines().map { it.substringBefore('#').trim() }.filter { it.isNotEmpty() }
    .map { "$it.kt" }.toSet()
val paquet: File = sourcesAndroid.resolve("com/myhitbodedut")
compiles.filterNot { paquet.resolve(it).isFile }.let { check(it.isEmpty()) { "fichiers.txt nomme des fichiers absents d'Android : $it" } }

// Les trois recopies de bouchons/coquilles/Ecrans.kt doivent encore se lire, mot pour mot, dans le
// fichier d'Android dont elles viennent : sinon la construction s'arrête et dit laquelle revoir.
val copies = mapOf(
    "ReglagesLecture.kt" to listOf("const val MIN = 0.8f", "const val MAX = 2.0f"),
    "HalakhaActivity.kt" to listOf(
        """fun source(h: Halakha.Choisie): String =""",
        """listOf("בן איש חי", if (h.annee == 1) "שנה ראשונה" else "שנה שנייה", h.section, "אות ${'$'}{Reference.lettres(h.numero)}")""",
        """.joinToString(" · ")""",
    ),
    "VueJour.kt" to listOf(
        """fun usageLevana(c: Context): Levana.Usage = Store.levanaUsage(c) ?: Levana.Usage.duNusah(Store.siddurNusah(c).cle)""",
    ),
)
val verifierCopies by tasks.registering {
    description = "Vérifie que les recopies des bouchons sont encore dans les sources d'Android."
    inputs.files(copies.keys.map { paquet.resolve(it) })
    val attendues = copies
    val dossier = paquet
    doLast {
        for ((fichier, extraits) in attendues) {
            val texte = dossier.resolve(fichier).readText()
            for (extrait in extraits) check(extrait in texte) {
                "$fichier ne contient plus « $extrait » : revoir sa recopie dans bouchons/coquilles/Ecrans.kt"
            }
        }
    }
}

sourceSets.main {
    kotlin.srcDir(sourcesAndroid)
    // La liste des morceaux de la version Play, la seule qu'iOS livre (liste « hors Play » vide).
    kotlin.srcDir(depot.resolve("android/app/src/musique_play/java"))
    kotlin.srcDir("bouchons")
    kotlin.srcDir(vecteursIos)
    kotlin.exclude { it.file.parentFile == paquet && it.name !in compiles }
    if (seul != null) {
        kotlin.exclude { it.file.parentFile == vecteursIos && it.name.startsWith("Vecteurs") && it.name != "VecteursIos.kt" && it.name != "$seul.kt" }
    }
    java.srcDir(dossierR.map { it.dir("java") })
    resources.srcDir(dossierR.map { it.dir("ressources") })
}

dependencies {
    jsonAosp("com.vaadin.external.google:android-json:0.0.20131108.vaadin1")
    // À l'exécution seulement : la compilation lit les signatures de org.json dans android.jar, celles d'aujourd'hui.
    runtimeOnly(files(jsonAndroid).builtBy(jsonCommeAndroid))
    implementation("com.kosherjava:zmanim:2.5.0")
    implementation("androidx.annotation:annotation-jvm:1.9.1")
    implementation(files(androidDocile).builtBy(androidJarDocile))
}

java { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) } }
tasks.named("compileKotlin") { dependsOn(engendrerR, androidJarDocile, verifierCopies) }
tasks.named("compileJava") { dependsOn(engendrerR) }
tasks.named("processResources") { dependsOn(engendrerR) }

// Mêmes réponses sur toute machine : fuseau, langue et encodage fixés.
fun JavaExec.cadre() {
    // android.jar en dernier : ses coquilles (org.json compris) ne doivent jamais passer devant une vraie classe.
    val tout = sourceSets.main.get().runtimeClasspath
    classpath = tout.filter { it != androidDocile } + files(androidDocile)
    jvmArgs("-Duser.timezone=UTC", "-Duser.language=en", "-Duser.country=US", "-Dfile.encoding=UTF-8",
            "-Dstdout.encoding=UTF-8")
    systemProperty("depot", depot.path)
    environment("TZ", "UTC")
}

tasks.register<JavaExec>("vecteurs") {
    description = "Écrit les vecteurs de référence des tests Swift (un fichier par générateur de tools/vecteurs_ios)."
    cadre()
    mainClass.set("VecteursIosKt")
    val generateurs = vecteursIos.listFiles()!!.filter { it.extension == "kt" && it.name.startsWith("Vecteurs") && it.name != "VecteursIos.kt" }
        .map { it.nameWithoutExtension }.filter { seul == null || it == seul }.sorted()
    args(listOf(sortie) + generateurs)
}
