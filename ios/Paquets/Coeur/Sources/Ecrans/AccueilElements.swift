import Foundation
import Coeur

// Ce que montre l'accueil (onglet Aujourd'hui, le panneau main_scroll de MainActivity.kt) : des valeurs prêtes à
// afficher, que `AccueilModele` calcule et que la vue lit sans rien décider. Ici aussi le dessin des trois anneaux
// (AnneauxDessin.kt) réduit à ses nombres, et le service système que l'accueil prévient.

// MARK: Textes et couleurs

/// Un texte de l'accueil : une chaîne de l'interface, ou un texte écrit tel quel (un chiffre, le nom d'un morceau,
/// une marque de la bande de la semaine).
public enum AccueilTexte: Sendable, Hashable {
    case libelle(Libelle)
    case brut(String)
}

/// Les couleurs de l'accueil. `brand`, `ink` et `muted` sont des jetons de la palette (`Jeton`) ; `ringWeek`,
/// `ringStreak` et `white` sont des couleurs fixes de res/values/colors.xml (#2E7DB3, #B8780F, #FFFFFF ; la nuit,
/// values-night : #6FB7E8, #E8B45C), que la palette n'a pas encore.
public enum AccueilCouleur: String, Sendable, CaseIterable {
    case brand
    case ringWeek = "ring_week"
    case ringStreak = "ring_streak"
    case ink
    case muted
    case white
}

/// Les quatre états du jour, ceux des captures de la feuille de route (MainActivity.renderToday).
public enum AccueilEtatJour: Sendable, Hashable, CaseIterable {
    /// La hitbodedout du jour reste à faire.
    case aFaire
    /// Une séance est en cours.
    case enCours
    /// La journée est faite (une note seule ne la fait pas).
    case faite
    /// Chabbat, fête ou date en pause : rien n'est attendu.
    case repos
}

/// La couleur d'un anneau, ou de ce qui parle de lui (la légende, le chiffre de la plaque).
func accueilCouleur(_ quel: Anneaux.Quel?, sinon: AccueilCouleur) -> AccueilCouleur {
    switch quel {
    case .jour: return .brand
    case .semaine: return .ringWeek
    case .serie: return .ringStreak
    case nil: return sinon
    }
}

// MARK: La plaque au centre des anneaux

/// Comment s'écrit le chiffre d'une face.
public enum AccueilFormatChiffre: Sendable, Hashable {
    /// Une durée (Store.formatDuration) : « 20 min », « 1 h 30 ».
    case duree
    /// « 3/5 » (plaque_semaine_valeur) : les jours faits sur les jours dus.
    case semaine(objectif: Int)
    /// Le nombre tel quel.
    case nombre
}

/// Une face de la plaque autre que le hassid (MainActivity.remplirFace) : un chiffre et ce qu'il compte.
public struct AccueilFace: Sendable, Equatable {
    public let face: Plaque.Face
    /// Le chiffre où le compteur s'arrête.
    public let cible: Int
    public let format: AccueilFormatChiffre
    /// Ce que le chiffre compte, sous lui (12 pt, atténué, trois lignes au plus).
    public let legende: Libelle
    /// La couleur du chiffre : celle de l'anneau dont parle la face, l'encre sinon.
    public let couleur: AccueilCouleur
    /// Le chiffre monte de 0 à `cible` en 650 ms (en ralentissant) : seulement s'il y a de quoi monter et que les
    /// animations ne sont pas réduites. Sinon il s'écrit d'un coup.
    public let compte: Bool

    public init(face: Plaque.Face, cible: Int, format: AccueilFormatChiffre, legende: Libelle,
                couleur: AccueilCouleur, compte: Bool) {
        self.face = face
        self.cible = cible
        self.format = format
        self.legende = legende
        self.couleur = couleur
        self.compte = compte
    }

    /// Le chiffre écrit pour une valeur du compteur (de 0 à `cible`).
    public func valeur(_ n: Int) -> AccueilTexte {
        switch format {
        case .duree: return .libelle(Store.formatDuration(n))
        case .semaine(let objectif): return .libelle(Libelle("plaque_semaine_valeur", .entier(n), .entier(objectif)))
        case .nombre: return .brut(String(n))
        }
    }

    /// Le chiffre arrivé au bout.
    public var texte: AccueilTexte { valeur(cible) }

    /// Ce que lit la lecture d'écran sur la plaque : le chiffre, puis sa légende, joints d'une espace.
    public var accessibilite: [AccueilTexte] { [texte, .libelle(legende)] }
}

