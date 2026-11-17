package com.myhitbodedut

import com.kosherjava.zmanim.ComplexZmanimCalendar
import com.kosherjava.zmanim.util.GeoLocation
import com.kosherjava.zmanim.util.NOAACalculator
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Date
import java.util.GregorianCalendar
import java.util.TimeZone

/**
 * Les zmanim du jour (demande du 10/10), hors ligne, par KosherJava 2.5.0
 * (ComplexZmanimCalendar). Le profil est fixe et chaque ligne nomme sa
 * méthode : aucune appellation de communauté (« séfarade »…) ne choisit à
 * la place de l'utilisateur. Formules, sources et limites : ZMANIM.md. Les
 * méthodes ont été lues dans zmanim-2.5.0-sources.jar ; le profil a été
 * vérifié par le propriétaire (29/10).
 *
 * Le même profil existe côté web (web/src/js/zmanim.js, sur kosher-zmanim),
 * comparé à celui-ci par les vecteurs de web/test/vecteurs_kosherjava.json.
 *
 * Pas d'Android ici : testable sur la machine virtuelle seule.
 */
object Zmanim {

    const val MOTEUR = "KosherJava 2.5.0, NOAACalculator"

    data class Lieu(
        val nom: String,
        val latitude: Double,
        val longitude: Double,
        /** En mètres. Le profil calcule au niveau de la mer : elle n'entre dans aucun zman. */
        val altitude: Double,
        /** Fuseau IANA, « Asia/Jerusalem ». */
        val fuseau: String,
    )

    enum class Statut {
        OK,

        /**
         * L'événement n'a pas lieu ce jour-là (soleil de minuit, nuit polaire) : ce n'est pas une erreur.
         * L'aube à 16,1° manque dès environ 50,5° N autour du solstice d'été (Londres ; audit du 16/11).
         */
        ABSENT,

        /** Le calcul a échoué : une erreur technique, distincte d'un événement absent. */
        ERREUR,
    }

    /** Une méthode : sa clé (libellé « zman_methode_<clé> ») et ses paramètres. */
    data class Methode(val cle: String, val parametres: String)

    /** Le format commun : le même côté web (zmanim.js). */
    data class Zman(
        val cle: String,
        val methode: Methode,
        val statut: Statut,
        val instant: Instant?,
        /** L'heure dans le fuseau du lieu ; sa date peut être le lendemain (chatsot de la nuit). */
        val local: ZonedDateTime?,
        val moteur: String = MOTEUR,
    )

    /**
     * Le profil, dans l'ordre de la journée. Pour chaque zman : la méthode
     * de ComplexZmanimCalendar qui le calcule. Rien d'autre ne décide.
     */
    val PROFIL: List<Pair<String, Methode>> = listOf(
        "alot" to Methode("degres", "16.1"),                 // getAlos16Point1Degrees
        "misheyakir" to Methode("degres", "11.5"),           // getMisheyakir11Point5Degrees
        "netz" to Methode("niveau_mer", ""),                 // getSeaLevelSunrise
        "szks_mga" to Methode("mga_72", "72"),               // getSofZmanShmaMGA
        "szks_gra" to Methode("gra", ""),                    // getSofZmanShmaGRA
        "szt_mga" to Methode("mga_72", "72"),                // getSofZmanTfilaMGA
        "szt_gra" to Methode("gra", ""),                     // getSofZmanTfilaGRA
        "chatsot" to Methode("meridien", ""),                // getChatzos (= getSunTransit en 2.5.0)
        "minha_gedola" to Methode("gra", ""),                // getMinchaGedola
        "minha_ketana" to Methode("gra", ""),                // getMinchaKetana
        "plag" to Methode("gra", ""),                        // getPlagHamincha
        "chkia" to Methode("niveau_mer", ""),                // getSeaLevelSunset
        "tset" to Methode("degres", "8.5"),                  // getTzaisGeonim8Point5Degrees
        "tset_rt" to Methode("minutes", "72"),               // getTzais72
        "chatsot_layla" to Methode("milieu_chatsot", ""),    // getSolarMidnight
    )

