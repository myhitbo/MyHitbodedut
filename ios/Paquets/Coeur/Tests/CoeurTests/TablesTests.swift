import Foundation
import Testing
@testable import Coeur

/// Les tables écrites dans le Kotlin d'Android (ios/PORTAGE.md § 4.1, tableau C ; ios/ROADMAP.md, tâche 6),
/// jugées contre `Tests/Vecteurs/tables.json`, que la JVM écrit en lisant le vrai Kotlin
/// (tools/vecteurs_ios/VecteursTables.kt). Écart de conception voulu : ROADMAP prévoyait tables.json comme
/// ressource lue par l'app ; les tables ont été écrites en Swift, grappe par grappe, et ce fichier est ici le
/// juge qui les compare entrée par entrée et vérifie les comptes du critère (6 échelles de paliers, 11
/// familles et 128 niveaux, 30 et 7 portions, 10 sujets, 5 temps, 21 correspondances de poses, 15 zmanim).
/// Une table changée dans le Kotlin change tables.json, et la garde de dérive (ios-oracle.yml) échoue.
/// Quand la table Swift est privée (Reference, SaisieVol, Poses), ce sont les sondes de tables.json qui la
/// jugent : la règle qui s'en sert doit répondre comme celle d'Android. Il n'y a pas de test Kotlin à porter :
/// rien ne reste à Android.
@Suite("Tables du Kotlin")
struct TablesTests {

    // MARK: - Les comptes du critère

    @Test func lesComptesDuCritereTiennent() throws {
        let v = try Self.vecteurs()
        let critere: [String: Int] = [
            "paliersEchelles": 6, "tropheesFamilles": 11, "tropheesNiveaux": 128, "tehilimMois": 30,
            "tehilimSemaine": 7, "sujetsTefila": 10, "sujetsSeance": 10, "mouvements": 5, "posesFeminines": 21,
            "zmanim": 15,
        ]
        for cle in critere.keys.sorted() {
            let lu = v.comptes[cle]
            let attendu = critere[cle]
            #expect(lu == attendu, "tables.json, \(cle)")
        }
        // Les mêmes comptes, côté Swift.
        let swift: [String: Int] = [
            "paliersEchelles": Paliers.Piste.allCases.count,
            "tropheesFamilles": Trophees.Famille.allCases.count,
            "tropheesNiveaux": Trophees.chemin.count,
            "tehilimMois": CycleTehilim.mois.count,
            "tehilimSemaine": CycleTehilim.semaine.count,
            "sujetsTefila": SujetTefila.allCases.count,
            "sujetsSeance": Theme.allCases.count,
            "mouvements": Hitbodedut.mouvements.count,
            "posesFeminines": Personnage.feminins.count,
            "zmanim": Zmanim.profil.count,
            "questions": QuestionsBlocage.questions.count,
            "ecransPresentation": Onboarding.ecrans.count,
            "conseils": Tips.all.count,
            "fetes": CalendrierJuif.fetes.count,
            "conditions": CalendrierJuif.C.toutes.count,
            "conditionsDerivees": CalendrierJuif.C.derivees.count,
            "compagnies": SaisieVol.compagnies.count,
            "contourIsrael": TerritoireIsrael.contour.count,
            "polices": PoliceHebraique.Police.allCases.count,
            "morceaux": MusiquePlay.morceaux.count,
            "tikkun": Tikkun.ordre.count,
        ]
        for cle in swift.keys.sorted() {
            let lu = v.comptes[cle]
            let compte = swift[cle]
            #expect(compte == lu, "Swift, \(cle)")
        }
        // Les tables privées du Swift : chacune de leurs entrées a sa sonde dans tables.json.
        let livres = v.reference.livres.count
        #expect(v.comptes["livresReference"] == livres)
        let villes = v.saisieVol.principal.count
        #expect(v.comptes["villesPrincipales"] == villes)
        let mois = v.saisieVol.mois.count
        #expect(v.comptes["nomsDeMois"] == mois)
    }

    // MARK: - Hitbodedut.kt

