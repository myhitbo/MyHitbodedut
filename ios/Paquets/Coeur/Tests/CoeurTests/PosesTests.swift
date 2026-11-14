import Foundation
import Testing
@testable import Coeur

/// Les poses du personnage (Character.kt d'Android, qui n'a pas de test sur Android) :
/// `Tests/Vecteurs/guidee.json` rejoué. Android choisit la pose du jour d'après `LocalDate.now()` ;
/// ici le jour est un argument, et les vecteurs portent des jours fixes, le générateur ayant d'abord
/// vérifié sa règle sur le vrai code pour les jours du lancement (trois fuseaux).
@Suite("Poses")
struct PosesTests {

    private struct Vecteurs: Decodable {
        struct Fixes: Decodable {
            let journal: String
            let study: String
            let reading: String
            let tehilim: String
            let accueil: String
            let source: String
            let article: String
        }
        struct PoseDuMoment: Decodable {
            let moment: String
            let pose: String
        }
        struct PoseDuJour: Decodable {
            let jour: String
            /// `LocalDate.toEpochDay()`.
            let numero: Int
            let call: String
            let during: String
            let joy: String
        }

        let poses: Fixes
        let posesMoments: [PoseDuMoment]
        let posesJours: [PoseDuJour]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/guidee.json"))
    }

    @Test func lesPosesFixesSontCellesDAndroid() throws {
        let v = try vecteurs()
        let accueil = Poses.greeting(false, jour: JourCivil.du("2026-11-14"))
        #expect(Poses.journal == v.poses.journal)
        #expect(Poses.study == v.poses.study)
        #expect(Poses.reading == v.poses.reading)
        #expect(Poses.tehilim == v.poses.tehilim)
        #expect(accueil == v.poses.accueil)
    }

    /// Une source se tient devant le livre, un article est un texte qu'on a écrit : sur toutes les
    /// entrées de la vraie bibliothèque.
    @Test func chaqueEntreeDeLaBibliothequeASaPose() throws {
        let v = try vecteurs()
        let bibliotheque = try JSONDecoder().decode(Bibliotheque.self, from: Depot.contenu("bibliotheque.json"))
        var sources = 0
        var articles = 0
        for entree in bibliotheque.entrees {
            let pose = Poses.ofLibraryEntry(entree)
            switch entree {
            case .source:
                sources += 1
                #expect(pose == v.poses.source, "\(entree.id)")
            case .article:
                articles += 1
                #expect(pose == v.poses.article, "\(entree.id)")
            }
        }
        #expect(sources > 0)
        #expect(articles > 0)
    }

    @Test func chaqueMomentASaPose() throws {
        let v = try vecteurs()
        let n = Moment.allCases.count
        let lus = v.posesMoments.count
        #expect(n == lus, "nombre de moments")
        for lu in v.posesMoments {
            let moment = try #require(Moment(rawValue: lu.moment), "moment inconnu : \(lu.moment)")
            let pose = Poses.ofMoment(moment)
            #expect(pose == lu.pose, "\(lu.moment)")
        }
    }

    @Test func laPoseDuJourEstCelleDAndroid() throws {
        let v = try vecteurs()
        for p in v.posesJours {
            let jour = try #require(JourCivil(iso: p.jour), "jour illisible : \(p.jour)")
            let numero = jour.jourJulien - 2_440_588
            let call = Poses.call(jour)
            let during = Poses.during(jour)
            let joy = Poses.joy(jour)
            let faite = Poses.greeting(true, jour: jour)
            let aFaire = Poses.greeting(false, jour: jour)
            #expect(numero == p.numero, "\(p.jour) : numéro du jour")
            #expect(call == p.call, "\(p.jour) : call")
            #expect(during == p.during, "\(p.jour) : during")
            #expect(joy == p.joy, "\(p.jour) : joy")
            #expect(faite == p.joy, "\(p.jour) : greeting(true)")
            #expect(aFaire == v.poses.accueil, "\(p.jour) : greeting(false)")
        }
    }

    /// La pose ne change pas d'une heure à l'autre : elle ne dépend que du jour, et elle tourne
    /// d'un jour au suivant.
    @Test func laPoseTourneDUnJourAuSuivant() {
        let jour = JourCivil.du("2026-11-14")
        let lendemain = jour.plus(jours: 1)
        let aujourdhui = Poses.call(jour)
        let encore = Poses.call(JourCivil.du("2026-11-14"))
        let demain = Poses.call(lendemain)
        #expect(aujourdhui == encore)
        #expect(aujourdhui != demain)
    }

    /// Chaque image que les poses nomment est livrée à iOS sous le nom qu'Android lui donne.
    @Test func chaqueImageNommeeEstLivree() throws {
        let v = try vecteurs()
        // Des doublons (reading et tehilim sont la même image) : un tableau, que Set réduit.
        var noms = Set([Poses.journal, Poses.study, Poses.reading, Poses.tehilim, v.poses.accueil,
                        v.poses.source, v.poses.article])
        for lu in v.posesMoments {
            noms.insert(lu.pose)
        }
        for p in v.posesJours {
            noms.insert(p.call)
            noms.insert(p.during)
            noms.insert(p.joy)
        }
        for nom in noms.sorted() {
            let chemin = Depot.racine.appendingPathComponent("ios/Ressources/Images/\(nom).webp").path
            let livree = FileManager.default.fileExists(atPath: chemin)
            #expect(livree, "\(nom).webp manque")
        }
    }
}
