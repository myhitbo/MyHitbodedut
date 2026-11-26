import Foundation
import Observation
import Coeur

// Les accueils des versions autres que Classique (AccueilVersion.kt d'Android, 17/11) : Sérénité, Bento, Instant et
// Pile, tirés des maquettes du propriétaire. Chacun dessine la même journée à sa manière et ouvre les mêmes écrans
// (séance, zmanim, textes, journal, réglages) ; le journal, la série, les réglages et la barrière sont les mêmes.
//
// Ce fichier tient ce qu'ils partagent : les données lues d'un coup (`DonneesAccueil`), les gestes communs
// (`AccueilVersion.commencerSeance`, `ouvrirZmanim`…) et ce que l'accueil fait à chaque retour (la présentation,
// le bravo en attente, la fiche d'un trophée neuf, le bilan de la semaine). Ce que chaque version montre en plus est
// dans SereniteModele.swift, BentoModele.swift, InstantModele.swift et PileModele.swift ; les vues, dans Vues.

// MARK: Les textes

/// Un texte d'un accueil de version : une chaîne de l'interface, un texte tel quel, ou une date civile que la vue
/// écrit « EEEE d MMMM » dans la langue de l'app, majuscule initiale (DonneesAccueil.dateCivile, `jour`).
public enum VersionTexte: Sendable, Hashable {
    case libelle(Libelle)
    case brut(String)
    case date(JourCivil)
}

/// Un zman en bref (DonneesAccueil.ZmanAffiche) : son nom, l'heure du lieu (« 16:42 ») et l'instant.
public struct VersionZman: Sendable, Hashable, Identifiable {
    public let cle: String
    public let nom: Libelle
    public let heure: String
    /// L'instant, en millisecondes depuis 1970.
    public let instant: Int64

    public var id: String { cle }
}

/// Le texte du jour (DonneesAccueil.PenseeAffichee) : l'hébreu, la traduction de la langue de l'app s'il y en a une,
/// la référence. Les deux textes sont des extraits de 420 unités au plus, sans balises.
public struct VersionPensee: Sendable, Hashable {
    public let hebreu: String
    public let traduction: String?
    public let reference: String
}

/// La dernière journée faite ou notée (DonneesAccueil.NoteAffichee), sans le texte de sa note : un accueil se voit dans
/// les captures d'écran et l'aperçu des applications récentes, que l'écran du journal cache (décision du 24/11).
/// `ecrite` dit seulement qu'une note existe.
public struct VersionNote: Sendable, Hashable {
    public let date: JourCivil
    public let minutes: Int
    public let ecrite: Bool
}

/// Les données d'un accueil de version, lues d'un coup (DonneesAccueil.lire) : ce que les maquettes montrent. Chaque
/// morceau qui peut manquer (pas de lieu, textes pas encore lus) est nil plutôt que de casser l'écran.
public struct DonneesAccueil: Sendable, Hashable {
    /// Les zmanim qu'un accueil montre en bref, dans l'ordre du jour (DonneesAccueil.REPERES).
    public static let reperes = ["netz", "chatsot", "minha_ketana", "chkia", "tset"]

    public let prenom: String
    /// Le jour civil du téléphone.
    public let aujourdhui: JourCivil
    /// L'heure du téléphone, qui choisit la salutation (Salutation.chaine).
    public let heure: Int
    /// La date hébraïque, isolée (U+2067 … U+2069) pour garder son ordre au milieu d'une ligne de gauche à droite.
    public let dateHebraique: String?
    public let faite: Bool
    /// Une séance est en cours (Store.isSessionRunning).
    public let enCours: Bool
    public let minutesAujourdhui: Int
    public let serie: Int
    public let semaineFaits: Int
    public let semaineDus: Int
    /// La semaine en cours, du dimanche au samedi (Store.currentWeek).
    public let semaine: [CaseSemaine]
    public let totalMinutes: Int
    public let objectifMinutes: Int
    /// Le nom du lieu des zmanim ; nil sans lieu.
    public let lieu: String?
    /// Les repères du jour, dans l'ordre.
    public let zmanim: [VersionZman]
    /// Le prochain zman, hors 'hatsot de la nuit ; nil sans lieu ou une fois la journée passée.
    public let prochain: VersionZman?
    /// L'instant de la lecture, en millisecondes : « dans 1 h 12 » se compte depuis lui.
    public let maintenant: Int64
    public let pensee: VersionPensee?
    public let derniereNote: VersionNote?

