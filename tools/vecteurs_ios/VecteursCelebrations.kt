// Les célébrations devant la JVM (Confettis.kt, l'objet Celebrations) : ce qui est neuf depuis la dernière
// fois, paliers et trophées. La règle est la fonction privée Celebrations.neuf, appelée ici par réflexion
// sur une pratique posée par Store (séances, notes, objectif du jour, jours du Tikoun), l'heure réglée par
// Horloge : son icône, son message, les marques des paliers et les clés des trophées à retenir. Le
// message est mis en forme par les vraies chaînes, mais TropheesVue et PaliersVue ne sont que des
// coquilles dans l'oracle (bouchons/coquilles/Ecrans.kt, qui rendent "") : il ne dit que la clé et le
// rang ; le trophée neuf et le plus haut palier neuf sont relevés par les mêmes appels que ceux de neuf,
// dont le texte est vérifié mot pour mot dans Confettis.kt. Chaque cas vérifie aussi que marquerNotifies
// (et notification, quand il n'y a rien à annoncer) écrit, dans les préférences, exactement ce que neuf rend.
//
// Les clés des libellés (TropheesVue.nom, TropheesVue.metal, PaliersVue.libelle) sont relevées dans le
// source de PaliersActivity.kt ; PaliersVue.valeur et Store.formatDuration y sont vérifiés mot pour mot.
// CelebrationsTests de Coeur rejoue tout sur Celebrations.swift.
//
// D'abord les cas qui disent la règle (premier passage, trophées d'avant les niveaux, tout vu, chaque
// piste seule, égalités de rang), puis des pratiques tirées d'une graine fixe, vues la veille, en partie,
// ou jamais.

import android.content.Context
import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.Celebrations
import com.myhitbodedut.Paliers
import com.myhitbodedut.Store
import com.myhitbodedut.Trophees
import java.io.File
import java.time.LocalDate
import java.time.ZoneId
import kotlin.random.Random

object VecteursCelebrations : Generateur {
    override val fichier = "celebrations.json"

    private val SOURCES = File(DEPOT, "android/app/src/main/java/com/myhitbodedut")

    /** Une pratique posée par Store : séances (jour, minutes), notes (jour, texte), objectif réglé, Tikoun. */
    private data class Monde(
        val aujourdhui: String,
        val seances: List<Pair<String, Int>>,
        val notes: List<Pair<String, String>> = emptyList(),
        val objectif: Int? = null,
        val tikkun: List<String> = emptyList(),
    ) {
        /** La même pratique, sans les séances d'aujourd'hui : celle qu'on a vue plus tôt dans la journée. */
        fun avantAujourdhui(): Monde = copy(seances = seances.filter { it.first != aujourdhui })
    }

    private class Neuf(val icone: String, val message: String, val marques: Set<String>, val trophees: Set<String>)

    private val methode = Celebrations::class.java
        .getDeclaredMethod("neuf", Context::class.java, Set::class.java, Set::class.java)
        .apply { isAccessible = true }

    private fun champ(o: Any, nom: String): Any? = o.javaClass.getDeclaredField(nom).apply { isAccessible = true }.get(o)

    /** Celebrations.neuf, la règle privée de Confettis.kt. */
    @Suppress("UNCHECKED_CAST")
    private fun neuf(c: Context, paliersVus: Set<String>?, tropheesVus: Set<String>?): Neuf {
        val r = methode.invoke(Celebrations, c, paliersVus, tropheesVus)!!
        return Neuf(champ(r, "icone") as String, champ(r, "message") as String,
            champ(r, "marques") as Set<String>, champ(r, "trophees") as Set<String>)
    }

    private fun theatre(m: Monde): Theatre {
        Horloge.regler(LocalDate.parse(m.aujourdhui).atTime(12, 0), ZoneId.of("UTC"))
        val t = Theatre()
        val c = t.contexte
        for ((jour, minutes) in m.seances) Store.addSession(c, minutes, null, null, jour)
        for ((jour, note) in m.notes) Store.setNote(c, jour, note)
        m.objectif?.let { Store.setDailyGoal(c, it) }
        if (m.tikkun.isNotEmpty()) t.prefs("myhitbodedut").edit().putString("tikkun_journal", m.tikkun.joinToString(",")).apply()
        check(Store.tikkunJournal(c) == m.tikkun.map { LocalDate.parse(it) }.toSet()) { "journal du Tikoun mal posé" }
        return t
    }

