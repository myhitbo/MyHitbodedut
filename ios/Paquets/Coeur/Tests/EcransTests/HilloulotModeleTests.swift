import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran des hilloulot (HilloulotActivity.kt) : le jour et ses tsadikim, les mieux connus d'abord ; la hilloula
/// seule d'un jour s'ouvre d'office, avec sa notice, sa biographie et sa source ; la recherche par date de l'année
/// et « Voir ce jour » ; le passage au lendemain d'un écran resté ouvert. Les attendus viennent des règles de Coeur
/// (Hilloulot.swift), sur les contenus exportés du dépôt.
@Suite("Modèle de l'écran des hilloulot")
@MainActor
struct HilloulotModeleTests {

    private static let contenus = HilloulotContenus(dossier: Fichiers.contenu)

    private static let jerusalem = Fuseau("Asia/Jerusalem") ?? .utc

    private static func fabriquer(iso: String = "2026-11-16", heure: Int = 10, langue: String = "fr",
                                  date: JourCivil? = nil, recherche: String? = nil,
                                  contenus: HilloulotContenus? = nil) throws
        -> (HilloulotModele, Magasin, PersistanceEnMemoire, HalakhaHorlogeReglable) {
        var reglages = Reglages()
        reglages.setInIsrael(true)
        let enregistrement = Enregistrement(reglages: reglages)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let jour = try #require(JourCivil(iso: iso))
        let horloge = HalakhaHorlogeReglable(DateHeure(jour, heure: heure), fuseau: jerusalem)
        let modele = HilloulotModele(magasin: magasin, contenus: contenus ?? Self.contenus, horloge: horloge,
                                     langue: langue, date: date, recherche: recherche)
        return (modele, magasin, persistance, horloge)
    }

    private static func duJour(_ modele: HilloulotModele) throws -> HilloulotDuJour {
        if case .jour(let du) = modele.contenu { return du }
        Issue.record("le jour attendu, et non \(modele.contenu)")
        throw HalakhaInattendu()
    }

    private static func resultats(_ modele: HilloulotModele) throws -> HilloulotResultats {
        if case .recherche(let r) = modele.contenu { return r }
        Issue.record("des résultats attendus, et non \(modele.contenu)")
        throw HalakhaInattendu()
    }

    /// Le 27 Adar I 5787 (en Israël, noussa'h non ashkénaze) : un seul tsadik, רבי יוסף שאול נתנזון, sa notice de
    /// Wikipédia, son article, et une longue biographie de MyTzadik (695 unités).
    private static func jourDeNathanson() throws -> JourCivil {
        let depuis = try #require(JourCivil(iso: "2026-11-16"))
        return try #require(Hilloulot.prochainJour("adar1-27", depuis: depuis, enIsrael: true))
    }

    // MARK: Le critère : la hilloula du jour s'ouvre avec sa biographie et sa source

