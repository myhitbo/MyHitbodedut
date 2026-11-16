import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran des trophées et des paliers (PaliersActivity.kt) : ce qu'il montre pour un journal forgé, ce que
/// font ses actions, ce qu'il retient comme vu. Les règles des trophées sont jugées dans CoeurTests ; ici,
/// l'écran qui s'en sert. Restent au test d'interface : le défilement jusqu'à « Vous êtes ici », les
/// animations, l'image partagée et la feuille de partage.
@Suite("Modèle de l'écran des paliers")
@MainActor
struct PaliersModeleTests {

    // MARK: Un journal forgé

    static let aujourdhui = "2026-11-16"

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    static func journal(_ seances: [(String, Int)]) throws -> Journal {
        var j = Journal()
        for (iso, minutes) in seances {
            let date = try jour(iso)
            j.addSession(minutes: minutes, date: date)
        }
        return j
    }

    /// Dix jours d'affilée, du jeudi 1ᵉʳ au samedi 10 octobre 2026, trente minutes chacun.
    static func dixJours() throws -> Journal {
        try journal((1...10).map { n in ("2026-10-" + (n < 10 ? "0" : "") + String(n), 30) })
    }

    static func horloge(_ iso: String = aujourdhui) throws -> HorlogeFixe {
        let date = try jour(iso)
        return HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc)
    }

    /// Ce que regardent les trophées, à midi d'aujourd'hui, en UTC.
    static func pratique(_ journal: Journal, _ reglages: Reglages = Reglages()) throws -> Trophees.Pratique {
        let date = try jour(aujourdhui)
        return Store.pratique(journal: journal, reglages: reglages, aujourdhui: date, fuseauTelephone: "UTC")
    }

    static func cles(_ p: Trophees.Pratique) -> Set<String> {
        var resultat = Set<String>()
        for n in Trophees.gagnes(p) { resultat.insert(n.cle) }
        return resultat
    }

    private func fabriquer(_ journal: Journal, _ reglages: Reglages = Reglages())
        throws -> (PaliersModele, Magasin, PersistanceEnMemoire) {
        let enregistrement = Enregistrement(journal: journal, reglages: reglages)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        return (PaliersModele(magasin: magasin, horloge: try Self.horloge()), magasin, persistance)
    }

    private func etapes(_ lignes: [PaliersLigne]) -> [PaliersEtape] {
        var resultat: [PaliersEtape] = []
        for l in lignes {
            if case .etape(let e) = l { resultat.append(e) }
        }
        return resultat
    }

    private func bannieres(_ lignes: [PaliersLigne]) -> [PaliersBanniere] {
        var resultat: [PaliersBanniere] = []
        for l in lignes {
            if case .banniere(let b) = l { resultat.append(b) }
        }
        return resultat
    }

    private func ici(_ lignes: [PaliersLigne]) -> PaliersIci? {
        for l in lignes {
            if case .ici(let i) = l { return i }
        }
        return nil
    }

    // MARK: Sans trophée

    @Test func unJournalVideMontreLePremierObjectifEtLesQuinzeSuivants() throws {
        let (modele, _, _) = try fabriquer(Journal())
        let tete = modele.enTete
        #expect(tete.grade == .bronze)
        #expect(tete.compte == 0)
        #expect(tete.titre == Libelle("grade_titre", .libelle(Libelle("metal_bronze"))))
        #expect(tete.sous == Libelle("grade_sous", .entier(0), .entier(10), .libelle(Libelle("metal_argent"))))
        #expect(tete.barre == 0)
        #expect(tete.partager == nil)
        #expect(modele.partage == nil)
        // Les plus proches, sans le prochain : à égalité (rien de commencé), les plus faciles.
        let proches = tete.proches.map { $0.niveau.cle }
        #expect(proches == ["plume:1", "premier_pas:2", "tikkun:1"])
        #expect(tete.prochesTitre == Libelle("trophees_proches_titre"))
        let premierProche = try #require(tete.proches.first)
        #expect(premierProche.progres == Libelle("trophee_progres", .entier(0), .entier(1)))
        #expect(premierProche.description == Libelle.pluriel("trophee_plume_desc", quantite: 1, .entier(1)))

        // La ligne : « Vous êtes ici » d'abord (aucun gagné), puis quinze à venir, la bannière de l'argent au
        // 10ᵉ, et le compte des autres.
        let lignes = modele.lignes
        let premiere = try #require(lignes.first)
        let objectif = try #require(ici(lignes))
        #expect(premiere == .ici(objectif))
        #expect(objectif.niveau == Trophees.Niveau(famille: .premierPas, rang: 1))
        #expect(objectif.encore == Libelle("trophee_encore", .entier(0), .entier(1), .entier(1)))
        #expect(objectif.fraction == 0)
        #expect(!objectif.pulser)
        let aVenir = etapes(lignes)
        #expect(aVenir.count == PaliersModele.montres)
        let attendus = Array(Trophees.chemin.dropFirst().prefix(15))
        let niveaux = aVenir.map { $0.niveau }
        #expect(niveaux == attendus)
        for e in aVenir {
            #expect(!e.gagne && e.metal == nil && e.sous == nil && e.retardPousse == nil, "\(e.niveau.cle)")
        }
        let indexBanniere = try #require(lignes.firstIndex(of: .banniere(PaliersBanniere(grade: .argent, rang: 10,
                                                                                        atteint: false))))
        // Le futur de rang 10 est le 9ᵉ de la liste (le rang 1 est « Vous êtes ici »).
        #expect(lignes[indexBanniere + 1] == .etape(aVenir[8]))
        let total = Trophees.chemin.count
        #expect(total == 128)
        #expect(lignes.last == .autres(Libelle("trophees_autres", .entier(total - 1 - 15))))
        #expect(lignes.count == 1 + 15 + 1 + 1)
        let ids = Set(lignes.map { $0.id })
        #expect(ids.count == lignes.count)

        // Les records, à zéro.
        #expect(modele.records == PaliersRecords(titre: Libelle("paliers_records"), lignes: [
            Libelle("record_serie", .libelle(Libelle.pluriel("palier_n_jours", quantite: 0, .entier(0)))),
            Libelle("record_jour", .libelle(Libelle("duration_minutes", .entier(0)))),
            Libelle("record_semaine", .libelle(Libelle("duration_minutes", .entier(0)))),
            Libelle("record_mois", .libelle(Libelle("duration_minutes", .entier(0)))),
        ]))
    }

    // MARK: Les gagnés

    @Test func lesGagnesPortentLeMetalDeLeurGradeEtLeurJour() throws {
        let j = try Self.dixJours()
        let (modele, _, _) = try fabriquer(j)
        let p = try Self.pratique(j)
        let faits = Trophees.chemin.filter { Trophees.gagne(p, $0) }
        let n = faits.count
        try #require(n >= 10 && n < 25)
        let lignes = modele.lignes
        let gagnees = etapes(lignes).filter { $0.gagne }
        let niveaux = gagnees.map { $0.niveau }
        #expect(niveaux == faits)
        for (i, e) in gagnees.enumerated() {
            #expect(e.metal == Trophees.grade(i + 1), "\(e.niveau.cle)")
        }
        let premier = try #require(gagnees.first)
        #expect(premier.niveau == Trophees.Niveau(famille: .premierPas, rang: 1))
        let premierJour = try Self.jour("2026-10-01")
        #expect(premier.sous == .gagneLe(premierJour))
        #expect(premier.coteObjet == 52)
        #expect(premier.opaciteObjet == 1)
        let accessibilite = premier.accessibilite { $0.iso }
        #expect(accessibilite == [Libelle.pluriel("trophee_premier_pas_desc", quantite: 1, .entier(1)),
                                  Libelle("trophee_gagne_le", .texte("2026-10-01"))])
        // La bannière de l'argent précède le 10ᵉ ; celle de l'or attend plus bas.
        let argent = try #require(lignes.firstIndex(of: .banniere(PaliersBanniere(grade: .argent, rang: 10, atteint: true))))
        #expect(lignes[argent + 1] == .etape(gagnees[9]))
        let or = lignes.contains(.banniere(PaliersBanniere(grade: .or, rang: 25, atteint: false)))
        #expect(or)
        let titreArgent = PaliersBanniere(grade: .argent, rang: 10, atteint: true)
        #expect(titreArgent.titre == Libelle("grade_atteint", .libelle(Libelle("metal_argent"))))
        #expect(titreArgent.sous == Libelle("grade_au", .entier(10)))
        #expect(titreArgent.medaille == .argent)
        #expect(titreArgent.encre == PaliersBanniere.encreAtteinte)
        let aVenirOr = PaliersBanniere(grade: .or, rang: 25, atteint: false)
        #expect(aVenirOr.titre == Libelle("grade_titre", .libelle(Libelle("metal_or"))))
        #expect(aVenirOr.medaille == nil && aVenirOr.degrade == nil && aVenirOr.encre == nil)
        // L'en-tête : l'argent, la barre depuis 10 vers 25.
        let tete = modele.enTete
        #expect(tete.grade == .argent)
        #expect(tete.barre == Float(n - 10) / Float(15))
        #expect(tete.sous == Libelle("grade_sous", .entier(n), .entier(25 - n), .libelle(Libelle("metal_or"))))
        #expect(tete.couleurBarre == TropheeTeintes.de(.argent).fonce)
        // Le prochain n'est jamais parmi les plus proches.
        let prochain = try #require(ici(lignes)).niveau
        let prochesCles = tete.proches.map { $0.niveau }
        #expect(!prochesCles.contains(prochain))
        #expect(tete.proches.count <= 3)
    }

    // MARK: L'ouverture

    @Test func laPremiereOuvertureNeFeteRienEtRetientLeVu() async throws {
        let j = try Self.dixJours()
        let (modele, _, persistance) = try fabriquer(j)
        try await modele.ouvrir()
        #expect(modele.neufs.isEmpty)
        #expect(modele.feteGrade == nil)
        #expect(modele.animer)
        let gagnees = etapes(modele.lignes).filter { $0.gagne }
        for e in gagnees {
            #expect(!e.neuf && e.retardRetournement == nil, "\(e.niveau.cle)")
        }
        // La ligne se remplit : les six dernières étapes une à une, 90 ms d'écart.
        let pousses = gagnees.map { $0.retardPousse }
        let n = gagnees.count
        #expect(pousses.first == 0)
        #expect(pousses.last == 450)
        #expect(pousses[n - 6] == 0)
        #expect(pousses[n - 5] == 90)
        let reglages = await persistance.enregistrement.reglages
        let p = try Self.pratique(j)
        #expect(reglages.gradeVu == 2)
        #expect(reglages.tropheesVus == Self.cles(p))
        let paliersVus = reglages.paliersVus
        #expect(paliersVus != nil)
    }

    @Test func leBronzeNeSeFetePas() async throws {
        let j = try Self.journal([("2026-11-02", 5)])
        var r = Reglages()
        r.setGradeVu(0)
        let (modele, _, persistance) = try fabriquer(j, r)
        try await modele.ouvrir()
        #expect(modele.feteGrade == nil)
        let vu = await persistance.enregistrement.reglages.gradeVu
        #expect(vu == 1)
    }

    @Test func unTropheeNeufSeRetourneEtUnNouveauGradeSeFeteUneFois() async throws {
        // Hier, deux jours ; aujourd'hui, dix : le grade passe du bronze à l'argent.
        let avant = try Self.pratique(Self.journal([("2026-10-01", 30), ("2026-10-02", 30)]))
        let vusAvant = Self.cles(avant)
        try #require(vusAvant.count > 0 && vusAvant.count < 10)
        var r = Reglages()
        r.setGradeVu(1)
        r.setTropheesVus(vusAvant)
        let j = try Self.dixJours()
        let p = try Self.pratique(j)
        let n = Self.cles(p).count
        try #require(n >= 10 && n < 25)
        let (modele, _, persistance) = try fabriquer(j, r)
        try await modele.ouvrir()
        let attendus = Self.cles(p).subtracting(vusAvant)
        #expect(modele.neufs == attendus)
        let neuves = etapes(modele.lignes).filter { $0.neuf }
        #expect(neuves.count == attendus.count)
        for (i, e) in neuves.enumerated() {
            #expect(e.retardRetournement == 400 + i * 120, "\(e.niveau.cle)")
        }
        let fete = try #require(modele.feteGrade)
        #expect(fete == PaliersFeteGrade(grade: .argent, compte: n))
        #expect(fete.ancien == .bronze)
        #expect(fete.titre == Libelle("grade_nouveau", .libelle(Libelle("metal_argent"))))
        #expect(fete.sous == Libelle("grade_sous_max", .entier(n)))
        #expect(fete.prochain == Libelle("grade_prochain", .libelle(Libelle("metal_or")), .entier(25)))
        #expect(fete.rayons == TropheeTeintes.de(.argent).clair.opacite(0x70))
        modele.fermerFeteGrade()
        #expect(modele.feteGrade == nil)

        // Une autre ouverture ne refête ni le grade ni les trophées.
        let enregistrement = await persistance.enregistrement
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let encore = PaliersModele(magasin: magasin, horloge: try Self.horloge())
        try await encore.ouvrir()
        #expect(encore.feteGrade == nil)
        #expect(encore.neufs.isEmpty)
    }

    @Test func leDernierGradeNAnnonceRienApres() {
        let fete = PaliersFeteGrade(grade: .platine, compte: 60)
        #expect(fete.prochain == nil)
        #expect(fete.ancien == .or)
        let premiere = PaliersFeteGrade(grade: .bronze, compte: 1)
        #expect(premiere.ancien == .bronze)
    }

    // MARK: Le filtre

    @Test func leFiltreNeMontreQueSaFamilleSansBanniereNiAnimation() async throws {
        let j = try Self.dixJours()
        let (modele, _, _) = try fabriquer(j)
        try await modele.ouvrir()
        modele.choisirFiltre(.jours)
        #expect(modele.filtreCle == "jours")
        #expect(!modele.animer)
        #expect(modele.neufs.isEmpty)
        let lignes = modele.lignes
        #expect(bannieres(lignes).isEmpty)
        let toutes = etapes(lignes)
        let gagnees = toutes.filter { $0.gagne }
        let niveaux = gagnees.map { $0.niveau.cle }
        #expect(niveaux == ["jours:1", "jours:2"])
        let septieme = try Self.jour("2026-10-07")
        let dixieme = try Self.jour("2026-10-10")
        let sous = gagnees.map { $0.sous }
        #expect(sous == [.gagneLe(septieme), .gagneLe(dixieme)])
        for e in toutes {
            #expect(e.retardPousse == nil && e.retardRetournement == nil, "\(e.niveau.cle)")
            #expect(e.niveau.famille == .jours)
        }
        let objectif = try #require(ici(lignes))
        #expect(objectif.niveau == Trophees.Niveau(famille: .jours, rang: 3))
        #expect(objectif.valeur == 10)
        #expect(objectif.seuil == 15)
        #expect(objectif.encore == Libelle("trophee_encore", .entier(10), .entier(15), .entier(5)))
        #expect(objectif.encore(4) == Libelle("trophee_encore", .entier(4), .entier(15), .entier(11)))
        #expect(!objectif.pulser)
        let aVenir = toutes.filter { !$0.gagne }
        #expect(aVenir.count == 15)
        let suivant = try #require(aVenir.first)
        #expect(suivant.niveau == Trophees.Niveau(famille: .jours, rang: 4))
        #expect(suivant.sous == .progres(valeur: 10, seuil: 18))
        #expect(suivant.opaciteObjet == 0.8)
        #expect(suivant.coteObjet == 44)
        #expect(lignes.last == .autres(Libelle("trophees_autres", .entier(24 - 3 - 15))))

        // Les puces : « Tous » puis les onze familles ; seule celle des jours est choisie.
        let filtres = modele.filtres
        #expect(filtres.count == 12)
        let choisis = filtres.filter { $0.choisi }.map { $0.id }
        #expect(choisis == ["jours"])
        let tous = try #require(filtres.first)
        #expect(tous.famille == nil)
        #expect(tous.titre == Libelle("trophees_filtre_tous"))
        #expect(tous.accessibilite == Libelle("trophees_filtre", .libelle(Libelle("trophees_filtre_tous"))))
        #expect(filtres[4].titre == Libelle("trophee_serie"))

        // Retour à tous : les bannières reviennent, toujours sans animation.
        modele.choisirFiltre(nil)
        let encore = modele.lignes
        #expect(!bannieres(encore).isEmpty)
        #expect(modele.filtreCle == nil)
    }

    @Test func leFiltreGardeSeRetrouve() throws {
        #expect(PaliersModele.famille(cle: "jours") == .jours)
        #expect(PaliersModele.famille(cle: "tikkun_serie") == .tikkunSerie)
        #expect(PaliersModele.famille(cle: "inconnue") == nil)
        #expect(PaliersModele.famille(cle: nil) == nil)
        let magasin = Magasin.enMemoire()
        let modele = PaliersModele(magasin: magasin, horloge: try Self.horloge(), filtre: .serie)
        #expect(modele.filtreCle == "serie")
        let choisis = modele.filtres.filter { $0.choisi }.map { $0.id }
        #expect(choisis == ["serie"])
    }

    // MARK: Records, partage, fiche

    @Test func lesRecordsEtLePartage() throws {
        // Dimanche 1ᵉʳ et lundi 2 novembre, puis lundi 9 : tous en 'Hechvan 5787.
        let j = try Self.journal([("2026-11-01", 20), ("2026-11-02", 45), ("2026-11-09", 70)])
        let (modele, _, _) = try fabriquer(j)
        #expect(modele.records.lignes == [
            Libelle("record_serie", .libelle(Libelle.pluriel("palier_n_jours", quantite: 2, .entier(2)))),
            Libelle("record_jour", .libelle(Libelle("duration_hours_minutes", .entier(1), .entier(10)))),
            Libelle("record_semaine", .libelle(Libelle("duration_hours_minutes", .entier(1), .entier(10)))),
            Libelle("record_mois", .libelle(Libelle("duration_hours_minutes", .entier(2), .entier(15)))),
        ])
        let n = Self.cles(try Self.pratique(j)).count
        try #require(n > 0)
        let partage = try #require(modele.partage)
        #expect(partage == PaliersPartage(grade: Trophees.grade(n), compte: n))
        #expect(partage.texte == Libelle("grade_partage_texte", .libelle(TropheeTextes.metal(Trophees.grade(n))),
                                         .entier(n)))
        #expect(partage.titreChoix == Libelle("grade_partager"))
        #expect(partage.titreImage == Libelle("grade_titre", .libelle(TropheeTextes.metal(Trophees.grade(n)))))
        #expect(partage.sousImage == Libelle("grade_sous_max", .entier(n)))
        #expect(partage.marque == Libelle("app_name"))
        #expect(modele.enTete.partager == Libelle("grade_partager"))
    }

    @Test func uneFicheDitLeJourGagneOuCeQuIlReste() throws {
        let j = try Self.dixJours()
        let (modele, _, _) = try fabriquer(j)
        let p = try Self.pratique(j)
        let faits = Trophees.chemin.filter { Trophees.gagne(p, $0) }
        let sept = Trophees.Niveau(famille: .jours, rang: 1)
        let rang = try #require(faits.firstIndex(of: sept)) + 1
        modele.ouvrirFiche(sept)
        let fiche = try #require(modele.fiche)
        #expect(fiche.gagne && fiche.retourner && !fiche.feter && !fiche.confettis)
        #expect(fiche.rangGlobal == rang)
        #expect(fiche.metal == Trophees.grade(rang))
        let septieme = try Self.jour("2026-10-07")
        #expect(fiche.etat == .gagne(sous: .gagneLe(septieme),
                                     grade: Libelle("trophee_detail_grade", .libelle(TropheeTextes.metal(Trophees.grade(rang))),
                                                    .entier(rang))))
        #expect(fiche.titre == Libelle.pluriel("trophee_jours_desc", quantite: 7, .entier(7)))
        #expect(fiche.nom == Libelle("trophee_jours"))
        #expect(fiche.niveauCourt == Libelle("trophee_niveau_court", .entier(1), .entier(24)))

        let quinze = Trophees.Niveau(famille: .jours, rang: 3)
        modele.ouvrirFiche(quinze)
        let aGagner = try #require(modele.fiche)
        #expect(!aGagner.gagne && !aGagner.retourner)
        #expect(aGagner.metal == nil)
        #expect(aGagner.rangGlobal == faits.count + 1)
        #expect(aGagner.etat == .aGagner(fraction: Trophees.fraction(p, quinze),
                                         encore: Libelle("trophee_encore", .entier(10), .entier(15), .entier(5))))
        modele.fermerFiche()
        #expect(modele.fiche == nil)
    }

    @Test func leBandeauMontreLePersonnageChoisi() throws {
        let (modele, _, _) = try fabriquer(Journal())
        #expect(modele.imageBandeau == "char_open_arms")
        var r = Reglages()
        r.setAdresse("f")
        let (feminin, _, _) = try fabriquer(Journal(), r)
        #expect(feminin.imageBandeau == "char_f_arms_up")
    }

    // MARK: Les chaînes

    /// La clé d'un libellé et celles qu'il contient.
    private static func cles(_ l: Libelle) -> [String] {
        var resultat = [l.cle]
        for argument in l.arguments {
            if case .libelle(let interieur) = argument { resultat += cles(interieur) }
        }
        return resultat
    }

    @Test func chaqueTexteDeLEcranEstAuCatalogueDansLesTroisLangues() async throws {
        let j = try Self.dixJours()
        let (modele, _, _) = try fabriquer(j)
        try await modele.ouvrir()
        var libelles: [Libelle] = [PaliersModele.titre, PaliersIci.titre, TropheeFiche.bouton]
        let tete = modele.enTete
        libelles += [tete.titre, tete.sous]
        if let t = tete.prochesTitre { libelles.append(t) }
        if let t = tete.partager { libelles.append(t) }
        for proche in tete.proches { libelles += proche.accessibilite }
        for filtre in modele.filtres { libelles += [filtre.titre, filtre.accessibilite] }
        for ligne in modele.lignes {
            switch ligne {
            case .banniere(let b): libelles += [b.titre, b.sous]
            case .etape(let e): libelles += e.accessibilite { $0.iso }
            case .ici(let i): libelles += [i.description, i.encore]
            case .tousGagnes(let l), .autres(let l): libelles.append(l)
            }
        }
        libelles += modele.records.lignes + [modele.records.titre]
        let fete = PaliersFeteGrade(grade: .argent, compte: 12)
        libelles += [fete.titre, fete.sous, fete.bouton]
        if let prochain = fete.prochain { libelles.append(prochain) }
        if let partage = modele.partage {
            libelles += [partage.texte, partage.titreChoix, partage.titreImage, partage.sousImage, partage.marque]
        }
        modele.ouvrirFiche(Trophees.Niveau(famille: .jours, rang: 1))
        if let fiche = modele.fiche {
            libelles += fiche.accessibilite
            if case .gagne(let sous, let grade) = fiche.etat { libelles += [sous.libelle { $0.iso }, grade] }
        }
        libelles += [TropheeSous.gagne.libelle { $0.iso }, Libelle("trophees_tous")]
        for f in Trophees.Famille.allCases {
            libelles += [TropheeTextes.nom(f), TropheeTextes.description(f, seuil: f.seuils[0])]
        }
        for m in Trophees.Metal.allCases { libelles.append(TropheeTextes.metal(m)) }
        for piste in Paliers.Piste.allCases { libelles.append(TropheeTextes.valeurPalier(piste, 75)) }

        let catalogue = try CatalogueBrut.lire()
        var toutes = Set<String>()
        for l in libelles { toutes.formUnion(Self.cles(l)) }
        for cle in toutes.sorted() {
            for langue in Traducteur.langues {
                let simple = catalogue.valeur(cle, langue: langue)
                let pluriel = catalogue.forme(cle, "other", langue: langue)
                #expect(simple != nil || pluriel != nil, "« \(cle) » manque en \(langue)")
            }
        }
    }

    @Test func lesTextesSeLisentCommeSurAndroid() throws {
        let fr = try Traducteur(catalogue: Fichiers.catalogue(), langue: "fr")
        let banniere = PaliersBanniere(grade: .argent, rang: 10, atteint: true)
        #expect(fr.texte(banniere.titre) == "Grade Argent atteint")
        #expect(fr.texte(banniere.sous) == "au 10ᵉ trophée")
        let (modele, _, _) = try fabriquer(Journal())
        #expect(fr.texte(modele.enTete.sous) == "0 trophées gagnés · encore 10 pour Argent")
        let en = try Traducteur(catalogue: Fichiers.catalogue(), langue: "en")
        let partage = PaliersPartage(grade: .or, compte: 30)
        #expect(en.texte(partage.texte) == "Gold grade on MyHitbodedut: 30 trophies, day after day.")
        #expect(en.texte(TropheeTextes.description(.serie, seuil: 7)) == "7 days in a row")
    }
}
