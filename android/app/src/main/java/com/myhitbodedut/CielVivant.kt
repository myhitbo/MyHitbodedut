package com.myhitbodedut

import android.animation.ValueAnimator
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.drawable.Drawable
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.content.ContextCompat
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * Les petites animations des ciels (24/11, demande du propriétaire : « Améliore les
 * arrière-plans de l'application, on rajoute des petites animations discrètes »).
 *
 * Ce fichier tient la chorégraphie entière, en chiffres, pour qu'un autre port (iOS, web) la
 * reprenne à l'identique ; le dessin est dans CielPage (fond du Jour) et PaysageCiel (cartes
 * des accueils Sérénité et Instant).
 *
 * Ce qui bouge, et rien d'autre :
 *  - les étoiles scintillent, chacune à son rythme (8 à 16 s par cycle), entre 45 % et 100 %
 *    de leur éclat, jamais au-delà de l'éclat du ciel immobile ;
 *  - tout le champ d'étoiles dérive d'un rien : ±3 dp en largeur sur 40 s, ±1,5 dp en hauteur
 *    sur 31 s ;
 *  - le halo du soleil ou de la lune respire : sur 12 s, il se resserre de 6 % et pâlit de 18 %,
 *    puis revient ; son plus grand et son plus clair sont ceux du ciel immobile ;
 *  - le jour, deux nuages très pâles passent de gauche à droite à 3 dp/s ; à l'aube et au
 *    coucher, un long voile de lumière à 2 dp/s ; sortis d'un côté, ils reviennent de l'autre.
 *
 * Ce qui ne bouge jamais : les écrans de lecture (siddour, Tehilim, livres, halakha…), la séance
 * (sa lueur qui respire, SouffleView, est d'avant et reste seule), les fonds unis.
 *
 * Quand rien ne bouge (voir [permis]) : le ciel prend sa pose de repos, la même à chaque fois —
 * étoiles pleines, halo entier, nuages à leur place de départ. Pour PaysageCiel, c'est l'image
 * d'avant ces animations, au pixel près.
 */
object CielVivant {

    /** Une image toutes les 50 ms au plus (20 par seconde) : le plus rapide de ces mouvements avance de 0,15 dp par image. */
    const val IMAGE_MS = 50L

    // --- Les étoiles ---------------------------------------------------------------------

    /** Le cycle le plus court et le plus long d'un scintillement, en secondes. */
    const val SCINTILLEMENT_MIN_S = 8.0
    const val SCINTILLEMENT_MAX_S = 16.0

    /** Au plus bas du scintillement, l'étoile garde 45 % de son éclat. */
    const val SCINTILLEMENT_BAS = 0.45f

    /** La dérive du champ d'étoiles : amplitude en dp et période en secondes, en largeur puis en hauteur. */
    const val DERIVE_X_DP = 3f
    const val DERIVE_X_S = 40.0
    const val DERIVE_Y_DP = 1.5f
    const val DERIVE_Y_S = 31.0

    // --- Le halo -------------------------------------------------------------------------

    /** Un souffle du halo : 12 s. Au creux, 94 % de sa taille et 82 % de son éclat. */
    const val SOUFFLE_S = 12.0
    const val SOUFFLE_TAILLE = 0.06f
    const val SOUFFLE_ECLAT = 0.18f

    // --- Les nuages ----------------------------------------------------------------------

    /** Vitesse des nuages du jour, et du voile de l'aube et du coucher, en dp par seconde. */
    const val NUAGE_DP_S = 3f
    const val VOILE_DP_S = 2f

    /**
     * Le ciel bouge-t-il ? Non si le téléphone a coupé les animations (« Supprimer les
     * animations », ou la durée des animations à 0 dans les options pour les développeurs), ni
     * en économie de batterie. L'écran qui le montre l'arrête aussi dès qu'il n'est plus devant
     * (HorlogeCiel, GardeCiel).
     */
    fun permis(animationsDuSysteme: Boolean, economieDeBatterie: Boolean): Boolean =
        animationsDuSysteme && !economieDeBatterie

    /** Une onde douce de 0 (repos) à 1 et retour, sur [periode] secondes, décalée de [phase] (en tours). */
    fun onde(secondes: Double, periode: Double, phase: Double = 0.0): Float =
        ((1.0 - cos(2.0 * PI * (secondes / periode + phase))) / 2.0).toFloat()

    /** L'éclat d'une étoile, de [SCINTILLEMENT_BAS] à 1, selon son cycle et son décalage. */
    fun scintillement(secondes: Double, periode: Double, phase: Double): Float =
        1f - (1f - SCINTILLEMENT_BAS) * onde(secondes, periode, phase)

    /** Le décalage du champ d'étoiles, en dp. */
    fun deriveX(secondes: Double): Float = DERIVE_X_DP * sin(2.0 * PI * secondes / DERIVE_X_S).toFloat()
    fun deriveY(secondes: Double): Float = DERIVE_Y_DP * sin(2.0 * PI * secondes / DERIVE_Y_S + 1.3).toFloat()

    /** La taille du halo (1 au repos) et son éclat (1 au repos). */
    fun tailleHalo(secondes: Double): Float = 1f - SOUFFLE_TAILLE * onde(secondes, SOUFFLE_S)
    fun eclatHalo(secondes: Double): Float = 1f - SOUFFLE_ECLAT * onde(secondes, SOUFFLE_S)

    /**
     * Le bord gauche d'un nuage de largeur [largeurNuage] parti de [depart] à [vitesse] (unités
     * par seconde), dans un ciel de largeur [largeurCiel] : il sort à droite, revient à gauche.
     */
    fun nuageX(depart: Float, vitesse: Float, secondes: Double, largeurCiel: Float, largeurNuage: Float): Float {
        val tour = (largeurCiel + largeurNuage).toDouble()
        if (tour <= 0.0) return depart
        val x = ((depart + largeurNuage) + vitesse * secondes) % tour
        return (x - largeurNuage).toFloat()
    }

    /**
     * Les étoiles d'un ciel : pour chacune, sa place (fractions de la largeur et de la hauteur),
     * son rayon (dp), son cycle (s) et son décalage (tours). Tirées d'une graine fixe : le même
     * ciel d'une ouverture à l'autre.
     */
    fun etoiles(nombre: Int, graine: Long, rayonMin: Float, rayonMax: Float): FloatArray {
        val r = java.util.Random(graine)
        val t = FloatArray(nombre * CHAMPS)
        for (i in 0 until nombre) {
            t[i * CHAMPS] = r.nextFloat()
            t[i * CHAMPS + 1] = r.nextFloat()
            t[i * CHAMPS + 2] = rayonMin + r.nextFloat() * (rayonMax - rayonMin)
            t[i * CHAMPS + 3] = (SCINTILLEMENT_MIN_S + r.nextFloat() * (SCINTILLEMENT_MAX_S - SCINTILLEMENT_MIN_S)).toFloat()
            t[i * CHAMPS + 4] = r.nextFloat()
        }
        return t
    }

    /** Les champs d'une étoile dans le tableau de [etoiles] : x, y, rayon, cycle, décalage. */
    const val CHAMPS = 5
}

/**
 * Le battement d'un ciel animé : au plus une image toutes les [CielVivant.IMAGE_MS], et seulement
 * quand l'écran le permet ([permis], GardeCiel) et que le dessin est visible ([visible], que la
 * vue qui le porte tient à jour : onglet caché, écran quitté, vue détachée). Il ne demande
 * qu'à redessiner son dessin, rien d'autre : pas d'objet créé par image.
 */
class HorlogeCiel(private val dessin: Drawable) : Runnable {

    private val origine = SystemClock.uptimeMillis()
    private var programme = false

    var permis = false
        set(v) { if (field != v) { field = v; suivre() } }

    var visible = true
        set(v) { if (field != v) { field = v; suivre() } }

    /** Le ciel bouge en ce moment ; sinon il est dans sa pose de repos. */
    val enMarche: Boolean get() = permis && visible && ValueAnimator.areAnimatorsEnabled()

    /** Le temps du ciel, en secondes depuis sa création. */
    fun secondes(): Double = (SystemClock.uptimeMillis() - origine) / 1000.0

    /** À chaque dessin : un ciel qui doit bouger et dont le battement s'était perdu (vue rattachée) repart. */
    fun relancerSiBesoin() {
        if (!programme && enMarche) programmer()
    }

    private fun suivre() {
        dessin.unscheduleSelf(this)
        programme = false
        if (enMarche) programmer()
        dessin.invalidateSelf()
    }

    /**
     * Sans vue pour le porter (dessin pas encore posé en fond), rien n'est programmé : le premier
     * dessin le relancera. Captures du 24/11 : le paysage, animé avant d'être posé sur sa carte,
     * se croyait programmé et ne bougeait jamais.
     */
    private fun programmer() {
        if (dessin.callback == null) return
        programme = true
        dessin.scheduleSelf(this, SystemClock.uptimeMillis() + CielVivant.IMAGE_MS)
    }

    override fun run() {
        programme = false
        // Animations coupées en cours de route : une dernière image, celle du repos.
        dessin.invalidateSelf()
        if (enMarche) programmer()
    }
}

/**
 * Ce qui permet aux ciels d'un écran de bouger (CielVivant.permis), suivi tant que l'écran est
 * devant : à [reprendre] (onResume) et quand l'économiseur de batterie s'allume ou s'éteint ;
 * à [suspendre] (onPause), tout s'arrête.
 */
class GardeCiel(private val activite: Activity, private val changement: (Boolean) -> Unit) {

    private val economie = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) = changement(permis(activite))
    }
    private var ecoute = false

    fun reprendre() {
        if (!ecoute) {
            ContextCompat.registerReceiver(activite, economie,
                IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED), ContextCompat.RECEIVER_NOT_EXPORTED)
            ecoute = true
        }
        changement(permis(activite))
    }

    fun suspendre() {
        if (ecoute) {
            runCatching { activite.unregisterReceiver(economie) }
            ecoute = false
        }
        changement(false)
    }

    companion object {
        fun permis(context: Context): Boolean = CielVivant.permis(
            ValueAnimator.areAnimatorsEnabled(),
            (context.getSystemService(Context.POWER_SERVICE) as? PowerManager)?.isPowerSaveMode == true,
        )
    }
}
