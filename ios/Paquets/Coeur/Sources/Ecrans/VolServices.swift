import Foundation
import Coeur

// Ce que l'écran du vol (VolActivity.kt) demande au système et au réseau, sans aucune API d'Apple : les
// protocoles que `VolModele` reçoit, leurs faux pour les tests et les aperçus, et les aides pures de l'écran
// (la mise en forme des heures injectée, le vol gardé dans les réglages, les notifications du vol, les
// requêtes en ligne). Les adaptateurs viendront dans ios/App/Services/.

// MARK: Le réseau (route d'un numéro, suivi en direct)

/// Ce qui lit une adresse HTTPS pour l'écran du vol (`URLSession` dans l'app : HTTPS seulement, sans
/// redirection, délais de 15 et 20 s comme `Reseau` et `SuiviVol.Relais` d'Android). Rend le code HTTP et le
/// corps, quel que soit le code ; lève sans connexion (`IOException` de Kotlin).
public protocol VolReseau: Sendable {
    func lire(_ adresse: String) async throws -> RouteVol.Reponse
}

/// Un réseau qui note chaque adresse demandée et rend des réponses enregistrées ; 404 pour une adresse
/// inconnue.
public actor FauxVolReseau: VolReseau {

    /// L'erreur d'un réseau absent.
    public struct HorsLigne: Error, Equatable, Sendable {
        public init() {}
    }

    /// Les adresses demandées, dans l'ordre.
    public private(set) var demandes: [String] = []
    private let reponses: [String: RouteVol.Reponse]
    private let horsLigne: Bool

    public init(_ reponses: [String: RouteVol.Reponse] = [:], horsLigne: Bool = false) {
        self.reponses = reponses
        self.horsLigne = horsLigne
    }

    public func lire(_ adresse: String) throws -> RouteVol.Reponse {
        demandes.append(adresse)
        if horsLigne { throw HorsLigne() }
        return reponses[adresse] ?? RouteVol.Reponse(code: 404, corps: "{}")
    }
}

/// Les services en ligne de l'écran : la route d'un numéro (adsbdb) et le suivi en direct (par le relais).
/// Sur iOS, ils n'existent qu'avec une adresse de relais en HTTPS donnée à la construction (PORTAGE.md § 6.2,
/// décision D10) : le chemin « OpenSky anonyme » d'Android n'est pas porté. Sans elle, l'écran n'en montre
/// rien (ni loupe, ni interrupteur, ni source adsbdb) et rien ne part.
public struct VolEnLigne: Sendable {
    /// L'adresse du relais (`BuildConfig.RELAIS_VOL`), « https://… ».
    public let relais: String
    public let reseau: any VolReseau

    public init(relais: String, reseau: any VolReseau) {
        self.relais = relais
        self.reseau = reseau
    }

    /// Le relais est une adresse HTTPS (`SuiviVol.fournisseur`) : sinon, aucun service en ligne.
    public var disponible: Bool {
        if case .relais = SuiviVol.fournisseur(relais) { return true }
        return false
    }
}

/// Les requêtes de l'écran, hors du fil principal.
enum VolRequetes {

    /// Une adresse que `RouteVol.chercher` demande et qui n'est pas encore lue.
    private struct AdresseALire: Error {}

    /// `RouteVol.chercher` (Coeur) attend un lecteur synchrone ; le réseau répond plus tard. On rejoue donc la
    /// recherche, chaque fois avec les réponses déjà lues, jusqu'à ce qu'elle n'en demande plus de nouvelle :
    /// l'enchaînement des demandes (callsign, puis airline et les indicatifs OACI) reste celui de Coeur. Une
    /// adresse que le réseau n'a pu lire lève à nouveau : `chercher` en fait « hors ligne », comme Android.
    static func route(_ numero: String, depart: String?, reseau: any VolReseau) async -> RouteVol.Resultat {
        var lues: [String: RouteVol.Reponse] = [:]
        var echouees: Set<String> = []
        // Une recherche demande au plus l'indicatif, la compagnie et un indicatif par compagnie qui porte ce code.
        for _ in 0..<24 {
            var aLire: String?
            let resultat = RouteVol.chercher(numero, depart) { adresse in
                if let lue = lues[adresse] { return lue }
                if !echouees.contains(adresse) { aLire = adresse }
                throw AdresseALire()
            }
            guard let adresse = aLire else { return resultat }
            do {
                lues[adresse] = try await reseau.lire(adresse)
            } catch {
                echouees.insert(adresse)
            }
        }
        return .erreur(raison: SuiviVol.Raison.horsLigne)
    }