/// Un anneau qui vient de se fermer, à fêter (MainActivity.apresRemplissage, AnneauxView.feter) : retour
/// haptique de confirmation, les anneaux battent deux fois (×1,07 en 180 ms, retour en 260 ms avec dépassement),
/// l'anneau passe devant et sa face s'affiche le temps de `AccueilModele.dureeFeteAnneau`. `numero` change à
/// chaque fête : la vue s'en sert d'identité.
public struct AccueilFeteAnneau: Sendable, Hashable {
    public let quel: Anneaux.Quel
    public let numero: Int
}

/// Le petit saut du hassid (MainActivity.sautiller), `fois` de suite : 10 pt vers le haut, ×1,04 / ×1,06, −3° en
/// 220 ms ; retour en 260 ms en rebond, +3° ; puis 0° en 160 ms. Jamais quand les animations sont réduites.
public struct AccueilSaut: Sendable, Hashable {
    public let fois: Int
    public let numero: Int
}

// MARK: La bande de la semaine

/// Le fond d'une case de la bande (bg_day_*), coins de 12 pt.
public enum AccueilFondJour: Sendable, Hashable {
    /// bg_day_done : la couleur des jours faits (jeton `dayDone`).
    case faite
    /// bg_day_exempt : day_exempt (#F3EEE2 ; la nuit #36322A).
    case exempte
    /// bg_day_today : `dayTodo`, bordé de 1,5 pt de `brand`.
    case aujourdhui
    /// bg_day_todo : `dayTodo`.
    case aFaire
}

/// Une case de la bande de la semaine, du dimanche au samedi (MainActivity.renderWeek, item_day.xml).
public struct AccueilJourSemaine: Sendable, Hashable, Identifiable {
    public let date: JourCivil
    /// Le jour de la semaine en abrégé (« EEE » dans la langue de l'app), que la vue écrit d'après `date`.
    /// La marque : ✓, la durée d'un jour fait touché, ש le Chabbat chômé, — un jour exempté, sinon le quantième.
    public let marque: AccueilTexte
    /// La durée d'un jour touché s'écrit aux trois quarts de la taille (16 pt → 12 pt).
    public let marqueReduite: Bool
    public let couleurEtiquette: AccueilCouleur
    public let couleurMarque: AccueilCouleur
    public let fond: AccueilFondJour
    /// Tout jour jusqu'à aujourd'hui s'ouvre (AjoutTemps.possible) : `AccueilModele.ouvrirJour`.
    public let ouvrable: Bool
    /// Ce que lit la lecture d'écran, joint par « · ».
    public let accessibilite: [Libelle]

    public var id: String { date.iso }
}

// MARK: Les pastilles de départ

/// Les pastilles sous « Commencer », dans l'ordre (activity_main.xml).
public enum AccueilPastilleGenre: String, Sendable, Hashable, CaseIterable {
    case duree, sujet, musique, barriere
}

/// Une pastille : « Durée 15 min », « Sujet Aucun »… (StartChip, StartChipLabel, StartChipValue).
public struct AccueilPastille: Sendable, Hashable, Identifiable {
    public let genre: AccueilPastilleGenre
    /// L'étiquette, atténuée.
    public let etiquette: Libelle
    /// La valeur, en gras, couleur de marque, une ligne, 160 pt au plus.
    public let valeur: AccueilTexte

    public var id: String { genre.rawValue }
}

// MARK: La ligne des trophées

/// Le grade et le prochain trophée, sous les anneaux (MainActivity.renderPaliers, paliers_line).
public struct AccueilLigneTrophee: Sendable, Hashable {
    /// Le métal de la médaille (TropheeDessin, forme MEDAILLE, icône ★), 26 pt, avant le texte.
    public let grade: Trophees.Metal
    /// « Prochain trophée : … · encore 3 », ou « Tous les trophées sont gagnés ! » ; la vue y ajoute « ›».
    public let texte: Libelle
    /// « Grade Argent », puis le texte : joints par « . ».
    public let accessibilite: [Libelle]
}

// MARK: Les cartes du moment

/// Quand un changement de la tefila a lieu, en tête de sa phrase (RappelsTefilaVue.moment).
public enum AccueilQuand: Sendable, Hashable {
    case aujourdhui
    case demain
    /// Le jour de la semaine, en toutes lettres (« EEEE », majuscule initiale).
    case jour(JourCivil)
    case hierSoir
    case motsae
    case ceSoir
    case demainSoir
    /// « Mardi soir » : le jour en toutes lettres, dans rappel_soir.
    case soir(JourCivil)

