import Foundation
import Coeur

// Ce que montrent les widgets de la série et des zmanim (StreakWidget.kt, ZmanimVignette.kt), sans les vues : la
// décision est ici, testée sous Linux (VignettesWidgetsTests) ; l'extension Widgets (ios/Widgets) n'a plus qu'à
// dessiner. Elle lit le journal et les réglages que l'app dépose dans le groupe d'apps
// (App/Services/SystemeWidgets.swift) et calcule elle-même sa chronologie : la série change à minuit, la prière du
// moment à chaque zman, sans que l'app ait à se réveiller (PORTAGE.md § 2.2.3).
//
// Rien ne lit l'heure ni le fuseau de la machine : `maintenant` (millisecondes Unix) et le fuseau du téléphone sont
// passés, comme à Chronologies.

/// Ce que l'app et l'extension Widgets se partagent dans le groupe d'apps : l'app recopie son journal et ses
/// réglages dans `dossier` (par un `Depot`, comme les siens) et pose sa langue sous `langue` ; le widget les relit.
public enum WidgetsPartage {
    /// Le groupe d'apps (les entitlements de l'app et de l'extension).
    public static let groupe = "group.com.myhitbodedut"
    /// Le dossier, dans le conteneur du groupe, de la copie de `journal.json` et `reglages.json`.
    public static let dossier = "Widgets"
    /// La langue de l'app (`Traducteur.langue`), dans les UserDefaults du groupe.
    public static let langue = "widgets.langue"
    /// Le genre (`kind`) du widget de la série.
    public static let serie = "serie"
    /// Le genre du widget des zmanim.
    public static let zmanim = "zmanim"
}

/// Le widget de la série (StreakWidget.kt) : la série dans sa pastille, la flamme, les anneaux et le hassid, la
/// salutation, les minutes du jour, la semaine, le bouton, et en grand le texte de ’hizouk du jour.
public enum VignetteSerie {

    /// Où mène un toucher (les liens `myhitbodedut://…` d'App/Liens.swift).
    public enum Destination: String, Sendable, Hashable {
        /// L'onglet Aujourd'hui (MainActivity).
        case accueil
        /// L'écran de la séance en cours (SessionActivity).
        case seance
        /// L'écran de la séance, qui part seul (EXTRA_START_NOW).
        case commencer
        /// La séance en cours se termine sans rien ouvrir (SessionService.ACTION_FINISH) : l'intention « Terminer » de
        /// la Live Activity, que le système exécute dans l'app.
        case terminer
    }

    /// La pastille d'un jour de la semaine (StreakWidget.semaine), dans l'ordre où Android les essaie.
    public enum EtatJour: String, Sendable, Hashable {
        /// Fait : un disque plein et une coche.
        case fait
        /// Sans obligation (Chabbat, Yom Tov, pause) : un disque voilé, ש le samedi, un tiret sinon.
        case repos
        /// Aujourd'hui, à faire : un cercle franc.
        case aujourdhui
        /// À venir : un cercle pâle.
        case avenir
        /// Passé sans être fait : un cercle à demi.
        case passe
    }

    /// Ce qui est écrit dans la pastille d'un jour.
    public enum Marque: String, Sendable, Hashable {
        /// « ✓ ».
        case coche
        /// « ש » (week_shabbat_mark).
        case chabbat
        /// « – ».
        case tiret
        case aucune
    }

    public struct Jour: Sendable, Hashable {
        public let date: JourCivil
        public let etat: EtatJour
        public let marque: Marque
        /// La lettre du jour est en encre franche aujourd'hui, en encre douce les autres jours.
        public let estAujourdhui: Bool
    }

    /// La séance en cours, pour le compteur vivant (`Text(timerInterval:)` à la place du Chronometer d'Android).
    public struct Seance: Sendable, Hashable {
        /// Le temps restant, le temps écoulé, ou rien (Store.sessionCounter).
        public let compteur: SessionRule.Compteur
        /// Son début, en millisecondes Unix.
        public let debut: Int64
        /// Sa fin prévue ; 0 pour une séance ouverte.
        public let fin: Int64
    }

    /// Le texte de ’hizouk du jour, sur la grande.
    public struct TexteDuJour: Sendable, Hashable {
        public let hebreu: String
        public let reference: String
    }

