import Foundation
import Testing
@testable import Coeur

/// SessionRuleTest d'Android, porté : la séance ouverte, puis les séances et les compteurs de
/// `Tests/Vecteurs/seance.json`, écrits par la JVM (tools/vecteurs_ios/VecteursSeance.kt ; les lectures
/// de durée sont rejouées par DureeSeanceTests). Reste à Android `l ecran de seance porte le
/// bouton sans duree`, qui lit un layout ; les libellés se vérifient sur le catalogue exporté.
@Suite("Séance")
struct SessionRuleTests {

    private let minute: Int64 = 60_000
    private let debut: Int64 = 1_700_000_000_000

    @Test func uneSeanceMinuteeSArreteASonTerme() {
        let fin = debut + 20 * minute
        let justeAvant = SessionRule.enCours(debutMillis: debut, finMillis: fin, duree: 20, maintenant: fin - 1)
        #expect(justeAvant)
        let aSonTerme = SessionRule.enCours(debutMillis: debut, finMillis: fin, duree: 20, maintenant: fin)
        #expect(!aSonTerme)
        let uneMinuteApres = SessionRule.enCours(debutMillis: debut, finMillis: fin, duree: 20, maintenant: fin + minute)
        #expect(!uneMinuteApres)
    }

    /// Le cœur de l'affaire : aucune fin inscrite ne doit interrompre une séance ouverte, même des
    /// heures plus tard.
    @Test func uneSeanceOuverteNeSArretePasDElleMeme() {
        let ouverte = SessionRule.estOuverte(debutMillis: debut, duree: SessionRule.ouverte)
        #expect(ouverte)
        let secondes: [Int64] = [1, 60, 600, 86_400]
        for s in secondes {
            let court = SessionRule.enCours(debutMillis: debut, finMillis: 0, duree: SessionRule.ouverte,
                                            maintenant: debut + s * 1_000)
            #expect(court, "elle doit courir encore après \(s) s")
        }
    }

    /// Sans séance en cours, rien n'est ouvert : le début à zéro le dit.
    @Test func aucuneSeanceNEstUneSeanceOuverte() {
        let ouverte = SessionRule.estOuverte(debutMillis: 0, duree: SessionRule.ouverte)
        #expect(!ouverte)
        let court = SessionRule.enCours(debutMillis: 0, finMillis: 0, duree: SessionRule.ouverte, maintenant: debut)
        #expect(!court)
    }

    /// La durée réelle est mesurée de la même façon dans les deux cas.
    @Test func laDureeReelleEstMesureeDepuisLeDebut() {
        let presqueUne = SessionRule.minutesEcoulees(debutMillis: debut, maintenant: debut + 59_999)
        #expect(presqueUne == 0)
        let une = SessionRule.minutesEcoulees(debutMillis: debut, maintenant: debut + minute)
        #expect(une == 1)
        let quaranteSept = SessionRule.minutesEcoulees(debutMillis: debut, maintenant: debut + 47 * minute + 30_000)
        #expect(quaranteSept == 47)
        // Une horloge qui recule ne doit pas produire de durée négative.
        let recul = SessionRule.minutesEcoulees(debutMillis: debut, maintenant: debut - minute)
        #expect(recul == 0)
        let sansDebut = SessionRule.minutesEcoulees(debutMillis: 0, maintenant: debut)
        #expect(sansDebut == 0)
    }

    @Test func leResteEstArrondiAuSuperieurEtJamaisNegatif() {
        let fin = debut + 10 * minute
        let dix = SessionRule.minutesRestantes(finMillis: fin, maintenant: debut)
        #expect(dix == 10)
        let uneSeconde = SessionRule.minutesRestantes(finMillis: fin, maintenant: fin - 1_000)
        #expect(uneSeconde == 1)
        let aLaFin = SessionRule.minutesRestantes(finMillis: fin, maintenant: fin)
        #expect(aLaFin == 0)
        let apres = SessionRule.minutesRestantes(finMillis: fin, maintenant: fin + minute)
        #expect(apres == 0)
    }

