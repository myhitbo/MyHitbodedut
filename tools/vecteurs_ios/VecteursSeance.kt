// L'arithmétique d'une séance et la durée saisie devant la JVM : ce que répondent SessionRule et
// DureeSeance d'Android, que rejouent SessionRuleTests et DureeSeanceTests de Coeur.
//
// Les instants sont des millisecondes Unix. Ils sont écrits en chaînes : certains cas vont jusqu'aux
// bornes d'un Long, qu'un nombre JSON ne porte pas à coup sûr. Les textes saisis sont écrits en unités
// UTF-16, pour que leurs blancs et leurs chiffres ne dépendent d'aucun éditeur.

import com.myhitbodedut.DureeSeance
import com.myhitbodedut.SessionRule

object VecteursSeance : Generateur {
    override val fichier = "seance.json"

    private const val MINUTE = 60_000L

    /** Le début de SessionRuleTest. */
    private const val DEBUT = 1_700_000_000_000L

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursSeance.kt"),
        "constantes" to linkedMapOf(
            "ouverte" to SessionRule.OUVERTE, "plafondOuverte" to SessionRule.PLAFOND_OUVERTE,
            "proposees" to DureeSeance.PROPOSEES.toList(), "min" to DureeSeance.MIN, "max" to DureeSeance.MAX,
        ),
        "compteurs" to listOf(false to false, true to false, false to true, true to true).map { (ouverte, masque) ->
            linkedMapOf("ouverte" to ouverte, "masque" to masque, "compteur" to SessionRule.compteur(ouverte, masque).name)
        },
        // Une ligne par séance inscrite ; ses réponses, instant par instant, dans l'ordre de « maintenant ».
        "seances" to seances().map(::reponses),
        // DureeSeance.lire : « ecrit » est le texte tel qu'on l'écrirait dans du Kotlin, pour le lire d'un coup d'œil.
        "lectures" to textes.map { t ->
            linkedMapOf("ecrit" to ecrit(t), "unites" to t.map { it.code }, "lu" to DureeSeance.lire(t))
        },
        // Chaque entier de « premier » à 500, écrit comme le fait toString : la borne basse, la borne haute.
        "entiers" to linkedMapOf("premier" to -300, "lus" to (-300..500).map { DureeSeance.lire(it.toString()) }),
        // Chaque unité du plan de base d'Unicode, après puis avant le chiffre 1 : [unité, nombre lu], et rien
        // pour ce qui n'est pas un nombre. Après : un chiffre donne 10 à 19, un blanc rogné laisse 1.
        // Avant : un chiffre donne 1, 11, 21… 91, un blanc ou un signe laissent 1.
        "unitesApres" to (0..0xFFFF).mapNotNull { code -> DureeSeance.lire("1" + code.toChar())?.let { listOf(code, it) } },
        "unitesAvant" to (0..0xFFFF).mapNotNull { code -> DureeSeance.lire(code.toChar() + "1")?.let { listOf(code, it) } },
    )

    // --- SessionRule ---------------------------------------------------------------------------------

    private class Seance(val debut: Long, val fin: Long, val duree: Int)

    /** Ce que `Store.beginSession` inscrit : une durée nulle ouvre la séance, sans fin. */
    private fun commencee(debut: Long, minutes: Int): Seance =
        if (minutes <= SessionRule.OUVERTE) Seance(debut, 0L, SessionRule.OUVERTE) else Seance(debut, debut + minutes * MINUTE, minutes)

    private fun seances(): List<Seance> = buildList {
        // Telles que l'app les inscrit : ouverte, puis minutées jusqu'au plafond de 240 et au-delà.
        for (minutes in listOf(0, 1, 2, 5, 10, 15, 20, 30, 60, 90, 239, 240, 241, 600)) add(commencee(DEBUT, minutes))
        // Des inscriptions qui ne se tiennent pas : chaque branche doit répondre quand même.
        add(Seance(DEBUT, 0L, 20))                              // minutée, sans fin inscrite
        add(Seance(DEBUT, DEBUT, 20))                           // finie dès son début
        add(Seance(DEBUT, DEBUT - MINUTE, 20))                  // finie avant son début
        add(Seance(DEBUT, DEBUT + 1, 20))
        add(Seance(DEBUT, DEBUT + 59_999, 1))                   // moins d'une minute pleine
        add(Seance(DEBUT, DEBUT + 20 * MINUTE, 240))            // la fin ne suit pas la durée
        add(Seance(DEBUT, DEBUT + 20 * MINUTE, 0))              // ouverte par sa durée, avec une fin
        add(Seance(DEBUT, 1L, 0))                               // une fin passée depuis longtemps
        add(Seance(DEBUT, 1L, 20))
        add(Seance(DEBUT, -1L, 0))                              // une fin négative
        add(Seance(DEBUT, -1L, 20))
        add(Seance(DEBUT, 0L, -1))                              // une durée négative
        add(Seance(DEBUT, DEBUT + 20 * MINUTE, -1))
        add(Seance(DEBUT, DEBUT + 20 * MINUTE, Int.MAX_VALUE))
        add(Seance(DEBUT, 0L, Int.MIN_VALUE))
        add(Seance(DEBUT, Long.MAX_VALUE, 20))                  // une fin aux bornes d'un Long
        add(Seance(DEBUT, Long.MAX_VALUE, 0))
        add(Seance(DEBUT, Long.MIN_VALUE, 20))
        // Aucune séance : le début à zéro, ou négatif.
        for (debut in listOf(0L, -1L, -MINUTE, Long.MIN_VALUE)) {
            add(Seance(debut, 0L, 0))
            add(Seance(debut, 0L, 20))
            add(Seance(debut, DEBUT + 20 * MINUTE, 20))
            add(Seance(debut, DEBUT + 20 * MINUTE, 0))
        }
        // Le plus petit début, et les plus grands : la fin d'une séance minutée y déborde d'un Long.
        for (debut in listOf(1L, MINUTE, Long.MAX_VALUE - 20 * MINUTE, Long.MAX_VALUE)) {
            add(commencee(debut, 0))
            add(commencee(debut, 20))
        }
    }

    /** Les instants « maintenant » : autour de chaque frontière de la séance, puis une horloge déréglée. */
    private fun instants(s: Seance): List<Long> {
        val d = s.debut
        val f = s.fin
        val plafond = d + SessionRule.PLAFOND_OUVERTE * MINUTE
        val deux31 = 1L shl 31
        return sortedSetOf(
            // Le début, et les premières minutes pleines ; 1 s et 10 min sont des instants de SessionRuleTest.
            d - MINUTE, d - 1, d, d + 1, d + 1_000, d + 59_999, d + MINUTE, d + MINUTE + 1, d + 2 * MINUTE - 1,
            d + 2 * MINUTE, d + 10 * MINUTE, d + 47 * MINUTE + 30_000,
            // La fin.
            f - 10 * MINUTE, f - MINUTE - 1, f - MINUTE, f - MINUTE + 1, f - 59_999, f - 1_000, f - 1, f, f + 1,
            f + 59_999, f + MINUTE, f + 60 * MINUTE,
            // Le plafond d'une séance ouverte, puis le lendemain.
            plafond - MINUTE, plafond - 1, plafond, plafond + 1, plafond + MINUTE - 1, plafond + MINUTE, d + 24 * 60 * MINUTE,
            // L'horloge déréglée, et l'heure des tests d'Android pour ce qui n'a ni début ni fin.
            0L, 1L, -1L, DEBUT, DEBUT + MINUTE, Long.MAX_VALUE, Long.MIN_VALUE,
            // Plus de minutes qu'un Int n'en porte : toInt() n'en garde que les 32 bits de poids faible.
            d + deux31 * MINUTE - 1, d + deux31 * MINUTE, d + (2 * deux31 + 5) * MINUTE,
            f - deux31 * MINUTE, f - (deux31 - 1) * MINUTE, f - (2 * deux31 + 7) * MINUTE,
        ).toList()
    }

    private fun reponses(s: Seance): Map<String, Any?> {
        val instants = instants(s)
        return linkedMapOf(
            "debut" to s.debut.toString(), "fin" to s.fin.toString(), "duree" to s.duree,
            "estOuverte" to SessionRule.estOuverte(s.debut, s.duree),
            "maintenant" to instants.map { it.toString() },
            "enCours" to instants.map { SessionRule.enCours(s.debut, s.fin, s.duree, it) },
            "minutesEcoulees" to instants.map { SessionRule.minutesEcoulees(s.debut, it) },
            "minutesAInscrire" to instants.map { SessionRule.minutesAInscrire(s.debut, s.fin, it) },
            "estEchue" to instants.map { SessionRule.estEchue(s.debut, s.fin, s.duree, it) },
            "minutesRestantes" to instants.map { SessionRule.minutesRestantes(s.fin, it) },
        )
    }

    // --- DureeSeance ---------------------------------------------------------------------------------

    private val textes = listOf(
        // DureeSeanceTest.
        " 25 ", "0", "600", "", "vingt",
        // Les bornes, les signes, les zéros de tête.
        "1", "2", "25", "239", "240", "241", "-1", "-0", "+0", "+5", "-5", "+240", "+241", "-240", "00012", "000",
        "0".repeat(50) + "25", "-" + "0".repeat(50) + "25",
        // Les 32 bits d'un Int de Kotlin : au-delà, ce n'est plus un nombre.
        "2147483647", "2147483648", "+2147483647", "+2147483648", "-2147483647", "-2147483648", "-2147483649",
        "4294967296", "4294967321", "-4294967271", "9223372036854775807", "9223372036854775808", "18446744073709551641",
        "9".repeat(40), "-" + "9".repeat(40),
        // Ce qui n'est pas un entier.
        "2.5", "2,5", "25.", ".5", "1e2", "0x10", "1_000", "1 000", "2 5", "12a", "a12", "+", "-", "+-5", "-+5", "--5", "++5",
        "5-", "5+", "- 5", "+ 5", "25 min", "1h30", "1:30", "#5", "(5)", "/5", "*5", "%5", "'5", "\"5\"",
        // Les blancs de Kotlin aux deux bouts : rognés. Tabulation, fins de ligne, séparateurs de fichier,
        // insécables, espaces d'Unicode, séparateurs de ligne et de paragraphe.
        " 25", "25 ", "   25   ", "\t25\n", "\r\n25\r\n", "\u000B25\u000C", "\u001C25\u001D", "\u001E25\u001F",
        " 25 ", " 25", " 25 ", " 25", "25 ", " 25", "　25　",
        "  25  ", " +5 ", " -5 ", " +25", " ", "   ", "\n", "\t", " ", "　",
        // Ce qui ressemble à un blanc et n'en est pas un pour Kotlin : le texte n'est plus un nombre.
        "\u008525", "25\u0085", "᠎25", "​25", "25​", "‌25", "‎25", "‏25", "‫25‬",
        "⁠25", "﻿25", "25﻿", "\u000025", "25\u0000", "\u000825", "\u001B25", "\u007F25",
        // Un blanc au milieu n'est jamais rogné.
        "2 5", "2 5", "2 5", "2\t5",
        // Les chiffres des autres écritures (Character.digit) : arabes, persans, n'ko, devanagari, bengalis,
        // thaïs, tibétains, khmers, mongols, pleine chasse ; mêlés aux chiffres ASCII ; avec un signe.
        "٢٥", "۲۵", "߂߅", "२५", "২৫", "๒๕", "༢༥",
        "២៥", "᠒᠕", "２５", "2٥", "٢2", "٠٠٣", "-٥", "+٥",
        " ٢٥ ", "１２３４", "٩٩٩", "٢٤٠", "٢٤١",
        "٠", "０", "٢١٤٧٤٨٣٦٤٧",
        "٢١٤٧٤٨٣٦٤٨",
        // Des nombres qui ne sont pas des chiffres décimaux : exposant, fraction, chiffre romain, idéogrammes,
        // chiffre cerclé, chiffre en indice, chiffre éthiopien, chiffre tamoul dix.
        "²", "½", "Ⅻ", "一", "〇", "①", "₂", "፩", "௰", "2²",
        // Hors du plan de base, Kotlin voit deux moitiés de paire, pas un chiffre : gras mathématique, adlam.
        "𝟐𝟓", "𞥒", "2𝟓",
        // Des signes qui ne sont pas ceux d'ASCII : moins typographique, plus pleine chasse, trait d'union.
        "−5", "＋5", "﹣5", "‐5", "–5",
        // De l'hébreu : des lettres pour un nombre, un mot après le nombre, un texte vocalisé.
        "כה", "כ״ה", "25 דקות", "25 דק׳", "דקות 25", "בְּרֵאשִׁית", "שלום", "כָּה",
    )

    /** Le texte comme on l'écrirait dans du Kotlin : ASCII tel quel, le reste en \uXXXX. */
    private fun ecrit(texte: String): String =
        texte.map { c -> if (c in ' '..'~') c.toString() else "\\u%04X".format(c.code) }.joinToString("")
}
