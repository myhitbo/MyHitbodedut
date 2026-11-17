// Les vignettes des zmanim devant la JVM : ce que répondent ZmanimWidget.prochaine (la prière du moment et
// sa limite) et ZmanimVignette d'Android (le prochain changement, le jour hébreu affiché, le début de la
// fenêtre et sa part écoulée), que rejouent ZmanimWidgetTests et ZmanimVignetteTests de Coeur.
//
// Les instants sont des millisecondes Unix. Un balayage s'écrit par son premier instant, son pas et son
// nombre d'instants. Les horaires sont construits par des formules sur le jour (rien ne vient du calcul
// astronomique), puis écrits tels que la JVM les a résolus : Swift les relit sans rien recalculer.

import com.myhitbodedut.ZmanimVignette
import com.myhitbodedut.ZmanimWidget
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

object VecteursVignettes : Generateur {
    override val fichier = "vignettes.json"

    private const val MINUTE = 60_000L
    private val CIVILE = DateTimeFormatter.ofPattern("uuuu-MM-dd'T'HH:mm:ss")
    private val PARIS: ZoneId = ZoneId.of("Europe/Paris")

    private fun millis(z: ZonedDateTime): Long = z.toInstant().toEpochMilli()
    private fun vu(millis: Long, zone: ZoneId): ZonedDateTime = Instant.ofEpochMilli(millis).atZone(zone)
    private fun a(zone: ZoneId, d: LocalDate, h: Int, m: Int, s: Int = 0, ms: Int = 0): ZonedDateTime =
        ZonedDateTime.of(d.atTime(h, m, s, ms * 1_000_000), zone)
    private fun le(zone: ZoneId, d: LocalDate, minutes: Long): ZonedDateTime = d.atStartOfDay().plusMinutes(minutes).atZone(zone)

    // --- La prière du moment (ZmanimWidget.prochaine) ---------------------------------------------------

    /**
     * Les horaires d'une date : l'aube, la fin de Cha'harit, la chki'a et le milieu de la nuit qui suit (de
     * 23 h 30 à 2 h 59), chacun manquant certains jours ; le netz et le tsét, qui ne comptent pas, aussi.
     * À Paris, celui du 25 octobre 2026 tombe le 26 à 2 h 27 : la veille à la même heure, l'heure double.
     */
    private fun horairesPriere(zone: ZoneId, d: LocalDate): Map<String, ZonedDateTime?> {
        val e = d.toEpochDay()
        return linkedMapOf(
            "alot" to if (Math.floorMod(e, 9L) == 0L) null else le(zone, d, 280 + Math.floorMod(e * 13, 60L)),
            "netz" to le(zone, d, 400 + Math.floorMod(e * 5, 40L)),
            // Sans aube, le michéyakir certains jours (FCALENDRIER-08) ; min'ha guedola, absente certains jours (FVOL-05).
            "misheyakir" to if (Math.floorMod(e, 9L) == 0L && Math.floorMod(e, 2L) == 0L) le(zone, d, 330 + Math.floorMod(e * 3, 30L)) else null,
            "szt_gra" to le(zone, d, 540 + Math.floorMod(e * 7, 50L)),
            "minha_gedola" to if (Math.floorMod(e, 5L) == 2L) null else le(zone, d, 740 + Math.floorMod(e * 3, 40L)),
            "chkia" to if (Math.floorMod(e, 11L) == 0L) null else le(zone, d, 990 + Math.floorMod(e * 11, 90L)),
            "tset" to le(zone, d, 1050 + Math.floorMod(e * 3, 40L)),
            "chatsot_layla" to if (Math.floorMod(e, 7L) == 5L) null else le(zone, d.plusDays(1), Math.floorMod(e * 17, 210L) - 30),
        )
    }

    private fun ecrites(horaires: Map<String, ZonedDateTime?>): Map<String, Long> =
        linkedMapOf<String, Long>().apply { horaires.forEach { (k, v) -> if (v != null) put(k, millis(v)) } }

