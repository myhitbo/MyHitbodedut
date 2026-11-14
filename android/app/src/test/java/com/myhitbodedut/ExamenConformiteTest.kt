package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * L'examen de conformité du 14/11, à la veille de la soumission à Google Play. Les
 * corrections touchent au cycle de vie et aux services : elles ne se voient qu'en lisant
 * le code, chaque garde doit exister à l'endroit où elle protège.
 */
class ExamenConformiteTest {

    private fun lire(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()

    /** Le code sans ses commentaires : un commentaire qui cite la règle ne la tient pas. */
    private fun code(f: String) = lire(f).lines()
        .filterNot { it.trim().startsWith("//") || it.trim().startsWith("*") || it.trim().startsWith("/*") }
        .joinToString("\n")

    /** Constat 9 : la garde du 13/11 n'avait protégé que GateService. */
    @Test
    fun `la seance rattrape le refus d Android de la mettre au premier plan`() {
        val service = code("SessionService.kt")
        // startForeground : un seul endroit, et jamais hors de runCatching.
        val pose = service.substringAfter("private fun startForegroundNow(): Boolean = runCatching {")
            .substringBefore("}.isSuccess")
        assertTrue("startForegroundNow() doit rattraper le refus", pose != service)
        assertEquals(
            "startForeground ne s'appelle que dans startForegroundNow()",
            Regex("""\bstartForeground\(""").findAll(service).count(),
            Regex("""\bstartForeground\(""").findAll(pose).count(),
        )
        // Refusé au démarrage : le service s'arrête sans se dire en marche et sans redemander
        // sa relance ; « Ne pas déranger » est rendu, la séance reste inscrite pour reconcilier().
        val demarrage = service.substringAfter("override fun onStartCommand").substringBefore("override fun onDestroy")
        val refus = demarrage.substringAfter("if (!startForegroundNow() && !enMarche) {", "").substringBefore("}")
        assertTrue(refus.contains("NePasDeranger.retablir(this)"))
        assertTrue(refus.contains("stopSelf()"))
        assertTrue(refus.contains("return START_NOT_STICKY"))
        assertTrue("la séance reste inscrite", !refus.contains("endSession"))
        assertTrue(
            "le service ne se dit en marche qu'une fois au premier plan",
            demarrage.indexOf("if (!startForegroundNow() && !enMarche) {") < demarrage.indexOf("enMarche = true"),
        )
    }

    /** Constat 2 (FBARRIERE-16) : le type mediaPlayback était déclaré, jamais demandé. */
    @Test
    fun `la seance se declare en lecture tant qu elle joue du son`() {
        assertTrue("la musique joue", SessionRule.joueDuSon(true, Ambiance.SILENCE))
        assertTrue("une ambiance joue", SessionRule.joueDuSon(false, Ambiance.PLUIE))
        assertTrue(SessionRule.joueDuSon(true, Ambiance.MER))
        assertTrue("ni musique ni ambiance", !SessionRule.joueDuSon(false, Ambiance.SILENCE))

        val service = code("SessionService.kt")
        val pose = service.substringAfter("private fun startForegroundNow(): Boolean = runCatching {")
            .substringBefore("}.isSuccess")
        // Le type lecture se demande seulement quand du son joue, et jamais sans repli.
        assertTrue(pose.contains("SessionRule.joueDuSon(Store.musicEnabled(this), AmbiancePlayer.choisie(this))"))
        assertTrue(pose.contains("FOREGROUND_SERVICE_TYPE_SPECIAL_USE or ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK"))
        val essai = pose.substringAfter("lectureRefusee = runCatching {").substringBefore("}.isFailure")
        assertTrue("le type lecture est essayé sous runCatching", essai.contains("FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK"))
        val repli = pose.substringAfter("if (!lecture || lectureRefusee) {").substringBefore("}")
        assertTrue("refusé, la séance repart sous usage spécial seul", repli.contains("FOREGROUND_SERVICE_TYPE_SPECIAL_USE)"))
        assertTrue("refusé, il n'est pas redemandé à chaque tour", pose.contains("!lectureRefusee &&"))
        val demarrage = service.substringAfter("override fun onStartCommand").substringBefore("override fun onDestroy")
        assertTrue("chaque commande le redemande", demarrage.contains("lectureRefusee = false"))

        // Le manifeste déclare ce que le code demande, et la permission qui va avec.
        val manifeste = File("src/main/AndroidManifest.xml").readText()
        val seance = manifeste.substringAfter("android:name=\".SessionService\"").substringBefore("</service>")
        assertTrue(seance.contains("android:foregroundServiceType=\"specialUse|mediaPlayback\""))
        assertTrue(manifeste.contains("android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"))
    }

    /** Constat 8 : l'accueil analysait 1,1 Mo de JSON sur le fil principal, sous la présentation. */
    @Test
    fun `l accueil lit ses fichiers hors du fil principal et ne se dessine pas sous la presentation`() {
        val accueil = code("MainActivity.kt")
        val reprise = accueil.substringAfter("override fun onResume() {").substringBefore("\n    }\n")
        val prechauffe = reprise.indexOf("Data.prechauffer(this)")
        val sortie = reprise.indexOf("if (presentationLancee) {")
        assertTrue("onResume lance la lecture hors du fil principal", prechauffe >= 0)
        assertTrue("avant de rendre la main sous la présentation", sortie > prechauffe)
        assertTrue("les services et les alarmes passent toujours", reprise.indexOf("SessionService.reconcilier(this)") in 0 until sortie)
        assertTrue(reprise.indexOf("applyServiceState()") in 0 until sortie)
        assertTrue("rien n'est dessiné sous la présentation", reprise.indexOf("refresh()", sortie) > reprise.indexOf("return", sortie))
        val presentation = accueil.substringAfter("private fun showOnboardingOnce() {").substringBefore("\n    }\n")
        assertTrue(presentation.indexOf("presentationLancee = true") in 0 until presentation.indexOf("startActivity(Intent(this, OnboardingActivity"))

        // Ce qui lit le siddour, la bibliothèque ou le Tikoun n'est appelé que données prêtes.
        val rendu = accueil.substringAfter("private fun refresh() {").substringBefore("\n    }\n")
        assertTrue(rendu.contains("if (Data.pret) renderDonnees()"))
        val donnees = accueil.substringAfter("private fun renderDonnees() {").substringBefore("\n    }\n")
        listOf("RepriseFavoris.lignes(", "AccueilMoment.cartes(", "SourceDuJour.carte(", "renderTikkun()").forEach { appel ->
            assertTrue("$appel dans renderDonnees", donnees.contains(appel))
            assertEquals("$appel nulle part ailleurs", 1, Regex("(?<!fun )" + Regex.escape(appel)).findAll(accueil).count())
        }

        // La lecture : sur son fil, marquée prête même en échec (l'accueil réessaie alors sur place).
        val data = code("ChizukCard.kt")
        val lecture = data.substringAfter("fun prechauffer(context: Context, apres: (() -> Unit)? = null) {")
            .substringBefore("\n    }\n")
        assertTrue(lecture.contains("if (pret) return"))
        val tache = lecture.substringAfter("fil.execute {")
        listOf("siddur(app)", "library(app)", "tikkun(app)").forEach { assertTrue(it, tache.contains(it)) }
        assertTrue(tache.indexOf("pret = true") > tache.indexOf("tikkun(app)"))
        assertTrue(tache.contains("Looper.getMainLooper()"))
    }

    /** Constat 10 : sous Android 17, le son de fin partait au moment où le service quittait le premier plan. */
    @Test
    fun `le son de fin se joue service encore au premier plan`() {
        val service = code("SessionService.kt")
        val fin = service.substringAfter("private fun finishSession(early: Boolean) {").substringBefore("\n    }\n")
        val masque = fin.substringAfter("if (!early && Store.hideCountdown(this)) {")
        assertTrue("« Ne pas déranger » rendu avant le son", masque.indexOf("NePasDeranger.retablir(this)") in 0 until masque.indexOf("chime()"))
        val son = masque.substringAfter("if (chime()) {").substringBefore("}")
        assertTrue("le tour de 5 s ne clôt pas une seconde fois", son.contains("handler.removeCallbacks(tick)"))
        assertTrue(son.contains("handler.postDelayed(finDuSon, DUREE_SON_MS)"))
        assertTrue("l'arrêt attend la fin du son", son.contains("return") && !son.contains("stopSelfAndClear"))
        assertTrue(Regex("""DUREE_SON_MS = \d_000L""").containsMatchIn(service))
        // Le délai ne coupe pas une séance neuve, et ne survit pas au service.
        val apres = service.substringAfter("private val finDuSon = Runnable {").substringBefore("}")
        assertTrue(apres.contains("if (!Store.hasSessionRecord(this)) stopSelfAndClear()"))
        assertTrue(service.substringAfter("override fun onDestroy()").substringBefore("super.onDestroy()").contains("handler.removeCallbacks(finDuSon)"))
        assertTrue("chime() dit si le son est parti", service.contains("private fun chime(): Boolean"))
    }

    /** Constat 12 : sans application Fichiers, ouvrir le sélecteur fermait l'application. */
    @Test
    fun `le selecteur de fichiers est toujours garde`() {
        val contrat = Regex("""val (\w+) =\s*registerForActivityResult\(ActivityResultContracts\.(OpenDocument|CreateDocument|OpenMultipleDocuments|OpenDocumentTree|GetContent)\b""")
        var lanceurs = 0
        File("src/main/java/com/myhitbodedut").listFiles { f -> f.extension == "kt" }!!.forEach { f ->
            val texte = code(f.name)
            contrat.findAll(texte).map { it.groupValues[1] }.forEach { nom ->
                lanceurs++
                val appels = texte.lines().filter { it.contains("$nom.launch(") }
                assertTrue("${f.name} : $nom n'est jamais lancé", appels.isNotEmpty())
                appels.forEach { assertTrue("${f.name} : $it", it.contains("runCatching { $nom.launch(")) }
            }
        }
        assertEquals("pickAudio, exportFile, importFile, choixBillet", 4, lanceurs)
        listOf("values", "values-en", "values-iw").forEach { d ->
            assertTrue(d, File("src/main/res/$d/strings.xml").readText().contains("name=\"fichiers_absents\""))
        }
    }

    /** Constat 11 : la mémoire vidée par Android faisait réanalyser le livre ouvert sur le fil principal. */
    @Test
    fun `l ecran de lecture garde son livre`() {
        val lecture = code("SiddurLectureActivity.kt")
        val recueil = lecture.substringAfter("private fun recueil(): Siddur =").substringBefore("\n\n")
        assertTrue("le livre gardé sert d'abord", recueil.contains("if (livre) livreOuvert ?: (Data.livre(this, id)"))
        assertTrue("un livre vide (introuvable) n'est pas gardé", recueil.contains("if (it.textes.isNotEmpty()) livreOuvert = it"))
        assertTrue("le siddour suit toujours le nusah choisi", recueil.contains("else Data.siddur(this)"))
        assertEquals("Data.livre n'est lu qu'ici et dans le chargement hors du fil principal", 2,
            Regex("""Data\.livre\(""").findAll(lecture).count())
    }
}
