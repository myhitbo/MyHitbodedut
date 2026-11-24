import Foundation
import Observation
import Coeur

// Les hilloulot (HilloulotActivity.kt, 11/10, réorganisées le 04/11) : en haut la recherche, puis le jour (flèches,
// retour à aujourd'hui) et ses tsadikim en liste compacte, les mieux connus d'abord ; un nom touché déplie sa
// notice, ses biographies et leurs sources. La recherche range les résultats par date, de Tichri à Eloul, et
// chaque date mène à son jour. L'interrupteur de la carte du jour est en bas : c'est un réglage, pas le contenu.
//
// La langue est celle de l'app (`Traducteur.langue`) : `ChizukCard.language(context)` d'Android. Israël ou
// diaspora, le noussa'h (ashkénaze ou non), l'interrupteur et la taille des lettres sont les réglages du
// `Magasin`, lus à chaque fois.

// MARK: Les contenus

/// `hilloulot.json` et les biographies d'autres sources (`hilloulot_bios/<mois>.json`), lus à la première demande
/// puis gardés (Hilloulot.table, Hilloulot.tableComplete). Android lit les biographies de toute l'année (6,9 Mo)
/// à l'ouverture de l'écran ; l'export les a coupées par mois, et seuls se lisent les mois qu'on montre.
///
/// À rejoindre `ContenusApp` quand Hilloulot y sera intégré (voir Contenus.swift) : un acteur à part d'ici là.
public actor HilloulotContenus {

    private let lire: ContenusApp.Lecteur
    private var tableLue: Hilloulot.Table?
    /// La table avec les biographies des fichiers déjà lus.
    private var complete: Hilloulot.Table?
    /// Les fichiers de biographies déjà appliqués (« hilloulot_bios/7.json »).
    public private(set) var fichiersLus: Set<String> = []

    public init(lecteur: @escaping ContenusApp.Lecteur) {
        lire = lecteur
    }

    /// Les contenus d'un dossier : `Contenu/` du paquet de l'app, ou `ios/Ressources/Contenu` du dépôt.
    public init(dossier: URL) {
        lire = ContenusApp.lecteur(dossier: dossier)
    }

    /// La table sans les biographies : la carte du jour, la recherche globale. Lève si le fichier manque ou
    /// ne se lit pas ; il sera relu à la demande suivante.
    public func table() throws -> Hilloulot.Table {
        if let tableLue { return tableLue }
        guard let donnees = try lire("hilloulot.json") else { throw ErreurContenu.absent("hilloulot.json") }
        let lue = try Hilloulot.parse(donnees)
        tableLue = lue
        return lue
    }

    /// La table avec les biographies des mois de ces clés (« 7-30 », « adar2-7 »), et de ceux déjà lus. Un mois
    /// sans fichier n'a pas de biographie ; un fichier illisible lève, et sera relu à la demande suivante.
    public func avecBios(pour cles: [String]) throws -> Hilloulot.Table {
        var courante = try complete ?? table()
        for fichier in Set(cles.map(Hilloulot.fichierDesBios)).sorted() where !fichiersLus.contains(fichier) {
            if let donnees = try lire(fichier) {
                courante = try Hilloulot.avecBios(courante, donnees)
                complete = courante
            }
            fichiersLus.insert(fichier)
        }
        return courante
    }
}

// MARK: Ce que l'écran montre

/// Où en est la lecture de la table.
public enum HilloulotEtat: Sendable, Equatable {
    case chargement
    case pret
    /// `hilloulot.json` n'a pu être lu : l'écran montre « Aucune hilloula ce jour », la recherche ne trouve rien.
    case erreur
}

/// Un lien externe : son libellé, suivi dans la vue de « ↗ », et l'adresse qu'ouvre le navigateur.
public struct HilloulotLien: Sendable, Equatable {
    public let libelle: Libelle
    public let url: String
}

/// Une source d'une fiche (HilloulotActivity.source) : discrète, 12 sp ; avec un lien, couleur de marque et
/// « ↗ » au bout, et le toucher ouvre `lien` ; sans lien, couleur atténuée, rien ne se touche.
public struct HilloulotSource: Sendable, Equatable, Identifiable {
    public let id: String
    public let nom: Libelle
    public let lien: String?
}