    /// L'argument de la phrase. `jourSemaine` écrit un jour en toutes lettres, majuscule initiale, dans la
    /// langue de l'app (`DateTimeFormatter.ofPattern("EEEE")` puis `replaceFirstChar { titlecase }`).
    public func argument(jourSemaine: (JourCivil) -> String) -> Libelle.Argument {
        switch self {
        case .aujourdhui: return .libelle(Libelle("rappel_aujourdhui"))
        case .demain: return .libelle(Libelle("rappel_demain"))
        case .jour(let d): return .texte(jourSemaine(d))
        case .hierSoir: return .libelle(Libelle("rappel_hier_soir"))
        case .motsae: return .libelle(Libelle("rappel_motsae"))
        case .ceSoir: return .libelle(Libelle("rappel_ce_soir"))
        case .demainSoir: return .libelle(Libelle("rappel_demain_soir"))
        case .soir(let d): return .libelle(Libelle("rappel_soir", .texte(jourSemaine(d))))
        }
    }
}

/// Un changement dans la tefila, annoncé quelques jours avant (RappelsTefilaVue.cartes) : une carte (bg_card),
/// trois lignes centrées.
public struct AccueilRappel: Sendable, Hashable, Identifiable {
    public let genre: RappelsTefila.Genre
    public let date: JourCivil
    /// 19 pt, gras, encre.
    public let titre: Libelle
    /// La clé de la phrase (16 pt, encre, interligne 1,25), qui prend `quand` en argument.
    public let cleCorps: String
    public let quand: AccueilQuand
    /// « Choul'han Aroukh, Ora'h 'Haïm 117:1 » (en hébreu, la référence en lettres), 12 pt, atténué.
    public let source: Libelle

    public var id: String { genre.rawValue + ":" + date.iso }

    /// La phrase, `jourSemaine` écrivant un jour en toutes lettres (voir `AccueilQuand.argument`).
    public func corps(jourSemaine: (JourCivil) -> String) -> Libelle {
        Libelle(cleCorps, quand.argument(jourSemaine: jourSemaine))
    }
}

/// Une carte de prière (AccueilMoment.carte) : la prière de l'heure, ou Birkat haLevana les soirs de la fenêtre.
public struct AccueilPriere: Sendable, Hashable, Identifiable {
    /// L'identifiant du texte du siddour.
    public let id: String
    /// « Pour cette heure », « Possible ce soir » : 12 pt, capitales, espacement 0,06, couleur de marque.
    public let etiquette: Libelle
    /// Le titre hébreu, 21 pt gras, de droite à gauche, dans la police choisie (déjà masqué pour elle).
    public let hebreu: String
    /// Le personnage (48 × 56), au féminin s'il le faut.
    public let image: String
    /// Le mot du moment (13 pt, atténué), sous la prière de l'heure seulement.
    public let mot: Libelle?
    public let route: AccueilRoute
}

/// La source du jour (SourceDuJour.carte) : un paragraphe des sources libres, le même toute la journée.
public struct AccueilSource: Sendable, Hashable, Identifiable {
    /// L'identifiant de l'entrée de la bibliothèque.
    public let id: String
    /// « Source du jour » : 12 pt, capitales, espacement 0,06, couleur de marque.
    public let titre: Libelle
    /// L'extrait (320 unités au plus, coupé à un mot, « … »), hébreu de droite à gauche, 18 pt, interligne +4,
    /// encre, police choisie (déjà masqué pour elle).
    public let texte: String
    /// La référence dans la langue de l'app, 13 pt, italique, atténuée.
    public let reference: String
    /// « Lire la suite », bouton à contour sur toute la largeur.
    public let bouton: Libelle
    public let route: AccueilRoute
}

/// Une carte sous les boutons du jour (accueil_moment), dans l'ordre d'Android : les rappels de tefila, la prière
/// de l'heure, Birkat haLevana, la source du jour.
public enum AccueilCarte: Sendable, Hashable, Identifiable {
    case rappel(AccueilRappel)
    case priere(AccueilPriere)
    case source(AccueilSource)

    public var id: String {
        switch self {
        case .rappel(let r): return "rappel:" + r.id
        case .priere(let p): return "priere:" + p.id
        case .source(let s): return "source:" + s.id
        }
    }
}