    /// « Bonjour, Avraham » le matin, bon après-midi, bonsoir (Salutation) ; sans prénom, « Votre journée ».
    public var salutation: Libelle {
        prenom.estBlanc ? Libelle("pile_titre") : Libelle(Salutation.chaine(heure), .texte(prenom))
    }

    /// La date civile et la date hébraïque, que la vue joint par « · ».
    public var ligneDate: [VersionTexte] {
        var ligne: [VersionTexte] = [.date(aujourdhui)]
        if let dateHebraique { ligne.append(.brut(dateHebraique)) }
        return ligne
    }

    /// « 12 jours d'affilée » (version_serie).
    public var libelleSerie: Libelle {
        Libelle.pluriel("version_serie", quantite: serie, .entier(serie))
    }

    /// « 4 sur 6 cette semaine » (version_semaine).
    public var libelleSemaine: Libelle {
        Libelle("version_semaine", .entier(semaineFaits), .entier(semaineDus))
    }

    /// Le bouton de la séance : y revenir, en faire une de plus, ou « Commencer · 15 min ».
    public var libelleCommencer: Libelle {
        if enCours { return Libelle("version_reprendre") }
        if faite { return Libelle("version_encore") }
        return Libelle("version_commencer", .libelle(DonneesAccueil.duree(objectifMinutes)))
    }

    /// Le soir, quand les zmanim du jour sont passés, `prochain` est nil alors qu'un lieu est choisi : on montre alors
    /// le dernier repère du jour (la sortie des étoiles) et son heure, sans compte à rebours. Nil aussi sans lieu :
    /// c'est le seul cas où l'on propose d'en choisir un (recette du 22/11 : Bento, Instant et Sérénité affichaient
    /// « Choisir un lieu » chaque soir, lieu choisi ou non).
    public var dernierDuJour: VersionZman? {
        prochain == nil ? zmanim.last : nil
    }

    /// « dans 1 h 12 » jusqu'au zman (DonneesAccueil.dans), jamais « dans 0 min ».
    public func dans(_ z: VersionZman) -> Libelle {
        let minutes = DonneesAccueil.minutesAvant(maintenant: maintenant, instant: z.instant)
        if minutes < 60 { return Libelle("version_dans_min", .entier(Int(minutes))) }
        return Libelle("version_dans_h", .entier(Int(minutes / 60)), .entier(Int(minutes % 60)))
    }

    /// Les minutes entières jusqu'à `instant`, jamais moins d'une (DonneesAccueil.minutesAvant) : dans la dernière
    /// minute avant un zman, les accueils annonçaient « dans 0 min » (recette du 22/11). Millisecondes Unix.
    public static func minutesAvant(maintenant: Int64, instant: Int64) -> Int64 {
        max((instant &- maintenant) / 60_000, 1)
    }

    /// « Aujourd'hui », « Hier », sinon la date (DonneesAccueil.jour).
    public func jour(_ date: JourCivil) -> VersionTexte {
        if date == aujourdhui { return .libelle(Libelle("version_aujourdhui")) }
        if date == aujourdhui.plus(jours: -1) { return .libelle(Libelle("version_hier")) }
        return .date(date)
    }

    /// « 1 h 05 », « 20 min » (DonneesAccueil.duree).
    public static func duree(_ minutes: Int) -> Libelle {
        if minutes < 60 { return Libelle("version_duree_min", .entier(minutes)) }
        return Libelle("version_duree_h", .entier(minutes / 60), .entier(minutes % 60))
    }
}

// MARK: Les routes

