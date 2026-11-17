import Foundation

/// Une notification locale qu'iOS doit tenir en attente : ce que le planificateur rend (PlanNotifications).
///
/// Le titre et le texte sont des `Libelle` : l'app les résout dans sa langue au moment de poser la notification.
/// `suite` est une seconde ligne, jointe au texte par un retour à la ligne comme sur Android (la phrase du trophée
/// tout proche sous le rappel, la prière du moment sous Tefilat haDerekh).
public struct NotificationPlanifiee: Sendable, Hashable {

    /// Les parts du budget de 64 notifications en attente (PORTAGE.md § 2.2.2), dans l'ordre où elles se
    /// départagent à instant égal.
    public enum Categorie: String, Sendable, Hashable, CaseIterable {
        /// Le rappel de hitbodedout (Reminder.kt, ReminderRule.kt).
        case rappel
        /// « Chabbat dans 3 h » (ChabbatAlerte.kt).
        case chabbat
        /// Birkat haLevana (LevanaAlerte.kt).
        case levana
        /// Les rappels du vol (VolRappels.kt, VolAlerte.kt).
        case vol
        /// La fin de la séance et le rappel reporté (« Plus tard »).
        case seance

        /// Le nombre de notifications que la catégorie peut tenir en attente.
        public var part: Int {
            switch self {
            case .rappel: return 30
            case .chabbat: return 4
            case .levana: return 6
            case .vol: return 14
            case .seance: return 2
            }
        }

        fileprivate var rang: Int {
            switch self {
            case .rappel: return 0
            case .chabbat: return 1
            case .levana: return 2
            case .vol: return 3
            case .seance: return 4
            }
        }
    }

    /// Les actions de la notification du rappel (ReminderReceiver.build).
    public enum Action: String, Sendable, Hashable, CaseIterable {
        /// « Commencer » : ouvre l'écran de séance, la séance lancée.
        case commencer
        /// « Plus tard » : reporte le rappel de `Reminder.snoozeMinutes`.
        case plusTard = "plus_tard"

        /// Le nom de la chaîne du bouton.
        public var libelle: String {
            switch self {
            case .commencer: return "reminder_action_start"
            case .plusTard: return "reminder_action_later"
            }
        }
    }

    /// Stable d'une programmation à l'autre : la même notification garde le même identifiant, et iOS remplace
    /// au lieu d'empiler.
    public let identifiant: String
    /// L'instant où elle s'affiche, en millisecondes Unix.
    public let instant: Int64
    public let titre: Libelle
    public let texte: Libelle
    public let suite: Libelle?
    public let categorie: Categorie
    public let actions: [Action]
    /// La clé du trophée tout proche qu'annonce la notification (« famille:rang ») : l'app le note parmi les
    /// trophées signalés (`trophees_proches_signales`) quand elle s'affiche, comme le fait ReminderReceiver.
    public let trophee: String?
    /// Le texte du siddour que la notification ouvre quand on la touche (LevanaAlerteReceiver : Birkat haLevana ;
    /// VolAlerte.texteSiddur pour le vol) ; nil : l'accueil de l'app.
    public let texteSiddur: String?

    public init(identifiant: String, instant: Int64, titre: Libelle, texte: Libelle, suite: Libelle? = nil,
                categorie: Categorie, actions: [Action] = [], trophee: String? = nil, texteSiddur: String? = nil) {
        self.identifiant = identifiant
        self.instant = instant
        self.titre = titre
        self.texte = texte
        self.suite = suite
        self.categorie = categorie
        self.actions = actions
        self.trophee = trophee
        self.texteSiddur = texteSiddur
    }
}