    /** D'où vient la limite rendue : l'une des trois clés, « veille » (le milieu de la nuit d'hier), ou rien. */
    private fun cleDe(limite: ZonedDateTime?, horaires: Map<String, ZonedDateTime?>): String? {
        if (limite == null) return null
        val cles = listOf("szt_gra", "chkia", "chatsot_layla").filter { horaires[it] == limite } +
            listOfNotNull("veille".takeIf { horaires["chatsot_layla"]?.minusDays(1) == limite })
        check(cles.size == 1) { "limite ambiguë : $limite, $cles" }
        return cles.single()
    }

    /** D'où vient le début d'une prière pas encore ouverte (FVOL-05) : min'ha guedola, ou rien. */
    private fun cleDebut(debut: ZonedDateTime?, horaires: Map<String, ZonedDateTime?>): String? {
        if (debut == null) return null
        check(horaires["minha_gedola"] == debut) { "début inattendu : $debut" }
        return "minha_gedola"
    }

    /** Des semaines entières à pas de 30 minutes, depuis minuit du premier jour ; les horaires du jour civil de chaque instant. */
    private fun balayagePriere(id: String, premier: LocalDate, jours: Int): Map<String, Any?> {
        val zone = ZoneId.of(id)
        val debut = millis(premier.atStartOfDay(zone))
        val nombre = jours * 48
        val dernier = vu(debut + (nombre - 1).toLong() * 30 * MINUTE, zone).toLocalDate()
        val dates = generateSequence(premier) { it.plusDays(1) }.takeWhile { !it.isAfter(dernier) }.toList()
        return linkedMapOf(
            "fuseau" to id, "debut" to debut, "pas" to 30, "nombre" to nombre,
            "jours" to dates.map { d ->
                val h = horairesPriere(zone, d)
                linkedMapOf("jour" to d.toString(), "horaires" to ecrites(h),
                    "veille" to h["chatsot_layla"]?.minusDays(1)?.let(::millis))
            },
            "reponses" to (0 until nombre).map { k ->
                val maintenant = vu(debut + k.toLong() * 30 * MINUTE, zone)
                val horaires = horairesPriere(zone, maintenant.toLocalDate())
                val (priere, limite, debut) = ZmanimWidget.prochaine(horaires, maintenant)
                listOf(priere, cleDe(limite, horaires), cleDebut(debut, horaires))
            },
        )
    }

    private fun prochaine(): List<Map<String, Any?>> = listOf(
        balayagePriere("Europe/Paris", LocalDate.of(2026, 10, 19), 14),
        balayagePriere("Asia/Jerusalem", LocalDate.of(2026, 3, 23), 7),
        balayagePriere("America/New_York", LocalDate.of(2026, 10, 29), 7),
        balayagePriere("Australia/Melbourne", LocalDate.of(2026, 4, 1), 7),
    )

