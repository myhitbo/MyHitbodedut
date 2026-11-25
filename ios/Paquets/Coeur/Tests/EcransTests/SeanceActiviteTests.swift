import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La Live Activity de la séance (la notification permanente de SessionService.kt, PORTAGE.md § 2.2.1) : ce
/// qu'elle montre dans ses trois états (reste, écoulé, masqué), le filtre de concentration qui masque aussi, et ses
/// chaînes. Les critères de la tâche 17 de la feuille de route qui se décident par des valeurs.
///
/// Restent à Xcode et à l'iPhone : le dessin (Widgets/ActiviteSeance.swift), le décompte qui tourne seul
/// (`Text(timerInterval:)`), le bouton « Terminer » (`ActiviteSeanceTerminer`, App Intents) et ActivityKit lui-même
/// (App/Services/SystemeActiviteEnDirect.swift).
@Suite("La Live Activity de la séance")
struct SeanceActiviteTests {

    /// Le 14/11/2023 vers 22 h UTC, en millisecondes Unix.
    private static let debut: Int64 = 1_700_000_000_000
    private static let minute: Int64 = 60_000

    /// Des réglages où une séance de `minutes` a commencé à `debut` (0 : sans durée).
    private static func seance(minutes: Int, masquer: Bool = false, concentration: Bool = false) -> Reglages {
        var reglages = Reglages()
        reglages.setHideCountdown(masquer)
        ConcentrationFiltre.poser(concentration, dans: &reglages)
        Store.beginSession(reglages: &reglages, minutes: minutes, millis: debut)
        return reglages
    }

    /// La fin que `SeanceEnCours` passe pour une séance sans durée : le plafond de 240 minutes.
    private static var plafond: Int64 {
        debut + Int64(SessionRule.plafondOuverte) * minute
    }

    // MARK: Sans séance

    @Test func sansSeanceRienNEstMontre() {
        let etat = SeanceActivite.pour(reglages: Reglages(), debut: Self.debut, fin: Self.debut + 20 * Self.minute)
        #expect(etat == nil)
    }

    /// Une séance close (Store.endSession) n'a plus rien à montrer, même si la Live Activity l'attend encore.
    @Test func uneSeanceCloseNeSeMontrePlus() {
        var reglages = Self.seance(minutes: 20)
        Store.endSession(reglages: &reglages, millis: Self.debut + 5 * Self.minute, fuseau: .utc)
        let etat = SeanceActivite.pour(reglages: reglages, debut: Self.debut, fin: Self.debut + 20 * Self.minute)
        #expect(etat == nil)
    }

    // MARK: Les trois états

