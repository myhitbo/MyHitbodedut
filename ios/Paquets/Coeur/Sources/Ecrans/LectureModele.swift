import Foundation
import Observation
import Coeur

// Le lecteur des textes (SiddurLectureActivity.kt) et son bouton de lecture (ReglagesLecture.kt) : un texte du
// siddour, ou un livre de la bibliothèque (LIVRE), en une liste paresseuse de lignes (LectureLignes) que la vue
// fait défiler. Les ajouts du jour (SiddurJour) dépendent de la date, de l'heure, du lieu et du nusah ; la
// taille, la nuit, la police, les langues, les favoris, les marque-pages et la reprise sont dans les réglages du
// `Magasin`, sous les clés d'Android.
//
// La vue dit au modèle ce qui est à l'écran (`visibles`) ; le modèle lui demande où aller (`defilement`). La
// ligne de tête (`ligneDeTete`) est celle que la reprise garde et que les changements de taille, de police ou de
// langues gardent en tête.
//
// Pas d'image ici (12/10) : on ne prie pas devant une image (Choul'han Aroukh, Ora'h 'Haïm 90, 23). Le modèle
// ne rend aucune illustration, seulement des icônes (marque-page, chevrons, barre de lecture).

/// Où en est le lecteur.
public enum LectureEtat: Sendable, Equatable {
    case chargement
    case pret
    /// Le texte n'existe pas (ou plus, dans ce nusah) : Android ferme l'écran (`finish()`), la vue revient en arrière.
    case introuvable
    /// Le contenu n'a pu être lu.
    case erreur
}

/// Une demande de défilement : aller à la ligne `ligne` (son id), en tête de l'écran. `jeton` change à chaque
/// demande, pour qu'une même ligne demandée deux fois se rejoigne deux fois.
public struct LectureDefilement: Sendable, Equatable {
    public let ligne: String
    /// Vrai : un défilement doux (le pied « Replier » qui ramène à son bandeau), sauf « Réduire les animations ».
    public let anime: Bool
    public let jeton: Int
}

/// Un signet de la bande : le titre d'une section.
public struct LectureSignet: Sendable, Equatable, Identifiable {
    /// Son rang dans la bande.
    public let id: Int
    /// Le titre hébreu, masqué pour la police.
    public let texte: String
    /// L'id de la ligne du titre.
    public let ligne: String
}