    /** Ce que la pratique d'un monde a déjà donné : ses marques et ses trophées, comme les retient l'app. */
    private fun vus(m: Monde): Pair<Set<String>, Set<String>> {
        val r = neuf(theatre(m).contexte, null, null)
        return r.marques to r.trophees
    }

    private fun cas(nom: String, m: Monde, paliersVus: Set<String>?, tropheesVus: Set<String>?): Map<String, Any?> {
        val c = theatre(m).contexte
        val bilan = Store.bilan(c)
        val pratique = Store.pratique(c)
        check(pratique.minutes == bilan.minutes) { "$nom : les minutes du bilan et de la pratique diffèrent" }
        val r = neuf(c, paliersVus, tropheesVus)
        // Le choix de neuf, par ses propres appels (le texte en est vérifié dans Confettis.kt).
        val etats = Paliers.etats(bilan)
        val gagnes = Trophees.gagnes(pratique)
        val trophee = Trophees.nouveaux(gagnes, tropheesVus).firstOrNull()
        val palier = paliersVus?.let { vus -> Paliers.nouveaux(etats, bilan, vus).maxByOrNull { it.rang } }
        val icone = when {
            trophee != null -> trophee.famille.icone
            palier != null -> "\uD83C\uDF89"
            else -> ""
        }
        check(r.icone == icone && r.message.isEmpty() == (trophee == null && palier == null)) { "$nom : le choix de neuf n'est pas celui relevé" }
        check(r.marques == Paliers.marques(etats, bilan) && r.trophees == gagnes.map { it.cle }.toSet()) { "$nom : état à retenir" }
        // marquerNotifies et notification retiennent, comme notifié, ce que neuf rend. notification n'est
        // appelée que s'il n'y a rien à annoncer : le Context du théâtre ne rend pas le NotificationManager
        // par son nom (Theatre.getSystemService lève), et Confettis.notifier le demande avant tout.
        val appels: List<(Context) -> Unit> = listOf({ x -> Celebrations.marquerNotifies(x) }) +
            if (r.message.isEmpty()) listOf({ x -> Celebrations.notification(x) }) else emptyList()
        for (appel in appels) {
            val c2 = theatre(m).contexte
            paliersVus?.let { Store.setPaliersNotifies(c2, it) }
            tropheesVus?.let { Store.setTropheesNotifies(c2, it) }
            appel(c2)
            check(Store.paliersNotifies(c2) == r.marques && Store.tropheesNotifies(c2) == r.trophees) { "$nom : notifiés" }
        }
        return linkedMapOf(
            "nom" to nom,
            "aujourdhui" to bilan.aujourdhui.toString(),
            // [jour, minutes], dans l'ordre des jours : les minutes du bilan, qui sont aussi celles de la pratique.
            "minutes" to bilan.minutes.entries.sortedBy { it.key }.map { listOf(it.key.toString(), it.value) },
            "serie" to bilan.serie,
            "debutMoisHebreu" to bilan.debutMoisHebreu.toString(),
            "objectifJour" to bilan.objectifJour,
            "notes" to pratique.notes,
            "meilleureSerie" to pratique.meilleureSerie,
            "tikkun" to pratique.tikkun.sorted().map { it.toString() },
            "paliersVus" to paliersVus?.sorted(),
            "tropheesVus" to tropheesVus?.sorted(),
            "icone" to r.icone,
            "message" to r.message,
            "marques" to r.marques.sorted(),
            "trophees" to r.trophees.sorted(),
            // [clé, métal] du trophée fêté ; [piste, atteint, rang] du palier fêté s'il n'y a pas de trophée.
            "trophee" to trophee?.let { listOf(it.cle, it.metal.name) },
            "palier" to if (trophee == null) palier?.let { listOf(it.piste.name, it.atteint, it.rang) } else null,
            "moisEtAnnee" to if (trophee == null && palier?.piste == Paliers.Piste.MOIS)
                CalendrierJuif.jour(bilan.aujourdhui, false).moisEtAnnee else null,
        )
    }

