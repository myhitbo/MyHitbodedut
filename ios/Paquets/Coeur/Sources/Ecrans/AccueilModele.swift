import Foundation
import Observation
import Coeur
import Barriere

/// L'accueil, l'onglet Aujourd'hui (MainActivity.kt, le panneau main_scroll d'activity_main.xml ; AnneauxView.kt,
/// AnneauxDessin.kt, AccueilMoment.kt, RappelsTefila.kt, SourceDuJour.kt, AjoutTemps.kt, DureeSeance.kt).
///
/// De haut en bas (refonte d'Android du 13/11) : l'en-tête — la date hébraïque qui ouvre les zmanim, la roue des
/// réglages —, le nom de l'app, la salutation, l'état du jour, la série et le total ; les trois anneaux autour
/// du hassid et leur légende ; le grade et le prochain trophée ; « Commencer » et ses pastilles ; la bande de la
/// semaine ; le mot de relance après une série rompue ; la note et « Je l'ai faite sans le téléphone » ; les cartes
/// du moment ; « Trophées » et « Mon parcours ».
///
/// Le journal et les réglages sont ceux du `Magasin`, lus à chaque fois ; l'heure vient de l'`Horloge`. Chaque
/// passage sur l'onglet appelle `apparaitre()` (onResume d'Android) : les contenus sont lus, la fête des trophées
/// et le bilan de la semaine passent, la plaque revient au hassid et les anneaux se remplissent depuis zéro.
///
/// Les animations (remplissage, retournement de la plaque, compteur, saut, fête d'un anneau) sont jouées par la
/// vue ; le modèle dit quand, et ce qui doit arriver à la fin. Avec « Réduire les animations » (`reduireAnimations`),
/// rien ne bouge : les anneaux sont pleins d'emblée, la face change d'un coup, aucun saut ni battement — et, comme
/// sur Android quand les animations sont coupées, aucun anneau n'est fêté.
@MainActor
@Observable
public final class AccueilModele {

    /// Le remplissage des anneaux (AnneauxView.remplir) : 900 ms, en ralentissant (DecelerateInterpolator 1,6).
    nonisolated public static let dureeRemplissage = 900
    /// Un anneau fêté reste devant ce temps, puis rend la place aux autres (AnneauxView.feter).
    nonisolated public static let dureeFeteAnneau = 2_800
    /// Sans toucher, la plaque revient au hassid au bout de ce temps (Plaque.RETOUR_MS).
    nonisolated public static let dureeRetourHassid = Int(Plaque.retourMs)
    /// Le compteur d'une face monte en ce temps (MainActivity.remplirFace).
    nonisolated public static let dureeCompteur = 650
    /// Les cartes du moment entrent en cascade à partir de ce délai (Effets.enfants, depart = 450 ms) : 14 pt plus
    /// bas et transparentes, puis à leur place en 420 ms, 45 ms d'écart entre deux (8 écarts au plus).
    nonisolated public static let departCascade = 450

    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    private let systeme: (any AccueilSysteme)?
    /// Ce que l'app constate de Temps d'écran (le même service que la carte des réglages) ; nil : rien d'observé.
    private let systemeBarriere: (any ReglagesBarriereSysteme)?
    private let melange: @Sendable ([String]) -> [String]

    /// « fr », « en » ou « he ».
    public let langue: String
    /// L'édition a la barrière du matin (`BuildConfig.HAS_GATE`) : sa pastille ne paraît qu'alors.
    public let barriere: Bool
    /// Vrai en debug : les textes de 'hizouk non relus passent aussi.
    public let debug: Bool

    /// La fête des trophées et des paliers neufs (Celebrations.ecran), à chaque passage.
    public let fete: TropheeFeteModele

    /// « Réduire les animations », que la vue recopie de l'environnement (`accessibilityReduceMotion`).
    public var reduireAnimations = false

    // MARK: L'état

    private var siddur: Siddur? = nil
    private var bibliotheque: Bibliotheque? = nil
    private var chizuk: Chizuk? = nil
    private var dejaApparu = false

    /// Le texte de relance tiré pour la rupture en cours ; il ne change pas tant qu'elle dure (relanceTiree).
    private var relanceId: String? = nil
    private var relanceTiree = false

    /// Les jours faits de la bande dont on a demandé la durée (« Montrer la durée ») : elle remplace le ✓.
    public private(set) var joursMontres: Set<JourCivil> = []

    /// La face montrée au centre des anneaux.
    public private(set) var face: Plaque.Face = .hassid
    /// L'anneau mis en avant (épaissi, les autres pâlis) ; nil : les trois à égalité.
    public private(set) var misEnAvant: Anneaux.Quel? = nil
    /// Monte à chaque retournement animé de la plaque (une pièce qui tourne : 0 → 90° en 140 ms en accélérant,
    /// la face change, −90° → 0 en 200 ms en ralentissant).
    public private(set) var retournements = 0
    /// Monte à chaque touche sur la plaque ou un anneau : un léger retour haptique (CONTEXT_CLICK).
    public private(set) var touches = 0
    /// Le retour au hassid attendu : la vue attend `dureeRetourHassid` puis appelle `retourHassid(numero)`.
    public private(set) var retourHassidPrevu: Int? = nil
    private var numeroRetour = 0

    /// L'état que les anneaux dessinent ; nil avant le premier passage.
    public private(set) var anneauxMontres: Anneaux.Etat? = nil
    /// Le remplissage en cours : la vue fait aller l'avance de 0 à 1 en `dureeRemplissage`, puis appelle
    /// `remplissageFini(numero)`. nil : les anneaux sont dessinés pleins (avance 1).
    public private(set) var remplissage: Int? = nil
    private var numeroRemplissage = 0
    /// Le dernier anneau fêté ; nil tant qu'aucun.
    public private(set) var feteAnneau: AccueilFeteAnneau? = nil
    /// Le dernier saut du hassid demandé.
    public private(set) var saut: AccueilSaut? = nil
    private var numeroEvenement = 0

    /// Les cartes du moment entrent en cascade : à la première apparition seulement (momentAnime), et jamais avec
    /// les animations réduites.
    public private(set) var cascade = false

    /// La boîte ouverte ; nil : aucune.
    public private(set) var dialogue: AccueilDialogue? = nil {
        didSet { if dialogue == nil { erreurSaisie = nil } }
    }
    /// La durée réglable refusée : la boîte reste ouverte et le dit sous le champ ; nil sinon.
    public private(set) var erreurSaisie: Libelle? = nil
    /// Le bilan de la semaine écoulée, à montrer une fois ; nil sinon.
    public private(set) var bilan: AccueilBilan? = nil
    /// Un mot bref (un Toast d'Android) ; nil sinon. La vue le retire avec `messageMontre()`.
    public private(set) var message: Libelle? = nil
    /// Les écrans à ouvrir, dans l'ordre : la vue ouvre le premier puis appelle `routeOuverte()`.
    public private(set) var routes: [AccueilRoute] = []

    /// Ce que Temps d'écran a dit au dernier passage (autorisation, surveillance), et les jetons de la sélection.
    public private(set) var constat = Constat()
    public private(set) var nombreDeJetons = 0
    /// L'état de la barrière, recalculé à chaque passage et après chaque geste (il compte deux ans de jours chômés :
    /// pas à chaque dessin) ; nil sans barrière ou avant le premier passage.
    public private(set) var etatBarriere: GateState? = nil