    /**
     * Le profil des Edot (audit du 16/11) : les zmanim du Yalkut Yosef à la place de ceux de
     * [PROFIL] ; les autres lignes restent communes. Sfard et Ashkenaz gardent [PROFIL] (Biour
     * Halakha 89:1 ne fixe pas de méthode pour l'aube ; MB 233:4 rapporte le plag du Gra ;
     * Biour Halakha 261:2 dispense des zmaniyot pour Rabbénou Tam). L'heure zmanit est celle du
     * Gra (du lever au coucher au niveau de la mer).
     *  - aube : 72 min zmaniyot avant le lever (Kitsour Yalkut Yosef 89:12) ;
     *  - michéyakir : 6 min zmaniyot après cette aube (calendrier Or ha'Haïm, proposé par l'audit) ;
     *  - Maguen Avraham : journée de 72 min zmaniyot de chaque côté (Kitsour YY 58:3 et 89:12) ;
     *  - tsét : 13,5 min zmaniyot après le coucher (Kitsour YY 233:5) ;
     *  - plag : 1¼ heure zmanit avant ce tsét (Kitsour YY 263:45) ;
     *  - Rabbénou Tam : 72 min zmaniyot après le coucher (Kitsour YY 293:3 et 293:7).
     */
    val PROFIL_EDOT: Map<String, Methode> = mapOf(
        "alot" to Methode("zmaniyot_avant_netz", "72"),       // getAlos72Zmanis
        "misheyakir" to Methode("zmaniyot_avant_netz", "66"), // lever − 1,1 heure zmanit
        "szks_mga" to Methode("mga_72_zmaniyot", "72"),       // getSofZmanShmaMGA72MinutesZmanis
        "szt_mga" to Methode("mga_72_zmaniyot", "72"),        // getSofZmanTfilaMGA72MinutesZmanis
        "plag" to Methode("plag_yalkut_yosef", ""),           // coucher − 1,025 heure zmanit
        "tset" to Methode("zmaniyot_apres_chkia", "13.5"),    // coucher + 0,225 heure zmanit
        "tset_rt" to Methode("zmaniyot_apres_chkia", "72"),   // getTzais72Zmanis
    )

    /** Le noussa'h « commun » : le profil [PROFIL] (Sfard, Ashkenaz, et tout appel sans noussa'h). */
    const val NUSAH_COMMUN = ""

    /** Le profil d'un noussa'h : [PROFIL], où les Edot prennent les lignes de [PROFIL_EDOT]. */
    fun profil(nusah: String = NUSAH_COMMUN): List<Pair<String, Methode>> =
        if (nusah == "edot") PROFIL.map { (cle, m) -> cle to (PROFIL_EDOT[cle] ?: m) } else PROFIL

    /** L'allumage : coucher au niveau de la mer moins [minutes] (getCandleLighting). */
    fun methodeAllumage(minutes: Int) = Methode("avant_chkia", minutes.toString())

    /** Les minutes d'allumage proposées dans les réglages ; 18 par défaut. */
    val ALLUMAGES = listOf(18, 20, 22, 30, 40)
    const val ALLUMAGE_DEFAUT = 18

    fun calendrier(lieu: Lieu, date: LocalDate): ComplexZmanimCalendar {
        val fuseau = TimeZone.getTimeZone(lieu.fuseau)
        val geo = GeoLocation(lieu.nom, lieu.latitude, lieu.longitude, lieu.altitude, fuseau)
        return ComplexZmanimCalendar(geo).apply {
            calendar = GregorianCalendar(fuseau).apply {
                clear()
                set(date.year, date.monthValue - 1, date.dayOfMonth, 12, 0)
            }
            // Explicite, même si c'est le défaut : le profil calcule au niveau de la mer.
            isUseElevation = false
            // L'algorithme de la NOAA (US National Oceanic and Atmospheric
            // Administration), écrit plutôt que laissé au défaut de la
            // bibliothèque : ZmanimTest le compare aux formules de la NOAA.
            astronomicalCalculator = NOAACalculator()
        }
    }

    /** Les quinze zmanim du profil de [nusah] pour [date] au [lieu]. */
    fun jour(lieu: Lieu, date: LocalDate, nusah: String = NUSAH_COMMUN): List<Zman> {
        val c = calendrier(lieu, date)
        val zone = ZoneId.of(lieu.fuseau)
        // getSolarMidnight prend le milieu entre chatsot d'aujourd'hui et de
        // demain, sans vérifier qu'ils existent : au-delà du cercle polaire,
        // l'un des deux manque et la bibliothèque lèverait une exception là où
        // l'événement est simplement absent.
        val nuitCalculable = c.chatzos != null && calendrier(lieu, date.plusDays(1)).chatzos != null
        val edot = nusah == "edot"
        return profil(nusah).map { (cle, methode) ->
            zman(cle, methode, zone) {
                when {
                    cle == "chatsot_layla" && !nuitCalculable -> null
                    edot && cle in PROFIL_EDOT -> valeurEdot(c, cle)
                    else -> valeur(c, cle)
                }
            }
        }
    }