    @Test func lesCinqTempsDeLaHitbodedoutGuidee() throws {
        let v = try Self.vecteurs().hitbodedut
        let likoutei = Hitbodedut.sourceLikoutei
        #expect(likoutei == v.sourceLikoutei)
        let rambam = Hitbodedut.sourceRambam
        #expect(rambam == v.sourceRambam)
        let n = Hitbodedut.mouvements.count
        #expect(n == v.mouvements.count)
        for (i, attendu) in v.mouvements.enumerated() where i < n {
            let m = Hitbodedut.mouvements[i]
            #expect(m.cle == attendu.cle, "rang \(i)")
            let he = Array(m.he.utf16)
            let heAttendu = Array(attendu.he.utf16)
            #expect(he == heAttendu, "\(attendu.cle) : l'hébreu vocalisé, unité par unité")
            #expect(m.titre == attendu.titre, "\(attendu.cle)")
            #expect(m.invite == attendu.invite, "\(attendu.cle)")
            #expect(m.illustration == attendu.illustration, "\(attendu.cle)")
            #expect(m.source == attendu.source, "\(attendu.cle)")
        }
    }

    // MARK: - Paliers.kt

    @Test func lesSixEchellesDePaliers() throws {
        let v = try Self.vecteurs().paliers
        let noms = Paliers.Piste.allCases.map { $0.rawValue }
        let nomsAttendus = v.map { $0.nom }
        #expect(noms == nomsAttendus, "les pistes, dans l'ordre")
        for attendu in v {
            let piste = try #require(Paliers.Piste(rawValue: attendu.nom), "piste \(attendu.nom)")
            #expect(piste.cle == attendu.cle)
            let base = Paliers.echelle(piste, jusqua: -1)
            #expect(base == attendu.base, "\(attendu.nom) : l'échelle de base")
            let dernier = try #require(attendu.base.last)
            let suite = Paliers.echelle(piste, jusqua: dernier)
            let suiteAttendue = attendu.base + [dernier + attendu.pas]
            #expect(suite == suiteAttendue, "\(attendu.nom) : le pas au-delà du dernier palier")
        }
    }

    // MARK: - Trophees.kt

    @Test func lesOnzeFamillesEtLesCentVingtHuitNiveaux() throws {
        let v = try Self.vecteurs().trophees
        let metaux = Trophees.Metal.allCases.map { $0.rawValue }
        #expect(metaux == v.metaux)
        let formes = Trophees.Forme.allCases.map { $0.rawValue }
        let formesAttendues = v.formes.map { $0.nom }
        #expect(formes == formesAttendues)
        for attendue in v.formes {
            let forme = try #require(Trophees.Forme(rawValue: attendue.nom), "forme \(attendue.nom)")
            #expect(forme.cle == attendue.cle)
        }
        let familles = Trophees.Famille.allCases.map { $0.rawValue }
        let famillesAttendues = v.familles.map { $0.nom }
        #expect(familles == famillesAttendues, "les familles, dans l'ordre")
        for attendue in v.familles {
            let f = try #require(Trophees.Famille(rawValue: attendue.nom), "famille \(attendue.nom)")
            #expect(f.cle == attendue.cle, "\(attendue.nom)")
            #expect(f.icone == attendue.icone, "\(attendue.nom)")
            #expect(f.forme.rawValue == attendue.forme, "\(attendue.nom)")
            #expect(f.seuils == attendue.seuils, "\(attendue.nom) : les seuils")
            let metauxFamille = (1...max(f.seuils.count, 1)).map { Trophees.metal(f, $0).rawValue }
            #expect(metauxFamille == attendue.metaux, "\(attendue.nom) : le métal de chaque rang")
            let couts = f.seuils.map { Trophees.cout(f, $0) }
            #expect(couts == attendue.couts, "\(attendue.nom) : le coût de chaque niveau")
        }
        let chemin = Trophees.chemin.map { $0.cle }
        #expect(chemin == v.chemin, "le chemin, du plus facile au plus dur")
        let grades = Trophees.seuilsGrades
        #expect(grades == v.seuilsGrades)
    }

    // MARK: - Tehilim.kt, Tikkun.kt

