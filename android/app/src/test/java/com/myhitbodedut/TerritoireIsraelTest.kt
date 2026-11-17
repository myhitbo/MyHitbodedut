package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** Israël ou diaspora d'après la position (16/10) : des villes de part et d'autre des frontières. */
class TerritoireIsraelTest {

    private val dedans = mapOf(
        "Jérusalem" to (31.7769 to 35.2224), "Tel Aviv" to (32.0853 to 34.7818), "Haïfa" to (32.7940 to 34.9896),
        "Eilat" to (29.5577 to 34.9519), "Beer Chéva" to (31.2518 to 34.7913), "Mitspé Ramon" to (30.6097 to 34.8019),
        "Kiryat Chmona" to (33.2073 to 35.5700), "Metoula" to (33.2770 to 35.5790), "Katsrin" to (32.9930 to 35.6900),
        "Ariel" to (32.1060 to 35.1710), "Hébron" to (31.5326 to 35.0998), "Tibériade" to (32.7922 to 35.5312),
        "Nahariya" to (33.0058 to 35.0950), "Ashkelon" to (31.6688 to 34.5743), "Ein Gedi" to (31.4500 to 35.3830),
        "Netanya" to (32.3215 to 34.8532), "Akko" to (32.9281 to 35.0818), "Bet Chéan" to (32.4973 to 35.4968),
        "Sderot" to (31.5250 to 34.5966), "Yotvata" to (29.8950 to 35.0600),
        "Ein Zivan" to (33.1060 to 35.8060), "Majdal Chams" to (33.2700 to 35.7700),
    )
    private val dehors = mapOf(
        "Amman" to (31.9539 to 35.9106), "Aqaba" to (29.5321 to 35.0063), "Beyrouth" to (33.8938 to 35.5018),
        "Tyr" to (33.2705 to 35.2038), "Damas" to (33.5138 to 36.2765), "Le Caire" to (30.0444 to 31.2357),
        "El Arich" to (31.1316 to 33.7984), "Taba" to (29.4900 to 34.8760), "Paris" to (48.8566 to 2.3522),
        "Irbid" to (32.5556 to 35.8500), "Nicosie" to (35.1856 to 33.3823), "Kerak" to (31.1800 to 35.7000),
        "Kuneitra" to (33.1256 to 35.8244),
    )

    @Test
    fun `les villes d Israel sont dedans`() = dedans.forEach { (nom, p) -> assertTrue(nom, TerritoireIsrael.contient(p.first, p.second)) }

    @Test
    fun `les villes voisines sont dehors`() = dehors.forEach { (nom, p) -> assertFalse(nom, TerritoireIsrael.contient(p.first, p.second)) }

    // Audit du 16/11 (gravité haute) : le statut pour le Yom tov chéni suit la résidence (Choul'han
    // Aroukh 496:3, Michna Beroura 496:13) ; un lieu de l'autre région pose la question, sans rien changer.
    // Il remplace la règle du 12/11 (FCALENDRIER-06), où choisir un lieu redéduisait la région.

    @Test
    fun `un lieu ne change jamais le statut, il pose la question`() {
        // Un Israélien à New York (ville ou position) : le statut reste Israël, la question est posée.
        assertEquals(TerritoireIsrael.Decision(null, false), TerritoireIsrael.decisionRegion(impliquee = false, actuelle = true, premierLieu = false, declare = false))
        assertEquals(TerritoireIsrael.Decision(null, false), TerritoireIsrael.decisionRegion(impliquee = false, actuelle = true, premierLieu = false, declare = true))
        // Un visiteur de diaspora en Israël : le statut reste diaspora.
        assertEquals(TerritoireIsrael.Decision(null, true), TerritoireIsrael.decisionRegion(impliquee = true, actuelle = false, premierLieu = false, declare = true))
        // Même région : rien à demander, et la question en attente tombe.
        assertEquals(TerritoireIsrael.Decision(null, null), TerritoireIsrael.decisionRegion(impliquee = true, actuelle = true, premierLieu = false, declare = false))
        // Le tout premier lieu d'un statut jamais choisi remplace la déduction faite du fuseau.
        assertEquals(TerritoireIsrael.Decision(true, null), TerritoireIsrael.decisionRegion(impliquee = true, actuelle = false, premierLieu = true, declare = false))
        // Un statut choisi l'emporte, même au premier lieu.
        assertEquals(TerritoireIsrael.Decision(null, true), TerritoireIsrael.decisionRegion(impliquee = true, actuelle = false, premierLieu = true, declare = true))
    }

    @Test
    fun `le statut ne s ecrit que par les reglages ou la reponse a la question`() {
        fun lire(nom: String) = File("src/main/java/com/myhitbodedut/$nom").readText()
        val store = lire("Store.kt")
        assertTrue(store.contains("putBoolean(KEY_IN_ISRAEL, value).putBoolean(KEY_IN_ISRAEL_MANUEL, manuel)"))
        // Le lieu passe par decisionRegion ; la position, par le même chemin.
        val lieu = store.substringAfter("fun setLieuZmanim(").substringBefore("\n    }")
        assertTrue(lieu.contains("TerritoireIsrael.decisionRegion(impliquee, inIsrael(context), lieuZmanim(context) == null, inIsraelManuel(context))"))
        assertTrue(lieu.contains("setRegionProposee(context, decision.proposition)"))
        assertTrue(store.substringAfter("fun setLieuPosition(").substringBefore("\n    }").contains("setLieuZmanim(context, lieu, null)"))
        // L'export et l'import portent le drapeau.
        assertTrue(store.substringAfter("fun exportJson").substringBefore("fun importJson").contains(".put(\"in_israel_manuel\", inIsraelManuel(context))"))
        assertTrue(store.substringAfter("fun importJson").contains("manuel = settings.optBoolean(\"in_israel_manuel\", inIsraelManuel(context))"))
        assertTrue(lire("SettingsActivity.kt").contains("Store.setInIsrael(this, !Store.inIsrael(this), manuel = true)"))
        assertFalse(lire("ChoixLieu.kt").contains("Store.setInIsrael("))
        // L'écran Zmanim pose la question, et la réponse est un choix.
        val zmanim = lire("ZmanimActivity.kt")
        assertTrue(zmanim.contains("Store.regionProposee(this)"))
        assertTrue(zmanim.contains("Store.setInIsrael(this@ZmanimActivity, proposee, manuel = true)"))
    }

    @Test
    fun `Yom tov cheni d un voyageur - la note`() {
        // 2026-10-04 : Sim'hat Torah en diaspora, jour ouvré en Israël (l'exemple de l'audit).
        val d = java.time.LocalDate.parse("2026-10-04")
        assertEquals("note_ytc_ben_israel", JourAffiche.noteYomTovCheni(d, statutIsrael = true, lieuEnIsrael = false, nusah = "edot"))
        assertEquals("note_ytc_ben_houl", JourAffiche.noteYomTovCheni(d, statutIsrael = false, lieuEnIsrael = true, nusah = "sefard"))
        assertEquals("note_ytc_ben_houl_ashkenaz", JourAffiche.noteYomTovCheni(d, statutIsrael = false, lieuEnIsrael = true, nusah = "ashkenaz"))
        assertNull(JourAffiche.noteYomTovCheni(d, statutIsrael = true, lieuEnIsrael = true, nusah = "edot"))
        // Un jour ordinaire : pas de note.
        assertNull(JourAffiche.noteYomTovCheni(java.time.LocalDate.parse("2026-10-14"), statutIsrael = true, lieuEnIsrael = false, nusah = "edot"))
    }
}
