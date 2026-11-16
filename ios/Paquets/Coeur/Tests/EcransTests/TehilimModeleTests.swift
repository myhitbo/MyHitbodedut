import Foundation
import Synchronization
import Testing
import Coeur
@testable import Ecrans

/// Une horloge qu'on avance : le jour change pendant que l'écran est ouvert.
private final class TehilimHorlogeMobile: Horloge, Sendable {
    private let instant: Mutex<Int64>
    let fuseau: Fuseau = .utc

    init(_ jour: JourCivil) {
        instant = Mutex(Fuseau.utc.millis(DateHeure(jour, heure: 12)))
    }

    var maintenant: Int64 {
        instant.withLock { $0 }
    }

    func avancer(jours: Int) {
        instant.withLock { $0 += Int64(jours) * 86_400_000 }
    }
}

/// Le livre de Tehilim (TehilimActivity.kt) : le bandeau et son compte, la portion du jour selon le mois hébraïque
/// et selon la semaine (jours relevés dans Tests/Vecteurs/tehilim.json), la grille des 150 psaumes, la ligne et la
/// feuille des marque-pages des Tehilim, et ce que chaque toucher ouvre. Sur le livre exporté du dépôt.
///
/// Restent au test d'interface : la mise en page (cinq cases par ligne à l'écran, la carte des deux portions), le
/// chevron, l'ondulation au toucher, la feuille à l'écran et sa navigation.
@Suite("Modèle du livre de Tehilim")
@MainActor
struct TehilimModeleTests {