    /// La position en direct par le relais (`SuiviVol.Relais.position`) : seulement l'indicatif et la position
    /// estimée partent. Un code sous 500 se lit (`SuiviVol.lire`, à l'heure de la réponse) ; en 5xx aussi le corps
    /// se lit (revue du 15/11) : le relais y dit « opensky 429 » quand le quota du jour est épuisé, une erreur
    /// nommée l'emporte alors sur « erreur 502 ». Une connexion absente : « hors ligne ».
    static func position(relais: String, indicatif: String, estime: Vol.Point, reseau: any VolReseau,
                         horloge: any Horloge) async -> SuiviVol.Resultat {
        guard case .relais(let adresseRelais) = SuiviVol.fournisseur(relais) else {
            return .erreur(raison: SuiviVol.Raison.relaisAbsent)
        }
        do {
            let reponse = try await reseau.lire(SuiviVol.adresse(adresseRelais, indicatif, estime))
            let r = SuiviVol.lire(reponse.corps, horloge.maintenant)
            if reponse.code < 500 { return r }
            if case .erreur(let raison) = r, raison != SuiviVol.Raison.illisible { return r }
            return .erreur(raison: SuiviVol.Raison.serveur(reponse.code))
        } catch {
            return .erreur(raison: SuiviVol.Raison.horsLigne)
        }
    }
}

// MARK: Le billet

/// La lecture d'un billet choisi par l'utilisateur, PDF ou photo (LecteurBillet.kt) : le texte du premier
/// code-barres de carte d'embarquement trouvé (PDF417, Aztec, QR, Data Matrix), sur les quatre premières pages
/// d'un PDF ou dans l'image, tournée d'un quart de tour au besoin ; nil s'il n'y en a pas. Rien ne part. Dans
/// l'app, Vision (`VNDetectBarcodesRequest`) sur les pages rendues par PDFKit ; le contenu du code est ensuite lu
/// par `CarteEmbarquement` (Coeur).
public protocol VolLecteurBillet: Sendable {
    func code(_ fichier: URL) async -> String?
}

/// Un lecteur de billet qui rend toujours le même code, et retient les fichiers qu'on lui a donnés.
public actor FauxVolLecteurBillet: VolLecteurBillet {
    public private(set) var lus: [URL] = []
    private let reponse: String?

    public init(_ reponse: String?) {
        self.reponse = reponse
    }

    public func code(_ fichier: URL) -> String? {
        lus.append(fichier)
        return reponse
    }
}

// MARK: Les notifications du vol

/// Retirer les notifications prévues du vol : le `Notificateur` des Services sait les poser et tout retirer,
/// pas en retirer une partie. Dans l'app, `removePendingNotificationRequests` des identifiants qui commencent par
/// `prefixe` (VolAlerte.enregistrer d'une liste vide, `alarmes.cancel`).
public protocol VolRetraitNotifications: Sendable {
    func retirer(prefixe: String) async
}

/// Des notifications en mémoire, pour les tests de l'écran du vol : un notificateur qui sait aussi retirer
/// celles d'un préfixe.
public actor FauxVolNotifications: Notificateur, VolRetraitNotifications {
    /// Les notifications prévues, dans l'ordre où elles ont été programmées.
    public private(set) var prevues: [NotificationPrevue] = []
    public private(set) var demandes = 0
    /// Les préfixes retirés, dans l'ordre.
    public private(set) var retraits: [String] = []
    private let accordee: Bool

    public init(accordee: Bool = true) {
        self.accordee = accordee
    }

    public func autorisation() -> Bool {
        accordee
    }

    public func demanderAutorisation() -> Bool {
        demandes += 1
        return accordee
    }

    public func programmer(_ notifications: [NotificationPrevue]) {
        for notification in notifications {
            prevues.removeAll { $0.identifiant == notification.identifiant }
            prevues.append(notification)
        }
    }

    public func annulerTout() {
        prevues = []
    }

    public func retirer(prefixe: String) {
        retraits.append(prefixe)
        prevues.removeAll { $0.identifiant.commenceParUnites(prefixe) }
    }
}

