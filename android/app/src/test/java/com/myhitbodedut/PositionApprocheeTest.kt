package com.myhitbodedut

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.Duration
import java.time.LocalDate
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * La position exacte limitée au GPS en vol (31/10, Google Play) : les zmanim
 * et la boussole se contentent de la position approximative, qu'Android donne
 * à 2 ou 3 km près. Ici, ce qui le garantit dans le code, et ce que l'écart
 * fait aux calculs.
 */
class PositionApprocheeTest {

    private val dossier = File("src/main/java/com/myhitbodedut")

    /** Les lignes de code, hors commentaires, d'un fichier. */
    private fun code(f: File) = f.readLines()
        .filterNot { it.trimStart().let { l -> l.startsWith("*") || l.startsWith("/**") || l.startsWith("//") } }
        .joinToString("\n")

    @Test
    fun `seul le GPS en vol demande la position exacte`() {
        val demandeurs = dossier.listFiles { f -> f.extension == "kt" }!!
            .filter { code(it).contains("ACCESS_FINE_LOCATION") && Regex("""\.launch\([^)]*ACCESS_FINE_LOCATION""").containsMatchIn(code(it)) }
            .map { it.name }
        assertEquals(listOf("VolActivity.kt"), demandeurs)
    }

    @Test
    fun `le choix du lieu ne demande que la position approximative`() {
        val choix = code(File(dossier, "ChoixLieu.kt"))
        assertTrue(choix.contains("autorisation.launch(Manifest.permission.ACCESS_COARSE_LOCATION)"))
        assertFalse("la position exacte est encore demandée", Regex("""launch\([^)]*FINE""").containsMatchIn(choix))
        // Le libellé « Position exacte » n'a plus de sens : il a disparu des trois langues.
        listOf("values", "values-en", "values-iw").forEach { d ->
            val xml = File("src/main/res/$d/strings.xml").readText()
            assertFalse("$d : boussole_position_exacte", xml.contains("boussole_position_exacte"))
            assertTrue("$d : boussole_actualiser_position", xml.contains("name=\"boussole_actualiser_position\""))
        }
    }

    @Test
    fun `le manifeste garde les deux et dit a quoi sert l exacte`() {
        val manifeste = File("src/main/AndroidManifest.xml").readText()
        assertTrue(manifeste.contains("android.permission.ACCESS_COARSE_LOCATION"))
        val exacte = manifeste.substringBefore("<uses-permission android:name=\"android.permission.ACCESS_FINE_LOCATION\"")
            .substringAfterLast("<!--")
        assertTrue("le commentaire doit réserver l'exacte au GPS en vol", exacte.contains("GPS") && exacte.contains("vol"))
        assertFalse(exacte.contains("boussole"))
    }

    // --- Ce que 3 km d'écart font aux calculs --------------------------------------

    /** Le point à [km] kilomètres de (lat, lon), vers le cap [cap] en degrés. */
    private fun decale(lat: Double, lon: Double, km: Double, cap: Double): Pair<Double, Double> {
        val r = Math.toRadians(cap)
        val dLat = km * cos(r) / 111.2
        val dLon = km * sin(r) / (111.2 * cos(Math.toRadians(lat)))
        return (lat + dLat) to (lon + dLon)
    }

    private fun ecartMax(lat: Double, lon: Double, km: Double): Double =
        (0 until 360 step 15).maxOf { cap ->
            val (la, lo) = decale(lat, lon, km, cap.toDouble())
            abs(DirectionJerusalem.ecart(DirectionJerusalem.grandCercle(la, lo), DirectionJerusalem.grandCercle(lat, lon)))
        }

    @Test
    fun `la direction de Jerusalem tient avec 3 km d ecart`() {
        val loin = listOf(48.8534 to 2.3488, 40.7143 to -74.006, -37.814 to 144.9633, 32.0853 to 34.7818, 32.7940 to 34.9896)
        loin.forEach { (lat, lon) ->
            val d = DirectionJerusalem.distanceKm(lat, lon)
            val e = ecartMax(lat, lon, 3.0)
            if (d >= 200) assertTrue("à $d km : $e°", e < 1.0)
            if (d >= 50) assertTrue("à $d km : $e° dépasse la tolérance", e < DirectionJerusalem.TOLERANCE)
        }
        // Tout près de Har haBayit, l'approximative ne suffit plus à la précision de la boussole :
        // c'est une limite connue (PUBLICATION_PLAY_STORE.md § 6.7), pas une erreur de calcul.
        assertTrue(ecartMax(31.7683, 35.2137, 3.0) > DirectionJerusalem.TOLERANCE)
    }

