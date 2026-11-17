package com.myhitbodedut

import android.content.Context
import org.json.JSONObject

/**
 * Le siddour (demande du 04/10, d'après la liste de l'application CalJ) :
 * les prières du jour, les bénédictions et les textes de certains moments,
 * en trois nusah au choix. Chaque siddur_<nusah>.json dit la source et la
 * licence de chaque texte (tools/siddur_construction.py).
 */
data class SiddurBloc(val texte: String, val consigne: Boolean, val fr: String? = null, val en: String? = null)

data class SiddurSection(val titre: String, val blocs: List<SiddurBloc>, val titreFr: String? = null, val titreEn: String? = null)

data class SiddurTexte(
    val id: String,
    val groupe: String,
    val titre: LocalizedText,
    val source: String,
    val sections: List<SiddurSection>,
    /** Le nusah d'où vient le texte, quand il manque à celui-ci et a été emprunté. */
    val emprunt: LocalizedText? = null,
    /** Le nombre de chapitres : celui de [sections], ou celui de l'index des livres, qui n'a pas leur texte. */
    val chapitres: Int = sections.size,
    /** Ses traductions sont automatiques, pas encore relues (clé « traduction » de livres.json ; audit du 12/11, COUV-05). */
    val traductionAuto: Boolean = false,
) {
    /**
     * Les chapitres dont au moins un paragraphe est traduit (hors consignes) : le Yalkout Yossef n'en a que
     * 92 sur 1 048 (audit du 12/11, COUV-01, TLIVRES-05) ; le lecteur le dit au lieu de passer sans prévenir à l'hébreu seul.
     */
    fun chapitresTraduits(): Int = sections.count { s -> s.blocs.any { !it.consigne && (it.fr != null || it.en != null) } }
}

data class SiddurGroupe(val cle: String, val titre: LocalizedText)

/** Les trois nusah proposés, dans l'ordre du sélecteur. */
enum class Nusah(val cle: String, val libelle: Int) {
    EDOT("edot", R.string.siddur_nusah_edot),
    SEFARD("sefard", R.string.siddur_nusah_sefard),
    ASHKENAZ("ashkenaz", R.string.siddur_nusah_ashkenaz);

    val brut: Int
        get() = when (this) {
            EDOT -> R.raw.siddur_edot
            SEFARD -> R.raw.siddur_sefard
            ASHKENAZ -> R.raw.siddur_ashkenaz
        }

    companion object {
        fun de(cle: String?): Nusah = entries.firstOrNull { it.cle == cle } ?: EDOT
    }
}

class Siddur(
    val groupes: List<SiddurGroupe>,
    val textes: List<SiddurTexte>,
    val nusah: LocalizedText = LocalizedText("", "", ""),
    val sources: List<String> = emptyList(),
) {
    fun texte(id: String): SiddurTexte? = textes.firstOrNull { it.id == id }
    fun du(groupe: String): List<SiddurTexte> = textes.filter { it.groupe == groupe }

    /**
     * Les seules mentions que les licences imposent (CC-BY, CC-BY-SA), sans
     * le nom de Sefaria (demande du 11/10) ; domaine public et CC0 n'en
     * demandent aucune.
     */
    val mentions: List<String>
        get() = mentionsObligatoires(sources)

    companion object {
        fun mentionsObligatoires(sources: List<String>): List<String> =
            sources.filter { it.contains("CC-BY") }.map { it.replace("Sefaria / ", "").replace("Sefaria, ", "") }
    }
}

object SiddurLoader {

    fun parse(json: String): Siddur {
        val racine = JSONObject(json)
        val meta = racine.optJSONObject("_meta")
        return Siddur(
            nusah = LocalizedText.parse(meta?.optJSONObject("nusah")),
            sources = Json.strings(meta?.optJSONArray("sources")),
            groupes = Json.array(racine.getJSONArray("groupes")) {
                SiddurGroupe(it.getString("cle"), LocalizedText.parse(it.getJSONObject("titre")))
            },
            textes = Json.array(racine.getJSONArray("textes")) { t ->
                SiddurTexte(
                    id = t.getString("id"),
                    groupe = t.getString("groupe"),
                    titre = LocalizedText.parse(t.getJSONObject("titre")),
                    source = t.optString("source", ""),
                    emprunt = t.optJSONObject("nusah")?.let { LocalizedText.parse(it) },
                    chapitres = t.optInt("chapitres", t.getJSONArray("sections").length()),
                    traductionAuto = t.has("traduction"),
                    sections = Json.array(t.getJSONArray("sections")) { s ->
                        SiddurSection(
                            titre = s.optString("titre", ""),
                            titreFr = s.optString("titre_fr", "").ifBlank { null },
                            titreEn = s.optString("titre_en", "").ifBlank { null },
                            blocs = Json.array(s.getJSONArray("blocs")) { b ->
                                // Une consigne a ses traductions à part, c_fr et c_en (TEFILA-02, Tefila LiChlomo).
                                if (b.has("c")) SiddurBloc(b.getString("c"), true, b.optString("c_fr", "").ifBlank { null }, b.optString("c_en", "").ifBlank { null })
                                else SiddurBloc(b.getString("t"), false, b.optString("fr", "").ifBlank { null }, b.optString("en", "").ifBlank { null })
                            },
                        )
                    },
                )
            },
        )
    }

    fun load(context: Context, nusah: Nusah): Siddur = parse(Json.readRaw(context, nusah.brut))
}

