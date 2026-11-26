package com.myhitbodedut

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Le ciel continu du Jour (24/11). Le propriétaire, d'après un fond d'écran animé qui suit le
 * cycle du jour, la Terre de jour et de nuit (NASA SVS 5477), des boucles d'aube et de coucher
 * illustrées et des aubes en accéléré : plus quatre ciels fixes, mais un ciel qui passe sans
 * à-coup par le noir de la nuit, le bleu du crépuscule, le violet, les rouges et les jaunes du
 * lever, l'heure dorée, le bleu du jour, l'orange et le violet du soir — d'après la hauteur
 * réelle du soleil au lieu choisi (Soleil), revue chaque minute.
 *
 * Ici, les couleurs brutes et les dosages, en fonction de la hauteur du soleil (degrés) et du
 * moment (matin ou soir) ; TeintesCiel les adapte au thème (lisibilité), CielPage les dessine.
 * Tout est pur et interpolé en continu entre des clés : CielContinuTest vérifie qu'aucune minute
 * ne saute. Les mêmes clés côté web (ciel.js).
 */
object CielContinu {

    /** Une clé : une hauteur du soleil et les trois couleurs du ciel (haut, milieu, horizon). */
    class Cle(val hauteur: Double, val haut: Int, val milieu: Int, val horizon: Int)

    private fun c(v: Long) = v.toInt()

    /** Le matin : nuit noire, bleu du crépuscule, heure bleue, rouges de l'aube, jaunes, heure dorée, bleu du jour. */
    val MATIN = listOf(
        Cle(-18.0, c(0xFF0A0E24), c(0xFF111839), c(0xFF1B2550)),
        Cle(-12.0, c(0xFF121C44), c(0xFF22336C), c(0xFF3A4E8E)),
        Cle(-6.0, c(0xFF222E69), c(0xFF56579A), c(0xFFB07898)),
        Cle(-2.0, c(0xFF36408A), c(0xFFA86A92), c(0xFFF08870)),
        Cle(0.0, c(0xFF4B5DA6), c(0xFFE2958A), c(0xFFFFAE76)),
        Cle(3.0, c(0xFF5A80C4), c(0xFFEEC29C), c(0xFFFFDDA0)),
        Cle(6.0, c(0xFF5994D6), c(0xFFB9D6EC), c(0xFFFBE5B6)),
        Cle(12.0, c(0xFF5AA5E6), c(0xFFA4D5F4), c(0xFFE2F3FB)),
        Cle(40.0, c(0xFF4E9BE2), c(0xFF96CDF2), c(0xFFDDF1FB)),
    )

    /** Le soir : bleu du jour, heure dorée, orange, coucher, violet du crépuscule, bleu, nuit noire. */
    val SOIR = listOf(
        Cle(-18.0, c(0xFF0A0E22), c(0xFF101733), c(0xFF18224A)),
        Cle(-12.0, c(0xFF131B46), c(0xFF23336C), c(0xFF3B4D8C)),
        Cle(-6.0, c(0xFF2C2A6C), c(0xFF5B4891), c(0xFFA2698C)),
        Cle(-3.0, c(0xFF463D8A), c(0xFF985C9C), c(0xFFDE7D78)),
        Cle(0.0, c(0xFF675FA6), c(0xFFE6826E), c(0xFFFF8A50)),
        Cle(2.0, c(0xFF6B7DC0), c(0xFFF0A472), c(0xFFFF9E5A)),
        Cle(6.0, c(0xFF6395D2), c(0xFFE4D2B0), c(0xFFFFD79E)),
        Cle(12.0, c(0xFF5AA5E6), c(0xFFA4D5F4), c(0xFFE2F3FB)),
        Cle(40.0, c(0xFF4E9BE2), c(0xFF96CDF2), c(0xFFDDF1FB)),
    )