/// Le planificateur unique d'iOS (PORTAGE.md § 2.2.2) : une fonction pure (état, maintenant) → notifications,
/// qui remplace les quatre récepteurs d'Android (ReminderReceiver, ChabbatAlerteReceiver, LevanaAlerteReceiver,
/// VolAlerteReceiver) et le signal de fin de SessionService.
///
/// Android pose une alarme à la fois et décide quand elle sonne ; iOS ne réveille pas l'app pour une notification
/// locale et n'en tient que 64 en attente. Chaque règle est donc suivie ici alarme après alarme, comme Android la
/// suivrait, et ce qui s'afficherait est rendu d'avance. Les règles sont celles d'Android, inchangées :
/// `ReminderRule`, `ChabbatAlerte.prochaine`, `LevanaAlerte.prochain`, la sélection de VolAlerte.
///
/// Les parts sont fixes (`Categorie.part`) : PORTAGE ne rend pas la marge aux rappels quand une catégorie n'use
/// pas sa part, si bien que 56 notifications au plus sont rendues, et la marge de 8 reste libre. Rien ne lit
/// l'heure ni le fuseau de la machine : `maintenant` (millisecondes Unix) et `fuseau` (celui du téléphone) sont
/// passés. Les zmanim aussi peuvent l'être (`horaires`, `allumage`), pour que les tests rendent ceux de la JVM.
/// L'app repasse à chaque ouverture, séance inscrite ou commencée, changement de réglage, de lieu, d'heure ou de
/// fuseau. Jugé par `Tests/Vecteurs/plan.json` (tools/vecteurs_ios/VecteursPlan.kt).
public enum PlanNotifications {

    /// Les notifications qu'une app peut tenir en attente sur iOS.
    public static let limite = 64
    /// Ce que les parts laissent libre.
    public static let marge = 8
    /// Les jours civils de rappels programmés d'avance, aujourd'hui compris : dix jours à trois heures par jour
    /// remplissent la part des rappels ; avec plus d'heures, la part coupe avant.
    public static let joursRappels = 10
    /// Un rappel du vol déclenché en retard s'affiche encore jusqu'à vingt minutes (VolAlerte.TOLERANCE_MS).
    public static let toleranceVol: Int64 = 20 * 60_000
    /// Les rappels du vol dus dans la minute qui suit s'affichent ensemble (VolAlerte.dus).
    private static let groupementVol: Int64 = 60_000

    /// Les zmanim d'un jour au lieu donné, par clé (`Zmanim.Zman.cle`), en millisecondes Unix ; un zman absent
    /// manque.
    public typealias Horaires = (_ lieu: Zmanim.Lieu, _ jour: JourCivil) -> [String: Int64]
    /// L'allumage d'un jour au lieu donné, `minutes` avant la chki'a, en millisecondes Unix ; nil s'il n'existe pas.
    public typealias Allumage = (_ lieu: Zmanim.Lieu, _ jour: JourCivil, _ minutes: Int) -> Int64?

    // MARK: Le plan entier

    /// Le plan, avec les zmanim de `Zmanim` et les heures du vol écrites comme `Instant.toString()`.
    public static func planifier(reglages: Reglages, journal: Journal, volRappels: [VolRappels.Rappel],
                                 maintenant: Int64, fuseau: Fuseau) -> [NotificationPlanifiee] {
        planifier(reglages: reglages, journal: journal, volRappels: volRappels, maintenant: maintenant, fuseau: fuseau,
                  horaires: { lieu, jour in horairesCalcules(lieu, jour) },
                  allumage: { lieu, jour, minutes in allumageCalcule(lieu, jour, minutes) },
                  heureVol: { t in instantTexte(t) })
    }