/// Une notification du vol, telle que VolAlerteReceiver l'afficherait : son titre, son texte et la seconde ligne
/// de Tefilat haDerekh (la prière du moment), que `NotificationPrevue` des Services n'a pas encore.
public struct VolNotification: Sendable, Hashable {
    public let identifiant: String
    /// L'instant où elle paraît, en millisecondes Unix.
    public let instant: Int64
    public let titre: Libelle
    public let texte: Libelle
    public let suite: Libelle?
    /// Le rappel qu'elle montre.
    public let rappel: VolRappels.Rappel

    /// Ce que le Notificateur pose : le titre et le texte (la seconde ligne attend `NotificationPrevue.suite`).
    public var prevue: NotificationPrevue {
        NotificationPrevue(identifiant: identifiant, instant: instant, titre: titre, corps: texte)
    }
}

/// Les notifications des rappels du vol (VolAlerte.kt, VolAlerteReceiver) : Android pose une alarme à la fois et
/// montre, à chaque déclenchement, les rappels dus ; iOS ne réveille pas l'app, tout est donc posé d'avance, dans
/// l'ordre où Android les montrerait. La règle est celle de `PlanNotifications.vol` (Coeur, en chantier), mêmes
/// identifiants : le jour où le planificateur unique sera intégré, il la remplacera.
public enum VolNotifications {

    /// Le début des identifiants des notifications du vol.
    public static let prefixe = "vol-"
    /// La part du vol dans les 64 notifications en attente d'iOS (PORTAGE.md § 2.2.2).
    public static let part = 14
    /// Un rappel déclenché en retard s'affiche encore jusqu'à vingt minutes (VolAlerte.TOLERANCE_MS).
    public static let tolerance: Int64 = 20 * 60_000
    /// Les rappels dus dans la minute qui suit s'affichent ensemble (VolAlerte.dus).
    static let groupement: Int64 = 60_000

    /// Les rappels gardés avec le vol, déclenchement après déclenchement : le plus proche qui n'a pas été montré
    /// (`volRappelVu`) et n'a pas plus de vingt minutes de retard, montré au plus tôt maintenant, avec ceux qui
    /// tombent dans la minute qui suit. Rien si les rappels du vol sont éteints. `heure` écrit l'heure d'une limite
    /// (VolAlerte.deuxHeures).
    public static func prevues(reglages: Reglages, rappels: [VolRappels.Rappel], maintenant: Int64,
                               nombre: Int = part, heure: (Int64) -> String) -> [VolNotification] {
        guard reglages.volRappelsActifs else { return [] }
        var vu = reglages.volRappelVu
        var t = maintenant
        var res: [VolNotification] = []
        while res.count < nombre {
            var prochain: Int64?
            for r in rappels where r.instant > vu && r.instant > t - tolerance {
                if let p = prochain, p <= r.instant { continue }
                prochain = r.instant
            }
            guard let p = prochain else { break }
            let declenchement = max(p, t)
            var dernierVu = vu
            var montres = 0
            for (rang, r) in rappels.enumerated()
            where r.instant > vu && r.instant <= declenchement + groupement && r.instant > declenchement - tolerance {
                res.append(notification(r, rang: rang, a: declenchement, nusah: reglages.siddurNusah, heure: heure))
                dernierVu = max(dernierVu, r.instant)
                montres += 1
            }
            if montres == 0 { break }
            vu = dernierVu
            t = declenchement
        }
        return res
    }

