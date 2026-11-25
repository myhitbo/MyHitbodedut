import Foundation
import Testing
import Barriere
import Coeur
@testable import Ecrans

/// L'aperçu du bouclier (GateService.preview, BlockerView.kt ; PORTAGE.md § 2.1.4, § 2.1.8) : les trois visages de
/// la réplique, leurs clés et leurs poses ; la réplique dit exactement ce que dira l'extension du bouclier, qui
/// compose les textes d'etat.json par la même règle ; l'essai réel, réussi ou refusé. BlockerView n'a pas de test
/// sur Android.
///
/// Restent à Xcode et à l'iPhone : la vue (Vues/ApercuBouclierVue.swift), le vrai bouclier dessiné par iOS
/// (Bouclier/Bouclier.swift) et l'essai réel (App/Services/SystemeBarriere.swift).
@Suite("Modèle de l'aperçu du bouclier")
@MainActor
struct ApercuBouclierModeleTests {

    /// Lundi 16 novembre 2026, 14 h, temps universel.
    private static let lundi: Int64 = 1_794_787_200_000 + 14 * 3_600_000

    private static func modele(_ enregistrement: Enregistrement = Enregistrement(),
                               essai: (any BouclierEssai)? = FauxBouclierEssai(fin: nil)) -> ApercuBouclierModele {
        ApercuBouclierModele(magasin: Magasin.enMemoire(enregistrement),
                             horloge: HorlogeFixe(maintenant: lundi, fuseau: .utc), essai: essai)
    }

    private static func catalogueIos() throws -> CatalogueBrut {
        try JSONDecoder().decode(CatalogueBrut.self, from: Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings"))
    }

    // MARK: Les visages

    @Test func lesTroisVisagesDansLOrdreDeBlockerMode() {
        let m = Self.modele()
        let visages = m.visages.map { $0.visage }
        #expect(visages == [.invite, .seance, .apercu])
        let noms = m.visages.map { $0.nom.cle }
        #expect(noms == ["apercu_bouclier_visage_invite", "apercu_bouclier_visage_seance", "apercu_bouclier_visage_essai"])
        let choisi = m.visage.visage
        #expect(choisi == .invite)
        m.choisi = .seance
        let seance = m.visage.visage
        #expect(seance == .seance)
    }

    /// PROMPT : la question, le sous-titre et la série, « Commencer maintenant » à la durée habituelle, puis
    /// « Autre réponse » et son sous-menu.
    @Test func leVisageRienDeFait() {
        let m = Self.modele()
        let contenu = m.visage.contenu
        #expect(contenu.pose == .appel)
        #expect(contenu.badge == nil)
        #expect(contenu.titre == Libelle("blocker_question"))
        let lignes = contenu.lignes.map { $0.cle }
        #expect(lignes == ["blocker_subtitle", "blocker_streak_none"])
        #expect(contenu.principal == Libelle("blocker_start", .libelle(Store.formatDuration(Reglages().targetMinutes))))
        #expect(contenu.secondaire == Libelle("bouclier_autre_reponse"))
        let menu = contenu.sousMenu.map { $0.cle }
        #expect(menu == ["blocker_already_done", "blocker_snooze"])
        #expect(contenu.sousMenu.last == Libelle("blocker_snooze", .entier(Reglages().snoozeMinutes)))
    }

    @Test func lesVisagesSeanceEtEssai() {
        let m = Self.modele()
        m.choisi = .seance
        let seance = m.visage.contenu
        #expect(seance.pose == .priere)
        #expect(seance.titre == Libelle("blocker_session_title"))
        #expect(seance.lignes == [Libelle("blocker_session_hidden_subtitle"), Libelle("blocker_streak_none")])
        #expect(seance.principal == Libelle("blocker_back_to_session"))
        #expect(seance.secondaire == nil)
        m.choisi = .apercu
        let essai = m.visage.contenu
        #expect(essai.badge == Libelle("blocker_preview_badge"))
        #expect(essai.titre == Libelle("blocker_question"))
        #expect(essai.principal == Libelle("blocker_close_preview"))
        #expect(essai.secondaire == nil)
    }

    /// Les poses du jour, celles de Character.call et Character.during.
    @Test func lesPosesDuJour() {
        let m = Self.modele()
        let jour = HorlogeFixe(maintenant: Self.lundi, fuseau: .utc).aujourdhui
        let images = m.visages.map { $0.image }
        #expect(images == [Poses.call(jour), Poses.during(jour), Poses.call(jour)])
    }

    /// La réplique et l'extension disent la même chose : les libellés de la réplique, résolus, sont les textes que
    /// l'extension lit dans etat.json, composés par la même règle.
    @Test(arguments: ["fr", "en", "he"])
    func laRepliqueDitCeQueDiraLeBouclier(langue: String) throws {
        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: langue)
        var enregistrement = Enregistrement()
        enregistrement.journal.addSession(minutes: 20, date: HorlogeFixe(maintenant: Self.lundi - 86_400_000).aujourdhui)
        let m = Self.modele(enregistrement)
        let etat = EtatBarriere.etat(journal: enregistrement.journal, reglages: enregistrement.reglages,
                                     millis: Self.lundi, fuseau: .utc, nombreDeJetons: 2,
                                     textes: { traducteur.texte($0) })
        for visage in m.visages {
            let extension_ = visage.visage.contenu { etat.bouclier[$0] }
            let replique = visage.contenu
            let titre = traducteur.texte(replique.titre)
            let lignes = replique.lignes.map { traducteur.texte($0) }
            let principal = traducteur.texte(replique.principal)
            let secondaire = replique.secondaire.map { traducteur.texte($0) }
            let sousMenu = replique.sousMenu.map { traducteur.texte($0) }
            let badge = replique.badge.map { traducteur.texte($0) }
            #expect(titre == extension_.titre)
            #expect(lignes == extension_.lignes)
            #expect(principal == extension_.principal)
            #expect(secondaire == extension_.secondaire)
            #expect(sousMenu == extension_.sousMenu)
            #expect(badge == extension_.badge)
            #expect(replique.pose == extension_.pose)
        }
    }

