import Foundation
import Testing
@testable import Coeur

/// PlaqueTest d'Android, porté : un toucher fait tourner la plaque du centre des anneaux et montre vos
/// chiffres, face après face, puis revient au hassid (demande du 04/10). Puis tout
/// `Tests/Vecteurs/plaque.json`, écrit par la JVM (tools/vecteurs_ios/VecteursPlaque.kt). Reste à Android
/// `l accueil fait tourner la plaque et compte depuis zero`, qui lit MainActivity et le gabarit de
/// l'accueil ; les clés de `les faces parlent les trois langues` se vérifient sur le catalogue exporté.
@Suite("Plaque")
struct PlaqueTests {

    @Test func lesFacesSeSuiventEtReviennentAuHassid() {
        var face = Plaque.Face.hassid
        var vues: [Plaque.Face] = []
        for _ in Plaque.Face.allCases {
            face = Plaque.suivante(face)
            vues.append(face)
        }
        let nombre = vues.count
        #expect(nombre == 8)
        guard nombre == 8 else { return }
        let derniere = vues[nombre - 1]
        #expect(derniere == Plaque.Face.hassid)
        let toutes = Set(vues)
        let attendues = Set(Plaque.Face.allCases)
        #expect(toutes == attendues)
        let premiere = vues[0]
        #expect(premiere == Plaque.Face.jour)
    }

    @Test func chaqueAnneauASaFace() {
        for quel in Anneaux.Quel.allCases {
            let anneau = Plaque.pour(quel).anneau
            #expect(anneau == quel, "\(quel.rawValue)")
        }
        let serie = Plaque.pour(.serie)
        #expect(serie == Plaque.Face.serie)
        let total = Plaque.Face.total.anneau
        #expect(total == nil)
    }

    @Test func laMoyenneDUnJourDePratique() {
        let sansPratique = Plaque.moyenne(totalMinutes: 0, jours: 0)
        #expect(sansPratique == 0)
        let troisJours = Plaque.moyenne(totalMinutes: 50, jours: 3)
        #expect(troisJours == 17)
        let dixJours = Plaque.moyenne(totalMinutes: 200, jours: 10)
        #expect(dixJours == 20)
    }

    private let lundi = JourCivil.du("2026-09-28")

    @Test func laMeilleureSerieNeCassePasSurUnJourExempte() {
        // Lundi à mercredi faits, jeudi exempté, vendredi fait, samedi manqué, dimanche fait.
        var faits = Set<JourCivil>()
        for decalage in [0, 1, 2, 4, 6] {
            faits.insert(lundi.plus(jours: decalage))
        }
        let jeudi = lundi.plus(jours: 3)
        let avecJeudi = Plaque.meilleureSerie(faits) { $0 == jeudi }
        #expect(avecJeudi == 4)
        let sansExemption = Plaque.meilleureSerie(faits) { _ in false }
        #expect(sansExemption == 3)
        let aucunJour = Plaque.meilleureSerie([]) { _ in false }
        #expect(aucunJour == 0)
        let unJour = Plaque.meilleureSerie([lundi]) { _ in false }
        #expect(unJour == 1)
    }

    @Test func lesFacesParlentLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let cles = ["plaque_jour", "plaque_semaine", "plaque_meilleure", "plaque_total", "plaque_moyenne",
                    "plaque_serie", "plaque_jours"]
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            let pluriels = catalogue.pluriels(langue)
            for cle in cles {
                // plaque_serie et plaque_jours sont des pluriels : leur forme « other » existe dans toute langue.
                let presente = simples[cle] != nil || pluriels["\(cle)[other]"] != nil
                #expect(presente, "\(langue) : \(cle)")
            }
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct FaceV: Decodable {
            let nom: String
            let rang: Int
            let anneau: String?
            let suivante: String
        }
        struct Pour: Decodable {
            let quel: String
            let face: String
        }
        /// Une meilleure série, et les jours pour lesquels la règle a demandé s'il était exempté.
        struct Serie: Decodable {
            let nom: String
            let faits: [String]
            let exemptes: [String]
            let samedis: Bool
            let meilleure: Int
            let demandes: Int
            let premiereDemande: String?
            let derniereDemande: String?
        }

