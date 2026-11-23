package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.ZoneId

/** Les villes des zmanim (10/10) : GeoNames, identifiants uniques, fuseaux valides. */
class VillesTest {

    private val villes = Villes.parse(File("src/main/res/raw/villes.json").readText())

    @Test
    fun `les villes sont lues et bien formees`() {
        assertTrue(villes.size >= 40)
        assertEquals(villes.size, villes.map { it.id }.toSet().size)
        villes.forEach { v ->
            assertTrue("${v.id}", v.nom.he.isNotBlank() && v.nom.fr.isNotBlank() && v.nom.en.isNotBlank())
            assertTrue("${v.id}", v.latitude in -90.0..90.0 && v.longitude in -180.0..180.0)
            ZoneId.of(v.fuseau)
        }
        assertEquals("Jérusalem", villes.first().nom.fr)
        assertTrue(villes.first().enIsrael)
        assertTrue(villes.none { it.enIsrael && it.fuseau != "Asia/Jerusalem" })
    }

    /**
     * Relecture du 23/11 : « Europe/Kyiv » (tzdata 2022b) est inconnu d'Android 8 et 9, où
     * ZoneId.of lève une exception ; Ouman et Kiev faisaient tomber l'application. Le test d'au-dessus
     * ne le voyait pas : il lit les fuseaux de la machine de construction, qui les connaît tous.
     */
    @Test
    fun `aucune ville ne porte un fuseau renomme depuis Android 8`() {
        // Les identifiants créés ou renommés par l'IANA depuis 2017 (tzdata 2017c à 2022g).
        val recents = setOf("Europe/Kyiv", "America/Nuuk", "Asia/Qostanay", "Pacific/Kanton", "America/Ciudad_Juarez")
        villes.forEach { v -> assertTrue("${v.id} ${v.fuseau}", v.fuseau !in recents) }
        assertEquals("Europe/Kiev", villes.first { it.id == 690688L }.fuseau)
    }

    @Test
    fun `un fuseau inconnu du telephone ne leve jamais d'exception`() {
        // Le nouveau nom et l'ancien mènent aux mêmes règles ; un identifiant inconnu rend le fuseau du téléphone.
        val hiver = java.time.Instant.parse("2026-01-15T12:00:00Z")
        assertEquals(ZoneId.of("Europe/Kiev").rules.getOffset(hiver), Zmanim.fuseau("Europe/Kyiv").rules.getOffset(hiver))
        assertEquals(ZoneId.systemDefault(), Zmanim.fuseau("Nulle/Part"))
        // Les zmanim se calculent, et le lieu enregistré se relit, avec un tel identifiant.
        val lieu = Zmanim.Lieu("?", 48.7501, 30.21944, 0.0, "Nulle/Part")
        assertTrue(Zmanim.jour(lieu, java.time.LocalDate.of(2026, 11, 23)).isNotEmpty())
        assertEquals("allumage", Zmanim.allumage(lieu, java.time.LocalDate.of(2026, 11, 27), 18).cle)
    }

    @Test
    fun `la source est citee, comme CC-BY le demande`() {
        val json = File("src/main/res/raw/villes.json").readText()
        assertTrue(json.contains("GeoNames") && json.contains("CC-BY 4.0"))
        listOf("values", "values-en", "values-iw").forEach { d ->
            assertTrue(d, File("src/main/res/$d/strings.xml").readText().contains("GeoNames"))
        }
    }
}