    // --- Les pratiques ----------------------------------------------------------------------------------

    private fun jours(fin: String, n: Int, minutes: (Int) -> Int): List<Pair<String, Int>> {
        val d = LocalDate.parse(fin)
        return (n - 1 downTo 0).map { i -> d.minusDays(i.toLong()).toString() to minutes(i) }
    }

    /** Un mois et demi de pratique jusqu'au mercredi 14 octobre 2026 (3 'Hechvan 5787) : chaque piste a des marques. */
    private val riche = Monde("2026-10-14", jours("2026-10-14", 45) { i -> listOf(45, 30, 20, 60, 15)[i % 5] },
        notes = listOf("2026-10-01" to "merci", "2026-10-02" to "une note", "2026-09-20" to "  "), objectif = 25)

    private fun fixes(): List<Map<String, Any?>> {
        val un = Monde("2026-10-14", listOf("2026-10-14" to 10))
        val (marquesUn, tropheesUn) = vus(un)
        val (marquesRiche, tropheesRiche) = vus(riche)
        val liste = mutableListOf(
            cas("premier passage", un, null, null),
            cas("paliers jamais regardés", un, null, emptySet()),
            cas("trophées jamais regardés", un, emptySet(), null),
            cas("rien de vu", un, emptySet(), emptySet()),
            cas("trophées d'avant les niveaux", un, emptySet(), setOf("premier_pas", "seance_longue")),
            cas("trophées vus, un d'avant les niveaux", un, emptySet(), setOf("premier_pas", "seance_longue:1")),
            cas("tout vu", un, marquesUn, tropheesUn),
            cas("pratique vide, rien de vu", Monde("2026-10-14", emptyList()), emptySet(), emptySet()),
            cas("pratique vide, premier passage", Monde("2026-10-14", emptyList()), null, null),
            cas("note seule", Monde("2026-10-14", emptyList(), notes = listOf("2026-10-14" to "pas pu")), emptySet(), emptySet()),
            cas("zéro minute", Monde("2026-10-14", listOf("2026-10-14" to 0)), emptySet(), emptySet()),
            cas("riche, tout vu", riche, marquesRiche, tropheesRiche),
            cas("riche, rien de vu", riche, emptySet(), emptySet()),
            cas("riche, paliers vus, trophées non", riche, marquesRiche, emptySet()),
            cas("riche, trophées vus, paliers non", riche, emptySet(), tropheesRiche),
        )
        // Chaque piste seule : ses marques retirées de celles vues, les trophées tous vus.
        for (piste in Paliers.Piste.entries) {
            val vus = marquesRiche.filterNot { it.substringBefore(':') == piste.cle }.toSet()
            liste += cas("riche, seule la piste ${piste.name}", riche, vus, tropheesRiche)
        }
        // Le plus haut palier de chaque piste retiré : toutes neuves, le plus haut rang gagne, le premier à égalité.
        val etatsRiche = Paliers.etats(Store.bilan(theatre(riche).contexte))
        val hauts = etatsRiche.filter { it.rang > 0 }.map { e ->
            marquesRiche.filter { it.substringBefore(':') == e.piste.cle && it.substringAfterLast(':') == e.atteint.toString() }
        }.flatten().toSet()
        liste += cas("riche, le haut de chaque piste", riche, marquesRiche - hauts, tropheesRiche)
        // Le plus haut niveau de chaque famille retiré : le métal, puis le rang, puis l'ordre des familles.
        val familles = tropheesRiche.groupBy { it.substringBefore(':') }.values.map { cles -> cles.maxBy { it.substringAfter(':').toInt() } }.toSet()
        liste += cas("riche, le haut de chaque famille", riche, marquesRiche, tropheesRiche - familles)
        liste += cas("riche, premier niveau de chaque famille seul vu", riche, marquesRiche,
            tropheesRiche.filter { it.endsWith(":1") }.toSet())
        // Une semaine de suite : le septième jour, vu la veille.
        val semaine = Monde("2026-10-16", jours("2026-10-16", 7) { 20 })
        val (mS, tS) = vus(semaine.avantAujourdhui())
        liste += cas("le septième jour", semaine, mS, tS)
        // Le palier du jour : l'objectif réglé à 25 min, atteint aujourd'hui.
        val objectif = Monde("2026-10-15", listOf("2026-10-14" to 60, "2026-10-15" to 25), objectif = 25)
        val (mO, tO) = vus(objectif.copy(seances = listOf("2026-10-14" to 60, "2026-10-15" to 24)))
        liste += cas("l'objectif du jour", objectif, mO, tO)
        // Un samedi : la série ne casse pas (mode chabbat par défaut), le jour de chabbat sans séance.
        val chabbat = Monde("2026-10-17", jours("2026-10-16", 6) { 15 })
        liste += cas("un samedi sans séance", chabbat, emptySet(), emptySet())
        // Le Tikoun HaKlali et les notes : la harpe et la plume.
        val tikkun = Monde("2026-12-31", listOf("2026-12-31" to 5), tikkun = (0 until 8).map { LocalDate.parse("2026-12-31").minusDays(it.toLong()).toString() },
            notes = (0 until 12).map { LocalDate.parse("2026-12-31").minusDays(it.toLong()).toString() to "note $it" })
        val (mT, tT) = vus(tikkun.copy(tikkun = tikkun.tikkun.drop(1)))
        liste += cas("Tikoun et notes", tikkun, mT, tT)
        liste += cas("Tikoun et notes, rien de vu", tikkun, emptySet(), emptySet())
        // Le mois hébreu qui change : Adar II d'une année embolismique, et Tichri.
        val adar = Monde("2027-03-10", jours("2027-03-10", 10) { 30 })
        val (mA, tA) = vus(adar.avantAujourdhui())
        liste += cas("en Adar II", adar, mA.filterNot { it.startsWith("mois:") }.toSet(), tA)
        val tichri = Monde("2026-09-14", jours("2026-09-14", 4) { 70 })
        liste += cas("en Tichri", tichri, vus(tichri).first.filterNot { it.startsWith("mois:") }.toSet(), vus(tichri).second)
        return liste
    }