    /// Le titre et le texte d'un rappel (VolAlerte.textes).
    static func notification(_ r: VolRappels.Rappel, rang: Int, a instant: Int64, nusah: Nusah,
                             heure: (Int64) -> String) -> VolNotification {
        let nom = VolMiseEnPage.nomPriere(r.priere)
        let texte: Libelle
        var suite: Libelle?
        switch r.type {
        case .tefilatHaderekh:
            texte = Libelle("vol_rappel_derekh_texte")
            if let limite = r.limite {
                suite = Libelle("vol_rappel_derekh_priere", .libelle(nom), .texte(heure(limite)))
            }
        case .priere:
            if let limite = r.limite {
                texte = Libelle("vol_rappel_priere_texte", .libelle(nom), .texte(heure(limite)))
            } else {
                texte = Libelle("vol_rappel_priere_sans_limite", .libelle(nom))
            }
            // Cha'harit : le Chema d'abord (audit du 16/11).
            if r.chema != nil { suite = texteChema(r, heure) }
        case .priereFin:
            texte = Libelle("vol_rappel_fin_texte", .texte(heure(r.limite ?? r.instant)))
        case .omer:
            texte = Libelle("vol_rappel_omer_texte", .texte(String(r.omer)))
        case .hagomel:
            // Audit du 16/11 : obligation en Edot (Kitsour Yalkut Yosef 219:20) ; selon l'usage ailleurs.
            texte = Libelle(nusah == .edot ? "vol_rappel_gomel_texte_edot" : "vol_rappel_gomel_texte")
        case .chemaFin:
            texte = texteChema(r, heure)
        }
        return VolNotification(identifiant: prefixe + String(rang) + "-" + r.type.rawValue + "-" + String(r.instant),
                               instant: instant, titre: VolMiseEnPage.titreRappel(r), texte: texte, suite: suite,
                               rappel: r)
    }

    /// « Fin du Chema (Maguen Avraham) : … ; au besoin, selon le Gra : … » (VolAlerte.texteChema, audit du 16/11).
    static func texteChema(_ r: VolRappels.Rappel, _ heure: (Int64) -> String) -> Libelle {
        let chema = heure(r.chema ?? r.instant)
        let autre = r.chemaAutre.map(heure) ?? "\u{2014}"
        return Libelle(r.chemaCle == "szks_mga" ? "vol_rappel_chema_mga" : "vol_rappel_chema_gra", .texte(chema), .texte(autre))
    }

    /// Le texte du siddour qu'ouvre le rappel touché (VolAlerte.texteSiddur).
    public static func texteSiddur(_ r: VolRappels.Rappel) -> String {
        switch r.type {
        case .tefilatHaderekh: return "tefilat_haderekh"
        case .omer: return "sefirat_haomer"
        case .hagomel: return "hagomel"
        case .priere, .priereFin, .chemaFin: return r.priere ?? "arvit"
        }
    }
}

// MARK: Le vol gardé dans les réglages

/// Le vol calculé et ses rappels, gardés dans les réglages sous les clés d'Android (Store.vol, Store.setVol,
/// Store.volRappels, Store.setVolRappels), que `Reglages` (Coeur) ne lit pas encore : le numéro, les codes IATA,
/// les instants en millisecondes, le relevé (latitude et longitude écrites comme `Double.toString`, instant,
/// source « GPS » ou « DIRECT »), les rappels une ligne chacun, « TYPE|instant|prière|limite|omer|chema|chemaCle|chemaAutre »
/// (les trois derniers depuis la relecture du 23/11 ; les lignes à cinq champs d'un vol gardé avant se lisent encore).
public enum VolStockage {

    static let numero = "vol_numero"
    static let depart = "vol_depart"
    static let arrivee = "vol_arrivee"
    static let decollage = "vol_decollage"
    static let atterrissage = "vol_atterrissage"
    static let releveLatitude = "vol_releve_latitude"
    static let releveLongitude = "vol_releve_longitude"
    static let releveInstant = "vol_releve_instant"
    static let releveSource = "vol_releve_source"
    static let rappelsCle = "vol_rappels"

    /// Le vol gardé ; nil tant qu'aucun vol complet n'a été calculé, ou si un aéroport n'est plus dans la liste.
    public static func plan(_ reglages: Reglages, _ aeroports: [Vol.Aeroport]) -> Vol.Plan? {
        let brut = reglages.brut
        guard let iataDepart = chaine(brut, depart), let d = Aeroports.parIata(aeroports, iataDepart) else { return nil }
        guard let iataArrivee = chaine(brut, arrivee), let a = Aeroports.parIata(aeroports, iataArrivee) else { return nil }
        guard let t1 = long(brut, decollage), let t2 = long(brut, atterrissage) else { return nil }
        var releve: Vol.Point?
        if let lat = chaine(brut, releveLatitude).flatMap(Java.parseDouble),
           let lon = chaine(brut, releveLongitude).flatMap(Java.parseDouble),
           let t = long(brut, releveInstant) {
            releve = Vol.Point(instant: t, latitude: lat, longitude: lon)
        }
        let source: Vol.SourceReleve = chaine(brut, releveSource) == "DIRECT" ? .direct : .gps
        return Vol.Plan(numero: chaine(brut, numero) ?? "", depart: d, arrivee: a, decollage: t1, atterrissage: t2,
                        releve: releve, sourceReleve: source)
    }

