package com.myhitbodedut

import java.util.Locale

/**
 * Les chiffres des nombres que l'application écrit elle-même (distances, coordonnées, séries,
 * pourcentages). En arabe, toujours 0 à 9, comme dans le reste de l'interface (décision du
 * 24/11) : la langue de l'application se lit souvent sans sa région (« ar »), et l'arabe sans
 * région s'écrit en chiffres arabes orientaux (٠١٢٣), là où l'arabe de Tunisie s'écrit en
 * 0 à 9. Les autres langues ne changent pas.
 */
object Chiffres {

    fun locale(base: Locale): Locale =
        if (base.language == "ar") Locale.Builder().setLocale(base).setUnicodeLocaleKeyword("nu", "latn").build() else base

    fun locale(langue: String): Locale = locale(Locale.forLanguageTag(langue))
}
