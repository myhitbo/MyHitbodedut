// Les zmanim en vol devant la JVM : ce que répondent Vol.kt, VolCalendrier.kt et VolPriere.kt d'Android
// (sur Zmanim.kt et KosherJava 2.5.0), que rejoue VolTests de Coeur. Le juge principal reste
// web/test/vecteurs_vol.json (tools/vecteurs_vol : 26 vols, leurs zmanim en vol, leurs réserves, les dates
// de part et d'autre de la ligne, les jalons en diaspora), que VolTests rejoue aussi en entier. Ici, le reste :
//  - le fuseau nautique et la distance du grand cercle, sur un balayage ;
//  - les heures des billets (changements d'heure compris) et la vérification d'une saisie ;
//  - la position sur la route et la fiabilité, avec et sans relevé, relevés aux bornes du vol compris ;
//  - des vols entiers : chaque événement de la fenêtre (instant, position, écart si retard), les réserves,
//    les lignes de date (instant et dates), les jalons (diaspora à 18 minutes, Israël à 40), la prière du
//    moment et les horaires qu'elle reçoit. Les vols de VolTest, puis des routes polaires l'été et l'hiver,
//    la ligne de date près de l'équateur dans les deux sens, une route presque antipodale, un très long
//    courrier, le Svalbard, une route australe, des veilles et des jours de fête, un horaire en vol sans
//    correspondant si le vol part 30 minutes plus tard.
//
// Les instants sont des millisecondes Unix. iOS calcule sur KosherSwift, qui rend les zmanim d'un lieu à une
// seconde près de KosherJava : la prière et les horaires ne sont demandés qu'à plus de cinq secondes de tout
// zman de la fenêtre (et de tout zman moins un jour, que ZmanimWidget.prochaine compare aussi).
// sin, cos, asin, acos et atan2 peuvent différer au dernier chiffre d'une bibliothèque mathématique à l'autre :
// les positions et les distances se comparent à une marge près.

import com.myhitbodedut.Aeroports
import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.Vol
import com.myhitbodedut.VolCalendrier
import com.myhitbodedut.VolPriere
import java.io.File
import java.time.DayOfWeek
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import kotlin.math.abs

object VecteursVol : Generateur {
    override val fichier = "vol.json"

    private val aeroports: List<Vol.Aeroport> by lazy {
        Aeroports.parse(File(RES, "raw/aeroports.json").readText(), File(RES, "raw/aeroports_noms.json").readText())
    }

    private fun a(iata: String): Vol.Aeroport = Aeroports.parIata(aeroports, iata) ?: error("$iata absent")

    /** Comme VolTest : les heures du billet, lues à l'heure de chaque aéroport. */
    private fun plan(de: String, vers: String, decollage: String, atterrissage: String): Vol.Plan {
        val d = a(de)
        val v = a(vers)
        return Vol.Plan("TEST", d, v, Vol.instant(LocalDateTime.parse(decollage), d)!!, Vol.instant(LocalDateTime.parse(atterrissage), v)!!)
    }

    private fun premier(depuis: String, ok: (LocalDate) -> Boolean): LocalDate =
        generateSequence(LocalDate.parse(depuis)) { it.plusDays(1) }.first(ok)

    private fun jour(d: LocalDate, israel: Boolean = false) = CalendrierJuif.jour(d, israel)

    /** La première veille d'un jour de fête chômé (pas un simple Chabbat) à partir de [depuis], en diaspora. */
    private fun veilleDeFete(depuis: String): LocalDate =
        premier(depuis) { !jour(it).chome && jour(it.plusDays(1)).chome && "yom_tov" in jour(it.plusDays(1)).conditions }

