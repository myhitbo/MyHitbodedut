// Un Context de théâtre : ce qu'il faut d'Android pour que les règles de l'app tournent sur la
// JVM seule. Les préférences vivent en mémoire ; les ressources sont les vraies (res/raw,
// strings.xml), lues en place dans la langue demandée. Tout le reste d'Android répond par défaut
// (android.jar rendu docile par build.gradle.kts).

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.content.res.Configuration
import android.content.res.Resources
import android.os.LocaleList
import android.util.DisplayMetrics
import java.io.File
import java.io.InputStream
import java.util.Locale

/** La racine du dépôt, donnée par Gradle (-Ddepot=…). */
val DEPOT: File = File(System.getProperty("depot") ?: error("propriété « depot » absente : lancer par Gradle"))
val RES: File = File(DEPOT, "android/app/src/main/res")

/** Les identifiants de la classe R engendrée : (type, nom) ↔ identifiant. */
object Identifiants {
    private val lignes: List<Triple<String, String, Int>> =
        (Identifiants::class.java.getResourceAsStream("/r_noms.tsv") ?: error("r_noms.tsv absent"))
            .bufferedReader().readLines().filter { it.isNotBlank() }
            .map { it.split('\t') }.map { Triple(it[0], it[1], it[2].toInt()) }
    private val parId = lignes.associate { it.third to (it.first to it.second) }
    private val parNom = lignes.associate { (it.first to it.second) to it.third }

    /** « string/blocker_title » ; l'identifiant en chiffres s'il est inconnu. */
    fun nom(id: Int): String = parId[id]?.let { "${it.first}/${it.second}" } ?: id.toString()
    fun type(id: Int): String? = parId[id]?.first
    fun entree(id: Int): String = parId[id]?.second ?: error("ressource inconnue : $id")
    fun id(type: String, nom: String): Int = parNom[type to nom] ?: 0
}

/** Un monde d'essai : préférences en mémoire, ressources de l'app dans [langue] (« fr », « en », « he »). */
class Theatre(val langue: String = "fr") {
    private val prefs = LinkedHashMap<String, PrefsMemoire>()
    private val chaines = Chaines.de(langue)
    // L'arabe de l'app est celui de Tunisie (values-ar-rTN), aux chiffres latins.
    private val locale: Locale = Locale.forLanguageTag(if (langue == "ar") "ar-TN" else langue)

    fun prefs(nom: String): PrefsMemoire = prefs.getOrPut(nom) { PrefsMemoire() }

    /** Tous les fichiers de préférences, pour constater ce que le code a écrit. */
    val toutesLesPrefs: Map<String, PrefsMemoire> get() = prefs

    val ressources: Resources = object : Resources(null, null, null) {
        override fun getString(id: Int): String = chaine(id, emptyList())
        override fun getString(id: Int, vararg formatArgs: Any?): String = chaine(id, formatArgs.toList())
        override fun getText(id: Int): CharSequence = chaine(id, emptyList())
        override fun getQuantityString(id: Int, quantity: Int): String = pluriel(id, quantity, emptyList())
        override fun getQuantityString(id: Int, quantity: Int, vararg formatArgs: Any?): String =
            pluriel(id, quantity, formatArgs.toList())
        override fun getStringArray(id: Int): Array<String> =
            chaines.tableaux[Identifiants.entree(id)]?.toTypedArray() ?: error("tableau absent : ${Identifiants.nom(id)}")
        override fun openRawResource(id: Int): InputStream = brut(id)
        override fun getIdentifier(name: String?, defType: String?, defPackage: String?): Int =
            Identifiants.id(defType.orEmpty(), name.orEmpty())
        override fun getResourceEntryName(resid: Int): String = Identifiants.entree(resid)
        override fun getDisplayMetrics(): DisplayMetrics = DisplayMetrics().apply { density = 1f; scaledDensity = 1f }
        override fun getConfiguration(): Configuration = configuration
    }

    private val configuration: Configuration = object : Configuration() {
        override fun getLocales(): LocaleList = object : LocaleList() {
            override fun get(index: Int): Locale = locale
            override fun size(): Int = 1
            override fun isEmpty(): Boolean = false
            override fun toLanguageTags(): String = locale.toLanguageTag()
        }
    }.apply { @Suppress("DEPRECATION") this.locale = this@Theatre.locale }

    val contexte: Context = object : ContextWrapper(null) {
        override fun getSharedPreferences(name: String?, mode: Int): SharedPreferences = prefs(name!!)
        override fun getApplicationContext(): Context = this
        override fun getBaseContext(): Context = this
        override fun getResources(): Resources = ressources
        override fun getPackageName(): String = "com.myhitbodedut"
        override fun getString(resId: Int): String = chaine(resId, emptyList())
        override fun getString(resId: Int, vararg formatArgs: Any?): String = chaine(resId, formatArgs.toList())
        override fun getText(resId: Int): CharSequence = chaine(resId, emptyList())
        // Un service du système : une coquille docile de sa classe, dont chaque méthode rend zéro, faux ou null.
        override fun getSystemService(name: String): Any? = services[name]?.let(::coquille)
        override fun <T : Any?> getSystemService(serviceClass: Class<T>): T = coquille(serviceClass)
        override fun getSystemServiceName(serviceClass: Class<*>): String? =
            services.entries.firstOrNull { it.value == serviceClass }?.key
    }

