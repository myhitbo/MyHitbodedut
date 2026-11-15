// DanseMesure.kt devant la JVM : le pas du danseur à l'instant t d'une mesure, en simple précision, bit
// pour bit. Les 401 instants de DanseMesureTest, puis les voisins des seuils (fin du relais des poses,
// fin de la flexion, milieu et fin de mesure), des mesures négatives ou lointaines et les valeurs
// spéciales d'un Float. Chaque nombre est écrit par ses bits (floatToIntBits : un NaN unique).

import com.myhitbodedut.DanseMesure

object VecteursDanseMesure : Generateur {
    override val fichier = "danse_mesure.json"

    private fun voisins(x: Float): List<Float> = listOf(Math.nextDown(Math.nextDown(x)), Math.nextDown(x), x, Math.nextUp(x),
        Math.nextUp(Math.nextUp(x)))

    private val instants: List<Float> = buildList {
        for (i in 0..400) add(i / 400f)
        // Les seuils d'un temps (p = 0,1 et p = 0,14) vus de la mesure : t = p / 2, et dans le second temps.
        for (x in listOf(0f, 0.05f, 0.07f, 0.25f, 0.5f, 0.55f, 0.57f, 0.75f, 1f, 0.1f, 0.14f, 0.3f, 0.999f)) addAll(voisins(x))
        addAll(listOf(-0.0f, -0.25f, -0.5f, -0.75f, -1f, -1.3f, -7.95f, 1.25f, 2.5f, 3.7f, 10.05f, 123.456f, -123.456f,
            1e6f + 0.3f, 8_388_607.5f, 16_777_216f, 1e9f, -1e9f, Float.MAX_VALUE, -Float.MAX_VALUE, Float.MIN_VALUE,
            -Float.MIN_VALUE, 1e-30f, Float.NaN, Float.POSITIVE_INFINITY, Float.NEGATIVE_INFINITY))
        // Un balayage plus fin que celui du test, décalé pour ne pas retomber sur ses instants.
        for (i in 0 until 160) add(-2f + i * 0.0271f)
    }

    private fun bits(x: Float): Int = java.lang.Float.floatToIntBits(x)

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursDanseMesure.kt"),
        "tempsMs" to DanseMesure.TEMPS_MS,
        // [t, hauteur, flexion, balance, poseB] : t par floatToRawIntBits, les champs par floatToIntBits.
        "pas" to instants.map { t ->
            val p = DanseMesure.pas(t)
            listOf(java.lang.Float.floatToRawIntBits(t), bits(p.hauteur), bits(p.flexion), bits(p.balance), bits(p.poseB))
        },
    )
}
