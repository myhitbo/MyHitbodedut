package com.myhitbodedut

import android.app.Application

/** Au lancement, avant le premier écran : la langue de repli, les couleurs choisies ; l'icône qui va avec, elle, attend que l'application quitte l'écran (IconeLanceur). */
class MyHitbodedutApp : Application() {

    override fun onCreate() {
        super.onCreate()
        LangueApp.appliquerRepli(this)
        Apparence.installer(this)
        IconeLanceur.installer(this)
    }

    /** Les livres entiers lus se gardent en mémoire (FLECTURE-06) ; quand elle manque, on les oublie. */
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= TRIM_MEMORY_BACKGROUND || level == TRIM_MEMORY_RUNNING_LOW || level == TRIM_MEMORY_RUNNING_CRITICAL) Data.viderLivres()
    }
}
