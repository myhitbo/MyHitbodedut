package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** Un réglage qui pèse sur le passé est daté (audit du 12/11, FDONNEES-05). */
class HistoriqueReglageTest {

    private val d = { s: String -> LocalDate.parse(s) }

    @Test
    fun `sans historique la valeur du moment vaut pour tous les jours`() {
        assertTrue(HistoriqueReglage.valeurLe(emptyList(), d("2026-01-01"), true))
        assertFalse(HistoriqueReglage.valeurLe(emptyList(), d("2026-01-01"), false))
    }

    @Test
    fun `un changement ne touche pas le passe`() {
        val h = HistoriqueReglage.apresChangement(emptyList(), d("2026-11-05"), false, true)
        assertFalse(HistoriqueReglage.valeurLe(h, d("2026-11-04"), true))
        assertFalse(HistoriqueReglage.valeurLe(h, d("2026-08-03"), true))
        assertTrue(HistoriqueReglage.valeurLe(h, d("2026-11-05"), true))
        assertTrue(HistoriqueReglage.valeurLe(h, d("2026-12-01"), true))
    }

    @Test
    fun `changer puis revenir le meme jour ne laisse rien de plus`() {
        val aller = HistoriqueReglage.apresChangement(emptyList(), d("2026-11-05"), false, true)
        val retour = HistoriqueReglage.apresChangement(aller, d("2026-11-05"), true, false)
        assertFalse(HistoriqueReglage.valeurLe(retour, d("2026-11-05"), false))
        assertFalse(HistoriqueReglage.valeurLe(retour, d("2026-10-01"), false))
    }

    @Test
    fun `un voyage aller-retour garde la diaspora pour les jours passes`() {
        var h = HistoriqueReglage.apresChangement(emptyList(), d("2026-10-01"), false, true) // arrivée
        h = HistoriqueReglage.apresChangement(h, d("2026-10-20"), true, false)                // retour
        assertFalse(HistoriqueReglage.valeurLe(h, d("2026-09-20"), false))
        assertTrue(HistoriqueReglage.valeurLe(h, d("2026-10-10"), false))
        assertFalse(HistoriqueReglage.valeurLe(h, d("2026-10-25"), false))
    }

    @Test
    fun `l encodage fait l aller-retour et ignore ce qui est illisible`() {
        val h = HistoriqueReglage.apresChangement(emptyList(), d("2026-11-05"), false, true)
        assertEquals("2000-01-01=0,2026-11-05=1", HistoriqueReglage.encoder(h))
        assertEquals(h, HistoriqueReglage.decoder(HistoriqueReglage.encoder(h)))
        assertEquals(h, HistoriqueReglage.decoder("n'importe quoi,2026-13-45=1,2026-11-05=x,2000-01-01=0,2026-11-05=1"))
        assertTrue(HistoriqueReglage.decoder(null).isEmpty())
    }

    @Test
    fun `un changement du futur est ecarte et la liste reste bornee`() {
        val futur = HistoriqueReglage.decoder("2000-01-01=0,2099-01-01=1")
        val h = HistoriqueReglage.apresChangement(futur, d("2026-11-05"), false, true)
        assertEquals("2000-01-01=0,2026-11-05=1", HistoriqueReglage.encoder(h))
        var long = emptyList<HistoriqueReglage.Entree>()
        var v = false
        var jour = d("2020-01-01")
        repeat(HistoriqueReglage.MAX + 50) { long = HistoriqueReglage.apresChangement(long, jour, v, !v); v = !v; jour = jour.plusDays(1) }
        assertTrue(long.size <= HistoriqueReglage.MAX)
    }

    @Test
    fun `Store date les deux reglages et isExempt s en sert`() {
        val src = File("src/main/java/com/myhitbodedut/Store.kt").readText()
        val exempt = src.substringAfter("fun isExempt").substringBefore("fun isEveOfRestDay")
        assertTrue(exempt.contains("HistoriqueReglage.valeurLe"))
        assertTrue(src.substringAfter("fun setInIsrael").substringBefore("fun ").contains("KEY_HISTO_ISRAEL"))
        assertTrue(src.substringAfter("fun setShabbatMode").substringBefore("private const").contains("KEY_HISTO_SHABBAT"))
    }
}