    /// Les réglages avec ce vol ; nil efface le vol, son relevé et ses rappels.
    public static func avecPlan(_ reglages: Reglages, _ plan: Vol.Plan?) -> Reglages {
        var brut = reglages.brut
        let cleReleve = [releveLatitude, releveLongitude, releveInstant, releveSource]
        guard let plan else {
            for cle in [numero, depart, arrivee, decollage, atterrissage, rappelsCle] + cleReleve {
                brut[cle] = nil
            }
            return Reglages(brut: brut)
        }
        brut[numero] = .chaine(plan.numero)
        brut[depart] = .chaine(plan.depart.iata)
        brut[arrivee] = .chaine(plan.arrivee.iata)
        brut[decollage] = .entier(plan.decollage)
        brut[atterrissage] = .entier(plan.atterrissage)
        // Le relevé appartient à ce vol : un vol saisi à nouveau l'efface.
        if let r = plan.releve {
            brut[releveLatitude] = .chaine(Java.texte(r.latitude))
            brut[releveLongitude] = .chaine(Java.texte(r.longitude))
            brut[releveInstant] = .entier(r.instant)
            brut[releveSource] = .chaine(plan.sourceReleve == .direct ? "DIRECT" : "GPS")
        } else {
            for cle in cleReleve {
                brut[cle] = nil
            }
        }
        return Reglages(brut: brut)
    }

    /// Les rappels du vol gardé (Store.volRappels) ; une ligne illisible est sautée.
    public static func rappels(_ reglages: Reglages) -> [VolRappels.Rappel] {
        guard let texte = chaine(reglages.brut, rappelsCle) else { return [] }
        return rappelsDe(texte)
    }

    /// Store.volRappelsDe : une ligne de cinq champs (un vol gardé avant le 23/11) ou de huit ; les trois derniers
    /// sont la fin du Chema du rite, sa clé et celle de l'autre avis. Une ligne d'un autre nombre de champs est sautée.
    public static func rappelsDe(_ texte: String) -> [VolRappels.Rappel] {
        var res: [VolRappels.Rappel] = []
        for ligne in texte.split(separator: "\n", omittingEmptySubsequences: false) {
            let c = ligne.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard c.count == 5 || c.count == 8 else { continue }
            guard let type = VolRappels.Genre.allCases.first(where: { nomKotlin($0) == c[0] }) else { continue }
            guard let t = Int64(c[1]) else { continue }
            func instant(_ i: Int) -> Int64? { i < c.count ? Int64(c[i]) : nil }
            let cle: String? = c.count > 6 && !c[6].isEmpty ? c[6] : nil
            res.append(VolRappels.Rappel(type: type, instant: t, priere: c[2].isEmpty ? nil : c[2],
                                         limite: instant(3), omer: Int(c[4]) ?? 0,
                                         chema: instant(5), chemaCle: cle, chemaAutre: instant(7)))
        }
        return res
    }

    /// Store.volRappelsEnTexte : une ligne par rappel, huit champs.
    public static func rappelsEnTexte(_ rappels: [VolRappels.Rappel]) -> String {
        rappels.map { (r: VolRappels.Rappel) -> String in
            func texte(_ t: Int64?) -> String { t.map { String($0) } ?? "" }
            let champs: [String] = [nomKotlin(r.type), String(r.instant), r.priere ?? "", texte(r.limite), String(r.omer),
                                    texte(r.chema), r.chemaCle ?? "", texte(r.chemaAutre)]
            return champs.joined(separator: "|")
        }.joined(separator: "\n")
    }

    /// Les réglages avec ces rappels (Store.setVolRappels).
    public static func avecRappels(_ reglages: Reglages, _ rappels: [VolRappels.Rappel]) -> Reglages {
        var brut = reglages.brut
        brut[rappelsCle] = .chaine(rappelsEnTexte(rappels))
        return Reglages(brut: brut)
    }

    /// Le nom de l'énumération Kotlin : « TEFILAT_HADEREKH », « PRIERE_FIN ».
    static func nomKotlin(_ genre: VolRappels.Genre) -> String {
        genre.rawValue.uppercased()
    }

