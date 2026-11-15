import Foundation
import Testing
@testable import Coeur

/// SessionRuleTest d'Android (avec SessionCounterTest, du même fichier), porté : la séance ouverte, sa durée réelle,
/// le reste arrondi au supérieur, le compteur masqué. Les libellés sont cherchés dans le catalogue exporté
/// (`Localizable.xcstrings`) au lieu des strings.xml ; les deux tests qui lisent un layout d'Android
/// (`activity_session.xml`, `activity_settings.xml`) y restent : ils reviendront avec l'écran de séance.
@Suite("SessionRule")
struct SessionRuleTests {

    private let minute: Int64 = 60_000
    private let debut: Int64 = 1_700_000_000_000

    @Test func uneSeanceMinuteeSArreteASonTerme() {
        let fin = debut + 20 * minute
        #expect(SessionRule.enCours(debut: debut, fin: fin, duree: 20, maintenant: fin - 1))
        #expect(!SessionRule.enCours(debut: debut, fin: fin, duree: 20, maintenant: fin))
        #expect(!SessionRule.enCours(debut: debut, fin: fin, duree: 20, maintenant: fin + minute))
    }

    /// Le cœur de l'affaire : aucune fin inscrite ne doit interrompre une séance ouverte, même des heures plus tard.
    @Test func uneSeanceOuverteNeSArretePasDElleMeme() {
        #expect(SessionRule.estOuverte(debut: debut, duree: SessionRule.ouverte))
        for secondes: Int64 in [1, 60, 600, 86_400] {
            let court = SessionRule.enCours(debut: debut, fin: 0, duree: SessionRule.ouverte, maintenant: debut + secondes * 1_000)
            #expect(court, "elle doit courir encore après \(secondes) s")
        }
    }

    /// Sans séance en cours, rien n'est ouvert : le début à zéro le dit.
    @Test func aucuneSeanceNEstUneSeanceOuverte() {
        #expect(!SessionRule.estOuverte(debut: 0, duree: SessionRule.ouverte))
        #expect(!SessionRule.enCours(debut: 0, fin: 0, duree: SessionRule.ouverte, maintenant: debut))
    }

    /// La durée réelle est mesurée de la même façon dans les deux cas.
    @Test func laDureeReelleEstMesureeDepuisLeDebut() {
        #expect(SessionRule.minutesEcoulees(debut: debut, maintenant: debut + 59_999) == 0)
        #expect(SessionRule.minutesEcoulees(debut: debut, maintenant: debut + minute) == 1)
        #expect(SessionRule.minutesEcoulees(debut: debut, maintenant: debut + 47 * minute + 30_000) == 47)
        // Une horloge qui recule ne doit pas produire de durée négative.
        #expect(SessionRule.minutesEcoulees(debut: debut, maintenant: debut - minute) == 0)
        #expect(SessionRule.minutesEcoulees(debut: 0, maintenant: debut) == 0)
    }

    @Test func leResteEstArrondiAuSuperieurEtJamaisNegatif() {
        let fin = debut + 10 * minute
        #expect(SessionRule.minutesRestantes(fin: fin, maintenant: debut) == 10)
        #expect(SessionRule.minutesRestantes(fin: fin, maintenant: fin - 1_000) == 1)
        #expect(SessionRule.minutesRestantes(fin: fin, maintenant: fin) == 0)
        #expect(SessionRule.minutesRestantes(fin: fin, maintenant: fin + minute) == 0)
    }

    /// Les libellés que l'écran et la notification promettent.
    @Test func lesLibellesDeLaSeanceOuverteExistentDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in ["session_open", "session_open_caption", "session_elapsed", "blocker_session_open_subtitle"] {
                #expect(chaines[cle] != nil, "\(langue) : « \(cle) » manquant")
            }
        }
    }
}

/// Le compteur masqué : rien à l'écran pendant la séance, ni dans la notification, ni sur le bouclier.
@Suite("SessionCounter")
struct SessionCounterTests {

    @Test func masqueLeCompteurNeDitRienSeanceOuverteOuNon() {
        #expect(SessionRule.compteur(ouverte: false, masque: true) == .masque)
        #expect(SessionRule.compteur(ouverte: true, masque: true) == .masque)
    }

    @Test func sansMasquageChaqueSeanceDitCeQuElleA() {
        #expect(SessionRule.compteur(ouverte: false, masque: false) == .reste)
        #expect(SessionRule.compteur(ouverte: true, masque: false) == .ecoule)
    }

    /// Les trois endroits qui affichent un compteur doivent avoir un texte pour le cas masqué.
    @Test func lesTroisEndroitsOntUnLibellePourLeCompteurMasque() throws {
        let catalogue = try Catalogue.lire()
        let cles = ["session_hidden_caption", "session_running_hidden", "blocker_session_hidden_subtitle",
                    "settings_hide_countdown", "settings_hide_countdown_hint"]
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles { #expect(chaines[cle] != nil, "\(langue) : « \(cle) » manquant") }
        }
    }
}