    /** DixAmeliorationsTest, puis les bornes à la milliseconde, l'heure qui double, des horaires vides ou dans le désordre. */
    private fun casPriere(): List<Map<String, Any?>> {
        val jerusalem = ZoneId.of("Asia/Jerusalem")
        val j = LocalDate.of(2026, 10, 14)
        fun t(h: Int, m: Int, s: Int = 0, ms: Int = 0) = a(jerusalem, j, h, m, s, ms)
        val horaires = mapOf("szt_gra" to t(10, 30), "chkia" to t(17, 50), "chatsot_layla" to t(23, 40))
        val nuit = mapOf("alot" to t(5, 20), "szt_gra" to t(10, 30), "chkia" to t(17, 50), "chatsot_layla" to t(23, 40).plusMinutes(70))
        val d = LocalDate.of(2026, 10, 25)
        val heureDouble = mapOf("alot" to a(PARIS, d, 5, 20), "szt_gra" to a(PARIS, d, 10, 0), "chkia" to a(PARIS, d, 17, 30),
            "chatsot_layla" to a(PARIS, d.plusDays(1), 2, 30))
        val desordre = mapOf("chatsot_layla" to t(8, 0), "chkia" to t(9, 0), "szt_gra" to t(10, 30))
        // Min'ha guedola (FVOL-05) : avant elle, Min'ha n'est pas ouverte ; après la chki'a, celle du lendemain.
        val guedola = horaires + mapOf("alot" to t(5, 20), "minha_gedola" to t(12, 35))
        val guedolaTardive = horaires + mapOf("minha_gedola" to t(18, 0))
        // Sans aube : le michéyakir, sinon le nets (FCALENDRIER-08).
        val sansAube = mapOf("misheyakir" to t(4, 10), "netz" to t(5, 0), "szt_gra" to t(10, 30), "chkia" to t(17, 50),
            "chatsot_layla" to t(23, 40).plusMinutes(70))
        val netzSeul = mapOf("netz" to t(5, 0), "szt_gra" to t(10, 30), "chkia" to t(17, 50))
        fun z(texte: String) = Instant.parse(texte).atZone(PARIS)
        val cas: List<Pair<Map<String, ZonedDateTime?>, ZonedDateTime>> = listOf(
            horaires to t(7, 0), horaires to t(13, 0), horaires to t(19, 0), horaires to t(23, 50),
            nuit to t(0, 20), nuit to t(2, 0), nuit to t(6, 0),
            horaires to t(10, 30), horaires to t(10, 29, 59, 999), horaires to t(17, 50), horaires to t(23, 40), horaires to t(23, 39, 59, 999),
            nuit to t(5, 20), nuit to t(5, 19, 59, 999), nuit to t(0, 50), nuit to t(0, 49, 59, 999), nuit to t(0, 0),
            heureDouble to z("2026-10-24T22:00:00Z"), heureDouble to z("2026-10-25T00:15:00Z"), heureDouble to z("2026-10-25T00:45:00Z"),
            heureDouble to z("2026-10-25T01:15:00Z"), heureDouble to z("2026-10-25T01:29:59.999Z"), heureDouble to z("2026-10-25T01:30:00Z"),
            heureDouble to z("2026-10-25T01:45:00Z"), heureDouble to z("2026-10-25T04:30:00Z"),
            emptyMap<String, ZonedDateTime?>() to t(12, 0), mapOf("alot" to t(5, 20)) to t(4, 0), mapOf("alot" to t(5, 20)) to t(12, 0),
            desordre to t(7, 0), desordre to t(8, 30), desordre to t(9, 30), desordre to t(11, 0),
            guedola to t(10, 30), guedola to t(12, 34, 59, 999), guedola to t(12, 35), guedola to t(17, 0),
            guedolaTardive to t(11, 0), guedolaTardive to t(17, 55), sansAube to t(1, 0), sansAube to t(4, 30), sansAube to t(4, 0),
            netzSeul to t(4, 59), netzSeul to t(5, 0),
            // « Maintenant » vu d'un autre fuseau : tout se compare sur la ligne du temps.
            horaires to t(13, 0).withZoneSameInstant(ZoneId.of("UTC")),
        )
        return cas.map { (h, maintenant) ->
            val (priere, limite, debut) = ZmanimWidget.prochaine(h, maintenant)
            val fuseau = h.values.firstNotNullOfOrNull { it }?.zone?.id ?: maintenant.zone.id
            check(h.values.all { it == null || it.zone.id == fuseau })
            linkedMapOf(
                "fuseau" to fuseau, "horaires" to ecrites(h), "fuseauMaintenant" to maintenant.zone.id, "maintenant" to millis(maintenant),
                "priere" to priere, "limite" to limite?.let(::millis), "fuseauLimite" to limite?.zone?.id, "civile" to limite?.format(CIVILE),
                "debut" to debut?.let(::millis),
            )
        }
    }

    // --- Le prochain changement (ZmanimVignette.prochainChangement) ----------------------------------------

    /** Les dix zmanim d'une date dans l'ordre de la journée, deux manquant certains jours ; le dernier, après minuit. */
    private fun zmanimDuJour(zone: ZoneId, d: LocalDate): List<ZonedDateTime?> {
        val e = d.toEpochDay()
        return listOf(
            le(zone, d, 300 + Math.floorMod(e * 7, 60L)),
            le(zone, d, 420 + Math.floorMod(e * 3, 60L)),
            le(zone, d, 540 + Math.floorMod(e * 5, 30L)),
            if (Math.floorMod(e, 4L) == 0L) null else le(zone, d, 570 + Math.floorMod(e * 11, 30L)),
            le(zone, d, 720 + Math.floorMod(e, 30L)),
            le(zone, d, 760 + Math.floorMod(e * 13, 30L)),
            le(zone, d, 990 + Math.floorMod(e * 17, 30L)),
            le(zone, d, 1040 + Math.floorMod(e * 19, 30L)),
            if (Math.floorMod(e, 6L) == 1L) null else le(zone, d, 1070 + Math.floorMod(e * 23, 40L)),
            le(zone, d, 1420 + Math.floorMod(e * 29, 100L)),
        )
    }

