import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'aide à la concentration, qui remplace « Ne pas déranger » (NePasDeranger.kt, PORTAGE.md § 2.2.6) : les
/// étapes dans l'ordre et leurs chaînes, l'état du filtre de mode de concentration relu dans les réglages, le
/// message quand les Réglages ne s'ouvrent pas ; la clé propre à iOS du filtre (`ConcentrationFiltre`) ; et
/// l'écran de séance, dont le filtre masque le décompte. NePasDeranger.kt n'a pas de test sur Android.
///
/// Restent à Xcode et à l'iPhone : le bouton qui ouvre les Réglages, le filtre réel dans Réglages → Concentration
/// (App/ConcentrationFiltreIntention.swift) et son appel quand le mode s'active ou s'éteint.
@Suite("Modèle de l'aide à la concentration")
@MainActor
struct ConcentrationModeleTests {

    /// ios/Ressources/Chaines/ios.xcstrings, les chaînes propres à iOS, lu comme le catalogue d'Android.
    private static func catalogueIos() throws -> CatalogueBrut {
        try JSONDecoder().decode(CatalogueBrut.self, from: Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings"))
    }

    // MARK: L'écran d'aide

    @Test func lesCinqEtapesDansLOrdreDesReglages() {
        let etapes = ConcentrationModele.apercu().etapes
        #expect(etapes.count == 5)
        let numeros = etapes.map { $0.numero }
        #expect(numeros == [1, 2, 3, 4, 5])
        let textes = etapes.map { $0.numeroTexte }
        #expect(textes == ["1", "2", "3", "4", "5"])
        let cles = etapes.map { $0.texte.cle }
        #expect(cles == ["concentration_etape_ouvrir", "concentration_etape_creer", "concentration_etape_autoriser",
                         "concentration_etape_planifier", "concentration_etape_app"])
        let identifiants = Set(etapes.map { $0.id })
        #expect(identifiants.count == 5)
        for etape in etapes {
            #expect(etape.texte.arguments.isEmpty)
        }
    }

    @Test func lesTextesDeLEcran() {
        let m = ConcentrationModele.apercu()
        // Le titre est celui de la ligne des réglages qui mène ici ; l'introduction, son indication.
        #expect(m.titre == Libelle("settings_ne_pas_deranger"))
        #expect(m.introduction == Libelle("reglages_concentration_hint"))
        #expect(m.titreEtapes == Libelle("concentration_etapes_titre"))
        #expect(m.resultat == Libelle("concentration_resultat"))
        #expect(m.libelleOuvrirReglages == Libelle("concentration_ouvrir_reglages"))
        #expect(m.noteOuvrirReglages == Libelle("concentration_ouvrir_reglages_note"))
        #expect(m.titreFiltre == Libelle("concentration_filtre_carte_titre"))
        #expect(m.explicationFiltre == Libelle("concentration_filtre_carte_texte"))
        #expect(m.message == nil)
    }

    @Test func lEtatDuFiltreSuitLesReglages() {
        let libre = ConcentrationModele.apercu()
        #expect(!libre.filtreMasqueDecompte)
        #expect(libre.etatFiltre == Libelle("concentration_filtre_etat_libre"))
        let masque = ConcentrationModele.apercu(masqueDecompte: true)
        #expect(masque.filtreMasqueDecompte)
        #expect(masque.etatFiltre == Libelle("concentration_filtre_etat_masque"))
    }

    /// Le filtre qui s'active pendant que l'écran est ouvert se voit tout de suite : l'état est relu à chaque fois.
    @Test func unFiltreQuiSActiveSeVoitTouteDeSuite() async throws {
        let magasin = Magasin.enMemoire()
        let m = ConcentrationModele(magasin: magasin)
        #expect(!m.filtreMasqueDecompte)
        try await ConcentrationFiltre.ecrire(true, dans: magasin)
        #expect(m.filtreMasqueDecompte)
        #expect(m.etatFiltre == Libelle("concentration_filtre_etat_masque"))
        try await ConcentrationFiltre.ecrire(false, dans: magasin)
        #expect(!m.filtreMasqueDecompte)
    }

    @Test func desReglagesQuiNeSOuvrentPasLeDisent() {
        let m = ConcentrationModele.apercu()
        m.reglagesImpossibles()
        #expect(m.message == Libelle("settings_screen_missing"))
        m.message = nil
        #expect(m.message == nil)
    }

    // MARK: La clé du filtre

    @Test func laCleDuFiltreSePoseEtSeRetire() {
        var reglages = Reglages()
        #expect(!ConcentrationFiltre.masqueDecompte(reglages))
        ConcentrationFiltre.poser(true, dans: &reglages)
        #expect(ConcentrationFiltre.masqueDecompte(reglages))
        #expect(reglages.brut[ConcentrationFiltre.cle] == JSON.booleen(true))
        // Faux retire la clé : des réglages sans filtre restent ceux d'Android.
        ConcentrationFiltre.poser(false, dans: &reglages)
        #expect(!ConcentrationFiltre.masqueDecompte(reglages))
        #expect(reglages.brut[ConcentrationFiltre.cle] == nil)
        #expect(reglages == Reglages())
    }

    @Test func laCleDuFiltreGardeLesAutresReglages() {
        var reglages = Reglages()
        reglages.setHideCountdown(true)
        ConcentrationFiltre.poser(true, dans: &reglages)
        #expect(reglages.hideCountdown)
        ConcentrationFiltre.poser(false, dans: &reglages)
        #expect(reglages.hideCountdown)
    }

    /// Seul un booléen vrai compte ; la clé est propre à iOS, Android ne l'a pas.
    @Test func seulUnBooleenVraiMasque() {
        let cle = ConcentrationFiltre.cle
        #expect(cle.hasPrefix("ios_"))
        let faux = Reglages(brut: ObjetJSON([(cle, JSON.booleen(false))]))
        #expect(!ConcentrationFiltre.masqueDecompte(faux))
        let entier = Reglages(brut: ObjetJSON([(cle, JSON.entier(1))]))
        #expect(!ConcentrationFiltre.masqueDecompte(entier))
        let vrai = Reglages(brut: ObjetJSON([(cle, JSON.booleen(true))]))
        #expect(ConcentrationFiltre.masqueDecompte(vrai))
    }

    @Test func ecrireUnChoixInchangeNEcritRien() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        try await ConcentrationFiltre.ecrire(false, dans: magasin)
        let avant = await persistance.ecrituresReglages
        #expect(avant == 0)
        try await ConcentrationFiltre.ecrire(true, dans: magasin)
        let apres = await persistance.ecrituresReglages
        #expect(apres == 1)
        let relu = try await persistance.lire()
        #expect(ConcentrationFiltre.masqueDecompte(relu.reglages))
    }

    // MARK: L'écran de séance

    /// Le filtre masque le chiffre, la lueur et ce que dit VoiceOver ; la légende ne promet pas de son, que seul
    /// le réglage « Masquer le décompte » fait entendre.
    @Test func leFiltreMasqueLeDecompteDeLaSeance() async throws {
        var reglages = Reglages()
        ConcentrationFiltre.poser(true, dans: &reglages)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = SeanceModeleTests.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        // À l'arrêt, la durée se montre quand même.
        #expect(b.modele.decompte == .duree(Store.formatDuration(15)))
        #expect(b.modele.decompteAccessible == nil)
        try await b.modele.commencer(minutes: 10)
        #expect(b.modele.decompte == .masque)
        #expect(b.modele.texteDecompte(a: b.horloge.maintenant) == nil)
        #expect(b.modele.legende == Libelle("session_running_hidden"))
        #expect(!b.modele.souffleActif)
        #expect(b.modele.decompteAccessible == Libelle("session_running_hidden"))
    }

    /// Le mode s'éteint pendant la séance : le chiffre revient aussitôt.
    @Test func leDecompteRevientQuandLeModeSEteint() async throws {
        var reglages = Reglages()
        ConcentrationFiltre.poser(true, dans: &reglages)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = SeanceModeleTests.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        try await b.modele.commencer(minutes: 10)
        #expect(b.modele.decompte == .masque)
        try await ConcentrationFiltre.ecrire(false, dans: b.magasin)
        let fin = Store.sessionEndsAt(reglages: b.magasin.reglages)
        #expect(b.modele.decompte == .reste(fin: fin))
        #expect(b.modele.legende == Libelle("session_target", .libelle(Store.formatDuration(10))))
        #expect(b.modele.souffleActif)
        #expect(b.modele.decompteAccessible == b.seance.texteEnCours)
    }

    /// Avec le réglage « Masquer le décompte » en plus, la légende reste la sienne : le son de fin sonnera.
    @Test func avecLeReglageMasquerLeDecompteLaLegendeResteLaSienne() async throws {
        var reglages = Reglages()
        reglages.setHideCountdown(true)
        ConcentrationFiltre.poser(true, dans: &reglages)
        let jour = try SeanceOutils.jour("2026-11-16")
        let b = SeanceModeleTests.banc(DateHeure(jour, heure: 10), reglages: reglages)
        await b.modele.ouvrir()
        try await b.modele.commencer(minutes: 10)
        #expect(b.modele.decompte == .masque)
        #expect(b.modele.legende == Libelle("session_hidden_caption"))
        #expect(b.modele.decompteAccessible == Libelle("session_running_hidden"))
    }

    // MARK: Les chaînes

    /// Les clés d'Android sont au catalogue d'Android ; les chaînes neuves, dans ios.xcstrings ; toutes en
    /// français, en anglais et en hébreu, sans repli.
    @Test func chaqueCleEstAuCatalogueEnTroisLangues() throws {
        let android = try CatalogueBrut.lire()
        let ios = try Self.catalogueIos()
        let m = ConcentrationModele.apercu()
        let deAndroid = ["settings_ne_pas_deranger", "settings_screen_missing", "session_running_hidden"]
        var neuves = [m.introduction.cle, m.titreEtapes.cle, m.resultat.cle, m.libelleOuvrirReglages.cle,
                      m.noteOuvrirReglages.cle, m.titreFiltre.cle, m.explicationFiltre.cle,
                      "concentration_filtre_etat_masque", "concentration_filtre_etat_libre"]
        neuves += m.etapes.map { $0.texte.cle }
        neuves += ConcentrationFiltre.clesIntention
        #expect(neuves.count == 19)
        for cle in deAndroid {
            for langue in Traducteur.langues {
                let valeur = android.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue)")
            }
        }
        for cle in neuves {
            // Une clé neuve ne double pas une clé d'Android (la chaîne d'Android l'emporterait à la fusion).
            let chezAndroid = android.strings[cle] != nil
            #expect(!chezAndroid, "« \(cle) » existe déjà chez Android")
            for langue in Traducteur.langues {
                let valeur = ios.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue) dans ios.xcstrings")
            }
        }
    }

    /// Le texte du bouton dit honnêtement ce qu'il ouvre : la page de l'app dans les Réglages.
    @Test func laNoteDuBoutonNommeLaPageDeLApp() throws {
        let ios = try Self.catalogueIos()
        for langue in Traducteur.langues {
            let note = ios.valeur("concentration_ouvrir_reglages_note", langue: langue) ?? ""
            #expect(note.contains("MyHitbodedut"), "en \(langue)")
        }
    }
}
