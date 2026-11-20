import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le Chemin (refonte d'Android du 13/11, MainActivity.renderChemin) : les trois chiffres, le mois, l'état du journal
/// et des trophées, et les cartes qui ouvrent le journal, le parcours et les paliers. Les chiffres eux-mêmes (séries,
/// total, trophées) sont jugés dans CoeurTests sur les vecteurs d'Android.
@Suite("Modèle du Chemin")
@MainActor
struct CheminModeleTests {

    /// Jeudi 12 novembre 2026, à midi, en UTC.
    static let aujourdhui = "2026-11-12"

    private func fabriquer(_ journal: Journal = Journal()) throws -> CheminModele {
        let magasin = Magasin.enMemoire(Enregistrement(journal: journal))
        let date = try #require(JourCivil(iso: Self.aujourdhui))
        return CheminModele(magasin: magasin, horloge: HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc))
    }

    @Test func sansRien() throws {
        let m = try fabriquer()
        #expect(m.serie == 0)
        #expect(m.meilleure == 0)
        #expect(m.total == Store.formatDuration(0))
        #expect(m.etatJournal == Libelle.pluriel("journal_summary", quantite: 0, .entier(0),
                                                 .libelle(Store.formatDuration(0))))
        let ids = m.chiffres.map(\.id)
        #expect(ids == ["serie", "meilleure", "total"])
        #expect(m.titre == Libelle("nav_chemin"))
        let barres = m.graphique.barres.count
        #expect(barres == 30)
    }

    /// Quatre jours d'affilée début novembre, puis trois jusqu'à aujourd'hui ; une note seule ne compte pas.
    @Test func unJournalForge() throws {
        var journal = Journal()
        for (iso, minutes) in [("2026-11-02", 10), ("2026-11-03", 11), ("2026-11-04", 20), ("2026-11-05", 30),
                               ("2026-11-10", 15), ("2026-11-11", 25), ("2026-11-12", 5)] {
            let date = try #require(JourCivil(iso: iso))
            journal.addSession(minutes: minutes, date: date)
        }
        try journal.setNote(date: #require(JourCivil(iso: "2026-11-07")), note: "Une idée")
        let m = try fabriquer(journal)
        #expect(m.serie == 3)
        #expect(m.meilleure == 4)
        #expect(m.total == Store.formatDuration(116))
        #expect(m.chiffres.first?.valeur == .brut("3"))
        #expect(m.etatJournal == Libelle.pluriel("journal_summary", quantite: 7, .entier(7),
                                                 .libelle(Store.formatDuration(116))))
        #expect(m.etatTrophees.cle == "accueil_prochain_trophee")
    }

    @Test func lesCartesOuvrentLeurEcran() throws {
        let m = try fabriquer()
        m.ouvrir(.journal)
        m.ouvrir(.parcours)
        m.ouvrir(.paliers)
        #expect(m.routes == [.journal, .parcours, .paliers])
        m.routeOuverte()
        #expect(m.routes == [.parcours, .paliers])
    }

    @Test func lesClesSontAuCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        let m = try fabriquer()
        let cles = [m.titre.cle, m.libelleJournal.cle, m.etatJournal.cle, m.libelleParcours.cle,
                    m.indicationParcours.cle, m.libelleTrophees.cle, m.etatTrophees.cle] + m.chiffres.map(\.libelle.cle)
        for cle in cles {
            for langue in Traducteur.langues {
                let present = catalogue.strings[cle]?.localizations?[langue] != nil
                #expect(present, "\(cle) manque en \(langue)")
            }
        }
    }
}