    /** `Context.getString(id, args…)` : la chaîne de la langue, mise en forme comme le fait Android. */
    fun chaine(id: Int, arguments: List<Any?>): String {
        val nom = Identifiants.entree(id)
        val brute = chaines.simples[nom] ?: error("chaîne absente : $nom")
        return if (arguments.isEmpty()) brute else String.format(locale, brute, *arguments.toTypedArray())
    }

    private fun pluriel(id: Int, quantite: Int, arguments: List<Any?>): String {
        val nom = Identifiants.entree(id)
        val formes = chaines.pluriels[nom] ?: error("pluriel absent : $nom")
        // Les règles de CLDR pour les langues de l'app, sur des entiers.
        val forme = when (langue) {
            "fr" -> if (quantite == 0 || quantite == 1) "one" else "other"
            "he" -> when (quantite) { 1 -> "one"; 2 -> "two"; else -> "other" }
            "es" -> if (quantite == 1) "one" else if (quantite != 0 && quantite % 1_000_000 == 0) "many" else "other"
            "ar" -> when {
                quantite == 0 -> "zero"
                quantite == 1 -> "one"
                quantite == 2 -> "two"
                Math.floorMod(quantite, 100) in 3..10 -> "few"
                Math.floorMod(quantite, 100) in 11..99 -> "many"
                else -> "other"
            }
            else -> if (quantite == 1) "one" else "other"
        }
        val brute = formes[forme] ?: formes["other"] ?: error("pluriel sans forme « other » : $nom")
        return if (arguments.isEmpty()) brute else String.format(locale, brute, *arguments.toTypedArray())
    }

    private fun brut(id: Int): InputStream {
        val nom = Identifiants.entree(id)
        val fichier = File(RES, "raw").listFiles()!!.firstOrNull { it.nameWithoutExtension == nom }
            ?: error("res/raw/$nom absent")
        return fichier.inputStream()
    }

    private companion object {
        val services: Map<String, Class<*>> = mapOf(
            Context.NOTIFICATION_SERVICE to android.app.NotificationManager::class.java,
            Context.ALARM_SERVICE to android.app.AlarmManager::class.java,
            Context.POWER_SERVICE to android.os.PowerManager::class.java,
            Context.APP_OPS_SERVICE to android.app.AppOpsManager::class.java,
            Context.AUDIO_SERVICE to android.media.AudioManager::class.java,
        )

        private val allocateur = sun.misc.Unsafe::class.java.getDeclaredField("theUnsafe").apply { isAccessible = true }.get(null) as sun.misc.Unsafe

        /** Une instance sans passer par un constructeur (ceux des services d'Android sont cachés). */
        @Suppress("UNCHECKED_CAST")
        fun <T> coquille(classe: Class<T>): T = allocateur.allocateInstance(classe) as T
    }
}

/** `SharedPreferences` en mémoire, avec les règles d'Android : absent → défaut, mauvais type → exception. */
class PrefsMemoire : SharedPreferences {
    val valeurs = LinkedHashMap<String, Any>()

    override fun getAll(): MutableMap<String, *> = LinkedHashMap(valeurs)
    override fun getString(key: String?, defValue: String?): String? = (valeurs[key] ?: defValue) as String?
    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String?, defValues: Set<String>?): Set<String>? =
        (valeurs[key] ?: defValues) as Set<String>?
    override fun getInt(key: String?, defValue: Int): Int = (valeurs[key] ?: defValue) as Int
    override fun getLong(key: String?, defValue: Long): Long = (valeurs[key] ?: defValue) as Long
    override fun getFloat(key: String?, defValue: Float): Float = (valeurs[key] ?: defValue) as Float
    override fun getBoolean(key: String?, defValue: Boolean): Boolean = (valeurs[key] ?: defValue) as Boolean
    override fun contains(key: String?): Boolean = valeurs.containsKey(key)
    override fun edit(): SharedPreferences.Editor = Edition()
    override fun registerOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}
    override fun unregisterOnSharedPreferenceChangeListener(listener: SharedPreferences.OnSharedPreferenceChangeListener?) {}

    private inner class Edition : SharedPreferences.Editor {
        private val ecrits = LinkedHashMap<String, Any?>()
        private var vider = false

        private fun pose(key: String?, valeur: Any?): SharedPreferences.Editor { ecrits[key!!] = valeur; return this }
        override fun putString(key: String?, value: String?) = pose(key, value)
        override fun putStringSet(key: String?, values: Set<String>?) = pose(key, values?.let { LinkedHashSet(it) })
        override fun putInt(key: String?, value: Int) = pose(key, value)
        override fun putLong(key: String?, value: Long) = pose(key, value)
        override fun putFloat(key: String?, value: Float) = pose(key, value)
        override fun putBoolean(key: String?, value: Boolean) = pose(key, value)
        override fun remove(key: String?) = pose(key, null)
        override fun clear(): SharedPreferences.Editor { vider = true; return this }
        override fun commit(): Boolean { apply(); return true }
        override fun apply() {
            // Comme Android : « clear » d'abord, quel que soit l'ordre des appels ; une valeur null retire la clé.
            if (vider) valeurs.clear()
            for ((cle, valeur) in ecrits) if (valeur == null) valeurs.remove(cle) else valeurs[cle] = valeur
            ecrits.clear()
            vider = false
        }
    }
}
