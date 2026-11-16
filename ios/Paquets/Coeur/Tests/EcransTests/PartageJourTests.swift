import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'image de partage d'un jour (PartageJour.kt) : son contenu, testé sans dessin comme sur Android, puis sa mise en
/// page bloc par bloc. Le dessin lui-même (ImageRenderer) est jugé sur le simulateur.
@Suite("Partage du jour")
@MainActor
struct PartageJourTests {

    private func contexte(_ reglages: Reglages, fuseau: String = "Asia/Jerusalem") async throws -> ZmanimContexte {
        let telephone = try #require(Fuseau(fuseau))
        let sources = await ZmanimSources.lire(contenus: ZmanimEssais.contenus, hilloulot: ZmanimEssais.hilloulot)
        return ZmanimContexte(reglages: reglages, fuseauTelephone: telephone, langue: "fr", sources: sources)
    }

    @Test func leContenuDuJour() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let c = try await contexte(ZmanimEssais.reglages(ville))
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let contenu = PartageContenu.pour(jour, c)
        #expect(contenu.date == jour)
        #expect(contenu.nomFichier == "jour-2026-10-12.png")
        let carte = ZmanimVueJour.carte(jour, c)
        #expect(contenu.dateHebraique == carte.dateHebraique)
        let marques = ZmanimEssais.cles(contenu.marques)
        #expect(marques.contains("fete_roch_hodech"))
        // La hilloula : trois noms au plus.
        let table = try await ZmanimEssais.hilloulot.table()
        let noms = Hilloulot.pour(table, date: jour, enIsrael: true).prefix(3).map { $0.he }
        #expect(contenu.hilloula == noms.joined(separator: " · "))
        // La halakha : le début du Yalkut Yosef, 420 unités au plus.
        let yalkut = try await ZmanimEssais.contenus.yalkutYosef()
        let debut = try #require(YalkutYosef.pour(yalkut, date: jour, israel: true).first?.texte)
        if debut.utf16.count > 420 {
            #expect(contenu.halakha == debut.premieresUnites(420) + "…")
            #expect(contenu.halakha.utf16.count == 421)
        } else {
            #expect(contenu.halakha == debut)
        }
        #expect(contenu.source == Libelle("halakha_livre"))
    }

    /// Le partage ne lit pas les interrupteurs de la carte du jour : la hilloula et la halakha y sont quand même.
    @Test func lesInterrupteursDeLaCarteNeMasquentRien() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        var reglages = ZmanimEssais.reglages(ville)
        reglages.setHilloulotAffichees(false)
        reglages.setHalakhaAffichee(false)
        let masque = try await contexte(reglages)
        let visible = try await contexte(ZmanimEssais.reglages(ville))
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        #expect(PartageContenu.pour(jour, masque) == PartageContenu.pour(jour, visible))
        #expect(ZmanimVueJour.halakha(jour, masque) == nil)
    }

    /// L'omer est sur la carte du jour, pas sur l'image ; la paracha d'un Chabbat est sur les deux.
    @Test func lOmerNonLaParachaOui() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.paris)
        let c = try await contexte(ZmanimEssais.reglages(ville), fuseau: "Europe/Paris")
        let lundi = try #require(JourCivil(iso: "2027-05-03"))
        let carte = ZmanimEssais.cles(ZmanimVueJour.carte(lundi, c).marques)
        #expect(carte.contains("zmanim_omer_ce_soir"))
        let image = ZmanimEssais.cles(PartageContenu.pour(lundi, c).marques)
        #expect(!image.contains("zmanim_omer_ce_soir"))
        let chabbat = try #require(JourCivil(iso: "2026-10-17"))
        let paracha = CalendrierJuif.jour(chabbat, enIsrael: false).paracha
        let texte = try #require(paracha)
        let marques = PartageContenu.pour(chabbat, c).marques
        #expect(marques.contains(Libelle("zmanim_paracha", .texte(texte))))
    }

    /// La mise en page de l'image : 1080 × 1350, les blocs dans l'ordre d'Android, leurs tailles et leurs espaces.
    @Test func laMiseEnPageDeLImage() throws {
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let complet = PartageContenu(date: jour, dateHebraique: "א׳ חשון תשפ״ז", marques: [Libelle("fete_roch_hodech")],
                                     hilloula: "רבי א · רבי ב", halakha: "הלכה", source: Libelle("halakha_livre"))
        let blocs = PartageImage.blocs(complet)
        let tailles = blocs.map { $0.taille }
        #expect(tailles == [92, 40, 40, 30, 44, 30, 42])
        let apres = blocs.map { $0.apres }
        #expect(apres == [8, 22, 40, 6, 40, 6, 20])
        let textes = blocs.map { $0.texte }
        let attendus: [PartageBloc.Texte] = [
            .brut("א׳ חשון תשפ״ז"),
            .dateCivile(jour),
            .libelles([Libelle("fete_roch_hodech")], separateur: "  ·  "),
            .libelles([Libelle("hilloula_titre")], separateur: ""),
            .brut("רבי א · רבי ב"),
            .libelles([Libelle("halakha_yomit_titre"), Libelle("halakha_livre")], separateur: " · "),
            .brut("הלכה"),
        ]
        #expect(textes == attendus)
        let hebreux = blocs.filter { $0.police == .hebraique }.count
        #expect(hebreux == 3)
        let droiteAGauche = blocs.filter { $0.sens == .droiteAGauche }.count
        #expect(droiteAGauche == 3)
        let premier = try #require(blocs.first)
        #expect(premier.gras)
        #expect(premier.teinte == .encre)
        #expect(PartageImage.largeur == 1080)
        #expect(PartageImage.hauteur == 1350)
        #expect(PartageImage.largeurTexte == 1080 - 2 * PartageImage.marge)
        #expect(PartageImage.haut == PartageImage.marge + 40)
        #expect(PartageImage.signatureLigneDeBase == 1350 - PartageImage.marge / 2)
        #expect(PartageImage.signature == Libelle("app_name"))
        // Sans fête, sans hilloula ni halakha : la date seule.
        let nu = PartageContenu(date: jour, dateHebraique: "ב׳ חשון", marques: [], hilloula: " ", halakha: "",
                                source: nil)
        let blocsNus = PartageImage.blocs(nu)
        #expect(blocsNus.count == 2)
    }

    /// L'onglet Zmanim et le calendrier partagent le jour qu'ils montrent.
    @Test func lesEcransPartagentLeurJour() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let fuseau = try #require(Fuseau("Asia/Jerusalem"))
        let magasin = Magasin.enMemoire(Enregistrement(reglages: ZmanimEssais.reglages(ville)))
        let zmanim = ZmanimModele(magasin: magasin, horloge: HorlogeFixe(DateHeure(jour, heure: 9), fuseau: fuseau),
                                  contenus: ZmanimEssais.contenus, hilloulot: ZmanimEssais.hilloulot)
        await zmanim.apparaitre()
        zmanim.jourSuivant()
        let attendu = PartageContenu.pour(jour.plus(jours: 1), zmanim.contexte)
        #expect(zmanim.partage == attendu)
        #expect(!zmanim.partage.halakha.isEmpty)
    }
}
