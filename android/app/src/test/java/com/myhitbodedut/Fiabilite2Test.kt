package com.myhitbodedut

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Le lot fiabilité 2 (revue du 01/10). Les règles pures sont dans
 * FiabiliteTest ; ici, les branchements qui ne se voient qu'en lisant le
 * code : chaque garde doit exister à l'endroit où il protège.
 */
class Fiabilite2Test {

    private fun lire(f: String) = File("src/main/java/com/myhitbodedut/$f").readText()

    /** La séance finie n'est plus écrasée par une nouvelle dans les 5 s qui suivent. */
    @Test
    fun `une nouvelle seance clot d abord la precedente`() {
        val service = lire("SessionService.kt")
        val start = service.substringAfter("fun start(context: Context, minutes: Int)").substringBefore("}")
        assertTrue("start() doit clore la séance restée inscrite", start.contains("cloreLaPrecedente(context)"))
        assertTrue(start.indexOf("cloreLaPrecedente") < start.indexOf("Store.beginSession"))
        assertTrue("le tour du service doit viser le terme", service.contains("private fun delaiTick()"))
    }

    /** Un redémarrage du service sans séance n'inscrit plus une journée de 0 min. */
    @Test
    fun `le service relance sans seance s arrete sans rien inscrire`() {
        val service = lire("SessionService.kt")
        val debut = service.substringAfter("override fun onStartCommand").substringBefore("when (intent?.action)")
        assertTrue(debut.contains("intent == null && !Store.hasSessionRecord(this)"))
        val fin = service.substringAfter("private fun finishSession").substringBefore("val theme")
        assertTrue(fin.contains("!Store.hasSessionRecord(this)"))
    }

    @Test
    fun `une note seule effacee disparait du journal`() {
        val note = lire("Store.kt").substringAfter("fun setNote").substringBefore("writeDays")
        assertTrue(note.contains("existing?.noteSeule == true && note.isBlank() -> all.remove(date)"))
    }

    @Test
    fun `un journal illisible est mis de cote avant d etre ecrase`() {
        assertTrue(lire("Store.kt").contains("KEY_DAYS_CORROMPU"))
    }

    @Test
    fun `l import a un plafond et les notes une longueur`() {
        val reglages = lire("SettingsActivity.kt")
        // Le fichier lu jusqu'à 3 Mo (une sauvegarde chiffrée est un tiers plus grosse), le texte en clair jusqu'à 2 Mo.
        assertTrue(reglages.contains("IMPORT_MAX_OCTETS = 3 * 1024 * 1024"))
        assertTrue(reglages.contains("CLAIR_MAX_OCTETS = 2 * 1024 * 1024"))
        assertTrue(reglages.contains("octets.size > CLAIR_MAX_OCTETS"))
        assertTrue(reglages.contains("clair.toByteArray(Charsets.UTF_8).size > CLAIR_MAX_OCTETS"))
        assertTrue(reglages.contains("if (total > IMPORT_MAX_OCTETS) return@use null"))
        assertTrue(lire("NoteDialog.kt").contains("LengthFilter(Store.NOTE_MAX)"))
        assertTrue(lire("Store.kt").contains("const val NOTE_MAX = 4000"))
    }

    @Test
    fun `le rappel se tait pendant une hitbodedout`() {
        assertTrue(lire("Reminder.kt").contains("!Store.isSessionRunning(context) && ReminderRule.shouldNotify("))
    }

    @Test
    fun `le journal refuse la capture d ecran`() {
        assertTrue(lire("JournalActivity.kt").contains("FLAG_SECURE"))
    }

    /** La note d'après séance s'écrit dans le carnet du bravo : il protège comme NoteDialog (audit du 12/11). */
    @Test
    fun `le carnet du bravo refuse la capture d ecran`() {
        val carnet = lire("CelebrationActivity.kt").substringAfter("private fun carnet(").substringBefore("private fun ouvrirSuite(")
        assertTrue(carnet.contains("FLAG_SECURE"))
        // Après la garde du jour : un bravo sans page (séance annulée, sansNote) reste capturable.
        assertTrue(carnet.indexOf("dateNote ?: return") < carnet.indexOf("FLAG_SECURE"))
    }

    /** Le brouillon partagé avec NoteDialog porte l'humeur d'avant : le carnet ne la jette pas. */
    @Test
    fun `le carnet garde l humeur d avant du brouillon`() {
        val source = lire("CelebrationActivity.kt")
        assertTrue(source.contains("avant = brouillon?.avant ?: initiale.avant"))
        val saisie = source.substringAfter("private fun saisie()").substringBefore("private fun etatEnregistre")
        assertTrue(saisie.contains("avant = avant"))
    }