    /// Le plan : chaque catégorie dans sa part, les premières dans le temps gardées, le tout trié par instant
    /// (puis catégorie, puis identifiant). `heureVol` écrit une heure du vol dans un texte (VolAlerte.deuxHeures).
    public static func planifier(reglages: Reglages, journal: Journal, volRappels: [VolRappels.Rappel],
                                 maintenant: Int64, fuseau: Fuseau, horaires: Horaires, allumage: Allumage,
                                 heureVol: (Int64) -> String) -> [NotificationPlanifiee] {
        let chaine = rappels(reglages: reglages, journal: journal, maintenant: maintenant, fuseau: fuseau,
                             nombre: NotificationPlanifiee.Categorie.rappel.part)
        var liste: [NotificationPlanifiee] = []
        liste.append(contentsOf: chaine.filter { $0.categorie == .rappel }.prefix(NotificationPlanifiee.Categorie.rappel.part))
        var seance = chaine.filter { $0.categorie == .seance }
        if let fin = finDeSeance(reglages: reglages, maintenant: maintenant) {
            seance.append(fin)
        }
        liste.append(contentsOf: trie(seance).prefix(NotificationPlanifiee.Categorie.seance.part))
        liste.append(contentsOf: chabbat(reglages: reglages, maintenant: maintenant, fuseau: fuseau, allumage: allumage))
        liste.append(contentsOf: levana(reglages: reglages, maintenant: maintenant, fuseau: fuseau, horaires: horaires))
        let vols = vol(reglages: reglages, rappels: volRappels, maintenant: maintenant, heure: heureVol)
        liste.append(contentsOf: vols.prefix(NotificationPlanifiee.Categorie.vol.part))
        return trie(liste)
    }

    // MARK: Le rappel de hitbodedout (Reminder.kt, ReminderReceiver)

    /// Les rappels des `joursRappels` jours civils à venir, aujourd'hui compris, alarme après alarme comme
    /// Reminder.reschedule et ReminderReceiver les suivraient : le prochain instant réglé
    /// (`ReminderRule.prochainDeclenchement`), ou le report s'il tombe avant ; chaque déclenchement consomme le
    /// report (un report qui tombe après le prochain rappel réglé se perd, comme sur Android). Le rappel ne
    /// s'affiche que si aucune séance ne court à cet instant et que `ReminderRule.shouldNotify` le permet ce
    /// jour-là à cette heure : la journée faite, un jour de repos, la veille après midi le taisent. Un rappel
    /// reporté est de la catégorie `seance`. La phrase du trophée tout proche va sous le premier, une fois. La
    /// suite s'arrête une fois `nombre` rappels (hors report) trouvés. Une séance ouverte court tant qu'on ne l'a
    /// pas close (`SessionRule.enCours`) : elle tait tous les rappels, et la suite n'est pas parcourue.
    public static func rappels(reglages: Reglages, journal: Journal, maintenant: Int64, fuseau: Fuseau,
                               nombre: Int = Int.max) -> [NotificationPlanifiee] {
        guard reglages.reminderEnabled, !Store.isSessionOpen(reglages: reglages) else { return [] }
        let fuseauTelephone = fuseau.identifiant
        let heures = reglages.reminderTimes
        let aujourdhui = fuseau.jour(millis: maintenant)
        let dernier = aujourdhui.plus(jours: joursRappels - 1)
        let titre = Libelle("reminder_title")
        let texte = Libelle("reminder_text", .libelle(Store.formatDuration(reglages.targetMinutes)))
        let proche = tropheeProche(reglages: reglages, journal: journal, aujourdhui: aujourdhui,
                                   fuseauTelephone: fuseauTelephone)
        var res: [NotificationPlanifiee] = []
        var trouves = 0
        var t = maintenant
        var report = reglages.reminderSnoozedUntil
        // Chaque tour avance jusqu'à l'heure réglée suivante : 1 440 heures par jour sur dix jours, et le report.
        for _ in 0..<(joursRappels * ReminderRule.minutesParJour + 2) {
            if trouves >= nombre { break }
            let regle = ReminderRule.prochainDeclenchement(maintenant: DateHeureZonee(millis: t, fuseau: fuseau),
                                                           heures: heures)?.millis
            var quand = regle
            var reporte = false
            if report > t {
                if let regle {
                    if report < regle {
                        quand = report
                        reporte = true
                    }
                } else {
                    quand = report
                    reporte = true
                }
            }
            guard let q = quand else { break }
            let civile = fuseau.dateHeure(millis: q)
            if civile.jour > dernier { break }
            report = 0
            let jour = civile.jour
            let permis = !Store.isSessionRunning(reglages: reglages, millis: q) && ReminderRule.shouldNotify(
                nowMinutes: civile.heure * 60 + civile.minute,
                doneToday: Store.isDone(journal: journal, date: jour),
                todayIsRestDay: Store.isExempt(reglages: reglages, date: jour, fuseauTelephone: fuseauTelephone),
                tomorrowIsRestDay: Store.isEveOfRestDay(reglages: reglages, date: jour, fuseauTelephone: fuseauTelephone),
                sunsetMinutes: nil)
            if permis {
                let premier = res.isEmpty
                res.append(NotificationPlanifiee(
                    identifiant: (reporte ? "rappel-reporte-" : "rappel-") + String(q),
                    instant: q, titre: titre, texte: texte,
                    suite: premier ? proche?.phrase : nil,
                    categorie: reporte ? .seance : .rappel,
                    actions: [.commencer, .plusTard],
                    trophee: premier ? proche?.cle : nil))
                if !reporte { trouves += 1 }
            }
            t = q
        }
        return res
    }

