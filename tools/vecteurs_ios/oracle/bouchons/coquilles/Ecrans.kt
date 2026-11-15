// Coquilles des écrans de l'app que les règles nomment : signatures seules, sauf trois recopies,
// dont build.gradle.kts vérifie qu'elles sont encore dans le fichier d'origine (« copies »).
package com.myhitbodedut

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

object BuildConfig {
    const val DEBUG = false
    const val APPLICATION_ID = "com.myhitbodedut"
    const val VERSION_NAME = "jvm"
    const val VERSION_CODE = 0
    const val HAS_GATE = true
    const val SUIVI_VOL = true
    const val RELAIS_VOL = ""
}

class MainActivity : Activity()
class ZmanimActivity : Activity()
class PaliersActivity : Activity()

class SessionActivity : Activity() {
    companion object {
        const val EXTRA_START_NOW = "start_now"
        const val EXTRA_DEPUIS_RAPPEL = "depuis_rappel"
    }
}

class LibraryEntryActivity : Activity() {
    companion object {
        const val EXTRA_ID = "entry_id"
    }
}

class SiddurLectureActivity : Activity() {
    companion object {
        fun intent(context: Context, id: String): Intent = Intent(context, SiddurLectureActivity::class.java).putExtra("id", id)
    }
}

class HalakhaActivity : Activity() {
    companion object {
        // Recopie de HalakhaActivity.kt.
        fun source(h: Halakha.Choisie): String =
            listOf("בן איש חי", if (h.annee == 1) "שנה ראשונה" else "שנה שנייה", h.section, "אות ${Reference.lettres(h.numero)}")
                .joinToString(" · ")
    }
}

object VueJour {
    fun carte(c: Context): LinearLayout = LinearLayout(c)
    fun texte(c: Context, valeur: CharSequence, taille: Float, couleurId: Int, gras: Boolean = false, haut: Int = 0): TextView =
        TextView(c)

    // Recopie de VueJour.kt.
    fun usageLevana(c: Context): Levana.Usage = Store.levanaUsage(c) ?: Levana.Usage.duNusah(Store.siddurNusah(c).cle)
}

class ReglagesLecture {
    data class Rendu(val echelle: Float, val sombre: Boolean, val fond: Int, val texte: Int, val discret: Int, val titre: Int)
    enum class Role { TEXTE, TITRE, DISCRET, FOND }

    companion object {
        // Recopie de ReglagesLecture.kt.
        const val MIN = 0.8f
        const val MAX = 2.0f
        fun <T : View> marquer(vue: T, role: Role): T = vue
    }
}

object TropheeDessin {
    fun icones(context: Context): Map<String, Path> = emptyMap()
    fun dessinerIcone(c: Canvas, trace: Path, cx: Float, cy: Float, taille: Float, p: Paint) {}
    fun traitIcone(): Paint = Paint()
}

object TropheesVue {
    fun description(c: Context, f: Any?, seuil: Int): String = ""
    fun nom(c: Context, f: Any?): String = ""
    fun metal(c: Context, m: Any?): String = ""
}

object PaliersVue {
    fun libelle(c: Context, piste: Any?, bilan: Any?): String = ""
    fun valeur(c: Context, piste: Any?, atteint: Any?): String = ""
}

object FicheTrophee {
    fun feter(activity: Activity, trophees: Any?) {}
}

object AnimationsTrophees {
    fun etincelles(activity: Activity, vue: View, grade: Any?) {}
}

object BoussoleWidget {
    fun refresh(context: Context) {}
}

object Barres {
    fun installer(activity: Activity) {}
}

object BandeauDefilant {
    fun installer(activity: Activity) {}
}

object AnneauxImage {
    fun notification(context: Context): android.graphics.Bitmap = android.graphics.Bitmap.createBitmap(1, 1, android.graphics.Bitmap.Config.ARGB_8888)
}