/// Le lecteur d'un texte du siddour ou d'un livre.
@MainActor
@Observable
public final class LectureModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    /// « fr », « en » ou « he ».
    public let langue: String
    /// Ce qu'on a ouvert (les extras d'Android).
    public let cible: LectureCible

    public private(set) var etat: LectureEtat = .chargement
    /// Les lignes du texte, dans l'ordre ; vide tant que rien n'est lu.
    public private(set) var lignes: [LectureLigne] = []

    private var texte: SiddurTexte? = nil
    /// Le siddour du nusah affiché (pour les renvois) ; nil pour un livre.
    private var siddur: Siddur? = nil
    /// Le nom du recueil : le nusah du siddour, « Livres » pour un livre.
    private var nomRecueil: TexteLocalise = .vide
    /// Le nusah du texte affiché (nil pour un livre) : un autre nusah n'a pas les mêmes paragraphes.
    private var nusahAffiche: Nusah? = nil
    private var annotations: [SiddurJour.Annotation] = []
    /// Les ajouts repliés que l'on a ouverts, pour ce texte.
    private var ouverts: Set<String> = []
    /// L'id de chaque ligne, vers son rang.
    private var rangs: [String: Int] = [:]
    /// Les rangs des titres de section : un signet chacun.
    private var debuts: [Int] = []

    // MARK: Ce qui est à l'écran

    /// Le rang de la première ligne visible ; nil tant que rien n'est montré.
    public private(set) var premiere: Int? = nil
    private var derniere = 0
    private var enBas = false
    /// Le signet touché : il reste marqué tant que le doigt ne reprend pas la page.
    private var choisi: Int? = nil
    /// La dernière demande de défilement ; la vue la suit (`onChange`).
    public private(set) var defilement: LectureDefilement? = nil
    private var jeton = 0
    /// Quand la lecture a été quittée (onPause), pour `revenir()`.
    private var pauseA: Int64 = 0
    /// Le texte a été lu une fois (onCreate) : `.task` revient à chaque apparition de la vue (au retour d'un
    /// renvoi), où Android ne fait que onRestart (`revenir()`), sans relire ni retourner au marque-page.
    @ObservationIgnored private var lance = false

    // MARK: Le bouton de lecture et les messages

    /// Déplié : la barre (A−, %, A+, lune, police, langues, nusah, masquer, replier) ; sinon la pastille « Aa ».
    public private(set) var barreDepliee = false
    /// La pastille effacée en descendant dans le texte ; elle revient en remontant ou d'un toucher.
    public private(set) var pastilleEffacee = false
    private var parcouru: Double = 0
    /// Un message bref (le Toast d'Android) : « Marque-page posé », « Marque-page retiré ». La vue l'efface.
    public private(set) var message: Libelle? = nil
    /// La barre du bas qui suit le masquage (Snackbar) : `lecture_masque_info`, action `lecture_annuler_masque`.
    public private(set) var annonceMasque = false
    /// La feuille des marque-pages de ce texte est ouverte (le bouton du bandeau).
    public var feuilleMarques = false

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String, cible: LectureCible) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = ChizukCard.language(langue)
        self.cible = cible
    }

    // MARK: Le chargement

    /// Lit le texte et se place : au marque-page reçu, sinon à la place gardée (Store.positionLecture). À appeler
    /// à l'apparition de l'écran ; une seule fois (onCreate) : les appels suivants ne font rien.
    public func charger() async {
        guard !lance else { return }
        lance = true
        await lire(nusah: magasin.reglages.siddurNusah)
        guard etat == .pret else { return }
        if let marque = cible.marque {
            allerA(marque)
        } else if let position = LecturePreferences.positionLecture(magasin.reglages, cle: cle,
                                                                       maintenant: horloge.maintenant),
                  position < lignes.count {
            demander(lignes[position].id, anime: false)
        }
    }

    /// Lit le recueil et le texte, puis fait les lignes. Un nusah où le texte manque : `introuvable`.
    private func lire(nusah: Nusah) async {
        do {
            if cible.livre {
                let livre = try await contenus.livre(cible.id)
                nomRecueil = (try? await contenus.livres().nusah) ?? .vide
                texte = livre
                siddur = nil
                nusahAffiche = nil
                annotations = []
            } else {
                let lu = try await contenus.siddur(nusah)
                guard let trouve = lu.texte(cible.id) else {
                    etat = .introuvable
                    return
                }
                let toutes = try await contenus.annotations(nusah)
                texte = trouve
                siddur = lu
                nomRecueil = lu.nusah
                nusahAffiche = nusah
                annotations = toutes[cible.id] ?? []
            }
            etat = .pret
            reconstruire()
        } catch let erreur as ErreurContenu {
            if case .absent = erreur {
                etat = .introuvable
            } else {
                etat = .erreur
            }
        } catch {
            etat = .erreur
        }
    }

    /// La clé des favoris et de la reprise : « s:<id> » ou « l:<id> ».
    public var cle: String {
        cible.cle
    }

    /// Le nusah des marque-pages : celui du siddour affiché ; aucun pour un livre.
    private var nusahMarques: String {
        cible.livre ? "" : magasin.reglages.siddurNusah.rawValue
    }

    // MARK: Le jour

    /// Israël ou diaspora : le réglage, sinon ce que dit le fuseau du téléphone.
    private var enIsrael: Bool {
        magasin.reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// Le jour hébreu dont relève cette prière maintenant : Arvit, l'après-midi, est déjà celui de demain ; après
    /// la sortie des étoiles du lieu, les autres textes relèvent aussi de demain (28/10).
    public var jourDeLaPriere: CalendrierJuif.Jour {
        let reglages = magasin.reglages
        let aujourdhui = horloge.aujourdhui
        var apresSortie = false
        if let lieu = reglages.lieuZmanim,
           let sortie = Zmanim.jour(lieu: lieu, date: aujourdhui).first(where: { $0.cle == "tset" })?.instant {
            apresSortie = horloge.maintenant >= Int64((sortie.timeIntervalSince1970 * 1000).rounded(.down))
        }
        let date = CalendrierJuif.jourDeLaPriere(cible.id, date: aujourdhui, heure: horloge.dateHeure.heure,
                                                 apresSortie: apresSortie)
        return CalendrierJuif.jour(date, enIsrael: enIsrael, mukafChoma: reglages.mukafChoma)
    }

    /// Refait les lignes d'après le texte lu, le jour, les replis ouverts, les marque-pages et les réglages.
    private func reconstruire() {
        guard let texte else { return }
        let reglages = magasin.reglages
        let modeLangues = langues
        var notes: [(id: String, libelle: Libelle)] = []
        // Un livre sans traduction, quand on en a demandé une (04/11) : on le dit, l'hébreu reste.
        let traduit = texte.sections.contains { s in s.blocs.contains { $0.fr != nil || $0.en != nil } }
        if cible.livre && LanguesTexte.manque(modeLangues, aTraduction: traduit) {
            notes.append((id: "traduction", libelle: Libelle("lecture_sans_traduction")))
        }
        let jourLignes: [SiddurJour.Ligne]
        if cible.livre {
            jourLignes = SiddurJour.lignes(texte, [], [], nusah: reglages.siddurNusah)
        } else {
            let israel = enIsrael
            let jour = jourDeLaPriere
            if !annotations.isEmpty {
                notes.append((id: "jour", libelle: Libelle("siddur_jour_ajouts", .texte(jour.dateHebraique),
                                                           .libelle(Libelle(israel ? "region_israel" : "region_diaspora")))))
            }
            jourLignes = SiddurJour.lignes(texte, annotations, jour.conditions, ouverts: ouverts,
                                           nusah: reglages.siddurNusah, enIsrael: israel,
                                           sansTahanounFinTichri: reglages.sansTahanounFinTichri,
                                           sud: reglages.hemisphereSud)
        }
        var marquees = Set<LecturePlace>()
        for m in marquesDuTexte {
            marquees.insert(LecturePlace(section: m.section, bloc: m.bloc))
        }
        let recueil = siddur
        let police = self.police
        let nouvelles = LectureLignes.lignes(texte: texte, annotations: annotations, jour: jourLignes, notes: notes,
                                             marques: marquees, langues: modeLangues, police: police,
                                             titreDe: { id in recueil?.texte(id)?.titre.he })
        lignes = nouvelles
        var index: [String: Int] = [:]
        var titres: [Int] = []
        for ligne in nouvelles {
            index[ligne.id] = ligne.position
            if case .titre = ligne.contenu { titres.append(ligne.position) }
        }
        rangs = index
        debuts = titres
    }

    // MARK: Le bandeau

    /// Le titre hébreu du texte, dans la police choisie (masqué pour elle).
    public var titre: String {
        PoliceHebraique.masque(texte?.titre.he ?? "", police: police)
    }

    /// Les étiquettes sous le titre (16/10) : le nom traduit s'il diffère de l'hébreu, puis le nusah d'où vient le
    /// texte (celui de l'emprunt, ou du siddour ; « Livres » pour un livre).
    public var etiquettes: [String] {
        guard let texte else { return [] }
        var sortie: [String] = []
        let traduit = texte.titre.pour(langue)
        if !traduit.egalUnites(texte.titre.he) { sortie.append(traduit) }
        let nusah = (texte.emprunt ?? nomRecueil).pour(langue)
        if !nusah.estBlanc { sortie.append(nusah) }
        return sortie
    }

    /// Les étiquettes en une phrase, pour la lecture d'écran (les pastilles, elles, ne se lisent pas).
    public var etiquettesDescription: String {
        etiquettes.joined(separator: ", ")
    }

    /// L'horaire du jour de la prière (HorairePriere, 16/10) : Cha'harit, Min'ha, Arvit, avec un lieu choisi ;
    /// nil sinon (et toujours pour un livre). La vue le précède de « ◷ ».
    public var horaire: Libelle? {
        if cible.livre { return nil }
        let id = cible.id
        guard id == "chaharit" || id == "minha" || id == "arvit", let lieu = magasin.reglages.lieuZmanim else { return nil }
        let fuseau = Fuseau(lieu.fuseau) ?? horloge.fuseau
        guard let zone = TimeZone(identifier: fuseau.identifiant) else { return nil }
        let date = fuseau.jour(millis: horloge.maintenant)
        guard let heures = HorairePriere.heures(id, zmanim: Zmanim.jour(lieu: lieu, date: date), fuseau: zone) else {
            return nil
        }
        switch id {
        case "chaharit": return Libelle("banniere_chaharit", .texte(heures[0]))
        case "minha": return heures.count > 1 ? Libelle("banniere_minha", .texte(heures[0]), .texte(heures[1])) : nil
        default: return Libelle("banniere_arvit", .texte(heures[0]))
        }
    }

    /// L'icône des marque-pages : ruban en contour pour une prière, livre ouvert et ruban pour une étude.
    public var iconeMarques: String {
        LectureModele.icone(etude: cible.livre)
    }

    /// `SiddurLectureActivity.icone` : le nom de l'image.
    public static func icone(etude: Bool) -> String {
        etude ? "ic_marque_etude" : "ic_marque_priere"
    }

    // MARK: Le favori

    /// Le texte est dans les favoris de la Bibliothèque.
    public var estFavori: Bool {
        LecturePreferences.favoris(magasin.reglages).contains { $0.egalUnites(cle) }
    }

    /// « ★ » ou « ☆ ».
    public var symboleFavori: String {
        estFavori ? "\u{2605}" : "\u{2606}"
    }

    /// Ce que fait le toucher, pour la lecture d'écran.
    public var descriptionFavori: Libelle {
        Libelle(estFavori ? "favori_retirer" : "favori_ajouter")
    }

    public func basculerFavori() async throws {
        let cle = self.cle
        try await magasin.modifierReglages { LecturePreferences.basculerFavori(&$0, cle) }
    }

    // MARK: Les marque-pages

    /// Les marque-pages de ce texte (et de ce nusah), dans l'ordre du texte.
    public var marquesDuTexte: [MarquesPages.Marque] {
        MarquesPages.duTexte(LecturePreferences.marques(magasin.reglages), cle: cle, nusah: nusahMarques)
    }

    /// Un appui long sur un paragraphe : le marque, ou le démarque ; le message le dit.
    public func basculerMarque(_ bloc: LectureBloc) async throws {
        let place = bloc.place
        // L'aperçu du paragraphe tel qu'il est dans le texte (une variante retirée aujourd'hui y reste).
        let original = texte.flatMap { t -> SiddurBloc? in
            guard place.section < t.sections.count, place.bloc < t.sections[place.section].blocs.count else { return nil }
            return t.sections[place.section].blocs[place.bloc]
        } ?? bloc.bloc
        let marque = MarquesPages.Marque(cle: cle, nusah: nusahMarques, section: place.section, bloc: place.bloc,
                                         apercu: MarquesPages.apercu(original.texte))
        defer {
            // Ce qui est en mémoire fait foi, même si l'écriture a échoué.
            let posee = marquesDuTexte.contains { $0.memePlace(marque) }
            message = Libelle(posee ? "marque_posee" : "marque_retiree")
            reconstruire()
        }
        try await magasin.modifierReglages { LecturePreferences.basculerMarque(&$0, marque) }
    }

    /// Va au paragraphe d'un marque-page ; replié aujourd'hui, au premier paragraphe montré de sa section ou après.
    public func allerA(_ place: LecturePlace) {
        var trouvee: LectureLigne?
        var repli: LectureLigne?
        for ligne in lignes {
            guard case .bloc(let bloc) = ligne.contenu else { continue }
            if bloc.place == place {
                trouvee = ligne
                break
            }
            if repli == nil && bloc.place.section >= place.section { repli = ligne }
        }
        guard let destination = trouvee ?? repli else { return }
        choisi = nil
        demander(destination.id, anime: false)
    }

    public func allerALaMarque(_ m: MarquesPages.Marque) {
        feuilleMarques = false
        allerA(LecturePlace(section: m.section, bloc: m.bloc))
    }

    public func effacerMessage() {
        message = nil
    }

    // MARK: Les ajouts repliés

    /// Un toucher sur le bandeau d'un ajout : il s'ouvre ou se referme (le chevron tourne d'abord, dans la vue).
    public func basculer(_ cle: String) {
        if ouverts.contains(cle) {
            ouverts.remove(cle)
        } else {
            ouverts.insert(cle)
        }
        reconstruire()
    }

    /// Le pied « Replier » : l'ajout se referme, et l'on revient à son bandeau s'il est passé au-dessus de l'écran.
    public func replierDepuisLePied(_ cle: String) {
        basculer(cle)
        guard let rang = rangs["replie:" + cle], let haut = premiere, rang < haut else { return }
        demander("replie:" + cle, anime: true)
    }

    // MARK: Le défilement et les signets

    /// Ce que la vue montre : les ids des lignes visibles, et si la liste ne peut plus descendre.
    public func visibles(_ ids: [String], enBas: Bool) {
        let vus = ids.compactMap { rangs[$0] }
        guard let haut = vus.min(), let bas = vus.max() else { return }
        premiere = haut
        derniere = bas
        self.enBas = enBas
    }

    /// Le doigt reprend la page : le signet touché ne s'impose plus.
    public func debutGlisse() {
        choisi = nil
    }

    /// La ligne en tête de l'écran : celle que la reprise garde.
    public var ligneDeTete: LectureLigne? {
        guard let premiere, premiere < lignes.count else { return nil }
        return lignes[premiere]
    }

    /// La bande de signets : une section titrée par signet ; absente d'un texte d'une seule section.
    public var signets: [LectureSignet] {
        guard debuts.count > 1 else { return [] }
        var sortie: [LectureSignet] = []
        for (i, rang) in debuts.enumerated() {
            guard case .titre(let t) = lignes[rang].contenu else { continue }
            sortie.append(LectureSignet(id: i, texte: t.hebreu, ligne: lignes[rang].id))
        }
        return sortie
    }

    /// Le signet de la section qu'on lit (SignetsSiddur.courant), ou celui qu'on vient de toucher ; nil sans bande.
    public var signetActif: Int? {
        guard debuts.count > 1 else { return nil }
        if let choisi { return choisi }
        guard let premiere else { return 0 }
        return SignetsSiddur.courant(debuts, premiere: premiere, derniere: derniere, enBas: enBas)
    }

    /// Un toucher sur un signet : sa section en tête, et il reste marqué.
    public func allerAuSignet(_ i: Int) {
        guard i >= 0, i < debuts.count else { return }
        choisi = i
        demander(lignes[debuts[i]].id, anime: false)
    }

    private func demander(_ id: String, anime: Bool) {
        jeton += 1
        defilement = LectureDefilement(ligne: id, anime: anime, jeton: jeton)
        // La ligne demandée est en tête, jusqu'à ce que la vue dise ce qu'elle montre.
        if let rang = rangs[id] { premiere = rang }
    }

    /// Refait les lignes en gardant en tête la même ligne (le même paragraphe), si elle existe encore.
    private func reconstruireEnGardantLaPlace() {
        let tete = ligneDeTete?.id
        reconstruire()
        if let tete, rangs[tete] != nil { demander(tete, anime: false) }
    }

    // MARK: Quitter, revenir

    /// L'écran passe en arrière (onPause) : la place est gardée, avec l'instant.
    public func quitter() async throws {
        let maintenant = horloge.maintenant
        pauseA = maintenant
        // Rien encore de signalé par la vue : la première ligne (findFirstVisibleItemPosition, 0 en haut), qui
        // fait au moins de ce texte la dernière lecture.
        guard etat == .pret, !lignes.isEmpty else { return }
        let position = premiere ?? 0
        let cle = self.cle
        try await magasin.modifierReglages {
            LecturePreferences.setPositionLecture(&$0, cle: cle, position: position, maintenant: maintenant)
        }
    }

    /// L'écran revient au premier plan (onRestart). Resté ouvert jusqu'au lendemain derrière d'autres
    /// applications (bug du 02/11), une prière se redessine pour le jour, depuis le début, comme rouverte.
    public func revenir() {
        if pauseA == 0 || LecturePreferences.repriseValable(cle, quand: pauseA, maintenant: horloge.maintenant) { return }
        guard etat == .pret else { return }
        reconstruire()
        if let premiereLigne = lignes.first { demander(premiereLigne.id, anime: false) }
    }

    // MARK: Les réglages de lecture (ReglagesLecture)

    /// La taille des lettres (0,8 à 2) : elle multiplie celles des lignes.
    public var echelle: Float {
        magasin.reglages.lectureEchelle
    }

    /// La lecture de nuit : fond noir, texte clair, titres dorés (lecture_nuit_*) ; sinon papier, encre, marque.
    public var sombre: Bool {
        magasin.reglages.lectureSombre
    }

    /// La police hébraïque choisie.
    public var police: PoliceHebraique.Police {
        LecturePreferences.police(magasin.reglages)
    }

    /// Les langues de lecture : le choix enregistré, sinon celles de la langue de l'app.
    public var langues: LanguesTexte.Mode {
        LecturePreferences.mode(magasin.reglages, langue: langue)
    }

    /// Le bouton entier masqué : plus rien à l'écran ; deux touchers sur le texte le font revenir.
    public var masquee: Bool {
        magasin.reglages.lectureMasquee
    }

    /// La pastille « Aa » se montre : ni masquée, ni dépliée en barre.
    public var pastilleVisible: Bool {
        !masquee && !barreDepliee
    }

    /// La barre se montre.
    public var barreVisible: Bool {
        !masquee && barreDepliee
    }

    /// La taille en pour cent, arrondie.
    public var pourcent: Int {
        Kotlin.arrondiFlottant(echelle * 100)
    }

    /// « 120 % » sur la barre.
    public var libellePourcent: Libelle {
        Libelle("lecture_pourcent", .entier(pourcent))
    }

    /// « Taille du texte : 120 % », pour la lecture d'écran.
    public var descriptionPourcent: Libelle {
        Libelle("lecture_taille", .entier(pourcent))
    }

    /// L'état de la lune, pour la lecture d'écran : « activée » ou « désactivée ».
    public var etatNuit: Libelle {
        Libelle(sombre ? "lecture_nuit_oui" : "lecture_nuit_non")
    }

    /// Le choix du nusah dans la barre : au siddour seulement.
    public var avecNusah: Bool {
        !cible.livre
    }

    public var optionsPolice: [LectureOption<PoliceHebraique.Police>] {
        let actuelle = police
        return PoliceHebraique.Police.allCases.map {
            LectureOption(valeur: $0, nom: Libelle($0.libelle), choisi: $0 == actuelle)
        }
    }

    public var optionsLangues: [LectureOption<LanguesTexte.Mode>] {
        let actuel = langues
        return LanguesTexte.Mode.allCases.map {
            LectureOption(valeur: $0, nom: Libelle($0.libelle), choisi: $0 == actuel)
        }
    }

    /// Les trois nusah ; vide pour un livre.
    public var optionsNusah: [LectureOption<Nusah>] {
        guard avecNusah else { return [] }
        let actuel = magasin.reglages.siddurNusah
        return Nusah.allCases.map {
            LectureOption(valeur: $0, nom: Libelle("siddur_nusah_" + $0.rawValue), choisi: $0 == actuel)
        }
    }

    /// Le pas de A− et A+ (PAS), et les bornes (MIN, MAX).
    public static let pas: Float = 0.1

    /// A+ ou A− : dix pour cent de plus ou de moins, au dixième près, entre 80 et 200 %.
    public func changerTaille(plus: Bool) async throws {
        try await regler(taille: echelle + (plus ? LectureModele.pas : -LectureModele.pas))
    }

    /// Un toucher sur le pourcentage : 100 %.
    public func tailleNormale() async throws {
        try await regler(taille: 1)
    }

    private func regler(taille voulue: Float) async throws {
        // Au dixième près : dix touchers de +10 % ne doivent pas donner 199,99 %.
        let arrondie = Float(Kotlin.arrondiFlottant(voulue * 10)) / 10
        let nouvelle = min(max(arrondie, Reglages.echelleMin), Reglages.echelleMax)
        if nouvelle == echelle { return }
        let tete = ligneDeTete?.id
        defer {
            // Les lettres changent de taille : le même paragraphe reste en tête.
            if let tete, rangs[tete] != nil { demander(tete, anime: false) }
        }
        try await magasin.modifierReglages { $0.setLectureEchelle(nouvelle) }
    }

    /// La lune : la lecture de nuit, ou de jour ; la place reste.
    public func basculerNuit() async throws {
        let nuit = !sombre
        let tete = ligneDeTete?.id
        defer {
            if let tete, rangs[tete] != nil { demander(tete, anime: false) }
        }
        try await magasin.modifierReglages { $0.setLectureSombre(nuit) }
    }

    public func choisirPolice(_ p: PoliceHebraique.Police) async throws {
        defer { reconstruireEnGardantLaPlace() }
        try await magasin.modifierReglages { $0.setLecturePolice(p.cle) }
    }

    /// Les langues du texte : le texte se refait, à la même place.
    public func choisirLangues(_ mode: LanguesTexte.Mode) async throws {
        defer { reconstruireEnGardantLaPlace() }
        try await magasin.modifierReglages { $0.setLectureLangues(mode.cle) }
    }

    /// Le nusah, depuis la barre : le même garde sa place ; un autre n'a pas les mêmes paragraphes, on repart du
    /// début (et si le texte lui manque, l'écran se ferme).
    public func choisirNusah(_ nusah: Nusah) async throws {
        guard avecNusah else { return }
        do {
            try await magasin.modifierReglages { $0.setSiddurNusah(nusah) }
        } catch {
            await changerDeNusah(nusah)
            throw error
        }
        await changerDeNusah(nusah)
    }

    private func changerDeNusah(_ nusah: Nusah) async {
        if nusah == nusahAffiche {
            reconstruireEnGardantLaPlace()
            return
        }
        await lire(nusah: nusah)
        if etat == .pret, let premiereLigne = lignes.first { demander(premiereLigne.id, anime: false) }
    }

    /// La pastille touchée : la barre se déplie ; « Replier » la replie.
    public func deplierBarre(_ ouverte: Bool) {
        barreDepliee = ouverte
        pastilleEffacee = false
        parcouru = 0
    }

    /// « Masquer » : plus rien à l'écran ; la barre du bas dit comment le retrouver.
    public func masquer() async throws {
        barreDepliee = false
        annonceMasque = true
        try await magasin.modifierReglages { $0.setLectureMasquee(true) }
    }

    /// La barre du bas s'est effacée.
    public func finAnnonceMasque() {
        annonceMasque = false
    }

    /// Le bouton revient, déplié : deux touchers sur le texte, « Annuler » de la barre du bas, ou l'action
    /// d'accessibilité « Réglages de lecture » de la liste.
    public func retrouver() async throws {
        annonceMasque = false
        guard masquee else { return }
        deplierBarre(true)
        try await magasin.modifierReglages { $0.setLectureMasquee(false) }
    }

    /// Un toucher sur le texte : la pastille effacée par le défilement revient.
    public func toucherTexte() {
        if !masquee { montrerPastille(true) }
    }

    /// Le texte a défilé de `delta` points (positif : vers la fin) : 24 points dans un sens effacent ou rendent
    /// la pastille, même lentement.
    public func defilementVertical(_ delta: Double) {
        parcouru = (parcouru > 0) == (delta > 0) ? parcouru + delta : delta
        if parcouru > LectureModele.seuilPastille {
            montrerPastille(false)
            parcouru = 0
        } else if parcouru < -LectureModele.seuilPastille {
            montrerPastille(true)
            parcouru = 0
        }
    }

    /// Le chemin qui efface ou rend la pastille, en points.
    public static let seuilPastille: Double = 24

    private func montrerPastille(_ visible: Bool) {
        if barreDepliee || masquee { return }
        pastilleEffacee = !visible
    }
}