    /// La phrase du trophée tout proche (ReminderReceiver.tropheeProche), s'il y en a un pas encore signalé et
    /// que le réglage le permet : « Plus que 2 pour « 7 jours d'affilée » ».
    public static func tropheeProche(reglages: Reglages, journal: Journal, aujourdhui: JourCivil,
                                     fuseauTelephone: String) -> (phrase: Libelle, cle: String)? {
        guard reglages.rappelTropheeProche else { return nil }
        let p = Store.pratique(journal: journal, reglages: reglages, aujourdhui: aujourdhui,
                               fuseauTelephone: fuseauTelephone)
        guard let n = Trophees.proche(p) else { return nil }
        if reglages.tropheesProchesSignales.contains(n.cle) { return nil }
        let reste = n.seuil - Trophees.valeur(p, n.famille)
        // TropheesVue.description : le pluriel « trophee_<famille>_desc », le seuil pour quantité et argument.
        let description = Libelle.pluriel("trophee_" + n.famille.rawValue.lowercased() + "_desc",
                                          quantite: n.seuil, .entier(n.seuil))
        return (phrase: Libelle("rappel_trophee_proche", .entier(reste), .libelle(description)), cle: n.cle)
    }

    // MARK: La fin de la séance (SessionService.notifyCompleted)

    /// Le signal de fin d'une séance minutée en cours, à l'heure de sa fin (PORTAGE.md § 2.2.1) ; nil pour une
    /// séance ouverte, close ou sans séance.
    public static func finDeSeance(reglages: Reglages, maintenant: Int64) -> NotificationPlanifiee? {
        let debut = Store.sessionStartedAt(reglages: reglages)
        let fin = Store.sessionEndsAt(reglages: reglages)
        let duree = Store.sessionTarget(reglages: reglages)
        guard debut > 0, duree > 0, fin > maintenant else { return nil }
        return NotificationPlanifiee(identifiant: "fin-seance-" + String(fin), instant: fin,
                                  titre: Libelle("session_done_title"),
                                  texte: Libelle("session_done_text", .libelle(Store.formatDuration(duree))),
                                  categorie: .seance)
    }

    // MARK: « Chabbat dans 3 h » (ChabbatAlerte.kt)

