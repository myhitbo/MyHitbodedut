// Bouchons : trois symboles de l'app que les fichiers compilés ici nomment, mais dont le fichier
// tient à Android (Langue.kt, ChizukCard.kt, HalakhaActivity.kt). Les tables ne les appellent
// pas. Le titre du Ben Ich Haï dans la recherche rend ses champs, pour les vecteurs (Recherche.kt).
package com.myhitbodedut

import android.content.Context

object RegleLangue {
    fun normalise(@Suppress("UNUSED_PARAMETER") etiquette: String?): String = error("bouchon : RegleLangue (Langue.kt)")
}

object ChizukCard {
    fun language(@Suppress("UNUSED_PARAMETER") context: Context): String = error("bouchon : ChizukCard")
}

class HalakhaActivity private constructor() {
    companion object {
        /** Le titre du Ben Ich Haï dans la recherche : ses trois champs, que le test Swift met en forme. */
        fun source(h: Halakha.Choisie): String = "ben_ish_hai:${h.annee}:${h.numero}:${h.section}"
    }
}