    @Test func lesPortionsDesTehilimEtLOrdreDuTikoun() throws {
        let v = try Self.vecteurs()
        let psaumes = Tehilim.nombreDePsaumes
        #expect(psaumes == v.tehilim.psaumes)
        for (nom, swift, attendues) in [("mois", CycleTehilim.mois, v.tehilim.mois),
                                        ("semaine", CycleTehilim.semaine, v.tehilim.semaine)] {
            #expect(swift.count == attendues.count, "\(nom)")
            for (i, a) in attendues.enumerated() where i < swift.count {
                let p = swift[i]
                #expect(p.debut == a.debut, "\(nom) \(i + 1)")
                #expect(p.fin == a.fin, "\(nom) \(i + 1)")
                #expect(p.debutVerset == a.debutVerset, "\(nom) \(i + 1)")
                #expect(p.finVerset == a.finVerset, "\(nom) \(i + 1)")
            }
        }
        let ordre = Tikkun.ordre
        #expect(ordre == v.tikkun.ordre)
        let blocs = [Tikkun.ouverture, Tikkun.cloture, Tikkun.kavana, Tikkun.priere]
        #expect(blocs == v.tikkun.blocs)
    }

    // MARK: - Tefilot.kt, Theme.kt, QuestionsBlocage.kt, Onboarding.kt, Tips.kt

    @Test func lesSujetsLesQuestionsLaPresentationEtLesConseils() throws {
        let v = try Self.vecteurs()
        let sousSection = TefilotRules.sousSection
        #expect(sousSection == v.tefilot.sousSection)
        let sujets = SujetTefila.allCases.map { [$0.cle, $0.titre] }
        let sujetsAttendus = v.tefilot.sujets.map { [$0.cle, $0.titre] }
        #expect(sujets == sujetsAttendus, "les dix sujets de Tefilot, dans l'ordre")
        let themes = Theme.allCases.map { [$0.cle, $0.titre] }
        let themesAttendus = v.themes.map { [$0.cle, $0.titre] }
        #expect(themes == themesAttendus, "les dix sujets de séance, dans l'ordre")
        let questions = QuestionsBlocage.questions
        #expect(questions == v.questions)

        let version = Onboarding.version
        #expect(version == v.onboarding.version)
        let durees = Onboarding.durees
        #expect(durees == v.onboarding.durees)
        #expect(Onboarding.ecrans.count == v.onboarding.ecrans.count)
        for (i, a) in v.onboarding.ecrans.enumerated() where i < Onboarding.ecrans.count {
            let e = Onboarding.ecrans[i]
            #expect(e.cle == a.cle, "écran \(i)")
            #expect(e.titre == a.titre, "\(a.cle)")
            #expect(e.corps == a.corps, "\(a.cle)")
            #expect(e.illustration == a.illustration, "\(a.cle)")
            #expect(e.choixAdresse == a.choixAdresse, "\(a.cle)")
            #expect(e.choixDuree == a.choixDuree, "\(a.cle)")
            #expect(e.choixRappel == a.choixRappel, "\(a.cle)")
        }

        #expect(Tips.all.count == v.tips.count)
        for (i, a) in v.tips.enumerated() where i < Tips.all.count {
            let t = Tips.all[i]
            #expect(t.number == a.number, "conseil \(i)")
            #expect(t.titleRes == a.titleRes, "conseil \(a.number)")
            #expect(t.bodyRes == a.bodyRes, "conseil \(a.number)")
            #expect(t.art == a.art, "conseil \(a.number)")
        }
    }

    // MARK: - YalkutYosef.kt, Halakha.kt

    @Test func lesFenetresDuYalkoutYossefEtLesParachiotJointes() throws {
        let v = try Self.vecteurs()
        let parJour = YalkutYosef.parJour
        #expect(parJour == v.yalkutYosef.parJour)
        for ligne in v.yalkutYosef.fenetres {
            for (i, attendue) in ligne.jours.enumerated() {
                let fenetre = YalkutYosef.fenetre(mois: ligne.mois, jour: i + 1, embolismique: ligne.embolismique)
                #expect(fenetre == attendue, "mois \(ligne.mois), jour \(i + 1), embolismique \(ligne.embolismique)")
            }
        }
        let jointes = Halakha.jointes
        #expect(jointes.count == v.halakhaJointes.count)
        for a in v.halakhaJointes {
            let parts = jointes[a.jointe]
            #expect(parts == a.parts, "\(a.jointe)")
        }
    }