    /// Les `nombre` prochaines alertes, chacune `ChabbatAlerte.prochaine` après la précédente, comme le récepteur
    /// les enchaîne ; au lieu des alertes (`lieuAlertes`), avec les minutes d'allumage des réglages. Sans lieu,
    /// rien. Une chaîne s'arrête quand deux vendredis de suite n'ont pas d'allumage (nuit ou jour polaire).
    public static func chabbat(reglages: Reglages, maintenant: Int64, fuseau: Fuseau,
                               nombre: Int = NotificationPlanifiee.Categorie.chabbat.part,
                               allumage: Allumage) -> [NotificationPlanifiee] {
        guard let lieu = reglages.lieuAlertes(fuseauTelephone: fuseau.identifiant),
              let fuseauLieu = Fuseau(lieu.fuseau) else { return [] }
        let minutes = reglages.allumage
        var res: [NotificationPlanifiee] = []
        var t = maintenant
        for _ in 0..<max(nombre, 0) {
            let alerte = ChabbatAlerte.prochaine(
                maintenant: DateHeureZonee(millis: t, fuseau: fuseau),
                allumage: { jour in
                    guard let instant = allumage(lieu, jour, minutes) else { return nil }
                    return DateHeureZonee(millis: instant, fuseau: fuseauLieu)
                })
            guard let alerte else { break }
            res.append(NotificationPlanifiee(identifiant: "chabbat-" + alerte.jour.iso, instant: alerte.millis,
                                          titre: Libelle("chabbat_alerte_titre"), texte: Libelle("chabbat_alerte_texte"),
                                          categorie: .chabbat))
            t = alerte.millis
        }
        return res
    }

    // MARK: Birkat haLevana (LevanaAlerte.kt)

    /// Les `nombre` prochains rappels, chacun `LevanaAlerte.prochain` après le précédent, dans le fuseau du lieu
    /// des alertes (sinon celui du téléphone), selon l'usage choisi ou celui du noussa'h (VueJour.usageLevana),
    /// à la sortie des étoiles du lieu, sinon à 20 h (LevanaAlerte.heure). Rien si le rappel est éteint.
    public static func levana(reglages: Reglages, maintenant: Int64, fuseau: Fuseau,
                              nombre: Int = NotificationPlanifiee.Categorie.levana.part,
                              horaires: Horaires) -> [NotificationPlanifiee] {
        guard reglages.levanaRappel else { return [] }
        return withoutActuallyEscaping(horaires) { horaires in
            levanaRappels(reglages: reglages, maintenant: maintenant, fuseau: fuseau, nombre: nombre, horaires: horaires)
        }
    }

    private static func levanaRappels(reglages: Reglages, maintenant: Int64, fuseau: Fuseau, nombre: Int,
                                      horaires: @escaping Horaires) -> [NotificationPlanifiee] {
        let lieu = reglages.lieuAlertes(fuseauTelephone: fuseau.identifiant)
        let zone = lieu.flatMap { Fuseau($0.fuseau) } ?? fuseau
        let usage = reglages.levanaUsage.flatMap { Levana.Usage(rawValue: $0) } ?? Levana.Usage.duNusah(reglages.siddurNusah)
        var res: [NotificationPlanifiee] = []
        var t = maintenant
        for _ in 0..<max(nombre, 0) {
            let rappel = LevanaAlerte.prochain(
                DateHeureZonee(millis: t, fuseau: zone), usage: usage,
                heure: { jour in
                    if let lieu, let tset = horaires(lieu, jour)["tset"] {
                        return DateHeureZonee(millis: tset, fuseau: zone)
                    }
                    return DateHeureZonee(DateHeure(jour, heure: 20), fuseau: zone)
                },
                // Le Yom tov de la nuit suit le statut Israël ou diaspora (audit du 16/11).
                enIsrael: reglages.inIsrael(fuseauTelephone: fuseau.identifiant))
            guard let rappel else { break }
            res.append(NotificationPlanifiee(
                identifiant: "levana-" + rappel.quand.jour.iso + "-" + rappel.soir.rawValue.lowercased(),
                instant: rappel.quand.millis, titre: Libelle(rappel.soir.titre), texte: Libelle("levana_rappel_texte"),
                categorie: .levana, texteSiddur: "birkat_halevana"))
            t = rappel.quand.millis
        }
        return res
    }

    // MARK: Le vol (VolAlerte.kt)

