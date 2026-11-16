import Foundation
import Observation
import Coeur

// Le bouton de lecture (ReglagesLecture.kt) de la lecture des Tehilim (TehilimLectureActivity.kt) et du Tikoun
// (TikkunFlowActivity.kt) : la pastille « Aa », et dépliée, la barre A−, %, A+, lune, police (« אב »), langues
// (« אA »), masquer, replier. Ni nusah ici (`avecNusah` faux sur Android). Les réglages valent pour tous les
// écrans de lecture : ils vivent dans le `Magasin`, sous les clés d'Android (Reglages.lecture…).
//
// Le lecteur du siddour a les mêmes règles dans LectureModele.swift ; celles-ci en sont une copie pour ne
// dépendre que des fondations et de Coeur. Les deux s'écrivent dans les mêmes clés : un choix fait dans l'un se
// voit dans l'autre.

/// Un choix d'une liste de la barre (la police, les langues) : son nom et s'il est coché.
public struct TehilimOption<Valeur: Sendable & Hashable>: Sendable, Hashable, Identifiable {
    public let valeur: Valeur
    public let nom: Libelle
    public let choisi: Bool

    public var id: Valeur { valeur }
}

/// La pastille et la barre de lecture, avec leurs réglages.
@MainActor
@Observable
public final class TehilimBarreLecture {
    private let magasin: Magasin
    /// « fr », « en » ou « he » : la langue de l'app, qui donne les langues de lecture par défaut.
    public let langue: String

    /// Déplié : la barre ; sinon la pastille « Aa ».
    public private(set) var barreDepliee = false
    /// La pastille effacée en descendant dans le texte ; elle revient en remontant ou d'un toucher.
    public private(set) var pastilleEffacee = false
    /// La barre du bas qui suit le masquage (Snackbar) : `lecture_masque_info`, action `lecture_annuler_masque`.
    public private(set) var annonceMasque = false
    @ObservationIgnored private var parcouru: Double = 0
    /// Ce que l'écran fait quand la taille, la nuit, la police ou les langues changent : garder sa place
    /// (`surChangement` d'Android). Posé par le modèle de l'écran.
    @ObservationIgnored var surChangement: (@MainActor () -> Void)? = nil

    public init(magasin: Magasin, langue: String) {
        self.magasin = magasin
        self.langue = ChizukCard.language(langue)
    }

    // MARK: Les réglages

    /// La taille des lettres (0,8 à 2) : elle multiplie les tailles de base du texte.
    public var echelle: Float {
        magasin.reglages.lectureEchelle
    }

    /// La lecture de nuit : fond `lecture_nuit_fond` (#000000), texte `lecture_nuit_texte` (#F2F0EA), discret
    /// `lecture_nuit_discret` (#A3A8A5), titres `lecture_nuit_titre` (#D6C28C) ; sinon papier, encre, muted, marque.
    public var sombre: Bool {
        magasin.reglages.lectureSombre
    }

    /// La police hébraïque choisie (« serif » par défaut).
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    /// Les langues de lecture : le choix enregistré, sinon celles de la langue de l'app (LanguesTexte.mode).
    public var langues: LanguesTexte.Mode {
        if let cle = magasin.reglages.lectureLangues, let mode = LanguesTexte.Mode(rawValue: cle) { return mode }
        return LanguesTexte.defaut(langue)
    }

    /// Le bouton entier masqué : plus rien à l'écran ; deux touchers sur le texte le font revenir.
    public var masquee: Bool {
        magasin.reglages.lectureMasquee
    }

    /// La pastille « Aa » se montre : ni masquée, ni dépliée en barre (son effacement au défilement à part :
    /// `pastilleEffacee`, une animation d'opacité et de 24 points vers le bas, 180 ms).
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

    /// Les sept polices, la choisie cochée (le menu de « אב »).
    public var optionsPolice: [TehilimOption<PoliceHebraique.Police>] {
        let actuelle = police
        return PoliceHebraique.Police.allCases.map {
            TehilimOption(valeur: $0, nom: Libelle($0.libelle), choisi: $0 == actuelle)
        }
    }

    /// Les six façons de lire, la choisie cochée (le menu de « אA »).
    public var optionsLangues: [TehilimOption<LanguesTexte.Mode>] {
        let actuel = langues
        return LanguesTexte.Mode.allCases.map {
            TehilimOption(valeur: $0, nom: Libelle($0.libelle), choisi: $0 == actuel)
        }
    }

    // MARK: Les actions

    /// Le pas de A− et A+ (PAS).
    public static let pas: Float = 0.1
    /// Le chemin qui efface ou rend la pastille, en points.
    public static let seuilPastille: Double = 24

    /// A+ ou A− : dix pour cent de plus ou de moins, au dixième près, entre 80 et 200 %.
    public func changerTaille(plus: Bool) async throws {
        try await regler(taille: echelle + (plus ? TehilimBarreLecture.pas : -TehilimBarreLecture.pas))
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
        defer { surChangement?() }
        try await magasin.modifierReglages { $0.setLectureEchelle(nouvelle) }
    }

    /// La lune : la lecture de nuit, ou de jour.
    public func basculerNuit() async throws {
        let nuit = !sombre
        defer { surChangement?() }
        try await magasin.modifierReglages { $0.setLectureSombre(nuit) }
    }

    /// Une police du menu « אב ».
    public func choisirPolice(_ p: PoliceHebraique.Police) async throws {
        defer { surChangement?() }
        try await magasin.modifierReglages { $0.setLecturePolice(p.cle) }
    }

    /// Les langues du texte (menu « אA ») : le texte se refait, à la même place (Android recrée l'écran).
    public func choisirLangues(_ mode: LanguesTexte.Mode) async throws {
        defer { surChangement?() }
        try await magasin.modifierReglages { $0.setLectureLangues(mode.cle) }
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
    /// d'accessibilité « Réglages de lecture » (`lecture_reglages`) du texte.
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
        if parcouru > TehilimBarreLecture.seuilPastille {
            montrerPastille(false)
            parcouru = 0
        } else if parcouru < -TehilimBarreLecture.seuilPastille {
            montrerPastille(true)
            parcouru = 0
        }
    }

    private func montrerPastille(_ visible: Bool) {
        if barreDepliee || masquee { return }
        pastilleEffacee = !visible
    }
}