    @Test func laHilloulaSeuleDuJourSOuvreAvecSaBiographieEtSaSource() async throws {
        let date = try Self.jourDeNathanson()
        let (modele, _, _, _) = try Self.fabriquer(date: date)
        #expect(modele.contenu == .chargement)
        await modele.charger()
        await modele.attendre()
        #expect(modele.etat == .pret)
        let du = try Self.duJour(modele)
        #expect(du.jour == date)
        let table = try await Self.contenus.avecBios(pour: Hilloulot.clesPour(date, enIsrael: true))
        let attendues = Hilloulot.pour(table, date: date, enIsrael: true)
        try #require(attendues.count == 1)
        let h = attendues[0]
        let bio = try #require(h.bios.first)
        #expect(bio.texte.utf16.count > HilloulotModele.bioLongue)

        #expect(du.lignes.count == 1)
        let ligne = try #require(du.lignes.first)
        // La police par défaut (« serif ») : ses signes absents masqués, comme PoliceHebraique.appliquer d'Android.
        #expect(ligne.nom == PoliceHebraique.masque(h.he, police: .serif))
        #expect(ligne.premiere)
        #expect(ligne.depliable)
        // Seule ce jour-là : dépliée d'office.
        #expect(ligne.ouverte)
        #expect(ligne.action == Libelle("hilloula_reduire"))
        let deces: Libelle? = h.annee.estBlanc ? nil : Libelle("hilloula_annee", .texte("\u{2068}\(h.annee)\u{2069}"))
        #expect(ligne.deces == deces)
        // Un seul tsadik : le nombre, sans « Touchez un nom ».
        #expect(du.entete == [Libelle.pluriel("hilloulot_nombre", quantite: 1, .entier(1))])
        #expect(du.aucune == nil)

        let fiche = try #require(ligne.fiche)
        let notice = h.description.map { HalakhaTexte.paragraphes(PoliceHebraique.masque($0, police: .serif)) }
        #expect(fiche.description == notice)
        #expect(notice != nil)
        // La source de la notice : Wikipédia, avec le lien de l'article.
        let noms = fiche.sources.map { $0.nom }
        #expect(noms == [Libelle("hilloula_source_wiki")])
        let lienWiki = fiche.sources.first?.lien
        let lienArticle = h.article.map { Hilloulot.lienArticle($0) }
        #expect(lienWiki == lienArticle)
        #expect(lienArticle != nil)
        // La biographie, mot pour mot, suivie de sa source et de son lien.
        #expect(fiche.bios.count == h.bios.count)
        let premiere = try #require(fiche.bios.first)
        #expect(premiere.paragraphes == HalakhaTexte.paragraphes(PoliceHebraique.masque(bio.texte, police: .serif)))
        #expect(premiere.source.nom == Libelle("hilloula_source_mytzadik"))
        #expect(premiere.source.lien == bio.lien)
        #expect(premiere.longue)
        #expect(premiere.repliee)
        #expect(premiere.bouton == Libelle("hilloula_lire_plus"))
        #expect(fiche.hidabroot == nil)

        // « Lire la suite », puis « Réduire ».
        modele.basculer(bio: premiere)
        let apresLecture = try Self.duJour(modele).lignes.first?.fiche?.bios.first
        let deplie = try #require(apresLecture)
        #expect(!deplie.repliee)
        #expect(deplie.bouton == Libelle("hilloula_reduire"))
        modele.basculer(bio: deplie)
        let apresReduction = try Self.duJour(modele).lignes.first?.fiche?.bios.first
        let replie = try #require(apresReduction)
        #expect(replie.repliee)

        // Le nom touché replie la fiche.
        modele.basculer(ligne)
        let apresToucher = try Self.duJour(modele).lignes.first
        let fermee = try #require(apresToucher)
        #expect(!fermee.ouverte)
        #expect(fermee.fiche == nil)
        #expect(fermee.action == Libelle("hilloula_lire_plus"))
    }

    @Test func lesSignesAbsentsDeLaPoliceSontMasques() async throws {
        // PoliceHebraique.appliquer d'Android : le meteg (U+05BD), absent de la police par défaut, devient U+034F dans
        // le nom et la notice ; la clé du dépliage garde le nom tel quel.
        let json = "{\"jours\":{\"7-1\":[{\"he\":\"רבי\u{05BD} א\",\"a\":\"\",\"s\":\"w\",\"t\":\"נוסח\u{05BD}\"}]}}"
        let contenus = HilloulotContenus(lecteur: { chemin in chemin == "hilloulot.json" ? Data(json.utf8) : nil })
        let depuis = try #require(JourCivil(iso: "2026-11-16"))
        let date = try #require(Hilloulot.prochainJour("7-1", depuis: depuis, enIsrael: true))
        let (modele, _, _, _) = try Self.fabriquer(date: date, contenus: contenus)
        await modele.charger()
        await modele.attendre()
        let du = try Self.duJour(modele)
        let ligne = try #require(du.lignes.first)
        #expect(ligne.nom == "רבי\u{034F} א")
        #expect(ligne.cle == "\(date.iso)|רבי\u{05BD} א")
        #expect(ligne.ouverte)
        let fiche = try #require(ligne.fiche)
        #expect(fiche.description == ["נוסח\u{034F}"])
    }

