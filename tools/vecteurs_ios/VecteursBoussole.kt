// Le cap de la boussole devant la JVM : BoussoleActivity.capDevant et BoussoleActivity.lisser, que
// rejoue BoussoleTests de Coeur.
//
// BoussoleActivity est un écran : l'oracle ne le compile pas (fichiers.txt). Ses deux fonctions
// pures sont donc recopiées ici, et la recopie est gardée : le générateur s'arrête si leurs lignes
// ne sont plus, au retrait près, celles de BoussoleActivity.kt.
//
// Les matrices sont écrites en bits (Float.toRawBits) : Swift reçoit les mêmes Float, zéros signés
// compris, sans recalculer un sinus ni dépendre de la lecture des nombres par un décodeur JSON.
// D'abord les rotations de RepriseBoussoleTest (la matrice Z·X·Y de DeviceOrientation), sur un
// balayage d'angles ; puis des matrices quelconques (graine fixe), des zéros signés et des extrêmes.

import com.myhitbodedut.DirectionJerusalem
import java.io.File
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

object VecteursBoussole : Generateur {
    override val fichier = "boussole.json"

    // --- Recopiés de BoussoleActivity (compagnon), comparés à l'original par garde() -------------

    fun capDevant(r: FloatArray): Double {
        val est = r[1] - r[2]
        val nord = r[4] - r[5]
        return DirectionJerusalem.norm(Math.toDegrees(kotlin.math.atan2(est.toDouble(), nord.toDouble())))
    }

    fun lisser(avant: Double?, mesure: Double): Double =
        avant?.let { DirectionJerusalem.norm(it + DirectionJerusalem.ecart(mesure, it) * 0.2) } ?: mesure

    // ------------------------------------------------------------------------------------------------

    /** Les [n] lignes, sans leur retrait, à partir de la première qui commence par [debut]. */
    private fun lignes(texte: String, debut: String, n: Int): List<String> {
        val toutes = texte.lines().map { it.trim() }
        val i = toutes.indexOfFirst { it.startsWith(debut) }
        check(i >= 0) { "« $debut » introuvable" }
        return toutes.subList(i, i + n)
    }

    private fun garde() {
        val origine = File(DEPOT, "android/app/src/main/java/com/myhitbodedut/BoussoleActivity.kt").readText()
        val recopie = File(DEPOT, "tools/vecteurs_ios/VecteursBoussole.kt").readText()
        val fonctions = listOf("fun capDevant(r: FloatArray): Double {" to 5, "fun lisser(avant: Double?, mesure: Double): Double =" to 2)
        for ((debut, n) in fonctions) {
            check(lignes(origine, debut, n) == lignes(recopie, debut, n)) {
                "BoussoleActivity.kt a changé (« $debut ») : recopier la fonction dans VecteursBoussole.kt"
            }
        }
    }

    /** RepriseBoussoleTest : la matrice Est-Nord-Haut ← téléphone de DeviceOrientation (Z·X·Y), ligne par ligne. */
    private fun matrice(alpha: Double, beta: Double, gamma: Double): FloatArray {
        val r = Math.PI / 180
        val (cA, sA) = cos(alpha * r) to sin(alpha * r)
        val (cB, sB) = cos(beta * r) to sin(beta * r)
        val (cG, sG) = cos(gamma * r) to sin(gamma * r)
        return floatArrayOf(
            (cA * cG - sA * sB * sG).toFloat(), (-cB * sA).toFloat(), (cG * sA * sB + cA * sG).toFloat(),
            (cG * sA + cA * sB * sG).toFloat(), (cA * cB).toFloat(), (sA * sG - cA * cG * sB).toFloat(),
            (-cB * sG).toFloat(), sB.toFloat(), (cB * cG).toFloat(),
        )
    }

    private fun bits(r: FloatArray) = r.map { it.toRawBits() }

    /** Des matrices qui ne sont pas des rotations : seule la formule compte. */
    private fun quelconques(): List<FloatArray> {
        val hasard = Random(7)
        val tirees = (1..100).map { FloatArray(9) { hasard.nextFloat() * 2 - 1 } }
        val z = 0f
        val m = -0f
        val max = Float.MAX_VALUE
        val minuscule = Float.MIN_VALUE
        val cas = listOf(
            floatArrayOf(z, z, z, z, z, z, z, z, z),
            floatArrayOf(z, m, z, z, m, z, z, z, z), floatArrayOf(z, m, z, z, z, z, z, z, z),
            floatArrayOf(z, z, m, z, z, m, z, z, z), floatArrayOf(z, z, z, z, m, z, z, z, z),
            floatArrayOf(z, z, m, z, -1f, z, z, z, z), floatArrayOf(z, m, z, z, -1f, z, z, z, z),
            floatArrayOf(z, 0.5f, 0.5f, z, -0.25f, -0.25f, z, z, z),
            floatArrayOf(z, max, -max, z, 1f, z, z, z, z), floatArrayOf(z, -max, max, z, z, z, z, z, z),
            floatArrayOf(z, minuscule, z, z, minuscule, z, z, z, z), floatArrayOf(z, -minuscule, z, z, z, minuscule, z, z, z),
            floatArrayOf(z, 1f, 1f - 1e-7f, z, 1e-7f, z, z, z, z), floatArrayOf(z, 0.1f, 0.3f, z, 0.2f, 0.7f, z, z, z),
        )
        return cas + tirees
    }

    override fun produire(): Map<String, Any?> {
        garde()
        val alphas = listOf(0.0, 30.0, 90.0, 135.0, 180.0, 200.0, 270.0, 359.0)
        val betas = listOf(-180.0, -90.0, -60.0, -30.0, 0.0, 30.0, 45.0, 60.0, 80.0, 89.0, 89.9, 90.0, 90.1, 120.0, 180.0)
        val gammas = listOf(-90.0, -45.0, 0.0, 30.0, 90.0)
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursBoussole.kt"),
            // Une rotation : ses angles, ses neuf Float en bits, le cap où l'on fait face.
            "rotations" to alphas.flatMap { a -> betas.flatMap { b -> gammas.map { g -> Triple(a, b, g) } } }.map { (a, b, g) ->
                val r = matrice(a, b, g)
                linkedMapOf("alpha" to a, "beta" to b, "gamma" to g, "bits" to bits(r), "cap" to capDevant(r))
            },
            "quelconques" to quelconques().map { r -> linkedMapOf("bits" to bits(r), "cap" to capDevant(r)) },
            // Le filtre : sans mesure d'avant, de part et d'autre du nord, et hors de 0..360.
            "lisser" to listOf(null, 0.0, 10.0, 179.9, 180.0, 350.0, 359.99, -10.0, 400.0).flatMap { avant ->
                listOf(0.0, 10.0, 90.0, 180.0, 180.1, 270.0, 359.0, 359.99, -5.0, 725.0).map { mesure ->
                    linkedMapOf("avant" to avant, "mesure" to mesure, "lisse" to lisser(avant, mesure))
                }
            },
        )
    }
}
