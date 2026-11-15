package com.myhitbodedut

import android.app.Activity
import android.app.ActivityManager
import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.PowerManager

/**
 * L'icône de lancement suit le choix צדיק / צדקת et la couleur des boutons
 * (demande du 29/10) : le visage du hassid ou de la tsadeket
 * (ic_launcher_face, ic_launcher_face_f), sur la plaque claire de la palette.
 *
 * Android ne change pas l'icône d'une application en marche : chaque
 * combinaison est une entrée du manifeste (activity-alias « Icone_m_vert »…),
 * et une seule est active. L'entrée voulue s'active avant que les autres ne
 * s'éteignent, pour qu'il y ait toujours une icône.
 *
 * Jamais écran ouvert (13/11, FACCUEIL-01). Éteindre (DISABLED) l'entrée par
 * laquelle l'application a été lancée fait retirer sa tâche par Android, même
 * avec DONT_KILL_APP : l'application se fermait seule sous le doigt, quelques
 * secondes après le choix « Tsadeket » de la présentation ou un changement de
 * couleur. Le choix est donc seulement enregistré (Store), et l'icône ne change
 * qu'au moment où l'application quitte l'écran ([installer]). Une entrée
 * éteinte retourne à DEFAULT, son état au manifeste (enabled="false"), qui ne
 * déclenche pas ce retrait ; seule l'entrée par défaut, allumée au manifeste,
 * ne s'éteint que par DISABLED. Si la tâche est retirée, c'est alors en
 * arrière-plan : on rouvre l'application par sa nouvelle icône.
 *
 * Certains lanceurs mettent quelques secondes à redessiner l'icône, ou
 * retirent le raccourci posé sur le bureau : l'application reste dans la
 * liste des applications.
 */
object IconeLanceur {

    private const val PAQUET = "com.myhitbodedut"

    /** L'entrée par défaut du manifeste (android:enabled="true"). */
    const val PAR_DEFAUT = "$PAQUET.Icone_m_vert"

    fun alias(adresse: Adresse?, accent: Apparence.Accent): String =
        "$PAQUET.Icone_${if (adresse == Adresse.FEMME) "f" else "m"}_${accent.cle}"

    fun tous(): List<String> =
        listOf(Adresse.HOMME, Adresse.FEMME).flatMap { a -> Apparence.Accent.values().map { alias(a, it) } }

    /** Une entrée est-elle active, d'après son réglage ? DEFAULT renvoie au manifeste, où seule [PAR_DEFAUT] l'est. */
    fun active(nom: String, etat: Int): Boolean = when (etat) {
        PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
        PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> nom == PAR_DEFAUT
        else -> false
    }

    /**
     * Les réglages à poser pour que [voulu] soit la seule entrée active, d'après les réglages
     * actuels [etats] : l'entrée voulue d'abord, puis celles à éteindre ; rien pour une entrée
     * déjà dans le bon état. Éteindre, c'est revenir à DEFAULT — sauf pour [PAR_DEFAUT].
     */
    fun changements(voulu: String, etats: Map<String, Int>): List<Pair<String, Int>> {
        fun reglage(nom: String): Int = when {
            nom == PAR_DEFAUT ->
                if (nom == voulu) PackageManager.COMPONENT_ENABLED_STATE_DEFAULT else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            nom == voulu -> PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else -> PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
        }
        return (listOf(voulu) + tous().filter { it != voulu })
            .filter { active(it, etats[it] ?: PackageManager.COMPONENT_ENABLED_STATE_DEFAULT) != (it == voulu) }
            .map { it to reglage(it) }
    }

    /**
     * L'application vient de quitter l'écran : est-ce le moment de changer d'icône ? Pas écran
     * éteint (on rallume sur l'application, qui ne doit pas avoir disparu), pas pendant une
     * séance, et pas tant qu'un écran d'une autre application est ouvert au-dessus de la nôtre
     * dans notre propre tâche (réglages du téléphone pour un accès, choix d'un fichier) : il se
     * fermerait avec elle. [sommets] : le paquet de l'activité du dessus de chacune de nos tâches.
     */
    fun peutBasculer(ecranAllume: Boolean, seanceEnCours: Boolean, sommets: List<String?>, paquet: String): Boolean =
        ecranAllume && !seanceEnCours && sommets.all { it == null || it == paquet }

    /** L'icône déjà posée depuis le lancement : évite de réinterroger Android à chaque sortie. */
    private var posee: String? = null

    /** Met l'icône à jour d'après les réglages ; sans effet si elle l'est déjà, ni hors d'un appareil. */
    private fun appliquer(context: Context) = runCatching {
        val voulu = alias(Store.adresse(context), Store.accent(context))
        if (voulu == posee) return@runCatching
        val pm = context.packageManager
        val etats = tous().associateWith { pm.getComponentEnabledSetting(ComponentName(context, it)) }
        val aPoser = changements(voulu, etats)
        if (aPoser.isEmpty()) {
            posee = voulu
            return@runCatching
        }
        val allume = (context.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
        val sommets = (context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).appTasks
            .map { it.taskInfo.topActivity?.packageName }
        // Sinon : à la prochaine sortie.
        if (!peutBasculer(allume, Store.isSessionRunning(context), sommets, context.packageName)) return@runCatching
        aPoser.forEach { (nom, etat) ->
            pm.setComponentEnabledSetting(ComponentName(context, nom), etat, PackageManager.DONT_KILL_APP)
        }
        posee = voulu
    }

    /**
     * À l'ouverture de l'application : l'icône se met à jour chaque fois que le dernier écran
     * visible quitte l'écran (retour au bureau, autre application), jamais avant. Une rotation
     * ou un changement de palette recréent l'écran sans le quitter : ils ne comptent pas.
     */
    fun installer(application: Application) {
        application.registerActivityLifecycleCallbacks(object : Application.ActivityLifecycleCallbacks {
            private var visibles = 0

            override fun onActivityStarted(activity: Activity) {
                visibles++
            }

            override fun onActivityStopped(activity: Activity) {
                if (visibles > 0) visibles--
                if (visibles == 0 && !activity.isChangingConfigurations) appliquer(application)
            }

            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
            override fun onActivityResumed(activity: Activity) = Unit
            override fun onActivityPaused(activity: Activity) = Unit
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
            override fun onActivityDestroyed(activity: Activity) = Unit
        })
    }
}