        let retourMs: Int64
        let faces: [FaceV]
        let pour: [Pour]
        /// Deux tours de plaque depuis le hassid, un toucher après l'autre.
        let tour: [String]
        /// [total des minutes, jours, moyenne].
        let moyennes: [[Int]]
        let series: [Serie]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/plaque.json"))
    }

    private struct Illisible: Error {}

    /// Une date comme l'écrit `LocalDate.toString()` : « 2026-09-28 », ou, hors des années 0000 à 9999,
    /// l'année signée (« -0001-12-29 », « +10000-01-01 »).
    private func jour(_ texte: String) throws -> JourCivil {
        if let jour = JourCivil(iso: texte) { return jour }
        let negatif = texte.hasPrefix("-")
        var nombres: [Int] = []
        for partie in texte.dropFirst().split(separator: "-") {
            guard let n = Int(partie) else { throw Illisible() }
            nombres.append(n)
        }
        let compte = nombres.count
        #expect(compte == 3, "date illisible : \(texte)")
        guard compte == 3 else { throw Illisible() }
        let annee = negatif ? -nombres[0] : nombres[0]
        return try #require(JourCivil(annee: annee, mois: nombres[1], jour: nombres[2]), "date illisible : \(texte)")
    }

    @Test func lesFacesDansLOrdreDAndroid() throws {
        let v = try vecteurs()
        let retour = Plaque.retourMs
        #expect(retour == v.retourMs)
        let noms = Plaque.Face.allCases.map { $0.rawValue }
        let attendus = v.faces.map { $0.nom }
        #expect(noms == attendus)
        for f in v.faces {
            let face = try #require(Plaque.Face(rawValue: f.nom), "face inconnue : \(f.nom)")
            let rang = Plaque.Face.allCases.firstIndex(of: face)
            #expect(rang == f.rang, "\(f.nom)")
            let anneau = face.anneau?.rawValue
            #expect(anneau == f.anneau, "\(f.nom)")
            let suivante = Plaque.suivante(face).rawValue
            #expect(suivante == f.suivante, "\(f.nom)")
        }
        for p in v.pour {
            let quel = try #require(Anneaux.Quel(rawValue: p.quel), "anneau inconnu : \(p.quel)")
            let face = Plaque.pour(quel).rawValue
            #expect(face == p.face, "pour(\(p.quel))")
        }
        var face = Plaque.Face.hassid
        var tour: [String] = []
        for _ in v.tour {
            face = Plaque.suivante(face)
            tour.append(face.rawValue)
        }
        #expect(tour == v.tour)
    }

    /// Le quotient en simple précision, arrondi comme `Math.round(float)` : demis vers plus l'infini,
    /// unités perdues au-delà de 2²⁴, bornes de 32 bits.
    @Test func chaqueMoyenneCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.moyennes.count
        #expect(nombre > 600)
        for cas in v.moyennes {
            let complet = cas.count == 3
            #expect(complet, "\(cas)")
            if !complet { continue }
            let moyenne = Plaque.moyenne(totalMinutes: cas[0], jours: cas[1])
            #expect(moyenne == cas[2], "moyenne(\(cas[0]), \(cas[1]))")
        }
    }

    /// La meilleure série, et les jours où la règle demande l'exemption : seulement un jour non fait,
    /// entre le premier et le dernier jour fait, dans l'ordre.
    @Test func chaqueMeilleureSerieCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.series.count
        #expect(nombre > 60)
        for cas in v.series {
            var faits = Set<JourCivil>()
            for texte in cas.faits {
                let j = try jour(texte)
                faits.insert(j)
            }
            var exemptes = Set<JourCivil>()
            for texte in cas.exemptes {
                let j = try jour(texte)
                exemptes.insert(j)
            }
            let samedis = cas.samedis
            var demandes: [JourCivil] = []
            let meilleure = Plaque.meilleureSerie(faits) { j in
                demandes.append(j)
                return exemptes.contains(j) || (samedis && j.jourDeSemaine == 7)
            }
            #expect(meilleure == cas.meilleure, "\(cas.nom)")
            let nombreDemandes = demandes.count
            #expect(nombreDemandes == cas.demandes, "\(cas.nom) : demandes")
            let premiere = demandes.first?.iso
            #expect(premiere == cas.premiereDemande, "\(cas.nom) : première demande")
            let derniere = demandes.last?.iso
            #expect(derniere == cas.derniereDemande, "\(cas.nom) : dernière demande")
        }
    }
}