    /// Les rappels du vol gardés avec lui, déclenchement après déclenchement comme VolAlerte.programmer et
    /// VolAlerteReceiver les suivraient : le plus proche qui n'a pas été montré (`volRappelVu`) et n'a pas plus
    /// de vingt minutes de retard, montré au plus tôt maintenant, avec ceux qui tombent dans la minute qui suit.
    /// Rien si les rappels du vol sont éteints. S'arrête une fois `nombre` atteint ou dépassé (un déclenchement
    /// peut en montrer plusieurs). `heure` écrit l'heure d'une limite dans le texte.
    public static func vol(reglages: Reglages, rappels: [VolRappels.Rappel], maintenant: Int64,
                           nombre: Int = NotificationPlanifiee.Categorie.vol.part,
                           heure: (Int64) -> String) -> [NotificationPlanifiee] {
        guard reglages.volRappelsActifs else { return [] }
        var vu = reglages.volRappelVu
        var t = maintenant
        var res: [NotificationPlanifiee] = []
        while res.count < nombre {
            var prochain: Int64?
            for r in rappels where r.instant > vu && r.instant > t - toleranceVol {
                if let p = prochain, p <= r.instant { continue }
                prochain = r.instant
            }
            guard let p = prochain else { break }
            let declenchement = max(p, t)
            var dernierVu = vu
            var montres = 0
            for (rang, r) in rappels.enumerated()
            where r.instant > vu && r.instant <= declenchement + groupementVol && r.instant > declenchement - toleranceVol {
                res.append(notificationVol(r, rang: rang, a: declenchement, nusah: reglages.siddurNusah, heure: heure))
                dernierVu = max(dernierVu, r.instant)
                montres += 1
            }
            if montres == 0 { break }
            vu = dernierVu
            t = declenchement
        }
        return res
    }

    /// Le titre et le texte d'un rappel du vol (VolAlerte.textes).
    private static func notificationVol(_ r: VolRappels.Rappel, rang: Int, a instant: Int64, nusah: Nusah,
                                        heure: (Int64) -> String) -> NotificationPlanifiee {
        let nom = nomPriere(r.priere)
        let titre: Libelle
        let texte: Libelle
        var suite: Libelle?
        switch r.type {
        case .tefilatHaderekh:
            titre = Libelle("vol_rappel_derekh_titre")
            texte = Libelle("vol_rappel_derekh_texte")
            if let limite = r.limite {
                suite = Libelle("vol_rappel_derekh_priere", .libelle(nom), .texte(heure(limite)))
            }
        case .priere:
            titre = Libelle("vol_rappel_priere_titre", .libelle(nom))
            if let limite = r.limite {
                texte = Libelle("vol_rappel_priere_texte", .libelle(nom), .texte(heure(limite)))
            } else {
                texte = Libelle("vol_rappel_priere_sans_limite", .libelle(nom))
            }
            // Cha'harit : le Chema d'abord (audit du 16/11).
            if r.chema != nil { suite = texteChema(r, heure) }
        case .priereFin:
            titre = Libelle("vol_rappel_fin_titre", .libelle(nom))
            texte = Libelle("vol_rappel_fin_texte", .texte(heure(r.limite ?? r.instant)))
        case .omer:
            titre = Libelle("vol_rappel_omer_titre")
            texte = Libelle("vol_rappel_omer_texte", .texte(String(r.omer)))
        case .hagomel:
            // Audit du 16/11 : obligation en Edot (Kitsour Yalkut Yosef 219:20) ; selon l'usage ailleurs.
            titre = Libelle("vol_rappel_gomel_titre")
            texte = Libelle(nusah == .edot ? "vol_rappel_gomel_texte_edot" : "vol_rappel_gomel_texte")
        case .chemaFin:
            titre = Libelle("vol_rappel_chema_titre")
            texte = texteChema(r, heure)
        }
        return NotificationPlanifiee(identifiant: "vol-" + String(rang) + "-" + r.type.rawValue + "-" + String(r.instant),
                                  instant: instant, titre: titre, texte: texte, suite: suite, categorie: .vol,
                                  texteSiddur: texteSiddur(r))
    }