/// Un écran qu'un accueil de version demande ; la racine (ios/App) l'ouvre dans la pile de l'accueil.
public enum AccueilVersionRoute: Sendable, Hashable {
    /// SessionActivity ; `demarrer` (EXTRA_START_NOW) : vrai sauf s'il y a déjà une séance en cours.
    case seance(demarrer: Bool)
    case zmanim
    case journal
    /// LibraryActivity : les sources de la bibliothèque.
    case textes
    case siddour
    case tehilim
    case chizuk
    case musique
    case reglages
    case parcours
    case recherche
    /// NoteDialog.show(today) : la note du jour.
    case note(JourCivil)
    /// CelebrationActivity.showIfPending : le bravo d'une séance close téléphone posé.
    case celebration(minutes: Int, dateNote: String?)
    /// OnboardingActivity, tant que la présentation n'a pas été vue.
    case presentation
}

// MARK: Le modèle

/// Ce que partagent les trois accueils (AccueilVersion) : les données, les gestes, et le retour sur l'accueil.
@MainActor
@Observable
public final class AccueilVersionModele {

    /// Pile : quatre cartes (PileActivity.NB).
    nonisolated public static let nombreDeCartes = 4
    /// Pile : la carte du 'hizouk se retourne en deux temps de 160 ms (PileActivity.retourner).
    nonisolated public static let dureeDemiTour = 160
    /// Bento : à la première ouverture, chaque rangée de tuiles entre 80 ms après la précédente, en 500 ms, de 10 pt
    /// plus bas (jamais avec « Réduire les animations »).
    nonisolated public static let ecartCascade = 80
    /// Instant : la jauge de la semaine se remplit en 900 ms, les barres des sept jours poussent en 700 ms.
    nonisolated public static let dureeJauge = 900
    nonisolated public static let dureeBarres = 700

    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    private let systeme: (any AccueilSysteme)?

    /// « fr », « en », « he », « es » ou « ar ».
    public let langue: String

    /// « Réduire les animations », que la vue recopie de l'environnement.
    public var reduireAnimations = false

    /// Les captures du ciel à heure fixe (ios/App/Captures.swift, « -capture serenite-m+03 ») : l'heure décimale du
    /// soleil moyen, sans lieu ; nil : le vrai soleil du lieu, maintenant.
    public var heureDuCiel: Double? = nil

    /// Le verrou du journal, posé par l'app (VerrouJournal.actif). Depuis le 24/11 aucun accueil de version ne montre le
    /// texte d'une note, verrou ou non : il reste pour l'app, qui le passe aux écrans ouverts d'ici.
    public var verrou: VerrouJournal? = nil

    /// La fiche d'un trophée neuf et la phrase d'un palier, comme au Classique (relecture du 23/11 : sans elle, un
    /// trophée gagné ici n'était jamais fêté). La racine la pose par-dessus l'accueil (`feteDesTrophees`).
    public let fete: TropheeFeteModele

    /// Le bilan de la semaine écoulée, à montrer une fois (décision du 24/11 : sur tous les accueils) ; nil sinon.
    public private(set) var bilan: AccueilBilan? = nil

    private var bibliotheque: Bibliotheque? = nil
    private var dejaApparu = false

    /// Les écrans à ouvrir, dans l'ordre : la racine ouvre le premier puis appelle `routeOuverte()`.
    public private(set) var routes: [AccueilVersionRoute] = []

