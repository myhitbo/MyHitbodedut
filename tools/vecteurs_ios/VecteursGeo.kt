// La géographie d'Android devant la JVM : la direction de Jérusalem (DirectionJerusalem), le
// territoire d'Israël (TerritoireIsrael) et la ville la plus proche (Villes), que rejouent
// DirectionJerusalemTests, TerritoireIsraelTests et VillePlusProcheTests de Coeur.
//
// sin, cos, tan, ln, atan2, acos et asin peuvent différer au dernier chiffre d'une bibliothèque
// mathématique à l'autre (la JVM, la glibc de la CI, celle d'Apple) : les tests Swift comparent les
// angles et les distances à une marge près. Ce qui n'est qu'arithmétique (norm, ecart, degres,
// point, face, le tracé de rayon du territoire) se compare à l'identique. Pour la ville la plus
// proche, « marge » dit de combien la deuxième est plus loin : une égalité à 1e-6 km près n'a pas
// de vainqueur certain d'une bibliothèque à l'autre.

import com.myhitbodedut.DirectionJerusalem
import com.myhitbodedut.TerritoireIsrael
import com.myhitbodedut.Villes
import java.io.File
import kotlin.math.cos
import kotlin.math.sin

object VecteursGeo : Generateur {
    override val fichier = "geo.json"

    private val villes = Villes.parse(File(RES, "raw/villes.json").readText())

    /** Le contour, privé dans TerritoireIsrael : lu par réflexion, pour que Swift compare sa recopie. */
    private val contour: List<DoubleArray> = (TerritoireIsrael::class.java.getDeclaredField("CONTOUR")
        .apply { isAccessible = true }.get(null) as Array<*>).map { it as DoubleArray }

    /** Les grandes villes de DirectionJerusalemTest, puis Honolulu (le méridien de 180°). */
    private val villesDuTest = listOf(
        "Paris" to (48.8566 to 2.3522), "New York" to (40.7128 to -74.0060), "Los Angeles" to (34.0522 to -118.2437),
        "Melbourne" to (-37.8136 to 144.9631), "Buenos Aires" to (-34.6037 to -58.3816), "Montréal" to (45.5017 to -73.5673),
        "Honolulu" to (21.3069 to -157.8583),
    )

    /** Une grille du globe, pôles compris, puis Jérusalem, son antipode et leurs voisins, et des longitudes hors de ±180°. */
    private fun points(): List<Pair<Double, Double>> {
        val latitudes = (-90..90 step 10).map { it.toDouble() } + listOf(-89.999, -45.5, -0.001, 0.001, 45.5, 89.999)
        val longitudes = (-180..180 step 20).map { it.toDouble() } + listOf(-179.999, -144.8, -100.5, 35.3, 179.999)
        val grille = latitudes.flatMap { lat -> longitudes.map { lon -> lat to lon } }
        val lat = DirectionJerusalem.LATITUDE
        val lon = DirectionJerusalem.LONGITUDE
        val antipode = -lat to lon - 180
        val voisins = listOf(
            lat to lon, lat + 0.001 to lon, lat to lon + 0.001, lat - 0.01 to lon - 0.01, lat + 0.5 to lon - 0.5,
            antipode, antipode.first + 0.01 to antipode.second, antipode.first to antipode.second + 0.01,
            antipode.first - 0.01 to antipode.second - 0.01, antipode.first to antipode.second + 360,
            90.0 to lon, -90.0 to lon, 0.0 to lon - 180, 0.0 to lon + 180, 0.0 to lon - 179.999, 0.0 to lon + 179.999,
            // Des longitudes qu'aucune carte n'écrit, mais que la formule accepte.
            10.0 to 200.0, 10.0 to 215.2354, 10.0 to 215.3, 10.0 to 360.0, 10.0 to 540.0, 10.0 to -200.0,
            10.0 to -324.7646, 10.0 to -540.0, -10.0 to 720.5,
        )
        return villesDuTest.map { it.second } + voisins + grille
    }

    /** Des angles en degrés : les cas du test, un balayage de −400° à 400° par pas de 2,5°, les demis et leurs voisins. */
    private fun angles(): List<Double> {
        val test = listOf(359.6, 54.01, 54.0, 95.8, 350.0, 4.0, -4.0, 4.1, 10.0, -20.0, 20.0)
        val bornes = listOf(-0.0, 0.0, 0.4, 0.49999999999999994, 0.5, 0.5000000000000001, -0.4, -0.5, -0.6, 22.4, 22.5,
            22.6, 337.4, 337.5, 337.6, 359.4, 359.5, 359.50000000000006, 359.9, 359.99, 359.99999999999994, 360.0,
            360.4, 360.5, 3.9999999, 4.0000001, -3.9999999, -4.0000001, 179.5, 180.0, 180.5, -180.0, -180.5,
            719.5, 720.0, -719.5, -720.0, 1e6 + 0.5, -1e6 - 0.5, 123456789.25, -1e-15, 1e-15, 1e15, -1e15)
        val balayage = (-160..160).map { it * 2.5 }
        return test + bornes + balayage
    }