    /** Une couleur qui suit la hauteur du soleil : des paires (hauteur, couleur), hauteurs croissantes. */
    class Suite(private val hauteurs: DoubleArray, private val couleurs: IntArray) {
        fun a(e: Double): Int {
            if (e <= hauteurs.first()) return couleurs.first()
            if (e >= hauteurs.last()) return couleurs.last()
            val i = hauteurs.indexOfFirst { it > e }
            val t = (e - hauteurs[i - 1]) / (hauteurs[i] - hauteurs[i - 1])
            return TeintesCiel.melange(couleurs[i - 1], couleurs[i], t)
        }
    }

    private fun suite(vararg p: Pair<Double, Long>) = Suite(p.map { it.first }.toDoubleArray(), p.map { it.second.toInt() }.toIntArray())

    /** Le disque du soleil : rouge-orangé à l'horizon, doré bas, jaune pâle haut. */
    val ASTRE = suite(0.0 to 0xFFFF8C4E, 3.0 to 0xFFFFB566, 8.0 to 0xFFFFDB8A, 20.0 to 0xFFFFF0B8, 40.0 to 0xFFFFF6CE)

    /** Sa lueur et sa couronne. */
    val LUEUR = suite(0.0 to 0xFFFF9A5C, 3.0 to 0xFFFFBE7E, 8.0 to 0xFFFFDFA0, 20.0 to 0xFFFFF6C8)

    /** La lune, et sa lueur. */
    const val LUNE = 0xFFF6F0D6.toInt()

    /**
     * Les nuages prennent la lumière du moment : leur corps et leur bord éclairé (le dessous,
     * tourné vers le soleil bas) — gris bleu pâle au crépuscule, roses et orangés à l'aube et au
     * coucher, dorés à l'heure dorée, blancs le jour.
     */
    val NUAGE_CORPS = suite(-12.0 to 0xFF5E6A8E, -6.0 to 0xFF6E6E9E, 0.0 to 0xFFE8A9A0, 4.0 to 0xFFF6D2B8, 10.0 to 0xFFFFFFFF)
    val NUAGE_BORD = suite(-12.0 to 0xFF7A86A8, -6.0 to 0xFFC88AA8, 0.0 to 0xFFFFB070, 4.0 to 0xFFFFD27A, 10.0 to 0xFFFFF4DC)

    /**
     * Les trois couleurs brutes du ciel pour [hauteur] : celles du matin et du soir mêlées selon
     * la part du [matin] (1 le matin, 0 le soir, entre les deux autour de midi et de minuit,
     * [partMatin]).
     */
    fun brutes(hauteur: Double, matin: Double): IntArray {
        if (matin >= 1.0) return selon(MATIN, hauteur)
        if (matin <= 0.0) return selon(SOIR, hauteur)
        val m = selon(MATIN, hauteur)
        val s = selon(SOIR, hauteur)
        return IntArray(3) { TeintesCiel.melange(s[it], m[it], matin) }
    }

    /** Le [matin] ou le soir, sans passage. */
    fun brutes(hauteur: Double, matin: Boolean): IntArray = brutes(hauteur, if (matin) 1.0 else 0.0)

    private fun selon(cles: List<Cle>, hauteur: Double): IntArray {
        if (hauteur <= cles.first().hauteur) return cles.first().let { intArrayOf(it.haut, it.milieu, it.horizon) }
        if (hauteur >= cles.last().hauteur) return cles.last().let { intArrayOf(it.haut, it.milieu, it.horizon) }
        val i = cles.indexOfFirst { it.hauteur > hauteur }
        val a = cles[i - 1]
        val b = cles[i]
        val t = (hauteur - a.hauteur) / (b.hauteur - a.hauteur)
        return intArrayOf(TeintesCiel.melange(a.haut, b.haut, t), TeintesCiel.melange(a.milieu, b.milieu, t), TeintesCiel.melange(a.horizon, b.horizon, t))
    }