    private static func chaine(_ brut: ObjetJSON, _ cle: String) -> String? {
        if case .chaine(let texte)? = brut[cle] { return texte }
        return nil
    }

    /// `getLong(cle, -1).takeIf { it >= 0 }`.
    private static func long(_ brut: ObjetJSON, _ cle: String) -> Int64? {
        guard let valeur = brut[cle]?.commeLong, valeur >= 0 else { return nil }
        return valeur
    }
}

// MARK: Les heures écrites

/// L'écriture des dates et des heures de l'écran, dans la langue de l'app : ce que les `DateTimeFormatter`
/// d'Android font avec `Locale.forLanguageTag(langue)`. Injectée : le modèle ne met rien en forme lui-même, et
/// ses textes (des `Libelle`) portent ces heures déjà écrites, comme les `getString` d'Android. `neutre` écrit des
/// chiffres seulement (tests, aperçus) ; `langue(_:)` est celle de l'app.
public struct VolFormats: Sendable {
    /// L'heure locale d'un aéroport : « mar. 10 ⁦18:42 TLV⁩ » avec le jour (`EEE d`), « ⁦11:42 JFK⁩ » sans.
    /// L'heure et le code sont isolés de gauche à droite (U+2066…U+2069), le jour reste dans le sens de la langue.
    public var heure: @Sendable (_ civile: DateHeure, _ iata: String, _ avecJour: Bool) -> String
    /// Un jour : « mar. 10 nov. » (`EEE d MMM`).
    public var jour: @Sendable (JourCivil) -> String
    /// Une heure saisie : « mar. 10 nov. 2026 · 18:42 » (`EEE d MMM yyyy · HH:mm`).
    public var saisie: @Sendable (DateHeure) -> String
    /// Un nombre à une décimale (`%.1f` dans la langue) : « 48,9 », « 48.9 ».
    public var decimal: @Sendable (Double) -> String

    public init(heure: @escaping @Sendable (_ civile: DateHeure, _ iata: String, _ avecJour: Bool) -> String,
                jour: @escaping @Sendable (JourCivil) -> String,
                saisie: @escaping @Sendable (DateHeure) -> String,
                decimal: @escaping @Sendable (Double) -> String) {
        self.heure = heure
        self.jour = jour
        self.saisie = saisie
        self.decimal = decimal
    }

    /// Des chiffres seulement : « 2026-11-17 ⁦11:00 LYS⁩ », « 2026-11-17 · 11:00 », « 48.9 ».
    public static let neutre = VolFormats(
        heure: { civile, iata, avecJour in
            VolFormats.ecrire(avecJour ? civile.jour.iso : nil, civile, iata)
        },
        jour: { $0.iso },
        saisie: { $0.jour.iso + " · " + VolFormats.hm($0) },
        decimal: { Java.format($0, decimales: 1) })

    /// L'écriture d'Android dans la langue de l'app (« fr », « en », « he ») : les noms de jours et de mois de
    /// `DateFormatter`, la virgule décimale du français.
    public static func langue(_ langue: String) -> VolFormats {
        VolFormats(
            heure: { civile, iata, avecJour in
                VolFormats.ecrire(avecJour ? VolFormats.motif("EEE d", langue, civile) : nil, civile, iata)
            },
            jour: { VolFormats.motif("EEE d MMM", langue, DateHeure($0)) },
            saisie: { VolFormats.motif("EEE d MMM yyyy · HH:mm", langue, $0) },
            decimal: { x in
                let texte = Java.format(x, decimales: 1)
                return langue == "fr" ? texte.remplacantUnites(".", par: ",") : texte
            })
    }

    /// « mar. 10 ⁦18:42 TLV⁩ » : le jour s'il est donné, puis l'heure et le code isolés de gauche à droite.
    static func ecrire(_ jour: String?, _ civile: DateHeure, _ iata: String) -> String {
        let isole: String = "\u{2066}" + hm(civile) + " " + iata + "\u{2069}"
        guard let jour else { return isole }
        return jour + " " + isole
    }

    /// « 09:05 ».
    static func hm(_ civile: DateHeure) -> String {
        String(format: "%02d:%02d", civile.heure, civile.minute)
    }