    public struct Affichage: Sendable, Hashable {
        /// Le jour civil du téléphone.
        public let aujourdhui: JourCivil
        public let serie: Int
        public let fait: Bool
        /// Shabbat, Yom Tov ou pause : rien n'est attendu aujourd'hui.
        public let repos: Bool
        /// nil hors séance.
        public let seance: Seance?
        public let anneaux: Anneaux.Etat
        /// L'illustration au creux des anneaux (Poses, Personnage) : il prie pendant la séance.
        public let personnage: String
        /// La première ligne : la séance en cours, bonjour et le prénom, ou l'état du jour.
        public let salutation: Libelle
        /// « 12 / 20 min » (widget_minutes).
        public let minutes: Libelle
        /// Le nombre mis en grand dans `minutes`.
        public let minutesFaites: Int
        /// « 3 jours sur 5 cette semaine » (week_gauge).
        public let libelleSemaine: Libelle
        /// Du dimanche au samedi.
        public let semaine: [Jour]
        /// La série dite à VoiceOver, et sur l'écran verrouillé (status_streak, status_streak_none).
        public let lectureSerie: Libelle
        /// Les anneaux dits à VoiceOver (rings_description).
        public let lectureAnneaux: Libelle
        /// Le bouton : « Commencer », ou pendant la séance « Terminer maintenant ».
        public let bouton: Libelle
        public let destinationBouton: Destination
        /// Le reste de la vignette : l'app, ou pendant la séance son écran.
        public let destination: Destination
        /// La grande : le texte de ’hizouk du jour, nil sans texte.
        public let texteDuJour: TexteDuJour?

        /// La flamme s'allume quand le jour est fait, ou qu'il n'attend rien (Shabbat ne l'éteint pas).
        public var flammeAllumee: Bool { fait || repos }

        /// Le compteur vivant prend la place des minutes du jour (de la série sur la petite).
        public var compteurMontre: Bool {
            guard let seance else { return false }
            return seance.compteur != .masque
        }
    }

    /// Une chronologie : les instants où l'affichage change, le premier à `maintenant`, et quand la redemander.
    public struct Chronologie: Sendable, Hashable {
        public let instants: [Int64]
        public let recharge: Int64
    }

    /// Les heures où la salutation change (Salutation.partie) ; 0 h est minuit, où le jour change.
    static let heuresDeBascule = [0, 5, 12, 18]

    /// Ce que montre la vignette à `maintenant` (StreakWidget.Etat.lire, vues, salutation, texteDuJour).
    /// `chizuk` : les textes de ’hizouk, nil s'ils manquent (la grande se passe alors de texte) ; `langue` : celle
    /// de l'app, pour la référence du texte.
    public static func affichage(journal: Journal, reglages: Reglages, maintenant: Int64, fuseauTelephone: Fuseau,
                                 chizuk: Chizuk?, langue: String, debug: Bool = false) -> Affichage {
        let fuseau = fuseauTelephone.identifiant
        let aujourdhui = fuseauTelephone.jour(millis: maintenant)
        let heure = fuseauTelephone.dateHeure(millis: maintenant).heure
        let serie = Store.streak(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: fuseau)
        let enCours = Store.isSessionRunning(reglages: reglages, millis: maintenant)
        let fait = Store.isDone(journal: journal, date: aujourdhui)
        let repos = Store.isExempt(reglages: reglages, date: aujourdhui, fuseauTelephone: fuseau)
        let anneaux = Store.anneaux(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                    fuseauTelephone: fuseau)
        let cases = Store.currentWeek(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                                      fuseauTelephone: fuseau)
        let prenom = journal.firstName

        let pose = enCours ? Poses.during(aujourdhui) : Poses.greeting(fait, jour: aujourdhui)
        let personnage = ApparenceChoisie(reglages).image(pose)

        let salutation: Libelle
        if enCours {
            salutation = Libelle("widget_running")
        } else if !prenom.estBlanc {
            salutation = Libelle(Salutation.chaine(heure), .texte(prenom))
        } else if fait {
            salutation = Libelle("widget_done")
        } else if repos {
            // « Pas encore aujourd'hui » un jour de Shabbat sonnait comme un reproche (revue du 30/09).
            salutation = Libelle("widget_rest")
        } else {
            salutation = Libelle("widget_todo")
        }

        var seance: Seance?
        if enCours {
            seance = Seance(compteur: Store.sessionCounter(reglages: reglages),
                            debut: Store.sessionStartedAt(reglages: reglages),
                            fin: Store.sessionEndsAt(reglages: reglages))
        }

        let jour = anneaux.jour
        let semaine = anneaux.semaine
        let anneauSerie = anneaux.serie
        let lectureSerie = serie == 0
            ? Libelle("status_streak_none")
            : Libelle.pluriel("status_streak", quantite: serie, .entier(serie))
        let lectureAnneaux = Libelle("rings_description",
                                     .libelle(Store.formatDuration(jour.fait)), .libelle(Store.formatDuration(jour.objectif)),
                                     .entier(semaine.fait), .entier(semaine.objectif),
                                     .entier(anneauSerie.fait), .entier(anneauSerie.objectif))

        return Affichage(
            aujourdhui: aujourdhui, serie: serie, fait: fait, repos: repos, seance: seance, anneaux: anneaux,
            personnage: personnage, salutation: salutation,
            minutes: Libelle("widget_minutes", .entier(jour.fait), .entier(jour.objectif)), minutesFaites: jour.fait,
            libelleSemaine: Libelle.pluriel("week_gauge", quantite: semaine.fait, .entier(semaine.fait),
                                            .entier(semaine.objectif)),
            semaine: jours(cases, aujourdhui: aujourdhui), lectureSerie: lectureSerie, lectureAnneaux: lectureAnneaux,
            // Hors séance, le bouton part droit sur son écran et la lance. Pendant, il la termine, comme le bouton de
            // la notification : la même intention que la Live Activity (ActiviteSeanceTerminer).
            bouton: Libelle(enCours ? "session_finish_now" : "widget_start"),
            destinationBouton: enCours ? .terminer : .commencer,
            destination: enCours ? .seance : .accueil,
            texteDuJour: chizuk.flatMap { texteDuJour($0, aujourdhui: aujourdhui, langue: langue, debug: debug) })
    }