    /**
     * [nombre] instants de [debut] en pas de [pas] millisecondes ; pour chacun, l'écart en millisecondes
     * jusqu'au changement rendu, et son fuseau.
     */
    private fun changement(lieu: ZoneId, horaires: List<ZonedDateTime?>, telephone: ZonedDateTime?, debut: Long, pas: Long, nombre: Int):
        Map<String, Any?> {
        val fuseauHoraires = horaires.firstNotNullOfOrNull { it }?.zone ?: lieu
        check(horaires.all { it == null || it.zone == fuseauHoraires })
        return linkedMapOf(
            "fuseau" to lieu.id, "fuseauHoraires" to fuseauHoraires.id, "horaires" to horaires.map { it?.let(::millis) },
            "telephone" to telephone?.let(::millis), "fuseauTelephone" to telephone?.zone?.id,
            "debut" to debut, "pas" to pas, "nombre" to nombre,
            "resultats" to (0 until nombre).map { k ->
                val maintenant = vu(debut + k * pas, lieu)
                val r = ZmanimVignette.prochainChangement(horaires, maintenant, telephone)
                listOf(millis(r) - millis(maintenant), r.zone.id)
            },
        )
    }

    private fun minuit(zone: ZoneId, d: LocalDate): ZonedDateTime = d.atStartOfDay(zone)

    private fun prochainChangement(): List<Map<String, Any?>> {
        val newYork = ZoneId.of("America/New_York")
        val jerusalem = ZoneId.of("Asia/Jerusalem")
        val bruxelles = ZoneId.of("Europe/Brussels")
        val havane = ZoneId.of("America/Havana")
        val utc = ZoneId.of("UTC")
        val blocs = mutableListOf<Map<String, Any?>>()
        // Autour du tsét et de minuit, un jour ordinaire et les deux nuits où l'heure change ; le téléphone
        // ailleurs (son minuit tombe à 6 h ou à 23 h de Paris), ou à Bruxelles (même instant que celui du lieu).
        for (d in listOf(LocalDate.of(2026, 11, 2), LocalDate.of(2026, 10, 24), LocalDate.of(2026, 3, 28))) {
            val horaires = zmanimDuJour(PARIS, d) + zmanimDuJour(PARIS, d.plusDays(1))
            val debut = millis(a(PARIS, d, 16, 0))
            for (telephone in listOf(null, minuit(newYork, d.plusDays(1)), minuit(jerusalem, d.plusDays(1)), minuit(bruxelles, d.plusDays(1)))) {
                blocs += changement(PARIS, horaires, telephone, debut, 10 * MINUTE, 61)
            }
        }
        // Sans lieu ni téléphone, rien que minuit et les dix minutes ; puis La Havane, où minuit manque le
        // 8 mars 2026 (l'heure avance à 0 h) et revient deux fois le 1er novembre.
        blocs += changement(PARIS, emptyList(), null, millis(a(PARIS, LocalDate.of(2026, 11, 2), 22, 0)), 5 * MINUTE, 49)
        for (d in listOf(LocalDate.of(2026, 3, 7), LocalDate.of(2026, 10, 31))) {
            blocs += changement(havane, emptyList(), null, millis(a(havane, d, 22, 0)), 5 * MINUTE, 49)
        }
        // Des horaires vus d'UTC : le changement garde le fuseau de l'horaire retenu.
        val d = LocalDate.of(2026, 11, 2)
        blocs += changement(PARIS, zmanimDuJour(PARIS, d).map { it?.withZoneSameInstant(utc) }, null, millis(a(PARIS, d, 16, 0)), 10 * MINUTE, 61)
        return blocs
    }

