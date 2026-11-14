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
}