    /// Les instants où la vignette change, de `maintenant` au deuxième minuit du téléphone : minuit (le jour, la
    /// semaine, la série), 5 h, 12 h et 18 h (la salutation), et la fin prévue de la séance en cours. Android
    /// redessinait par une alarme juste après minuit (programmerMinuit) et à chaque changement d'état.
    public static func chronologie(reglages: Reglages, maintenant: Int64, fuseauTelephone: Fuseau) -> Chronologie {
        let aujourdhui = fuseauTelephone.jour(millis: maintenant)
        let recharge = fuseauTelephone.millis(DateHeure(aujourdhui.plus(jours: 2)))
        var instants: Set<Int64> = [maintenant]
        for decalage in 0...1 {
            for heure in heuresDeBascule {
                instants.insert(fuseauTelephone.millis(DateHeure(aujourdhui.plus(jours: decalage), heure: heure)))
            }
        }
        let fin = Store.sessionEndsAt(reglages: reglages)
        if fin > 0 { instants.insert(fin) }
        let tries = instants.filter { $0 >= maintenant && $0 < recharge }.sorted()
        return Chronologie(instants: tries, recharge: recharge)
    }

    /// StreakWidget.semaine : la pastille et la marque de chaque jour.
    static func jours(_ cases: [CaseSemaine], aujourdhui: JourCivil) -> [Jour] {
        cases.prefix(7).map { (c: CaseSemaine) -> Jour in
            let estAujourdhui = c.date == aujourdhui
            let etat: EtatJour
            if c.done {
                etat = .fait
            } else if c.exempt {
                etat = .repos
            } else if estAujourdhui {
                etat = .aujourdhui
            } else if c.future {
                etat = .avenir
            } else {
                etat = .passe
            }
            let marque: Marque
            if c.done {
                marque = .coche
            } else if c.shabbat && c.exempt {
                marque = .chabbat
            } else if c.exempt {
                marque = .tiret
            } else {
                marque = .aucune
            }
            return Jour(date: c.date, etat: etat, marque: marque, estAujourdhui: estAujourdhui)
        }
    }

    /// StreakWidget.texteDuJour : un texte de l'ouverture par jour, le même toute la journée (la vignette se
    /// redessine souvent, et un texte qui changerait ne se lirait jamais jusqu'au bout). `toEpochDay() % taille`.
    static func texteDuJour(_ chizuk: Chizuk, aujourdhui: JourCivil, langue: String, debug: Bool) -> TexteDuJour? {
        let textes = ChizukRules.forMoment(chizuk, .ouverture, debug: debug)
        guard !textes.isEmpty else { return nil }
        let jourEpoque = aujourdhui.jourJulien - 2_440_588
        // Le reste de Kotlin garde le signe : avant 1970 Android lèverait ; ici, le reste positif.
        let item = textes[Kotlin.floorMod(jourEpoque, textes.count)]
        return TexteDuJour(hebreu: ChizukRules.hebrew(chizuk, item), reference: Reference.localise(item.ref, langue))
    }
}

/// Les widgets des zmanim (ZmanimVignette.vues) d'après ce que Chronologies calcule : les textes, les heures écrites
/// « HH:mm » dans le fuseau du lieu (DateTimeFormatter.ofPattern("HH:mm") d'Android), l'état de chaque ligne de la
/// journée, et la ligne de l'écran verrouillé.
public enum VignetteZmanim {

    /// Une ligne de la journée (la grande) ou un des trois zmanim à venir (la moyenne).
    public enum EtatLigne: String, Sendable, Hashable {
        /// Déjà passé : pâle.
        case passe
        /// Le prochain : en menthe, sur un bandeau.
        case prochain
        /// À venir.
        case avenir
    }

    public struct Ligne: Sendable, Hashable {
        /// « zman_<clé> ».
        public let nom: Libelle
        /// « HH:mm ».
        public let heure: String
        public let etat: EtatLigne
    }