    // MARK: - CalendrierJuif.kt, Zmanim.kt

    @Test func lesFetesLesConditionsEtLeProfilDesZmanim() throws {
        let v = try Self.vecteurs()
        let fetes = CalendrierJuif.fetes
        #expect(fetes.count == v.calendrier.fetes.count)
        for a in v.calendrier.fetes {
            let cle = fetes[a.index]
            #expect(cle == a.cle, "index de fête \(a.index)")
        }
        let toutes = CalendrierJuif.C.toutes
        #expect(toutes == v.calendrier.conditions)
        let derivees = CalendrierJuif.C.derivees
        #expect(derivees == v.calendrier.derivees)

        let profil = Zmanim.profil.map { [$0.cle, $0.methode.cle, $0.methode.parametres] }
        let profilAttendu = v.zmanim.profil.map { [$0.cle, $0.methode, $0.parametres] }
        #expect(profil == profilAttendu, "les quinze zmanim, dans l'ordre de la journée")
        let allumages = Zmanim.allumages
        #expect(allumages == v.zmanim.allumages)
        let defaut = Zmanim.allumageDefaut
        #expect(defaut == v.zmanim.allumageDefaut)
        for a in v.zmanim.methodesAllumage {
            let m = Zmanim.methodeAllumage(minutes: a.minutes)
            #expect(m.cle == a.methode, "\(a.minutes) min")
            #expect(m.parametres == a.parametres, "\(a.minutes) min")
        }
    }

    // MARK: - Reference.kt

    @Test func lesLivresCitesEtLesNombresEnLettres() throws {
        let v = try Self.vecteurs().reference
        for l in v.livres {
            let connue = Reference.connue(l.fr)
            #expect(connue == l.connue, "\(l.fr)")
            for (langue, attendu) in [("en", l.localiseEn), ("he", l.localiseHe), ("fr", l.localiseFr)] {
                let rendu = Array(Reference.localise(l.fr + "25", langue).utf16)
                let unites = Array(attendu.utf16)
                #expect(rendu == unites, "« \(l.fr)25 » en \(langue) : attendu « \(attendu) »")
            }
        }
        // De -1 à 1000.
        for (i, attendu) in v.lettres.enumerated() {
            let lettres = Array(Reference.lettres(i - 1).utf16)
            let unites = Array(attendu.utf16)
            #expect(lettres == unites, "\(i - 1) : attendu « \(attendu) »")
        }
        // Les nombres inversés, sans leurs guerchayim.
        for inv in v.inverses {
            let sans = Reference.lettres(inv.nombre).remplacantUnites("\u{05F4}", par: "")
            let egal = sans.egalUnites(inv.lettres)
            #expect(egal, "\(inv.nombre) : attendu « \(inv.lettres) »")
        }
    }

    // MARK: - SaisieVol.kt

    @Test func lesCompagniesEtLesTablesDeLaSaisieDUnVol() throws {
        let v = try Self.vecteurs().saisieVol
        let jour = try #require(JourCivil(iso: v.aujourdhui))
        #expect(SaisieVol.compagnies.count == v.compagnies.count)
        for (i, a) in v.compagnies.enumerated() where i < SaisieVol.compagnies.count {
            let c = SaisieVol.compagnies[i]
            let nom = Array(c.nom.utf16)
            let nomAttendu = Array(a.nom.utf16)
            #expect(nom == nomAttendu, "compagnie \(i) : attendu « \(a.nom) »")
            #expect(c.code == a.code, "\(a.nom)")
        }
        // Les tables privées de SaisieVol.swift, jugées par ce que lire() en tire.
        let essais = v.aeroportsEssai.map(Self.aeroport)
        for a in v.principal {
            let depart = SaisieVol.lire(a.ville, essais, jour).depart?.iata
            #expect(depart == a.depart, "ville principale « \(a.ville) »")
        }
        for a in v.mots {
            let depart = SaisieVol.lire(a.mot, [Self.aeroport(a.mot.uppercased())], jour).depart?.iata
            #expect(depart == a.depart, "mot courant « \(a.mot) »")
        }
        for a in v.mois {
            let date = SaisieVol.lire(a.texte, [], jour).date?.iso
            #expect(date == a.date, "« \(a.texte) »")
        }
        for a in v.jours {
            let date = SaisieVol.lire(a.texte, [], jour).date?.iso
            #expect(date == a.date, "« \(a.texte) »")
        }
        for a in v.vers + v.de {
            let p = SaisieVol.lire(a.texte, essais, jour)
            let depart = p.depart?.iata
            let arrivee = p.arrivee?.iata
            #expect(depart == a.depart, "« \(a.texte) »")
            #expect(arrivee == a.arrivee, "« \(a.texte) »")
        }
    }

