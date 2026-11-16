import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La lecture des Tehilim (TehilimLectureActivity.kt) : ce qu'on ouvre (DEBUT, FIN, DEBUT_VERSET, FIN_VERSET,
/// MARQUE_VERSET), le bandeau, les versets dans les langues choisies, précédent et suivant, les marque-pages posés
/// d'un appui long, le bouton de lecture ; et le critère de la feuille de route (tâche 22) : la portion du jour se
/// lit, un marque-page posé sur un verset se retrouve depuis le livre et rouvre ce verset. Sur le livre exporté.
///
/// Restent au test d'interface : l'appui long réel, le défilement jusqu'au verset à l'écran, le message bref
/// (Toast) qui s'efface, la pastille qui s'efface au défilement, les couleurs de nuit, les tailles de lettres.
@Suite("Modèle de la lecture des Tehilim")
@MainActor
struct TehilimLectureModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private static func lecture(_ cible: TehilimLectureCible, langue: String = "fr", magasin: Magasin? = nil)
        async -> TehilimLectureModele {
        let modele = TehilimLectureModele(magasin: magasin ?? Magasin.enMemoire(), contenus: contenus, langue: langue,
                                          cible: cible)
        await modele.charger()
        return modele
    }

    private static func traducteur(_ langue: String) throws -> Traducteur {
        try Traducteur(catalogue: Fichiers.catalogue(), langue: langue)
    }

    // MARK: Ce qu'on ouvre

    @Test func lesExtrasSontRamenesDansLeLivre() {
        let defaut = TehilimLectureCible().portion
        #expect(defaut == Portion(1, 1))
        let hors = TehilimLectureCible(debut: 0, fin: 200).portion
        #expect(hors == Portion(1, 150))
        let partielle = TehilimLectureCible(debut: 119, fin: 119, debutVerset: 97, finVerset: 176).portion
        #expect(partielle == Portion(119, 119, 97, 176))
        let jusquAuBout = TehilimLectureCible(debut: 119, fin: 119, debutVerset: 97, finVerset: 0).portion
        #expect(jusquAuBout == Portion(119, 119, 97, nil))
        let marque = TehilimLectureCible.marque(psaume: 23, verset: 4)
        #expect(marque == TehilimLectureCible(debut: 23, fin: 23, debutVerset: 1, finVerset: 0, marqueVerset: 4))
        let portion = TehilimLectureCible.portion(Portion(119, 119, 1, 96))
        #expect(portion == TehilimLectureCible(debut: 119, fin: 119, debutVerset: 1, finVerset: 96))
    }

    // MARK: Un psaume seul

    @Test func unPsaumeSeulSeLitAvecSaTraductionEtSesDeuxBoutons() async throws {
        let modele = await Self.lecture(.portion(Portion(23, 23)))
        #expect(modele.etat == .pret)
        #expect(modele.titre == Libelle("tehilim_single", .texte("23")))
        #expect(modele.sousTitre == Libelle.pluriel("tehilim_verses", quantite: 6, .entier(6)))
        let sousTitre = try #require(modele.sousTitre)
        let texte = try Self.traducteur("fr").texte(sousTitre)
        #expect(texte == "6 versets")

        let psaumes = modele.psaumes
        #expect(psaumes.count == 1)
        let psaume = try #require(psaumes.first)
        #expect(psaume.id == "p:23")
        #expect(psaume.premier)
        #expect(psaume.titre == Libelle("tikkun_psalm_he", .texte(Reference.lettres(23))))
        let ids = psaume.versets.map { $0.id }
        #expect(ids == ["v:23:1", "v:23:2", "v:23:3", "v:23:4", "v:23:5", "v:23:6"])

        // En français, par défaut : l'hébreu, puis la traduction française.
        #expect(!modele.hebreuSeul)
        let premier = try #require(psaume.versets.first)
        let livre = try await Self.contenus.tehilim()
        #expect(premier.numero == Reference.lettres(1))
        #expect(premier.hebreu == PoliceHebraique.masque(livre.versets(23)[0], police: .serif))
        #expect(premier.numeroLatin == nil)
        let langues = premier.traductions.map { $0.langue }
        #expect(langues == ["fr"])
        #expect(premier.traductions.first?.texte == livre.traduction("fr", 23, 1))
        #expect(!premier.marque)

        #expect(modele.navigationVisible)
        #expect(modele.precedentVisible)
        #expect(modele.suivantVisible)
    }

    @Test func enHebreuUnSeulBlocSansTraduction() async throws {
        let modele = await Self.lecture(.portion(Portion(23, 23)), langue: "he")
        #expect(modele.hebreuSeul)
        let versets = try #require(modele.psaumes.first).versets
        let traduits = versets.filter { !$0.traductions.isEmpty }.count
        #expect(traduits == 0)
        let sansHebreu = versets.filter { $0.hebreu == nil }.count
        #expect(sansHebreu == 0)
        let sousTitre = try #require(modele.sousTitre)
        let texte = try Self.traducteur("he").texte(sousTitre)
        #expect(texte == "6 פסוקים")
    }

    @Test func sansLHebreuLeNumeroEnChiffresVaDevantLaPremiereTraduction() async throws {
        var reglages = Reglages()
        reglages.setLectureLangues("fr+en")
        let modele = await Self.lecture(.portion(Portion(23, 23)),
                                        magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)))
        #expect(!modele.hebreuSeul)
        let troisieme = try #require(modele.psaumes.first?.versets[2])
        #expect(troisieme.hebreu == nil)
        #expect(troisieme.numeroLatin == "3")
        let langues = troisieme.traductions.map { $0.langue }
        #expect(langues == ["fr", "en"])
    }

    @Test func laPoliceMasqueSesSignesAbsents() async throws {
        var reglages = Reglages()
        reglages.setLecturePolice("frank")
        let modele = await Self.lecture(.portion(Portion(23, 23)), langue: "he",
                                        magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)))
        let livre = try await Self.contenus.tehilim()
        let premier = try #require(modele.psaumes.first?.versets.first)
        #expect(premier.hebreu == PoliceHebraique.masque(livre.versets(23)[0], police: .frank))
    }

    // MARK: Une portion

    @Test func laPortionDuJourSeLitDUnTraitSansBouton() async throws {
        // 1er Tichri : Tehilim 1 à 9, ce que la ligne « Selon le jour du mois » ouvre.
        let jour = try #require(JourCivil(iso: "2026-09-12"))
        let horloge = HorlogeFixe(DateHeure(jour, heure: 9), fuseau: .utc)
        let livre = TehilimModele(magasin: Magasin.enMemoire(), contenus: Self.contenus, horloge: horloge, langue: "fr")
        let modele = await Self.lecture(livre.routeMois.cible)
        #expect(modele.portion == Portion(1, 9))
        #expect(modele.titre == Libelle("tehilim_range", .texte("1"), .texte("9")))
        #expect(!modele.navigationVisible)
        let psaumes = modele.psaumes
        let numeros = psaumes.map { $0.numero }
        #expect(numeros == Array(1...9))
        let premiers = psaumes.filter { $0.premier }.map { $0.numero }
        #expect(premiers == [1])
        let tehilim = try await Self.contenus.tehilim()
        var total = 0
        for n in 1...9 { total += tehilim.versets(n).count }
        #expect(modele.nombreVersets == total)
        let affiches = psaumes.reduce(0) { $0 + $1.versets.count }
        #expect(affiches == total)
    }

    @Test func lePsaumeCentDixNeufCoupeNeMontreQueSesVersets() async throws {
        let modele = await Self.lecture(.portion(Portion(119, 119, 97, 176)))
        #expect(modele.titre == Libelle("tehilim_range_verses", .texte("119"), .texte("97"), .texte("176")))
        #expect(!modele.navigationVisible)
        #expect(modele.nombreVersets == 80)
        let versets = try #require(modele.psaumes.first).versets
        #expect(versets.first?.id == "v:119:97")
        #expect(versets.last?.id == "v:119:176")
        #expect(versets.count == 80)
    }

    // MARK: Précédent, suivant

    @Test func precedentEtSuivantMenentAuPsaumeVoisinDepuisLeHaut() async throws {
        let modele = await Self.lecture(.portion(Portion(1, 1)))
        #expect(!modele.precedentVisible)
        #expect(modele.suivantVisible)
        modele.precedent()
        #expect(modele.portion == Portion(1, 1))
        #expect(modele.defilement == nil)

        modele.suivant()
        #expect(modele.portion == Portion(2, 2))
        #expect(modele.titre == Libelle("tehilim_single", .texte("2")))
        let premier = try #require(modele.defilement)
        #expect(premier.cible == nil)
        modele.suivant()
        let second = try #require(modele.defilement)
        #expect(second.cible == nil)
        #expect(second.jeton != premier.jeton)
        modele.precedent()
        #expect(modele.portion == Portion(2, 2))

        let dernier = await Self.lecture(.portion(Portion(150, 150)))
        #expect(dernier.precedentVisible)
        #expect(!dernier.suivantVisible)
        dernier.suivant()
        #expect(dernier.portion == Portion(150, 150))
    }

    @Test func uneLecturePartielleNAPasDeBoutons() async {
        let modele = await Self.lecture(.portion(Portion(119, 119, 1, 96)))
        modele.suivant()
        #expect(modele.portion == Portion(119, 119, 1, 96))
    }

    // MARK: Les marque-pages

    @Test func unAppuiLongMarqueEtDemarqueLeVerset() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        let modele = await Self.lecture(.portion(Portion(23, 23)), magasin: magasin)
        let livre = try await Self.contenus.tehilim()

        let pose = try await modele.basculerMarque(psaume: 23, verset: 3)
        #expect(pose)
        #expect(modele.message == Libelle("marque_posee"))
        let attendue = MarquesPages.Marque(cle: "t:tehilim", nusah: "", section: 23, bloc: 3,
                                           apercu: Reference.lettres(23) + ", " + Reference.lettres(3) + " · "
                                               + MarquesPages.apercu(livre.versets(23)[2], mots: 5))
        let gardees = TehilimMarques.toutes(magasin.reglages)
        #expect(gardees == [attendue])
        let ecrites = await persistance.enregistrement.reglages
        #expect(TehilimMarques.toutes(ecrites) == [attendue])
        let marques = try #require(modele.psaumes.first).versets.filter { $0.marque }.map { $0.id }
        #expect(marques == ["v:23:3"])
        // La place reste : aucun défilement.
        #expect(modele.defilement == nil)

        modele.finMessage()
        #expect(modele.message == nil)
        let retire = try await modele.basculerMarque(psaume: 23, verset: 3)
        #expect(!retire)
        #expect(modele.message == Libelle("marque_retiree"))
        let restantes = TehilimMarques.toutes(magasin.reglages)
        #expect(restantes.isEmpty)
        let ecritures = await persistance.ecrituresReglages
        #expect(ecritures == 2)

        let horsDuPsaume = try await modele.basculerMarque(psaume: 23, verset: 7)
        #expect(!horsDuPsaume)
        let toujours = await persistance.ecrituresReglages
        #expect(toujours == 2)
    }

    @Test func unMarquePageDUnAutreTexteNeMarqueRien() async throws {
        var reglages = Reglages()
        TehilimMarques.basculer(&reglages, MarquesPages.Marque(cle: "s:chaharit", nusah: "", section: 23, bloc: 1,
                                                               apercu: "x"))
        let modele = await Self.lecture(.portion(Portion(23, 23)),
                                        magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)))
        let marques = try #require(modele.psaumes.first).versets.filter { $0.marque }.count
        #expect(marques == 0)
    }

    /// Le critère de la tâche 22 : lire la portion du jour, poser un marque-page sur un verset, le retrouver.
    @Test func laPortionDuJourUnMarquePagePoseEtRetrouve() async throws {
        let magasin = Magasin.enMemoire()
        // Le 1er Tichri, la portion du mois : Tehilim 1 à 9.
        let jour = try #require(JourCivil(iso: "2026-09-12"))
        let horloge = HorlogeFixe(DateHeure(jour, heure: 9), fuseau: .utc)
        let livre = TehilimModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: "fr")
        await livre.charger()
        #expect(livre.ligneSignets == nil)
        let lecture = await Self.lecture(livre.routeMois.cible, magasin: magasin)
        #expect(lecture.portion == Portion(1, 9))

        // Un appui long sur le verset 4 du psaume 5.
        let pose = try await lecture.basculerMarque(psaume: 5, verset: 4)
        #expect(pose)

        // De retour au livre : la ligne des marque-pages, puis la feuille, puis le marque-page.
        livre.actualiser()
        let ligne = try #require(livre.ligneSignets)
        #expect(ligne.nombre == 1)
        livre.ouvrirSignets()
        let signet = try #require(livre.lignesSignets.first)
        let route = livre.choisirSignet(signet)
        #expect(route == .lecture(.marque(psaume: 5, verset: 4)))

        // Le psaume s'ouvre seul, le verset marqué en haut de l'écran.
        let retrouvee = await Self.lecture(route.cible, magasin: magasin)
        #expect(retrouvee.portion == Portion(5, 5))
        #expect(retrouvee.navigationVisible)
        let defilement = try #require(retrouvee.defilement)
        #expect(defilement.cible == "v:5:4")
        let marques = try #require(retrouvee.psaumes.first).versets.filter { $0.marque }.map { $0.id }
        #expect(marques == ["v:5:4"])
    }

    @Test func unMarquePageHorsDuPsaumeNeDefilePas() async {
        let modele = await Self.lecture(.marque(psaume: 23, verset: 40))
        #expect(modele.portion == Portion(23, 23))
        #expect(modele.defilement == nil)
    }

    // MARK: Le bouton de lecture

    @Test func laTailleSeRegleParDixiemesEntreQuatreVingtsEtDeuxCents() async throws {
        let modele = await Self.lecture(.portion(Portion(23, 23)))
        let barre = modele.barre
        #expect(barre.pastilleVisible)
        #expect(!barre.barreVisible)
        barre.deplierBarre(true)
        #expect(barre.barreVisible)
        #expect(!barre.pastilleVisible)
        #expect(barre.pourcent == 100)

        try await barre.changerTaille(plus: true)
        #expect(barre.libellePourcent == Libelle("lecture_pourcent", .entier(110)))
        #expect(barre.descriptionPourcent == Libelle("lecture_taille", .entier(110)))
        try await barre.tailleNormale()
        #expect(barre.pourcent == 100)
        for _ in 0..<5 {
            try await barre.changerTaille(plus: false)
        }
        #expect(barre.pourcent == 80)
        barre.deplierBarre(false)
        #expect(barre.pastilleVisible)
    }

    @Test func laNuitLaPoliceEtLesLanguesSEcriventEtGardentLaPlace() async throws {
        let magasin = Magasin.enMemoire()
        let modele = await Self.lecture(.portion(Portion(23, 23)), magasin: magasin)
        let barre = modele.barre
        #expect(!barre.sombre)
        #expect(barre.etatNuit == Libelle("lecture_nuit_non"))

        modele.teteVisible("v:23:4")
        try await barre.basculerNuit()
        #expect(barre.sombre)
        #expect(barre.etatNuit == Libelle("lecture_nuit_oui"))
        let apresNuit = try #require(modele.defilement)
        #expect(apresNuit.cible == "v:23:4")

        let polices = barre.optionsPolice
        #expect(polices.count == 7)
        let cochee = polices.filter { $0.choisi }.map { $0.valeur }
        #expect(cochee == [.serif])
        try await barre.choisirPolice(.david)
        #expect(barre.police == .david)
        #expect(magasin.reglages.lecturePolice == "david")

        let langues = barre.optionsLangues.filter { $0.choisi }.map { $0.valeur }
        #expect(langues == [.heFr])
        try await barre.choisirLangues(.he)
        #expect(modele.hebreuSeul)
        #expect(magasin.reglages.lectureLangues == "he")
        let apresLangues = try #require(modele.defilement)
        #expect(apresLangues.cible == "v:23:4")
        #expect(apresLangues.jeton != apresNuit.jeton)
    }

    @Test func masquerPuisRetrouverLeBouton() async throws {
        let modele = await Self.lecture(.portion(Portion(23, 23)))
        let barre = modele.barre
        barre.deplierBarre(true)
        try await barre.masquer()
        #expect(barre.masquee)
        #expect(barre.annonceMasque)
        #expect(!barre.pastilleVisible)
        #expect(!barre.barreVisible)
        barre.finAnnonceMasque()
        #expect(!barre.annonceMasque)

        try await barre.retrouver()
        #expect(!barre.masquee)
        #expect(barre.barreVisible)
    }

    @Test func laPastilleSEffaceEnDescendantEtRevientEnRemontant() async {
        let modele = await Self.lecture(.portion(Portion(23, 23)))
        let barre = modele.barre
        barre.defilementVertical(10)
        #expect(!barre.pastilleEffacee)
        barre.defilementVertical(20)
        #expect(barre.pastilleEffacee)
        barre.defilementVertical(-30)
        #expect(!barre.pastilleEffacee)
        barre.defilementVertical(30)
        #expect(barre.pastilleEffacee)
        barre.toucherTexte()
        #expect(!barre.pastilleEffacee)
    }

    // MARK: L'erreur

    @Test func unLivreIllisibleNeMontreRien() async {
        let modele = TehilimLectureModele(magasin: Magasin.enMemoire(), contenus: ContenusApp(lecteur: { _ in nil }),
                                          langue: "fr", cible: .portion(Portion(23, 23)))
        await modele.charger()
        #expect(modele.etat == .erreur)
        #expect(modele.psaumes.isEmpty)
        #expect(modele.sousTitre == nil)
        #expect(modele.titre == Libelle("tehilim_single", .texte("23")))
    }
}