    /// Une heure civile écrite selon `motif` dans `langue` : lue comme une heure UTC, écrite en UTC.
    private static func motif(_ motif: String, _ langue: String, _ civile: DateHeure) -> String {
        let format = DateFormatter()
        // En arabe, des chiffres 0 à 9 (Chiffres.locale, décision du 24/11).
        format.locale = Traducteur.localeDesChiffres(langue)
        format.timeZone = TimeZone(secondsFromGMT: 0)
        format.dateFormat = motif
        let millis = Fuseau.utc.millis(civile)
        return format.string(from: Date(timeIntervalSince1970: Double(millis) / 1000))
    }
}

// MARK: Les textes de l'écran

/// L'heure d'un instant aux deux aéroports, écrite (VolAlerte.deuxHeures) : `depart` porte le jour,
/// `arrivee` seulement s'il change. Ensemble : « mar. 10 ⁦18:42 TLV⁩ · ⁦11:42 JFK⁩ ».
public struct VolDeuxHeures: Sendable, Hashable {
    public let depart: String
    public let arrivee: String

    public init(depart: String, arrivee: String) {
        self.depart = depart
        self.arrivee = arrivee
    }

    public var texte: String {
        depart + " · " + arrivee
    }
}

/// Les textes de l'écran qui ne dépendent que de leurs arguments (VolActivity, VolAlerte).
public enum VolMiseEnPage {

    /// Les heures d'un instant aux deux aéroports ; nil si un fuseau est inconnu.
    public static func deuxHeures(_ plan: Vol.Plan, _ t: Int64, _ formats: VolFormats) -> VolDeuxHeures? {
        guard let zd = Vol.zone(plan.depart.fuseau), let za = Vol.zone(plan.arrivee.fuseau) else { return nil }
        let dep = zd.dateHeure(millis: t)
        let arr = za.dateHeure(millis: t)
        return VolDeuxHeures(depart: formats.heure(dep, plan.depart.iata, true),
                             arrivee: formats.heure(arr, plan.arrivee.iata, arr.jour != dep.jour))
    }

    /// Les deux heures en une ligne ; `Instant.toString()` si un fuseau est inconnu.
    public static func texteDeuxHeures(_ plan: Vol.Plan, _ t: Int64, _ formats: VolFormats) -> String {
        deuxHeures(plan, t, formats)?.texte ?? instantTexte(t)
    }

    /// « mer. 28 ⁦19:20 TLV⁩ » : l'heure locale d'un aéroport, celle du billet (heureAeroport).
    public static func heureAeroport(_ a: Vol.Aeroport, _ t: Int64, _ formats: VolFormats) -> String {
        guard let z = Vol.zone(a.fuseau) else { return a.iata }
        return formats.heure(z.dateHeure(millis: t), a.iata, true)
    }

    /// `Instant.toString()` à la seconde : « 2026-10-14T06:00:00Z ».
    static func instantTexte(_ t: Int64) -> String {
        let c = Fuseau.utc.dateHeure(millis: t)
        return c.jour.iso + "T" + String(format: "%02d:%02d:%02d", c.heure, c.minute, c.seconde) + "Z"
    }

    /// Le nom d'une prière (VolAlerte.nomPriere) : Arvit par défaut.
    public static func nomPriere(_ priere: String?) -> Libelle {
        switch priere ?? "" {
        case "chaharit": return Libelle("widget_zmanim_chaharit")
        case "minha": return Libelle("widget_zmanim_minha")
        default: return Libelle("widget_zmanim_arvit")
        }
    }

    /// Le titre d'un rappel, celui de sa notification (VolAlerte.textes).
    public static func titreRappel(_ r: VolRappels.Rappel) -> Libelle {
        switch r.type {
        case .tefilatHaderekh: return Libelle("vol_rappel_derekh_titre")
        case .priere: return Libelle("vol_rappel_priere_titre", .libelle(nomPriere(r.priere)))
        case .priereFin: return Libelle("vol_rappel_fin_titre", .libelle(nomPriere(r.priere)))
        case .omer: return Libelle("vol_rappel_omer_titre")
        case .hagomel: return Libelle("vol_rappel_gomel_titre")
        case .chemaFin: return Libelle("vol_rappel_chema_titre")
        }
    }

    /// `Duration.between(de, a).toMinutes()` : les secondes entières vers moins l'infini, puis la division
    /// tronquée de Java.
    public static func minutes(de: Int64, a: Int64) -> Int64 {
        let ms = a - de
        let secondes = ms >= 0 ? ms / 1000 : -((-ms + 999) / 1000)
        return secondes / 60
    }