    // MARK: - TerritoireIsrael.kt, DirectionJerusalem.kt

    @Test func leContourDIsraelEtLaCibleDeLaBoussole() throws {
        let v = try Self.vecteurs()
        let contour = TerritoireIsrael.contour
        #expect(contour == v.territoireIsrael, "les 45 points, dans l'ordre")
        let latitude = DirectionJerusalem.latitude
        #expect(latitude == v.directionJerusalem.latitude)
        let longitude = DirectionJerusalem.longitude
        #expect(longitude == v.directionJerusalem.longitude)
        let tolerance = DirectionJerusalem.tolerance
        let toleranceAttendue = Float(v.directionJerusalem.tolerance)
        #expect(tolerance == toleranceAttendue)
    }

    // MARK: - Character.kt (Poses), Personnage.kt

    @Test func lesPosesParMomentEtLeursCorrespondancesFeminines() throws {
        let v = try Self.vecteurs()
        let p = v.poses
        let constantes = [Poses.journal, Poses.study, Poses.reading, Poses.tehilim]
        let constantesAttendues = [p.journal, p.study, p.reading, p.tehilim]
        #expect(constantes == constantesAttendues)
        for a in p.moments {
            let moment = try #require(Moment(rawValue: a.moment), "moment \(a.moment)")
            let pose = Poses.ofMoment(moment)
            #expect(pose == a.pose, "\(a.moment)")
        }
        // Les réserves de Poses sont privées : la pose de chaque jour les révèle, rang par rang.
        for a in p.jours {
            let jour = try #require(JourCivil(iso: a.jour))
            let numero = jour.jourJulien - 2_440_588
            // Character.ofDay : le jour depuis 1970, plus sept fois le sel (1, 2, 3), modulo la réserve.
            let appel = p.appel[Kotlin.floorMod(numero + 7, p.appel.count)]
            let pendant = p.pendant[Kotlin.floorMod(numero + 14, p.pendant.count)]
            let joie = p.joie[Kotlin.floorMod(numero + 21, p.joie.count)]
            let call = Poses.call(jour)
            #expect(call == a.call, "\(a.jour)")
            #expect(call == appel, "\(a.jour) : la réserve d'appel")
            let during = Poses.during(jour)
            #expect(during == a.during, "\(a.jour)")
            #expect(during == pendant, "\(a.jour) : la réserve de séance")
            let joy = Poses.joy(jour)
            #expect(joy == a.joy, "\(a.jour)")
            #expect(joy == joie, "\(a.jour) : la réserve de joie")
            let fait = Poses.greeting(true, jour: jour)
            #expect(fait == a.greetingFait, "\(a.jour)")
            let accueil = Poses.greeting(false, jour: jour)
            #expect(accueil == a.greeting, "\(a.jour)")
        }
        // Huit jours de suite parcourent les trois réserves entières.
        let appels = Set(p.jours.map { $0.call })
        #expect(appels == Set(p.appel))
        let pendants = Set(p.jours.map { $0.during })
        #expect(pendants == Set(p.pendant))
        let joies = Set(p.jours.map { $0.joy })
        #expect(joies == Set(p.joie))

        let feminins = Personnage.feminins.map { [$0.hassid, $0.feminine] }
        let femininsAttendus = v.personnage.map { [$0.hassid, $0.feminine] }
        #expect(feminins == femininsAttendus, "les 21 correspondances, dans l'ordre")
        for a in v.personnage {
            let f = Personnage.feminin(a.hassid)
            #expect(f == a.feminine, "\(a.hassid)")
        }
    }