/**
 * La bande de signets en tête de la lecture (demande du 10/10) : une
 * section par signet, et celle où l'on lit d'après ce qui est à l'écran.
 * Les débuts et les bornes sont des positions croissantes, lignes de la
 * liste côté Android, pixels côté web : la même règle sert aux deux.
 */
object SignetsSiddur {

    /**
     * L'indice du signet de la section en cours. En haut de la page : la
     * dernière section commencée à la première ligne visible. Tout en bas, où
     * la page ne peut plus monter, une section courte n'atteindrait jamais
     * le haut : c'est alors la dernière commencée à l'écran qui compte.
     */
    fun courant(debuts: List<Int>, premiere: Int, derniere: Int, enBas: Boolean): Int {
        val borne = if (enBas) derniere else premiere
        return debuts.indexOfLast { it <= borne }.coerceAtLeast(0)
    }
}

/**
 * Le texte que l'heure suggère, en tête de la liste du siddour : une
 * indication d'après l'horloge, non un horaire de zmanim. Les heures sont
 * larges exprès ; la liste entière reste juste en dessous.
 */
object SiddurMoment {

    fun suggestion(heure: java.time.LocalTime): String {
        val minutes = heure.hour * 60 + heure.minute
        return when {
            minutes < 5 * 60 -> "tikoun_hatsot"
            minutes < 6 * 60 + 30 -> "birkot_hachahar"
            minutes < 12 * 60 + 30 -> "chaharit"
            minutes < 18 * 60 + 30 -> "minha"
            minutes < 22 * 60 + 30 -> "arvit"
            else -> "chema_coucher"
        }
    }

    /**
     * La Méguila d'Esther avec la prière (13/10) : sous Arvit la nuit qui ouvre
     * Pourim (le jour hébreu de demain), sous Cha'harit le jour même. Dans une
     * ville murée, le 15 Adar ; quand il tombe un Chabbat (Pourim mechoulach),
     * la Méguila se lit le vendredi 14.
     */
    fun megila(moment: String?, aujourdhui: java.time.LocalDate, israel: Boolean, mukafChoma: Boolean): Boolean {
        val jour = when (moment) {
            "chaharit" -> aujourdhui
            "arvit" -> aujourdhui.plusDays(1)
            else -> return false
        }
        val fetes = CalendrierJuif.jour(jour, israel, mukafChoma).fetes
        if ("pourim" in fetes || "pourim_jerusalem" in fetes && jour.dayOfWeek != java.time.DayOfWeek.SATURDAY) return true
        return mukafChoma && "pourim_ailleurs" in fetes && jour.dayOfWeek == java.time.DayOfWeek.FRIDAY
    }

    /**
     * Birkat haIlanot (14/10) : on la dit une fois l'an, en voyant des arbres
     * fruitiers en fleur — en Nissan dans l'hémisphère nord (Choulhan Aroukh
     * O.H. 226). [latitude] : celle du lieu des zmanim, ou null.
     * Audit du 16/11 : en Edot et en Ashkenaz, encore en Iyar pour qui n'a pas béni en Nissan, tant que
     * les arbres sont en fleur (Kitsour Yalkut Yosef 226:10, a posteriori ; Michna Beroura 226:5) ; le
     * texte le dit (note de l'application). Le Sfard s'en tient à Nissan (Kaf ha'Haïm 226:1 : après
     * Nissan, sans Chem ni Malkhout).
     */
    fun ilanot(date: java.time.LocalDate, latitude: Double?, nusah: String? = null): Boolean {
        val c = com.kosherjava.zmanim.hebrewcalendar.JewishCalendar(date)
        return if (latitude != null && latitude < 0) moisIlanotSud(c.jewishMonth)
        else c.jewishMonth == com.kosherjava.zmanim.hebrewcalendar.JewishDate.NISSAN ||
            (c.jewishMonth == com.kosherjava.zmanim.hebrewcalendar.JewishDate.IYAR && nusah in setOf("edot", "ashkenaz"))
    }

    /**
     * L'hémisphère sud (14/10) : on bénit quand les arbres y fleurissent (Har Tsvi
     * O.H. 1:118 ; Min'hat Yits'hak 10:16, cités par Yeshivat Har Etzion) ; en
     * Australie en Eloul et Tichri (Halachipedia, « Birkat HaIlanot »). Recoupé, non
     * lu dans les responsa elles-mêmes ; la floraison locale prime sur le mois.
     */
    fun moisIlanotSud(mois: Int): Boolean =
        mois == com.kosherjava.zmanim.hebrewcalendar.JewishDate.ELUL || mois == com.kosherjava.zmanim.hebrewcalendar.JewishDate.TISHREI

    /** Le hassid qui accompagne la suggestion, parmi les illustrations de l'application. */
    fun illustration(id: String): Int = when (id) {
        "tikoun_hatsot" -> R.drawable.char_praying
        "birkot_hachahar" -> R.drawable.char_welcome
        // Les tefillin et le lit (planche du 11/10).
        "chaharit" -> R.drawable.char_tefillin
        "chema_coucher" -> R.drawable.scene_sleeping
        // L'aéroport, décor gardé (demande du 11/10).
        "tefilat_haderekh" -> R.drawable.scene_airport
        "minha" -> R.drawable.char_standing_back
        "arvit" -> R.drawable.char_tehilim
        else -> R.drawable.char_thinking
    }
}