    // MARK: L'essai réel

    @Test func lEssaiReussi() async {
        let fin = Self.lundi + PilotageBarriere.dureeEssai
        let service = FauxBouclierEssai(fin: fin)
        let m = Self.modele(essai: service)
        #expect(m.essaiDisponible)
        #expect(m.etatEssai == nil)
        await m.faireEssai()
        #expect(m.finEssai == fin)
        #expect(m.message == nil)
        #expect(m.etatEssai == Libelle("apercu_bouclier_essai_en_cours", .texte("14:02")))
        let demandes = await service.demandes
        #expect(demandes == 1)
    }

    @Test func lEssaiRefuseLeDit() async {
        let m = Self.modele(essai: FauxBouclierEssai(fin: nil))
        await m.faireEssai()
        #expect(m.finEssai == nil)
        #expect(m.message == Libelle("apercu_bouclier_essai_impossible"))
        m.messageVu()
        #expect(m.message == nil)
    }

    @Test func sansEssaiRienNeSeDemande() async {
        let m = Self.modele(essai: nil)
        #expect(!m.essaiDisponible)
        await m.faireEssai()
        #expect(m.finEssai == nil)
        #expect(m.message == nil)
    }

    /// La série se relit à l'apparition de l'écran.
    @Test func actualiserRelitLaSerie() async throws {
        let magasin = Magasin.enMemoire()
        let horloge = HorlogeFixe(maintenant: Self.lundi, fuseau: .utc)
        let m = ApercuBouclierModele(magasin: magasin, horloge: horloge, essai: nil)
        let avant = m.visage.contenu.lignes.last?.cle
        #expect(avant == "blocker_streak_none")
        try await magasin.modifierJournal { $0.addSession(minutes: 15, date: horloge.aujourdhui) }
        m.actualiser()
        let apres = m.visage.contenu.lignes.last?.cle
        #expect(apres == "blocker_streak")
    }

    // MARK: Les chaînes

    @Test func chaqueCleEstAuCatalogueEnTroisLangues() throws {
        let android = try CatalogueBrut.lire()
        let ios = try Self.catalogueIos()
        let m = Self.modele()
        let deAndroid = [m.titre.cle, "blocker_question", "blocker_subtitle", "blocker_streak_none",
                         "blocker_already_done", "blocker_session_title", "blocker_session_hidden_subtitle",
                         "blocker_back_to_session", "blocker_preview_badge", "blocker_close_preview"]
        var neuves = [m.introduction.cle, m.titreEssai.cle, m.explicationEssai.cle, m.boutonEssai.cle,
                      "apercu_bouclier_essai_en_cours", "apercu_bouclier_essai_impossible", "bouclier_autre_reponse"]
        neuves += m.visages.map { $0.nom.cle }
        #expect(neuves.count == 10)
        for cle in deAndroid {
            for langue in Traducteur.langues {
                let valeur = android.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue)")
            }
        }
        for cle in neuves {
            let chezAndroid = android.strings[cle] != nil
            #expect(!chezAndroid, "« \(cle) » existe déjà chez Android")
            for langue in Traducteur.langues {
                let valeur = ios.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue) dans ios.xcstrings")
            }
        }
        for langue in Traducteur.langues {
            let enCours = ios.valeur("apercu_bouclier_essai_en_cours", langue: langue) ?? ""
            #expect(enCours.contains("%1$@"), "en \(langue)")
        }
    }
}
