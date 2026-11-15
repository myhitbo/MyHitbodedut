import Foundation
import Testing
@testable import Coeur

/// L'accueil du premier lancement (OnboardingTest.kt), les libellés vérifiés sur le catalogue exporté
/// (Localizable.xcstrings, d'après les strings.xml d'Android), et `Tests/Vecteurs/interface_a.json` rejoué.
/// Restent à Android : les manifestes et le seul code qui ouvre une connexion (de « l'application ne demande
/// aucun accès réseau », seule la phrase du catalogue se vérifie ici), la déclaration de l'écran et son
/// ouverture au premier lancement (manifeste, MainActivity), la version comparée par MainActivity et Store,
/// le choix de l'adresse hors de la présentation (CelebrationActivity) et le gabarit de l'écran
/// (activity_onboarding.xml).
@Suite("Onboarding")
struct OnboardingTests {

    private struct Vecteurs: Decodable {
        struct Resume: Decodable {
            let version: Int
            let durees: [Int]
            let dernier: Int
        }
        struct Ecran: Decodable {
            let cle: String
            let titre: String
            let corps: String
            let illustration: String
            let choixAdresse: Bool
            let choixDuree: Bool
            let choixRappel: Bool
        }
        struct Pas: Decodable {
            let index: Int
            let ecran: String
            let suivant: Int
            let precedent: Int
            let estPremier: Bool
            let estDernier: Bool
        }

        let onboarding: Resume
        let onboardingEcrans: [Ecran]
        let onboardingParcours: [Pas]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_a.json"))
    }

    @Test func lesEcransSontDistinctsEtComplets() {
        let ecrans = Onboarding.ecrans
        let n = ecrans.count
        let cles = Set(ecrans.map { $0.cle }).count
        let titres = Set(ecrans.map { $0.titre }).count
        let corps = Set(ecrans.map { $0.corps }).count
        let illustrations = Set(ecrans.map { $0.illustration }).count
        #expect(n == 7)
        #expect(cles == n)
        #expect(titres == n)
        #expect(corps == n)
        #expect(illustrations == n)
    }

    @Test func leParcoursResteDansSesBornes() {
        let dernier = Onboarding.dernier
        let apresPremier = Onboarding.suivant(0)
        let apresDernier = Onboarding.suivant(dernier)
        let apresLoin = Onboarding.suivant(50)
        let avantPremier = Onboarding.precedent(0)
        let avantNegatif = Onboarding.precedent(-3)
        let premier = Onboarding.estPremier(0)
        let estDernier = Onboarding.estDernier(dernier)
        let avantDernier = Onboarding.estDernier(dernier - 1)
        let ecranNegatif: OnboardingEcran? = Onboarding.ecran(-1)
        let ecranLoin: OnboardingEcran? = Onboarding.ecran(9)
        let premierEcran = Onboarding.ecrans.first
        let dernierEcran = Onboarding.ecrans.last
        #expect(apresPremier == 1)
        #expect(apresDernier == dernier)
        #expect(apresLoin == dernier)
        #expect(avantPremier == 0)
        #expect(avantNegatif == 0)
        #expect(premier)
        #expect(estDernier)
        #expect(!avantDernier)
        #expect(ecranNegatif == premierEcran)
        #expect(ecranLoin == dernierEcran)
    }

    /// Le dernier écran affirme ce qui sort du téléphone. Ce que déclarent les manifestes, et le seul code qui
    /// ouvre une connexion, restent à Android ; la phrase, elle, est celle du catalogue d'iOS (l'édition
    /// complète, values/strings.xml) : elle doit dire quand l'application se connecte, et vers où.
    @Test func lApplicationNeDemandeAucunAccesReseau() throws {
        let fr = try Catalogue.lire().simples("fr")
        let phrase = try #require(fr["onboarding_private_body"])
        let ditQuand = phrase.contient("suivi d\u{2019}un vol en direct")
        let ditOu = phrase.contient("adsbdb.com")
        #expect(ditQuand, "l'accueil doit dire quand l'application se connecte")
        #expect(ditOu, "l'accueil doit dire que le numéro de vol part vers adsbdb")
    }

    /// La présentation revient une fois à chaque nouvelle version d'elle-même, installation existante
    /// comprise : le choix צדיק / צדקת ne se pose que là. Sur iOS, `Reglages.hasOnboarded` compare la version
    /// vue à `Reglages.versionPresentation` : ce doit être celle-ci.
    @Test func laPresentationEstVersionneeEtMontreeAuxInstallationsExistantes() {
        let version = Onboarding.version
        let comparee = Reglages.versionPresentation
        #expect(version >= 2)
        #expect(comparee == version, "la version vue doit être comparée à celle de la présentation")
    }