    /**
     * La part du matin dans les couleurs, d'après l'angle horaire du soleil (degrés, négatif le
     * matin) : 1 le matin, 0 l'après-midi et le soir, et un passage d'une heure environ de part
     * et d'autre de midi et de minuit (le sinus de l'angle horaire de −0,25 à 0,25, soit 14,5°
     * du méridien). Là où le soleil reste bas à midi (le nord en hiver : 7° à Stockholm le 21/12)
     * ou haut à minuit (en été), les clés du matin et du soir ne se rejoignent pas : sans ce
     * passage, le ciel sautait d'un coup à midi ou à minuit (CielContinuTest). Ailleurs, rien ne
     * change : à midi le soleil est au-dessus de 12° et à minuit sous −18°, où les deux suites
     * sont les mêmes.
     */
    fun partMatin(angleHoraire: Double): Double = rampe(sin(angleHoraire * PI / 180), PASSAGE, -PASSAGE)
    const val PASSAGE = 0.25

    /**
     * L'astre s'efface là où son arc recommence, faute de quoi il sauterait d'un bord de l'écran à
     * l'autre : le soleil autour de minuit (il ne s'y montre que là où il ne se couche pas, au
     * jour polaire), la lune autour de midi (à la nuit polaire). Une heure de part et d'autre
     * (15° d'angle horaire) ; ailleurs, l'astre y est sous l'horizon et rien ne change.
     */
    fun fonduArc(angleHoraire: Double, soleil: Boolean): Double =
        if (soleil) rampe(abs(angleHoraire), 180.0, 165.0) else rampe(abs(angleHoraire), 0.0, 15.0)

    /** Une rampe douce : 0 à [de], 1 à [a] (de > a permis : la rampe descend). */
    fun rampe(x: Double, de: Double, a: Double): Double {
        val t = ((x - de) / (a - de)).coerceIn(0.0, 1.0)
        return t * t * (3 - 2 * t)
    }

    /** Thème sombre : la luminance de chaque arrêt, en part de la plus haute permise. */
    fun partsSombre(e: Double): FloatArray {
        val nuit = floatArrayOf(0.25f, 0.40f, 0.55f)
        val crepuscule = floatArrayOf(0.36f, 0.48f, 0.56f)
        val jour = floatArrayOf(0.38f, 0.44f, 0.52f)
        val (a, b, t) = when {
            e <= -12 -> Triple(nuit, nuit, 0.0)
            e < -3 -> Triple(nuit, crepuscule, (e + 12) / 9)
            e < 6 -> Triple(crepuscule, crepuscule, 0.0)
            e < 12 -> Triple(crepuscule, jour, (e - 6) / 6)
            else -> Triple(jour, jour, 0.0)
        }
        return FloatArray(3) { (a[it] + (b[it] - a[it]) * t).toFloat() }
    }

    /**
     * Le poids des couleurs chaudes de l'aube et du coucher, de 0 (nuit, jour) à 1 (−6° à +10°,
     * jusqu'au bout de l'heure dorée), nul à +16° : en thème sombre, ce qu'elles prennent du haut
     * du ciel (TeintesCiel). Il s'arrêtait à +12° : l'horizon de +6° à +12°, crème puis blanc
     * bleuté, passait par un vert-de-gris pâle qui, assombri, virait au kaki.
     */
    fun chaleur(e: Double): Double = rampe(e, -12.0, -6.0) * (1 - rampe(e, 10.0, 16.0))

    /** Les étoiles s'allument avec la profondeur du crépuscule : aucune à −4°, toutes à −14°. */
    fun etoiles(e: Double): Double = rampe(e, -4.0, -14.0)

    /** Les nuages : presque rien en pleine nuit, visibles dès le crépuscule. */
    fun nuages(e: Double): Double = 0.15 + 0.85 * rampe(e, -14.0, -6.0)

    /** Les rayons doux autour du soleil bas : à l'heure dorée seulement. */
    fun rayons(e: Double): Double = rampe(e, -2.0, 2.5) * (1 - rampe(e, 6.0, 10.0))

    /** Le disque du soleil paraît en se levant et s'efface en se couchant (−3° à +1°, une quinzaine de minutes). */
    fun soleilVisible(e: Double): Double = rampe(e, -3.0, 1.0)

