// La suite du vol devant la JVM : ce que répondent VolRappels.kt, SaisieVol.kt, CarteEmbarquement.kt,
// Aeroports.kt, RouteVol.kt (la lecture des réponses d'adsbdb, et la recherche contre des réponses
// enregistrées) et SuiviVol.kt (la lecture des réponses du relais et d'OpenSky) d'Android, que rejouent
// les tests Swift de Coeur (AeroportsTests, SaisieVolTests, CarteEmbarquementTests, RouteVolTests,
// SuiviVolTests, VolRappelsTests).
//
//  - les aéroports lus (une empreinte par aéroport, quelques fiches entières), le pliage, la recherche,
//    le nom local ;
//  - la saisie d'une centaine de phrases de vol (français, anglais, hébreu ; formats de date ; fautes),
//    les heures d'un billet, la durée estimée ;
//  - le code BCBP des cartes d'embarquement ;
//  - les numéros de vol, la route d'adsbdb, la recherche contre un faux adsbdb (adresses demandées comprises) ;
//  - les indicatifs, la réponse du relais, celle d'OpenSky, les carrés et les adresses ;
//  - les rappels de quelques vols types : les zmanim de la route que reçoit VolRappels (ceux qu'il lit),
//    la prière ouverte sur un balayage, les rappels.
//
// Les instants sont des millisecondes Unix ; les dates « AAAA-MM-JJ » ; les heures « HH:MM ».

import com.myhitbodedut.Aeroports
import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.CarteEmbarquement
import com.myhitbodedut.RouteVol
import com.myhitbodedut.SaisieVol
import com.myhitbodedut.SuiviVol
import com.myhitbodedut.Vol
import com.myhitbodedut.VolRappels
import java.io.File
import java.io.IOException
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime

object VecteursVolSuite : Generateur {
    override val fichier = "vol_suite.json"

    private val aeroports: List<Vol.Aeroport> by lazy {
        Aeroports.parse(File(RES, "raw/aeroports.json").readText(), File(RES, "raw/aeroports_noms.json").readText())
    }
    private val sansNoms: List<Vol.Aeroport> by lazy { Aeroports.parse(File(RES, "raw/aeroports.json").readText()) }

