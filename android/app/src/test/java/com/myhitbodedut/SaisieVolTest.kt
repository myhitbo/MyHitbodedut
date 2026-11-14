package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.Duration
import java.time.LocalDate
import java.time.LocalTime

/** La saisie rapide d'un vol (04/11) : des phrases comme on les dirait, et le code des cartes d'embarquement. */
class SaisieVolTest {

    private val aeroports = Aeroports.parse(File("src/main/res/raw/aeroports.json").readText(), File("src/main/res/raw/aeroports_noms.json").readText())
    private val mercredi = LocalDate.of(2026, 11, 4)

    private fun lire(t: String) = SaisieVol.lire(t, aeroports, mercredi)

    @Test
    fun `la phrase du proprietaire`() {
        val p = lire("je prends le vol elal Lyon tlv de demain a 11h")
        assertEquals("LY", p.compagnie)
        assertEquals("LYS", p.depart?.iata)
        assertEquals("TLV", p.arrivee?.iata)
        assertEquals(LocalDate.of(2026, 11, 5), p.date)
        assertEquals(LocalTime.of(11, 0), p.heureDepart)
        assertNull(p.numero)
    }

    @Test
    fun `numero, ville a plusieurs aeroports, date chiffree`() {
        val p = lire("LY 382 de Paris à Tel Aviv le 12/11 à 9h40")
        assertEquals("LY382", p.numero)
        assertEquals("CDG", p.depart?.iata)
        assertEquals("TLV", p.arrivee?.iata)
        assertEquals(LocalDate.of(2026, 11, 12), p.date)
        assertEquals(LocalTime.of(9, 40), p.heureDepart)
    }

    @Test
    fun `en hebreu, avec les prefixes mem et lamed`() {
        val p = lire("מחר בשעה 11 טיסת אל על מליון לתל אביב")
        assertEquals("LY", p.compagnie)
        assertEquals("LYS", p.depart?.iata)
        assertEquals("TLV", p.arrivee?.iata)
        assertEquals(LocalDate.of(2026, 11, 5), p.date)
        assertEquals(LocalTime.of(11, 0), p.heureDepart)
        val q = lire("טיסה לניו יורק מתל אביב ב-12.11 בשעה 23:45")
        assertEquals("TLV", q.depart?.iata)
        assertEquals("JFK", q.arrivee?.iata)
        assertEquals(LocalDate.of(2026, 11, 12), q.date)
    }

    @Test
    fun `en anglais, avec pm et l arrivee`() {
        val p = lire("Flight LY81 Tel Aviv to Bangkok on Nov 12 at 11:30pm, arrives 15:10")
        assertEquals("LY81", p.numero)
        assertEquals("TLV", p.depart?.iata)
        assertEquals("BKK", p.arrivee?.iata)
        assertEquals(LocalDate.of(2026, 11, 12), p.date)
        assertEquals(LocalTime.of(23, 30), p.heureDepart)
        assertEquals(LocalTime.of(15, 10), p.heureArrivee)
    }

    @Test
    fun `l heure d embarquement d un billet est ecartee`() {
        val p = lire("Boarding 10:20 Departure 11:00 LYS TLV 14 nov. 2026 Arrival 16:05")
        assertNull("« TLV 14 » n'est pas un numéro de vol", p.numero)
        assertEquals(LocalTime.of(11, 0), p.heureDepart)
        assertEquals(LocalTime.of(16, 5), p.heureArrivee)
        assertEquals(LocalDate.of(2026, 11, 14), p.date)
    }

    @Test
    fun `la duree du vol n est ni une heure ni un numero, la porte non plus (FVOL-04)`() {
        // Audit du 12/11 : « 4h25 » devenait l'heure de départ, « 4h 25m » le numéro 4H25M, « gate » effaçait le départ.
        lire("Vol AF1620 · Durée 4h25 · Paris-Charles de Gaulle (CDG) 10:35 → Tel Aviv (TLV) 16:00").let {
            assertEquals("AF1620", it.numero)
            assertEquals(LocalTime.of(10, 35), it.heureDepart)
            assertEquals(LocalTime.of(16, 0), it.heureArrivee)
        }
        lire("Flight time 4h 25m. Departs CDG 10:35 arrives TLV 16:00 on 15 Nov").let {
            assertNull(it.numero)
            assertNull(it.compagnie)
            assertEquals(LocalTime.of(10, 35), it.heureDepart)
            assertEquals(LocalTime.of(16, 0), it.heureArrivee)
        }
        lire("Boarding 5:20 gate B12 Departure 6:05 BUD TLV 15 Nov").let {
            assertNull("B12 est la porte", it.numero)
            assertEquals(LocalTime.of(6, 5), it.heureDepart)
        }
        // Israir : 6H est une compagnie, ses chiffres ne sont pas une heure.
        lire("Israir 6H 123 TLV ATH 15/11 10:35 13:00").let {
            assertEquals("6H123", it.numero)
            assertEquals(LocalTime.of(10, 35), it.heureDepart)
            assertEquals(LocalTime.of(13, 0), it.heureArrivee)
        }
        lire("Porte fermée 5h45, départ 6h05 BUD TLV 15/11").let {
            assertNull(it.numero)
            assertEquals(LocalTime.of(6, 5), it.heureDepart)
            assertNull(it.heureArrivee)
        }
        // L'embarquement reste écarté.
        assertEquals(emptyList<LocalTime>(), SaisieVol.heures("boarding time 5:20"))
        assertEquals(emptyList<LocalTime>(), SaisieVol.heures("porte fermee 5h45"))
    }

    @Test
    fun `depuis et un jour de la semaine`() {
        val p = lire("aller à Marseille depuis Tel Aviv le 20 novembre à 8h")
        assertEquals("TLV", p.depart?.iata)
        assertEquals("MRS", p.arrivee?.iata)
        assertEquals(LocalDate.of(2026, 11, 20), p.date)
        assertEquals(LocalDate.of(2026, 11, 10), lire("TO3461 TLV → LYS mardi 18:50").date)
    }

    @Test
    fun `une phrase sans vol ne propose rien`() {
        assertTrue(lire("bonjour").vide)
    }

    @Test
    fun `la carte d embarquement BCBP, sans garder le nom`() {
        val t = CarteEmbarquement.lire("M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100", mercredi)!!
        assertEquals("LYS", t.depart)
        assertEquals("TLV", t.arrivee)
        assertEquals("LY382", t.numero)
        assertEquals(LocalDate.of(2026, 11, 12), t.date)
        assertNull(CarteEmbarquement.lire("https://exemple.org", mercredi))
    }

    @Test
    fun `la duree estimee reste vraisemblable`() {
        val d = SaisieVol.dureeEstimee(Aeroports.parIata(aeroports, "LYS")!!, Aeroports.parIata(aeroports, "TLV")!!)
        assertTrue(d >= Duration.ofMinutes(225) && d <= Duration.ofMinutes(270))
    }
}
