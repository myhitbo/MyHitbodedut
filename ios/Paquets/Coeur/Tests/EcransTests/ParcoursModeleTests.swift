import Foundation
import Testing
import Coeur
@testable import Ecrans

/// « Mon parcours » (ParcoursActivity.kt) : le critère de la feuille de route, « le parcours montre les mêmes
/// étapes qu'Android » — les quatre tuiles dans leur ordre, la moyenne, le mois, les sujets, l'humeur — pour
/// un journal vide et un journal forgé. Les chiffres eux-mêmes (Parcours.bilan, Parcours.humeur, les séries)
/// sont jugés dans CoeurTests, sur les vecteurs d'Android.
///
/// Restent au test d'interface : la cascade des blocs, les chiffres qui montent, les barres qui se remplissent
/// (et rien de tout cela avec « Réduire les animations »), le dessin du mois de droite à gauche en hébreu.
@Suite("Modèle de « Mon parcours »")
@MainActor
struct ParcoursModeleTests {

    /// Jeudi 12 novembre 2026, à midi, en UTC.
    static let aujourdhui = "2026-11-12"

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    private func fabriquer(_ journal: Journal = Journal()) throws -> (ParcoursModele, Magasin) {
        let magasin = Magasin.enMemoire(Enregistrement(journal: journal))
        let date = try Self.jour(Self.aujourdhui)
        let horloge = HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc)
        return (ParcoursModele(magasin: magasin, horloge: horloge), magasin)
    }

    /// Du lundi 2 au jeudi 5 novembre (quatre jours d'affilée), puis du mardi 10 au jeudi 12 (trois jours,
    /// jusqu'à aujourd'hui), avec des sujets et l'humeur de deux jours.
    static func journalForge() throws -> Journal {
        var journal = Journal()
        let seances: [(String, Int, [String])] = [
            ("2026-11-02", 10, ["gratitude"]),
            ("2026-11-03", 11, ["famille", "gratitude"]),
            ("2026-11-04", 20, []),
            ("2026-11-05", 30, ["gratitude", "inconnu"]),
            ("2026-11-10", 15, ["famille"]),
            ("2026-11-11", 25, ["parnassa"]),
            ("2026-11-12", 5, []),
        ]
        for (iso, minutes, themes) in seances {
            let date = try jour(iso)
            journal[date] = Journee(minutes: minutes, note: "", themes: themes)
        }
        // Une note seule (un samedi) : ni un jour fait, ni une rupture de série.
        try journal.setNote(date: jour("2026-11-07"), note: "Une idée")
        try journal.ecrirePlus(JournalPlus.Plus(avant: 2, apres: 4), pour: jour("2026-11-10"))
        try journal.ecrirePlus(JournalPlus.Plus(avant: 3, apres: 5), pour: jour("2026-11-11"))
        // Une humeur à moitié notée ne compte pas ; ni un jour du journal enrichi sans journée.
        try journal.ecrirePlus(JournalPlus.Plus(avant: 1), pour: jour("2026-11-12"))
        try journal.ecrirePlus(JournalPlus.Plus(avant: 1, apres: 1), pour: jour("2026-11-20"))
        return journal
    }

    // MARK: Le journal vide

    @Test func sansRienLesTuilesSontAZeroEtLesSectionsLeDisent() throws {
        let (modele, _) = try fabriquer()
        #expect(modele.titre == Libelle("parcours_title"))
        #expect(modele.sousTitre == Libelle("parcours_hint"))
        #expect(modele.imageBandeau == "char_praise")
        let tuiles = modele.tuiles
        let ids = tuiles.map(\.id)
        #expect(ids == ["serie", "meilleure", "jours", "total"])
        let valeurs = tuiles.map(\.valeur)
        #expect(valeurs == [.nombre(0), .nombre(0), .nombre(0), .duree(Libelle("duration_minutes", .entier(0)))])
        #expect(modele.moyenne == nil)
        #expect(modele.texteMois == Libelle("parcours_mois_vide"))
        #expect(modele.sujets.isEmpty)
        #expect(modele.sujetsVide == Libelle("parcours_sujets_vide"))
        #expect(modele.humeur == nil)
        #expect(modele.graphique.barres.count == 30)
    }

    // MARK: Un journal forgé

    @Test func lesTuilesDansLOrdreDAndroid() throws {
        let (modele, _) = try fabriquer(Self.journalForge())
        let tuiles = modele.tuiles
        let valeurs = tuiles.map(\.valeur)
        #expect(valeurs == [
            .nombre(3),
            .nombre(4),
            .nombre(7),
            .duree(Libelle("duration_hours_minutes", .entier(1), .entier(56))),
        ])
        let unites = tuiles.map(\.unite)
        #expect(unites == [
            Libelle.pluriel("parcours_unite_jours", quantite: 3),
            Libelle.pluriel("parcours_unite_jours", quantite: 4),
            nil,
            nil,
        ])
        let libelles = tuiles.map(\.libelle)
        #expect(libelles == [
            Libelle("parcours_serie"), Libelle("parcours_meilleure"),
            Libelle("parcours_jours_faits"), Libelle("parcours_total"),
        ])
        let teintes = tuiles.map(\.teinte)
        #expect(teintes == [.anneauSerie, .anneauSerie, .anneauSemaine, .marque])
    }

    @Test func laMoyenneSArrondiCommeMathRound() throws {
        // 116 minutes en 7 jours : 16,57 → 17.
        let (forge, _) = try fabriquer(Self.journalForge())
        #expect(forge.moyenne == Libelle("parcours_moyenne_ligne", .libelle(Libelle("duration_minutes", .entier(17)))))
        // 21 minutes en 2 jours : 10,5 → 11 (le demi vers le haut).
        var journal = Journal()
        try journal.addSession(minutes: 10, date: Self.jour("2026-11-02"))
        try journal.addSession(minutes: 11, date: Self.jour("2026-11-03"))
        let (modele, _) = try fabriquer(journal)
        #expect(modele.moyenne == Libelle("parcours_moyenne_ligne", .libelle(Libelle("duration_minutes", .entier(11)))))
    }

    @Test func leMoisDitSonTempsEtSesJours() throws {
        var journal = try Self.journalForge()
        // Octobre ne compte pas dans le mois de novembre.
        try journal.addSession(minutes: 60, date: Self.jour("2026-10-31"))
        let (modele, _) = try fabriquer(journal)
        #expect(modele.texteMois == Libelle.pluriel("parcours_mois_total", quantite: 7,
                                                     .libelle(Libelle("duration_hours_minutes", .entier(1), .entier(56))),
                                                     .entier(7)))
        #expect(modele.titreMois == Libelle("parcours_mois"))
        let graphique = modele.graphique
        #expect(graphique.total == 116)
        let parts = graphique.barres.map(\.part)
        #expect(parts[4] == 1)
        let aujourdhui = graphique.barres.filter(\.aujourdhui).map(\.jour)
        #expect(aujourdhui == [12])
    }

    @Test func lesSujetsLesPlusFrequentsEnBarres() throws {
        let (modele, _) = try fabriquer(Self.journalForge())
        let sujets = modele.sujets
        let themes = sujets.map(\.theme)
        #expect(themes == [.gratitude, .famille, .parnassa])
        let fois = sujets.map(\.fois)
        #expect(fois == [
            Libelle.pluriel("parcours_fois", quantite: 3, .entier(3)),
            Libelle.pluriel("parcours_fois", quantite: 2, .entier(2)),
            Libelle.pluriel("parcours_fois", quantite: 1, .entier(1)),
        ])
        let noms = sujets.map(\.nom)
        #expect(noms == [Libelle("theme_gratitude"), Libelle("theme_famille"), Libelle("theme_parnassa")])
        let parts = sujets.map(\.part)
        #expect(parts == [1, 2.0 / 3.0, 1.0 / 3.0])
        #expect(modele.titreSujets == Libelle("parcours_sujets"))
    }

    @Test func uneBarreDeSujetGardeQuatrePourCentAuMoins() {
        let rare = ParcoursSujet(theme: .autre, nombre: 1, plusFrequent: 50)
        #expect(rare.part == 0.02)
        #expect(rare.partDessinee == 0.04)
        let plein = ParcoursSujet(theme: .autre, nombre: 50, plusFrequent: 50)
        #expect(plein.partDessinee == 1)
    }

    @Test func lHumeurMoyenneSurLesJoursNotes() throws {
        let (modele, _) = try fabriquer(Self.journalForge())
        let humeur = try #require(modele.humeur)
        // (2 + 3) / 2 = 2,5 → 3 ; (4 + 5) / 2 = 4,5 → 5 ; deux jours.
        #expect(humeur.avant == 3)
        #expect(humeur.apres == 5)
        #expect(humeur.jours == 2)
        #expect(humeur.texte == "\u{2066}\u{1F610}  \u{2192}  \u{1F604}\u{2069}")
        #expect(humeur.legende == [
            Libelle("parcours_humeur_legende"),
            Libelle.pluriel("parcours_humeur_jours", quantite: 2, .entier(2)),
        ])
        #expect(modele.titreHumeur == Libelle("parcours_humeur"))
    }

    @Test func ceQuiChangeAilleursSeVoitAussitot() async throws {
        let (modele, magasin) = try fabriquer()
        #expect(modele.moyenne == nil)
        let date = try Self.jour(Self.aujourdhui)
        try await magasin.modifierJournal { $0.addSession(minutes: 20, theme: "emotions", date: date) }
        let valeurs = modele.tuiles.map(\.valeur)
        #expect(valeurs == [.nombre(1), .nombre(1), .nombre(1), .duree(Libelle("duration_minutes", .entier(20)))])
        let themes = modele.sujets.map(\.theme)
        #expect(themes == [.emotions])
    }

    @Test func lesTeintesDesTuiles() {
        #expect(ParcoursTeinte.marque.jeton == .brand)
        #expect(ParcoursTeinte.anneauSerie.jeton == nil)
        #expect(ParcoursTeinte.anneauSerie.couleur(nuit: false) == Couleur(hex: "#B8780F"))
        #expect(ParcoursTeinte.anneauSemaine.couleur(nuit: true) == Couleur(hex: "#6FB7E8"))
        #expect(ParcoursTeinte.marque.couleur(nuit: false) == nil)
    }
}
