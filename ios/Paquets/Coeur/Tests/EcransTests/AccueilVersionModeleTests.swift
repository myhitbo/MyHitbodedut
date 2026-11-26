import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les accueils des versions (AccueilVersion.kt, SereniteActivity.kt, BentoActivity.kt, InstantActivity.kt,
/// PileActivity.kt) : les données lues d'un coup (DonneesAccueil.lire), ce que chaque version en montre, et les gestes
/// communs. Avec AccueilProchainTest, AccueilSoirTest, AccueilNoteTest et BilanPartoutTest d'Android (22-24/11). Restent
/// au test d'interface : le paysage peint, les animations (cascade, anneau, égaliseur, retournement, jauge, barres), les
/// polices.
@Suite("Modèle des accueils des versions")
@MainActor
struct AccueilVersionModeleTests {

    /// Lundi 16 novembre 2026.
    static let lundi = "2026-11-16"
    static let contenus = ContenusApp(dossier: Fichiers.contenu)
    static let jerusalem = Zmanim.Lieu(nom: "Jérusalem", latitude: 31.778, longitude: 35.2354, fuseau: "UTC")

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    struct Banc {
        let modele: AccueilVersionModele
        let magasin: Magasin
        let persistance: PersistanceEnMemoire
        let systeme: FauxAccueilSysteme
        let aujourdhui: JourCivil
    }

    func banc(_ journal: Journal = Journal(), _ reglages: Reglages = Reglages(), heure: Int = 10, minute: Int = 0,
              langue: String = "fr", presentationVue: Bool = true) throws -> Banc {
        var r = reglages
        if presentationVue { r.setOnboarded() }
        let enregistrement = Enregistrement(journal: journal, reglages: r)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let date = try Self.jour(Self.lundi)
        let horloge = HorlogeFixe(DateHeure(date, heure: heure, minute: minute), fuseau: .utc)
        let systeme = FauxAccueilSysteme()
        let modele = AccueilVersionModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: langue,
                                          systeme: systeme)
        return Banc(modele: modele, magasin: magasin, persistance: persistance, systeme: systeme, aujourdhui: date)
    }

    static func journal(_ seances: [(String, Int)], notes: [(String, String)] = []) throws -> Journal {
        var j = Journal()
        for (iso, minutes) in seances {
            j.addSession(minutes: minutes, date: try jour(iso))
        }
        for (iso, note) in notes {
            j.setNote(date: try jour(iso), note: note)
        }
        return j
    }

    // MARK: Les données communes

    @Test func lesTextesCommuns() throws {
        #expect(DonneesAccueil.duree(20) == Libelle("version_duree_min", .entier(20)))
        #expect(DonneesAccueil.duree(65) == Libelle("version_duree_h", .entier(1), .entier(5)))
        let d = try banc().modele.donnees
        #expect(d.jour(d.aujourdhui) == .libelle(Libelle("version_aujourdhui")))
        #expect(d.jour(d.aujourdhui.plus(jours: -1)) == .libelle(Libelle("version_hier")))
        let avant = d.aujourdhui.plus(jours: -2)
        #expect(d.jour(avant) == .date(avant))
        // « dans 1 h 12 », « dans 5 min », jamais négatif.
        let z = VersionZman(cle: "chkia", nom: Libelle("zman_chkia"), heure: "11:12", instant: d.maintenant + 72 * 60_000)
        #expect(d.dans(z) == Libelle("version_dans_h", .entier(1), .entier(12)))
        let proche = VersionZman(cle: "chkia", nom: Libelle("zman_chkia"), heure: "", instant: d.maintenant + 5 * 60_000 + 59_000)
        #expect(d.dans(proche) == Libelle("version_dans_min", .entier(5)))
        // Jamais « dans 0 min » (recette du 22/11) : la dernière minute, et l'heure passée, disent une minute.
        let passe = VersionZman(cle: "netz", nom: Libelle("zman_netz"), heure: "", instant: d.maintenant - 60_000)
        #expect(d.dans(passe) == Libelle("version_dans_min", .entier(1)))
        let derniere = VersionZman(cle: "chkia", nom: Libelle("zman_chkia"), heure: "", instant: d.maintenant + 20_000)
        #expect(d.dans(derniere) == Libelle("version_dans_min", .entier(1)))
    }

    /// AccueilProchainTest d'Android : les minutes entières jusqu'au zman, jamais moins d'une.
    @Test func lesMinutesJusquAuZmanJamaisZero() {
        func a(_ h: Int, _ m: Int, _ sec: Int = 0) -> Int64 {
            Int64(((h * 60 + m) * 60 + sec) * 1000)
        }
        // Les minutes entières, comme avant.
        #expect(DonneesAccueil.minutesAvant(maintenant: a(10, 32, 30), instant: a(10, 40)) == 7)
        #expect(DonneesAccueil.minutesAvant(maintenant: a(10, 32), instant: a(10, 40)) == 8)
        #expect(DonneesAccueil.minutesAvant(maintenant: a(9, 28), instant: a(10, 40)) == 72)
        // Dans la dernière minute, une minute, jamais zéro.
        #expect(DonneesAccueil.minutesAvant(maintenant: a(10, 39, 1), instant: a(10, 40)) == 1)
        #expect(DonneesAccueil.minutesAvant(maintenant: a(10, 39, 59), instant: a(10, 40)) == 1)
        #expect(DonneesAccueil.minutesAvant(maintenant: a(10, 38, 30), instant: a(10, 40)) == 1)
        // Un écran resté ouvert après l'heure : pas de minutes négatives.
        #expect(DonneesAccueil.minutesAvant(maintenant: a(10, 45), instant: a(10, 40)) == 1)
    }

    @Test func sansLieuNiPrenom() throws {
        let d = try banc().modele.donnees
        #expect(d.salutation == Libelle("pile_titre"))
        #expect(d.lieu == nil)
        #expect(d.zmanim.isEmpty)
        #expect(d.prochain == nil)
        // La date hébraïque du jour civil, isolée pour garder son ordre de droite à gauche.
        let hebraique = CalendrierJuif.jour(try Self.jour(Self.lundi), enIsrael: false).dateHebraique
        #expect(d.dateHebraique == "\u{2067}" + hebraique + "\u{2069}")
        #expect(d.ligneDate == [.date(try Self.jour(Self.lundi)), .brut("\u{2067}" + hebraique + "\u{2069}")])
        #expect(d.libelleSerie == Libelle.pluriel("version_serie", quantite: 0, .entier(0)))
        #expect(d.libelleCommencer == Libelle("version_commencer", .libelle(DonneesAccueil.duree(15))))
        #expect(d.derniereNote == nil)
    }

    @Test func laSalutationSuitLHeure() throws {
        var j = Journal()
        j.setFirstName("Avraham")
        #expect(try banc(j, heure: 9).modele.donnees.salutation
                == Libelle("hero_greeting_morning", .texte("Avraham")))
        #expect(try banc(j, heure: 20).modele.donnees.salutation
                == Libelle("hero_greeting_evening", .texte("Avraham")))
    }

    @Test func lesReperesDuJourEtLeProchain() throws {
        var r = Reglages()
        r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
        let d = try banc(Journal(), r, heure: 10).modele.donnees
        #expect(d.lieu == "Jérusalem")
        #expect(d.zmanim.map(\.cle) == DonneesAccueil.reperes)
        // Chaque heure en « HH:mm », à l'heure du lieu.
        for z in d.zmanim {
            #expect(z.heure.count == 5 && z.heure.dropFirst(2).first == ":", "\(z.cle) : \(z.heure)")
            #expect(z.nom == Libelle("zman_" + z.cle))
        }
        // À 10 h, le prochain est le premier zman encore à venir (pas forcément un repère).
        let prochain = try #require(d.prochain)
        #expect(prochain.instant > d.maintenant)
        #expect(prochain.cle != "chatsot_layla")
        // Le lever est passé, la chki'a à venir.
        let netz = try #require(d.zmanim.first { $0.cle == "netz" })
        let chkia = try #require(d.zmanim.first { $0.cle == "chkia" })
        #expect(netz.instant < d.maintenant)
        #expect(chkia.instant > d.maintenant)
    }

    @Test func troisEtatsDuBouton() throws {
        let aFaire = try banc().modele
        #expect(aFaire.donnees.libelleCommencer == Libelle("version_commencer", .libelle(DonneesAccueil.duree(15))))
        aFaire.commencerSeance()
        aFaire.preparerSeance()
        #expect(aFaire.routes == [.seance(demarrer: true), .seance(demarrer: false)])

        let faite = try banc(Self.journal([(Self.lundi, 20)])).modele
        #expect(faite.donnees.libelleCommencer == Libelle("version_encore"))
        #expect(faite.donnees.faite)
        #expect(faite.donnees.minutesAujourdhui == 20)

        var r = Reglages()
        let date = try Self.jour(Self.lundi)
        Store.beginSession(reglages: &r, minutes: 15, millis: Fuseau.utc.millis(DateHeure(date, heure: 9, minute: 55)))
        let enCours = try banc(Journal(), r).modele
        #expect(enCours.donnees.enCours)
        #expect(enCours.donnees.libelleCommencer == Libelle("version_reprendre"))
        enCours.commencerSeance()
        #expect(enCours.routes == [.seance(demarrer: false)])
    }

    @Test func laDerniereNote() throws {
        // Une note seule compte ; la plus récente l'emporte ; une journée sans note n'a pas de texte.
        let j = try Self.journal([("2026-11-12", 25), ("2026-11-14", 10)], notes: [("2026-11-13", "Merci")])
        let n = try #require(try banc(j).modele.donnees.derniereNote)
        #expect(n.date == (try Self.jour("2026-11-14")))
        #expect(n.minutes == 10)
        #expect(!n.ecrite)
        // Décision du 24/11 (AccueilNoteTest) : seulement qu'une note existe, jamais son texte.
        let avecNote = try Self.journal([("2026-11-12", 25)], notes: [("2026-11-15", "  Une ligne  ")])
        let m = try #require(try banc(avecNote).modele.donnees.derniereNote)
        #expect(m.date == (try Self.jour("2026-11-15")))
        #expect(m.ecrite)
        #expect(m == VersionNote(date: try Self.jour("2026-11-15"), minutes: 0, ecrite: true))
    }

    /// AccueilNoteTest d'Android : aucun des quatre accueils n'écrit le texte d'une note, chacun dit qu'elle existe.
    @Test func aucunAccueilNEcritLeTexteDUneNote() throws {
        let j = try Self.journal([("2026-11-15", 12), (Self.lundi, 20)], notes: [(Self.lundi, "Secret du jour")])
        let m = try banc(j).modele
        let ecrite = Libelle("version_note_ecrite")
        #expect(m.bento.journal.texte == ecrite)
        #expect(m.pile.journal.texte == ecrite)
        #expect(m.instant.journal.noteEcrite)
        #expect(m.serenite.jours.first?.noteEcrite == true)
        let tout = "\(m.bento)\(m.pile)\(m.instant)\(m.serenite)\(m.donnees)"
        #expect(!tout.contains("Secret du jour"))
    }

    @Test func lesGestesCommuns() throws {
        let m = try banc().modele
        m.ouvrirZmanim()
        m.ouvrirJournal()
        m.ouvrirTextes()
        m.ouvrirSiddour()
        m.ouvrirTehilim()
        m.ouvrirChizuk()
        m.ouvrirMusique()
        m.ouvrirReglages()
        m.ouvrirParcours()
        m.ouvrirRecherche()
        m.ecrireNote()
        #expect(m.routes == [.zmanim, .journal, .textes, .siddour, .tehilim, .chizuk, .musique, .reglages, .parcours,
                             .recherche, .note(try Self.jour(Self.lundi))])
        m.routeOuverte()
        #expect(m.routes.first == .journal)
    }

    // MARK: Le retour sur l'accueil

    @Test func presentationPuisBravo() async throws {
        var r = Reglages()
        r.setPendingCelebration(minutes: 20, dateNote: Self.lundi)
        let b = try banc(Self.journal([(Self.lundi, 20)]), r, presentationVue: false)
        let m = b.modele
        #expect(m.donnees.pensee == nil)
        await m.apparaitre()
        #expect(m.routes == [.presentation, .celebration(minutes: 20, dateNote: Self.lundi)])
        #expect(!b.magasin.reglages.hasPendingCelebration)
        let ecrit = await b.persistance.enregistrement.reglages.hasPendingCelebration
        #expect(!ecrit)
        #expect(await b.systeme.etatsAppliques == 1)
        #expect(await b.systeme.vignettesRafraichies == 1)
        // Le texte du jour est lu : l'hébreu, la traduction française, la référence.
        let p = try #require(m.donnees.pensee)
        #expect(!p.hebreu.isEmpty)
        #expect(!p.reference.isEmpty)
        // Au retour, la présentation (déjà demandée) ne revient pas.
        m.routeOuverte()
        m.routeOuverte()
        await m.apparaitre()
        #expect(m.routes.isEmpty)
        #expect(await b.systeme.etatsAppliques == 2)
    }

    @Test func laTraductionSuitLaLangueDeLApp() async throws {
        let he = try banc(langue: "he").modele
        await he.apparaitre()
        #expect(he.donnees.pensee?.traduction == nil)
        // Les langues de lecture (relecture du 23/11) : en espagnol et en arabe tunisien l'hébreu seul, et non plus
        // le français ; un choix « hébreu seul » est respecté.
        for langue in ["es", "ar"] {
            let m = try banc(langue: langue).modele
            await m.apparaitre()
            #expect(m.donnees.pensee != nil)
            #expect(m.donnees.pensee?.traduction == nil, "\(langue)")
        }
        var seul = Reglages()
        seul.setLectureLangues(LanguesTexte.Mode.he.rawValue)
        let hebreuSeul = try banc(Journal(), seul, langue: "fr").modele
        await hebreuSeul.apparaitre()
        #expect(hebreuSeul.donnees.pensee != nil)
        #expect(hebreuSeul.donnees.pensee?.traduction == nil)
        let en = try banc(langue: "en").modele
        await en.apparaitre()
        let fr = try banc(langue: "fr").modele
        await fr.apparaitre()
        // Le même paragraphe, le même jour ; l'anglais et le français diffèrent s'ils existent tous deux.
        #expect(en.donnees.pensee?.hebreu == fr.donnees.pensee?.hebreu)
        if let a = en.donnees.pensee?.traduction, let b = fr.donnees.pensee?.traduction {
            #expect(a != b)
        }
    }

    // MARK: Sérénité

    @Test func sereniteLeSoirEtLeMatin() throws {
        let soir = try banc(heure: 22).modele.serenite
        #expect(soir.nuit)
        #expect(soir.etiquette == Libelle("serenite_ce_soir"))
        #expect(soir.titre == Libelle("pile_titre"))
        #expect(soir.initiale == nil)
        let matin = try banc(heure: 10).modele.serenite
        #expect(!matin.nuit)
        #expect(matin.phase == .jour)
        #expect(matin.etiquette == Libelle("serenite_aujourdhui"))
        let objectif = Libelle("serenite_titre", .libelle(DonneesAccueil.duree(15)))
        #expect(matin.titreCarte == objectif)
        #expect(matin.accessibiliteCarte == Libelle("serenite_ouvrir", .libelle(objectif)))
        #expect(matin.titreZmanim == Libelle("pile_zmanim"))
        #expect(matin.prochain == nil)
        #expect(matin.jours.isEmpty)
        // La date, la date hébraïque, puis la série.
        #expect(matin.ligne.count == 3)
        #expect(matin.ligne.last == .libelle(Libelle.pluriel("version_serie", quantite: 0, .entier(0))))
    }

    @Test func sereniteFaiteEtDerniersJours() throws {
        var j = try Self.journal([("2026-11-12", 25), ("2026-11-13", 30), ("2026-11-15", 12), (Self.lundi, 20)],
                                 notes: [("2026-11-15", "Une ligne"), ("2026-11-14", "Note seule")])
        j.setFirstName("rivka")
        let s = try banc(j).modele.serenite
        #expect(s.etiquette == Libelle("serenite_faite"))
        #expect(s.titreCarte == Libelle("serenite_titre", .libelle(DonneesAccueil.duree(20))))
        // La carte se lit toujours avec la durée de la prochaine.
        #expect(s.accessibiliteCarte == Libelle("serenite_ouvrir",
                                                .libelle(Libelle("serenite_titre", .libelle(DonneesAccueil.duree(15))))))
        #expect(s.initiale == "R")
        // Les trois dernières journées faites ; la note seule n'en est pas une.
        #expect(s.jours.map(\.date) == [try Self.jour(Self.lundi), try Self.jour("2026-11-15"), try Self.jour("2026-11-13")])
        #expect(s.jours.map(\.noteEcrite) == [false, true, false])
        #expect(s.jours.first?.jour == .libelle(Libelle("version_aujourdhui")))
        #expect(s.jours[1].duree == DonneesAccueil.duree(12))
    }

    @Test func sereniteEnCours() throws {
        var r = Reglages()
        let date = try Self.jour(Self.lundi)
        Store.beginSession(reglages: &r, minutes: 15, millis: Fuseau.utc.millis(DateHeure(date, heure: 21, minute: 55)))
        let s = try banc(Journal(), r, heure: 22).modele.serenite
        #expect(s.etiquette == Libelle("serenite_en_cours"))
    }

    @Test func leReglageDeLaMusique() throws {
        var silence = Reglages()
        silence.setMusicEnabled(false)
        #expect(try banc(Journal(), silence).modele.serenite.reglage == [.libelle(Libelle("ambiance_silence"))])
        var pluie = Reglages()
        pluie.setAmbiance("pluie")
        let morceau = try #require(MusicLibrary.selected(MusiqueRegles.etat(pluie)))
        let titre: VersionTexte
        switch morceau.title {
        case .nom(let nom): titre = .brut(nom)
        case .libelle(let libelle): titre = .libelle(libelle)
        }
        #expect(try banc(Journal(), pluie).modele.serenite.reglage == [.libelle(Libelle("ambiance_pluie")), titre])
        // Le silence se tait quand un morceau joue.
        #expect(try banc().modele.serenite.reglage == [titre])
        let m = try banc().modele
        m.toucherOnglet(.aujourdhui)
        m.toucherOnglet(.zmanim)
        m.toucherOnglet(.textes)
        m.toucherOnglet(.journal)
        #expect(m.routes == [.zmanim, .textes, .journal])
        #expect(SereniteOnglet.allCases.filter(\.actif) == [.aujourdhui])
    }

    @Test func sereniteAvecLieu() throws {
        var r = Reglages()
        r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
        let b = try banc(Journal(), r)
        let s = b.modele.serenite
        let d = b.modele.donnees
        #expect(s.titreZmanim == Libelle("pile_zmanim_lieu", .texte("Jérusalem")))
        let z = try #require(d.prochain)
        #expect(s.prochain == SereniteZman(nom: z.nom, heure: z.heure, dans: d.dans(z)))
    }

    // MARK: Bento

    @Test func bentoSansRien() throws {
        var r = Reglages()
        r.setMusicEnabled(false)
        let e = try banc(Journal(), r).modele.bento
        #expect(e.titre == Libelle("pile_titre"))
        #expect(e.hitbodedout.titre == Libelle("bento_hitbo_titre"))
        #expect(e.hitbodedout.bouton == Libelle("version_commencer", .libelle(DonneesAccueil.duree(15))))
        #expect(e.hitbodedout.faits == 0)
        #expect(e.hitbodedout.fraction == 0)
        #expect(e.hitbodedout.accessibilite == Libelle("pile_hitbodedout"))
        #expect(e.serie.nombre == 0)
        #expect(e.serie.jours == Libelle.pluriel("bento_jours", quantite: 0))
        #expect(e.serie.barres == [false, false, false, false, false, false, false])
        #expect(e.zmanim.etiquette == Libelle("pile_zmanim"))
        #expect(e.zmanim.valeur == .libelle(Libelle("version_choisir_lieu")))
        #expect(!e.zmanim.compte)
        #expect(e.zmanim.chkia == nil)
        // Ni ambiance ni musique : « Musique », « Silence », et rien ne danse.
        #expect(e.ambiance == BentoAmbiance(etiquette: Libelle("bento_musique"),
                                            nom: .libelle(Libelle("ambiance_silence")), joue: false))
        #expect(e.journal == BentoJournal(quand: nil, duree: nil, texte: Libelle("version_ecrire_note")))
    }

    @Test func bentoUneSemaineCommencee() throws {
        // Dimanche 15 et lundi 16 faits : deux jours d'affilée, deux sur les jours dus de la semaine.
        let j = try Self.journal([("2026-11-15", 30), (Self.lundi, 20)], notes: [(Self.lundi, "Bien")])
        var r = Reglages()
        r.setAmbiance("mer")
        r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
        let b = try banc(j, r)
        let e = b.modele.bento
        let d = b.modele.donnees
        #expect(e.hitbodedout.titre == Libelle("bento_faite", .libelle(DonneesAccueil.duree(20))))
        #expect(e.hitbodedout.bouton == Libelle("version_encore"))
        #expect(e.hitbodedout.faits == 2)
        #expect(e.hitbodedout.dus == d.semaineDus)
        #expect(e.hitbodedout.fraction == Double(2) / Double(d.semaineDus))
        #expect(e.hitbodedout.accessibiliteAnneau == Libelle("version_semaine", .entier(2), .entier(d.semaineDus)))
        #expect(e.serie.nombre == 2)
        #expect(e.serie.barres == [true, true, false, false, false, false, false])
        #expect(e.serie.accessibilite == Libelle.pluriel("version_serie", quantite: 2, .entier(2)))
        let z = try #require(d.prochain)
        #expect(e.zmanim.etiquette == z.nom)
        #expect(e.zmanim.valeur == .libelle(d.dans(z)))
        #expect(e.zmanim.compte)
        #expect(e.zmanim.chkia?.cle == "chkia")
        #expect(e.zmanim.accessibilite == [.libelle(Libelle("version_prochain", .libelle(z.nom))), .libelle(d.dans(z))])
        #expect(e.ambiance.etiquette == Libelle("bento_ambiance"))
        #expect(e.ambiance.nom == .libelle(Libelle("ambiance_mer")))
        #expect(e.ambiance.joue)
        #expect(e.journal.quand == .libelle(Libelle("version_aujourdhui")))
        #expect(e.journal.duree == DonneesAccueil.duree(20))
        #expect(e.journal.texte == Libelle("version_note_ecrite"))
    }

    // MARK: Pile

    @Test func pileLesQuatreCartes() throws {
        var j = Journal()
        j.setFirstName("Avraham")
        let m = try banc(j).modele
        let e = m.pile
        #expect(PileCarte.allCases.count == AccueilVersionModele.nombreDeCartes)
        #expect(e.position == Libelle("pile_position", .entier(1), .entier(4)))
        #expect(e.hitbodedout.titre == Libelle("pile_hitbo_titre_prenom", .texte("Avraham")))
        #expect(e.hitbodedout.image == "char_welcome")
        #expect(e.hitbodedout.jours.count == 7)
        #expect(e.hizouk.pensee == nil)
        #expect(e.hizouk.bouton == nil)
        #expect(e.zmanim.etiquette == Libelle("pile_zmanim"))
        #expect(e.zmanim.zmanim.isEmpty)
        #expect(e.zmanim.prochain == nil)
        #expect(e.journal == PileJournal(jour: nil, duree: nil, texte: nil))
        m.choisirPage(2)
        #expect(m.pile.position == Libelle("pile_position", .entier(3), .entier(4)))
        m.choisirPage(9)
        #expect(m.page == 3)
        m.choisirPage(-1)
        #expect(m.page == 0)
        #expect(try banc().modele.pile.hitbodedout.titre == Libelle("pile_hitbo_titre"))
    }

    @Test func pileFaiteEtSonJournal() throws {
        let j = try Self.journal([(Self.lundi, 20), ("2026-11-14", 12)])
        let e = try banc(j).modele.pile
        #expect(e.hitbodedout.titre == Libelle("pile_hitbo_faite", .libelle(DonneesAccueil.duree(20))))
        #expect(e.hitbodedout.image == Poses.greeting(true, jour: try Self.jour(Self.lundi)))
        #expect(e.hitbodedout.bouton == Libelle("version_encore"))
        #expect(e.journal.jour == .libelle(Libelle("version_aujourdhui")))
        #expect(e.journal.duree == DonneesAccueil.duree(20))
        #expect(e.journal.texte == Libelle("version_note_sans_texte"))
    }

    @Test func pileLeHizoukSeRetourne() async throws {
        let m = try banc().modele
        await m.apparaitre()
        let recto = m.pile.hizouk
        let p = try #require(recto.pensee)
        try #require(p.traduction != nil)
        #expect(!recto.verso)
        #expect(recto.bouton == Libelle("pile_voir_traduction"))
        m.basculerTraduction()
        #expect(m.retournements == 1)
        #expect(m.pile.hizouk.verso)
        #expect(m.pile.hizouk.bouton == Libelle("pile_revoir_hebreu"))
        m.reduireAnimations = true
        m.basculerTraduction()
        #expect(!m.pile.hizouk.verso)
        // Sans animations, la carte change d'un coup.
        #expect(m.retournements == 1)
        // En hébreu, pas de traduction : la carte ne se retourne pas.
        let he = try banc(langue: "he").modele
        await he.apparaitre()
        he.basculerTraduction()
        #expect(!he.pile.hizouk.verso)
        #expect(he.pile.hizouk.bouton == nil)
    }

    @Test func pileLesZmanimPassesSontAttenues() throws {
        var r = Reglages()
        r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
        let b = try banc(Journal(), r)
        let e = b.modele.pile
        let d = b.modele.donnees
        let prochain = try #require(d.prochain)
        #expect(e.zmanim.etiquette == Libelle("pile_zmanim_lieu", .texte("Jérusalem")))
        #expect(e.zmanim.prochain == Libelle("version_prochain", .libelle(prochain.nom)))
        #expect(e.zmanim.dans == d.dans(prochain))
        for z in e.zmanim.zmanim {
            #expect(z.passe == (z.zman.instant < prochain.instant), "\(z.zman.cle)")
        }
        #expect(e.zmanim.zmanim.first { $0.zman.cle == "netz" }?.passe == true)
        #expect(e.zmanim.zmanim.first { $0.zman.cle == "tset" }?.passe == false)
    }

    // MARK: La version montrée

    @Test func laVersionMontreeSuitLeReglage() async throws {
        let b = try banc()
        #expect(b.modele.version == .classique)
        #expect(!b.modele.fondSombre)
        try await b.magasin.modifierReglages { $0.setVersionApp(.pile) }
        #expect(b.modele.version == .pile)
        // Le fond de Pile est sombre, celui de Bento clair, celui de Sérénité suit le ciel.
        #expect(b.modele.fondSombre)
        try await b.magasin.modifierReglages { $0.setVersionApp(.bento) }
        #expect(!b.modele.fondSombre)
        try await b.magasin.modifierReglages { $0.setVersionApp(.serenite) }
        #expect(!b.modele.fondSombre)
        let soir = try banc(heure: 21)
        try await soir.magasin.modifierReglages { $0.setVersionApp(.serenite) }
        #expect(soir.modele.fondSombre)
        // Instant : un tableau de bord sombre, de jour comme de nuit.
        try await b.magasin.modifierReglages { $0.setVersionApp(.instant) }
        #expect(b.modele.version == .instant)
        #expect(b.modele.fondSombre)
    }

    // MARK: Le soir (AccueilSoirTest)

    /// Le soir, zmanim du jour passés et un lieu choisi : le dernier repère du jour et son heure, sans compte à
    /// rebours ; « Choisir un lieu » ne reste que sans lieu (recette du 22/11).
    @Test func leSoirLeDernierRepereDuJourEtSonHeure() throws {
        var r = Reglages()
        r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
        let b = try banc(Journal(), r, heure: 23, minute: 30)
        let d = b.modele.donnees
        #expect(d.prochain == nil)
        let soir = try #require(d.dernierDuJour)
        #expect(soir.cle == "tset")
        #expect(soir == d.zmanim.last)
        // Sérénité, Bento et Instant le montrent.
        #expect(b.modele.serenite.prochain == SereniteZman(nom: soir.nom, heure: soir.heure, dans: nil))
        let bento = b.modele.bento.zmanim
        #expect(bento.etiquette == soir.nom)
        #expect(bento.valeur == .brut(soir.heure))
        #expect(bento.accessibilite == [.libelle(soir.nom), .brut(soir.heure)])
        #expect(b.modele.instant.zmanim.ligne == [.libelle(soir.nom), .brut(soir.heure)])
        // En journée, le prochain zman, et rien d'autre.
        let jour = try banc(Journal(), r, heure: 10).modele.donnees
        #expect(jour.prochain != nil)
        #expect(jour.dernierDuJour == nil)
        // Sans lieu, rien à montrer : on propose d'en choisir un.
        let sans = try banc(heure: 23, minute: 30).modele
        #expect(sans.donnees.dernierDuJour == nil)
        #expect(sans.serenite.prochain == nil)
        #expect(sans.bento.zmanim.valeur == .libelle(Libelle("version_choisir_lieu")))
        #expect(sans.instant.zmanim.ligne == [.libelle(Libelle("version_choisir_lieu"))])
        #expect(sans.instant.zmanim.accessibilite == [.libelle(Libelle("version_sans_lieu"))])
    }

    /// Le profil du rite (relecture du 23/11) : les zmanim des accueils sont ceux de l'écran des zmanim.
    @Test func lesZmanimSuiventLeRite() throws {
        for nusah in Nusah.allCases {
            var r = Reglages()
            r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
            r.setSiddurNusah(nusah)
            let d = try banc(Journal(), r).modele.donnees
            let attendu = Zmanim.jour(lieu: Self.jerusalem, date: try Self.jour(Self.lundi), nusah: nusah)
                .first { $0.cle == "tset" }?.instant
            let tset = try #require(d.zmanim.first { $0.cle == "tset" })
            #expect(tset.instant == attendu.map(AccueilVersionModele.millis), "\(nusah)")
        }
    }

    // MARK: Instant

    @Test func instantSansRien() throws {
        let e = try banc().modele.instant
        #expect(e.dateCivile == .date(try Self.jour(Self.lundi)))
        #expect(e.titre == Libelle("instant_titre"))
        #expect(e.bouton == Libelle("version_commencer", .libelle(DonneesAccueil.duree(15))))
        #expect(!e.enCours)
        #expect(e.semaineFaits == 0)
        #expect(e.fraction == 0)
        #expect(e.serie == 0)
        #expect(e.joursSerie == Libelle.pluriel("bento_jours", quantite: 0))
        #expect(e.total == Libelle("instant_total", .libelle(DonneesAccueil.duree(0))))
        #expect(e.zmanim.reperes.isEmpty)
        #expect(e.minutes.minutes == [0, 0, 0, 0, 0, 0, 0])
        #expect(e.minutes.moyenne == 0)
        #expect(e.minutes.echelle == 15)
        #expect(e.minutes.jours.last == (try Self.jour(Self.lundi)))
        #expect(e.minutes.jours.first == (try Self.jour("2026-11-10")))
        #expect(e.pensee == nil)
        #expect(e.journal == InstantJournal(jour: nil, duree: nil, noteEcrite: false))
    }

    @Test func instantUneSemaineEtSesMinutes() throws {
        // Le jeudi 12 (25 min), le vendredi 13 (rien), le dimanche 15 (30) et le lundi 16 (20) : trois jours faits.
        let j = try Self.journal([("2026-11-12", 25), ("2026-11-15", 30), (Self.lundi, 20)],
                                 notes: [(Self.lundi, "Merci")])
        var r = Reglages()
        r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
        let b = try banc(j, r)
        let e = b.modele.instant
        let d = b.modele.donnees
        #expect(e.titre == Libelle("serenite_faite"))
        #expect(e.bouton == Libelle("version_encore"))
        #expect(e.dateHebraique == d.dateHebraique)
        #expect(e.semaineFaits == d.semaineFaits)
        #expect(e.fraction == Double(d.semaineFaits) / Double(d.semaineDus))
        #expect(e.accessibiliteSemaine == Libelle("version_semaine", .entier(d.semaineFaits), .entier(d.semaineDus)))
        #expect(e.serie == 2)
        #expect(e.total == Libelle("instant_total", .libelle(DonneesAccueil.duree(75))))
        // Du mardi 10 au lundi 16 ; la moyenne des jours faits, tronquée : 75 / 3 = 25.
        #expect(e.minutes.minutes == [0, 0, 25, 0, 0, 30, 20])
        #expect(e.minutes.moyenne == 25)
        #expect(e.minutes.echelle == 30)
        #expect(e.minutes.total == DonneesAccueil.duree(75))
        #expect(e.minutes.libelleMoyenne == Libelle("instant_moyenne", .libelle(DonneesAccueil.duree(25))))
        // Les zmanim en petit : le prochain, son heure, le temps qui reste ; les cinq repères en nom court.
        let z = try #require(d.prochain)
        #expect(e.zmanim.ligne == [.libelle(Libelle("version_prochain", .libelle(z.nom))), .brut(z.heure),
                                   .libelle(d.dans(z))])
        #expect(e.zmanim.accessibilite == [.libelle(Libelle("version_prochain", .libelle(z.nom))), .brut(z.heure)])
        #expect(e.zmanim.reperes.map(\.nom) == [Libelle("instant_z_netz"), Libelle("instant_z_chatsot"),
                                                Libelle("instant_z_minha"), Libelle("instant_z_chkia"),
                                                Libelle("instant_z_tset")])
        #expect(e.zmanim.reperes.map(\.heure) == d.zmanim.map(\.heure))
        #expect(e.journal == InstantJournal(jour: .libelle(Libelle("version_aujourdhui")),
                                            duree: DonneesAccueil.duree(20), noteEcrite: true))
        // Une moyenne tronquée comme `toInt()` de Kotlin : (10 + 11) / 2 = 10,5 → 10.
        let impair = try banc(try Self.journal([("2026-11-14", 10), ("2026-11-15", 11)])).modele.instant.minutes
        #expect(impair.moyenne == 10)
    }

    @Test func instantEnCours() throws {
        var r = Reglages()
        let date = try Self.jour(Self.lundi)
        Store.beginSession(reglages: &r, minutes: 15, millis: Fuseau.utc.millis(DateHeure(date, heure: 9, minute: 55)))
        let e = try banc(Journal(), r).modele.instant
        #expect(e.enCours)
        #expect(e.bouton == Libelle("version_reprendre"))
    }

    // MARK: La fiche d'un trophée neuf et le bilan de la semaine, sur tous les accueils

    /// Relecture du 23/11 : un trophée neuf ouvre sa fiche ici aussi ; décision du 24/11 (BilanPartoutTest) : le bilan
    /// de la semaine s'ouvre sur tous les accueils, une fois par semaine. Un bravo qui attend passe d'abord.
    @Test func laFicheDuTropheeEtLeBilanDeLaSemaine() async throws {
        // La semaine du dimanche 8 au samedi 14 : trois jours faits.
        let j = try Self.journal([("2026-11-09", 20), ("2026-11-10", 25), ("2026-11-11", 30)])
        var bravo = Reglages()
        bravo.setPendingCelebration(minutes: 30, dateNote: "2026-11-11")
        // Aucun trophée vu encore (une liste vide, et non absente : absente, rien n'est neuf au premier passage).
        bravo.setTropheesVus([])
        let b = try banc(j, bravo)
        let m = b.modele
        await m.apparaitre()
        // Le bravo d'abord : ni fiche ni bilan.
        #expect(m.routes == [.celebration(minutes: 30, dateNote: "2026-11-11")])
        #expect(m.fete.fiches.isEmpty)
        #expect(m.bilan == nil)
        // Au retour : la fiche du premier trophée, puis le bilan.
        m.routeOuverte()
        await m.apparaitre()
        #expect(!m.fete.fiches.isEmpty)
        let bilan = try #require(m.bilan)
        #expect(bilan.debut == (try Self.jour("2026-11-08")))
        #expect(bilan.titre == Libelle("bilan_titre"))
        #expect(b.magasin.reglages.bilanVu == "2026-11-08")
        m.fermerBilan()
        #expect(m.bilan == nil)
        // Une fois par semaine : il ne revient pas.
        await m.apparaitre()
        #expect(m.bilan == nil)
    }
}