    /** VoyageNuitTest, puis les égalités : un horaire à l'instant même, à une milliseconde, aux dix minutes, au minuit du lieu. */
    private fun casChangement(): List<Map<String, Any?>> {
        val d = LocalDate.of(2026, 11, 2)
        val bruxelles = ZoneId.of("Europe/Brussels")
        val jerusalem = ZoneId.of("Asia/Jerusalem")
        val neuf = a(PARIS, d, 9, 5)
        val finChaharit = a(PARIS, d, 9, 12)
        val treize = a(PARIS, d, 13, 0)
        val tard = a(PARIS, d, 23, 55)
        val minuitLieu = minuit(PARIS, d.plusDays(1))
        val cas: List<Triple<List<ZonedDateTime?>, ZonedDateTime, ZonedDateTime?>> = listOf(
            Triple(listOf(finChaharit, null, finChaharit.plusHours(5)), neuf, null),
            Triple(listOf(treize.plusHours(3), treize.minusHours(1)), treize, null),
            Triple(emptyList(), tard, null),
            Triple(listOf(treize), treize, null),
            Triple(listOf(treize, treize.plusNanos(1_000_000)), treize, null),
            Triple(listOf(treize.plusMinutes(10)), treize, null),
            Triple(listOf(treize.plusMinutes(10).withZoneSameInstant(ZoneId.of("UTC"))), treize, null),
            Triple(emptyList(), tard, minuit(bruxelles, d.plusDays(1))),
            Triple(listOf(minuitLieu.withZoneSameInstant(jerusalem)), tard, null),
            Triple(emptyList(), a(PARIS, d, 22, 58), minuit(jerusalem, d.plusDays(1))),
            Triple(listOf(null, null), tard, minuitLieu.minusMinutes(1)),
        )
        return cas.map { (horaires, maintenant, telephone) ->
            val r = ZmanimVignette.prochainChangement(horaires, maintenant, telephone)
            linkedMapOf(
                "fuseau" to maintenant.zone.id,
                "horaires" to horaires.map { h -> h?.let { listOf(millis(it), it.zone.id) } },
                "telephone" to telephone?.let(::millis), "fuseauTelephone" to telephone?.zone?.id,
                "maintenant" to millis(maintenant), "resultat" to millis(r), "fuseauResultat" to r.zone.id, "civile" to r.format(CIVILE),
            )
        }
    }

    // --- Le jour hébreu affiché (ZmanimVignette.jourHebreuAffiche) --------------------------------------------

    private fun jourAffiche(lieu: ZoneId, tset: ZonedDateTime?, debut: Long, pas: Long, nombre: Int): Map<String, Any?> = linkedMapOf(
        "fuseau" to lieu.id, "tset" to tset?.let(::millis), "fuseauTset" to tset?.zone?.id,
        "debut" to debut, "pas" to pas, "nombre" to nombre,
        "jours" to (0 until nombre).map { k -> ZmanimVignette.jourHebreuAffiche(vu(debut + k * pas, lieu), tset).toString() },
    )

    private fun jourHebreuAffiche(): List<Map<String, Any?>> {
        val d = LocalDate.of(2026, 11, 2)
        val tset = a(PARIS, d, 17, 52)
        val melbourne = ZoneId.of("Australia/Melbourne")
        val tsetMelbourne = a(melbourne, LocalDate.of(2026, 4, 5), 18, 3)
        return listOf(
            // Une heure autour du tsét, minute par minute ; puis la milliseconde d'avant, l'instant même, celle d'après.
            jourAffiche(PARIS, tset, millis(tset) - 30 * MINUTE, MINUTE, 61),
            jourAffiche(PARIS, tset, millis(tset) - 1, 1, 3),
            // Autour de minuit : après le tsét d'hier, le surlendemain ; sans tsét, la date ; avant celui de demain, la date.
            jourAffiche(PARIS, tset, millis(a(PARIS, d, 23, 30)), MINUTE, 61),
            jourAffiche(PARIS, null, millis(a(PARIS, d, 23, 30)), MINUTE, 61),
            jourAffiche(PARIS, a(PARIS, d.plusDays(1), 17, 53), millis(a(PARIS, d, 23, 30)), MINUTE, 61),
            // Le tsét vu d'un autre fuseau : la comparaison se fait sur la ligne du temps.
            jourAffiche(PARIS, tset.withZoneSameInstant(ZoneId.of("Asia/Jerusalem")), millis(tset) - 2 * MINUTE, MINUTE, 5),
            // La nuit où l'heure d'hiver revient, puis le sud.
            jourAffiche(PARIS, a(PARIS, LocalDate.of(2026, 10, 25), 17, 40), millis(a(PARIS, LocalDate.of(2026, 10, 24), 23, 0)), 10 * MINUTE, 61),
            jourAffiche(melbourne, tsetMelbourne, millis(tsetMelbourne) - 12 * 60 * MINUTE, 20 * MINUTE, 73),
        )
    }

