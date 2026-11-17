package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/** La table des libellés (Libelles.kt) couvre toutes les clés ajout_, fete_, zman_ de strings.xml. */
class LibellesTest {

    @Test
    fun `aucune cle ne manque a la table`() {
        val xml = File("src/main/res/values/strings.xml").readText()
        val cles = Regex("""name="((?:ajout|fete|zman)_[a-z0-9_]+)"""").findAll(xml).map { it.groupValues[1] }.toSet()
        val table = File("src/main/java/com/myhitbodedut/Libelles.kt").readText()
        val manquantes = cles.filter { !table.contains("\"$it\" -> R.string.$it") }
        assertEquals("régénérer Libelles.kt", emptyList<String>(), manquantes)
        assertTrue(cles.size >= 75)
    }

    /**
     * TMECA-01 (13/11) : le calendrier rend des clés nues (« hanouka ») et la table ne connaît que
     * des clés préfixées. Chaque fête qu'il peut rendre a son libellé par « fete_<clé> », et aucune
     * par sa clé nue : c'est ainsi que la pastille des vignettes ne nommait jamais la fête.
     */
    @Test
    fun `chaque fete du calendrier a son libelle par la cle prefixee`() {
        (CalendrierJuif.FETES.values + listOf("pourim_ailleurs", "pourim_jerusalem")).forEach {
            assertNotNull("fete_$it", Libelles.res("fete_$it"))
            assertNull(it, Libelles.res(it))
        }
    }

    @Test
    fun `la pastille des vignettes nomme la fete du jour`() {
        fun jour(iso: String, muree: Boolean = false) = CalendrierJuif.jour(LocalDate.parse(iso), muree, muree)
        // 26 Kislev 5787 ; 1er Hechvan 5787 ; un jour ordinaire.
        assertEquals(R.string.fete_hanouka, ZmanimVignette.libelleFete(jour("2026-12-06")))
        assertEquals(R.string.fete_roch_hodech, ZmanimVignette.libelleFete(jour("2026-10-12")))
        assertNull(ZmanimVignette.libelleFete(jour("2026-10-19")))
        // À Jérusalem, le 14 Adar n'est Pourim qu'ailleurs, et le 15 l'est.
        assertEquals(R.string.fete_pourim, ZmanimVignette.libelleFete(jour("2027-03-23")))
        assertEquals(R.string.fete_pourim_ailleurs, ZmanimVignette.libelleFete(jour("2027-03-23", muree = true)))
        assertEquals(R.string.fete_pourim_jerusalem, ZmanimVignette.libelleFete(jour("2027-03-24", muree = true)))
        val vignette = File("src/main/java/com/myhitbodedut/ZmanimVignette.kt").readText()
        assertTrue("CalendrierJuif.jour(aujourdhui, israel, Store.mukafChoma(context))" in vignette)
    }
}