// MARK: Le bilan de la semaine

/// Un trophée gagné la semaine écoulée : sa médaille, 40 × 40, 6 pt entre deux.
public struct AccueilBilanTrophee: Sendable, Hashable, Identifiable {
    public let niveau: Trophees.Niveau
    public let forme: Trophees.Forme
    /// Le grade de son rang parmi les gagnés (`faits.indexOf(t) + 1`).
    public let metal: Trophees.Metal
    public let icone: String
    /// Pour la lecture d'écran.
    public let description: Libelle

    public var id: String { niveau.cle }
}

/// Le bilan de la semaine écoulée (MainActivity.bilanDeLaSemaine) : une boîte, une fois par semaine.
public struct AccueilBilan: Sendable, Hashable {
    /// Le dimanche de la semaine résumée.
    public let debut: JourCivil
    /// « Votre semaine ».
    public let titre: Libelle
    /// « 1 h 20 de hitbodedout, sur 5 jours. » : 17 pt, gras, encre.
    public let minutes: Libelle
    /// « 20 min de plus que la semaine d'avant. » : 15 pt, atténué, 6 pt au-dessus.
    public let plus: Libelle?
    /// « Votre meilleure semaine jusqu'ici. » : 15 pt, gras, couleur de marque, 6 pt au-dessus.
    public let record: Libelle?
    /// « Trophées gagnés cette semaine : » : 15 pt, atténué, 10 pt au-dessus ; nil sans trophée.
    public let titreTrophees: Libelle?
    /// Six au plus, en rangée.
    public let trophees: [AccueilBilanTrophee]
    /// « Continuer » ferme la boîte.
    public let bouton: Libelle
}

// MARK: Les dialogues

/// À quoi sert une durée choisie.
public enum AccueilUsageDuree: Sendable, Hashable {
    /// La durée de la prochaine séance (pastille « Durée », titre settings_target).
    case prochaine
    /// Une hitbodedout faite sans le téléphone, ce jour-là (titre offline_how_long) ; le bravo suit si c'est
    /// aujourd'hui.
    case horsTelephone(JourCivil)
    /// Du temps ajouté à un jour de la bande (AjoutTemps, titre offline_how_long).
    case ajout(JourCivil)
}

/// Une ligne du choix de la durée : une durée proposée, ou « Durée réglable… » (minutes nil).
public struct AccueilOptionDuree: Sendable, Hashable, Identifiable {
    public let minutes: Int?
    public let libelle: Libelle

    public var id: Int { minutes ?? -1 }
}

/// Une ligne du choix du sujet : « Aucun » (nil), puis les sujets dans l'ordre de Theme.
public struct AccueilOptionSujet: Sendable, Hashable, Identifiable {
    public let theme: Theme?
    public let libelle: Libelle

    public var id: String { theme?.cle ?? "" }
}

/// La boîte d'un jour de la bande (AjoutTemps.ouvrir).
public struct AccueilJourDialogue: Sendable, Hashable {
    /// Le titre : la date en entier (`FormatStyle.FULL`), que la vue écrit.
    public let date: JourCivil
    /// « Rien d'inscrit ce jour. », ou « Inscrit ce jour : 20 min. ».
    public let message: Libelle
    /// « Ajouter du temps fait hors du téléphone » (bouton principal).
    public let ajouter: Libelle
    /// « Montrer la durée » (bouton neutre) : seulement pour un jour fait.
    public let montrer: Libelle?
    /// « Retour ».
    public let retour: Libelle
}

/// La boîte ouverte sur l'accueil ; nil : aucune.
public enum AccueilDialogue: Sendable, Hashable {
    /// Une liste : les durées proposées, puis « Durée réglable… » (DureeSeance.choisir).
    case duree(AccueilUsageDuree)
    /// Un champ numérique, prérempli de la durée habituelle (DureeSeance.saisir) : titre duration_custom_title,
    /// indication duration_custom_hint, « OK » et « Retour ».
    case dureeLibre(AccueilUsageDuree)
    /// Une liste : « Aucun » puis les sujets (titre session_theme_title).
    case sujet
    /// Une liste à deux lignes, « Aujourd'hui » et « Hier » (titre offline_which_day).
    case jourHorsTelephone(aujourdhui: JourCivil, hier: JourCivil)
    /// La boîte d'un jour de la bande.
    case jour(AccueilJourDialogue)
}

// MARK: Les écrans ouverts