    public struct Affichage: Sendable, Hashable {
        /// La date hébraïque, en tête.
        public let date: String
        /// La fête du jour, sinon la paracha de la semaine ; nil sans l'une ni l'autre.
        public let pastille: Libelle?
        /// « Cha'harit », « Min'ha », « Arvit », ou « Choisir le lieu ».
        public let titre: Libelle
        public let aLieu: Bool
        /// « jusqu'à 09:12 » (widget_jusqua) ; nil sans limite.
        public let jusqua: Libelle?
        /// « 09:12 » ; nil sans limite.
        public let heureLimite: String?
        /// La fenêtre de la jauge et du temps qui reste, en millisecondes Unix : nil sans limite.
        public let debut: Int64?
        public let limite: Int64?
        /// La moyenne : les trois zmanim à venir (une case vide est nil), le premier en menthe.
        public let prochains: [Ligne?]
        /// La grande : la journée.
        public let journee: [Ligne]
        /// La moyenne et la grande : « Série : 12 jours » (widget_zmanim_serie) ; nil pour les autres.
        public let serie: Libelle?
        /// L'écran verrouillé, en une ligne : « Min'ha jusqu'à 17:02 » (widget_zmanim_jusqua), la prière seule sans
        /// limite, « Choisir le lieu » sans lieu.
        public let ligne: Libelle
        /// L'écran verrouillé : le prochain zman, nil sans lieu ou sans zman à venir.
        public let prochainZman: Ligne?
    }

    /// Le fuseau des heures écrites : celui du lieu, sinon celui du téléphone (un fuseau inconnu compte comme
    /// absent, comme `runCatching { ZoneId.of(…) }`).
    public static func fuseau(lieu: Zmanim.Lieu?, fuseauTelephone: Fuseau) -> Fuseau {
        guard let lieu, let zone = Fuseau(lieu.fuseau) else { return fuseauTelephone }
        return zone
    }

    /// « HH:mm » d'un instant dans un fuseau.
    public static func heure(_ instant: Int64, fuseau: Fuseau) -> String {
        Store.formatMinutes(fuseau.dateHeure(millis: instant).minutesDuJour)
    }

    /// Ce que montre une entrée de la chronologie. `serie` : la série du jour, pour la moyenne et la grande (nil la
    /// tait) ; `maintenant` : l'instant de l'entrée, qui dit ce qui est passé.
    public static func affichage(_ a: Chronologies.Affichage, famille: Chronologies.Famille, maintenant: Int64,
                                 fuseau: Fuseau, serie: Int?) -> Affichage {
        let heureLimite = a.limite.map { heure($0, fuseau: fuseau) }
        let jusqua = heureLimite.map { Libelle("widget_jusqua", .texte($0)) }
        let titre = a.titre
        let ligne: Libelle
        if let heureLimite {
            ligne = Libelle("widget_zmanim_jusqua", .libelle(titre), .texte(heureLimite))
        } else {
            ligne = titre
        }
        var prochains: [Ligne?] = []
        for (k, place) in a.prochains.enumerated() {
            guard let z = place else {
                prochains.append(nil)
                continue
            }
            let etat: EtatLigne = k == 0 ? .prochain : .avenir
            prochains.append(Ligne(nom: Libelle(z.libelle), heure: heure(z.instant, fuseau: fuseau), etat: etat))
        }
        var journee: [Ligne] = []
        for (k, z) in a.journee.enumerated() {
            let etat: EtatLigne
            if k == a.prochain {
                etat = .prochain
            } else if z.instant <= maintenant {
                etat = .passe
            } else {
                etat = .avenir
            }
            journee.append(Ligne(nom: Libelle(z.libelle), heure: heure(z.instant, fuseau: fuseau), etat: etat))
        }
        var prochainZman: Ligne?
        if let premier = a.prochains.first, let z = premier {
            prochainZman = Ligne(nom: Libelle(z.libelle), heure: heure(z.instant, fuseau: fuseau), etat: .prochain)
        } else if let k = a.prochain, k < a.journee.count {
            let z = a.journee[k]
            prochainZman = Ligne(nom: Libelle(z.libelle), heure: heure(z.instant, fuseau: fuseau), etat: .prochain)
        }
        var libelleSerie: Libelle?
        if let serie, famille != .petite {
            libelleSerie = Libelle.pluriel("widget_zmanim_serie", quantite: serie, .entier(serie))
        }
        return Affichage(date: a.dateHebraique, pastille: a.pastille, titre: titre, aLieu: a.priere != nil,
                         jusqua: jusqua, heureLimite: heureLimite, debut: a.limite == nil ? nil : a.debut,
                         limite: a.limite, prochains: prochains, journee: journee, serie: libelleSerie, ligne: ligne,
                         prochainZman: prochainZman)
    }
}