    private val versOuest by lazy { plan("TLV", "JFK", "2026-11-10T12:30", "2026-11-10T17:45") }
    private val releve = Vol.Point(Instant.parse("2026-11-10T18:30:00Z"), 56.0, -30.0)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to linkedMapOf(
            "source" to "tools/vecteurs_ios/VecteursVol.kt",
            "unites" to "instants et écarts en millisecondes Unix ; latitudes et longitudes en degrés ; distances en km",
            "evenement" to listOf("cle", "instant", "latitude", "longitude", "ecartSiRetard"),
            "jalon" to listOf("type", "instant", "date", "chabbat", "fetes", "omer", "allumage", "latitude", "longitude", "repli"),
            "priere" to listOf("maintenant", "priere", "limite", "debut"),
            "horaires" to listOf("maintenant", "alot", "szt_gra", "minha_gedola", "chkia", "chatsot_layla"),
        ),
        "constantes" to linkedMapOf(
            "dureeMax" to Vol.DUREE_MAX.toMillis(), "marge" to Vol.MARGE.toMillis(), "retard" to Vol.RETARD.toMillis(),
            "latitudeHaute" to Vol.LATITUDE_HAUTE, "couvert" to VolPriere.COUVERT.toMillis(),
        ),
        // [longitude, décalage nautique, fuseau nautique] : les demi-heures de part et d'autre de chaque borne.
        "nautiques" to longitudes().map { listOf(it, Vol.decalageNautique(it), Vol.fuseauNautique(it)) },
        // [lat1, lon1, lat2, lon2, km].
        "distances" to distances().map { (p, q) -> listOf(p.first, p.second, q.first, q.second, Vol.distanceKm(p.first, p.second, q.first, q.second)) },
        // [fuseau, heure locale, instant ou null] : Vol.instant, dans le trou et le doublon des changements d'heure.
        "instants" to instants(),
        "verifier" to verifications(),
        "positions" to positions(),
        "vols" to vols().map { (nom, p) -> vol(nom, p) },
    )

    // --- Fonctions simples ---------------------------------------------------------------------------

    private fun longitudes(): List<Double> = buildList {
        for (k in -13..13) {
            val borne = 7.5 + 15.0 * k
            addAll(listOf(borne - 0.5, borne - 1e-9, borne, borne + 1e-9))
        }
        addAll(listOf(-180.0, -179.9, -0.0, 0.0, 3.0, 35.0, -74.0, 179.9, 180.0, 200.0, -200.0, 1e6, -1e6))
    }.distinct()

    private fun distances(): List<Pair<Pair<Double, Double>, Pair<Double, Double>>> {
        val points = listOf("TLV", "JFK", "CDG", "SFO", "HKG", "MEL", "LAX", "SYD", "ZQN", "EZE", "SIN", "LYR", "AKL", "MAD", "NAN", "HNL")
            .map { a(it).let { x -> x.latitude to x.longitude } }
        return buildList {
            for (i in points.indices) for (k in i until points.size) add(points[i] to points[k])
            add((0.0 to 0.0) to (0.0 to 180.0))
            add((90.0 to 0.0) to (-90.0 to 0.0))
            add((90.0 to 10.0) to (90.0 to -170.0))
            add((10.0 to 179.9) to (10.0 to -179.9))
            add((-33.0 to 151.0) to (33.0 to -29.0))
            add((45.0 to 45.0) to (45.0 + 1e-7 to 45.0))
            add((0.0 to 0.0) to (0.0 to 0.0))
        }
    }

    private fun instants(): List<List<Any?>> {
        val cas = listOf(
            "TLV" to "2026-03-27T01:59", "TLV" to "2026-03-27T02:30", "TLV" to "2026-10-25T01:30", "TLV" to "2026-12-15T12:00", "TLV" to "2026-07-15T12:00",
            "CDG" to "2026-03-29T02:30", "CDG" to "2026-10-25T02:30", "CDG" to "2026-07-01T10:00", "JFK" to "2026-01-01T10:00",
            "JFK" to "2026-03-08T02:30", "JFK" to "2026-11-01T01:30", "MEL" to "2026-04-05T02:30", "MEL" to "2026-10-04T02:30",
            "LHR" to "2026-03-29T01:30", "LHR" to "2026-10-25T01:30", "ZQN" to "2026-04-05T02:30", "ZQN" to "2026-09-27T02:30",
        ) + listOf("MEL", "SYD", "BNE", "ADL", "DRW", "PER", "CGK", "DPS", "DJJ", "LAX", "JFK", "PHX", "HNL", "YUL", "EZE", "ZQN", "TLV")
            .flatMap { listOf(it to "2026-12-15T12:00", it to "2026-07-15T12:00") }
        return cas.map { (iata, local) ->
            val x = a(iata)
            listOf(x.fuseau, local, Vol.instant(LocalDateTime.parse(local), x)?.toEpochMilli())
        } + listOf(listOf("Mars/Olympus", "2026-01-01T10:00", Vol.instant(LocalDateTime.parse("2026-01-01T10:00"), a("JFK").copy(fuseau = "Mars/Olympus"))?.toEpochMilli()))
    }

    private fun verifications(): List<Map<String, Any?>> {
        val p = versOuest
        val heure = Duration.ofHours(1)
        val cas = listOf(
            "valide" to p,
            "meme_aeroport" to p.copy(arrivee = p.depart),
            "meme_code_autre_fiche" to p.copy(arrivee = p.depart.copy(nom = "autre", latitude = 0.0)),
            "meme_aeroport_et_a_rebours" to p.copy(arrivee = p.depart, atterrissage = p.decollage - heure),
            "atterrissage_au_decollage" to p.copy(atterrissage = p.decollage),
            "atterrissage_avant" to p.copy(atterrissage = p.decollage - Duration.ofMillis(1)),
            "une_milliseconde" to p.copy(atterrissage = p.decollage + Duration.ofMillis(1)),
            "vingt_deux_heures" to p.copy(atterrissage = p.decollage + Vol.DUREE_MAX),
            "vingt_deux_heures_et_une_milliseconde" to p.copy(atterrissage = p.decollage + Vol.DUREE_MAX + Duration.ofMillis(1)),
            "vingt_trois_heures" to p.copy(atterrissage = p.decollage + Duration.ofHours(23)),
            "trop_long_et_fuseau_inconnu" to p.copy(atterrissage = p.decollage + Duration.ofHours(23), arrivee = a("JFK").copy(fuseau = "Mars/Olympus")),
            "depart_inconnu" to p.copy(depart = a("TLV").copy(fuseau = "Mars/Olympus")),
            "arrivee_inconnue" to p.copy(arrivee = a("JFK").copy(fuseau = "Mars/Olympus")),
            "fuseau_vide" to p.copy(arrivee = a("JFK").copy(fuseau = "")),
        )
        return cas.map { (nom, x) -> linkedMapOf("nom" to nom, "plan" to plan(x), "invalide" to Vol.verifier(x)?.name?.lowercase()) }
    }

    // --- Positions -----------------------------------------------------------------------------------

    private fun positions(): List<Map<String, Any?>> {
        val p = versOuest
        val ms = Duration.ofMillis(1)
        val plans = listOf(
            "versOuest" to p,
            "releveGps" to p.copy(releve = releve),
            "releveDirect" to p.copy(releve = releve, sourceReleve = Vol.SourceReleve.DIRECT),
            "releveAuDecollage" to p.copy(releve = releve.copy(instant = p.decollage)),
            "releveJusteApresDecollage" to p.copy(releve = releve.copy(instant = p.decollage + ms)),
            "releveJusteAvantAtterrissage" to p.copy(releve = releve.copy(instant = p.atterrissage - ms)),
            "releveAAtterrissage" to p.copy(releve = releve.copy(instant = p.atterrissage)),
            "releveDehors" to p.copy(releve = releve.copy(instant = p.atterrissage + Duration.ofHours(1))),
            "releveAvant" to p.copy(releve = releve.copy(instant = p.decollage - Duration.ofHours(1)), sourceReleve = Vol.SourceReleve.DIRECT),
            "ligneOuest" to plan("SFO", "HKG", "2026-11-10T11:00", "2026-11-11T19:00"),
            "polaire" to plan("JFK", "HKG", "2026-06-20T11:00", "2026-06-21T15:00"),
            "antipodes" to plan("AKL", "MAD", "2026-11-10T20:00", "2026-11-11T05:00"),
            "memeAeroport" to p.copy(arrivee = p.depart),
            "pole" to p.copy(arrivee = p.arrivee.copy(latitude = 90.0, longitude = 0.0)),
        )
        return plans.map { (nom, x) ->
            val duree = Duration.between(x.decollage, x.atterrissage)
            val instants = buildList {
                addAll(listOf(x.decollage - Duration.ofHours(3), x.decollage - ms, x.decollage, x.decollage + ms))
                for (k in listOf(1, 10, 25, 50, 75, 90, 99)) add(x.decollage + duree.multipliedBy(k.toLong()).dividedBy(100))
                addAll(listOf(x.atterrissage - ms, x.atterrissage, x.atterrissage + ms, x.atterrissage + Duration.ofHours(3)))
                x.releve?.let { r -> addAll(listOf(r.instant - Duration.ofMinutes(10), r.instant - ms, r.instant, r.instant + ms, r.instant + Duration.ofMinutes(10))) }
            }.distinct().sorted()
            linkedMapOf(
                "nom" to nom, "plan" to plan(x),
                "releveUtilisable" to Vol.releveUtilisable(x),
                "fiabilite" to Vol.Calcul(x, emptyList(), emptySet(), emptyList()).fiabilite.name.lowercase(),
                "distanceKm" to Vol.distanceKm(x),
                "points" to instants.map { t -> Vol.position(x, t).let { q -> listOf(t.toEpochMilli(), q.latitude, q.longitude) } },
            )
        }
    }

    // --- Vols entiers --------------------------------------------------------------------------------

    private fun vols(): List<Pair<String, Vol.Plan>> {
        val vendredi = premier("2026-11-01") { it.dayOfWeek == DayOfWeek.FRIDAY }
        val omer = premier("2027-01-01") { jour(it.plusDays(1)).omer == 4 }
        val pessah = veilleDeFete("2027-01-01")
        val septieme = veilleDeFete(pessah.plusDays(3).toString())
        val chavouot = veilleDeFete(septieme.plusDays(3).toString())
        val tichri = veilleDeFete("2027-07-01")
        return listOf(
            // VolTest
            "versOuest" to versOuest,
            "versEst" to plan("JFK", "TLV", "2026-11-10T23:00", "2026-11-11T16:40"),
            "nuit" to plan("TLV", "CDG", "2026-11-10T22:30", "2026-11-11T02:00"),
            "court" to plan("TLV", "ETM", "2026-11-10T09:50", "2026-11-10T10:40"),
            "ligneOuest" to plan("SFO", "HKG", "2026-11-10T11:00", "2026-11-11T19:00"),
            "ligneEst" to plan("HKG", "SFO", "2026-11-10T21:00", "2026-11-10T18:00"),
            "polaireEte" to plan("JFK", "HKG", "2026-06-20T11:00", "2026-06-21T15:00"),
            "pacifiqueAller" to plan("MEL", "LAX", "2026-12-15T10:30", "2026-12-15T06:45"),
            "pacifiqueRetour" to plan("LAX", "MEL", "2026-12-22T22:30", "2026-12-24T08:45"),
            "escale" to plan("LAX", "YUL", "2026-12-15T09:30", "2026-12-15T17:55"),
            "tasman" to plan("SYD", "ZQN", "2026-12-18T09:00", "2026-12-18T14:15"),
            "atlantiqueSud" to plan("TLV", "EZE", "2026-11-10T23:00", "2026-11-11T09:20"),
            "releveGps" to versOuest.copy(releve = releve),
            "releveDirect" to versOuest.copy(releve = releve, sourceReleve = Vol.SourceReleve.DIRECT),
            "releveDehors" to versOuest.copy(releve = releve.copy(instant = versOuest.atterrissage + Duration.ofHours(1))),
            "vendredi" to plan("TLV", "JFK", "${vendredi}T12:30", "${vendredi}T17:45"),
            "samedi" to plan("TLV", "JFK", "${vendredi.plusDays(1)}T12:30", "${vendredi.plusDays(1)}T17:45"),
            "omer" to plan("TLV", "JFK", "${omer}T17:00", "${omer}T22:15"),
            "courtVendredi" to plan("TLV", "ETM", "${vendredi}T09:50", "${vendredi}T10:40"),
            // Routes polaires, l'été (soleil de minuit) et l'hiver (nuit polaire).
            "polaireHiver" to plan("JFK", "HKG", "2026-12-20T11:00", "2026-12-21T15:00"),
            "singapourEte" to plan("SIN", "JFK", "2026-06-20T23:35", "2026-06-21T06:20"),
            "singapourHiver" to plan("SIN", "JFK", "2026-12-20T23:35", "2026-12-21T05:20"),
            "svalbardEte" to plan("LYR", "TOS", "2026-06-21T12:00", "2026-06-21T13:40"),
            "svalbardHiver" to plan("LYR", "TOS", "2026-12-21T12:00", "2026-12-21T13:40"),
            // L'hémisphère sud au-delà de 60°, la ligne de date vers l'est.
            "australSud" to plan("SYD", "SCL", "2026-12-18T11:00", "2026-12-18T09:30"),
            // La ligne de date près de l'équateur : vers l'ouest la date avance, vers l'est elle recule.
            "fidjiOuest" to plan("HNL", "NAN", "2026-11-10T14:00", "2026-11-11T18:40"),
            "fidjiEst" to plan("NAN", "HNL", "2026-11-12T22:00", "2026-11-12T06:00"),
            // Presque aux antipodes : le grand cercle est mal conditionné.
            "antipodes" to plan("AKL", "MAD", "2026-11-10T20:00", "2026-11-11T05:00"),
            // Des veilles de fête (la chki'a passe en vol au printemps et à l'automne sur un départ de fin
            // d'après-midi) et deux jours de fête : diaspora et Israël diffèrent.
            "veillePessah" to plan("TLV", "JFK", "${pessah}T17:00", "${pessah}T22:15"),
            "pessahPremierJour" to plan("TLV", "JFK", "${pessah.plusDays(1)}T17:00", "${pessah.plusDays(1)}T22:15"),
            "pessahSecondJour" to plan("TLV", "JFK", "${pessah.plusDays(2)}T17:00", "${pessah.plusDays(2)}T22:15"),
            "veilleSeptieme" to plan("TLV", "JFK", "${septieme}T17:00", "${septieme}T22:15"),
            "veilleChavouot" to plan("TLV", "JFK", "${chavouot}T17:00", "${chavouot}T22:15"),
            "veilleTichri" to plan("TLV", "JFK", "${tichri}T17:00", "${tichri}T22:15"),
            // Le Omer de l'autre côté de la ligne de date.
            "omerPacifique" to plan("LAX", "MEL", "2027-05-04T22:30", "2027-05-06T08:45"),
            // Vers l'ouest presque à la vitesse du soleil : un horaire en vol sans correspondant à moins de 3 h quand
            // le vol part 30 minutes plus tard (ecartSiRetard null ; le plus proche est à plus de 5 h).
            "sansCorrespondant" to plan("CDG", "LAX", "2026-01-20T10:00", "2026-01-20T12:30"),
        )
    }

    private fun aeroport(x: Vol.Aeroport): Map<String, Any?> =
        linkedMapOf("iata" to x.iata, "latitude" to x.latitude, "longitude" to x.longitude, "fuseau" to x.fuseau)

    private fun plan(p: Vol.Plan): Map<String, Any?> = linkedMapOf(
        "depart" to aeroport(p.depart), "arrivee" to aeroport(p.arrivee),
        "decollage" to p.decollage.toEpochMilli(), "atterrissage" to p.atterrissage.toEpochMilli(),
        "releve" to p.releve?.let { listOf(it.instant.toEpochMilli(), it.latitude, it.longitude) },
        "source" to p.sourceReleve.name.lowercase(),
    )

    private fun vol(nom: String, p: Vol.Plan): Map<String, Any?> {
        val c = Vol.calculer(p)
        return linkedMapOf(
            "nom" to nom,
            "plan" to plan(p),
            "fiabilite" to c.fiabilite.name.lowercase(),
            "evenements" to c.evenements.map { listOf(it.cle, it.instant.toEpochMilli(), it.latitude, it.longitude, it.ecartSiRetard?.toMillis()) },
            "enVol" to c.enVol.size,
            "reserves" to c.reserves.map { it.name.lowercase() }.sorted(),
            // Les zmanim absents en un point du vol, dans l'ordre du profil (FVOL-11) ; une durée invraisemblable (FVOL-12).
            "absents" to c.absents,
            "invraisemblable" to Vol.invraisemblable(p),
            "lignesDate" to c.lignesDate.map { listOf(it.instant.toEpochMilli(), it.avant.toString(), it.apres.toString()) },
            "jalons" to listOf(false to 18, true to 40).map { (israel, minutes) ->
                linkedMapOf("enIsrael" to israel, "minutes" to minutes, "liste" to VolCalendrier.jalons(c, israel, minutes).map { j ->
                    listOf(j.type.name.lowercase(), j.instant.toEpochMilli(), j.date.toString(), j.chabbat, j.fetes, j.omer, j.allumage?.toEpochMilli(), j.latitude, j.longitude, j.repli)
                })
            },
            // [instant, prière, limite, début] ; le début d'une Min'ha pas encore ouverte (FVOL-05).
            "priere" to instantsPriere(c).map { m ->
                VolPriere.priere(c, m).let { r -> listOf(m.toEpochMilli(), r?.priere, r?.limite?.toEpochMilli(), r?.debut?.toEpochMilli()) }
            },
            "horaires" to instantsHoraires(c).map { m ->
                val h = Vol.horaires(c, m)
                listOf(m.toEpochMilli()) + listOf("alot", "szt_gra", "minha_gedola", "chkia", "chatsot_layla").map { h[it]?.toInstant()?.toEpochMilli() }
            },
        )
    }

    /** Les instants à plus de cinq secondes de tout zman de la fenêtre, et de tout zman moins un jour. */
    private fun loinDesZmanim(c: Vol.Calcul, candidats: List<Instant>): List<Instant> {
        val sensibles = c.evenements.flatMap { listOf(it.instant, it.instant - Duration.ofDays(1)) }
        return candidats.distinct().sorted().filter { t -> sensibles.none { abs(Duration.between(it, t).toMillis()) < 5000 } }
    }

    /** Toutes les heures de 7 h avant le décollage à 7 h après l'atterrissage, les bornes de la couverture, et cinq minutes de part et d'autre de chaque zman en vol. */
    private fun instantsPriere(c: Vol.Calcul): List<Instant> {
        val p = c.plan
        val ms = Duration.ofMillis(1)
        return loinDesZmanim(c, buildList {
            var t = p.decollage - Duration.ofHours(7)
            val fin = p.atterrissage + Duration.ofHours(7)
            while (!t.isAfter(fin)) { add(t); t += Duration.ofHours(1) }
            addAll(listOf(p.decollage - VolPriere.COUVERT - ms, p.decollage - VolPriere.COUVERT, p.atterrissage + VolPriere.COUVERT, p.atterrissage + VolPriere.COUVERT + ms))
            c.enVol.forEach { addAll(listOf(it.instant - Duration.ofMinutes(5), it.instant + Duration.ofMinutes(5))) }
        })
    }

    /** Toutes les deux heures, de 7 h avant le décollage à 7 h après l'atterrissage. */
    private fun instantsHoraires(c: Vol.Calcul): List<Instant> = loinDesZmanim(c, buildList {
        var t = c.plan.decollage - Duration.ofHours(7)
        val fin = c.plan.atterrissage + Duration.ofHours(7)
        while (!t.isAfter(fin)) { add(t); t += Duration.ofHours(2) }
    })
}