    @Test func plusieursTsadikimRestentFermesDansLOrdreDeCoeur() async throws {
        let (modele, _, _, _) = try Self.fabriquer()
        await modele.charger()
        await modele.attendre()
        let du = try Self.duJour(modele)
        let jour = try #require(JourCivil(iso: "2026-11-16"))
        let table = try await Self.contenus.table()
        let attendues = Hilloulot.pour(table, date: jour, enIsrael: true)
        let noms = du.lignes.map { $0.nom }
        let nomsAttendus = attendues.map { $0.he }
        #expect(noms == nomsAttendus)
        let premieres = du.lignes.filter { $0.premiere }.count
        #expect(premieres == (attendues.isEmpty ? 0 : 1))
        if attendues.count > 1 {
            let ouvertes = du.lignes.filter { $0.ouverte }.count
            #expect(ouvertes == 0)
            #expect(du.entete.first == Libelle.pluriel("hilloulot_nombre", quantite: attendues.count, .entier(attendues.count)))
        }
        let ids = du.lignes.map { $0.id }
        #expect(Set(ids).count == ids.count)
        #expect(du.dateHebraique == CalendrierJuif.jour(jour, enIsrael: true).dateHebraique)
        #expect(du.lien.url == Hilloulot.lienHyomi(jour))
        #expect(du.lien.libelle == Libelle("hilloula_lien"))
        // Aujourd'hui : pas de bouton « Aujourd'hui ».
        #expect(du.aujourdhui == nil)
    }

    @Test func unNomToucheSeDeplie() async throws {
        // Le 27 Adar II 5787 : les clés « adar-27 » et « adar2-27 » (hors noussa'h ashkénaze), quatorze tsadikim, dont
        // plusieurs à notice.
        let depuis = try #require(JourCivil(iso: "2026-11-16"))
        let date = try #require(Hilloulot.prochainJour("adar-27", depuis: depuis, enIsrael: true))
        let (modele, _, _, _) = try Self.fabriquer(date: date)
        await modele.charger()
        await modele.attendre()
        let du = try Self.duJour(modele)
        #expect(du.lignes.count > 1)
        #expect(du.entete.last == Libelle("hilloulot_toucher"))
        let depliable = du.lignes.first(where: { $0.depliable })
        let ligne = try #require(depliable)
        #expect(!ligne.ouverte)
        #expect(ligne.fiche == nil)
        modele.basculer(ligne)
        let apres = try Self.duJour(modele).lignes.first(where: { $0.id == ligne.id })
        let ouverte = try #require(apres)
        #expect(ouverte.ouverte)
        #expect(ouverte.fiche != nil)
        // Une ligne sans rien à déplier ne bouge pas.
        if let simple = du.lignes.first(where: { !$0.depliable }) {
            modele.basculer(simple)
            let ensuite = try Self.duJour(modele).lignes.first(where: { $0.id == simple.id })
            let toujours = try #require(ensuite)
            #expect(!toujours.ouverte)
            #expect(toujours.action == nil)
        }
    }

    @Test func leNomTraduitSuitLaLangue() async throws {
        let date = try Self.jourDeNathanson()
        let table = try await Self.contenus.table()
        let h = try #require(Hilloulot.pour(table, date: date, enIsrael: true).first)
        let cas: [(String, String?)] = [("fr", h.fr ?? h.en), ("en", h.en), ("he", nil)]
        for (langue, attendu) in cas {
            let (modele, _, _, _) = try Self.fabriquer(langue: langue, date: date)
            await modele.charger()
            let traduit = try Self.duJour(modele).lignes.first?.traduit
            let blanc = attendu?.estBlanc ?? true
            #expect(traduit == (blanc ? nil : attendu), "\(langue)")
        }
    }

    // MARK: Le jour

    @Test func lesFlechesEtAujourdhui() async throws {
        let (modele, _, _, _) = try Self.fabriquer()
        await modele.charger()
        modele.jourSuivant()
        #expect(modele.jour.iso == "2026-11-17")
        let ailleurs = try Self.duJour(modele).aujourdhui
        #expect(ailleurs == Libelle("calendrier_aujourdhui"))
        modele.jourPrecedent()
        modele.jourPrecedent()
        #expect(modele.jour.iso == "2026-11-15")
        modele.revenirAujourdhui()
        #expect(modele.jour.iso == "2026-11-16")
        let revenu = try Self.duJour(modele).aujourdhui
        #expect(revenu == nil)
    }

    @Test func lEcranResteOuvertPasseAuLendemainSansEcraserUnJourChoisi() async throws {
        let (modele, _, _, horloge) = try Self.fabriquer(heure: 23)
        await modele.charger()
        modele.suspendre()
        horloge.avancer(heures: 2)
        modele.reprendre()
        #expect(modele.jour.iso == "2026-11-17")

        let (choisi, _, _, autre) = try Self.fabriquer(heure: 23)
        await choisi.charger()
        choisi.jourPrecedent()
        choisi.suspendre()
        autre.avancer(heures: 2)
        choisi.reprendre()
        #expect(choisi.jour.iso == "2026-11-15")
    }