    private fun a(iata: String): Vol.Aeroport = Aeroports.parIata(aeroports, iata) ?: error("$iata absent")

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to linkedMapOf(
            "source" to "tools/vecteurs_ios/VecteursVolSuite.kt",
            "unites" to "instants en millisecondes Unix ; dates AAAA-MM-JJ ; heures HH:MM ; durées en minutes",
            "empreinte" to "String.hashCode de « iata|nom|ville|pays|latitude|longitude|fuseau|nom he|nom fr|alias joints par ; » (latitude et longitude par Double.toString, un nom absent : « null »)",
            "proposition" to listOf("numero", "compagnie", "depart", "arrivee", "date", "heureDepart", "heureArrivee", "dateArrivee", "vide"),
            "evenement" to listOf("cle", "instant", "latitude", "longitude"),
            "rappel" to listOf("type", "instant", "priere", "limite", "omer"),
        ),
        "aeroports" to aeroportsLus(),
        "plier" to plier().map { listOf(it, Aeroports.plier(it)) },
        "chercher" to chercher(),
        "exact" to exact(),
        "nomLocal" to nomLocal(),
        "parIata" to listOf("TLV", "CDG", "URC", "tlv", "", "ZZZ", "JFK", "OOL").map { listOf(it, Aeroports.parIata(aeroports, it)?.iata) },
        "saisie" to saisie(),
        "heures" to heures(),
        "durees" to durees(),
        "cartes" to cartes(),
        "numeros" to numeros(),
        "routes" to routes(),
        "recherches" to recherchesRoute(),
        "indicatifs" to indicatifs(),
        "memes" to memes(),
        "raisons" to raisons(),
        "releves" to relevesRelais(),
        "adresses" to adresses(),
        "carres" to carres(),
        "etats" to etats(),
        "vols" to vols(),
    )

    // --- Aéroports -----------------------------------------------------------------------------------

    private fun fiche(x: Vol.Aeroport): String =
        "${x.iata}|${x.nom}|${x.ville}|${x.pays}|${x.latitude}|${x.longitude}|${x.fuseau}|${x.noms["he"]}|${x.noms["fr"]}|${x.alias.joinToString(";")}"

    private fun aeroportsLus(): Map<String, Any?> = linkedMapOf(
        "nombre" to aeroports.size,
        "empreintes" to aeroports.map { fiche(it).hashCode() },
        "sansNoms" to linkedMapOf(
            "nombre" to sansNoms.size,
            "empreintes" to sansNoms.map { fiche(it).hashCode() }.take(40),
        ),
        "fiches" to listOf("TLV", "CDG", "ORY", "JFK", "ZRH", "MEL", "LHR", "ETM", "AAA", "AAE", "AAL", "GVA", "BSL", "LYS", "MRS", "NCE", "SFO", "OOL")
            .map { iata ->
                val x = a(iata)
                linkedMapOf("iata" to x.iata, "nom" to x.nom, "ville" to x.ville, "pays" to x.pays, "latitude" to x.latitude,
                    "longitude" to x.longitude, "fuseau" to x.fuseau, "noms" to linkedMapOf("he" to x.noms["he"], "fr" to x.noms["fr"]),
                    "alias" to x.alias)
            },
    )

    private fun plier(): List<String> = listOf(
        "", " ", "   ", "Zurich", "Zürich", "ZÜRICH", "  Zürich  ", "Genève", "São Paulo", "Tel-Aviv", "Tel Aviv–Yafo", "L’Aquila",
        "L'Aquila", "\"Orly\"", "St. Petersburg", "Saint-Pétersbourg", "İstanbul", "Straße", "ΑΘΗΝΑ", "Αθήνα", "Москва", "北京",
        "Ben\tGurion", "Ben\nGurion", "Ben Gurion", "Ben Gurion", "Ben\u000BGurion", "Ben\u000CGurion", "a  .  b",
        "תל אביב", "תל-אביב", "תל־אביב", "תֵּל אָבִיב", "בֵּן־גּוּרְיוֹן", "צ׳רלס דה גול", "ת״א", "ﬁnnair", "Åre Östersund",
        "Œuvre", "Ærø", "Łódź", "Kraków", "Dubrovnik ", "Malé", "Curaçao", "Reykjavík", "Ñandú", "ǅemal", "Á", "́",
        "x‍y", "aéroport d'Annaba - Rabah-Bitat", "→", "LY 382 ✈",
    )

    private fun chercher(): List<List<Any?>> {
        val requetes = listOf(
            "tlv", "TLV", " tlv ", "zurich", "Zürich", "zur", "ZRH", "Ben Gurion", "  ", "", "תל אביב", "תל-אביב", "בן גוריון",
            "מלבורן", "Londres", "london", "paris", "Paris", "par", "new york", "New-York", "ניו יורק", "lyon", "ליון", "lys",
            "genève", "geneve", "geneva", "bâle", "basel", "milan", "rome", "roma", "orly", "charles de gaulle", "heathrow",
            "jfk", "lga", "ewr", "a", "ab", "z", "x", "san", "saint", "st", "st.", "new", "int", "international", "aéroport",
            "airport", "-", "'", "דה", "נמל", "123", "tel aviv", "aviv", "eilat", "אילת", "ramon", "mexico", "méxico",
            "sao paulo", "são paulo", "buenos aires", "bangkok", "dubai", "dubaï", "moscou", "moscow", "tokyo", "osaka",
            "queenstown", "sydney", "melbourne", "los angeles", "montreal", "montréal", "toronto", "chicago", "washington",
        )
        return requetes.map { q -> listOf(q, 20, Aeroports.chercher(aeroports, q).map { it.iata }) } +
            listOf("par", "a", "san", "international", "lon").map { q -> listOf(q, 5, Aeroports.chercher(aeroports, q, 5).map { it.iata }) } +
            listOf("zurich", "tlv", "par").map { q -> listOf(q, 0, Aeroports.chercher(aeroports, q, 0).map { it.iata }) } +
            // Sans les noms de Wikidata : la ville et le nom d'OurAirports seuls.
            listOf("תל אביב", "zurich", "Londres", "tlv").map { q -> listOf(q, -1, Aeroports.chercher(sansNoms, q).map { it.iata }) }
    }

    private fun exact(): List<List<Any?>> = listOf(
        "zurich", "tel aviv", "londres", "london", "lyon", "ליון", "פריז", "paris", "x", "", "new york", "tel aviv yafo",
        "geneve", "Genève", "bale", "eilat", "אילת", "melbourne", "orly", "tlv", "ben gurion", "rome", "los angeles",
    ).map { listOf(it, Aeroports.exact(aeroports, it)?.iata) }

    private fun nomLocal(): List<List<Any?>> = listOf("TLV", "CDG", "AAA", "AAE", "ZRH", "JFK").flatMap { iata ->
        listOf("he", "iw", "fr", "en", "de", "").map { langue -> listOf(iata, langue, Aeroports.nomLocal(a(iata), langue)) }
    }

    // --- Saisie --------------------------------------------------------------------------------------

    private val mercredi = LocalDate.of(2026, 11, 4)

    private fun proposition(p: SaisieVol.Proposition): List<Any?> = listOf(
        p.numero, p.compagnie, p.depart?.iata, p.arrivee?.iata, p.date?.toString(), p.heureDepart?.toString(), p.heureArrivee?.toString(),
        p.dateArrivee?.toString(), p.vide,
    )

    private val phrases = listOf(
        // Les cas de SaisieVolTest.
        "je prends le vol elal Lyon tlv de demain a 11h",
        "LY 382 de Paris à Tel Aviv le 12/11 à 9h40",
        "מחר בשעה 11 טיסת אל על מליון לתל אביב",
        "טיסה לניו יורק מתל אביב ב-12.11 בשעה 23:45",
        "Flight LY81 Tel Aviv to Bangkok on Nov 12 at 11:30pm, arrives 15:10",
        "Boarding 10:20 Departure 11:00 LYS TLV 14 nov. 2026 Arrival 16:05",
        "aller à Marseille depuis Tel Aviv le 20 novembre à 8h",
        "TO3461 TLV → LYS mardi 18:50",
        "bonjour",
        // Français.
        "vol AF 1234 Paris Nice le 3 décembre à 7h15",
        "Air France de Lyon vers Paris demain 6h",
        "easyJet Genève Tel Aviv 25/12 10h05",
        "transavia Orly Tel Aviv",
        "LY5 TLV JFK 01/01/2027 00:30",
        "Vol ELY382 le 12.11.26 à 21h",
        "je pars après demain à 14h de Marseille",
        "vendredi à 15h vol pour Eilat",
        "le 1er décembre 2026 Paris → New York 10h30 arrivée 13h10",
        "le 31/02 vol pour Rome",
        "vol le 29/02/2028 pour Rome",
        "Vol W6 2345 Budapest Tel-Aviv",
        "Vols : Nice - Tel Aviv 17 novembre 23h50 → 05h05",
        "ryanair dublin londres samedi 8h",
        "Rome Fiumicino à Tel Aviv le 2 janvier 2027",
        "vol de nuit Tel Aviv Paris ce soir 23h55",
        "aujourd'hui 17h30 Lyon Nice",
        "Swiss LX 252 Zurich Tel Aviv lundi 10:05",
        "Lufthansa LH686 Francfort Tel Aviv 12 déc.",
        "Vueling de Barcelone à Paris le 05.12.2026 à 06h45",
        "Aegean A3 929 Athènes Tel Aviv dimanche",
        "vol pour Bâle depuis Tel Aviv à 7",
        "départ Genève 14h20 arrivée Tel Aviv 19h05",
        "Paris Charles de Gaulle Tel Aviv",
        "Paris Orly - Eilat Ramon le 8 nov",
        "de Paris a New York",
        "vers Paris depuis Lyon",
        "par Paris",
        "les vols des compagnies",
        "Lyon Lyon",
        "TLV TLV",
        "CDG ORY",
        "Tel Aviv Yafo Paris",
        "tel aviv-yafo vers londres",
        "Los Angeles Sao Paulo",
        "São Paulo Buenos Aires 3 mars",
        "mars 3 Paris Rome",
        "Genève Zürich 12 November",
        "le 31 avril Paris Lyon",
        "demain demain Paris",
        "apres-demain Paris Rome",
        "après demain 9h Paris Rome",
        "Corsair SS 924 Orly Pointe-à-Pitre 14/11 11h30",
        "Air Corsica XK 101 Ajaccio Orly",
        "Royal Air Maroc Casablanca Paris",
        "Tunisair Tunis Marseille",
        "Arkia IZ 351 Tel Aviv Eilat 13h",
        "Israir 6H 102 Eilat Haïfa",
        "vol 2X 1234 Lyon Paris",
        "A1 123 Paris Lyon",
        "U22148 Lyon Genève",
        "U2 2148 Lyon Geneve",
        "LY 0382",
        "ly382",
        "LY38200",
        "vol à 25h",
        "vol à 14:61",
        "vol à 24:00",
        "vol à 0h",
        "vol à 12h60",
        "vers 9 Paris",
        "à 11h Paris",
        "11 am Paris",
        "11pm Paris",
        "12 pm Paris",
        "12 am Paris",
        "à 7.30 Paris",
        "le 12.11 Paris",
        "le 12/11/26 Paris",
        "le 12/11/2026 Paris",
        "le 1/1 Paris",
        "le 12/13 Paris",
        "le 00/11 Paris",
        "le 2026-11-20 Paris",
        "le 2026-02-30 Paris",
        "12.11.2026 10:00 Lyon Tel Aviv 17.11.2026 08:00",
        "nov 12 2027 Paris",
        "12 nov. 2026 Paris",
        "sept 9 Paris",
        "9 sept Paris",
        // Anglais.
        "Flight UA 90 Newark to Tel Aviv Dec 5 10:40 pm",
        "BA165 London Heathrow - Tel Aviv 12:30 tomorrow",
        "Departing JFK 11:30 PM arriving TLV 5:00 PM",
        "tonight 9pm from Tel Aviv to Paris",
        "LY001 2026-11-20 JFK TLV",
        "Delta DL234 from New York to Tel Aviv on November 21 2026 at 4:15pm",
        "today at 12 am",
        "Saturday flight to Rome",
        "Boarding gate closes 10:40, departure 11:10",
        "Turkish Airlines TK 785 Istanbul Tel Aviv 18 Nov",
        "Wizz Air W6 4321 from Budapest to Tel Aviv on December 1",
        "KLM KL461 Amsterdam to Tel Aviv, gate C12, boarding 09:15, departs 09:55",
        "Emirates EK 931 Dubai to Tel Aviv at 7:45am",
        "United flight from Newark to Tel Aviv on Friday",
        "to London from Paris",
        "Gate closes 23:10 Departure 23:40 TLV-LHR",
        "QF9 Melbourne Perth London",
        "flight at 7",
        "after tomorrow at 6 am to Eilat",
        // Hébreu.
        "טיסה ללונדון מחר בשעה 7",
        "אל על מתל אביב לפריז ב-15 בדצמבר בשעה 10:30",
        "טיסת ישראייר לאילת היום 18:00",
        "ביום שני טיסה לרומא",
        "בשבת טיסה לרומא",
        "שני כרטיסים לפריז",
        "טיסה מניו יורק לתל אביב 12/11",
        "טִיסָה לְפָּרִיז מָחָר בְּשָׁעָה 9",
        "טיסה ל־פריז מחרתיים",
        "ארקיע מאילת לתל אביב הערב",
        "טיסה מליון לתל אביב ב 20 נובמבר",
        "טיסה מתל אביב למילאנו ב12 בנובמבר",
        "עלייה למטוס 10:20 המראה 11:00",
        "שער 12 בשעה 14",
        // Fautes, bruit, cas limites.
        "elal lyonn tlv demian 11h",
        "TLV-CDG",
        "TLV->CDG 10h",
        "LYS→TLV",
        "✈ LY 81 ✈",
        "→",
        "->",
        "",
        "   ",
        "new york paris",
        "paris new york",
        "PARIS TEL AVIV 12/11 9H40",
        "Paris, Tel Aviv, 12/11, 9:40",
        "vol: LY382; de: CDG; vers: TLV; le: 12/11",
        "el al el al Paris",
        "easy jet Lyon Nice",
        "lot Varsovie Tel Aviv",
        "ita roma milano",
        "tap air portugal lisbonne",
        "AF1234",
        "af 1234 et LY382",
        "jan 5", "5 jan", "fev 2", "2 fevrier", "mai 1", "1 mai", "juin 10", "10 juin", "aout 15", "15 août", "dec 31", "31 decembre",
        // Les blancs de la JVM ne sont pas ceux d'ICU : l'espace insécable n'en est pas un, la tabulation si.
        "LY\u00A0382 Paris\u00A0Tel Aviv 12/11 à\u00A09h", "LY\t382\tParis\tTel Aviv\t12/11\tà\t9h", "vol\u2009LY81 TLV–BKK 12\u202Fnov",
    )

    private fun saisie(): List<List<Any?>> {
        val autresJours = listOf(
            "2026-12-28" to listOf("2 janvier Paris", "5 décembre Paris", "le 20/12 Paris", "le 22/12 Paris", "le 21/12 Paris", "lundi Paris",
                "dimanche Paris", "demain Paris", "1 janvier Paris", "le 29/02 Paris", "29 fevrier Paris"),
            "2024-02-28" to listOf("le 29/02 Paris", "29 fevrier Paris", "demain Paris", "après demain Paris", "le 1/3 Paris", "mercredi Paris"),
            "2026-01-03" to listOf("30 décembre Paris", "le 27/12 Paris", "le 26/12 Paris", "samedi Paris", "today Paris"),
            "2027-02-28" to listOf("le 29/02 Paris", "29/02/2028 Paris", "demain Paris"),
        )
        return phrases.map { t -> listOf(t, mercredi.toString(), proposition(SaisieVol.lire(t, aeroports, mercredi))) } +
            autresJours.flatMap { (jour, liste) ->
                val d = LocalDate.parse(jour)
                liste.map { t -> listOf(t, jour, proposition(SaisieVol.lire(t, aeroports, d))) }
            }
    }

    private fun heures(): List<List<Any?>> = listOf(
        "11h", "11h30", "11 h 30", "11:30", "11 am", "11am", "11pm", "11 pm", "12pm", "12am", "12:30am", "12:30 pm", "0h", "00:00",
        "23:59", "24:00", "25h", "9h60", "a 11", "à 11", "at 7", "vers 9", "בשעה 23", "בשעה 7:30", "a 11h", "at 7pm", "a 11/12",
        "a 11:30", "a 11.", "la 11", "boarding 10:20 departure 11:00", "gate closes 23:10 dep 23:40", "embarquement 8h fermeture 8h20 depart 8h40",
        "porte 12 a 14h", "שער 3 בשעה 14", "עלייה 10:20 המראה 11:00", "123:45", "1:23:45", "7h7", "7h07", "07h07", "7 h", "7h ", "h7",
        "1h2", "19h45 et 21h", "du 10:00 au 12:00", "10:00-12:00", "10:00am", "10:00 am", "10 :00", "a  11", "à\t11",
        "boardingxxxxxxxxxxxxxxxxxxxxxx 10:00", "boardingxxxxxxxxxxxxxxxxxxx 10:00", "", "vol",
        "a\u00A011", "11\u00A0h", "11\u00A0pm", "11\th30", "11\u000Bam",
    ).map { t ->
        val leger = java.text.Normalizer.normalize(t, java.text.Normalizer.Form.NFD).replace(Regex("\\p{M}"), "").lowercase()
        listOf(t, SaisieVol.heures(leger).map { it.toString() })
    }

    private fun durees(): List<List<Any?>> = listOf(
        "LYS" to "TLV", "TLV" to "LYS", "CDG" to "JFK", "TLV" to "ETM", "TLV" to "JFK", "MEL" to "LAX", "SYD" to "ZQN", "CDG" to "ORY",
        "TLV" to "BKK", "LHR" to "SYD", "JFK" to "HKG", "EZE" to "TLV", "GVA" to "BSL", "NCE" to "MRS",
    ).map { (x, y) -> listOf(x, y, SaisieVol.dureeEstimee(a(x), a(y)).toMinutes()) }

    // --- Carte d'embarquement ------------------------------------------------------------------------

    private fun cartes(): List<List<Any?>> {
        val base = "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100"
        val codes = listOf(
            base, "https://exemple.org", "",
            "M1DUPONT/JEAN        EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 001Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 366Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 365Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 000Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 367Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006    Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 1 2Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 +12Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 -12Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKAF 0006 ١٢٣Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKU2 2148 316Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFKEZY2148 316Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFK6H 0102A316Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFK6H 00000316Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CDGJFK6H 12345316Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 cdgJFKAF 0006 316Y001A0001 100",
            "M1DUPONT/JEAN         EABC123 CD JFKAF 0006 316Y001A0001 100",
            "M1DUPONT/JEAN         EABC123  CDJFKAF 0006 316Y001A0001 100",
            "M2DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "MXDUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "N1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "m1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "M٣DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 31",
            "M1DUPONT/JEAN         EABC123 LYSTLVL  0382 316Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLV L 0382 316Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 03 2 316Y012A0001 100",
            "M\uFF11DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "M1DUPONT/JE\uD83D\uDE00N        EABC123 LYSTLVLY 0382 316Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 \uFF13\uFF11\uFF16Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 +  Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 0  Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382  60Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382\t60Y012A0001 100",
            "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 366Y012A0001 100",
        )
        val jours = listOf("2026-11-04", "2026-01-02", "2026-12-30", "2024-07-01", "2025-07-02", "2027-12-31")
        return codes.flatMap { code ->
            jours.map { jour ->
                val t = CarteEmbarquement.lire(code, LocalDate.parse(jour))
                listOf(code, jour, t?.let { listOf(it.depart, it.arrivee, it.compagnie, it.numero, it.date?.toString()) })
            }
        }
    }

    // --- Route (adsbdb) ------------------------------------------------------------------------------

    private fun numeros(): List<List<Any?>> = listOf(
        "ly 81", "ELY081", "U22148", "bonjour", "LY81", "ly81a", "LY 0", "LY0000", "LY00001", "ELY", "E", "", "  ", "QF9", "qf 9",
        "2X1234", "X21234", "221234", "AFR 1234", "af\t12", "af 12", "LY81AB", "LY12345", "Ly 8 1", "ÉLY81", "ly-81", "LY\u00A081", "LY\u000B81", "LY\r\n81",
    ).map { t -> listOf(t, RouteVol.normaliser(t)?.let { listOf(it.code, it.chiffres, it.suffixe) }) }

    private fun resultatRoute(r: RouteVol.Resultat): List<Any?> = when (r) {
        is RouteVol.Resultat.Trouve -> listOf("trouve", r.indicatif, r.compagnie, r.escales, r.de, r.vers)
        is RouteVol.Resultat.AutreDepart -> listOf("autre_depart", r.indicatif, r.compagnie, r.escales)
        RouteVol.Resultat.Introuvable -> listOf("introuvable")
        RouteVol.Resultat.Invalide -> listOf("invalide")
        is RouteVol.Resultat.Erreur -> listOf("erreur", r.raison)
    }

    private fun route(icao: String?, vararg escales: String): String {
        val p = { iata: String -> "{\"iata_code\":\"$iata\"}" }
        val milieu = if (escales.size == 3) ",\"midpoint\":${p(escales[1])}" else ""
        val indicatif = if (icao == null) "" else "\"callsign_icao\":\"$icao\","
        return "{\"response\":{\"flightroute\":{$indicatif\"airline\":{\"name\":\"Cie\"}," +
            "\"origin\":${p(escales.first())}$milieu,\"destination\":${p(escales.last())}}}}"
    }

    private fun routes(): List<List<Any?>> {
        val corps = listOf(
            route("ELY81", "TLV", "BKK"), route("QFA9", "MEL", "PER", "LHR"), route(null, "TLV", "BKK"), route("ely 81", "TLV", "BKK"),
            route("LY81", "TLV", "BKK"), route("ELY81", "TLV", "TLV"),
            "{\"response\":{\"flightroute\":{\"callsign_icao\":\"ELY81\",\"origin\":{\"iata_code\":\"TLV\"},\"destination\":{\"iata_code\":\"bkk\"}}}}",
            "{\"response\":{\"flightroute\":{\"callsign_icao\":\"ELY81\",\"origin\":{\"iata_code\":\"TLV\"},\"destination\":{\"iata_code\":null}}}}",
            "{\"response\":{\"flightroute\":{\"callsign_icao\":\"ELY81\",\"origin\":{\"iata_code\":\"TLV\"},\"midpoint\":{\"iata_code\":\"\"},\"destination\":{\"iata_code\":\"BKK\"}}}}",
            "{\"response\":{\"flightroute\":{\"callsign_icao\":12,\"airline\":{\"name\":42},\"origin\":{\"iata_code\":123},\"destination\":{\"iata_code\":\"A1B\"}}}}",
            "{\"response\":{\"flightroute\":{\"airline\":\"El Al\",\"origin\":\"TLV\",\"destination\":{\"iata_code\":\"BKK\"}}}}",
            "{\"response\":{\"flightroute\":{\"callsign_icao\":null,\"airline\":{\"name\":null},\"origin\":{\"iata_code\":\"TLV\"},\"destination\":{\"iata_code\":\"BKK\"}}}}",
            "{\"response\":{\"flightroute\":{}}}", "{\"response\":{\"flightroute\":null}}", "{\"response\":\"unknown callsign\"}", "{\"response\":{}}",
            "{}", "[]", "", "pas du json", "<html>", "{\"response\":{\"flightroute\":{\"origin\":{\"iata_code\":\"TLV\"},\"destination\":{\"iata_code\":\"BKK\"}}}} reste",
            "{\"response\":{\"flightroute\":{\"callsign_icao\":\"ELY81\",\"airline\":{\"name\":\"El Al Israel Airlines\"},\"origin\":{\"iata_code\":\"TLV\",\"name\":\"Ben Gurion\"},\"destination\":{\"iata_code\":\"BKK\"}}}}",
        )
        return corps.flatMap { c -> listOf(null, "TLV", "MEL", "PER", "LHR", "BKK", "XXX").map { d -> listOf(c, d, resultatRoute(RouteVol.lire(c, d))) } }
    }

    /** Un faux adsbdb : une table de réponses (code, corps), 404 « {} » ailleurs ; une adresse « hors ligne » lève. */
    private fun recherchesRoute(): List<Map<String, Any?>> {
        val table = linkedMapOf(
            "callsign/LY81" to (200 to route("ELY81", "TLV", "BKK")),
            "airline/QF" to (200 to "{\"response\":[{\"icao\":\"QFA\"}]}"),
            "callsign/QFA9" to (200 to route("QFA9", "MEL", "PER", "LHR")),
            "callsign/QF9" to (400 to "{}"),
        )
        val autre = linkedMapOf(
            "callsign/AB12" to (404 to ""),
            "airline/AB" to (200 to "{\"response\":[{\"icao\":\"ab\"},{\"name\":\"x\"},\"QQQ\",{\"icao\":\"ABX\"},{\"icao\":\"ABY\"}]}"),
            "callsign/ABX12" to (404 to "{}"),
            "callsign/ABY12" to (200 to route("ABY12", "CDG", "ORY")),
            "callsign/CD34" to (404 to "{}"),
            "airline/CD" to (200 to "pas du json"),
            "callsign/EF56" to (500 to "panne"),
            "callsign/GH78" to (404 to "{}"),
            "airline/GH" to (429 to "{}"),
            "callsign/IJ9" to (404 to "{}"),
            "airline/IJ" to (200 to "{\"response\":\"inconnu\"}"),
            "callsign/KL1" to (301 to ""),
            "callsign/MN2" to (200 to "<html>"),
            "callsign/OPQ3" to (404 to "{}"),
            "callsign/RS4" to (404 to "{}"),
            "airline/RS" to (200 to "{\"response\":[{\"icao\":\"RSA\"}]}"),
            "callsign/RSA4" to (199 to "{}"),
            "callsign/TU5" to (404 to "{}"),
            "airline/TU" to (404 to "{}"),
            "callsign/VW6A" to (200 to route("VWX6A", "TLV", "ETM")),
        )
        val horsLigne = setOf("callsign/HL1", "airline/HM", "callsign/HMA2")
        val tableHm = linkedMapOf("callsign/HM2" to (404 to "{}"))
        val cas = listOf(
            Triple("LY81", "TLV", table), Triple("LY81", "MEL", table), Triple("QF9", "PER", table), Triple("QF9", null, table),
            Triple("XX999", null, table), Triple("nimporte", null, table), Triple("ly 081", "TLV", table), Triple("ELY81", null, table),
            Triple("QF9", "LHR", table), Triple("QF 0009", "MEL", table),
            Triple("AB12", null, autre), Triple("AB12", "CDG", autre), Triple("CD34", null, autre), Triple("EF56", null, autre),
            Triple("GH78", null, autre), Triple("IJ9", null, autre), Triple("KL1", null, autre), Triple("MN2", null, autre),
            Triple("OPQ3", null, autre), Triple("RS4", null, autre), Triple("TU5", null, autre), Triple("VW6A", "TLV", autre),
            Triple("HL1", null, autre), Triple("HM2", null, tableHm),
        )
        return cas.map { (numero, depart, t) ->
            val demandes = mutableListOf<String>()
            val lecteur = RouteVol.Lecteur { adresse ->
                demandes += adresse
                val chemin = adresse.removePrefix(RouteVol.ADSBDB + "/")
                if (chemin in horsLigne) throw IOException("hors ligne")
                t[chemin] ?: (404 to "{}")
            }
            val r = RouteVol.chercher(numero, depart, lecteur)
            linkedMapOf(
                "numero" to numero, "depart" to depart,
                "reponses" to t.entries.map { (chemin, rep) -> listOf(chemin, rep.first, rep.second) },
                "horsLigne" to horsLigne.toList(),
                "resultat" to resultatRoute(r), "demandes" to demandes,
            )
        } + listOf(
            // Le serveur refuse tout : 503 à la première demande.
            linkedMapOf("numero" to "LY81", "depart" to null, "reponses" to listOf(listOf("*", 503, "")), "horsLigne" to emptyList<String>(),
                "resultat" to resultatRoute(RouteVol.chercher("LY81", null) { 503 to "" }), "demandes" to listOf("${RouteVol.ADSBDB}/callsign/LY81")),
        )
    }

    // --- Suivi (relais, OpenSky) ---------------------------------------------------------------------

    private fun indicatifs(): List<List<Any?>> = listOf(
        "ely 001", "LY001", "ELY1", "ELY12345", "ELY1AB", "ELY1ABC", "ely1a", " ELY1 ", "E LY 1", "ELY\t1", "AFR", "AFR0", "", "ELY001  ",
        "123", "élY1", "ELY1", "QFA9", "ELY\u00A01", "ﬀY1",
    ).map { listOf(it, SuiviVol.normaliser(it)) }

    private fun memes(): List<List<Any?>> = listOf(
        "ELY001" to "ELY1", "ELY1" to "ELY11", "ELY000" to "ELY0", "ELY100" to "ELY1", "ely1" to "ELY001", " ELY1 " to "ELY1",
        "ELY1A" to "ELY001A", "ELY1A" to "ELY1", "ELY" to "ELY", "ELY1" to "", "" to "", "AFR12   " to "AFR12", "ELY001  " to "ELY1",
        "ELY1" to "ELY1 ", "EL1" to "EL1", "ELY1AB" to "ELY01AB", "ELY 1" to "ELY1",
    ).map { (x, y) -> listOf(x, y, SuiviVol.memeIndicatif(x, y)) }

    private fun raisons(): List<List<Any?>> = listOf(
        listOf("constantes", listOf(SuiviVol.Raison.HORS_LIGNE, SuiviVol.Raison.QUOTA, SuiviVol.Raison.ILLISIBLE, SuiviVol.Raison.POSITION_INVALIDE,
            SuiviVol.Raison.RELAIS_ABSENT, SuiviVol.Raison.SERVICE)),
    ) + listOf(429, 503, 500, 400, 404, 0, -1, 200).map { listOf("serveur", it, SuiviVol.Raison.serveur(it)) } +
        listOf("serveur_503", "serveur_429", "quota", "serveur_", "serveur_x", "serveur_-5", "hors_ligne", "", "serveur_12345678901",
            "serveur_\u0665\u0660\u0663", "serveur_+5", "serveur_-", "serveur_+", "serveur_ 5", "serveur_5 ", "serveur_2147483647",
            "serveur_-2147483648", "serveur_-2147483649", "serveur_2147483648", "serveur_0503", "SERVEUR_503").map {
            listOf("codeServeur", it, SuiviVol.Raison.codeServeur(it))
        } +
        listOf("opensky 429", "opensky 503", " opensky 500 ", "opensky injoignable", "x", "", "opensky  429", "Opensky 429", "opensky 4290",
            "opensky 99999999999", "opensky 2147483647", "opensky 2147483648", "opensky 4a", "opensky ٤٢٩").map {
            // Un nombre qui déborde lève (toInt) : null ici ; SuiviVol.lire le rend « illisible ».
            listOf("duRelais", it, runCatching { SuiviVol.Raison.duRelais(it) }.getOrNull())
        }

    private fun resultatSuivi(r: SuiviVol.Resultat): List<Any?> = when (r) {
        is SuiviVol.Resultat.Trouve -> listOf("trouve", r.point.instant.toEpochMilli(), r.point.latitude, r.point.longitude, r.altitudeMetres)
        SuiviVol.Resultat.Introuvable -> listOf("introuvable")
        is SuiviVol.Resultat.Erreur -> listOf("erreur", r.raison)
    }

    private val maintenant = Instant.parse("2026-11-10T18:35:00Z")

    private fun relevesRelais(): List<List<Any?>> {
        val m = maintenant.toEpochMilli()
        val corps = listOf(
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"altitude_geo":11200,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50,"longitude":-21,"instant":"2026-11-10T18:00:00Z"}""",
            """{"trouve":false}""", """{"erreur":"x"}""", "pas du json", "",
            """{"erreur":"opensky 429"}""", """{"erreur":"opensky 503","trouve":true}""", """{"erreur":"opensky 99999999999"}""", """{"erreur":null}""", """{"erreur":12}""",
            """{"trouve":"true","latitude":"50.5","longitude":"-21.2","instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":"oui","latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":1,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"altitude_baro":10900.5,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"altitude_geo":null,"altitude_baro":10900,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"altitude_geo":"haut","altitude_baro":"10900","instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":91,"longitude":-21.2,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":-90,"longitude":180,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":-90.0001,"longitude":0,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":0,"longitude":-180.5,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":91,"longitude":0,"instant":"2026-11-10T17:00:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:25:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:24:59.999Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:24:59.9999999Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:25:00.000000001Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:40:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00.123Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10t18:30:00z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T19:30:00+01:00"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T17:30:00-01:00"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10 18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00.Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-31T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T24:00:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:29:60Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":1762799400}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2}""",
            """{"trouve":true,"longitude":-21.2,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":null,"longitude":-21.2,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":"abc","longitude":-21.2,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":"NaN","longitude":-21.2,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"altitude_geo":"NaN","altitude_baro":12,"instant":"2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"altitude_geo":-0.5,"instant":"2026-11-10T18:30:00Z"}""",
            """[1,2]""", """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00Z"} reste""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00.1234567890Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T23:59:60Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T24:00:01Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00+01"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T19:30:30+01:00:30"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00+24:00"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00+00:60"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00-00:00"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00Zx"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":" 2026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-1-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T8:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2024-02-29T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-02-29T18:30:00Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00.Z","altitude_geo":1e3}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"2026-11-10T18:30:00\u0660Z"}""",
            """{"trouve":true,"latitude":50.5,"longitude":-21.2,"instant":"\u0662026-11-10T18:30:00Z"}""",
            """{"trouve":true,"latitude":-0.0,"longitude":-0.0,"instant":"2026-11-10T18:30:00Z","altitude_geo":-0.0}""",
            """{"trouve":true,"latitude":"50.5d","longitude":" -21.2 ","instant":"2026-11-10T18:30:00Z"}""",
        )
        return corps.map { c -> listOf(c, m, resultatSuivi(SuiviVol.lire(c, maintenant))) }
    }

    private fun adresses(): List<List<Any?>> {
        val point = { lat: Double, lon: Double -> Vol.Point(maintenant, lat, lon) }
        return listOf(
            Triple("https://r.test/", "ELY1", point(50.123, -20.36)),
            Triple("https://r.test", "ELY1", point(50.15, -20.25)),
            Triple("https://r.test///", "ELY 1", point(-0.04, 0.04)),
            Triple("https://r.test/v1/", "É/1&x=2", point(89.99, 179.99)),
            Triple("", "AFR12", point(-90.0, -180.0)),
            Triple("https://r.test", "a+b*c-d.e_f~g", point(0.05, 0.25)),
            Triple("https://r.test", "", point(1e-9, -1e-9)),
            Triple("https://r.test", "אל על", point(32.0, 34.9)),
        ).map { (relais, indicatif, p) -> listOf(relais, indicatif, p.latitude, p.longitude, SuiviVol.adresse(relais, indicatif, p)) }
    }

    private fun carres(): List<List<Any?>> = listOf(
        50.1 to -20.3, 10.0 to 178.0, 10.0 to -178.0, 88.0 to 0.0, -88.0 to 0.0, 0.0 to 175.0, 0.0 to -175.0, 0.0 to 175.0001,
        0.0 to 180.0, 0.0 to -180.0, 32.0 to 34.9, 89.95 to 179.95, -0.05 to -0.05, 45.0 to 174.9999,
    ).map { (lat, lon) ->
        val c = SuiviVol.carres(lat, lon)
        listOf(lat, lon, c.map { it.toList() }, c.map { SuiviVol.adresseEtats(it) })
    } + listOf(listOf(10.0, 178.0, SuiviVol.carres(10.0, 178.0, 1.0).map { it.toList() }, SuiviVol.carres(10.0, 178.0, 1.0).map { SuiviVol.adresseEtats(it) }))

    private fun etats(): List<List<Any?>> {
        val t = Instant.parse("2026-11-10T18:30:00Z").epochSecond
        val vieux = Instant.parse("2026-11-10T18:00:00Z").epochSecond
        val corps = listOf(
            """{"time":$t,"states":[
            ["abc","AFR12   ","France",$t,$t,-20.0,51.0,11000,false,250,270,0,null,11200,"1",false,0],
            ["def","ELY001  ","Israel",$t,$t,-21.2,50.5,10900,false,250,270,0,null,11150,"2",false,0]]}""",
            """{"time":$t,"states":[["def","ELY1","Israel",$t,$t,34.9,32.0,null,true,0,0,0,null,null,"2",false,0],
            ["def","ELY1","Israel",null,$t,null,null,null,false,0,0,0,null,null,"2",false,0]]}""",
            """{"time":0,"states":null}""", "<html>", "", """{"time":0}""", """{"states":[]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,false]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,null,false,0,0,0,null,null]]}""",
            """{"states":[["def","ELY1","Israel",$vieux,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,95.0,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel","$t",$t,"-21.2","50.5","10900","false",0,0,0,null,"11000"]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,"true",0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,1,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,"haut",false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,"haut"]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,"ouest",50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",${t}.7,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def",12,"Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY2","Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,11000],"x"]}""",
            """{"states":["x",["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[null,["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY2","Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,11000],["def","ELY01","Israel",$t,$t,-22.2,51.5,null,false,0,0,0,null,null]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,11000],["def","ELY1","Israel",$t,$t,-22.2,51.5,null,false,0,0,0,null,null]]}""",
            """{"states":{"a":1}}""", """{"states":"x"}""",
            """{"states":[["def","ELY1","Israel",$t,$t,"NaN",50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-21.2,50.5,10900,false,0,0,0,null,"Infinity"]]}""",
            """{"states":[["def","ELY1","Israel",$t,$t,-0.0,-0.0,-0.0,false,0,0,0,null,-0.0]]}""",
            """{"states":[["def","ELY1","Israel",9999999999999,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",-99999999999,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",99999999999999999,$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",${t + 1},$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",${t - 600},$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
            """{"states":[["def","ELY1","Israel",${t - 601},$t,-21.2,50.5,10900,false,0,0,0,null,11000]]}""",
        )
        return corps.flatMap { c -> listOf("ELY1", "AFR12", "ELY001", "XXX1").map { ind -> listOf(c, ind, maintenant.toEpochMilli(), resultatSuivi(SuiviVol.lireEtats(c, ind, maintenant))) } }
    }

    // --- Rappels en vol ------------------------------------------------------------------------------

    /** Les zmanim que lisent VolRappels (les bornes des prières) et VolCalendrier (chki'a et tsét). */
    private val clesLues = VolRappels.BORNES.flatMap { listOf(it.second, it.third) }.toSet() + setOf("chkia", "tset")

    private fun plan(de: String, vers: String, decollage: String, atterrissage: String): Vol.Plan {
        val d = a(de)
        val v = a(vers)
        return Vol.Plan("TEST", d, v, Vol.instant(LocalDateTime.parse(decollage), d)!!, Vol.instant(LocalDateTime.parse(atterrissage), v)!!)
    }

    private fun vols(): List<Map<String, Any?>> {
        val veille = generateSequence(LocalDate.parse("2027-01-01")) { it.plusDays(1) }.first { CalendrierJuif.jour(it.plusDays(1), false).omer == 4 }
        val veilleIsrael = generateSequence(LocalDate.parse("2027-01-01")) { it.plusDays(1) }.first { CalendrierJuif.jour(it.plusDays(1), true).omer == 20 }
        val liste = listOf(
            // Les trajets de VolRappelsTest.
            plan("MEL", "LAX", "2026-12-15T10:30", "2026-12-15T06:45") to false,
            plan("LAX", "YUL", "2026-12-15T09:30", "2026-12-15T17:55") to false,
            plan("YUL", "LAX", "2026-12-22T08:00", "2026-12-22T11:05") to false,
            plan("LAX", "MEL", "2026-12-22T22:30", "2026-12-24T08:45") to false,
            plan("SYD", "ZQN", "2026-12-18T09:00", "2026-12-18T14:15") to false,
            plan("TLV", "EZE", "2026-11-10T23:00", "2026-11-11T09:20") to false,
            plan("TLV", "JFK", "2026-11-10T12:30", "2026-11-10T17:45") to false,
            plan("JFK", "TLV", "2026-11-10T23:00", "2026-11-11T16:40") to false,
            plan("TLV", "JFK", "${veille}T17:00", "${veille}T22:15") to false,
            Vol.Plan("T", a("TLV"), a("ETM"), Instant.parse("2026-11-10T08:00:00Z"), Instant.parse("2026-11-10T08:04:00Z")) to false,
            // D'autres vols types.
            Vol.Plan("T", a("TLV"), a("ETM"), Instant.parse("2026-11-10T08:00:00Z"), Instant.parse("2026-11-10T08:05:00Z")) to false,
            plan("TLV", "ETM", "2026-11-10T16:20", "2026-11-10T17:15") to true,
            plan("CDG", "TLV", "2026-11-13T10:00", "2026-11-13T15:10") to false,
            plan("TLV", "BKK", "2026-11-12T23:30", "2026-11-13T12:40") to true,
            plan("LHR", "TLV", "2026-06-20T22:00", "2026-06-21T05:10") to false,
            plan("TLV", "LYS", "${veilleIsrael}T16:00", "${veilleIsrael}T19:30") to true,
            plan("TLV", "LYS", "${veilleIsrael}T16:00", "${veilleIsrael}T19:30") to false,
            plan("JFK", "HKG", "2026-12-01T10:00", "2026-12-02T15:00") to false,
            plan("SFO", "SIN", "2026-03-10T23:30", "2026-03-12T07:30") to false,
        )
        return liste.map { (p, israel) ->
            val c = Vol.calculer(p)
            val r = VolRappels.rappels(c, israel)
            val sondes = generateSequence(p.decollage - Duration.ofHours(2)) { it + Duration.ofMinutes(17) }
                .takeWhile { !it.isAfter(p.atterrissage + Duration.ofHours(2)) }.toList() +
                c.evenements.filter { it.cle in clesLues }.flatMap { listOf(it.instant, it.instant - Duration.ofMillis(1), it.instant + Duration.ofMillis(1)) }
                    .filter { !it.isBefore(p.decollage - Duration.ofHours(2)) && !it.isAfter(p.atterrissage + Duration.ofHours(2)) }
            linkedMapOf(
                "plan" to listOf(p.depart.iata, p.arrivee.iata, p.decollage.toEpochMilli(), p.atterrissage.toEpochMilli()),
                "enIsrael" to israel,
                "evenements" to c.evenements.filter { it.cle in clesLues }.map { listOf(it.cle, it.instant.toEpochMilli(), it.latitude, it.longitude) },
                "ouvertes" to sondes.distinct().sorted().map { t -> VolRappels.ouverte(c, t).let { o -> listOf(t.toEpochMilli(), o?.first, o?.second?.toEpochMilli()) } },
                "rappels" to r.map { listOf(it.type.name, it.instant.toEpochMilli(), it.priere, it.limite?.toEpochMilli(), it.omer) },
            )
        }
    }
}