    /** Au retour, le carnet repart de ce qui est gardé, comme NoteDialog.onStart (FDONNEES-02). */
    @Test
    fun `le carnet repart de ce qui est garde au retour`() {
        val source = lire("CelebrationActivity.kt")
        val retour = source.substringAfter("override fun onRestart()").substringBefore("}")
        assertTrue(retour.contains("repartir()"))
        val repartir = source.substringAfter("private fun repartir()").substringBefore("override fun onRestart()")
        assertTrue(repartir.contains("initiale = JournalPlus.lire("))
        assertTrue(repartir.contains("noteInitiale = Store.record("))
        assertTrue(repartir.contains("NoteBrouillon.modifie("))
    }

    /** Le carnet qui s'ouvre de lui-même cache « Partager » : le bouton est posé avant lui. */
    @Test
    fun `partager est pose avant le carnet`() {
        val creation = lire("CelebrationActivity.kt").substringAfter("override fun onCreate(").substringBefore("override fun onSaveInstanceState(")
        assertTrue(creation.indexOf("R.id.celebration_share") in 0 until creation.indexOf("carnet(savedInstanceState)"))
    }

    /**
     * Relecture du 23/11 : journal verrouillé, la page du carnet n'est pas proposée quand le jour
     * porte déjà un écrit. Le brouillon que la page écrit à chaque frappe en est un : la question
     * n'est donc posée qu'à la première création, et l'écran recréé reprend la réponse de l'état gardé.
     */
    @Test
    fun `le bravo decide une fois de sa page de carnet`() {
        val source = lire("CelebrationActivity.kt")
        val creation = source.substringAfter("override fun onCreate(").substringBefore("setContentView(")
        assertTrue(creation.contains("if (savedInstanceState != null) savedInstanceState.getString(ETAT_DATE)"))
        assertTrue(creation.contains("VerrouJournal.actif(this) && NoteDialog.dejaEcrit(this, it)"))
        val garde = source.substringAfter("override fun onSaveInstanceState(").substringBefore("private fun carnet(")
        assertTrue(garde.contains("outState.putString(ETAT_DATE, dateNote)"))
        assertFalse(source.contains("val dateNote: String? by lazy"))
    }

    @Test
    fun `la vignette se met a jour apres minuit et apres un import`() {
        assertTrue(lire("StreakWidget.kt").contains("private fun programmerMinuit"))
        val reglages = lire("SettingsActivity.kt")
        val apresImport = reglages.substringAfter("val imported = Store.importJson(this, text)").substringBefore("Toast.makeText(\n")
        assertTrue("import : vignette non rafraîchie", apresImport.contains("StreakWidget.refresh(this)"))
    }

    @Test
    fun `israel ou diaspora est fige au premier acces`() {
        val bloc = lire("Store.kt").substringAfter("fun inIsrael(context: Context)").substringBefore("}")
        assertTrue(bloc.contains("if (!p.contains(KEY_IN_ISRAEL))"))
    }

    @Test
    fun `hors telephone fige ses dates et n emprunte pas le sujet de la prochaine seance`() {
        val accueil = lire("MainActivity.kt")
        val bloc = accueil.substringAfter("private fun declarerHorsTelephone").substringBefore("private fun hierOuvert")
        assertTrue(bloc.contains("val aujourdhui = Store.today()"))
        assertFalse(bloc.contains("Store.sessionTheme(this)"))
        assertTrue(accueil.contains("Store.addSession(this, minutes, theme = null, date = date)"))
        assertTrue(accueil.contains("(!done || hierOuvert())"))
    }

    /** TFRUX-07 (14/11) : le jour est toujours nommé, et « Aujourd'hui » reste proposé aujourd'hui fait. */
    @Test
    fun `hors telephone nomme toujours le jour`() {
        val accueil = lire("MainActivity.kt")
        val bloc = accueil.substringAfter("private fun declarerHorsTelephone").substringBefore("private fun hierOuvert")
        assertTrue(bloc.contains("if (hierOuvert) {"))
        assertFalse(bloc.contains("aujourdhuiOuvert"))
        val duree = accueil.substringAfter("private fun choisirDureeHorsTelephone").substringBefore("private fun pickDuration")
        assertTrue(duree.contains("R.string.offline_how_long_today") && duree.contains("R.string.offline_how_long_yesterday"))
        assertTrue(duree.contains("R.string.offline_added_yesterday"))
        assertTrue(duree.contains("estAujourdhui && !dejaFait"))
        listOf("values", "values-en", "values-iw").forEach {
            val xml = File("src/main/res/$it/strings.xml").readText()
            listOf("offline_how_long_today", "offline_how_long_yesterday", "offline_added_today", "offline_added_yesterday")
                .forEach { n -> assertTrue("$it $n", xml.contains("name=\"$n\"")) }
        }
    }

    @Test
    fun `le bravo survit a une rotation`() {
        val manifeste = File("src/main/AndroidManifest.xml").readText()
        val bloc = manifeste.substringAfter("android:name=\".CelebrationActivity\"").substringBefore("/>")
        assertTrue(bloc.contains("android:configChanges=\"orientation|screenSize"))
    }
}