    /// « 10 minutes », « 1 minute », « 1 h 11 min », « 2 h » : le compte à rebours en toutes lettres (dureeEnMots).
    public static func dureeEnMots(_ minutes: Int) -> Libelle {
        if minutes == 1 { return Libelle("vol_duree_une_minute") }
        if minutes < 60 { return Libelle("vol_duree_minutes", .texte(String(minutes))) }
        // Un pluriel d'Android (« 1 heure », « 3 heures ») : `getQuantityString`.
        if minutes % 60 == 0 {
            return Libelle.pluriel("vol_duree_heures", quantite: minutes / 60, .texte(String(minutes / 60)))
        }
        return Libelle("vol_duree_heures_minutes", .texte(String(minutes / 60)), .texte(String(minutes % 60)))
    }

    /// « +12 min si le départ a 30 min de retard » ; « …l'arrivée… » quand la route est recalée sur un relevé.
    public static func ecart(_ ms: Int64, recale: Bool) -> Libelle {
        let signe = ms < 0 ? "\u{2212}" : "+"
        let m = minutes(de: 0, a: ms)
        return Libelle(recale ? "vol_ecart_gps" : "vol_ecart", .texte(signe + String(m < 0 ? -m : m)))
    }

    /// « au-dessus de 48,9° N, 2,4° E ».
    public static func position(_ latitude: Double, _ longitude: Double, _ formats: VolFormats) -> Libelle {
        let lat = formats.decimal(Swift.abs(latitude))
        let lon = formats.decimal(Swift.abs(longitude))
        return Libelle("vol_position",
                       .libelle(Libelle(latitude >= 0 ? "vol_lat_nord" : "vol_lat_sud", .texte(lat))),
                       .libelle(Libelle(longitude >= 0 ? "vol_lon_est" : "vol_lon_ouest", .texte(lon))))
    }

    /// Une raison de `SuiviVol.Raison` dans la langue de l'interface (raisonLisible).
    public static func raison(_ raison: String) -> Libelle {
        if let code = SuiviVol.Raison.codeServeur(raison) { return Libelle("vol_erreur_serveur", .entier(code)) }
        switch raison {
        case SuiviVol.Raison.horsLigne: return Libelle("vol_erreur_hors_ligne")
        case SuiviVol.Raison.quota: return Libelle("vol_erreur_quota")
        case SuiviVol.Raison.illisible: return Libelle("vol_erreur_illisible")
        case SuiviVol.Raison.positionInvalide: return Libelle("vol_erreur_position")
        case SuiviVol.Raison.relaisAbsent: return Libelle("vol_erreur_relais_absent")
        case SuiviVol.Raison.tropDeDemandes: return Libelle("vol_erreur_trop_de_demandes")
        default: return Libelle("vol_erreur_service")
        }
    }

    /// La phrase d'une saisie refusée par `Vol.verifier`.
    public static func invalide(_ i: Vol.Invalide) -> Libelle {
        switch i {
        case .memeAeroport: return Libelle("vol_invalide_meme_aeroport")
        case .arriveeAvantDepart: return Libelle("vol_invalide_arrivee_avant_depart")
        case .tropLong: return Libelle("vol_invalide_trop_long")
        case .fuseauInconnu: return Libelle("vol_invalide_fuseau_inconnu")
        }
    }

    /// La phrase d'une réserve du calcul.
    public static func reserve(_ r: Vol.Reserve) -> Libelle {
        switch r {
        case .hauteLatitude: return Libelle("vol_reserve_haute_latitude")
        case .absent: return Libelle("vol_reserve_absent")
        case .erreur: return Libelle("vol_reserve_erreur")
        case .aRebours: return Libelle("vol_reserve_a_rebours")
        }
    }

    /// Le nom d'un zman de la frise (« zman_<clé> ») ; la clé elle-même hors de la table (comme Android).
    public static func nomZman(_ cle: String) -> Libelle {
        Libelle(Libelles.res("zman_" + cle) ?? cle)
    }

    /// « LYS · Lyon » : le code et la ville (ou le nom) d'un aéroport choisi.
    public static func nomAeroport(_ a: Vol.Aeroport) -> String {
        a.iata + " · " + (a.ville.isEmpty ? a.nom : a.ville)
    }
}