/// Les écrans que l'accueil ouvre, avec leurs paramètres.
public enum AccueilRoute: Sendable, Hashable {
    /// SessionActivity ; `demarrer` est EXTRA_START_NOW : vrai sauf s'il y a déjà une séance en cours (on y revient).
    case seance(demarrer: Bool)
    /// PaliersActivity : les trophées et les paliers.
    case paliers
    /// ParcoursActivity : « Mon parcours ».
    case parcours
    /// MusicActivity : la musique de la séance.
    case musique
    /// NoteDialog.show(date) : la note d'un jour.
    case note(JourCivil)
    /// CelebrationActivity : EXTRA_MINUTES, EXTRA_NOTE_DATE (le jour de la note qu'elle proposera, AAAA-MM-JJ).
    case celebration(minutes: Int, dateNote: String?)
    /// OnboardingActivity : la présentation, une fois par version.
    case presentation
    /// SiddurLectureActivity.ouvrir(id) : un texte du siddour, dans le nusah choisi.
    case siddour(String)
    /// LibraryEntryActivity, EXTRA_ID : une entrée de la bibliothèque.
    case entreeBibliotheque(String)
    /// ZmanimActivity : la date hébraïque en tête du Jour ouvre le ciel (zmanim, calendrier, hilloulot, boussole).
    case zmanim
    /// SettingsActivity ; `carteBarriere` (EXTRA_CARTE_BARRIERE) : l'écran défile jusqu'à la carte du mode, quand
    /// la pastille « Avec Hachem » demande un réglage (GesteBarriere.REGLER).
    case reglages(carteBarriere: Bool)
}

// MARK: L'en-tête du Jour

/// En tête du Jour (refonte du 13/11, MainActivity.renderEntete et renderCiel) : à gauche, l'icône du ciel du moment
/// et la date hébraïque, qui ouvrent les zmanim ; à droite, la roue des réglages (ic_nav_settings_off, 48 pt).
public struct AccueilEntete: Sendable, Hashable {
    /// La date hébraïque, qui change à la sortie des étoiles du lieu (minuit sans lieu) ; nil si le calcul échoue.
    public let dateHebraique: String?
    /// Ce que la puce montre : la date, sinon « Zmanim » (nav_zmanim). 14 pt, une ligne, suivie d'un chevron.
    public let titre: AccueilTexte
    /// « כ״ט חשון. Zmanim, calendrier, hilloulot, boussole » (jour_ciel).
    public let accessibilite: Libelle
    /// Le ciel du moment : l'icône devant la date, la plaque et le voile du haut de page (CielDuJour).
    public let ciel: CielDuJour.Phase
    /// « Réglages » : la description de la roue (settings_title).
    public let reglages: Libelle
}

// MARK: Le dessin des anneaux

/// Un anneau tel qu'AnneauxDessin le trace, du bord vers le centre : la série dehors, le jour contre le hassid.
/// Les longueurs sont dans l'unité du carré (des points pour la vue).
public struct AccueilTrait: Sendable, Equatable {
    public let quel: Anneaux.Quel
    /// 0 la série (dehors), 1 la semaine, 2 le jour.
    public let rang: Int
    /// Du bord du carré au milieu du trait : l'ovale se dessine dans le carré rentré d'autant de chaque côté.
    public let retrait: Double
    /// L'épaisseur du trait : ×1,3 pour l'anneau mis en avant.
    public let epaisseur: Double
    /// 1 pour l'anneau en avant (ou les trois à égalité) ; 70/255 pour les autres, piste comprise.
    public let opacite: Double
    /// La piste vide : la couleur `day_todo` mêlée à 22 % de celle de l'anneau, toujours tracée en entier.
    public let teintePiste: Double
    /// Un premier tour complet, à la couleur de l'anneau, bouts ronds.
    public let tourPlein: Bool
    /// Le tour en cours, de 0 à 1 : un arc depuis le haut (−90°), de 360° × `reste` dans le sens de lecture
    /// (à droite en français, à gauche en hébreu).
    public let reste: Double
    /// Le tour en cours repasse sur un tour complet : sa teinte est mêlée de 28 % de noir.
    public let assombri: Bool
}

/// AnneauxDessin.kt, en nombres : ce que la vue trace, et l'anneau sous le doigt.
public enum AccueilAnneaux {