    // MARK: - PoliceHebraique.kt, MusiquePlay.kt

    @Test func lesSignesAbsentsDesPolicesEtLesMorceauxLivres() throws {
        let v = try Self.vecteurs()
        #expect(PoliceHebraique.Police.allCases.count == v.polices.count)
        for (i, a) in v.polices.enumerated() where i < PoliceHebraique.Police.allCases.count {
            let police = PoliceHebraique.Police.allCases[i]
            #expect(police.cle == a.cle, "police \(i)")
            #expect(police.libelle == a.libelle, "\(a.cle)")
            let absents = PoliceHebraique.absents(police).map { Self.hexadecimal($0) }
            #expect(absents == a.absents, "\(a.cle) : les signes masqués")
        }

        #expect(MusiquePlay.morceaux.count == v.musique.count)
        for (i, a) in v.musique.enumerated() where i < MusiquePlay.morceaux.count {
            let m = MusiquePlay.morceaux[i]
            #expect(m.id == a.id, "morceau \(i)")
            #expect(m.rawRes == a.rawRes, "\(a.id)")
            #expect(m.titleRes == a.titleRes, "\(a.id)")
        }
    }

    // MARK: - Aides

    /// L'aéroport d'essai du générateur : seul son code compte, sa ville ne ressemble à aucun mot sondé.
    private static func aeroport(_ iata: String) -> Vol.Aeroport {
        Vol.Aeroport(iata: iata, nom: "Essai " + iata, ville: "zz" + iata.lowercased(), pays: "ZZ",
                     latitude: 0, longitude: 0, fuseau: "UTC")
    }

    /// Les unités UTF-16 d'une chaîne, « 05BD », comme le générateur les écrit.
    private static func hexadecimal(_ texte: String) -> [String] {
        texte.utf16.map { unite in
            let chiffres = String(unite, radix: 16, uppercase: true)
            return String(repeating: "0", count: max(0, 4 - chiffres.count)) + chiffres
        }
    }