    @Test func lesLibellesExistentDansLesTroisLangues() throws {
        let cles = [
            "onboarding_step", "onboarding_next", "onboarding_back", "onboarding_skip",
            "onboarding_start", "onboarding_practice", "onboarding_practice_body",
            "onboarding_session", "onboarding_session_body",
            "onboarding_days", "onboarding_days_body",
            "onboarding_texts", "onboarding_texts_body",
            "onboarding_yours", "onboarding_yours_body",
            "onboarding_adresse", "onboarding_adresse_body",
            "adresse_tsadik", "adresse_tsadeket",
            "onboarding_private", "onboarding_private_body",
        ]
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for cle in cles {
                let present = simples[cle] != nil
                #expect(present, "\(langue) : « \(cle) » manquant")
            }
        }
    }

    /// La question צדיק / צדקת est posée une fois, et jamais en dernier : le dernier écran porte la promesse
    /// que rien ne sort du téléphone, c'est elle qu'on doit lire avant de commencer.
    @Test func unSeulEcranDemandeCommentSAdresserAVous() throws {
        let avecChoix = Onboarding.ecrans.filter { $0.choixAdresse }.count
        let dernier = try #require(Onboarding.ecrans.last)
        #expect(avecChoix == 1)
        #expect(dernier.cle == "prive")
        #expect(!dernier.choixAdresse)
    }

    @Test func laDureeEtLeRappelSeChoisissentChacunSurUnSeulEcran() {
        let duree = Onboarding.ecrans.filter { $0.choixDuree }.map { $0.cle }
        let rappel = Onboarding.ecrans.filter { $0.choixRappel }.map { $0.cle }
        #expect(duree == ["seance"])
        #expect(rappel == ["jours"])
        // Les durées proposées existent sur l'écran de pratique.
        for d in Onboarding.durees {
            let offerte = [5, 10, 15, 30, 60, 90].contains(d)
            #expect(offerte, "\(d) min")
        }
    }

    /// La table, entrée par entrée et dans l'ordre d'Android : la version, les durées, les sept écrans.
    @Test func laTableEstCelleDAndroid() throws {
        let v = try vecteurs()
        let version = Onboarding.version
        let durees = Onboarding.durees
        let dernier = Onboarding.dernier
        let n = Onboarding.ecrans.count
        let lus = v.onboardingEcrans.count
        #expect(version == v.onboarding.version)
        #expect(durees == v.onboarding.durees)
        #expect(dernier == v.onboarding.dernier)
        #expect(n == lus, "nombre d'écrans")
        for (ici, lu) in zip(Onboarding.ecrans, v.onboardingEcrans) {
            #expect(ici.cle == lu.cle)
            #expect(ici.titre == lu.titre, "\(lu.cle) : titre")
            #expect(ici.corps == lu.corps, "\(lu.cle) : corps")
            #expect(ici.illustration == lu.illustration, "\(lu.cle) : illustration")
            #expect(ici.choixAdresse == lu.choixAdresse, "\(lu.cle) : choixAdresse")
            #expect(ici.choixDuree == lu.choixDuree, "\(lu.cle) : choixDuree")
            #expect(ici.choixRappel == lu.choixRappel, "\(lu.cle) : choixRappel")
        }
    }

    /// Le parcours d'Android rang par rang, bornes d'un Int de Kotlin comprises (Int.MAX_VALUE + 1 y déborde).
    @Test func leParcoursEstCeluiDAndroid() throws {
        let v = try vecteurs()
        let n = v.onboardingParcours.count
        #expect(n > 20, "rangs lus")
        for p in v.onboardingParcours {
            let ecran = Onboarding.ecran(p.index).cle
            let suivant = Onboarding.suivant(p.index)
            let precedent = Onboarding.precedent(p.index)
            let premier = Onboarding.estPremier(p.index)
            let dernier = Onboarding.estDernier(p.index)
            #expect(ecran == p.ecran, "\(p.index) : ecran")
            #expect(suivant == p.suivant, "\(p.index) : suivant")
            #expect(precedent == p.precedent, "\(p.index) : precedent")
            #expect(premier == p.estPremier, "\(p.index) : estPremier")
            #expect(dernier == p.estDernier, "\(p.index) : estDernier")
        }
    }

    /// Chaque écran nomme des chaînes du catalogue, dans les trois langues, et une image livrée à iOS.
    @Test func chaqueEcranNommeDesChainesEtUneImageLivrees() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            for ecran in Onboarding.ecrans {
                let titre = simples[ecran.titre] != nil
                let corps = simples[ecran.corps] != nil
                #expect(titre, "\(langue) : « \(ecran.titre) » manquant")
                #expect(corps, "\(langue) : « \(ecran.corps) » manquant")
            }
        }
        for ecran in Onboarding.ecrans {
            let chemin = Depot.racine.appendingPathComponent("ios/Ressources/Images/\(ecran.illustration).webp").path
            let livree = FileManager.default.fileExists(atPath: chemin)
            #expect(livree, "\(ecran.illustration).webp manque")
        }
    }
}