    /// Les libellés que l'écran et la notification promettent (strings.xml d'Android, ici le catalogue
    /// exporté : values, values-en et values-iw sont fr, en et he).
    @Test func lesLibellesDeLaSeanceOuverteExistentDansLesTroisLangues() throws {
        let cles = ["session_open", "session_open_caption", "session_elapsed", "blocker_session_open_subtitle"]
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                let present = chaines[cle] != nil
                #expect(present, "\(langue) : « \(cle) » manquant")
            }
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let ouverte: Int
            let plafondOuverte: Int
        }
        struct LigneCompteur: Decodable {
            let ouverte: Bool
            let masque: Bool
            let compteur: String
        }
        /// Une séance inscrite et ses réponses, instant par instant. Les instants sont écrits en
        /// chaînes : ils vont jusqu'aux bornes d'un `Long`.
        struct Seance: Decodable {
            let debut: String
            let fin: String
            let duree: Int
            let estOuverte: Bool
            let maintenant: [String]
            let enCours: [Bool]
            let minutesEcoulees: [Int]
            let minutesAInscrire: [Int]
            let estEchue: [Bool]
            let minutesRestantes: [Int]
        }

        let constantes: Constantes
        let compteurs: [LigneCompteur]
        let seances: [Seance]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/seance.json"))
    }

    /// `Compteur.name` de Kotlin.
    private func nom(_ compteur: SessionRule.Compteur) -> String {
        switch compteur {
        case .reste: return "RESTE"
        case .ecoule: return "ECOULE"
        case .masque: return "MASQUE"
        }
    }

    @Test func lesConstantesEtLesCompteursDAndroid() throws {
        let v = try vecteurs()
        let ouverte = SessionRule.ouverte
        #expect(ouverte == v.constantes.ouverte)
        let plafond = SessionRule.plafondOuverte
        #expect(plafond == v.constantes.plafondOuverte)
        let combinaisons = v.compteurs.count
        #expect(combinaisons == 4)
        for c in v.compteurs {
            let compteur = nom(SessionRule.compteur(ouverte: c.ouverte, masque: c.masque))
            #expect(compteur == c.compteur, "compteur(ouverte: \(c.ouverte), masque: \(c.masque))")
        }
    }

    /// Chaque séance, à chaque instant : ouverte et minutées jusqu'au plafond et au-delà, aucune séance,
    /// des fins qui ne se tiennent pas, des instants aux bornes d'un `Long` et plus de minutes qu'un
    /// `Int` de Kotlin n'en porte.
    @Test func chaqueSeanceRepondCommeSurAndroid() throws {
        let v = try vecteurs()
        var instants = 0
        var ecarts: [String] = []
        for s in v.seances {
            let debutMillis = try #require(Int64(s.debut), "début illisible : \(s.debut)")
            let finMillis = try #require(Int64(s.fin), "fin illisible : \(s.fin)")
            let seance = "séance (\(s.debut), \(s.fin), \(s.duree))"
            let ouverte = SessionRule.estOuverte(debutMillis: debutMillis, duree: s.duree)
            #expect(ouverte == s.estOuverte, "\(seance) : estOuverte")
            let n = s.maintenant.count
            let tailles = [s.enCours.count, s.minutesEcoulees.count, s.minutesAInscrire.count, s.estEchue.count,
                           s.minutesRestantes.count]
            let completes = tailles == [n, n, n, n, n]
            #expect(completes, "\(seance) : une réponse par instant")
            guard completes else { continue }
            for (rang, ecrit) in s.maintenant.enumerated() {
                let maintenant = try #require(Int64(ecrit), "instant illisible : \(ecrit)")
                let ou = "\(seance) à \(ecrit)"
                instants += 1
                let enCours = SessionRule.enCours(debutMillis: debutMillis, finMillis: finMillis, duree: s.duree,
                                                  maintenant: maintenant)
                if enCours != s.enCours[rang] {
                    ecarts.append("\(ou) : enCours \(enCours), Android \(s.enCours[rang])")
                }
                let ecoulees = SessionRule.minutesEcoulees(debutMillis: debutMillis, maintenant: maintenant)
                if ecoulees != s.minutesEcoulees[rang] {
                    ecarts.append("\(ou) : minutesEcoulees \(ecoulees), Android \(s.minutesEcoulees[rang])")
                }
                let aInscrire = SessionRule.minutesAInscrire(debutMillis: debutMillis, finMillis: finMillis,
                                                             maintenant: maintenant)
                if aInscrire != s.minutesAInscrire[rang] {
                    ecarts.append("\(ou) : minutesAInscrire \(aInscrire), Android \(s.minutesAInscrire[rang])")
                }
                let echue = SessionRule.estEchue(debutMillis: debutMillis, finMillis: finMillis, duree: s.duree,
                                                 maintenant: maintenant)
                if echue != s.estEchue[rang] {
                    ecarts.append("\(ou) : estEchue \(echue), Android \(s.estEchue[rang])")
                }
                let restantes = SessionRule.minutesRestantes(finMillis: finMillis, maintenant: maintenant)
                if restantes != s.minutesRestantes[rang] {
                    ecarts.append("\(ou) : minutesRestantes \(restantes), Android \(s.minutesRestantes[rang])")
                }
            }
        }
        #expect(instants > 2_000, "les vecteurs doivent couvrir chaque frontière de chaque séance")
        let nombre = ecarts.count
        let premiers = ecarts.prefix(20).joined(separator: "\n")
        #expect(nombre == 0, "\(premiers)")
    }
}

/// SessionCounterTest d'Android (dans SessionRuleTest.kt), porté : le compteur masqué. Ce qui est
/// promis : rien à l'écran pendant la séance. Le piège serait de retirer le chiffre de l'écran et de le
/// laisser dans la notification en cours ou sur l'écran de barrage, où il se lit tout aussi bien.
/// Reste à Android `le reglage a son interrupteur dans les reglages`, qui lit un layout.
@Suite("Compteur de séance")
struct SessionCounterTests {

    @Test func masqueLeCompteurNeDitRienSeanceOuverteOuNon() {
        let minutee = SessionRule.compteur(ouverte: false, masque: true)
        #expect(minutee == .masque)
        let ouverte = SessionRule.compteur(ouverte: true, masque: true)
        #expect(ouverte == .masque)
    }

    @Test func sansMasquageChaqueSeanceDitCeQuElleA() {
        let minutee = SessionRule.compteur(ouverte: false, masque: false)
        #expect(minutee == .reste)
        let ouverte = SessionRule.compteur(ouverte: true, masque: false)
        #expect(ouverte == .ecoule)
    }

    /// Les trois endroits qui affichent un compteur doivent avoir un texte pour le cas masqué : sans
    /// lui, l'un d'eux retomberait sur le chiffre.
    @Test func lesTroisEndroitsOntUnLibellePourLeCompteurMasque() throws {
        let cles = [
            "session_hidden_caption", "session_running_hidden", "blocker_session_hidden_subtitle",
            "settings_hide_countdown", "settings_hide_countdown_hint",
        ]
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in cles {
                let present = chaines[cle] != nil
                #expect(present, "\(langue) : « \(cle) » manquant")
            }
        }
    }
}
