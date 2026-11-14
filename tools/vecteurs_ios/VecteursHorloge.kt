// L'horloge figée de l'oracle (bouchons/Horloge.kt) : le code d'Android lit bien l'heure réglée, pas celle
// de la machine. Une preuve de la réécriture, gardée par la CI comme les autres vecteurs.

import com.myhitbodedut.Store
import com.myhitbodedut.SessionRule
import java.time.LocalDateTime
import java.time.ZoneId

object VecteursHorloge : Generateur {
    override val fichier = "horloge.json"

    override fun produire(): Map<String, Any?> {
        val instants = listOf(
            LocalDateTime.of(2026, 3, 29, 1, 30) to "Europe/Paris",
            LocalDateTime.of(2026, 11, 14, 23, 59) to "Asia/Jerusalem",
            LocalDateTime.of(2024, 2, 29, 12, 0) to "America/New_York",
        )
        return linkedMapOf(
            "_meta" to mapOf("source" to "tools/vecteurs_ios/VecteursHorloge.kt"),
            "defaut" to linkedMapOf("today" to Store.today(), "jourTikkun" to Store.jourTikkun()),
            "regles" to instants.map { (civile, zone) ->
                Horloge.regler(civile, ZoneId.of(zone))
                linkedMapOf("civile" to civile.toString(), "fuseau" to zone,
                    "today" to Store.today(), "jourTikkun" to Store.jourTikkun(),
                    "millis" to Horloge.millis())
            },
        )
    }
}