    private fun tires(): List<Map<String, Any?>> {
        val r = Random(20261016)
        val debut = LocalDate.parse("2026-01-01")
        val minutes = listOf(0, 5, 10, 12, 15, 20, 25, 30, 45, 60, 61, 90, 120, 150)
        return (1..48).map { k ->
            val aujourdhui = debut.plusDays(r.nextLong(0, 730))
            val etendue = r.nextInt(1, 50)
            val densite = r.nextInt(30, 101)
            val seances = (etendue - 1 downTo 0).mapNotNull { i ->
                if (r.nextInt(100) < densite) aujourdhui.minusDays(i.toLong()).toString() to minutes[r.nextInt(minutes.size)] else null
            }
            val notes = (0 until r.nextInt(0, 6)).map { aujourdhui.minusDays(r.nextLong(0, 60)).toString() to listOf("merci", "", " ", "une note")[r.nextInt(4)] }
            val tikkun = (0 until r.nextInt(0, 5)).map { aujourdhui.minusDays(r.nextLong(0, 12)).toString() }.distinct()
            val objectif = listOf(null, 0, 10, 25, 45, 200)[r.nextInt(6)]
            val m = Monde(aujourdhui.toString(), seances, notes, objectif, tikkun)
            when (r.nextInt(6)) {
                0 -> cas("tirage $k, premier passage", m, null, null)
                1 -> cas("tirage $k, rien de vu", m, emptySet(), emptySet())
                2 -> {
                    val (mv, tv) = vus(m.avantAujourdhui())
                    cas("tirage $k, vu plus tôt", m, mv, tv)
                }
                3 -> {
                    val (mv, tv) = vus(m)
                    cas("tirage $k, en partie vu", m, mv.filter { r.nextInt(5) > 0 }.toSet(), tv.filter { r.nextInt(5) > 0 }.toSet())
                }
                4 -> {
                    val (mv, tv) = vus(m.avantAujourdhui())
                    cas("tirage $k, paliers seuls regardés", m, mv, if (r.nextBoolean()) null else tv.map { it.substringBefore(':') }.toSet())
                }
                else -> {
                    val (mv, tv) = vus(m)
                    cas("tirage $k, tout vu", m, mv, tv)
                }
            }
        }
    }

    // --- Les libellés, relevés dans le source d'Android -------------------------------------------------