    /** L'écart d'un cap à l'autre : les cas du test, puis une grille de part et d'autre du nord et du sud. */
    private fun ecarts(): List<Pair<Double, Double>> {
        val test = listOf(10.0 to 0.0, 350.0 to 10.0, 10.0 to 350.0, 112.39 to 112.0, 54.01 to 54.0)
        val valeurs = listOf(0.0, 10.0, 90.0, 179.0, 180.0, 181.0, 270.0, 350.0, 359.9, -10.0, 370.0, -0.0, 540.0)
        return test + valeurs.flatMap { cible -> valeurs.map { cap -> cible to cap } }
    }

    /** PositionApprocheeTest : le point à [km] kilomètres de (lat, lon), vers le cap [cap] en degrés. */
    private fun decale(lat: Double, lon: Double, km: Double, cap: Double): Pair<Double, Double> {
        val r = Math.toRadians(cap)
        val dLat = km * cos(r) / 111.2
        val dLon = km * sin(r) / (111.2 * cos(Math.toRadians(lat)))
        return (lat + dLat) to (lon + dLon)
    }

    private fun ecartMax(lat: Double, lon: Double, km: Double): Double =
        (0 until 360 step 15).maxOf { cap ->
            val (la, lo) = decale(lat, lon, km, cap.toDouble())
            kotlin.math.abs(DirectionJerusalem.ecart(DirectionJerusalem.grandCercle(la, lo), DirectionJerusalem.grandCercle(lat, lon)))
        }

    /** Les colonnes de la grille autour d'Israël : de 34,10° à 36,00° E par pas de 0,02°. */
    private val longitudesTerritoire = (0..95).map { (3410 + 2 * it) / 100.0 }

    /** Les lignes : de 29,30° à 33,50° N par pas de 0,02°. */
    private val latitudesTerritoire = (0..210).map { (2930 + 2 * it) / 100.0 }

    /** Sur le bord : chaque sommet, ses voisins à 1e-9° et à 0,01°, et le milieu de chaque côté. */
    private fun bords(): List<Pair<Double, Double>> = contour.indices.flatMap { i ->
        val (y, x) = contour[i][0] to contour[i][1]
        val (yj, xj) = contour[(i + 1) % contour.size].let { it[0] to it[1] }
        listOf(y to x, y to x - 1e-9, y to x + 1e-9, y - 1e-9 to x, y + 1e-9 to x, y to x - 0.01, y to x + 0.01,
            (y + yj) / 2 to (x + xj) / 2)
    }

    /** Des points pour la ville la plus proche : une grille du globe, puis autour de chaque ville. */
    private fun pointsVilles(): List<Pair<Double, Double>> {
        val grille = (-80..80 step 10).flatMap { lat -> (-180 until 180 step 15).map { lon -> lat.toDouble() to lon.toDouble() } }
        val autour = villes.flatMap { v ->
            listOf(v.latitude to v.longitude, v.latitude + 0.2 to v.longitude + 0.3, v.latitude - 0.45 to v.longitude - 0.1,
                v.latitude + 0.5 to v.longitude - 0.2, v.latitude to v.longitude + 0.7)
        }
        return autour + grille
    }