    /// Une séance minutée : le temps restant, jusqu'à la fin prévue ; la légende de l'écran de séance.
    @Test func uneSeanceMinuteeMontreLeReste() throws {
        let fin = Self.debut + 20 * Self.minute
        let etat = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: 20), debut: Self.debut, fin: fin))
        #expect(etat.decompte == .reste)
        #expect(etat.montre == .reste)
        #expect(!etat.concentration)
        #expect(etat.debut == Self.debut)
        #expect(etat.fin == fin)
        #expect(etat.legende == Libelle("session_target", .libelle(Libelle("duration_minutes", .entier(20)))))
        #expect(etat.legendeMontree == etat.legende)
    }

    /// Une séance sans durée : le temps passé, jusqu'au plafond où elle sera close.
    @Test func uneSeanceSansDureeMontreLEcoule() throws {
        let etat = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: SessionRule.ouverte),
                                                    debut: Self.debut, fin: Self.plafond))
        #expect(etat.decompte == .ecoule)
        #expect(etat.montre == .ecoule)
        #expect(etat.fin == Self.plafond)
        #expect(etat.legende == Libelle("session_open_caption"))
        #expect(etat.legendeMontree == Libelle("session_open_caption"))
    }

    /// « Masquer le décompte » : rien, et la promesse du son de fin (session_hidden_caption), minutée ou non.
    @Test func leDecompteMasqueNeMontreRien() throws {
        let minutee = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: 30, masquer: true),
                                                       debut: Self.debut, fin: Self.debut + 30 * Self.minute))
        #expect(minutee.decompte == .masque)
        #expect(minutee.montre == .masque)
        #expect(minutee.legendeMontree == Libelle("session_hidden_caption"))
        let ouverte = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: SessionRule.ouverte, masquer: true),
                                                       debut: Self.debut, fin: Self.plafond))
        #expect(ouverte.decompte == .masque)
        #expect(ouverte.legendeMontree == Libelle("session_hidden_caption"))
    }

    /// L'état suit le compteur de `SeanceEnCours` (le texte de la notification d'Android) dans les trois cas.
    @Test func lEtatSuitLeCompteurDeLaSeance() throws {
        let cas: [(Reglages, SessionRule.Compteur, SeanceActivite.Decompte)] = [
            (Self.seance(minutes: 20), .reste, .reste),
            (Self.seance(minutes: SessionRule.ouverte), .ecoule, .ecoule),
            (Self.seance(minutes: 20, masquer: true), .masque, .masque),
        ]
        for (reglages, compteur, decompte) in cas {
            #expect(Store.sessionCounter(reglages: reglages) == compteur)
            let etat = try #require(SeanceActivite.pour(reglages: reglages, debut: Self.debut, fin: Self.plafond))
            #expect(etat.decompte == decompte)
        }
    }

    // MARK: Le filtre de concentration

    /// Le filtre masque le décompte d'une séance minutée, sans promettre de son.
    @Test func leFiltreMasqueLeReste() throws {
        let etat = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: 20, concentration: true),
                                                    debut: Self.debut, fin: Self.debut + 20 * Self.minute))
        #expect(etat.concentration)
        #expect(etat.decompte == .reste)
        #expect(etat.montre == .masque)
        #expect(etat.legendeMontree == Libelle("session_running_hidden"))
        #expect(etat.legendeMontree == SeanceActivite.legendeConcentration)
    }

    @Test func leFiltreMasqueLEcoule() throws {
        let etat = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: SessionRule.ouverte,
                                                                          concentration: true),
                                                    debut: Self.debut, fin: Self.plafond))
        #expect(etat.montre == .masque)
        #expect(etat.legendeMontree == Libelle("session_running_hidden"))
    }

    /// Le filtre et « Masquer le décompte » ensemble : le son de fin reste promis, puisque le réglage le fait entendre.
    @Test func leFiltreSurUnDecompteDejaMasqueGardeLaPromesseDuSon() throws {
        let etat = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: 20, masquer: true,
                                                                          concentration: true),
                                                    debut: Self.debut, fin: Self.debut + 20 * Self.minute))
        #expect(etat.montre == .masque)
        #expect(etat.legendeMontree == Libelle("session_hidden_caption"))
    }

    /// Le filtre qui s'éteint rend le décompte : l'état change, et l'app le renvoie à la Live Activity.
    @Test func leFiltreQuiSEteintRendLeDecompte() throws {
        var reglages = Self.seance(minutes: 20, concentration: true)
        let fin = Self.debut + 20 * Self.minute
        let avant = try #require(SeanceActivite.pour(reglages: reglages, debut: Self.debut, fin: fin))
        ConcentrationFiltre.poser(false, dans: &reglages)
        let apres = try #require(SeanceActivite.pour(reglages: reglages, debut: Self.debut, fin: fin))
        #expect(avant != apres)
        #expect(apres.montre == .reste)
        #expect(apres.legendeMontree == apres.legende)
    }

    /// Un réglage sans rapport ne change pas l'état : l'app ne renvoie rien.
    @Test func unReglageSansRapportNeChangeRien() throws {
        var reglages = Self.seance(minutes: 20)
        let fin = Self.debut + 20 * Self.minute
        let avant = try #require(SeanceActivite.pour(reglages: reglages, debut: Self.debut, fin: fin))
        reglages.setTargetMinutes(45)
        let apres = try #require(SeanceActivite.pour(reglages: reglages, debut: Self.debut, fin: fin))
        #expect(avant == apres)
    }

    // MARK: Les bornes

    /// Une fin avant le début (des réglages abîmés) est ramenée au début : l'intervalle du décompte n'est jamais
    /// vide à l'envers, ce que `Text(timerInterval:)` ne supporterait pas.
    @Test func laFinNePrecedeJamaisLeDebut() throws {
        let etat = try #require(SeanceActivite.pour(reglages: Self.seance(minutes: 20), debut: Self.debut,
                                                    fin: Self.debut - Self.minute))
        #expect(etat.fin == Self.debut)
    }

    // MARK: Les chaînes

    /// Les clés d'Android sont au catalogue d'Android ; les chaînes neuves (le texte d'une fin passée, le titre de
    /// l'intention « Terminer »), dans ios.xcstrings ; toutes en français, en anglais et en hébreu.
    @Test func chaqueCleEstAuCatalogueEnTroisLangues() throws {
        let android = try CatalogueBrut.lire()
        let ios = try JSONDecoder().decode(CatalogueBrut.self,
                                           from: Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings"))
        let deAndroid = [SeanceActivite.titre.cle, SeanceActivite.terminer.cle, SeanceActivite.legendeConcentration.cle,
                         "session_hidden_caption", "session_open_caption", "session_target", "duration_minutes"]
        let neuves = [SeanceActivite.echue.cle, "ios_seance_terminer_intention"]
        for cle in deAndroid {
            for langue in Traducteur.langues {
                let valeur = android.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue)")
            }
        }
        for cle in neuves {
            let chezAndroid = android.strings[cle] != nil
            #expect(!chezAndroid, "« \(cle) » existe déjà chez Android")
            for langue in Traducteur.langues {
                let valeur = ios.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue) dans ios.xcstrings")
            }
        }
    }
}