    // --- Le début de la fenêtre et sa part écoulée -------------------------------------------------------------

    private fun debut(): List<Map<String, Any?>> {
        val d = LocalDate.of(2026, 11, 2)
        val complet = mapOf("alot" to a(PARIS, d, 5, 20), "netz" to a(PARIS, d, 7, 30), "szt_gra" to a(PARIS, d, 10, 12),
            "chkia" to a(PARIS, d, 17, 15), "tset" to a(PARIS, d, 17, 52))
        val sansAlot = complet - "alot"
        // Min'ha guedola et michéyakir (13/11, FVOL-05 ; FCALENDRIER-08).
        val avecGuedola = complet + mapOf("minha_gedola" to a(PARIS, d, 12, 31), "misheyakir" to a(PARIS, d, 6, 0))
        val sansAlotMisheyakir = avecGuedola - "alot"
        val variantes = listOf(complet, sansAlot, emptyMap<String, ZonedDateTime?>(), mapOf("chkia" to null), avecGuedola, sansAlotMisheyakir)
        return variantes.flatMap { h ->
            listOf("chaharit", "minha", "arvit", "", "autre", "Chaharit").map { priere ->
                linkedMapOf("priere" to priere, "horaires" to ecrites(h), "resultat" to ZmanimVignette.debut(priere, h)?.let(::millis))
            }
        }
    }

    private fun ecoule(): Map<String, Any?> {
        val d = LocalDate.of(2026, 11, 2)
        val t = millis(a(PARIS, d, 5, 20))
        val fin = millis(a(PARIS, d, 9, 12, 30, 250))
        fun z(ms: Long) = vu(ms, PARIS)
        val cas: List<Triple<Long?, Long?, Long>> = listOf(
            Triple(null, fin, t), Triple(t, null, t), Triple(null, null, t),
            Triple(t, t, t), Triple(fin, t, t), Triple(t, t + 1, t), Triple(t, t + 999, t), Triple(t, t + 999, t + 1500),
            Triple(t, t + 999, t - 1), Triple(t, t + 999, t + 999), Triple(t, t + 1000, t + 500), Triple(t, t + 1000, t + 1000),
            Triple(t, fin, t - 1), Triple(t, fin, t - 500), Triple(t, fin, t - 1000), Triple(t, fin, t), Triple(t, fin, t + 999),
            Triple(t, fin, t + 1000), Triple(t, fin, fin - 1), Triple(t, fin, fin), Triple(t, fin, fin + 1), Triple(t, fin, fin + 86_400_000),
            Triple(t, t + 3 * 1000, t + 1000), Triple(t, t + 3 * 1000, t + 2000), Triple(t, t + 7 * 1000, t + 3000),
            Triple(t, t + 1_000_000_000_000, t + 333_333_333_333), Triple(t - 1_000_000_000_000, t, t),
        )
        return linkedMapOf(
            "cas" to cas.map { (debut, finCas, maintenant) ->
                linkedMapOf("debut" to debut, "fin" to finCas, "maintenant" to maintenant,
                    "resultat" to ZmanimVignette.ecoule(debut?.let(::z), finCas?.let(::z), z(maintenant)))
            },
            // Toute la fenêtre de Cha'harit d'un jour, et vingt minutes avant et après, toutes les 37 secondes.
            "balayage" to linkedMapOf(
                "debut" to t, "fin" to fin, "premier" to t - 20 * MINUTE, "pas" to 37_000, "nombre" to 444,
                "resultats" to (0 until 444).map { k -> ZmanimVignette.ecoule(z(t), z(fin), z(t - 20 * MINUTE + k * 37_000L)) },
            ),
        )
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursVignettes.kt"),
        "journee" to ZmanimVignette.JOURNEE,
        "prochaine" to prochaine(),
        "prochaineCas" to casPriere(),
        "prochainChangement" to prochainChangement(),
        "prochainChangementCas" to casChangement(),
        "jourHebreuAffiche" to jourHebreuAffiche(),
        "debut" to debut(),
        "ecoule" to ecoule(),
    )
}