    /** L'allumage des bougies ce jour-là au [lieu], [minutes] avant la chki'a. */
    fun allumage(lieu: Lieu, date: LocalDate, minutes: Int): Zman {
        val c = calendrier(lieu, date).apply { candleLightingOffset = minutes.toDouble() }
        return zman("allumage", methodeAllumage(minutes), ZoneId.of(lieu.fuseau)) { c.candleLighting }
    }

    /**
     * Les heures du 'hamets la veille de Pessa'h (audit du 16/11) : fin de la consommation (fin
     * de la 4e heure) et fin du bi'our (fin de la 5e heure), selon le Maguen Avraham puis selon
     * le Gra. Edot : heures zmaniyot de l'aube à tsét, à 72 min zmaniyot (Kitsour Yalkut Yosef
     * 443:1, « וחושבים השעות בשעות זמניות מעמוד השחר עד צאת הכוכבים ») ; les autres : la journée de
     * 72 min fixes de la ligne « Fin du Chema (Maguen Avraham) ». Choul'han Aroukh 443:1.
     */
    fun hamets(lieu: Lieu, date: LocalDate, nusah: String = NUSAH_COMMUN): List<Zman> {
        val c = calendrier(lieu, date)
        val zone = ZoneId.of(lieu.fuseau)
        val edot = nusah == "edot"
        val mga = if (edot) Methode("mga_72_zmaniyot", "72") else Methode("mga_72", "72")
        fun heures(debut: Date?, heure: Long, n: Int): Date? =
            if (debut == null || heure == Long.MIN_VALUE) null else Date(debut.time + n * heure)
        fun mgaHeures(n: Int): Date? =
            if (edot) heures(c.alos72Zmanis, c.shaahZmanis72MinutesZmanis, n) else heures(c.alos72, c.shaahZmanisMGA, n)
        return listOf(
            zman("hamets_achila", mga, zone) { mgaHeures(4) },
            zman("hamets_achila", Methode("gra", ""), zone) { heures(c.seaLevelSunrise, c.shaahZmanisGra, 4) },
            zman("hamets_biour", mga, zone) { mgaHeures(5) },
            zman("hamets_biour", Methode("gra", ""), zone) { heures(c.seaLevelSunrise, c.shaahZmanisGra, 5) },
        )
    }

    /** Les lignes de [PROFIL_EDOT], en heures zmaniyot du Gra (lever et coucher au niveau de la mer). */
    private fun valeurEdot(c: ComplexZmanimCalendar, cle: String): Date? {
        val heure = c.shaahZmanisGra
        fun decale(d: Date?, heures: Double): Date? =
            if (d == null || heure == Long.MIN_VALUE) null else Date(d.time + Math.round(heures * heure))
        return when (cle) {
            "alot" -> c.alos72Zmanis
            "misheyakir" -> decale(c.seaLevelSunrise, -1.1)
            "szks_mga" -> c.sofZmanShmaMGA72MinutesZmanis
            "szt_mga" -> c.sofZmanTfilaMGA72MinutesZmanis
            "plag" -> decale(c.seaLevelSunset, -1.025)
            "tset" -> decale(c.seaLevelSunset, 0.225)
            "tset_rt" -> c.tzais72Zmanis
            else -> error("zman Edot inconnu : $cle")
        }
    }

    private fun valeur(c: ComplexZmanimCalendar, cle: String): Date? = when (cle) {
        "alot" -> c.alos16Point1Degrees
        "misheyakir" -> c.misheyakir11Point5Degrees
        "netz" -> c.seaLevelSunrise
        "szks_mga" -> c.sofZmanShmaMGA
        "szks_gra" -> c.sofZmanShmaGRA
        "szt_mga" -> c.sofZmanTfilaMGA
        "szt_gra" -> c.sofZmanTfilaGRA
        "chatsot" -> c.chatzos
        "minha_gedola" -> c.minchaGedola
        "minha_ketana" -> c.minchaKetana
        "plag" -> c.plagHamincha
        "chkia" -> c.seaLevelSunset
        "tset" -> c.tzaisGeonim8Point5Degrees
        "tset_rt" -> c.tzais72
        "chatsot_layla" -> c.solarMidnight
        else -> error("zman inconnu : $cle")
    }

    /**
     * KosherJava rend null quand l'événement n'a pas lieu (au-delà du cercle
     * polaire) ; une exception est une erreur. Les deux ne se confondent pas.
     */
    private fun zman(cle: String, methode: Methode, zone: ZoneId, calcul: () -> Date?): Zman = try {
        val d = calcul()
        if (d == null) Zman(cle, methode, Statut.ABSENT, null, null)
        else Zman(cle, methode, Statut.OK, d.toInstant(), d.toInstant().atZone(zone))
    } catch (e: RuntimeException) {
        Zman(cle, methode, Statut.ERREUR, null, null)
    }
}