    /// Un seul acteur pour la suite : le livre n'est lu qu'une fois.
    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    private static func modele(_ iso: String, langue: String = "fr", reglages: Reglages = Reglages()) throws -> TehilimModele {
        let date = try jour(iso)
        let horloge = HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc)
        return TehilimModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)), contenus: contenus,
                             horloge: horloge, langue: langue)
    }

    private static func traducteur(_ langue: String) throws -> Traducteur {
        try Traducteur(catalogue: Fichiers.catalogue(), langue: langue)
    }

    // MARK: Le bandeau

    @Test func leBandeauCompteLesPsaumesEtLesVersetsAvecLeSeparateurDeLaLangue() async throws {
        let modele = try Self.modele("2026-09-12")
        #expect(modele.etat == .chargement)
        #expect(modele.sousTitre == nil)
        await modele.charger()
        #expect(modele.etat == .pret)
        #expect(modele.titre == Libelle("tehilim_title"))
        #expect(modele.sousTitre == Libelle("tehilim_count", .entier(150), .texte("2\u{202F}527")))
        let sousTitre = try #require(modele.sousTitre)
        let fr = try Self.traducteur("fr").texte(sousTitre)
        #expect(fr == "150 Tehilim, 2\u{202F}527 versets")

        let anglais = try Self.modele("2026-09-12", langue: "en")
        await anglais.charger()
        let sousTitreAnglais = try #require(anglais.sousTitre)
        let en = try Self.traducteur("en").texte(sousTitreAnglais)
        #expect(en == "150 Tehillim, 2,527 verses")
    }

    @Test func leGroupementDesChiffres() {
        let petit = TehilimTexte.groupe(150, langue: "fr")
        #expect(petit == "150")
        let mille = TehilimTexte.groupe(1000, langue: "he")
        #expect(mille == "1,000")
        let million = TehilimTexte.groupe(1_234_567, langue: "fr")
        #expect(million == "1\u{202F}234\u{202F}567")
    }

    @Test func leLivreIllisibleLaisseLesPortionsEtLaGrille() async throws {
        let date = try Self.jour("2026-09-12")
        let horloge = HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc)
        let modele = TehilimModele(magasin: Magasin.enMemoire(), contenus: ContenusApp(lecteur: { _ in nil }),
                                   horloge: horloge, langue: "fr")
        await modele.charger()
        #expect(modele.etat == .erreur)
        #expect(modele.sousTitre == nil)
        let portion = modele.portionDuMois
        #expect(portion == Portion(1, 9))
        let rangees = modele.grille.count
        #expect(rangees == 30)
    }

    @Test func leBandeauMontreLePersonnageAuLivreSelonLAdresse() throws {
        let sans = try Self.modele("2026-09-12")
        #expect(sans.image == "char_tehilim")
        var reglages = Reglages()
        reglages.setAdresse("f")
        let femme = try Self.modele("2026-09-12", reglages: reglages)
        #expect(femme.image == "char_f_tehilim")
    }

    // MARK: La portion du jour

    @Test func roshHachanaLePremierDuMoisEtLeChabbat() throws {
        // 1er Tichri 5787, un samedi (Tests/Vecteurs/tehilim.json).
        let modele = try Self.modele("2026-09-12")
        let jourHebreu = modele.jourHebreu
        let jourDuMois = jourHebreu.jour
        let longueur = jourHebreu.longueur
        #expect(jourDuMois == 1)
        #expect(longueur == 30)
        #expect(modele.portionDuMois == Portion(1, 9))
        #expect(modele.etatMois == Libelle("tehilim_month_state", .texte("1"),
                                           .libelle(Libelle("tehilim_range", .texte("1"), .texte("9")))))
        #expect(modele.routeMois == .lecture(TehilimLectureCible(debut: 1, fin: 9, debutVerset: 1, finVerset: 0)))
        #expect(modele.portionDeLaSemaine == Portion(120, 150))
        #expect(modele.routeSemaine == .lecture(TehilimLectureCible(debut: 120, fin: 150)))

        let fr = try Self.traducteur("fr")
        let mois = fr.texte(modele.etatMois)
        #expect(mois == "Jour 1 du mois\u{00A0}: Tehilim 1 à 9")
        let semaine = fr.texte(modele.etatSemaine)
        #expect(semaine == "Samedi\u{00A0}: Tehilim 120 à 150")
    }

    @Test func enHebreuLesNumerosSontEnLettresEtLeJourANomHebreu() throws {
        let modele = try Self.modele("2026-09-12", langue: "he")
        let he = try Self.traducteur("he")
        let mois = he.texte(modele.etatMois)
        #expect(mois == "יום " + Reference.lettres(1) + " לחודש: תהילים " + Reference.lettres(1) + " עד "
            + Reference.lettres(9))
        let semaine = he.texte(modele.etatSemaine)
        #expect(semaine == "יום שבת: תהילים " + Reference.lettres(120) + " עד " + Reference.lettres(150))
    }

    @Test func leVingtNeuviemeDUnMoisDeVingtNeufJoursFinitLeLivre() throws {
        // 29 Eloul 5786, un vendredi : le mois n'a que 29 jours, les deux dernières portions se disent ensemble.
        let modele = try Self.modele("2026-09-11")
        let jourHebreu = modele.jourHebreu
        let jourDuMois = jourHebreu.jour
        let longueur = jourHebreu.longueur
        #expect(jourDuMois == 29)
        #expect(longueur == 29)
        #expect(modele.portionDuMois == Portion(140, 150))
        #expect(modele.portionDeLaSemaine == Portion(107, 119))
        let anglais = try Self.modele("2026-09-11", langue: "en")
        let semaine = try Self.traducteur("en").texte(anglais.etatSemaine)
        #expect(semaine == "Friday: Tehillim 107 to 119")
    }

    @Test func lePsaumeCentDixNeufSeCoupeEnDeux() throws {
        let vingtCinq = try Self.modele("2026-10-06")
        #expect(vingtCinq.portionDuMois == Portion(119, 119, 1, 96))
        #expect(vingtCinq.routeMois == .lecture(TehilimLectureCible(debut: 119, fin: 119, debutVerset: 1, finVerset: 96)))
        let fr = try Self.traducteur("fr")
        let mois = fr.texte(vingtCinq.etatMois)
        #expect(mois == "Jour 25 du mois\u{00A0}: Tehilim 119, versets 1 à 96")
        #expect(vingtCinq.portionDeLaSemaine == Portion(51, 72))
        let semaine = fr.texte(vingtCinq.etatSemaine)
        #expect(semaine == "Mardi\u{00A0}: Tehilim 51 à 72")

        let vingtSix = try Self.modele("2026-10-07")
        #expect(vingtSix.portionDuMois == Portion(119, 119, 97, 176))
        #expect(vingtSix.routeMois == .lecture(TehilimLectureCible(debut: 119, fin: 119, debutVerset: 97, finVerset: 176)))
    }

    @Test func leJourSeRelitAuRetourSurLEcran() throws {
        let debut = try Self.jour("2026-09-11")
        let horloge = TehilimHorlogeMobile(debut)
        let modele = TehilimModele(magasin: Magasin.enMemoire(), contenus: Self.contenus, horloge: horloge, langue: "fr")
        #expect(modele.portionDuMois == Portion(140, 150))
        horloge.avancer(jours: 1)
        // Rien ne change tant que l'écran ne revient pas au premier plan (onResume).
        #expect(modele.portionDuMois == Portion(140, 150))
        modele.actualiser()
        let jour = modele.jour
        let attendu = try Self.jour("2026-09-12")
        #expect(jour == attendu)
        #expect(modele.portionDuMois == Portion(1, 9))
        #expect(modele.portionDeLaSemaine == Portion(120, 150))
    }

    @Test func lesNomsDesJoursDansLesTroisLangues() {
        let dimanche = TehilimTexte.nomDuJour(1, langue: "fr")
        #expect(dimanche == "Dimanche")
        let mercredi = TehilimTexte.nomDuJour(4, langue: "en")
        #expect(mercredi == "Wednesday")
        let lundi = TehilimTexte.nomDuJour(2, langue: "he")
        #expect(lundi == "יום שני")
        // Une autre langue que les trois de l'app : l'anglais.
        let autre = TehilimTexte.nomDuJour(7, langue: "de")
        #expect(autre == "Saturday")
    }

    // MARK: La grille

    @Test func laGrilleACentCinquantePsaumesCinqParLigne() throws {
        let modele = try Self.modele("2026-09-12")
        let grille = modele.grille
        #expect(grille.count == 30)
        let tailles = Set(grille.map { $0.cases.count })
        #expect(tailles == [5])
        let numeros = grille.flatMap { rangee in rangee.cases.map { $0.id } }
        #expect(numeros == Array(1...150))
        let ids = grille.map { $0.id }
        #expect(ids == Array(0..<30))

        let vingtCinq = try #require(grille[4].cases.last)
        #expect(vingtCinq.id == 25)
        #expect(vingtCinq.numero == "25")
        #expect(vingtCinq.description == Libelle("tehilim_single", .texte("25")))
        #expect(vingtCinq.route == .lecture(.de(Portion(25, 25))))
        #expect(vingtCinq.route == .lecture(TehilimLectureCible(debut: 25, fin: 25)))
    }

    @Test func enHebreuLaGrilleEstEnLettres() throws {
        let modele = try Self.modele("2026-09-12", langue: "he")
        let premiere = try #require(modele.grille.first?.cases.first)
        #expect(premiere.numero == Reference.lettres(1))
        let quinze = try #require(modele.grille[2].cases.last)
        #expect(quinze.numero == "ט״ו")
        let texte = try Self.traducteur("he").texte(quinze.description)
        #expect(texte == "תהילים ט״ו")
    }

    // MARK: Les marque-pages

    private static func marque(_ psaume: Int, _ verset: Int, cle: String = "t:tehilim")
        -> MarquesPages.Marque {
        MarquesPages.Marque(cle: cle, nusah: cle.commenceParUnites("s:") ? "edot" : "", section: psaume, bloc: verset,
                            apercu: Reference.lettres(psaume) + ", " + Reference.lettres(verset) + " · אשרי")
    }

    @Test func sansMarquePageNiLigneNiFeuille() throws {
        let modele = try Self.modele("2026-09-12")
        #expect(modele.ligneSignets == nil)
        #expect(modele.filtresSignets.isEmpty)
        modele.ouvrirSignets()
        #expect(!modele.feuilleSignetsOuverte)
    }

    @Test func laLigneEtLaFeuilleNeMontrentQueLesTehilim() throws {
        var reglages = Reglages()
        // Posés dans le désordre ; un marque-page du siddour n'est pas des Tehilim.
        TehilimMarques.basculer(&reglages, Self.marque(23, 4))
        TehilimMarques.basculer(&reglages, Self.marque(1, 2, cle: "s:chaharit"))
        TehilimMarques.basculer(&reglages, Self.marque(3, 1))
        TehilimMarques.basculer(&reglages, Self.marque(23, 2))
        let modele = try Self.modele("2026-09-12", reglages: reglages)

        let ligne = try #require(modele.ligneSignets)
        #expect(ligne.nombre == 3)
        #expect(ligne.titre == Libelle("marques_titre"))
        #expect(ligne.icone == "ic_marque_priere")

        modele.ouvrirSignets()
        #expect(modele.feuilleSignetsOuverte)
        #expect(modele.filtreSignets == "*")
        let filtres = modele.filtresSignets.map { $0.id }
        #expect(filtres == ["*", "t"])
        let noms = modele.filtresSignets.map { $0.libelle }
        #expect(noms == [Libelle("recherche_tout"), Libelle("tehilim_title")])

        // Dans l'ordre du livre : psaume, puis verset.
        let lignes = modele.lignesSignets
        #expect(lignes.count == 3)
        let routes = lignes.map { $0.route }
        #expect(routes == [.lecture(.marque(psaume: 3, verset: 1)), .lecture(.marque(psaume: 23, verset: 2)),
                           .lecture(.marque(psaume: 23, verset: 4))])
        let premiere = try #require(lignes.first)
        #expect(premiere.titre == Libelle("tehilim_title"))
        #expect(premiere.apercu == Reference.lettres(3) + ", " + Reference.lettres(1) + " · אשרי…")
        #expect(premiere.icone == "ic_marque_priere")

        modele.choisirFiltreSignets("t")
        #expect(modele.filtreSignets == "t")
        let filtrees = modele.lignesSignets.count
        #expect(filtrees == 3)
        modele.choisirFiltreSignets("s")
        #expect(modele.filtreSignets == "t")

        let route = modele.choisirSignet(premiere)
        #expect(route == .lecture(TehilimLectureCible(debut: 3, fin: 3, marqueVerset: 1)))
        #expect(!modele.feuilleSignetsOuverte)

        // Rouverte, la feuille repart de « Tout ».
        modele.ouvrirSignets()
        #expect(modele.filtreSignets == "*")
        modele.fermerSignets()
        #expect(!modele.feuilleSignetsOuverte)
    }

    @Test func lApercuSuitLaPoliceDeLecture() throws {
        var reglages = Reglages()
        // Un meteg (U+05BD), absent de la police à empattements : masqué dans la feuille.
        TehilimMarques.basculer(&reglages, MarquesPages.Marque(cle: TehilimLectureModele.cleMarques, nusah: "",
                                                               section: 1, bloc: 1, apercu: "\u{05D0}\u{05BD}"))
        let modele = try Self.modele("2026-09-12", reglages: reglages)
        let ligne = try #require(modele.lignesSignets.first)
        let apercu = ligne.apercu
        #expect(apercu == "\u{05D0}\u{034F}…")
    }
}