    @Test func uneTableIllisibleNeMontreAucuneHilloula() async throws {
        let vide = HilloulotContenus(lecteur: { _ in nil })
        let (modele, _, _, _) = try Self.fabriquer(contenus: vide)
        await modele.charger()
        #expect(modele.etat == .erreur)
        let du = try Self.duJour(modele)
        #expect(du.aucune == Libelle("hilloulot_aucune"))
        #expect(du.lignes.isEmpty)
        #expect(du.entete.isEmpty)
    }

    // MARK: Les réglages

    @Test func lInterrupteurReglesLaCarteDuJour() async throws {
        let (modele, magasin, persistance, _) = try Self.fabriquer()
        #expect(modele.afficheesSurLaCarteDuJour)
        try await modele.afficherSurLaCarteDuJour(false)
        #expect(!magasin.reglages.hilloulotAffichees)
        let ecrit = await persistance.enregistrement.reglages.brut["hilloulot_affichees"]
        #expect(ecrit == .booleen(false))
    }

    // MARK: La recherche

    @Test func laRechercheRangeParDateEtMeneAuJour() async throws {
        let (modele, _, _, _) = try Self.fabriquer(recherche: "נחמן")
        #expect(modele.enRecherche)
        await modele.charger()
        await modele.attendre()
        let table = try await Self.contenus.table()
        let trouvees = Hilloulot.recherche(table, texte: "נחמן")
        #expect(!trouvees.isEmpty)
        let r = try Self.resultats(modele)
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(trouvees.count)))
        // Les dates, dans l'ordre de leur première apparition parmi les soixante premières.
        var cles: [String] = []
        for t in trouvees.prefix(HilloulotModele.resultatsMontres) where !cles.contains(t.cle) {
            cles.append(t.cle)
        }
        let obtenues = r.groupes.map { $0.cle }
        #expect(obtenues == cles)
        let dates = r.groupes.map { $0.date }
        let datesAttendues = cles.map { Hilloulot.dateDe($0) }
        #expect(dates == datesAttendues)
        let montres = r.groupes.reduce(0) { $0 + $1.lignes.count }
        #expect(montres == min(trouvees.count, HilloulotModele.resultatsMontres))
        // Dans la recherche, rien ne s'ouvre d'office.
        let ouvertes = r.groupes.flatMap { $0.lignes }.filter { $0.ouverte }.count
        #expect(ouvertes == 0)

        // « Voir ce jour › » : le prochain jour de cette date, ses tsadikim dépliés, le champ vidé.
        let groupe = try #require(r.groupes.first)
        #expect(groupe.voir == Libelle("hilloulot_ouvrir_jour"))
        let depuis = try #require(JourCivil(iso: "2026-11-16"))
        let attendu = try #require(Hilloulot.prochainJour(groupe.cle, depuis: depuis, enIsrael: true))
        modele.voirLeJour(groupe)
        #expect(modele.recherche == "")
        #expect(modele.jour == attendu)
        #expect(modele.retourEnHaut == 1)
        await modele.attendre()
        let du = try Self.duJour(modele)
        for l in groupe.lignes where l.depliable {
            let ligne = du.lignes.first(where: { $0.nom == l.nom })
            let ouverte = ligne?.ouverte ?? false
            #expect(ouverte, "\(l.nom)")
        }
    }

    @Test func moinsDeDeuxUnitesRamenentLeJour() async throws {
        let (modele, _, _, _) = try Self.fabriquer()
        await modele.charger()
        modele.chercher("נחמן")
        await modele.attendre()
        _ = try Self.resultats(modele)
        modele.chercher(" נ ")
        #expect(!modele.enRecherche)
        _ = try Self.duJour(modele)
    }

    @Test func seuleLaDerniereRechercheSAffiche() async throws {
        let (modele, _, _, _) = try Self.fabriquer()
        await modele.charger()
        modele.chercher("נחמן")
        modele.chercher("אלישיב")
        await modele.attendre()
        let r = try Self.resultats(modele)
        let table = try await Self.contenus.table()
        let n = Hilloulot.recherche(table, texte: "אלישיב").count
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(n)))
    }
}