/// Une biographie d'une autre source (MyTzadik, המאיר לארץ), mot pour mot, suivie de sa source, comme le
/// demande l'accord.
public struct HilloulotBio: Sendable, Equatable, Identifiable {
    public let id: String
    /// `VueJour.paragraphes` : une demi-ligne vide entre deux paragraphes.
    public let paragraphes: [String]
    /// Plus de 500 unités : elle se replie à huit lignes, et `bouton` la déplie.
    public let longue: Bool
    /// Vrai : la vue la coupe à huit lignes, « … » au bout.
    public let repliee: Bool
    /// « Lire la suite » ou « Réduire », sous le texte, du côté où il commence ; nil pour une biographie courte.
    public let bouton: Libelle?
    public let source: HilloulotSource
}

/// Ce qui se déplie sous un nom (HilloulotActivity.fiche), dans cet ordre : la notice de Wikipédia, les sources
/// (Wikipédia, החכם היומי, תורת אמת), chaque biographie et sa source, Hidabroot.
public struct HilloulotFiche: Sendable, Equatable {
    /// La première phrase de l'article de Wikipédia hébreu, en paragraphes ; nil sans notice.
    public let description: [String]?
    public let sources: [HilloulotSource]
    public let bios: [HilloulotBio]
    /// « Lire sur Hidabroot ↗ », l'article de ce tsadik ; nil s'il n'y en a pas.
    public let hidabroot: HilloulotSource?
}

/// Un tsadik (HilloulotActivity.ligne) : son nom, la traduction et l'année dessous ; le chevron s'il y a de quoi
/// déplier. Écrit de droite à gauche dans toutes les langues : le nom hébreu à droite, le chevron à gauche.
public struct HilloulotLigne: Sendable, Equatable, Identifiable {
    /// Unique dans l'écran.
    public let id: String
    /// « 2026-11-15|<nom> » au jour, « r|<clé>|<nom> » dans la recherche : ce que retient le dépliage.
    public let cle: String
    /// Le nom hébreu, 17 sp, gras ; les signes absents de la police masqués (U+034F).
    public let nom: String
    /// Le nom dans la langue de l'app (en anglais à défaut du français) ; nil en hébreu ou sans traduction.
    public let traduit: String?
    /// « Décès : ⁨ה'תרל"ה⁩ » ; nil sans année.
    public let deces: Libelle?
    /// La première de sa carte : pas de filet au-dessus.
    public let premiere: Bool
    /// Une notice, une biographie, un article ou un lien Hidabroot : le chevron, et la ligne se touche.
    public let depliable: Bool
    public let ouverte: Bool
    /// Pour l'accessibilité, après le nom et la traduction : « Réduire » ou « Lire la suite » ; nil sinon.
    public let action: Libelle?
    /// Ce qui se déplie ; nil si la ligne est fermée.
    public let fiche: HilloulotFiche?
}

/// Les résultats d'une date (HilloulotActivity.enteteDate) : la date hébraïque, « Voir ce jour › », ses tsadikim.
public struct HilloulotGroupe: Sendable, Equatable, Identifiable {
    public var id: String { cle }
    /// La clé « mois-jour » (« 7-30 »).
    public let cle: String
    /// « ל׳ תשרי » (Hilloulot.dateDe).
    public let date: String
    /// « Voir ce jour › » : `voirLeJour(_:)`.
    public let voir: Libelle
    public let lignes: [HilloulotLigne]
}

/// Le jour montré, hors recherche.
public struct HilloulotDuJour: Sendable, Equatable {
    public let jour: JourCivil
    /// « כ״ז אדר א׳ תשפ״ז ».
    public let dateHebraique: String
    /// « Aujourd'hui » sous la date quand on s'en est éloigné : `revenirAujourdhui()` ; nil le jour même.
    public let aujourdhui: Libelle?
    /// « Aucune hilloula ce jour » ; nil s'il y en a.
    public let aucune: Libelle?
    /// « 7 tsadikim ce jour », puis « Touchez un nom pour lire sa biographie. » s'il y en a plusieurs et qu'un se
    /// déplie : joints par « · » ; vide sans hilloula.
    public let entete: [Libelle]
    /// La carte des tsadikim, les mieux connus d'abord (Hilloulot.duJour) ; un seul : déplié d'office.
    public let lignes: [HilloulotLigne]
    /// « Les sages du jour sur hyomi.org.il ↗ ».
    public let lien: HilloulotLien
}