    /// Pile : la carte montrée, de 0 à 3 (gardée d'un retour à l'autre, comme ETAT_PAGE).
    public private(set) var page = 0
    /// Pile : le 'hizouk montre sa traduction.
    public private(set) var traductionVisible = false
    /// Pile : monte à chaque retournement animé de la carte du 'hizouk.
    public private(set) var retournements = 0

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String,
                systeme: (any AccueilSysteme)? = nil) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = ChizukCard.language(langue)
        self.systeme = systeme
        fete = TropheeFeteModele(magasin: magasin, horloge: horloge)
    }

    /// La version que l'app montre (VersionApp.courante) : Classique tant qu'aucune n'est choisie.
    public var version: VersionApp {
        VersionApp.accueil(magasin.reglages)
    }

    /// Le fond de l'accueil est sombre (VueVersion.barres, `clair` faux) : Pile toujours, Sérénité la nuit et le soir,
    /// Bento jamais. La racine en tire le mode de l'écran, pour que la barre d'état reste lisible.
    public var fondSombre: Bool {
        switch version {
        case .pile, .instant: return true
        case .serenite:
            let phase = ciel
            return !(phase == .jour || phase == .aube)
        case .bento, .classique: return false
        }
    }

    /// La police des textes hébreux (PoliceHebraique.appliquer) : `.policeHebraique(police, taille:)`.
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    // MARK: Le retour sur l'accueil

    /// onCreate puis onResume d'AccueilVersion : la présentation tant qu'elle n'a pas été vue, les services, le texte
    /// du jour, puis le bravo en attente ; s'il n'y en a pas, la fiche d'un trophée neuf (comme au Classique), puis le
    /// bilan de la semaine (décision du 24/11). Un bravo qui attend passe d'abord : la fiche et le bilan viennent au
    /// retour. Une écriture refusée ne l'arrête pas.
    public func apparaitre() async {
        if !dejaApparu {
            dejaApparu = true
            if !magasin.reglages.hasOnboarded { routes.append(.presentation) }
        }
        await systeme?.appliquerEtat()
        if bibliotheque == nil { bibliotheque = try? await contenus.bibliotheque() }
        let bravo = await celebrationEnAttente()
        if !bravo {
            try? await fete.passer()
            if bilan == nil, let b = await AccueilBilan.aMontrer(magasin: magasin, horloge: horloge) { bilan = b }
        }
        await systeme?.rafraichirVignettes()
    }

    /// Le bilan a été lu (« Continuer »).
    public func fermerBilan() {
        bilan = nil
    }

    /// L'écran en tête de `routes` est ouvert.
    public func routeOuverte() {
        if !routes.isEmpty { routes.removeFirst() }
    }

    // MARK: Les gestes communs

    /// La séance d'un seul geste, réglée comme sur l'accueil Classique ; en cours, on y revient.
    public func commencerSeance() {
        routes.append(.seance(demarrer: !enCours))
    }

    /// L'écran de préparation : durée, sujet, musique, manière.
    public func preparerSeance() {
        routes.append(.seance(demarrer: false))
    }

    public func ouvrirZmanim() { routes.append(.zmanim) }
    public func ouvrirJournal() { routes.append(.journal) }
    public func ouvrirTextes() { routes.append(.textes) }
    public func ouvrirSiddour() { routes.append(.siddour) }
    public func ouvrirTehilim() { routes.append(.tehilim) }
    public func ouvrirChizuk() { routes.append(.chizuk) }
    public func ouvrirMusique() { routes.append(.musique) }
    public func ouvrirReglages() { routes.append(.reglages) }
    public func ouvrirParcours() { routes.append(.parcours) }
    public func ouvrirRecherche() { routes.append(.recherche) }

    /// La note du jour (NoteDialog.show(today)).
    public func ecrireNote() {
        routes.append(.note(horloge.aujourdhui))
    }

    // MARK: Pile

    /// La carte montrée a changé (glissée du doigt) ; bornée aux quatre cartes.
    public func choisirPage(_ p: Int) {
        page = min(max(p, 0), AccueilVersionModele.nombreDeCartes - 1)
    }

    /// « Voir la traduction » ou « Revoir l'hébreu » : la carte se retourne (sans animation, elle change d'un coup).
    public func basculerTraduction() {
        traductionVisible.toggle()
        if !reduireAnimations { retournements += 1 }
    }

    // MARK: Les données

    /// DonneesAccueil.lire : tout ce que les maquettes montrent, lu maintenant.
    public var donnees: DonneesAccueil {
        let reglages = magasin.reglages
        let journal = magasin.journal
        let aujourdhui = horloge.aujourdhui
        let fuseauTelephone = horloge.fuseau.identifiant
        let lieu = reglages.lieuZmanim
        let zone = lieu.flatMap { Fuseau($0.fuseau) } ?? horloge.fuseau
        let maintenant = DateHeureZonee(millis: horloge.maintenant, fuseau: zone)
        // Le profil du rite, comme l'écran des zmanim, les vignettes et l'accueil Classique : sans lui, les Edot (rite
        // par défaut) lisaient ici un tsét à 8,5° et ailleurs le leur (relecture du 23/11).
        let jour = lieu.map { Zmanim.jour(lieu: $0, date: maintenant.jour, nusah: reglages.siddurNusah) } ?? []
        var tset: DateHeureZonee? = nil
        if let instant = jour.first(where: { $0.cle == "tset" })?.instant {
            tset = DateHeureZonee(millis: AccueilVersionModele.millis(instant), fuseau: zone)
        }
        let enIsrael = reglages.inIsrael(fuseauTelephone: fuseauTelephone)
        let hebraique = CalendrierJuif.jour(ZmanimVignette.jourHebreuAffiche(maintenant: maintenant, tset: tset),
                                            enIsrael: enIsrael).dateHebraique
        let tous: [VersionZman] = jour.compactMap { z in
            guard let instant = z.instant else { return nil }
            let millis = AccueilVersionModele.millis(instant)
            let h = zone.dateHeure(millis: millis)
            return VersionZman(cle: z.cle, nom: Libelle("zman_\(z.cle)"),
                               heure: AccueilVersionModele.deuxChiffres(h.heure) + ":" + AccueilVersionModele.deuxChiffres(h.minute),
                               instant: millis)
        }
        let semaine = Store.currentWeek(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                        fuseauTelephone: fuseauTelephone)
        let progression = JaugeSemaine.progression(semaine)
        return DonneesAccueil(
            prenom: journal.firstName,
            aujourdhui: aujourdhui,
            heure: horloge.dateHeure.heure,
            dateHebraique: hebraique.isEmpty ? nil : "\u{2067}\(hebraique)\u{2069}",
            faite: journal.isDone(aujourdhui),
            enCours: enCours,
            minutesAujourdhui: journal.record(aujourdhui)?.minutes ?? 0,
            serie: Store.streak(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                fuseauTelephone: fuseauTelephone),
            semaineFaits: progression.faits,
            semaineDus: progression.dus,
            semaine: semaine,
            totalMinutes: Store.totalMinutes(journal: journal),
            objectifMinutes: reglages.targetMinutes,
            lieu: lieu?.nom,
            zmanim: tous.filter { DonneesAccueil.reperes.contains($0.cle) },
            prochain: tous.first { $0.instant > horloge.maintenant && $0.cle != "chatsot_layla" },
            maintenant: horloge.maintenant,
            pensee: pensee(aujourdhui),
            derniereNote: derniereNote)
    }

    // MARK: Ce qui se lit

    private var enCours: Bool {
        Store.isSessionRunning(reglages: magasin.reglages, millis: horloge.maintenant)
    }

    /// Le paragraphe du jour (SourceDuJour) : l'hébreu, et la traduction des langues de lecture (LanguesTexte), comme
    /// la carte du Classique : en espagnol et en arabe tunisien l'hébreu seul, et non plus le français ; un choix
    /// « hébreu seul » est respecté (relecture du 23/11). nil tant que la bibliothèque n'est pas lue.
    private func pensee(_ jour: JourCivil) -> VersionPensee? {
        guard let bibliotheque, let p = SourceDuJour.choix(bibliotheque, jour) else { return nil }
        let fr = p.indice < p.source.paragraphesFr.count ? p.source.paragraphesFr[p.indice] : nil
        let en = p.indice < p.source.paragraphesEn.count ? p.source.paragraphesEn[p.indice] : nil
        let traduction = LanguesTexte.textes(modeLangues, p.texte, fr, en).first { $0.langue != "he" }?.texte
        return VersionPensee(
            hebreu: PoliceHebraique.masque(SourceDuJour.extrait(SourceDuJour.sansBalises(p.texte), max: 420),
                                           police: police),
            traduction: traduction.map { SourceDuJour.extrait(SourceDuJour.sansBalises($0), max: 420) },
            reference: Reference.localise(p.source.ref, langue))
    }

    /// Les langues de lecture : le choix enregistré, sinon celles de la langue de l'app (LanguesTexte.mode).
    private var modeLangues: LanguesTexte.Mode {
        let r = magasin.reglages
        if let cle = r.lectureLangues, let mode = LanguesTexte.Mode(rawValue: cle) { return mode }
        return LanguesTexte.defaut(langue)
    }

    /// La journée la plus récente faite ou notée ; si elle a une note, seulement qu'elle existe.
    private var derniereNote: VersionNote? {
        let journal = magasin.journal
        var plusRecente: (JourCivil, Journee)? = nil
        for (date, r) in journal.jours where r.faite || !r.note.estBlanc {
            if let (d, _) = plusRecente, d >= date { continue }
            plusRecente = (date, r)
        }
        guard let (date, r) = plusRecente else { return nil }
        return VersionNote(date: date, minutes: r.minutes, ecrite: !r.note.estBlanc)
    }

    /// Les trois dernières journées faites, de la plus récente à la plus ancienne (Sérénité, « Vos derniers jours »).
    func derniersJours(_ nombre: Int) -> [(date: JourCivil, journee: Journee)] {
        magasin.journal.jours
            .filter { $0.value.faite }
            .sorted { $0.key > $1.key }
            .prefix(nombre)
            .map { (date: $0.key, journee: $0.value) }
    }

    var reglages: Reglages {
        magasin.reglages
    }

    var journal: Journal {
        magasin.journal
    }

    /// Le ciel du moment (CielDuJour.maintenant), d'après les zmanim du lieu ; sans lieu, l'heure du téléphone.
    var ciel: CielDuJour.Phase {
        if let heureDuCiel {
            let minutes = Kotlin.versInt(heureDuCiel * 60)
            return CielDuJour.parHeure(heure: minutes / 60, minute: minutes % 60)
        }
        let lieu = magasin.reglages.lieuZmanim
        let zone = lieu.flatMap { Fuseau($0.fuseau) } ?? horloge.fuseau
        return CielDuJour.phase(maintenant: DateHeureZonee(millis: horloge.maintenant, fuseau: zone), lieu: lieu,
                                nusah: magasin.reglages.siddurNusah)
    }

    /// Le ciel continu de la carte-paysage (24/11, CielDuJour.etat, AccueilVersion.paysage) : la hauteur du vrai
    /// soleil au lieu des zmanim, sinon le soleil moyen de l'heure du téléphone ; le jour du mois hébreu, qui donne la
    /// lune.
    public var etatCiel: EtatCiel {
        if let heureDuCiel { return CielDuJour.etat(heure: heureDuCiel) }
        let reglages = magasin.reglages
        let lieu = reglages.lieuZmanim
        let zone = lieu.flatMap { Fuseau($0.fuseau) } ?? horloge.fuseau
        return CielDuJour.etat(maintenant: DateHeureZonee(millis: horloge.maintenant, fuseau: zone), lieu: lieu,
                               enIsrael: reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant),
                               nusah: reglages.siddurNusah)
    }

    /// Le réglage de la musique de la séance, tel que les accueils le nomment : l'ambiance choisie, et le morceau
    /// retenu si la musique est allumée (nil sinon).
    var ambianceEtMorceau: (ambiance: Ambiance, morceau: VersionTexte?) {
        let r = magasin.reglages
        let ambiance = Ambiance.of(r.ambiance)
        guard r.musicEnabled, let piste = MusicLibrary.selected(MusiqueRegles.etat(r)) else { return (ambiance, nil) }
        switch piste.title {
        case .nom(let nom): return (ambiance, .brut(nom))
        case .libelle(let libelle): return (ambiance, .libelle(libelle))
        }
    }

    /// CelebrationActivity.showIfPending : le bravo en attente est pris, et son écran s'ouvre. Vrai s'il y en avait un.
    @discardableResult
    private func celebrationEnAttente() async -> Bool {
        var copie = magasin.reglages
        guard let celebration = copie.takePendingCelebration() else { return false }
        routes.append(.celebration(minutes: celebration.minutes, dateNote: celebration.dateNote))
        // Une écriture refusée garde le changement en mémoire : le bravo est pris quand même.
        let sans = copie
        try? await magasin.modifierReglages { $0 = sans }
        return true
    }

    nonisolated static func millis(_ instant: Date) -> Int64 {
        Kotlin.versLong((instant.timeIntervalSince1970 * 1000).rounded())
    }

    /// « %02d » : l'heure et la minute en chiffres latins, comme le motif « HH:mm » d'Android.
    nonisolated static func deuxChiffres(_ n: Int) -> String {
        n < 10 ? "0\(n)" : "\(n)"
    }
}
