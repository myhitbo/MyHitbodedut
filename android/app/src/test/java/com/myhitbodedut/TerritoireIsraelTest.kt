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

    // Audit du 12/11, FCALENDRIER-06 : la région choisie à la main survit aux reprises de la position.

    @Test
    fun `une reprise de la position garde la region choisie a la main`() {
        val (lat, lon) = dedans.getValue("Jérusalem")
        val paris = dehors.getValue("Paris")
        // Bascule manuelle puis reprise silencieuse : rien à écrire, la région ne bouge pas.
        assertNull(TerritoireIsrael.regionPourPosition(lat, lon, manuelle = true, reprise = true))
        assertNull(TerritoireIsrael.regionPourPosition(paris.first, paris.second, manuelle = true, reprise = true))
        // Sans choix manuel, la région suit la position, reprise ou non (16/10).
        assertEquals(true, TerritoireIsrael.regionPourPosition(lat, lon, manuelle = false, reprise = true))
        assertEquals(false, TerritoireIsrael.regionPourPosition(paris.first, paris.second, manuelle = false, reprise = true))
        // Choisir le lieu redéduit la région, même réglée à la main.
        assertEquals(true, TerritoireIsrael.regionPourPosition(lat, lon, manuelle = true, reprise = false))
        assertEquals(false, TerritoireIsrael.regionPourPosition(paris.first, paris.second, manuelle = true, reprise = false))
    }

    @Test
    fun `le choix manuel est memorise, sauvegarde, et seul un choix de lieu l efface`() {
        fun lire(nom: String) = File("src/main/java/com/myhitbodedut/$nom").readText()
        val store = lire("Store.kt")
        // La région et son drapeau s'écrivent ensemble : toute région déduite efface le choix manuel.
        assertTrue(store.contains("putBoolean(KEY_IN_ISRAEL, value).putBoolean(KEY_IN_ISRAEL_MANUEL, manuel)"))
        // Une reprise : le lieu était déjà la position du téléphone, et on ne vient pas de la choisir.
        val position = store.substringAfter("fun setLieuPosition(").substringBefore("\n    }")
        assertTrue(position.contains("val reprise = !choisie && lieuZmanim(context) != null && lieuVille(context) == -1L"))
        assertTrue(position.contains("TerritoireIsrael.regionPourPosition(lieu.latitude, lieu.longitude, inIsraelManuel(context), reprise)"))
        // L'export et l'import portent le drapeau.
        assertTrue(store.substringAfter("fun exportJson").substringBefore("fun importJson").contains(".put(\"in_israel_manuel\", inIsraelManuel(context))"))
        assertTrue(store.substringAfter("fun importJson").contains("manuel = settings.optBoolean(\"in_israel_manuel\", inIsraelManuel(context))"))
        // Les réglages : la bascule est un choix manuel.
        assertTrue(lire("SettingsActivity.kt").contains("Store.setInIsrael(this, !Store.inIsrael(this), manuel = true)"))
        // La position ne réécrit plus la région qu'en passant par Store.setLieuPosition ; seule la liste des lieux « choisit ».
        val choix = lire("ChoixLieu.kt")
        assertFalse(choix.contains("Store.setInIsrael("))
        assertTrue(choix.contains("Store.setLieuPosition(context, lieu, choisie)"))
        assertTrue(choix.contains("if (i == 0) demanderPosition(choisie = true)"))
        assertTrue(choix.substringAfter("fun rafraichir()").substringBefore("localiser()").contains("choisie = false"))
        assertTrue(choix.substringAfter("fun reprendreEnFond(").contains("enregistrerPosition(context, connue)"))
    }
}
