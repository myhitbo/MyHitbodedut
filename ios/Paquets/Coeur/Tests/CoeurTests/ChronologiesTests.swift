import Foundation
import Testing
@testable import Coeur

/// Les chronologies des vignettes des zmanim (Chronologies.swift) : les tests neufs de la tâche 12 (ROADMAP), une
/// entrée de chronologie par zman et la bascule du jour hébreu à tsét, et rien de ce qui s'affiche ne change entre
/// deux entrées. Puis ce que `Tests/Vecteurs/chronologies.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursChronologies.kt), dit que la vignette d'Android montrerait à 2 292 instants de
/// trente journées, avec les zmanim de KosherJava rendus tels quels. Restent à Android les vues (RemoteViews),
/// l'alarme du prochain changement (ZmanimTic) et la lecture des réglages.
@Suite("Chronologies des vignettes")
struct ChronologiesTests {

    // MARK: Les vecteurs de la JVM

    /// Un élément de réponse : un nombre, un texte, un booléen ou null.
    private enum Brut: Decodable {
        case nombre(Int64)
        case texte(String)
        case booleen(Bool)
        case nul

        init(from decoder: any Decoder) throws {
            let c = try decoder.singleValueContainer()
            if c.decodeNil() {
                self = .nul
            } else if let b = try? c.decode(Bool.self) {
                self = .booleen(b)
            } else if let n = try? c.decode(Int64.self) {
                self = .nombre(n)
            } else {
                self = .texte(try c.decode(String.self))
            }
        }

        var nombre: Int64? {
            if case .nombre(let n) = self { return n }
            return nil
        }

        var texte: String? {
            if case .texte(let t) = self { return t }
            return nil
        }

        var booleen: Bool? {
            if case .booleen(let b) = self { return b }
            return nil
        }
    }

    private struct Hebreu: Decodable {
        let date: String
        let fete: String?
        let paracha: String?
    }

    private struct Jour: Decodable {
        let lieu: String
        let latitude: Double
        let longitude: Double
        let fuseau: String
        let israel: Bool
        let jour: String
        let horaires: [String: Int64]
        let demain: [String: Int64]
        let veille: Int64?
        let hebreu: [String: Hebreu]
        let reponses: [[Brut]]
    }

    private struct Fichier: Decodable {
        let jours: [Jour]
    }

