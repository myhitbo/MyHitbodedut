import Foundation
import Testing
@testable import Coeur

/// AnneauxTest d'Android, porté : ce que mesurent les trois anneaux, le second tour au-delà de l'objectif,
/// les paliers de la série et les fêtes des anneaux fermés (demandes du 01/10 et du 04/10), puis tout
/// `Tests/Vecteurs/anneaux.json`, écrit par la JVM (tools/vecteurs_ios/VecteursAnneaux.kt). Reste à
/// Android ce qui lit le code des écrans et le gabarit de l'accueil : `l accueil anime les anneaux sans
/// qu on touche`, et dans `l accueil la vignette et les notifications dessinent les memes anneaux` tout
/// sauf les chaînes, vérifiées ici sur le catalogue exporté.
@Suite("Anneaux")
struct AnneauxTests {

    private let semaine = JaugeSemaine.Progression(faits: 4, dus: 6)
    private let mercredi = JourCivil.du("2026-10-07")

    /// `assertEquals(attendu, reel, delta)` de JUnit, pour des flottants.
    private func proches(_ attendu: Float, _ reel: Float, _ delta: Float = 1e-6) -> Bool {
        attendu == reel || abs(attendu - reel) <= delta
    }

    @Test func leJourMesureLesMinutesSurLObjectif() {
        let e = Anneaux.etat(minutesJour: 8, objectifJour: 15, semaine: semaine, serie: 4)
        let fait = e.jour.fait
        #expect(fait == 8)
        let objectif = e.jour.objectif
        #expect(objectif == 15)
        let fraction = proches(Float(8) / Float(15), e.jour.fraction)
        #expect(fraction, "fraction : \(e.jour.fraction)")
        let atteint = e.jour.atteint
        #expect(!atteint)
        let tours = e.jour.tours
        #expect(tours == 0)
    }

    /// Comme chez Apple : l'anneau ne se ferme pas, il repasse sur lui-même.
    @Test func auDelaDeLObjectifLAnneauFaitUnSecondTour() {
        let e = Anneaux.etat(minutesJour: 23, objectifJour: 15, semaine: semaine, serie: 4)
        let atteint = e.jour.atteint
        #expect(atteint)
        let tours = e.jour.tours
        #expect(tours == 1)
        let reste = proches(Float(8) / Float(15), e.jour.reste)
        #expect(reste, "reste : \(e.jour.reste)")
        let double = Anneaux.etat(minutesJour: 30, objectifJour: 15, semaine: semaine, serie: 4)
        let deuxTours = double.jour.tours
        #expect(deuxTours == 2)
        let resteNul = proches(0, double.jour.reste)
        #expect(resteNul, "reste : \(double.jour.reste)")
    }

