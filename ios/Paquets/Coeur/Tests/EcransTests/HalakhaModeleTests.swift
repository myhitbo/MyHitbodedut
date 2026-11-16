import Foundation
import Synchronization
import Testing
import Coeur
@testable import Ecrans

/// Une horloge qu'on avance : l'écran laissé ouvert jusqu'au lendemain (onPause, puis onRestart d'Android).
/// Partagée par les tests de la halakha et des hilloulot.
final class HalakhaHorlogeReglable: Horloge {
    private let instant: Mutex<Int64>
    let fuseau: Fuseau

    init(_ dateHeure: DateHeure, fuseau: Fuseau) {
        instant = Mutex(fuseau.millis(dateHeure))
        self.fuseau = fuseau
    }

    var maintenant: Int64 {
        instant.withLock { $0 }
    }

    func avancer(heures: Int) {
        instant.withLock { $0 += Int64(heures) * 3_600_000 }
    }
}

/// Un contenu qui n'est pas celui attendu.
struct HalakhaInattendu: Error {}

/// L'écran de la halakha du jour (HalakhaActivity.kt) : ce qu'il montre un jour donné, selon le livre choisi, ce
/// que trouve sa recherche, ses réglages, et le passage au lendemain d'un écran resté ouvert, qui n'écrase pas un
/// jour choisi. Les halakhot attendues viennent des règles de Coeur, sur les livres exportés du dépôt.
@Suite("Modèle de l'écran de la halakha")
@MainActor
struct HalakhaModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private static let jerusalem = Fuseau("Asia/Jerusalem") ?? .utc

    /// Un modèle, son magasin en mémoire, sa persistance et son horloge, arrêtée à `heure` du jour `iso` à
    /// Jérusalem ; Israël réglé.
    private static func fabriquer(_ source: Reglages.SourceHalakha? = nil, iso: String = "2026-11-16", heure: Int = 10,
                                  langue: String = "fr", date: JourCivil? = nil, recherche: String? = nil,
                                  contenus: ContenusApp? = nil) throws
        -> (HalakhaModele, Magasin, PersistanceEnMemoire, HalakhaHorlogeReglable) {
        var reglages = Reglages()
        reglages.setInIsrael(true)
        if let source { reglages.setSourceHalakha(source) }
        let enregistrement = Enregistrement(reglages: reglages)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let jour = try #require(JourCivil(iso: iso))
        let horloge = HalakhaHorlogeReglable(DateHeure(jour, heure: heure), fuseau: jerusalem)
        let modele = HalakhaModele(magasin: magasin, contenus: contenus ?? Self.contenus, horloge: horloge, langue: langue,
                                   date: date, recherche: recherche)
        return (modele, magasin, persistance, horloge)
    }

    private static func duJour(_ modele: HalakhaModele) throws -> HalakhaDuJour {
        if case .jour(let du) = modele.contenu { return du }
        Issue.record("le jour attendu, et non \(modele.contenu)")
        throw HalakhaInattendu()
    }

    private static func resultats(_ modele: HalakhaModele) throws -> HalakhaResultats {
        if case .recherche(let r) = modele.contenu { return r }
        Issue.record("des résultats attendus, et non \(modele.contenu)")
        throw HalakhaInattendu()
    }

    // MARK: Le jour

    @Test func leJourMontreLeYalkutYosefParDefaut() async throws {
        let (modele, _, _, _) = try Self.fabriquer()
        #expect(modele.contenu == .chargement)
        #expect(modele.etat == .chargement)
        await modele.charger()
        #expect(modele.etat == .pret)
        #expect(modele.source == .yalkut)
        let du = try Self.duJour(modele)
        let jour = try #require(JourCivil(iso: "2026-11-16"))
        #expect(du.jour == jour)
        #expect(modele.estAujourdhui)
        let dateHebraique = CalendrierJuif.jour(jour, enIsrael: true).dateHebraique
        #expect(du.dateHebraique == dateHebraique)
        let livre = try await Self.contenus.yalkutYosef()
        let seifs = YalkutYosef.pour(livre, date: jour, israel: true)
        #expect(!seifs.isEmpty)
        let carte = try #require(du.yalkut)
        #expect(carte.titre == YalkutYosef.titreCarte(seifs))
        #expect(carte.paragraphes == HalakhaTexte.paragraphes(YalkutYosef.texteCarte(seifs)))
        // Le Ben Ish 'Haï n'est pas choisi : ni son titre ni ses cartes.
        #expect(du.benIshHai.isEmpty)
        #expect(du.benIshHaiTitre == nil)
        #expect(du.aucune == nil)
        #expect(du.yalkutSource == Libelle("halakha_yalkut_source"))
        #expect(du.note == Libelle("halakha_note"))
        #expect(du.lien.libelle == Libelle("halakha_yomit_lien"))
        #expect(du.lien.url == "https://halachayomit.co.il/fr/default.aspx")
    }

    @Test func leBenIshHaiDonneLaPartDuJourDeSaParacha() async throws {
        let (modele, _, _, _) = try Self.fabriquer(.benIshHai)
        await modele.charger()
        let du = try Self.duJour(modele)
        let jour = try #require(JourCivil(iso: "2026-11-16"))
        let livre = try await Self.contenus.benIshHai()
        let attendues = Halakha.pour(livre, date: jour, enIsrael: true)
        #expect(!attendues.isEmpty)
        #expect(du.yalkut == nil)
        #expect(du.yalkutSource == nil)
        #expect(du.benIshHaiTitre == Libelle("halakha_ben_ish_hai"))
        let titres = du.benIshHai.map { $0.titre }
        let titresAttendus = attendues.map { Halakha.source($0) }
        #expect(titres == titresAttendus)
        let textes = du.benIshHai.map { $0.paragraphes }
        let textesAttendus = attendues.map { HalakhaTexte.paragraphes($0.texte) }
        #expect(textes == textesAttendus)
        #expect(du.aucune == nil)
    }

    @Test func lesDeuxLivresMontrentLeYalkutYosefPuisLeBenIshHai() async throws {
        let (modele, _, _, _) = try Self.fabriquer(.lesDeux)
        await modele.charger()
        let du = try Self.duJour(modele)
        #expect(du.yalkut != nil)
        #expect(!du.benIshHai.isEmpty)
        #expect(du.yalkutSource != nil)
        let ids = du.benIshHai.map { $0.id } + [du.yalkut?.id ?? ""]
        #expect(Set(ids).count == ids.count)
    }

    @Test func lesFlechesChangentLeJour() async throws {
        let (modele, _, _, _) = try Self.fabriquer()
        await modele.charger()
        modele.jourSuivant()
        #expect(modele.jour.iso == "2026-11-17")
        #expect(!modele.estAujourdhui)
        let suivant = try Self.duJour(modele)
        #expect(suivant.jour.iso == "2026-11-17")
        modele.jourPrecedent()
        modele.jourPrecedent()
        #expect(modele.jour.iso == "2026-11-15")
    }

    @Test func uneDateRecueOuvreCeJour() async throws {
        let date = try #require(JourCivil(iso: "2026-12-07"))
        let (modele, _, _, _) = try Self.fabriquer(date: date)
        await modele.charger()
        let du = try Self.duJour(modele)
        #expect(du.jour == date)
        #expect(!modele.estAujourdhui)
    }

    @Test func leLienSuitLaLangueDeLApp() async throws {
        for (langue, code) in [("fr", "fr"), ("en", "en"), ("he", "he")] {
            let (modele, _, _, _) = try Self.fabriquer(langue: langue)
            await modele.charger()
            let du = try Self.duJour(modele)
            #expect(du.lien.url == "https://halachayomit.co.il/\(code)/default.aspx")
        }
    }

    @Test func desLivresIllisiblesNeMontrentAucuneHalakha() async throws {
        let vide = ContenusApp(lecteur: { _ in nil })
        let (modele, _, _, _) = try Self.fabriquer(.lesDeux, contenus: vide)
        await modele.charger()
        #expect(modele.etat == .erreur)
        let du = try Self.duJour(modele)
        #expect(du.aucune == Libelle("halakha_aucune"))
        #expect(du.yalkut == nil)
        #expect(du.benIshHai.isEmpty)
        modele.chercher("שבת")
        await modele.attendre()
        let r = try Self.resultats(modele)
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(0)))
        #expect(r.cartes.isEmpty)
    }

    // MARK: Le lendemain (bug du 02/11)

    @Test func lEcranResteOuvertPasseAuLendemain() async throws {
        let (modele, _, _, horloge) = try Self.fabriquer(heure: 23)
        await modele.charger()
        modele.suspendre()
        horloge.avancer(heures: 2)
        modele.reprendre()
        #expect(modele.jour.iso == "2026-11-17")
        #expect(modele.estAujourdhui)
    }

    @Test func unJourChoisiNEstPasEcrase() async throws {
        let (modele, _, _, horloge) = try Self.fabriquer(heure: 23)
        await modele.charger()
        modele.jourPrecedent()
        modele.suspendre()
        horloge.avancer(heures: 2)
        modele.reprendre()
        #expect(modele.jour.iso == "2026-11-15")
        // Une date reçue de la carte du jour, elle non plus.
        let date = try #require(JourCivil(iso: "2026-12-07"))
        let (recue, _, _, autre) = try Self.fabriquer(heure: 23, date: date)
        recue.suspendre()
        autre.avancer(heures: 2)
        recue.reprendre()
        #expect(recue.jour == date)
    }

    @Test func leMemeJourRienNeChange() async throws {
        let (modele, _, _, horloge) = try Self.fabriquer(heure: 9)
        modele.jourSuivant()
        modele.suspendre()
        horloge.avancer(heures: 3)
        modele.reprendre()
        #expect(modele.jour.iso == "2026-11-17")
        // Sans pause d'abord, reprendre ne fait rien.
        let (neuf, _, _, autre) = try Self.fabriquer(heure: 23)
        autre.avancer(heures: 2)
        neuf.reprendre()
        #expect(neuf.jour.iso == "2026-11-16")
    }

    // MARK: Les réglages

    @Test func lesPucesChoisissentLeLivreEtLEcrivent() async throws {
        let (modele, magasin, persistance, _) = try Self.fabriquer()
        let avant = modele.sources.map { $0.source }
        #expect(avant == [.yalkut, .benIshHai, .lesDeux])
        let libelles = modele.sources.map { $0.libelle }
        #expect(libelles == [Libelle("halakha_source_yalkut"), Libelle("halakha_source_bih"), Libelle("halakha_source_deux")])
        let choisies = modele.sources.filter { $0.choisie }.map { $0.source }
        #expect(choisies == [.yalkut])
        try await modele.choisirSource(.lesDeux)
        #expect(magasin.reglages.sourceHalakha == .lesDeux)
        let ecrit = await persistance.enregistrement.reglages.brut["halakha_source"]
        #expect(ecrit == .chaine("les_deux"))
        let apres = modele.sources.filter { $0.choisie }.map { $0.source }
        #expect(apres == [.lesDeux])
    }

    @Test func lInterrupteurReglesLaCarteDuJour() async throws {
        let (modele, magasin, persistance, _) = try Self.fabriquer()
        #expect(modele.afficheeSurLaCarteDuJour)
        try await modele.afficherSurLaCarteDuJour(false)
        #expect(!modele.afficheeSurLaCarteDuJour)
        #expect(!magasin.reglages.halakhaAffichee)
        let ecrit = await persistance.enregistrement.reglages.brut["halakha_affichee"]
        #expect(ecrit == .booleen(false))
    }

    // MARK: La recherche

    @Test func laRechercheParcourtLesLivresChoisis() async throws {
        let (modele, _, _, _) = try Self.fabriquer(recherche: "שבת")
        #expect(modele.enRecherche)
        await modele.charger()
        await modele.attendre()
        let yalkut = try await Self.contenus.yalkutYosef()
        let benIshHai = try await Self.contenus.benIshHai()
        let yy = YalkutYosef.recherche(yalkut, texte: "שבת")
        let bih = Halakha.recherche(benIshHai, texte: "שבת")
        #expect(!yy.isEmpty)
        #expect(!bih.isEmpty)

        // Le Yalkut Yosef seul, par défaut : quarante cartes au plus, toutes les trouvailles comptées.
        let seul = try Self.resultats(modele)
        #expect(seul.nombre == Libelle("hilloulot_resultats", .entier(yy.count)))
        let titres = seul.cartes.map { $0.titre }
        let titresAttendus = yy.prefix(HalakhaModele.resultatsMontres).map { YalkutYosef.source($0) }
        #expect(titres == titresAttendus)

        // Les deux : le Yalkut Yosef, puis le Ben Ish 'Haï.
        try await modele.choisirSource(.lesDeux)
        await modele.attendre()
        let deux = try Self.resultats(modele)
        #expect(deux.nombre == Libelle("hilloulot_resultats", .entier(yy.count + bih.count)))
        let attendus = yy.prefix(40).map { YalkutYosef.source($0) } + bih.prefix(40).map { Halakha.source($0) }
        let obtenus = deux.cartes.map { $0.titre }
        #expect(obtenus == attendus)
        let textes = deux.cartes.map { $0.paragraphes }
        let textesAttendus = yy.prefix(40).map { HalakhaTexte.paragraphes($0.texte) }
            + bih.prefix(40).map { HalakhaTexte.paragraphes($0.texte) }
        #expect(textes == textesAttendus)
        let ids = deux.cartes.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test func moinsDeDeuxUnitesRamenentLeJour() async throws {
        let (modele, _, _, _) = try Self.fabriquer()
        await modele.charger()
        modele.chercher(" ש ")
        #expect(!modele.enRecherche)
        _ = try Self.duJour(modele)
        modele.chercher("שבת")
        await modele.attendre()
        _ = try Self.resultats(modele)
        modele.chercher("")
        _ = try Self.duJour(modele)
    }

    @Test func seuleLaDerniereRechercheSAffiche() async throws {
        let (modele, _, _, _) = try Self.fabriquer(.lesDeux)
        await modele.charger()
        modele.chercher("שבת")
        modele.chercher("תפילין")
        await modele.attendre()
        let r = try Self.resultats(modele)
        let yalkut = try await Self.contenus.yalkutYosef()
        let benIshHai = try await Self.contenus.benIshHai()
        let n = YalkutYosef.recherche(yalkut, texte: "תפילין").count + Halakha.recherche(benIshHai, texte: "תפילין").count
        #expect(r.nombre == Libelle("hilloulot_resultats", .entier(n)))
    }

    // MARK: Les paragraphes (VueJour.paragraphes)

    @Test func lesParagraphesSeCoupentAuxRetoursALaLigne() {
        #expect(HalakhaTexte.paragraphes("א\n\n ב \n\nג\n") == ["א", "ב", "ג"])
        #expect(HalakhaTexte.paragraphes("  seul  ") == ["seul"])
        #expect(HalakhaTexte.paragraphes("seul\n\n") == ["seul"])
        #expect(HalakhaTexte.paragraphes("") == [""])
        #expect(HalakhaTexte.paragraphes("un\ndeux") == ["un", "deux"])
    }
}
