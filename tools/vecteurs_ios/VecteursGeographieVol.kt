// La géographie et le vol devant la JVM (tâche 13) : la direction et la distance de Jérusalem sur une
// grille du globe, le contour d'Israël point par point, la ville la plus proche, la recherche des
// aéroports, la lecture des phrases et des cartes d'embarquement, la durée estimée, et pour des trajets
// réels les rappels en vol et la prière du moment. Les zmanim en vol eux-mêmes sont jugés par
// web/test/vecteurs_vol.json (tools/vecteurs_vol), que l'export copie pour iOS.

import com.myhitbodedut.Aeroports
import com.myhitbodedut.CarteEmbarquement
import com.myhitbodedut.DirectionJerusalem
import com.myhitbodedut.SaisieVol
import com.myhitbodedut.TerritoireIsrael
import com.myhitbodedut.Villes
import com.myhitbodedut.Vol
import com.myhitbodedut.VolPriere
import com.myhitbodedut.VolRappels
import java.io.File
import java.time.Duration
import java.time.LocalDate
import java.time.LocalDateTime

object VecteursGeographieVol : Generateur {
    override val fichier = "geographie_vol.json"

    private val requetes = listOf(
        "tlv", "TLV", "zurich", "Ben Gurion", "  ", "תל אביב", "תל-אביב", "בן גוריון", "מלבורן", "Londres", "par", "paris",
        "new y", "Lyon", "lys", "Genève", "ז", "x", "san", "Saint", "o'hare", "São Paulo", "MÜNCHEN", "eilat", "אילת", "ny",
    )

    private val phrases = listOf(
        "je prends le vol elal Lyon tlv de demain a 11h",
        "LY 382 de Paris à Tel Aviv le 12/11 à 9h40",
        "מחר בשעה 11 טיסת אל על מליון לתל אביב",
        "טיסה לניו יורק מתל אביב ב-12.11 בשעה 23:45",
        "Flight LY81 Tel Aviv to Bangkok on Nov 12 at 11:30pm, arrives 15:10",
        "Boarding 10:20 Departure 11:00 LYS TLV 14 nov. 2026 Arrival 16:05",
        "aller à Marseille depuis Tel Aviv le 20 novembre à 8h",
        "TO3461 TLV → LYS mardi 18:50",
        "bonjour",
        "AF 1620 CDG-TLV 2026-12-03 07:15 12:40",
        "easyjet Genève Tel Aviv après demain 6h05",
        "vol de Nice vers Eilat samedi",
        "wizz air budapest tel aviv 3 janvier 2027 à 14h",
        "LY5 TLV JFK 01/02/27 00:30 05:45",
        "United UA 90 Newark → Tel Aviv tonight at 10:35 pm",
        "טיסה ביום שני מאילת לחיפה",
        "Turkish TK 785 Istanbul TLV 12 h 05",
        "le 31/02 à 25h",
        "ryanair FR 1234 de Marseille à Lisbonne le 5 mars",
        "דצמבר 14 אל על LY001",
    )

    private val cartes = listOf(
        "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100",
        "M1COHEN/DAVID         EXYZ987 TLVJFKLY 0001 001Y030C0002 100",
        "M1LEVI/SARAH          EQWE456 CDGTLVAF 1620 365Y015F0003 100",
        "M2A/B                 EAAAAAA ZRHTLVLX 0256 060Y001A0004 100",
        "https://exemple.org",
        "M1X/Y                 EAAAAAA LYSTLVLY 03A2 316Y012A0001 100",
        "M1COURT",
    )

