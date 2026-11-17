package com.myhitbodedut

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

/**
 * La demande des notifications, la même pour la présentation, Rappels, Réglages et le départ
 * d'une séance (13/11, FACCUEIL-05). Chaque écran avait la sienne : celle des Rappels relançait
 * sans fin une question qu'Android ne pose plus après deux refus, et le toucher restait mort.
 *
 * Ici la question est posée, puis sa réponse est lue : un refus revenu sans qu'Android ait rien
 * montré (PermissionRules.refusSansQuestion) ouvre l'écran système des notifications de
 * l'application. Le premier toucher après un refus définitif n'est donc jamais perdu, et il n'y a
 * pas de drapeau à tenir d'un écran à l'autre.
 *
 * À créer avec l'écran, dans un champ de l'activité : Android n'accepte l'inscription d'un retour
 * de demande qu'avant le démarrage de l'écran. [apres] : l'écran se redessine, quelle que soit la réponse.
 */
class DemandeNotifications(private val ecran: ComponentActivity, private val apres: () -> Unit) {

    /** La question est à l'écran : il n'y a pas encore de refus à signaler. */
    var enCours = false
        private set

    /** Android proposait-il encore d'expliquer la demande, juste avant qu'on la lance ? */
    private var expliquaitAvant = false

    private val demande = ecran.registerForActivityResult(ActivityResultContracts.RequestPermission()) { accordee ->
        enCours = false
        if (PermissionRules.refusSansQuestion(accordee, expliquaitAvant, explique())) ouvrirReglages()
        apres()
    }

    private fun explique(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        ecran.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)

    private fun ouvrirReglages() {
        runCatching { ecran.startActivity(Permissions.notificationSettingsIntent(ecran)) }
    }

    /** Demande les notifications ; sans effet si elles s'affichent déjà. */
    fun lancer() {
        if (Permissions.hasNotifications(ecran)) return
        // Coupées dans les réglages du téléphone (avant Android 13, ou permission pourtant accordée) :
        // il n'y a rien à demander, seulement l'écran système à ouvrir (04/11).
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(ecran, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            ouvrirReglages()
            return
        }
        expliquaitAvant = explique()
        enCours = true
        demande.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}