/// La recherche (deux unités au moins, une fois rognée).
public struct HilloulotResultats: Sendable, Equatable {
    /// « Résultats : 12 » : toutes les trouvailles, même au-delà des soixante montrées.
    public let nombre: Libelle
    /// Les soixante premières, par date dans l'ordre de l'année, en une seule carte.
    public let groupes: [HilloulotGroupe]
}

/// Ce que montre la liste, entre la carte de recherche (en haut) et celle du réglage (en bas).
public enum HilloulotContenu: Sendable, Equatable {
    /// La table se lit, ou la première recherche tourne.
    case chargement
    case jour(HilloulotDuJour)
    case recherche(HilloulotResultats)
}

// MARK: Le modèle

/// L'écran des hilloulot. Il s'ouvre sur aujourd'hui, sur une date (`EXTRA_DATE`, la carte du jour) ou sur une
/// recherche (`EXTRA_RECHERCHE`, un résultat de la recherche globale).
@MainActor
@Observable
public final class HilloulotModele {

    /// Au plus tant de trouvailles montrées (`take(60)`).
    public static let resultatsMontres = 60
    /// Une biographie plus longue que cela (en unités UTF-16) se replie à huit lignes.
    public static let bioLongue = 500

    private let magasin: Magasin
    private let contenus: HilloulotContenus
    private let horloge: any Horloge
    /// « fr », « en » ou « he ».
    public let langue: String

    /// Le jour montré.
    public private(set) var jour: JourCivil
    /// Le texte du champ de recherche.
    public private(set) var recherche: String
    public private(set) var etat: HilloulotEtat = .chargement
    /// Augmente quand la liste doit revenir en haut (« Voir ce jour ») : la vue défile alors au début.
    public private(set) var retourEnHaut = 0
    /// Le bouton de lecture (ReglagesLecture.installer, `avecNuit` et `avecLangues` faux) : la taille des lettres, la
    /// police, le défilement automatique, masquer, replier.
    public let barre: TehilimBarreLecture

    /// La table, avec les biographies des mois déjà lus ; nil tant qu'elle se lit.
    private var table: Hilloulot.Table?
    /// Les noms dépliés et repliés exprès (`cle` des lignes) ; un seul tsadik ce jour-là est déplié d'office.
    private var deplies: Set<String> = []
    private var replies: Set<String> = []
    /// Les longues biographies dépliées (`id` des biographies).
    private var biosOuvertes: Set<String> = []
    /// Les trouvailles de la dernière recherche finie.
    private var trouvees: Trouvees?

    @ObservationIgnored private var quitteLe: JourCivil?
    @ObservationIgnored private var fichiersBios: Set<String> = []
    @ObservationIgnored private var tacheRecherche: Task<Void, Never>?
    @ObservationIgnored private var tacheBios: Task<Void, Never>?
    @ObservationIgnored private var demande = 0

    private struct Trouvees: Sendable {
        let texte: String
        let liste: [(cle: String, hilloula: Hilloulot.Hilloula)]
    }

