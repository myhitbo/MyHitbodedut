// Produit web/test/vecteurs_kosherjava.json (10/10/2026) : ce que le code
// Android (CalendrierJuif.kt, Zmanim.kt, sur KosherJava 2.5.0) répond, jour
// par jour, pour que le portage web (tefila.js, zmanim.js, sur
// kosher-zmanim) soit comparé à lui sans recopier une seule valeur à la main.
//
// À compiler avec CalendrierJuif.kt, Zmanim.kt et le jar com.kosherjava:zmanim:2.5.0,
// sur la JVM seule (README.md à côté de ce fichier).
import com.myhitbodedut.CalendrierJuif
import com.myhitbodedut.Zmanim
import java.time.LocalDate

fun main() {
    val sb = StringBuilder("{\n\"moteur\": \"${Zmanim.MOTEUR}\",\n\"jours\": {\n")
    var d = LocalDate.parse("2025-09-01")
    val fin = LocalDate.parse("2030-12-31")
    var premier = true
    while (!d.isAfter(fin)) {
        for (israel in listOf(false, true)) {
            val j = CalendrierJuif.jour(d, israel)
            if (!premier) sb.append(",\n")
            premier = false
            sb.append("\"$d${if (israel) "/il" else ""}\": {\"h\": [${j.jourHebreu}, ${j.moisHebreu}, ${j.anneeHebraique}], ")
            sb.append("\"t\": \"${j.dateHebraique}\", \"f\": [${j.fetes.joinToString { "\"$it\"" }}], \"o\": ${j.omer}, ")
            sb.append("\"p\": ${j.paracha?.let { "\"$it\"" } ?: "null"}, \"x\": ${j.chome}, ")
            sb.append("\"c\": [${CalendrierJuif.C.TOUTES.filter { it in j.conditions }.joinToString { "\"$it\"" }}]}")
        }
        d = d.plusDays(1)
    }
    sb.append("\n},\n\"zmanim\": [\n")
    val lieux = listOf(
        Zmanim.Lieu("Jérusalem", 31.76904, 35.21633, 0.0, "Asia/Jerusalem"),
        Zmanim.Lieu("Paris", 48.85341, 2.3488, 0.0, "Europe/Paris"),
        Zmanim.Lieu("New York", 40.71427, -74.00597, 0.0, "America/New_York"),
        Zmanim.Lieu("Melbourne", -37.814, 144.96332, 0.0, "Australia/Melbourne"),
        Zmanim.Lieu("Tromsø", 69.6492, 18.9553, 0.0, "Europe/Oslo"),
        // À l'est de 150° E, kosher-zmanim 0.9.0 décalait la date d'un jour (audit du 16/11).
        Zmanim.Lieu("Sydney", -33.86785, 151.20732, 0.0, "Australia/Sydney"),
        Zmanim.Lieu("Auckland", -36.84853, 174.76349, 0.0, "Pacific/Auckland"),
        Zmanim.Lieu("Wellington", -41.28664, 174.77557, 0.0, "Pacific/Auckland"),
    )
    val dates = listOf("2026-01-15", "2026-03-29", "2026-06-21", "2026-09-12", "2026-10-25", "2026-12-21", "2027-04-22")
    val lignes = mutableListOf<String>()
    for (l in lieux) for (iso in dates) {
        val date = LocalDate.parse(iso)
        val z = Zmanim.jour(l, date) + Zmanim.allumage(l, date, 18)
        // Le profil des Edot (« edot_<clé> », audit du 16/11) et les heures du 'hamets
        // (« hamets_<n>_<noussa'h> », dans l'ordre de Zmanim.hamets).
        val edot = Zmanim.jour(l, date, "edot").filter { it.cle in Zmanim.PROFIL_EDOT }.map { it.copy(cle = "edot_${it.cle}") }
        val hamets = listOf("edot", "").flatMap { n ->
            Zmanim.hamets(l, date, n).mapIndexed { i, h -> h.copy(cle = "hamets_${i}_${n.ifEmpty { "commun" }}") }
        }
        val valeurs = (z + edot + hamets).joinToString { "\"${it.cle}\": " + (it.instant?.let { i -> "\"$i\"" } ?: "\"${it.statut}\"") }
        lignes += "{\"lieu\": \"${l.nom}\", \"lat\": ${l.latitude}, \"lon\": ${l.longitude}, \"fuseau\": \"${l.fuseau}\", \"date\": \"$iso\", $valeurs}"
    }
    sb.append(lignes.joinToString(",\n")).append("\n]\n}\n")
    print(sb)
}