    /// « Fin du Chema (Maguen Avraham) : … ; au besoin, selon le Gra : … » (VolAlerte.texteChema, audit du 16/11).
    private static func texteChema(_ r: VolRappels.Rappel, _ heure: (Int64) -> String) -> Libelle {
        let chema = heure(r.chema ?? r.instant)
        let autre = r.chemaAutre.map(heure) ?? "\u{2014}"
        return Libelle(r.chemaCle == "szks_mga" ? "vol_rappel_chema_mga" : "vol_rappel_chema_gra", .texte(chema), .texte(autre))
    }

    /// VolAlerte.texteSiddur : le texte du siddour qu'ouvre un rappel du vol.
    static func texteSiddur(_ r: VolRappels.Rappel) -> String {
        switch r.type {
        case .tefilatHaderekh: return "tefilat_haderekh"
        case .omer: return "sefirat_haomer"
        case .hagomel: return "hagomel"
        case .priere, .priereFin, .chemaFin: return r.priere ?? "arvit"
        }
    }

    /// VolAlerte.nomPriere : le nom de la prière, Arvit par défaut.
    private static func nomPriere(_ priere: String?) -> Libelle {
        switch priere ?? "" {
        case "chaharit": return Libelle("widget_zmanim_chaharit")
        case "minha": return Libelle("widget_zmanim_minha")
        default: return Libelle("widget_zmanim_arvit")
        }
    }

    // MARK: Les zmanim calculés

    /// Les zmanim de `Zmanim.jour`, en millisecondes Unix.
    public static func horairesCalcules(_ lieu: Zmanim.Lieu, _ jour: JourCivil) -> [String: Int64] {
        var res: [String: Int64] = [:]
        for z in Zmanim.jour(lieu: lieu, date: jour) {
            if let instant = z.instant {
                res[z.cle] = millis(instant)
            }
        }
        return res
    }

    /// L'allumage de `Zmanim.allumage`, en millisecondes Unix.
    public static func allumageCalcule(_ lieu: Zmanim.Lieu, _ jour: JourCivil, _ minutes: Int) -> Int64? {
        guard let instant = Zmanim.allumage(lieu: lieu, date: jour, minutes: minutes).instant else { return nil }
        return millis(instant)
    }

    /// `Instant.toString()` : « 2026-10-14T06:00:00Z », les millisecondes écrites si elles ne sont pas nulles.
    public static func instantTexte(_ millis: Int64) -> String {
        let c = Fuseau.utc.dateHeure(millis: millis)
        var texte = c.jour.iso + "T" + chiffres(c.heure, 2) + ":" + chiffres(c.minute, 2) + ":" + chiffres(c.seconde, 2)
        if c.milli != 0 {
            texte += "." + chiffres(c.milli, 3)
        }
        return texte + "Z"
    }

    // MARK: Aides

    /// Trié par instant, puis catégorie, puis identifiant : deux programmations du même état donnent la même liste.
    private static func trie(_ liste: [NotificationPlanifiee]) -> [NotificationPlanifiee] {
        liste.sorted { a, b in
            (a.instant, a.categorie.rang, a.identifiant) < (b.instant, b.categorie.rang, b.identifiant)
        }
    }

    private static func millis(_ date: Date) -> Int64 {
        Kotlin.versLong((date.timeIntervalSince1970 * 1000).rounded())
    }

    /// Un entier positif complété de zéros à gauche jusqu'à `largeur` chiffres.
    private static func chiffres(_ n: Int, _ largeur: Int) -> String {
        let texte = String(n)
        let manque = largeur - texte.count
        return manque > 0 ? String(repeating: "0", count: manque) + texte : texte
    }
}