    private fun bloc(texte: String, debut: String, fin: String): String {
        val i = texte.indexOf(debut)
        check(i >= 0) { "« $debut » introuvable" }
        val j = texte.indexOf(fin, i + debut.length)
        check(j > i) { "fin de « $debut » introuvable" }
        return texte.substring(i, j)
    }

    private fun paires(bloc: String, motif: String): List<List<String>> =
        Regex(motif, RegexOption.DOT_MATCHES_ALL).findAll(bloc).map { listOf(it.groupValues[1], it.groupValues[2]) }.toList()

    private fun libelles(): Map<String, Any?> {
        val ecran = File(SOURCES, "PaliersActivity.kt").readText()
        val nom = paires(bloc(ecran, "fun nom(c: Context, f: Trophees.Famille): String", "})"),
            """Trophees\.Famille\.([A-Z_]+) -> R\.string\.([a-z0-9_]+)""")
        val metal = paires(bloc(ecran, "fun metal(c: Context, m: Trophees.Metal): String", "})"),
            """Trophees\.Metal\.([A-Z_]+) -> R\.string\.([a-z0-9_]+)""")
        val libelle = bloc(ecran, "fun libelle(c: Context, piste: Paliers.Piste, bilan: Paliers.Bilan): String", "\n    }\n")
        val pistes = paires(libelle, """Paliers\.Piste\.([A-Z]+) ->.*?R\.string\.([a-z0-9_]+)""")
        check(nom.size == Trophees.Famille.entries.size && metal.size == Trophees.Metal.entries.size &&
            pistes.size == Paliers.Piste.entries.size) { "libellés : une famille, un métal ou une piste sans clé" }
        // Ce que Celebrations.swift recopie de PaliersVue, de Store.formatDuration et de neuf, mot pour mot.
        val extraits = mapOf(
            "PaliersActivity.kt" to listOf(
                "c.getString(R.string.palier_mois, \"\\u2068\" + CalendrierJuif.jour(bilan.aujourdhui, false).moisEtAnnee + \"\\u2069\")",
                "Paliers.Piste.SERIE, Paliers.Piste.JOURS -> c.resources.getQuantityString(R.plurals.palier_n_jours, v, v)",
                "else -> Store.formatDuration(c, v)",
            ),
            "Store.kt" to listOf(
                "minutes < 60 -> context.getString(R.string.duration_minutes, minutes)",
                "minutes % 60 == 0 -> context.getString(R.string.duration_hours, minutes / 60)",
                "else -> context.getString(R.string.duration_hours_minutes, minutes / 60, minutes % 60)",
            ),
            "Confettis.kt" to listOf(
                "val trophee = Trophees.nouveaux(gagnes, tropheesVus).firstOrNull()",
                "val palier = paliersVus?.let { vus -> Paliers.nouveaux(etats, bilan, vus).maxByOrNull { it.rang } }",
                "trophee != null -> trophee.famille.icone to c.getString(R.string.trophee_niveau_gagne,",
                "TropheesVue.nom(c, trophee.famille), trophee.rang, TropheesVue.metal(c, trophee.metal))",
                "palier != null -> \"\uD83C\uDF89\" to c.getString(R.string.palier_nouveau,",
                "PaliersVue.libelle(c, palier.piste, bilan), PaliersVue.valeur(c, palier.piste, palier.atteint))",
                "else -> \"\" to \"\"",
                "return Neuf(icone, message, Paliers.marques(etats, bilan), gagnes.map { it.cle }.toSet())",
                "if (r.message.isNotEmpty()) Confettis.notifier(context, context.getString(R.string.celebration_titre), r.message, r.icone)",
            ),
        )
        for ((fichier, lignes) in extraits) {
            val texte = File(SOURCES, fichier).readText()
            for (l in lignes) check(l in texte) { "$fichier ne contient plus « $l » : revoir Celebrations.swift et VecteursCelebrations.kt" }
        }
        return linkedMapOf("nom" to nom, "metal" to metal, "palier" to pistes)
    }

    override fun produire(): Map<String, Any?> = linkedMapOf(
        "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursCelebrations.kt"),
        "libelles" to libelles(),
        "cas" to fixes() + tires(),
    )
}