    /// `melange` : le mélange du sac des textes de relance ; un mélange fixe dans les tests.
    /// `systemeBarriere` : Temps d'écran, pour la pastille « Avec Hachem » (nil : autorisé, aucune application).
    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String, barriere: Bool,
                debug: Bool = false, systeme: (any AccueilSysteme)? = nil,
                systemeBarriere: (any ReglagesBarriereSysteme)? = nil,
                melange: @escaping @Sendable ([String]) -> [String] = { $0.shuffled() }) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = ChizukCard.language(langue)
        self.barriere = barriere
        self.debug = debug
        self.systeme = systeme
        self.systemeBarriere = systemeBarriere
        self.melange = melange
        fete = TropheeFeteModele(magasin: magasin, horloge: horloge)
    }

    // MARK: Le passage sur l'onglet

    /// Un passage sur l'accueil (onResume ; à la première apparition, aussi onCreate). Une écriture refusée ne
    /// l'arrête pas : le changement reste en mémoire, la prochaine écriture l'emportera.
    public func apparaitre() async {
        if !dejaApparu {
            dejaApparu = true
            // La présentation, une fois par version d'elle-même (showOnboardingOnce).
            if !reglages.hasOnboarded { routes.append(.presentation) }
            // Animations réduites : les cartes sont à leur place d'emblée (Effets.cascade, `actifs`).
            cascade = !reduireAnimations
        } else {
            cascade = false
        }
        await systeme?.appliquerEtat()
        await lireBarriere()
        await lireContenus()
        await rafraichir()
        // renderPaliers : la fête du neuf, puis le bilan de la semaine.
        try? await fete.passer()
        await bilanDeLaSemaine()
        // Chaque retour : le hassid au centre, et les anneaux se remplissent depuis zéro.
        montrerFace(.hassid)
        montrerAnneaux(depuisZero: true)
        // La séance s'est close téléphone posé : le bravo attendait ici.
        await celebrationEnAttente()
        await systeme?.rafraichirVignettes()
    }

    /// Retour sur l'onglet Aujourd'hui depuis l'onglet Textes (sur Android, un panneau de la même activité :
    /// `rejouer()` seul, sans onResume) : les anneaux se rejouent, rien d'autre. Re-toucher l'onglet déjà actif ne
    /// fait rien sur Android (OnItemSelectedListener ne voit pas une resélection).
    public func ongletChoisi() {
        montrerAnneaux(depuisZero: true)
    }

    /// Ouvert depuis la notification de fin de séance (EXTRA_ASK_NOTE) : la note du jour de la séance, sauf si le
    /// bravo attend encore (c'est lui qui la proposera). À appeler avant `apparaitre()`, comme onCreate précède
    /// onResume : après, le bravo serait déjà pris.
    public func demanderNote(_ date: JourCivil) {
        if !reglages.hasPendingCelebration { routes.append(.note(date)) }
    }

    /// L'écran en tête de `routes` est ouvert.
    public func routeOuverte() {
        if !routes.isEmpty { routes.removeFirst() }
    }

    /// Le mot bref a été montré.
    public func messageMontre() {
        message = nil
    }

    // MARK: L'en-tête du Jour (refonte du 13/11)

    /// La date hébraïque et le ciel du moment, en tête du Jour (renderEntete, renderCiel). La date suit la sortie des
    /// étoiles du lieu, dans les zmanim de son noussa'h, comme la vignette ; sans lieu, minuit du téléphone.
    public var entete: AccueilEntete {
        let lieu = reglages.lieuZmanim
        let zone = lieu.flatMap { Fuseau($0.fuseau) } ?? horloge.fuseau
        let maintenant = DateHeureZonee(millis: horloge.maintenant, fuseau: zone)
        var tset: DateHeureZonee? = nil
        if let lieu,
           let instant = Zmanim.jour(lieu: lieu, date: maintenant.jour, nusah: reglages.siddurNusah)
            .first(where: { $0.cle == "tset" })?.instant {
            tset = DateHeureZonee(millis: Kotlin.versLong((instant.timeIntervalSince1970 * 1000).rounded()), fuseau: zone)
        }
        let jour = ZmanimVignette.jourHebreuAffiche(maintenant: maintenant, tset: tset)
        let date = CalendrierJuif.jour(jour, enIsrael: enIsrael).dateHebraique
        let titre: AccueilTexte = date.isEmpty ? .libelle(Libelle("nav_zmanim")) : .brut(date)
        let nom: Libelle.Argument = date.isEmpty ? .libelle(Libelle("nav_zmanim")) : .texte(date)
        return AccueilEntete(dateHebraique: date.isEmpty ? nil : date, titre: titre,
                             accessibilite: Libelle("jour_ciel", nom),
                             ciel: CielDuJour.phase(maintenant: maintenant, lieu: lieu),
                             reglages: Libelle("settings_title"))
    }

    /// La date hébraïque touchée : le ciel (zmanim, calendrier, hilloulot, boussole).
    public func ouvrirZmanim() {
        routes.append(.zmanim)
    }

    /// La roue : les réglages.
    public func ouvrirReglages() {
        routes.append(.reglages(carteBarriere: false))
    }

    /// Le nom de l'app, 13 pt, atténué, espacement 0,08.
    public var nomApp: Libelle { Libelle("app_name") }

    /// « Bonjour, Avraham » le matin, bon après-midi, bonsoir (Salutation) : 26 pt gras ; nil sans prénom.
    public var salutation: Libelle? {
        let prenom = magasin.journal.firstName
        guard !prenom.estBlanc else { return nil }
        return Libelle(Salutation.chaine(horloge.dateHeure.heure), .texte(prenom))
    }

    /// Sans prénom, la ligne d'état devient le titre : 20 pt, gras, police du système, encre ; sinon 15 pt, Varela
    /// Round, atténuée.
    public var etatEstTitre: Bool {
        salutation == nil
    }

    /// L'état du jour : une séance en cours n'est pas « pas encore faite », et un jour de repos n'attend rien.
    public var etatDuJour: AccueilEtatJour {
        if enCours { return .enCours }
        if faite { return .faite }
        if Store.isExempt(reglages: reglages, date: aujourdhui, fuseauTelephone: fuseauTelephone) { return .repos }
        return .aFaire
    }

    public var titreEtat: Libelle {
        switch etatDuJour {
        case .enCours: return Libelle("status_running")
        case .faite: return Libelle("status_done")
        case .repos: return Libelle("status_rest")
        case .aFaire: return Libelle("status_pending")
        }
    }

    /// La série, ou « Série à relancer » à qui en a déjà eu une, ou « Pas encore de série » le premier jour.
    public var ligneSerie: Libelle {
        let serie = self.serie
        if serie > 0 { return Libelle.pluriel("status_streak", quantite: serie, .entier(serie)) }
        if magasin.journal.aDejaPratique { return Libelle("status_streak_none") }
        return Libelle("status_streak_first")
    }

    /// « 2 h 30 au total », après le point (status_separator, caché à la lecture d'écran) ; nil le premier jour.
    public var ligneTotal: Libelle? {
        let total = magasin.journal.totalMinutes
        guard total > 0 else { return nil }
        return Libelle("status_total", .libelle(Store.formatDuration(total)))
    }

    /// Le point entre la série et le total.
    public var separateur: Libelle { Libelle("status_separator") }

    /// Une journée faite : « Aujourd'hui : 20 min de pratique », ou « Validée sans minuteur » (16 pt, Varela
    /// Round, couleur de marque) ; nil sinon.
    public var detailDuJour: Libelle? {
        guard faite else { return nil }
        let minutes = magasin.journal.record(aujourdhui)?.minutes ?? 0
        if minutes > 0 { return Libelle("today_minutes", .libelle(Store.formatDuration(minutes))) }
        return Libelle("today_declared")
    }

    // MARK: Les anneaux

    /// Les trois anneaux, ici et maintenant.
    public var anneaux: Anneaux.Etat {
        Store.anneaux(journal: magasin.journal, reglages: reglages, aujourdhui: aujourdhui,
                      fuseauTelephone: fuseauTelephone)
    }

    /// L'avance du dessin au départ : 0 pendant un remplissage, 1 sinon.
    public var avanceDepart: Double {
        remplissage == nil ? 1 : 0
    }

    /// Les traits à dessiner pour une avance donnée (de 0 à 1).
    public func traits(avance: Double) -> [AccueilTrait] {
        AccueilAnneaux.traits(anneauxMontres ?? anneaux, misEnAvant: misEnAvant, avance: avance)
    }

    /// Ce que lit la lecture d'écran sur les anneaux (rings_description).
    public var descriptionAnneaux: Libelle {
        let etat = anneaux
        return Libelle("rings_description", .libelle(Store.formatDuration(etat.jour.fait)),
                       .libelle(Store.formatDuration(etat.jour.objectif)), .entier(etat.semaine.fait),
                       .entier(etat.semaine.objectif), .entier(etat.serie.fait), .entier(etat.serie.objectif))
    }

    /// La légende sous les anneaux (16 pt, centrée) : la semaine, ou le détail de l'anneau mis en avant.
    public var legende: Libelle {
        let etat = anneaux
        switch misEnAvant {
        case .jour:
            return Libelle(etat.jour.atteint ? "ring_day_reached" : "ring_day_detail",
                           .libelle(Store.formatDuration(etat.jour.fait)), .libelle(Store.formatDuration(etat.jour.objectif)))
        case .serie:
            // « ring_streak_detail » est un pluriel depuis le 13/11 sur Android (MainActivity, StreakWidget).
            if etat.serie.atteint {
                return Libelle("ring_streak_reached", .entier(etat.serie.fait), .entier(etat.serie.objectif))
            }
            return Libelle.pluriel("ring_streak_detail", quantite: etat.serie.fait, .entier(etat.serie.fait),
                                   .entier(etat.serie.objectif))
        case .semaine, nil:
            return Libelle.pluriel("week_gauge", quantite: etat.semaine.fait, .entier(etat.semaine.fait),
                                   .entier(etat.semaine.objectif))
        }
    }

    /// La couleur de la légende : celle de l'anneau mis en avant, atténuée sinon.
    public var couleurLegende: AccueilCouleur {
        accueilCouleur(misEnAvant, sinon: .muted)
    }

    /// Un anneau touché : mis en avant, ou remis avec les autres s'il l'était (AnneauxView.onTouchEvent). Sa face
    /// s'affiche au centre ; le relâcher ramène le hassid.
    public func toucherAnneau(_ quel: Anneaux.Quel) {
        touches += 1
        mettreEnAvant(misEnAvant == quel ? nil : quel)
    }

    /// Le remplissage `numero` est arrivé au bout (AnneauxView.surRempli → MainActivity.apresRemplissage). Un anneau
    /// qui vient de se fermer est fêté, une fois par jour, par semaine ou par palier ; sinon le hassid salue d'un
    /// saut. Lève si les réglages ne s'écrivent pas.
    public func remplissageFini(_ numero: Int) async throws {
        guard remplissage == numero else { return }
        remplissage = nil
        let etat = anneaux
        let jour = aujourdhui
        let nouveaux = Anneaux.aFeter(etat, aujourdhui: jour, dejaFetes: reglages.anneauxFetes)
        let marques = Anneaux.marques(etat, aujourdhui: jour)
        if let quel = nouveaux.first {
            numeroEvenement += 1
            feteAnneau = AccueilFeteAnneau(quel: quel, numero: numeroEvenement)
            // L'anneau fermé passe devant, et sa face s'affiche au centre le temps de la fête.
            mettreEnAvant(quel)
        } else if face == .hassid {
            sauter(1)
        }
        try await magasin.modifierReglages { $0.setAnneauxFetes(marques) }
    }

    /// La fête `numero` a duré `dureeFeteAnneau` : l'anneau rend la place aux autres, s'il est encore devant.
    public func finFeteAnneau(_ numero: Int) {
        guard let fete = feteAnneau, fete.numero == numero, misEnAvant == fete.quel else { return }
        mettreEnAvant(nil)
    }

    // MARK: La plaque

    /// Le hassid au centre (Character.greeting, au féminin s'il le faut) : celui qui accueille tant que la journée
    /// reste à faire, la joie du jour une fois faite. Fond : une pastille ronde `stageSoft`.
    public var imageHassid: String {
        Personnage.pour(adresse, Poses.greeting(faite, jour: aujourdhui))
    }

    /// La face montrée, sauf le hassid : son chiffre et ce qu'il compte ; nil pour le hassid.
    public var plaque: AccueilFace? {
        let etat = anneaux
        let journal = magasin.journal
        let cible: Int
        let format: AccueilFormatChiffre
        let legende: Libelle
        switch face {
        case .hassid:
            return nil
        case .jour:
            cible = etat.jour.fait
            format = .duree
            legende = Libelle("plaque_jour", .libelle(Store.formatDuration(etat.jour.objectif)))
        case .semaine:
            cible = etat.semaine.fait
            format = .semaine(objectif: etat.semaine.objectif)
            legende = Libelle("plaque_semaine")
        case .serie:
            cible = etat.serie.fait
            format = .nombre
            legende = Libelle.pluriel("plaque_serie", quantite: etat.serie.fait, .entier(etat.serie.fait),
                                      .entier(etat.serie.objectif))
        case .meilleure:
            cible = Store.meilleureSerie(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                         fuseauTelephone: fuseauTelephone)
            format = .nombre
            legende = Libelle("plaque_meilleure")
        case .total:
            cible = journal.totalMinutes
            format = .duree
            legende = Libelle("plaque_total")
        case .jours:
            let jours = journal.joursFaits.count
            cible = jours
            format = .nombre
            legende = Libelle.pluriel("plaque_jours", quantite: jours, .entier(jours))
        case .moyenne:
            cible = Plaque.moyenne(totalMinutes: journal.totalMinutes, jours: journal.joursFaits.count)
            format = .duree
            legende = Libelle("plaque_moyenne")
        }
        return AccueilFace(face: face, cible: cible, format: format, legende: legende,
                           couleur: accueilCouleur(face.anneau, sinon: .ink), compte: cible > 0 && !reduireAnimations)
    }

    /// Ce que lit la lecture d'écran sur la plaque : « Touchez pour voir vos chiffres » au hassid, le chiffre et sa
    /// légende sinon (joints d'une espace).
    public var accessibilitePlaque: [AccueilTexte] {
        plaque?.accessibilite ?? [.libelle(Libelle("rings_character_hint"))]
    }

    /// Un toucher au centre : la face suivante, en tournant, avec un léger retour haptique.
    public func toucherPlaque() {
        touches += 1
        tournerPlaque(Plaque.suivante(face))
    }

    /// Le retour au hassid prévu sous ce numéro est échu (Plaque.RETOUR_MS sans toucher).
    public func retourHassid(_ numero: Int) {
        guard retourHassidPrevu == numero else { return }
        tournerPlaque(.hassid)
    }

    // MARK: Les trophées

    /// Le grade et le prochain trophée ; un toucher ouvre les paliers (`ouvrirPaliers`).
    public var ligneTrophee: AccueilLigneTrophee {
        let p = pratique
        let grade = Trophees.grade(Trophees.gagnes(p).count)
        let texte: Libelle
        if let prochain = Trophees.prochain(p) {
            let reste = prochain.seuil - min(Trophees.valeur(p, prochain.famille), prochain.seuil)
            texte = Libelle("accueil_prochain_trophee", .libelle(TropheeTextes.description(prochain)), .entier(reste))
        } else {
            texte = Libelle("trophees_tous")
        }
        return AccueilLigneTrophee(grade: grade, texte: texte, accessibilite: [TropheeTextes.grade(grade), texte])
    }

    /// « 🏆 Trophées » et « Mon parcours », côte à côte en bas de page (boutons à contour).
    public var libelleTrophees: Libelle { Libelle("trophees_paliers") }
    public var libelleParcours: Libelle { Libelle("parcours_title") }

    public func ouvrirPaliers() {
        routes.append(.paliers)
    }

    public func ouvrirParcours() {
        routes.append(.parcours)
    }

    /// Le bilan a été lu (« Continuer »).
    public func fermerBilan() {
        bilan = nil
    }

    // MARK: Commencer

    /// « Revenir à la hitbodedout en cours », « Faire une hitbodedout de plus », ou « Commencer une hitbodedout de
    /// 15 min » (StartButton : 60 pt de haut, coins de 30, 17 pt, l'icône de lecture devant le texte).
    public var libelleCommencer: Libelle {
        if enCours { return Libelle("action_back_to_session") }
        if faite { return Libelle("action_another_session") }
        return Libelle("action_start_session", .libelle(Store.formatDuration(reglages.targetMinutes)))
    }

    /// Un seul geste : la séance part tout de suite, avec la durée, le sujet et la musique des pastilles ; une
    /// séance en cours, on y revient.
    public func commencer() {
        routes.append(.seance(demarrer: !enCours))
    }

    /// « Préparer la séance » (start_prepare, FPRODUIT-04) : l'écran de préparation, sans démarrer — « Sans durée »
    /// et « Commencer simplement » y vivent.
    public var libellePreparer: Libelle { Libelle("start_prepare") }

    public func preparer() {
        routes.append(.seance(demarrer: false))
    }

    /// Les pastilles sous le bouton, dans l'ordre ; celle de la barrière seulement dans l'édition qui l'a.
    public var pastilles: [AccueilPastille] {
        var liste = [
            AccueilPastille(genre: .duree, etiquette: Libelle("start_duration"),
                            valeur: .libelle(Store.formatDuration(reglages.targetMinutes))),
            AccueilPastille(genre: .sujet, etiquette: Libelle("start_theme"),
                            valeur: .libelle(Libelle(sujet?.titre ?? "session_theme_none_short"))),
            // « start_music » a disparu avec la refonte de l'accueil d'Android (13/11) : le titre de l'écran de la musique.
            AccueilPastille(genre: .musique, etiquette: Libelle("music_title"), valeur: valeurMusique),
        ]
        if barriere {
            // L'état réel, en court (13/11, FPRODUIT-02) : « Activé » ne s'affiche plus pour rien.
            let etat = etatBarriere ?? (reglages.isEnabled ? .armed : .disabled)
            liste.append(AccueilPastille(genre: .barriere, etiquette: Libelle("start_focus"),
                                         valeur: .libelle(GateStatus.pastilleDe(etat))))
        }
        return liste
    }

    /// Ce que fait le toucher de la pastille « Avec Hachem » (GateRule.geste, 13/11, FBARRIERE-08) : basculer le mode
    /// s'il peut agir ; sinon mener à la carte du mode, ou relancer la surveillance arrêtée.
    public var gesteBarriere: GesteBarriere {
        GateRule.geste(faitsBarriere)
    }

    /// Les faits de GateStatus.faits, vus d'iOS : l'accès est l'autorisation de Temps d'écran ; une sélection que le
    /// système ne reconnaît plus ne compte pas d'application ; le « service » vit tant que la surveillance est
    /// inscrite et s'est réveillée dans le jour.
    private var faitsBarriere: GateFaits {
        let applications = constat.selectionValide == false ? 0 : nombreDeJetons
        var vivant = constat.surveillanceInscrite != false
        if let reveil = constat.dernierReveil, horloge.maintenant - reveil > Evaluation.silenceMaximum { vivant = false }
        return GateFaits(active: reglages.isEnabled, accesAccordes: constat.autorise, applications: applications,
                         serviceVivant: vivant, seanceEnCours: enCours, faite: false, exempte: false, reportee: false,
                         dansLaFenetre: false)
    }

    /// Une pastille touchée : la durée et le sujet se choisissent dans une liste, la musique ouvre son écran, la
    /// barrière du matin s'allume ou s'éteint d'un geste. Lève si les réglages ne s'écrivent pas.
    public func toucherPastille(_ genre: AccueilPastilleGenre) async throws {
        switch genre {
        case .duree:
            dialogue = .duree(.prochaine)
        case .sujet:
            dialogue = .sujet
        case .musique:
            routes.append(.musique)
        case .barriere:
            guard barriere else { return }
            switch gesteBarriere {
            case .regler:
                routes.append(.reglages(carteBarriere: true))
            case .relancer:
                await systeme?.appliquerEtat()
                await lireBarriere()
            case .basculer:
                let active = !reglages.isEnabled
                try await magasin.modifierReglages { $0.setEnabled(active) }
                await systeme?.appliquerEtat()
                await lireBarriere()
            }
        }
    }

    /// Le sujet de la prochaine séance ; nil : aucun.
    public var sujet: Theme? {
        guard case .chaine(let cle)? = reglages.brut[AccueilModele.cleSujet] else { return nil }
        return ThemeRules.parse(cle)
    }

    // MARK: La bande de la semaine

    /// Les sept cases, du dimanche au samedi.
    public var semaine: [AccueilJourSemaine] {
        let jour = aujourdhui
        let journal = magasin.journal
        return Store.currentWeek(journal: journal, reglages: reglages, aujourdhui: jour,
                                 fuseauTelephone: fuseauTelephone).map { (c: CaseSemaine) -> AccueilJourSemaine in
            // Le samedi chômé porte sa marque, pas un point à cocher.
            let repos = c.shabbat && c.exempt
            let minutes = journal.record(c.date)?.minutes ?? 0
            let montre = c.done && joursMontres.contains(c.date)
            let marque: AccueilTexte
            if montre {
                marque = .brut(JaugeSemaine.dureeCourte(minutes))
            } else if c.done {
                marque = .brut("\u{2713}")
            } else if repos {
                marque = .libelle(Libelle("week_shabbat_mark"))
            } else if c.exempt {
                marque = .brut("\u{2014}")
            } else {
                marque = .brut(String(c.date.jour))
            }
            let couleurMarque: AccueilCouleur
            if c.done {
                couleurMarque = .white
            } else if repos {
                couleurMarque = .brand
            } else if c.future {
                couleurMarque = .muted
            } else {
                couleurMarque = .ink
            }
            let fond: AccueilFondJour
            if c.done {
                fond = .faite
            } else if c.exempt {
                fond = .exempte
            } else if c.date == jour {
                fond = .aujourdhui
            } else {
                fond = .aFaire
            }
            let accessibilite: [Libelle]
            if c.done {
                accessibilite = [Libelle("week_done"), Store.formatDuration(minutes)]
            } else if repos {
                accessibilite = [Libelle("settings_shabbat")]
            } else if c.exempt {
                accessibilite = [Libelle("gate_exempt_title")]
            } else {
                accessibilite = [Libelle("week_todo")]
            }
            return AccueilJourSemaine(date: c.date, marque: marque, marqueReduite: montre,
                                      couleurEtiquette: c.done ? .white : .muted, couleurMarque: couleurMarque,
                                      fond: fond, ouvrable: AjoutTemps.possible(c.date, aujourdhui: jour),
                                      accessibilite: accessibilite)
        }
    }

    /// Une case touchée (AjoutTemps.ouvrir) : sa boîte, pour y ajouter du temps fait hors du téléphone ou, un jour
    /// fait, montrer sa durée sur la bande. Jamais un jour à venir.
    public func ouvrirJour(_ date: JourCivil) {
        guard AjoutTemps.possible(date, aujourdhui: aujourdhui) else { return }
        var minutes: Int? = nil
        if let journee = magasin.journal.record(date), journee.faite {
            minutes = journee.minutes
        }
        let message: Libelle
        if let minutes {
            message = Libelle("jour_fait", .libelle(Store.formatDuration(minutes)))
        } else {
            message = Libelle("jour_rien")
        }
        dialogue = .jour(AccueilJourDialogue(date: date, message: message, ajouter: Libelle("jour_ajouter_temps"),
                                             montrer: minutes == nil ? nil : Libelle("jour_montrer_duree"),
                                             retour: Libelle("action_back")))
    }

    /// « Ajouter du temps fait hors du téléphone », dans la boîte d'un jour : sa durée se choisit ensuite.
    public func ajouterTemps() {
        guard case .jour(let boite)? = dialogue else { return }
        dialogue = .duree(.ajout(boite.date))
    }

    /// « Montrer la durée » : elle remplace le ✓ sur la bande ; demandée encore, le ✓ revient.
    public func montrerDuree() {
        guard case .jour(let boite)? = dialogue else { return }
        dialogue = nil
        if joursMontres.contains(boite.date) {
            joursMontres.remove(boite.date)
        } else {
            joursMontres.insert(boite.date)
        }
    }

    // MARK: La relance

    /// Le mot de relance après une rupture de série (view_chizuk, moment « Reprendre la route ») : seulement à qui
    /// a déjà pratiqué et dont la série est retombée à zéro ; le même texte tant que la rupture dure.
    public var relance: ChizukCarte? {
        guard serieRompue, let chizuk, let id = relanceId, let item = chizuk.item(id) else { return nil }
        return ChizukCarte(item: item, chizuk: chizuk, moment: .relance, mode: modeLangues, langue: langue,
                           adresse: adresse)
    }

    // MARK: La note et la séance hors du téléphone

    /// « Écrire une note » (bouton texte, toute la largeur) : une journée faite seulement.
    public var libelleNote: Libelle? {
        faite ? Libelle("action_write_note") : nil
    }

    public func ecrireNote() {
        routes.append(.note(aujourdhui))
    }

    /// « Je l'ai faite sans le téléphone » (bouton texte, toute la largeur) : tant qu'aujourd'hui ou hier peut
    /// encore être inscrit, et hors séance.
    public var libelleHorsTelephone: Libelle? {
        ((!faite || hierOuvert) && !enCours) ? Libelle("action_done_offline") : nil
    }

    /// Une hitbodedout faite sans le téléphone : aujourd'hui, ou hier si hier n'est pas encore fait ; les deux
    /// ouverts, on demande lequel. Puis sa durée. Les dates sont figées au geste.
    public func declarerHorsTelephone() {
        let jour = aujourdhui
        let hier = jour.plus(jours: -1)
        let aujourdhuiOuvert = !magasin.journal.isDone(jour)
        if aujourdhuiOuvert && hierOuvert {
            dialogue = .jourHorsTelephone(aujourdhui: jour, hier: hier)
        } else if hierOuvert {
            dialogue = .duree(.horsTelephone(hier))
        } else {
            dialogue = .duree(.horsTelephone(jour))
        }
    }

    /// « Aujourd'hui » ou « Hier » choisi : sa durée ensuite.
    public func choisirJourHorsTelephone(hier: Bool) {
        guard case .jourHorsTelephone(let jour, let veille)? = dialogue else { return }
        dialogue = .duree(.horsTelephone(hier ? veille : jour))
    }

    // MARK: Les choix

    /// Le titre de la boîte ouverte, s'il en a un (celle d'un jour prend la date, écrite par la vue).
    public var titreDialogue: Libelle? {
        switch dialogue {
        case .duree(.prochaine)?: return Libelle("settings_target")
        case .duree?: return Libelle("offline_how_long")
        case .dureeLibre?: return Libelle("duration_custom_title")
        case .sujet?: return Libelle("session_theme_title")
        case .jourHorsTelephone?: return Libelle("offline_which_day")
        case .jour?, nil: return nil
        }
    }

    /// Les durées proposées (5, 10, 15, 30 min, 1 h, 1 h 30), puis « Durée réglable… ».
    public var optionsDuree: [AccueilOptionDuree] {
        DureeSeance.proposees.map { AccueilOptionDuree(minutes: $0, libelle: Store.formatDuration($0)) }
            + [AccueilOptionDuree(minutes: nil, libelle: Libelle("duration_custom"))]
    }

    /// Le champ de la durée réglable : prérempli de la durée habituelle, tout sélectionné.
    public var texteDureeLibre: String {
        String(reglages.targetMinutes)
    }

    public var indicationDureeLibre: Libelle { Libelle("duration_custom_hint") }

    /// « OK » de la durée réglable : `android.R.string.ok` sur Android, une chaîne du système ; clé neuve, la même
    /// qu'AjoutTempsModele et SeanceModele (fr « OK », en « OK », he « אישור »).
    public var libelleValider: Libelle { Libelle("action_ok") }

    /// « Aujourd'hui », « Hier ».
    public var optionsJourHorsTelephone: [Libelle] {
        [Libelle("offline_today"), Libelle("offline_yesterday")]
    }

    /// « Aucun » en tête, puis les sujets.
    public var optionsSujet: [AccueilOptionSujet] {
        [AccueilOptionSujet(theme: nil, libelle: Libelle("session_theme_none_short"))]
            + Theme.allCases.map { AccueilOptionSujet(theme: $0, libelle: Libelle($0.titre)) }
    }

    /// « Retour », le bouton qui ferme une boîte sans rien faire.
    public var libelleRetour: Libelle { Libelle("action_back") }

    /// La boîte se ferme sans rien faire (Retour, un toucher dehors).
    public func fermerDialogue() {
        dialogue = nil
    }

    /// Une ligne de la liste des durées : une durée, ou nil pour « Durée réglable… ». Lève si l'écriture échoue.
    public func choisirDuree(_ minutes: Int?) async throws {
        guard case .duree(let usage)? = dialogue else { return }
        guard let minutes else {
            dialogue = .dureeLibre(usage)
            return
        }
        dialogue = nil
        try await appliquerDuree(minutes, usage)
    }

    /// « OK » sur la durée réglable : le nombre lu, ramené de 1 à 240 ; ce qui n'est pas un nombre ne fait rien.
    /// « OK » de la durée réglable : un nombre de 1 à 240 minutes ; sinon la boîte reste ouverte et le dit sous le
    /// champ (FACCUEIL-15, DureeSeance.valide).
    public func validerDureeLibre(_ texte: String) async throws {
        guard case .dureeLibre(let usage)? = dialogue else { return }
        guard let minutes = DureeSeance.valide(texte) else {
            erreurSaisie = Libelle("duration_custom_hint")
            return
        }
        erreurSaisie = nil
        dialogue = nil
        try await appliquerDuree(minutes, usage)
    }

    /// Un sujet choisi, ou nil pour « Aucun ».
    public func choisirSujet(_ theme: Theme?) async throws {
        guard case .sujet? = dialogue else { return }
        dialogue = nil
        let cle = AccueilModele.cleSujet
        try await magasin.modifierReglages { r in
            var brut = r.brut
            if let theme {
                brut[cle] = JSON.chaine(theme.cle)
            } else {
                brut[cle] = nil
            }
            r = Reglages(brut: brut)
        }
    }

    // MARK: Les cartes du moment

    /// Les cartes sous les boutons du jour, dans l'ordre : les rappels de tefila, la prière de l'heure, Birkat
    /// haLevana, la source du jour. Un contenu illisible retire ses cartes, sans plus.
    public var cartes: [AccueilCarte] {
        var liste: [AccueilCarte] = []
        for r in rappels { liste.append(.rappel(r)) }
        if let siddur {
            let heure = horloge.dateHeure
            if let id = momentDuSiddour, let texte = siddur.texte(id) {
                liste.append(.priere(AccueilPriere(id: texte.id, etiquette: Libelle("siddur_maintenant"),
                                                   hebreu: PoliceHebraique.masque(texte.titre.he, police: police),
                                                   image: Personnage.pour(adresse, SiddurMoment.illustration(texte.id)),
                                                   mot: Libelle(Salutation.mot(heure.heure)),
                                                   route: .siddour(texte.id))))
            }
            if levanaCeSoir, let texte = siddur.texte("birkat_halevana") {
                liste.append(.priere(AccueilPriere(id: texte.id, etiquette: Libelle("levana_ce_soir"),
                                                   hebreu: PoliceHebraique.masque(texte.titre.he, police: police),
                                                   image: Personnage.pour(adresse, "char_praise"), mot: nil,
                                                   route: .siddour(texte.id))))
            }
        }
        if let bibliotheque, let pensee = SourceDuJour.choix(bibliotheque, aujourdhui) {
            liste.append(.source(AccueilSource(id: pensee.source.id, titre: Libelle("source_du_jour"),
                                               texte: PoliceHebraique.masque(SourceDuJour.extrait(pensee.texte), police: police),
                                               reference: Reference.localise(pensee.source.ref, langue),
                                               bouton: Libelle("source_du_jour_lire"),
                                               route: .entreeBibliotheque(pensee.source.id))))
        }
        return liste
    }

    /// Une carte touchée (prière, ou « Lire la suite » de la source) ouvre son texte.
    public func ouvrir(_ route: AccueilRoute) {
        routes.append(route)
    }

    /// Les changements de la tefila des jours à venir (RappelsTefilaVue.cartes).
    public var rappels: [AccueilRappel] {
        let jour = aujourdhui
        let israel = enIsrael
        let muk = reglages.mukafChoma
        let edot = reglages.siddurNusah == .edot
        let sansGuechem = edot && reglages.hemisphereSud
        let liste = RappelsTefila.prochains(jour, sansGuechem: sansGuechem) { d in
            CalendrierJuif.jour(d, enIsrael: israel, mukafChoma: muk)
        }
        return liste.map { (r: RappelsTefila.Rappel) -> AccueilRappel in
            let titre: String
            let corps: String
            switch r.genre {
            case .pluieDebut:
                titre = "rappel_pluie_debut_titre"
                corps = edot ? "rappel_pluie_debut_edot" : "rappel_pluie_debut"
            case .pluieFin:
                titre = "rappel_pluie_fin_titre"
                corps = edot ? "rappel_pluie_fin_edot" : "rappel_pluie_fin"
            case .guechemDebut:
                titre = "rappel_guechem_titre"
                corps = "rappel_guechem_debut"
            case .guechemFin:
                titre = "rappel_guechem_titre"
                corps = RappelsTefila.cleGuechemFin(reglages.siddurNusah, enIsrael: israel)
            case .dixJours:
                titre = "rappel_dix_jours_titre"
                corps = "rappel_dix_jours"
            case .omer:
                titre = "rappel_omer_titre"
                corps = "rappel_omer"
            }
            return AccueilRappel(genre: r.genre, date: r.date, titre: Libelle(titre), cleCorps: corps,
                                 quand: AccueilModele.quand(r, aujourdhui: jour),
                                 source: Libelle("rappel_source", .texte(sourceLocale(r.genre.source))))
        }
    }

    /// Le moment d'un changement, en tête de sa phrase (RappelsTefilaVue.moment).
    nonisolated static func quand(_ r: RappelsTefila.Rappel, aujourdhui: JourCivil) -> AccueilQuand {
        if !r.genre.leSoir {
            if r.date == aujourdhui { return .aujourdhui }
            if r.date == aujourdhui.plus(jours: 1) { return .demain }
            return .jour(r.date)
        }
        let soir = r.date.plus(jours: -1)
        if soir < aujourdhui { return .hierSoir }
        if soir.jourDeSemaine == 7 { return .motsae }
        if soir == aujourdhui { return .ceSoir }
        if soir == aujourdhui.plus(jours: 1) { return .demainSoir }
        return .soir(soir)
    }

    /// « 117:1 » ; en hébreu « קי״ז, א׳ », comme les autres références de l'app.
    private func sourceLocale(_ source: String) -> String {
        guard langue.egalUnites("he") else { return source }
        let morceaux = source.split(separator: ":").compactMap { Int($0) }
        guard morceaux.count == 2 else { return source }
        return Reference.lettres(morceaux[0]) + ", " + Reference.lettres(morceaux[1])
    }

    /// La prière que suggère l'heure : avec un lieu, d'après ses zmanim (nil dans les creux) ; sans lieu, les heures
    /// fixes de SiddurMoment.
    /// La nuit de Chabbat, de fête ou de 'Hol hamoed Pessa'h, pas de Tikoun 'hatsot ; pas d'office de semaine proposé
    /// un Chabbat ou un Yom tov (audit du 16/11, AccueilMoment.kt).
    private var momentDuSiddour: String? {
        let heure = horloge.dateHeure
        let brut: String?
        if let lieu = reglages.lieuZmanim {
            brut = JourAffiche.momentDuSiddour(lieu: lieu, maintenant: Date(timeIntervalSince1970: Double(horloge.maintenant) / 1000),
                                               enIsrael: enIsrael, nusah: reglages.siddurNusah)
        } else {
            brut = SiddurMoment.suggestion(heure: heure.heure, minute: heure.minute,
                                           sansTikoun: JourAffiche.sansTikounHatsot(aujourdhui, enIsrael: enIsrael))
        }
        return JourAffiche.momentOuvrable(brut, date: aujourdhui, heure: heure.heure, enIsrael: enIsrael)
    }

    /// Birkat haLevana se dit ce soir : dans la fenêtre de l'usage suivi, à partir de 14 h, dans le fuseau du lieu
    /// (celui du téléphone sans lieu).
    private var levanaCeSoir: Bool {
        let zone = reglages.lieuZmanim.flatMap { Fuseau($0.fuseau) } ?? horloge.fuseau
        let maintenant = zone.dateHeure(millis: horloge.maintenant)
        let usage = reglages.levanaUsage.flatMap { Levana.Usage(rawValue: $0) } ?? Levana.Usage.duNusah(reglages.siddurNusah)
        let fenetre = Levana.fenetre(maintenant.jour, fuseau: zone, usage: usage,
                                     horaires: Levana.Horaires.du(reglages.lieuZmanim, fuseau: zone))
        // Ni un soir de Chabbat ou de Yom tov qui n'est pas le dernier (audit du 16/11, MB 426:12 ; YY 426:33), ni
        // après la fermeture de la fenêtre.
        switch Levana.etat(fenetre, maintenant.jour, fuseau: zone, enIsrael: enIsrael) {
        case .ceSoir, .dernierSoir: return maintenant.heure >= 14 && horloge.maintenant < fenetre.fin
        default: return false
        }
    }

    // MARK: Ce qui se lit

    /// La clé du sujet de la prochaine séance (KEY_SESSION_THEME de Store.kt).
    nonisolated static let cleSujet = "session_theme"

    private var reglages: Reglages {
        magasin.reglages
    }

    private var aujourdhui: JourCivil {
        horloge.aujourdhui
    }

    private var fuseauTelephone: String {
        horloge.fuseau.identifiant
    }

    private var enIsrael: Bool {
        reglages.inIsrael(fuseauTelephone: fuseauTelephone)
    }

    private var enCours: Bool {
        Store.isSessionRunning(reglages: reglages, millis: horloge.maintenant)
    }

    /// Une note seule ne fait pas la journée.
    private var faite: Bool {
        magasin.journal.record(aujourdhui)?.faite ?? false
    }

    private var serie: Int {
        Store.streak(journal: magasin.journal, reglages: reglages, aujourdhui: aujourdhui,
                     fuseauTelephone: fuseauTelephone)
    }

    private var serieRompue: Bool {
        serie == 0 && magasin.journal.aDejaPratique
    }

    /// Hier n'est ni fait ni exempté : on peut encore l'inscrire.
    private var hierOuvert: Bool {
        let hier = aujourdhui.plus(jours: -1)
        return !magasin.journal.isDone(hier)
            && !Store.isExempt(reglages: reglages, date: hier, fuseauTelephone: fuseauTelephone)
    }

    private var pratique: Trophees.Pratique {
        Store.pratique(journal: magasin.journal, reglages: reglages, aujourdhui: aujourdhui,
                       fuseauTelephone: fuseauTelephone)
    }

    private var adresse: Adresse? {
        Adresse.parse(reglages.adresse)
    }

    /// La police des textes hébreux des cartes (prière, source du jour) : `.policeHebraique(police, taille:)`.
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: reglages.lecturePolice) ?? .serif
    }

    /// Les langues de lecture : le choix enregistré, sinon celles de la langue de l'app (LanguesTexte.mode).
    private var modeLangues: LanguesTexte.Mode {
        if let cle = reglages.lectureLangues, let mode = LanguesTexte.Mode(rawValue: cle) { return mode }
        return LanguesTexte.defaut(langue)
    }

    /// La pastille de la musique : éteinte ou sans morceau (les phrases de la carte de la musique d'Android,
    /// MainActivity.renderMusic, depuis la refonte du 13/11), « Aléatoire », ou le morceau retenu.
    private var valeurMusique: AccueilTexte {
        guard reglages.musicEnabled else { return .libelle(Libelle("music_off_summary")) }
        let etat = MusicLibrary.Etat(names: reglages.musicNames, userTracks: reglages.musicUserTracks,
                                     trackId: reglages.musicTrackId)
        guard let morceau = MusicLibrary.selected(etat) else { return .libelle(Libelle("music_none_summary")) }
        if reglages.musicShuffle { return .libelle(Libelle("music_shuffle_short")) }
        switch morceau.title {
        case .nom(let nom): return .brut(nom)
        case .libelle(let libelle): return .libelle(libelle)
        }
    }

    // MARK: Les gestes intérieurs

    /// Relit Temps d'écran et recalcule l'état de la barrière (renderStartCard : GateStatus.evaluate).
    private func lireBarriere() async {
        guard barriere else {
            etatBarriere = nil
            return
        }
        if let systemeBarriere {
            constat = await systemeBarriere.constat()
            nombreDeJetons = max(await systemeBarriere.nombreDeJetons(), 0)
        }
        let millis = horloge.maintenant
        let fuseau = horloge.fuseau
        let etat = EtatBarriere.etat(journal: magasin.journal, reglages: reglages, millis: millis, fuseau: fuseau,
                                     nombreDeJetons: nombreDeJetons, textes: { $0.cle })
        etatBarriere = GateStatus.evaluate(etat, maintenant: EtatBarriere.horodatage(millis: millis, fuseau: fuseau),
                                           constat: constat)
    }

    /// Les contenus des cartes : le siddour du nusah choisi, la bibliothèque, les textes de 'hizouk. Un contenu
    /// illisible ne montre pas ses cartes ; il sera relu au passage suivant.
    private func lireContenus() async {
        siddur = try? await contenus.siddur(reglages.siddurNusah)
        if bibliotheque == nil { bibliotheque = try? await contenus.bibliotheque() }
        if chizuk == nil { chizuk = try? await contenus.chizuk() }
    }

    /// refresh() : le mot de relance, tiré au premier affichage de la rupture seulement.
    private func rafraichir() async {
        guard serieRompue else {
            relanceTiree = false
            relanceId = nil
            return
        }
        guard !relanceTiree, let chizuk else { return }
        relanceTiree = true
        let debug = self.debug
        let melange = self.melange
        do {
            relanceId = try await magasin.modifierReglages { r in
                ChizukSac.tirer(chizuk, moment: .relance, debug: debug, reglages: &r, melange: melange)
            }
        } catch {
            relanceId = ChizukSac.dernier(reglages, moment: .relance)
        }
    }

    /// Le bilan de la semaine écoulée : à la première ouverture de la semaine, une fois.
    private func bilanDeLaSemaine() async {
        let jour = aujourdhui
        let debut = BilanSemaine.debutSemaine(jour).plus(jours: -7)
        if let vu = reglages.bilanVu, vu.egalUnites(debut.iso) { return }
        let journal = magasin.journal
        let minutes = Store.bilan(journal: journal, reglages: reglages, aujourdhui: jour,
                                  fuseauTelephone: fuseauTelephone).minutes
        let dates = Store.datesTrophees(journal: journal, reglages: reglages, fuseauTelephone: fuseauTelephone)
        guard let b = BilanSemaine.precedente(jour, minutes: minutes, dates: dates) else {
            let iso = debut.iso
            try? await magasin.modifierReglages { $0.setBilanVu(iso) }
            return
        }
        let iso = b.debut.iso
        try? await magasin.modifierReglages { $0.setBilanVu(iso) }
        let p = pratique
        let faits = Trophees.chemin.filter { Trophees.gagne(p, $0) }
        let trophees = b.trophees.prefix(6).map { (t: Trophees.Niveau) -> AccueilBilanTrophee in
            AccueilBilanTrophee(niveau: t, forme: t.famille.forme,
                                metal: Trophees.grade((faits.firstIndex(of: t) ?? -1) + 1),
                                icone: t.famille.icone, description: TropheeTextes.description(t))
        }
        bilan = AccueilBilan(
            debut: b.debut, titre: Libelle("bilan_titre"),
            minutes: Libelle("bilan_minutes", .libelle(Store.formatDuration(b.minutes)),
                             .libelle(Libelle.pluriel("palier_n_jours", quantite: b.jours, .entier(b.jours)))),
            plus: b.ecart > 0 && b.precedente > 0 ? Libelle("bilan_plus", .libelle(Store.formatDuration(b.ecart))) : nil,
            record: b.record ? Libelle("bilan_record") : nil,
            titreTrophees: b.trophees.isEmpty ? nil : Libelle("bilan_trophees"),
            trophees: trophees, bouton: Libelle("celebration_continue"))
    }

    /// CelebrationActivity.showIfPending : le bravo en attente est pris, et son écran s'ouvre.
    private func celebrationEnAttente() async {
        var copie = reglages
        guard let celebration = copie.takePendingCelebration() else { return }
        routes.append(.celebration(minutes: celebration.minutes, dateNote: celebration.dateNote))
        // Une écriture refusée garde le changement en mémoire : le bravo est pris quand même.
        let sans = copie
        try? await magasin.modifierReglages { $0 = sans }
    }

    /// Une durée choisie, selon ce à quoi elle sert.
    private func appliquerDuree(_ minutes: Int, _ usage: AccueilUsageDuree) async throws {
        switch usage {
        case .prochaine:
            try await magasin.modifierReglages { $0.setTargetMinutes(minutes) }
        case .horsTelephone(let date):
            try await inscrire(minutes, date: date, bravo: date == aujourdhui)
            if minutes > 0 { await systeme?.retirerRappelDuJour() }
            await systeme?.rafraichirVignettes()
            await celebrationEnAttente()
        case .ajout(let date):
            try await inscrire(minutes, date: date, bravo: false)
            if minutes > 0 { await systeme?.retirerRappelDuJour() }
            await systeme?.rafraichirVignettes()
            message = Libelle("jour_ajoute", .libelle(Store.formatDuration(minutes)))
            try? await fete.passer()
            await bilanDeLaSemaine()
        }
        await rafraichir()
        // Une journée inscrite lève la barrière du jour : la pastille le dit aussitôt.
        await lireBarriere()
        montrerAnneaux(depuisZero: false)
    }

    /// Store.addSession sans sujet (celui des pastilles est celui de la PROCHAINE séance), puis ce qui est neuf est
    /// marqué comme notifié : l'application est ouverte, la fête se fait à l'écran (Celebrations.marquerNotifies).
    /// `bravo` : le bravo attend, pour ce jour (une séance d'aujourd'hui).
    private func inscrire(_ minutes: Int, date: JourCivil, bravo: Bool) async throws {
        var journal = magasin.journal
        var r = reglages
        let jour = aujourdhui
        Store.addSession(journal: &journal, reglages: &r, minutes: minutes, theme: nil, date: date,
                         millis: horloge.maintenant, fuseau: horloge.fuseau)
        let zone = fuseauTelephone
        let neuf = Celebrations.marquerNotifies(
            Store.bilan(journal: journal, reglages: r, aujourdhui: jour, fuseauTelephone: zone),
            Store.pratique(journal: journal, reglages: r, aujourdhui: jour, fuseauTelephone: zone),
            paliersNotifies: r.paliersNotifies, tropheesNotifies: r.tropheesNotifies)
        r.setPaliersNotifies(neuf.marques)
        r.setTropheesNotifies(neuf.trophees)
        if bravo { r.setPendingCelebration(minutes: minutes, dateNote: date.iso) }
        let nouveau = journal
        let nouveaux = r
        try await magasin.modifierJournal { $0 = nouveau }
        try await magasin.modifierReglages { $0 = nouveaux }
    }

    /// Les anneaux montrent l'état d'ici et maintenant ; ils se remplissent depuis zéro au premier affichage, quand
    /// il a changé, ou si `depuisZero` le demande (AnneauxView.montrer). Sans animations, ils sont pleins d'emblée.
    private func montrerAnneaux(depuisZero: Bool) {
        let nouvel = anneaux
        let rejouer = anneauxMontres == nil || anneauxMontres != nouvel || depuisZero
        anneauxMontres = nouvel
        guard rejouer else { return }
        if reduireAnimations {
            remplissage = nil
            return
        }
        numeroRemplissage += 1
        remplissage = numeroRemplissage
    }

    /// Met un anneau en avant, ou revient aux trois (nil) ; sa face s'affiche au centre si elle n'y est pas.
    private func mettreEnAvant(_ quel: Anneaux.Quel?) {
        guard misEnAvant != quel else { return }
        misEnAvant = quel
        if quel != face.anneau {
            if let quel {
                tournerPlaque(Plaque.pour(quel))
            } else {
                tournerPlaque(.hassid)
            }
        }
    }

    /// La plaque tourne vers une face ; une face autre que le hassid revient au hassid après `dureeRetourHassid`.
    private func tournerPlaque(_ vers: Plaque.Face) {
        numeroRetour += 1
        retourHassidPrevu = vers == .hassid ? nil : numeroRetour
        guard vers != face else { return }
        montrerFace(vers)
        if !reduireAnimations {
            retournements += 1
            // Revenu au hassid, il salue d'un saut, une fois le retournement fini.
            if vers == .hassid { sauter(1) }
        }
    }

    /// Remplit la plaque avec `vers`, et met en avant l'anneau dont elle parle.
    private func montrerFace(_ vers: Plaque.Face) {
        face = vers
        if vers == .hassid { retourHassidPrevu = nil }
        mettreEnAvant(vers.anneau)
    }

    private func sauter(_ fois: Int) {
        guard fois > 0, !reduireAnimations else { return }
        numeroEvenement += 1
        saut = AccueilSaut(fois: fois, numero: numeroEvenement)
    }
}