    /// L'épaisseur d'un anneau et l'écart entre deux (8 et 3 dp sur Android).
    public static let epaisseur: Double = 8
    public static let ecart: Double = 3
    /// La part de la couleur de l'anneau dans sa piste vide (TEINTE_PISTE).
    public static let teintePiste: Double = 0.22
    /// L'opacité des anneaux qui ne sont pas en avant (alpha 70 sur 255).
    public static let opaciteEnRetrait: Double = 70.0 / 255.0
    /// Le noir mêlé au second tour.
    public static let assombrissement: Double = 0.28

    /// Les trois traits, du bord vers le centre. `avance` (0 à 1) : la part du remplissage déjà dessinée.
    public static func traits(_ etat: Anneaux.Etat, misEnAvant: Anneaux.Quel?, avance: Double,
                              epaisseur: Double = AccueilAnneaux.epaisseur,
                              ecart: Double = AccueilAnneaux.ecart) -> [AccueilTrait] {
        let borne = Float(min(max(avance, 0), 1))
        var traits: [AccueilTrait] = []
        for (rang, anneau) in etat.duCentre.reversed().enumerated() {
            let depuisBord = Double(rang) * (epaisseur + ecart)
            let enAvant = misEnAvant == nil || misEnAvant == anneau.quel
            let trait = misEnAvant == anneau.quel ? epaisseur * 1.3 : epaisseur
            // La fraction en simple précision, comme le Float de Kotlin.
            let fraction: Float = anneau.fraction * borne
            var tours = 0
            var reste: Float = 0
            if fraction > 0 {
                tours = Kotlin.versInt(Double(fraction))
                reste = fraction - Float(tours)
            }
            traits.append(AccueilTrait(quel: anneau.quel, rang: rang, retrait: depuisBord + epaisseur / 2,
                                       epaisseur: trait, opacite: enAvant ? 1 : opaciteEnRetrait,
                                       teintePiste: teintePiste, tourPlein: tours >= 1, reste: Double(reste),
                                       assombri: tours > 0))
        }
        return traits
    }

    /// L'anneau sous un point du carré de côté `cote` (origine en haut à gauche) : nil entre les anneaux, au
    /// centre ou dehors. Une marge d'un demi-écart autour de chaque trait : le doigt n'est pas une pointe.
    public static func sousLePoint(cote: Double, x: Double, y: Double,
                                   epaisseur: Double = AccueilAnneaux.epaisseur,
                                   ecart: Double = AccueilAnneaux.ecart) -> Anneaux.Quel? {
        let rayon = cote / 2
        let distance = ((x - rayon) * (x - rayon) + (y - rayon) * (y - rayon)).squareRoot()
        let depuisBord = rayon - distance
        if depuisBord < 0 { return nil }
        let pas = epaisseur + ecart
        let marge = ecart / 2
        let ordre: [Anneaux.Quel] = [.serie, .semaine, .jour]
        for (rang, quel) in ordre.enumerated() {
            let debut = Double(rang) * pas
            if depuisBord >= debut - marge && depuisBord <= debut + epaisseur + marge { return quel }
        }
        return nil
    }
}

// MARK: Le système

/// Ce que l'accueil fait faire au système à chaque passage et à chaque changement (MainActivity.applyServiceState,
/// StreakWidget.refresh, ZmanimWidget.refresh). L'adaptateur de l'app branche la barrière de Temps d'écran (posée
/// ou levée selon « enabled »), les rappels et les alertes (Chabbat, Levana, vol), et les vignettes.
public protocol AccueilSysteme: Sendable {
    /// applyServiceState : la barrière selon les réglages, puis les rappels et les alertes replanifiés.
    func appliquerEtat() async
    /// Les vignettes (série, zmanim) suivent ce que l'accueil vient de montrer.
    func rafraichirVignettes() async
    /// Des minutes viennent d'être inscrites : le rappel « Il est temps… » déjà paru ne reste pas dans le centre
    /// de notifications (Store.addSession, `cancel(Notifications.ID_REMINDER)` quand minutes > 0, 02/11).
    func retirerRappelDuJour() async
}

/// Un système qui compte ce qu'on lui demande.
public actor FauxAccueilSysteme: AccueilSysteme {
    public private(set) var etatsAppliques = 0
    public private(set) var vignettesRafraichies = 0
    public private(set) var rappelsRetires = 0

    public init() {}

    public func appliquerEtat() {
        etatsAppliques += 1
    }

    public func rafraichirVignettes() {
        vignettesRafraichies += 1
    }

    public func retirerRappelDuJour() {
        rappelsRetires += 1
    }
}