    /**
     * Les zmanim s'affichent à la minute. 3 km d'écart les déplacent de quelques secondes, et
     * de 34 s au pire relevé : l'aube (16,1°) à Paris au solstice d'été, quand le soleil
     * passe à peine sous l'horizon.
     */
    @Test
    fun `les zmanim bougent de moins d une minute avec 3 km d ecart`() {
        val lieux = listOf(
            Zmanim.Lieu("Jérusalem", 31.76904, 35.21633, 0.0, "Asia/Jerusalem"),
            Zmanim.Lieu("Paris", 48.85341, 2.3488, 0.0, "Europe/Paris"),
            Zmanim.Lieu("New York", 40.71427, -74.00597, 0.0, "America/New_York"),
        )
        listOf("2026-06-21", "2026-12-21", "2026-03-20").map(LocalDate::parse).forEach { date ->
            lieux.forEach { lieu ->
                val ref = Zmanim.jour(lieu, date).associateBy { it.cle }
                listOf(0.0, 90.0, 180.0, 270.0).forEach { cap ->
                    val (la, lo) = decale(lieu.latitude, lieu.longitude, 3.0, cap)
                    Zmanim.jour(lieu.copy(latitude = la, longitude = lo), date).forEach { z ->
                        val a = ref.getValue(z.cle).instant ?: return@forEach
                        val b = z.instant ?: return@forEach
                        val s = abs(Duration.between(a, b).seconds)
                        assertTrue("${lieu.nom} $date ${z.cle} : $s s", s < 60)
                    }
                }
            }
        }
    }

    // --- La position gardée au sol, arrondie (examen du 14/11, constat 3) ------------

    /**
     * Accordée pour le GPS en vol, la position exacte peut répondre au sol : ce qui est gardé
     * est arrondi au centième de degré, moins d'un kilomètre, ce que donnerait l'approximative.
     */
    @Test
    fun `au sol la position gardee est arrondie au kilometre`() {
        assertEquals(31.77, PositionSol.arrondie(31.76904), 1e-9)
        assertEquals(-74.01, PositionSol.arrondie(-74.00597), 1e-9)
        assertEquals(2.35, PositionSol.arrondie(2.3488), 1e-9)
        val choix = code(File(dossier, "ChoixLieu.kt"))
        val enregistre = choix.substringAfter("fun enregistrerPosition(").substringBefore("Store.setLieuPosition")
        assertTrue(enregistre.contains("PositionSol.arrondie(position.latitude)"))
        assertTrue(enregistre.contains("PositionSol.arrondie(position.longitude)"))
        assertTrue("rien de plus précis n'est gardé", enregistre.contains("Zmanim.Lieu(nom, latitude, longitude,"))
        assertFalse("le sol n'attend plus 100 m", choix.contains("PRECIS_M"))
        assertTrue(choix.contains("val seuil = APPROCHE_M"))
    }

    @Test
    fun `l arrondi ne deplace ni les zmanim ni la direction de Jerusalem`() {
        // Au pire, un demi-centième de degré dans chaque sens.
        val pire = listOf(31.765 to 35.215, 48.855 to 2.345, 40.715 to -74.005, 32.085 to 34.785)
        pire.forEach { (lat, lon) ->
            val dLat = abs(PositionSol.arrondie(lat) - lat) * 111.2
            val dLon = abs(PositionSol.arrondie(lon) - lon) * 111.2 * cos(Math.toRadians(lat))
            assertTrue("$lat, $lon : ${Math.hypot(dLat, dLon)} km", Math.hypot(dLat, dLon) < 0.8)
        }
        // Moins de 0,8 km : la boussole tient au-delà de 15 km de Har haBayit.
        listOf(31.7470 to 34.9881, 31.5326 to 35.0998, 31.8969 to 35.0095, 32.0853 to 34.7818, 48.8534 to 2.3488).forEach { (lat, lon) ->
            assertTrue(DirectionJerusalem.distanceKm(lat, lon) >= 15)
            assertTrue("$lat, $lon", ecartMax(lat, lon, 0.8) < DirectionJerusalem.TOLERANCE)
        }
    }
}