    private static func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/tables.json"))
    }

    // MARK: - tables.json

    private struct Vecteurs: Decodable {
        let comptes: [String: Int]
        let hitbodedut: HitbodedutV
        let paliers: [PisteV]
        let trophees: TropheesV
        let tehilim: TehilimV
        let tikkun: TikkunV
        let tefilot: TefilotV
        let themes: [SujetV]
        let questions: [String]
        let onboarding: OnboardingV
        let tips: [TipV]
        let yalkutYosef: YalkutV
        let halakhaJointes: [JointeV]
        let calendrier: CalendrierV
        let zmanim: ZmanimV
        let reference: ReferenceV
        let saisieVol: SaisieVolV
        let territoireIsrael: [[Double]]
        let directionJerusalem: DirectionV
        let poses: PosesV
        let personnage: [FeminineV]
        let polices: [PoliceV]
        let musique: [MorceauV]
    }

    private struct HitbodedutV: Decodable {
        struct MouvementV: Decodable {
            let cle: String
            let he: String
            let titre: String
            let invite: String
            let illustration: String
            let source: String
        }
        let sourceLikoutei: String
        let sourceRambam: String
        let mouvements: [MouvementV]
    }

    private struct PisteV: Decodable {
        let nom: String
        let cle: String
        let base: [Int]
        let pas: Int
    }

    private struct TropheesV: Decodable {
        struct FormeV: Decodable {
            let nom: String
            let cle: String
        }
        struct FamilleV: Decodable {
            let nom: String
            let cle: String
            let icone: String
            let forme: String
            let seuils: [Int]
            let metaux: [String]
            let couts: [Double]
        }
        let metaux: [String]
        let formes: [FormeV]
        let familles: [FamilleV]
        let chemin: [String]
        let seuilsGrades: [Int]
    }

    private struct PortionV: Decodable {
        let debut: Int
        let fin: Int
        let debutVerset: Int
        let finVerset: Int?
    }

    private struct TehilimV: Decodable {
        let psaumes: Int
        let mois: [PortionV]
        let semaine: [PortionV]
    }

    private struct TikkunV: Decodable {
        let ordre: [Int]
        let blocs: [String]
    }

    private struct SujetV: Decodable {
        let nom: String
        let cle: String
        let titre: String
    }

    private struct TefilotV: Decodable {
        let sousSection: String
        let sujets: [SujetV]
    }

    private struct OnboardingV: Decodable {
        struct EcranV: Decodable {
            let cle: String
            let titre: String
            let corps: String
            let illustration: String
            let choixAdresse: Bool
            let choixDuree: Bool
            let choixRappel: Bool
        }
        let version: Int
        let durees: [Int]
        let ecrans: [EcranV]
    }

    private struct TipV: Decodable {
        let number: Int
        let titleRes: String
        let bodyRes: String
        let art: String
    }

    private struct YalkutV: Decodable {
        struct FenetreV: Decodable {
            let embolismique: Bool
            let mois: Int
            let jours: [String?]
        }
        let parJour: Int
        let fenetres: [FenetreV]
    }

    private struct JointeV: Decodable {
        let jointe: String
        let parts: [String]
    }

    private struct CalendrierV: Decodable {
        struct FeteV: Decodable {
            let index: Int
            let cle: String
        }
        let fetes: [FeteV]
        let conditions: [String]
        let derivees: [String]
    }

    private struct ZmanimV: Decodable {
        struct ProfilV: Decodable {
            let cle: String
            let methode: String
            let parametres: String
        }
        struct AllumageV: Decodable {
            let minutes: Int
            let methode: String
            let parametres: String
        }
        let profil: [ProfilV]
        let allumages: [Int]
        let allumageDefaut: Int
        let methodesAllumage: [AllumageV]
    }

    private struct ReferenceV: Decodable {
        struct LivreV: Decodable {
            let fr: String
            let en: String
            let he: String
            let connue: Bool
            let localiseEn: String
            let localiseHe: String
            let localiseFr: String
        }
        struct InverseV: Decodable {
            let nombre: Int
            let lettres: String
        }
        let livres: [LivreV]
        let inverses: [InverseV]
        let lettres: [String]
    }

    private struct SaisieVolV: Decodable {
        struct CompagnieV: Decodable {
            let nom: String
            let code: String
        }
        struct PrincipalV: Decodable {
            let ville: String
            let iata: String
            let depart: String?
        }
        struct MotV: Decodable {
            let mot: String
            let depart: String?
        }
        struct MoisV: Decodable {
            let nom: String
            let mois: Int
            let texte: String
            let date: String?
        }
        struct JourV: Decodable {
            let nom: String
            let jour: String
            let texte: String
            let date: String?
        }
        struct SensV: Decodable {
            let mot: String
            let texte: String
            let depart: String?
            let arrivee: String?
        }
        let aujourdhui: String
        let compagnies: [CompagnieV]
        let principal: [PrincipalV]
        let aeroportsEssai: [String]
        let mots: [MotV]
        let mois: [MoisV]
        let jours: [JourV]
        let vers: [SensV]
        let de: [SensV]
    }

    private struct DirectionV: Decodable {
        let latitude: Double
        let longitude: Double
        let tolerance: Double
    }

    private struct PosesV: Decodable {
        struct MomentV: Decodable {
            let moment: String
            let pose: String
        }
        struct JourV: Decodable {
            let jour: String
            let call: String
            let during: String
            let joy: String
            let greetingFait: String
            let greeting: String
        }
        let appel: [String]
        let pendant: [String]
        let joie: [String]
        let journal: String
        let study: String
        let reading: String
        let tehilim: String
        let moments: [MomentV]
        let jours: [JourV]
    }

    private struct FeminineV: Decodable {
        let hassid: String
        let feminine: String
    }

    private struct PoliceV: Decodable {
        let nom: String
        let cle: String
        let libelle: String
        let absents: [String]?
    }

    private struct MorceauV: Decodable {
        let id: String
        let rawRes: String
        let titleRes: String
    }
}
