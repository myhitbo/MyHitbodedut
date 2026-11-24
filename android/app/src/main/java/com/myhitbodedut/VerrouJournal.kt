package com.myhitbodedut

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts

/**
 * Le verrou du journal (audit du 12/11, revue du 15/11).
 *
 * Le journal ne s'ouvre qu'avec le code ou l'empreinte du téléphone. Pour
 * que ce verrou serve à quelque chose, tout ce qui montre ou emporte le
 * texte du journal passe par ici : l'écran du journal, la fenêtre de note
 * déjà remplie, l'export, et la désactivation du verrou lui-même. Sans
 * verrouillage d'écran sur le téléphone, il n'y a rien à demander.
 */
object VerrouJournal {

    /** Le verrou est demandé, et le téléphone a un code, un schéma ou une empreinte pour le tenir. */
    fun actif(context: Context): Boolean = Store.journalVerrou(context) && ecranProtege(context)

    fun ecranProtege(context: Context): Boolean =
        context.getSystemService(KeyguardManager::class.java)?.isDeviceSecure == true

    /** La demande système du code ou de l'empreinte, ou null si le téléphone n'en a pas. */
    fun demande(activity: Activity): Intent? {
        @Suppress("DEPRECATION")
        return activity.getSystemService(KeyguardManager::class.java)
            ?.createConfirmDeviceCredentialIntent(activity.getString(R.string.journal_verrou_titre), null)
    }

    /**
     * [onOk] tout de suite si le verrou n'est pas actif, sinon après le code
     * ou l'empreinte ; [onRefus] si l'on renonce. La demande n'est pas
     * gardée à travers une rotation : il suffit alors de toucher à nouveau.
     */
    fun exiger(activity: ComponentActivity, onOk: () -> Unit, onRefus: () -> Unit = {}) {
        if (!actif(activity)) { onOk(); return }
        val intention = demande(activity) ?: run { onOk(); return }
        lateinit var lanceur: ActivityResultLauncher<Intent>
        // Une clé neuve à chaque demande (relecture du 23/11). Un compteur repartait de zéro avec le
        // processus : l'écran restauré retrouvait la clé « 0 » et le résultat d'une demande restée
        // sans réponse, que register() rendait aussitôt — avant que « lanceur » ne soit posé
        // (UninitializedPropertyAccessException), et à la place du code qu'on venait de demander.
        lanceur = activity.activityResultRegistry.register(
            "verrou_journal_${java.util.UUID.randomUUID()}",
            ActivityResultContracts.StartActivityForResult()
        ) { resultat ->
            lanceur.unregister()
            if (resultat.resultCode == Activity.RESULT_OK) onOk() else onRefus()
        }
        lanceur.launch(intention)
    }
}