    private static func vecteurs() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/chronologies.json"))
    }

    private static func fuseau(_ identifiant: String) -> Fuseau {
        guard let f = Fuseau(identifiant) else { preconditionFailure("fuseau inconnu : \(identifiant)") }
        return f
    }

    private static func lieu(_ j: Jour) -> Zmanim.Lieu {
        Zmanim.Lieu(nom: j.lieu, latitude: j.latitude, longitude: j.longitude, fuseau: j.fuseau)
    }

    /// Les zmanim que la JVM a écrits pour ce jour et le lendemain ; rien pour une autre date.
    private static func horaires(_ j: Jour) -> PlanNotifications.Horaires {
        let jour = JourCivil.du(j.jour)
        let lendemain = jour.plus(jours: 1)
        let duJour = j.horaires
        let demain = j.demain
        return { _, date in
            if date == jour { return duJour }
            if date == lendemain { return demain }
            return [:]
        }
    }

    private static func pastille(_ h: Hebreu?) -> Libelle? {
        if let fete = h?.fete { return Libelle(fete) }
        if let paracha = h?.paracha { return Libelle("widget_paracha", .texte(paracha)) }
        return nil
    }

    @Test func lesVecteursCouvrentTrenteJournees() throws {
        let f = try Self.vecteurs()
        let jours = f.jours.count
        #expect(jours == 30)
        var reponses = 0
        for j in f.jours { reponses += j.reponses.count }
        #expect(reponses == 2292)
    }

    @Test func laVignetteMontreCeQueMontreAndroid() throws {
        for j in try Self.vecteurs().jours {
            let lieu = Self.lieu(j)
            let zone = Self.fuseau(j.fuseau)
            let horaires = Self.horaires(j)
            for r in j.reponses {
                let t = try #require(r[0].nombre)
                let contexte = "\(j.lieu) \(j.jour) à \(t)"
                let grande = Chronologies.affichage(famille: .grande, lieu: lieu, maintenant: t, fuseauTelephone: zone,
                                                    enIsrael: j.israel, horaires: horaires)
                #expect(grande.priere == r[1].texte, "\(contexte)")
                let limiteAttendue: Int64?
                switch r[2].texte {
                case nil: limiteAttendue = nil
                case "veille"?: limiteAttendue = j.veille
                case let cle?: limiteAttendue = j.horaires[cle]
                }
                #expect(grande.limite == limiteAttendue, "\(contexte)")
                #expect(grande.jourHebreu.iso == r[3].texte, "\(contexte)")
                let hebreu = j.hebreu[grande.jourHebreu.iso]
                #expect(grande.dateHebraique == hebreu?.date, "\(contexte)")
                let pastille = Self.pastille(hebreu)
                #expect(grande.pastille == pastille, "\(contexte)")
                // La journée de la grande vignette : d'aujourd'hui, ou de demain une fois la nuit tombée.
                let demain = try #require(r[4].booleen)
                let source = demain ? j.demain : j.horaires
                var journee: [Chronologies.ZmanAffiche] = []
                for cle in ZmanimVignette.journee {
                    if let instant = source[cle] { journee.append(Chronologies.ZmanAffiche(cle: cle, instant: instant)) }
                }
                #expect(grande.journee == journee, "\(contexte)")
                let prochain = try #require(r[5].nombre)
                let indice: Int? = prochain >= 0 ? Int(prochain) : nil
                #expect(grande.prochain == indice, "\(contexte)")
                // La moyenne : les trois suivants, lus comme getOrNull(prochain + k).
                let moyenne = Chronologies.affichage(famille: .moyenne, lieu: lieu, maintenant: t, fuseauTelephone: zone,
                                                     enIsrael: j.israel, horaires: horaires)
                var prochains: [Chronologies.ZmanAffiche?] = []
                for k in 0..<3 {
                    let i = Int(prochain) + k
                    prochains.append(i >= 0 && i < journee.count ? journee[i] : nil)
                }
                #expect(moyenne.prochains == prochains, "\(contexte)")
                let moyenneSansJournee = moyenne.journee.isEmpty
                #expect(moyenneSansJournee, "\(contexte)")
                let petite = Chronologies.affichage(famille: .petite, lieu: lieu, maintenant: t, fuseauTelephone: zone,
                                                    enIsrael: j.israel, horaires: horaires)
                #expect(petite.priere == grande.priere, "\(contexte)")
                #expect(petite.limite == grande.limite, "\(contexte)")
                let petiteSansListe = petite.prochains.isEmpty && petite.journee.isEmpty && petite.prochain == nil
                #expect(petiteSansListe, "\(contexte)")
            }
        }
    }

    // MARK: La chronologie

    /// La dernière entrée commencée à `t`.
    private static func enVigueur(_ c: Chronologies.Chronologie, _ t: Int64) -> Chronologies.Entree? {
        c.entrees.last(where: { $0.instant <= t })
    }

    @Test func uneEntreeParZmanEtRienNeChangeEntreDeux() throws {
        for j in try Self.vecteurs().jours {
            let lieu = Self.lieu(j)
            let zone = Self.fuseau(j.fuseau)
            let horaires = Self.horaires(j)
            let jour = JourCivil.du(j.jour)
            let minuit = zone.millis(DateHeure(jour))
            let minuitSuivant = DateHeureZonee(DateHeure(jour.plus(jours: 1)), fuseau: zone).millis
            for famille in Chronologies.Famille.allCases {
                let c = Chronologies.chronologie(famille: famille, lieu: lieu, maintenant: minuit, fuseauTelephone: zone,
                                                 enIsrael: j.israel, horaires: horaires)
                let contexte = "\(j.lieu) \(j.jour) \(famille.rawValue)"
                #expect(c.recharge == minuitSuivant, "\(contexte)")
                let instants = c.entrees.map { $0.instant }
                let premier = instants.first
                #expect(premier == minuit, "\(contexte)")
                let tries = instants == instants.sorted() && Set(instants).count == instants.count
                #expect(tries, "\(contexte)")
                // Une entrée par zman du jour, et pas d'autre que minuit, les zmanim et le milieu de la nuit d'hier.
                var attendus: Set<Int64> = [minuit]
                for t in j.horaires.values where t >= minuit && t < minuitSuivant { attendus.insert(t) }
                if let veille = j.veille, veille >= minuit, veille < minuitSuivant { attendus.insert(veille) }
                #expect(Set(instants) == attendus, "\(contexte)")
                // Rien de ce qui s'affiche ne change entre deux entrées.
                for r in j.reponses {
                    let t = try #require(r[0].nombre)
                    let entree = try #require(Self.enVigueur(c, t))
                    let ici = Chronologies.affichage(famille: famille, lieu: lieu, maintenant: t, fuseauTelephone: zone,
                                                     enIsrael: j.israel, horaires: horaires)
                    #expect(entree.affichage == ici, "\(contexte) à \(t)")
                }
            }
        }
    }

    @Test func leJourHebreuBasculeATset() throws {
        for j in try Self.vecteurs().jours {
            guard let tset = j.horaires["tset"] else { continue }
            let zone = Self.fuseau(j.fuseau)
            let jour = JourCivil.du(j.jour)
            let c = Chronologies.chronologie(famille: .petite, lieu: Self.lieu(j), maintenant: zone.millis(DateHeure(jour)),
                                             fuseauTelephone: zone, enIsrael: j.israel, horaires: Self.horaires(j))
            let trouve = c.entrees.firstIndex(where: { $0.instant == tset })
            let rang = try #require(trouve, "\(j.lieu) \(j.jour)")
            #expect(rang > 0, "\(j.lieu) \(j.jour)")
            let avant = c.entrees[rang - 1].affichage.jourHebreu
            let apres = c.entrees[rang].affichage.jourHebreu
            #expect(avant == jour, "\(j.lieu) \(j.jour)")
            #expect(apres == jour.plus(jours: 1), "\(j.lieu) \(j.jour)")
            let dateAvant = c.entrees[rang - 1].affichage.dateHebraique
            let dateApres = c.entrees[rang].affichage.dateHebraique
            #expect(dateAvant != dateApres, "\(j.lieu) \(j.jour)")
        }
    }

    @Test func enCoursDeJourneeLaPremiereEntreeEstMaintenant() throws {
        let f = try Self.vecteurs()
        let j = try #require(f.jours.first)
        let zone = Self.fuseau(j.fuseau)
        let maintenant = zone.millis(DateHeure(JourCivil.du(j.jour), heure: 13, minute: 7, seconde: 3))
        let c = Chronologies.chronologie(famille: .moyenne, lieu: Self.lieu(j), maintenant: maintenant,
                                         fuseauTelephone: zone, enIsrael: j.israel, horaires: Self.horaires(j))
        let premier = c.entrees.first?.instant
        #expect(premier == maintenant)
        let passes = c.entrees.filter { $0.instant < maintenant }.count
        #expect(passes == 0)
        let minuitSuivant = zone.millis(DateHeure(JourCivil.du(j.jour).plus(jours: 1)))
        let apres = j.horaires.values.filter { $0 > maintenant && $0 < minuitSuivant }.count
        let nombre = c.entrees.count
        #expect(nombre == apres + 1)
    }

    @Test func sansLieuUneSeuleEntreeJusquAMinuitDuTelephone() {
        let paris = Self.fuseau("Europe/Paris")
        let maintenant = paris.millis(DateHeure(JourCivil.du("2026-10-16"), heure: 21))
        let c = Chronologies.chronologie(famille: .grande, lieu: nil, maintenant: maintenant, fuseauTelephone: paris,
                                         enIsrael: false, horaires: { _, _ in [:] })
        let nombre = c.entrees.count
        #expect(nombre == 1)
        let minuit = paris.millis(DateHeure(JourCivil.du("2026-10-17")))
        #expect(c.recharge == minuit)
        if let a = c.entrees.first?.affichage {
            #expect(a.priere == nil)
            #expect(a.titre == Libelle("zmanim_choisir_lieu"))
            #expect(a.jourHebreu == JourCivil.du("2026-10-16"))
            let vide = a.journee.isEmpty && a.prochains.isEmpty && a.limite == nil
            #expect(vide)
        }
    }

    @Test func avecLesVraisZmanimLeVendrediSoirDitDejaChabbat() throws {
        // Jérusalem, vendredi 16 octobre 2026 (KosherSwift) : à tsét, la vignette passe au samedi.
        let jerusalem = Self.fuseau("Asia/Jerusalem")
        let vendredi = JourCivil.du("2026-10-16")
        let c = Chronologies.chronologie(famille: .grande, lieu: Lieux.jerusalem, maintenant: jerusalem.millis(DateHeure(vendredi)),
                                         fuseauTelephone: jerusalem, enIsrael: true)
        let nombre = c.entrees.count
        #expect(nombre >= 15)
        #expect(nombre <= 20)
        let derniere = try #require(c.entrees.last)
        #expect(derniere.affichage.jourHebreu == vendredi.plus(jours: 1))
        #expect(derniere.affichage.priere == "arvit")
        let premiere = try #require(c.entrees.first)
        #expect(premiere.affichage.jourHebreu == vendredi)
        let paracha = premiere.affichage.pastille?.cle
        #expect(paracha == "widget_paracha")
    }

    @Test func lesTitresSontDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            var cles = ["zmanim_choisir_lieu", "widget_zmanim_chaharit", "widget_zmanim_minha", "widget_zmanim_arvit",
                        "widget_paracha"]
            for cle in ZmanimVignette.journee { cles.append("zman_" + cle) }
            for cle in cles {
                let present = chaines[cle] != nil
                #expect(present, "\(langue) : \(cle)")
            }
        }
    }
}