    /** Au-dessus de −3°, c'est le soleil qui suit l'arc ; en dessous, la lune, qui paraît jusqu'à −7°. */
    fun soleilPlutotQueLune(e: Double): Boolean = e >= -3.0
    fun luneVisible(e: Double): Double = rampe(e, -3.0, -7.0)

    /**
     * La lueur large demeure un peu sous l'horizon, jusqu'à ce que la lune prenne le relais (de
     * 0° à −3° ; elle allait jusqu'à −6° et s'éteignait d'un coup à −3°, CielContinuTest).
     */
    fun lueurVisible(e: Double): Double = rampe(e, -3.0, 0.0)

    /** La hauteur dessinée, de 0 (l'horizon) à 1 (60° et plus) : le sinus de la hauteur. */
    fun elevationDessinee(e: Double): Double = (sin(e * PI / 180) / sin(PI / 3)).coerceIn(0.0, 1.0)

    /** Le rayon du soleil, en dp : un peu plus grand près de l'horizon. */
    fun rayonSoleil(e: Double): Float = (14.0 + 3.0 * (1 - rampe(e, 0.0, 15.0))).toFloat()
    const val RAYON_LUNE = 12f

    /**
     * La lune d'après le jour du mois hébreu (1 à 30) : son âge depuis le molad, la part éclairée
     * (0 nouvelle, 1 pleine) et si elle croît. Un fin croissant les premiers jours, la moitié vers
     * le 7 ou le 8, pleine le 14 ou le 15, puis elle décroît.
     */
    data class Lune(val age: Double, val eclairee: Double, val croissante: Boolean)

    const val MOIS_LUNAIRE = 29.530589

    fun lune(jourDuMois: Int): Lune {
        val age = (jourDuMois.coerceIn(1, 30) - 0.5)
        val angle = 2 * PI * age / MOIS_LUNAIRE
        return Lune(age, (1 - cos(angle)) / 2, age < MOIS_LUNAIRE / 2)
    }

    /** Une couleur en #RRGGBB, pour les messages des tests. */
    fun hexa(c: Int) = "#%06X".format(c and 0xFFFFFF)

    /** L'arrondi utilisé pour revoir le ciel au plus une fois par quart de degré. */
    fun arrondi(e: Double): Double = (e * 4).roundToInt() / 4.0
}

/**
 * Où en est le ciel : la hauteur du soleil (degrés), son angle horaire (degrés, négatif le
 * matin), la part du jour écoulée (0 au lever, 1 au coucher) et celle de la nuit (0 au coucher,
 * 1 au lever), le jour du mois hébreu (la lune).
 */
data class EtatCiel(val hauteur: Double, val angleHoraire: Double, val progresJour: Double, val progresNuit: Double, val jourHebreu: Int) {
    /** La part du matin dans les couleurs (CielContinu.partMatin). */
    val matin: Double get() = CielContinu.partMatin(angleHoraire)

    /** L'astre du moment (le soleil jusqu'à 3° sous l'horizon, puis la lune) et son opacité. */
    val estSoleil: Boolean get() = CielContinu.soleilPlutotQueLune(hauteur)
    val astreVisible: Double get() =
        (if (estSoleil) CielContinu.soleilVisible(hauteur) else CielContinu.luneVisible(hauteur)) * CielContinu.fonduArc(angleHoraire, estSoleil)

    /** La lueur large du soleil demeure un peu sous l'horizon (CielContinu.lueurVisible). */
    val lueurVisible: Double get() =
        if (estSoleil) maxOf(CielContinu.soleilVisible(hauteur), CielContinu.lueurVisible(hauteur)) * CielContinu.fonduArc(angleHoraire, true) else astreVisible

    companion object {
        fun de(position: Soleil.Position, jourHebreu: Int) =
            EtatCiel(position.hauteur, position.angleHoraire, position.progresJour, position.progresNuit, jourHebreu)
    }
}