    @Test func laSemaineReprendLaJaugeExistante() {
        let e = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semaine, serie: 0)
        let fait = e.semaine.fait
        #expect(fait == 4)
        let objectif = e.semaine.objectif
        #expect(objectif == 6)
        let fraction = proches(semaine.fraction, e.semaine.fraction)
        #expect(fraction, "\(semaine.fraction) et \(e.semaine.fraction)")
    }

    @Test func laSerieViseLePremierPalierQuiLAtteint() {
        let attendus: [(serie: Int, palier: Int)] = [
            (0, 7), (1, 7), (7, 7), (8, 14), (14, 14), (15, 30), (30, 30), (31, 60),
            (100, 100), (101, 180), (365, 365), (366, 730), (730, 730), (731, 1095),
        ]
        for (serie, palier) in attendus {
            let calcule = Anneaux.palier(serie)
            #expect(calcule == palier, "série \(serie)")
        }
    }

    @Test func leJourDuPalierLAnneauDeLaSerieEstPlein() {
        let e = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semaine, serie: 7)
        let atteint = e.serie.atteint
        #expect(atteint)
        let plein = proches(1, e.serie.fraction)
        #expect(plein, "fraction : \(e.serie.fraction)")
        // Le lendemain, le palier suivant commence.
        let lendemain = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semaine, serie: 8)
        let atteintLendemain = lendemain.serie.atteint
        #expect(!atteintLendemain)
        let fraction = proches(Float(8) / Float(14), lendemain.serie.fraction)
        #expect(fraction, "fraction : \(lendemain.serie.fraction)")
    }

    @Test func sansObjectifRienNeSeRemplitEtRienNePlante() {
        let e = Anneaux.etat(minutesJour: 10, objectifJour: 0, semaine: JaugeSemaine.Progression(faits: 0, dus: 0), serie: 0)
        let jour = proches(0, e.jour.fraction)
        #expect(jour)
        let semaineVide = proches(0, e.semaine.fraction)
        #expect(semaineVide)
        let serie = proches(0, e.serie.fraction)
        #expect(serie)
        let atteint = e.jour.atteint
        #expect(!atteint)
        // Des valeurs négatives (horloge reculée) sont ramenées à zéro.
        let recule = Anneaux.etat(minutesJour: -5, objectifJour: 15, semaine: semaine, serie: -2).jour.fait
        #expect(recule == 0)
    }

    @Test func lObjectifQuotidienRetombeSurLaDureeHabituelle() {
        let nonRegle = Anneaux.objectifEffectif(regle: 0, dureeHabituelle: 15)
        #expect(nonRegle == 15)
        let regle = Anneaux.objectifEffectif(regle: 20, dureeHabituelle: 15)
        #expect(regle == 20)
        let auMoinsUne = Anneaux.objectifEffectif(regle: 0, dureeHabituelle: 0)
        #expect(auMoinsUne == 1)
    }

    @Test func duCentreVersLExterieurJourSemaineSerie() {
        let e = Anneaux.etat(minutesJour: 8, objectifJour: 15, semaine: semaine, serie: 4)
        let ordre = e.duCentre.map { $0.quel }
        let attendu: [Anneaux.Quel] = [.jour, .semaine, .serie]
        #expect(ordre == attendu)
    }

    /// Seules les chaînes se portent : le reste lit AnneauxView, StreakWidget, AnneauxImage, Reminder,
    /// SessionService, MainActivity et le gabarit de l'accueil.
    @Test func lAccueilLaVignetteEtLesNotificationsDessinentLesMemesAnneaux() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in ["settings_daily_goal", "ring_day_detail", "ring_streak_detail", "rings_description"] {
                let presente = chaines[cle] != nil
                #expect(presente, "\(langue) : \(cle)")
            }
        }
    }

    // MARK: Animations automatiques (demande du 04/10)

    @Test func unAnneauFermeSeFeteUneFoisPuisPlus() {
        let plein = Anneaux.etat(minutesJour: 15, objectifJour: 15, semaine: semaine, serie: 4)
        let jourSeul: [Anneaux.Quel] = [.jour]
        let premiere = Anneaux.aFeter(plein, aujourdhui: mercredi, dejaFetes: [])
        #expect(premiere == jourSeul)
        let deja = Anneaux.marques(plein, aujourdhui: mercredi)
        let seconde = Anneaux.aFeter(plein, aujourdhui: mercredi, dejaFetes: deja)
        #expect(seconde.isEmpty)
        // Le lendemain, l'anneau du jour refermé se fête de nouveau.
        let lendemain = Anneaux.aFeter(plein, aujourdhui: mercredi.plus(jours: 1), dejaFetes: deja)
        #expect(lendemain == jourSeul)
    }

    @Test func rienAFeterTantQuAucunAnneauNEstFerme() {
        let e = Anneaux.etat(minutesJour: 8, objectifJour: 15, semaine: semaine, serie: 4)
        let aFeter = Anneaux.aFeter(e, aujourdhui: mercredi, dejaFetes: [])
        #expect(aFeter.isEmpty)
        let marques = Anneaux.marques(e, aujourdhui: mercredi)
        #expect(marques.isEmpty)
    }

    @Test func laSemaineSeFeteUneFoisParSemaineEtLaSerieUneFoisParPalier() {
        let semainePleine = JaugeSemaine.Progression(faits: 6, dus: 6)
        let e = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: semainePleine, serie: 7)
        let attendus: [Anneaux.Quel] = [.semaine, .serie]
        let premiere = Anneaux.aFeter(e, aujourdhui: mercredi, dejaFetes: [])
        #expect(premiere == attendus)
        let deja = Anneaux.marques(e, aujourdhui: mercredi)
        // Jeudi, même semaine : rien de neuf pour la semaine.
        let jeudi = Anneaux.aFeter(e, aujourdhui: mercredi.plus(jours: 1), dejaFetes: deja)
        let semaineJeudi = jeudi.contains(.semaine)
        #expect(!semaineJeudi)
        // Dimanche suivant : une autre semaine.
        let dimanche = Anneaux.aFeter(e, aujourdhui: JourCivil.du("2026-10-11"), dejaFetes: deja)
        let semaineDimanche = dimanche.contains(.semaine)
        #expect(semaineDimanche)
        // Le palier suivant de la série (14) se fête à son tour.
        let quatorze = Anneaux.etat(minutesJour: 0, objectifJour: 15, semaine: JaugeSemaine.Progression(faits: 0, dus: 0), serie: 14)
        let serieSeule: [Anneaux.Quel] = [.serie]
        let palier = Anneaux.aFeter(quatorze, aujourdhui: mercredi, dejaFetes: deja)
        #expect(palier == serieSeule)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        /// Un anneau, son nom étant celui de l'énumération Kotlin.
        struct AnneauV: Decodable {
            let quel: String
            let fait: Int
            let objectif: Int
        }
        struct Palier: Decodable {
            let serie: Int
            let palier: Int
        }
        /// Les valeurs d'un anneau ; les flottants sont donnés aussi par leurs bits (`floatToRawIntBits`).
        struct Valeurs: Decodable {
            let fait: Int
            let objectif: Int
            let fraction: Double
            let bitsFraction: Int32
            let tours: Int
            let reste: Double
            let bitsReste: Int32
            let atteint: Bool
        }
        struct Entree: Decodable {
            let minutesJour: Int
            let objectifJour: Int
            let faits: Int
            let dus: Int
            let serie: Int
        }
        struct EtatV: Decodable {
            let entree: Entree
            let jour: AnneauV
            let semaine: AnneauV
            let serie: AnneauV
            let duCentre: [String]
            let bitsFractions: [Int32]
            let atteints: [Bool]
        }
        /// `trouves[i]` : l'anneau que rend `anneau(Quel.entries[i])`, null là où Kotlin lève.
        struct ParQuel: Decodable {
            let duCentre: [AnneauV]
            let trouves: [AnneauV?]
        }
        struct Objectif: Decodable {
            let regle: Int
            let dureeHabituelle: Int
            let objectif: Int
        }
        struct Fete: Decodable {
            let deja: [String]
            let aFeter: [String]
        }
        struct Marques: Decodable {
            let jour: String
            let duCentre: [AnneauV]
            let parAnneau: [String?]
            let marques: [String]
            let fetes: [Fete]
        }
        /// Une date hors des années 0000 à 9999, donnée par ses trois nombres.
        struct Lointaine: Decodable {
            let annee: Int
            let mois: Int
            let jour: Int
            let duCentre: [AnneauV]
            let parAnneau: [String?]
        }

        let table: [Int]
        let paliers: [Palier]
        let anneaux: [Valeurs]
        let etats: [EtatV]
        let parQuel: [ParQuel]
        let objectifs: [Objectif]
        let marques: [Marques]
        let marquesLointaines: [Lointaine]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/anneaux.json"))
    }

    private func anneau(_ a: Vecteurs.AnneauV) throws -> Anneaux.Anneau {
        let quel = try #require(Anneaux.Quel(rawValue: a.quel), "anneau inconnu : \(a.quel)")
        return Anneaux.Anneau(quel: quel, fait: a.fait, objectif: a.objectif)
    }

    /// Un état bâti à la main, du centre vers l'extérieur.
    private func etat(_ anneaux: [Vecteurs.AnneauV]) throws -> Anneaux.Etat {
        let nombre = anneaux.count
        #expect(nombre == 3, "un état a trois anneaux")
        guard nombre == 3 else { throw Incomplet() }
        return try Anneaux.Etat(jour: anneau(anneaux[0]), semaine: anneau(anneaux[1]), serie: anneau(anneaux[2]))
    }

    private struct Incomplet: Error {}

    private func bits(_ x: Float) -> Int32 {
        Int32(bitPattern: x.bitPattern)
    }

    /// Les marques de chaque anneau, du centre vers l'extérieur.
    private func parAnneau(_ e: Anneaux.Etat, _ jour: JourCivil) -> [String?] {
        var marques: [String?] = []
        for a in e.duCentre {
            marques.append(Anneaux.marque(a, aujourdhui: jour))
        }
        return marques
    }

    @Test func chaquePalierCommeSurAndroid() throws {
        let v = try vecteurs()
        let table = Anneaux.paliers
        #expect(table == v.table)
        let nombre = v.paliers.count
        #expect(nombre > 300)
        for p in v.paliers {
            let palier = Anneaux.palier(p.serie)
            #expect(palier == p.palier, "palier(\(p.serie))")
        }
    }

    /// Fraction, tours et reste en simple précision, bit pour bit, y compris aux bornes des entiers.
    @Test func chaqueAnneauCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.anneaux.count
        #expect(nombre > 200)
        for cas in v.anneaux {
            let a = Anneaux.Anneau(quel: .jour, fait: cas.fait, objectif: cas.objectif)
            let contexte = "\(cas.fait) sur \(cas.objectif)"
            let bitsFraction = bits(a.fraction)
            #expect(bitsFraction == cas.bitsFraction, "fraction de \(contexte) : \(a.fraction), Android \(cas.fraction)")
            let tours = a.tours
            #expect(tours == cas.tours, "tours de \(contexte)")
            let bitsReste = bits(a.reste)
            #expect(bitsReste == cas.bitsReste, "reste de \(contexte) : \(a.reste), Android \(cas.reste)")
            let atteint = a.atteint
            #expect(atteint == cas.atteint, "atteint pour \(contexte)")
        }
    }

    @Test func chaqueEtatCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.etats.count
        #expect(nombre > 60)
        for cas in v.etats {
            let n = cas.entree
            let e = Anneaux.etat(minutesJour: n.minutesJour, objectifJour: n.objectifJour,
                                 semaine: JaugeSemaine.Progression(faits: n.faits, dus: n.dus), serie: n.serie)
            let contexte = "etat(\(n.minutesJour), \(n.objectifJour), (\(n.faits), \(n.dus)), \(n.serie))"
            let jour = try anneau(cas.jour)
            #expect(e.jour == jour, "\(contexte)")
            let semaine = try anneau(cas.semaine)
            #expect(e.semaine == semaine, "\(contexte)")
            let serie = try anneau(cas.serie)
            #expect(e.serie == serie, "\(contexte)")
            let noms = e.duCentre.map { $0.quel.rawValue }
            #expect(noms == cas.duCentre, "\(contexte)")
            let fractions = e.duCentre.map { bits($0.fraction) }
            #expect(fractions == cas.bitsFractions, "\(contexte)")
            let atteints = e.duCentre.map { $0.atteint }
            #expect(atteints == cas.atteints, "\(contexte)")
        }
    }

    /// `Etat.anneau(quel)` : le premier du centre qui porte ce nom, nil là où Kotlin lève.
    @Test func chaqueAnneauParSonNomCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.parQuel.count
        #expect(nombre > 0)
        for cas in v.parQuel {
            let e = try etat(cas.duCentre)
            let quels = Anneaux.Quel.allCases
            let rangs = quels.count
            #expect(rangs == cas.trouves.count)
            for (quel, trouve) in zip(quels, cas.trouves) {
                let calcule = e.anneau(quel)
                let attendu: Anneaux.Anneau?
                if let trouve {
                    attendu = try anneau(trouve)
                } else {
                    attendu = nil
                }
                #expect(calcule == attendu, "anneau(\(quel.rawValue))")
            }
        }
    }

    @Test func chaqueObjectifEffectifCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.objectifs.count
        #expect(nombre > 50)
        for cas in v.objectifs {
            let objectif = Anneaux.objectifEffectif(regle: cas.regle, dureeHabituelle: cas.dureeHabituelle)
            #expect(objectif == cas.objectif, "objectifEffectif(\(cas.regle), \(cas.dureeHabituelle))")
        }
    }

    /// Chaque état un jour donné : la marque de chaque anneau, les marques gardées, puis ce qui reste à
    /// fêter selon ce qui l'a déjà été (marques voisines des vraies comprises).
    @Test func chaqueMarqueEtChaqueFeteCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.marques.count
        #expect(nombre > 40)
        for cas in v.marques {
            let e = try etat(cas.duCentre)
            let jour = try #require(JourCivil(iso: cas.jour), "jour illisible : \(cas.jour)")
            let marquesDesAnneaux = parAnneau(e, jour)
            #expect(marquesDesAnneaux == cas.parAnneau, "\(cas.jour)")
            let marques = Anneaux.marques(e, aujourdhui: jour)
            let attendues = Set(cas.marques)
            #expect(marques == attendues, "\(cas.jour)")
            for f in cas.fetes {
                let aFeter = Anneaux.aFeter(e, aujourdhui: jour, dejaFetes: Set(f.deja)).map { $0.rawValue }
                #expect(aFeter == f.aFeter, "\(cas.jour), déjà fêtés \(f.deja)")
            }
        }
    }

    /// Hors des années 0000 à 9999, la date s'écrit comme `LocalDate.toString()` : « +10000-01-01 ».
    @Test func lesMarquesDesAnneesLointainesCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.marquesLointaines.count
        #expect(nombre > 0)
        for cas in v.marquesLointaines {
            let contexte = "\(cas.annee)/\(cas.mois)/\(cas.jour)"
            let jour = try #require(JourCivil(annee: cas.annee, mois: cas.mois, jour: cas.jour), "\(contexte)")
            let e = try etat(cas.duCentre)
            let marquesDesAnneaux = parAnneau(e, jour)
            #expect(marquesDesAnneaux == cas.parAnneau, "\(contexte)")
        }
    }
}