    private fun villeLaPlusProche(lat: Double, lon: Double): Map<String, Any?> {
        val triees = villes.map { it to Villes.distanceKm(lat, lon, it.latitude, it.longitude) }.sortedBy { it.second }
        return linkedMapOf("lat" to lat, "lon" to lon, "id" to Villes.plusProche(villes, lat, lon)?.id,
            "proche" to Villes.plusProche(villes, lat, lon, Double.MAX_VALUE)?.id, "km" to triees[0].second,
            "marge" to triees[1].second - triees[0].second)
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursGeo.kt"),
        "constantes" to linkedMapOf("latitude" to DirectionJerusalem.LATITUDE, "longitude" to DirectionJerusalem.LONGITUDE,
            "tolerance" to DirectionJerusalem.TOLERANCE, "source" to Villes.SOURCE, "villes" to villes.size),
        // Le grand cercle, la carte de Mercator et la distance, point par point.
        "directions" to points().map { (lat, lon) ->
            linkedMapOf("lat" to lat, "lon" to lon, "grandCercle" to DirectionJerusalem.grandCercle(lat, lon),
                "carte" to DirectionJerusalem.carte(lat, lon), "distanceKm" to DirectionJerusalem.distanceKm(lat, lon))
        },
        // Un angle : ramené entre 0 et 360, en degrés entiers, en point cardinal ; face à Jérusalem s'il est l'écart.
        "angles" to angles().map { d ->
            linkedMapOf("d" to d, "norm" to DirectionJerusalem.norm(d), "degres" to DirectionJerusalem.degres(d),
                "point" to DirectionJerusalem.point(d), "face" to DirectionJerusalem.face(d))
        },
        "ecarts" to ecarts().map { (cible, cap) ->
            linkedMapOf("cible" to cible, "cap" to cap, "ecart" to DirectionJerusalem.ecart(cible, cap))
        },
        // Le conseil du minyan (audit du 16/11) : les deux méthodes diffèrent de plus de 20° ; une grille du globe.
        "conseilMinyan" to (-80..80 step 10).map { lat ->
            linkedMapOf("lat" to lat, "conseil" to (-180..170 step 10).joinToString("") { lon ->
                if (DirectionJerusalem.conseilMinyan(lat.toDouble(), lon.toDouble())) "1" else "0"
            })
        },
        // Le statut Israël ou diaspora devant un nouveau lieu (audit du 16/11) : [impliquée, actuelle, premier lieu,
        // déclaré, région à enregistrer, question à poser].
        "decisionRegion" to (0 until 16).map { bits ->
            val (a, b, c, d) = listOf(1, 2, 4, 8).map { bits and it != 0 }
            val r = TerritoireIsrael.decisionRegion(a, b, c, d)
            listOf(a, b, c, d, r.region, r.proposition)
        },
        // PositionApprocheeTest : de combien la direction tourne au pire avec 1, 3 ou 10 km d'écart.
        "approchee" to listOf(48.8534 to 2.3488, 40.7143 to -74.006, -37.814 to 144.9633, 32.0853 to 34.7818,
            32.7940 to 34.9896, 31.7683 to 35.2137, 29.5577 to 34.9519, 31.25 to 34.79).map { (lat, lon) ->
            linkedMapOf("lat" to lat, "lon" to lon, "distanceKm" to DirectionJerusalem.distanceKm(lat, lon),
                "ecartMax" to listOf(1.0, 3.0, 10.0).map { ecartMax(lat, lon, it) })
        },
        // Le contour lu dans TerritoireIsrael, puis une grille autour d'Israël : une ligne par latitude, « 1 » dedans.
        "contour" to contour.map { listOf(it[0], it[1]) },
        "territoireLongitudes" to longitudesTerritoire,
        "territoire" to latitudesTerritoire.map { lat ->
            linkedMapOf("lat" to lat, "dedans" to longitudesTerritoire.joinToString("") { lon ->
                if (TerritoireIsrael.contient(lat, lon)) "1" else "0"
            })
        },
        "bords" to bords().map { (lat, lon) -> linkedMapOf("lat" to lat, "lon" to lon, "dedans" to TerritoireIsrael.contient(lat, lon)) },
        // La ville de villes.json la plus proche, à moins de 60 km (« id ») et sans limite (« proche »).
        "villes" to pointsVilles().map { (lat, lon) -> villeLaPlusProche(lat, lon) },
        // Le seuil : la ville la plus proche de Jérusalem-ouest, de Haïfa et du milieu de l'Atlantique, pour divers maxKm.
        "seuils" to listOf(31.78 to 35.20, 32.80 to 35.10, 31.30 to 35.40, 40.0 to -40.0).flatMap { (lat, lon) ->
            listOf(0.0, 1.0, 2.5, 10.0, 25.0, 59.9, 60.0, 60.1, 100.0, 1000.0, 5000.0, 20000.0).map { max ->
                val v = Villes.plusProche(villes, lat, lon, max)
                linkedMapOf("lat" to lat, "lon" to lon, "maxKm" to max, "id" to v?.id,
                    "km" to (Villes.plusProche(villes, lat, lon, Double.MAX_VALUE)
                        ?.let { Villes.distanceKm(lat, lon, it.latitude, it.longitude) }))
            }
        },
        // La distance de haversine entre deux points : le test, les pôles, l'antipode, le méridien de 180°.
        "distances" to listOf(
            listOf(31.76904, 35.21633, 32.08088, 34.78057), listOf(31.76904, 35.21633, 31.76904, 35.21633),
            listOf(48.85341, 2.3488, 45.76, 4.84), listOf(90.0, 0.0, -90.0, 0.0), listOf(90.0, 10.0, 90.0, -170.0),
            listOf(0.0, 0.0, 0.0, 180.0), listOf(0.0, 179.9, 0.0, -179.9), listOf(31.76904, 35.21633, -31.76904, -144.78367),
            listOf(-33.86785, 151.20732, 40.71427, -74.00597), listOf(10.0, 20.0, 10.000001, 20.000001),
            listOf(-89.999, 45.0, 89.999, -135.0), listOf(0.0, 0.0, 1e-9, 0.0), listOf(60.0, 360.0, 60.0, 0.0),
        ).map { (a, b, c, d) -> linkedMapOf("lat1" to a, "lon1" to b, "lat2" to c, "lon2" to d, "km" to Villes.distanceKm(a, b, c, d)) },
    )
}