    override fun produire(): Map<String, Any?> {
        fun lire(nom: String) = File(RES, "raw/$nom").readText()
        val aeroports = Aeroports.parse(lire("aeroports.json"), lire("aeroports_noms.json"))
        val villes = Villes.parse(lire("villes.json"))
        val mercredi = LocalDate.of(2026, 11, 4)
        fun a(iata: String) = Aeroports.parIata(aeroports, iata)!!
        fun plan(de: String, vers: String, decollage: String, atterrissage: String) = Vol.Plan(
            "TEST", a(de), a(vers), Vol.instant(LocalDateTime.parse(decollage), a(de))!!, Vol.instant(LocalDateTime.parse(atterrissage), a(vers))!!)
        val trajets = listOf(
            plan("MEL", "LAX", "2026-12-15T10:30", "2026-12-15T06:45"),
            plan("LAX", "YUL", "2026-12-15T09:30", "2026-12-15T17:55"),
            plan("YUL", "LAX", "2026-12-22T08:00", "2026-12-22T11:05"),
            plan("LAX", "MEL", "2026-12-22T22:30", "2026-12-24T08:45"),
            plan("SYD", "ZQN", "2026-12-18T09:00", "2026-12-18T14:15"),
            plan("TLV", "EZE", "2026-11-10T23:00", "2026-11-11T09:20"),
            plan("TLV", "JFK", "2026-11-10T12:30", "2026-11-10T17:45"),
            plan("JFK", "TLV", "2026-11-10T23:00", "2026-11-11T16:40"),
            plan("TLV", "JFK", "2027-03-29T17:00", "2027-03-29T22:15"),
        )
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursGeographieVol.kt"),
            // [latitude, longitude, grand cercle, carte, distance km, degrés entiers, point cardinal]
            "directions" to (-80..80 step 10).flatMap { lat ->
                (-180..170 step 20).map { lon ->
                    val la = lat + 0.37
                    val lo = lon + 0.61
                    val gc = DirectionJerusalem.grandCercle(la, lo)
                    listOf(la, lo, gc, DirectionJerusalem.carte(la, lo), DirectionJerusalem.distanceKm(la, lo),
                        DirectionJerusalem.degres(gc), DirectionJerusalem.point(gc))
                }
            },
            // Le contour d'Israël : une ligne par latitude, de 29,30 à 33,50 N, un caractère par longitude de 34,10 à 36,00 E (pas de 0,05°).
            "territoire" to (0..84).map { i ->
                val lat = 29.30 + i * 0.05
                (0..38).joinToString("") { j -> if (TerritoireIsrael.contient(lat, 34.10 + j * 0.05)) "1" else "0" }
            },
            // La ville la plus proche d'une grille autour d'Israël et de l'Europe : son identifiant, ou 0.
            "villes" to (0..20).flatMap { i -> (0..20).map { j -> 29.0 + i * 1.2 to -10.0 + j * 2.5 } }.map { (lat, lon) ->
                listOf(lat, lon, Villes.plusProche(villes, lat, lon)?.id ?: 0L)
            },
            "aeroports" to linkedMapOf(
                "nombre" to aeroports.size,
                "recherches" to requetes.map { q -> listOf(q, Aeroports.chercher(aeroports, q).joinToString(",") { it.iata }) },
                "noms" to listOf("TLV", "CDG", "JFK", "MEL", "LHR").map { i ->
                    listOf(i, Aeroports.nomLocal(a(i), "he"), Aeroports.nomLocal(a(i), "fr"), Aeroports.nomLocal(a(i), "en"))
                },
                "plier" to listOf("Tel-Aviv", "São Paulo", "O'Hare", "בֵּן־גּוּרְיוֹן", "  A.B  ", "Zürich").map { listOf(it, Aeroports.plier(it)) },
            ),
            // Chaque phrase : numéro, compagnie, départ, arrivée, date, heure de départ, heure d'arrivée, date d'arrivée.
            "saisie" to phrases.map { t ->
                val p = SaisieVol.lire(t, aeroports, mercredi)
                listOf(t, p.numero, p.compagnie, p.depart?.iata, p.arrivee?.iata, p.date?.toString(), p.heureDepart?.toString(),
                    p.heureArrivee?.toString(), p.dateArrivee?.toString())
            },
            "cartes" to cartes.map { c ->
                val t = CarteEmbarquement.lire(c, mercredi)
                listOf(c, t?.depart, t?.arrivee, t?.compagnie, t?.numero, t?.date?.toString())
            },
            "durees" to listOf("LYS" to "TLV", "TLV" to "JFK", "TLV" to "ETM", "SYD" to "LHR").map { (d, v) ->
                listOf(d, v, SaisieVol.dureeEstimee(a(d), a(v)).toMinutes())
            },
            // Pour chaque trajet : les rappels (« type|instant|prière|limite|omer »), puis la prière du moment toutes les 20 min,
            // de 7 h avant le décollage à 7 h après l'atterrissage (« instant|prière|limite », « - » hors de la fenêtre).
            "trajets" to trajets.map { p ->
                val c = Vol.calculer(p)
                val instants = generateSequence(p.decollage - Duration.ofHours(7)) { it + Duration.ofMinutes(20) }
                    .takeWhile { !it.isAfter(p.atterrissage + Duration.ofHours(7)) }.toList()
                linkedMapOf(
                    "trajet" to "${p.depart.iata}-${p.arrivee.iata}",
                    "decollage" to p.decollage.toEpochMilli(),
                    "atterrissage" to p.atterrissage.toEpochMilli(),
                    "rappels" to VolRappels.rappels(c, false).map { r ->
                        "${r.type.name}|${r.instant.toEpochMilli()}|${r.priere ?: "-"}|${r.limite?.toEpochMilli() ?: "-"}|${r.omer}"
                    },
                    "prieres" to instants.map { t ->
                        val r = VolPriere.priere(c, t)
                        "${t.toEpochMilli()}|${r?.first ?: "-"}|${r?.second?.toEpochMilli() ?: "-"}"
                    },
                )
            },
        )
    }
}