    /// `date` : `EXTRA_DATE` (aujourd'hui sinon, dans le fuseau du téléphone) ; `recherche` : `EXTRA_RECHERCHE`,
    /// qui remplit le champ (RechercheActivity.preremplir). Rien ne se lit avant `charger()`.
    public init(magasin: Magasin, contenus: HilloulotContenus, horloge: any Horloge, langue: String,
                date: JourCivil? = nil, recherche: String? = nil) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = langue
        jour = date ?? horloge.aujourdhui
        self.recherche = recherche ?? ""
        barre = TehilimBarreLecture(magasin: magasin, langue: langue, avecNuit: false, avecLangues: false)
    }

    // MARK: Les réglages

    /// Israël ou diaspora (Store.inIsrael) : le réglage, sinon ce que dit le fuseau du téléphone.
    public var enIsrael: Bool {
        magasin.reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// Le noussa'h ashkénaze : « adar » sans précision se dit alors en Adar I (Hilloulot.cles).
    public var ashkenaz: Bool {
        magasin.reglages.siddurNusah == .ashkenaz
    }

    /// L'interrupteur du bas : la hilloula sur la carte du jour, à l'accueil.
    public var afficheesSurLaCarteDuJour: Bool {
        magasin.reglages.hilloulotAffichees
    }

    /// La taille des lettres des écrans de lecture (0,8 à 2), qui multiplie celle de chaque texte de la liste
    /// (ReglagesLecture.retailler), hors champ de recherche.
    public var echelle: Float { magasin.reglages.lectureEchelle }

    /// La police hébraïque des réglages de lecture : la date hébraïque, les noms, les notices et les biographies.
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    // MARK: Ce qui s'affiche

    /// Deux unités au moins, une fois rognées (`recherche.trim().length >= 2`) : la liste montre les résultats.
    public var enRecherche: Bool {
        recherche.rogne.utf16.count >= 2
    }

    public var estAujourdhui: Bool {
        jour == horloge.aujourdhui
    }

    public var contenu: HilloulotContenu {
        guard let table else { return .chargement }
        if enRecherche {
            guard let trouvees else { return .chargement }
            return .recherche(resultats(trouvees))
        }
        return .jour(duJour(table))
    }

    private func duJour(_ table: Hilloulot.Table) -> HilloulotDuJour {
        let israel = enIsrael
        let du = Hilloulot.pour(table, date: jour, enIsrael: israel, ashkenaz: ashkenaz)
        var entete: [Libelle] = []
        var lignes: [HilloulotLigne] = []
        if !du.isEmpty {
            entete.append(Libelle.pluriel("hilloulot_nombre", quantite: du.count, .entier(du.count)))
            if du.count > 1 && du.contains(where: { HilloulotModele.aDesDetails($0) }) {
                entete.append(Libelle("hilloulot_toucher"))
            }
            for (i, h) in du.enumerated() {
                lignes.append(ligne(h, id: "\(jour.iso)#\(i)", cle: "\(jour.iso)|\(h.he)",
                                    ouvertParDefaut: du.count == 1, premiere: i == 0))
            }
        }
        return HilloulotDuJour(jour: jour,
                               dateHebraique: CalendrierJuif.jour(jour, enIsrael: israel).dateHebraique,
                               aujourdhui: estAujourdhui ? nil : Libelle("calendrier_aujourdhui"),
                               aucune: du.isEmpty ? Libelle("hilloulot_aucune") : nil,
                               entete: entete,
                               lignes: lignes,
                               lien: HilloulotLien(libelle: Libelle("hilloula_lien"), url: Hilloulot.lienHyomi(jour)))
    }

    /// Une seule carte, par date dans l'ordre de l'année (`groupBy` garde l'ordre des premières apparitions).
    private func resultats(_ t: Trouvees) -> HilloulotResultats {
        var cles: [String] = []
        var parCle: [String: [Hilloulot.Hilloula]] = [:]
        for (cle, h) in t.liste.prefix(HilloulotModele.resultatsMontres) {
            if parCle[cle] == nil { cles.append(cle) }
            parCle[cle, default: []].append(h)
        }
        var groupes: [HilloulotGroupe] = []
        for cle in cles {
            let noms = parCle[cle] ?? []
            var lignes: [HilloulotLigne] = []
            for (i, h) in noms.enumerated() {
                lignes.append(ligne(h, id: "r|\(cle)#\(i)", cle: "r|\(cle)|\(h.he)", ouvertParDefaut: false, premiere: i == 0))
            }
            groupes.append(HilloulotGroupe(cle: cle, date: Hilloulot.dateDe(cle), voir: Libelle("hilloulot_ouvrir_jour"),
                                           lignes: lignes))
        }
        return HilloulotResultats(nombre: Libelle("hilloulot_resultats", .entier(t.liste.count)), groupes: groupes)
    }

    /// Une notice, une biographie, un article de Hidabroot ou de Wikipédia : de quoi déplier.
    private nonisolated static func aDesDetails(_ h: Hilloulot.Hilloula) -> Bool {
        h.description != nil || !h.bios.isEmpty || h.hidabroot != nil || h.article != nil
    }

    /// Le nom traduit : l'anglais en anglais ; le français, ou l'anglais à défaut (audit 1.390), en français ;
    /// rien en hébreu.
    private func traduction(_ h: Hilloulot.Hilloula) -> String? {
        let nom: String?
        if langue.commenceParUnites("en") {
            nom = h.en
        } else if langue.commenceParUnites("fr") {
            nom = h.fr ?? h.en
        } else {
            nom = nil
        }
        guard let nom, !nom.estBlanc else { return nil }
        return nom
    }

    private func ligne(_ h: Hilloulot.Hilloula, id: String, cle: String, ouvertParDefaut: Bool, premiere: Bool) -> HilloulotLigne {
        let details = HilloulotModele.aDesDetails(h)
        let ouverte = details && (deplies.contains(cle) || (ouvertParDefaut && !replies.contains(cle)))
        // Isolée (FSI … PDI) : l'année hébraïque ne renverse pas la ligne.
        let deces: Libelle? = h.annee.estBlanc ? nil : Libelle("hilloula_annee", .texte("\u{2068}\(h.annee)\u{2069}"))
        // Les signes absents de la police choisie masqués (PoliceHebraique.appliquer d'Android) : le nom, la notice et
        // les biographies ; la clé garde le nom tel quel.
        return HilloulotLigne(id: id, cle: cle, nom: PoliceHebraique.masque(h.he, police: police), traduit: traduction(h),
                              deces: deces, premiere: premiere,
                              depliable: details, ouverte: ouverte,
                              action: details ? Libelle(ouverte ? "hilloula_reduire" : "hilloula_lire_plus") : nil,
                              fiche: ouverte ? fiche(h, id: id) : nil)
    }

    private func fiche(_ h: Hilloulot.Hilloula, id: String) -> HilloulotFiche {
        let police = self.police
        // La source : Wikipédia (l'article s'il existe), החכם היומי, תורת אמת.
        var sources: [HilloulotSource] = []
        if h.sources.contientUnites("w") {
            sources.append(HilloulotSource(id: "\(id)#w", nom: Libelle("hilloula_source_wiki"),
                                           lien: h.article.map { Hilloulot.lienArticle($0) }))
        }
        if h.sources.contientUnites("h") {
            sources.append(HilloulotSource(id: "\(id)#h", nom: Libelle("hilloula_source_hyomi"), lien: nil))
        }
        if h.sources.contientUnites("e") {
            sources.append(HilloulotSource(id: "\(id)#e", nom: Libelle("hilloula_source_toratemet"), lien: nil))
        }
        var bios: [HilloulotBio] = []
        for (b, bio) in h.bios.enumerated() {
            let idBio = "\(id)#bio\(b)"
            let longue = bio.texte.utf16.count > HilloulotModele.bioLongue
            let ouverte = biosOuvertes.contains(idBio)
            let nom = bio.source.egalUnites("m") ? "hilloula_source_mytzadik" : "hilloula_source_hameir"
            bios.append(HilloulotBio(id: idBio, paragraphes: HalakhaTexte.paragraphes(PoliceHebraique.masque(bio.texte, police: police)),
                                     longue: longue,
                                     repliee: longue && !ouverte,
                                     bouton: longue ? Libelle(ouverte ? "hilloula_reduire" : "hilloula_lire_plus") : nil,
                                     source: HilloulotSource(id: "\(idBio)#source", nom: Libelle(nom), lien: bio.lien)))
        }
        let hidabroot = h.hidabroot.map { HilloulotSource(id: "\(id)#i", nom: Libelle("hilloula_source_hidabroot"), lien: $0) }
        return HilloulotFiche(description: h.description.map { HalakhaTexte.paragraphes(PoliceHebraique.masque($0, police: police)) },
                              sources: sources, bios: bios,
                              hidabroot: hidabroot)
    }

    // MARK: Les actions

    /// Lit la table (sans biographies : l'écran s'ouvre tout de suite), puis les biographies du jour montré, ou
    /// lance la recherche reçue. Rend la main une fois la table lue ; le reste suit (`attendre()`).
    public func charger() async {
        guard table == nil else { return }
        do {
            table = try await contenus.table()
            etat = .pret
        } catch {
            table = [:]
            etat = .erreur
        }
        if enRecherche {
            lancerRecherche()
        } else {
            chargerBios()
        }
    }

    /// Le texte du champ a changé.
    public func chercher(_ texte: String) {
        recherche = texte
        if enRecherche {
            lancerRecherche()
        } else {
            demande += 1
            tacheRecherche?.cancel()
            tacheRecherche = nil
            trouvees = nil
            chargerBios()
        }
    }

    public func jourPrecedent() {
        aller(jour.plus(jours: -1))
    }

    public func jourSuivant() {
        aller(jour.plus(jours: 1))
    }

    /// « Aujourd'hui », sous la date.
    public func revenirAujourdhui() {
        aller(horloge.aujourdhui)
    }

    /// « Voir ce jour › » d'un résultat : le prochain jour où tombe sa date, à partir d'aujourd'hui ; ses tsadikim
    /// dépliés, le champ vidé, la liste revenue en haut. Rien si la date ne tombe pas dans les trois ans.
    public func voirLeJour(_ groupe: HilloulotGroupe) {
        guard let d = Hilloulot.prochainJour(groupe.cle, depuis: horloge.aujourdhui, enIsrael: enIsrael,
                                             ashkenaz: ashkenaz) else { return }
        jour = d
        // Les tsadikim de cette date parmi les soixante montrés (les `noms` d'Android), sous leur nom tel quel.
        for (cle, h) in trouvees?.liste.prefix(HilloulotModele.resultatsMontres) ?? [] where cle.egalUnites(groupe.cle) {
            deplies.insert("\(d.iso)|\(h.he)")
        }
        chercher("")
        retourEnHaut += 1
    }

    /// Un nom touché : sa fiche se déplie ou se replie.
    public func basculer(_ ligne: HilloulotLigne) {
        guard ligne.depliable else { return }
        if ligne.ouverte {
            deplies.remove(ligne.cle)
            replies.insert(ligne.cle)
        } else {
            deplies.insert(ligne.cle)
            replies.remove(ligne.cle)
        }
    }

    /// « Lire la suite » ou « Réduire » d'une longue biographie.
    public func basculer(bio: HilloulotBio) {
        guard bio.longue else { return }
        if biosOuvertes.contains(bio.id) {
            biosOuvertes.remove(bio.id)
        } else {
            biosOuvertes.insert(bio.id)
        }
    }

    /// L'interrupteur du bas (Store.setHilloulotAffichees).
    public func afficherSurLaCarteDuJour(_ oui: Bool) async throws {
        try await magasin.modifierReglages { $0.setHilloulotAffichees(oui) }
    }

    /// L'écran quitte le premier plan (onPause) : le jour qu'il est, pour `reprendre()`.
    public func suspendre() {
        quitteLe = horloge.aujourdhui
    }

    /// L'écran revient (onRestart). Laissé ouvert jusqu'au lendemain (bug du 02/11), il passe à aujourd'hui s'il
    /// montrait le jour d'alors ; un autre jour choisi exprès reste affiché.
    public func reprendre() {
        let aujourdhui = horloge.aujourdhui
        guard let avant = quitteLe else { return }
        if avant == aujourdhui || jour != avant { return }
        aller(aujourdhui)
    }

    /// Attend la fin de la recherche et des lectures de biographies lancées (les tests, les aperçus).
    public func attendre() async {
        while true {
            let recherche = tacheRecherche
            let bios = tacheBios
            if let recherche { await recherche.value }
            if let bios { await bios.value }
            if recherche == tacheRecherche && bios == tacheBios { return }
        }
    }

    // MARK: En arrière-plan

    private func aller(_ j: JourCivil) {
        jour = j
        chargerBios()
    }

    /// La recherche, hors du fil principal ; seule la dernière demandée s'affiche.
    private func lancerRecherche() {
        demande += 1
        let numero = demande
        tacheRecherche?.cancel()
        guard enRecherche, let table else { return }
        let texte = recherche
        tacheRecherche = Task {
            let liste = await Task.detached(priority: .userInitiated) {
                Hilloulot.recherche(table, texte: texte)
            }.value
            guard numero == self.demande else { return }
            self.trouvees = Trouvees(texte: texte, liste: liste)
            self.chargerBios()
        }
    }

    /// Les biographies des mois montrés (le jour, ou les dates des résultats), lues une fois chacun. Arrivées,
    /// elles complètent la table ; la recherche montrée se refait dessus, pour que ses tsadikim les aient.
    private func chargerBios() {
        guard etat == .pret else { return }
        let cles: [String]
        if enRecherche {
            guard let trouvees else { return }
            cles = trouvees.liste.prefix(HilloulotModele.resultatsMontres).map { $0.cle }
        } else {
            cles = Hilloulot.clesPour(jour, enIsrael: enIsrael, ashkenaz: ashkenaz)
        }
        let fichiers = Set(cles.map { Hilloulot.fichierDesBios($0) })
        guard !fichiers.isSubset(of: fichiersBios) else { return }
        let nouveaux = fichiers.subtracting(fichiersBios)
        fichiersBios.formUnion(fichiers)
        let contenus = self.contenus
        let precedente = tacheBios
        tacheBios = Task {
            if let precedente { await precedente.value }
            guard let complete = try? await contenus.avecBios(pour: cles) else {
                // Un fichier illisible : la prochaine demande de ces mois le relira (HilloulotContenus).
                self.fichiersBios.subtract(nouveaux)
                return
            }
            self.table = complete
            if self.enRecherche { self.lancerRecherche() }
        }
    }
}
