import Foundation
import Observation
import Coeur

// Le Tikoun HaKlali (TikkunFlowActivity.kt, activity_tikkun_flow.xml), le seul écran du Tikoun : le texte entier,
// d'un trait. La source le dit : « להמשיך מזה לזה ברצף אחד, ללא הפסק » ; aucun bouton entre les psaumes, rien à
// toucher : on fait défiler et on continue. L'ouverture, les dix psaumes à la suite, les versets de clôture ; puis
// ce qui se dit après le Tikoun sans en faire partie : la kavana du milouy et la prière de Rabbi Natan, chacune
// avec sa note. En bas, « J'ai dit le Tikoun en entier » : les dix psaumes comptent pour le jour du Tikoun, le jour
// entre au journal du Tikoun (ses trophées), et l'écran se ferme.
//
// Le journal du Tikoun vit dans les réglages, sous les clés d'Android (tikkun_day, tikkun_done, tikkun_journal),
// par les règles de Store.swift de Coeur (`jourTikkun`, `tikkunDone`, `setTikkunDone`, `tikkunJournal`).
//
// Pas d'image pendant une prière (13/10) ; pas de sous-titre en tête (12/10) : le texte dit lui-même où s'arrêter.

/// Un texte de titre : de l'hébreu tel quel (le titre d'une partie), ou une chaîne de l'interface (« תהילים ט״ז »).
public enum TikkunTexte: Sendable, Hashable {
    case hebreu(String)
    case libelle(Libelle)
}

/// Un élément de la page du Tikoun, dans l'ordre de lecture.
public struct TikkunElement: Sendable, Equatable, Identifiable {

    public enum Sorte: Sendable, Equatable {
        /// Le nom d'une partie ou d'un psaume : 20 pt, gras, couleur des titres (marque ; doré la nuit), de droite à
        /// gauche, police hébraïque ; 24 pt au-dessus (rien pour le premier), 4 pt dessous.
        case titre(TikkunTexte, premier: Bool)
        /// Un verset en hébreu : 19 pt, interligne + 13 pt, encre, de droite à gauche, police hébraïque.
        case verset(String)
        /// L'indication d'un arrêt dans le verset (« כאן צריך להפסיק מעט… ») : 15 pt, interligne + 4 pt, discret, de
        /// droite à gauche, police hébraïque.
        case arret(String)
        /// Un paragraphe d'une partie liturgique : 18 pt, interligne + 13 pt, encre, de droite à gauche, police
        /// hébraïque ; centré pour la formule de la kavana (un tableau de lettres, pas une phrase).
        case paragraphe(String, centre: Bool)
        /// La note d'une partie (« נאמרת אחרי התיקון… »), dans la langue de l'app : 14 pt, discret, alignée au début
        /// de la ligne, sous son titre (2 pt au-dessus).
        case note(String)
        /// Une traduction (« fr », « en ») : de gauche à droite, police à empattements du système, interligne + 4 pt.
        /// Seule (sans l'hébreu) : `base − 1` pt, encre ; sous l'hébreu : `base − 3` pt, discret. `margeHaut` : 4 pt
        /// sous l'hébreu ou une autre traduction, 12 pt sinon.
        case traduction(String, langue: String, seule: Bool, base: Int, margeHaut: Int)
    }

    /// Unique dans la page, stable d'un réglage à l'autre : « ouverture:titre », « psaume16:3 », « psaume32:6:arret »,
    /// « psaume32:6:suite », « psaume16:3:fr », « kavana:formule »…
    public let id: String
    public let sorte: Sorte
}

/// Le Tikoun HaKlali, d'un trait.
@MainActor
@Observable
public final class TikkunModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    /// « fr », « en » ou « he ».
    public let langue: String
    /// Le bouton de lecture : taille des lettres, lecture de nuit, police, langues.
    public let barre: TehilimBarreLecture

    public private(set) var etat: TehilimEtat = .chargement
    private var tikkun: Tikkun? = nil
    /// « J'ai dit le Tikoun en entier » touché : l'écran se ferme (`finish()`).
    public private(set) var termine = false

    /// La dernière demande de défilement (garder sa place quand la taille ou les langues changent).
    public private(set) var defilement: TehilimDefilement? = nil
    private var jeton = 0
    @ObservationIgnored private var tete: String? = nil

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = ChizukCard.language(langue)
        barre = TehilimBarreLecture(magasin: magasin, langue: langue)
        barre.surChangement = { [weak self] in
            self?.garderPlace()
        }
    }

    /// Lit le Tikoun. À appeler à l'apparition de l'écran.
    public func charger() async {
        do {
            tikkun = try await contenus.tikkun()
            etat = .pret
        } catch {
            etat = .erreur
        }
    }

    // MARK: Le bandeau et le bouton

    /// « Tikoun HaKlali », dans la langue de l'app.
    public var titre: Libelle {
        Libelle("tikkun_title")
    }

    /// « J'ai dit le Tikoun en entier ».
    public var libelleFin: Libelle {
        Libelle("tikkun_flow_done")
    }

    /// Le bouton du bas se touche une fois le texte lu.
    public var finPossible: Bool {
        etat == .pret && !termine
    }

    /// Les psaumes dits ce jour du Tikoun (le jour bascule à 4 h).
    public var psaumesDits: Set<Int> {
        Store.tikkunDone(reglages: magasin.reglages, maintenant: horloge.dateHeure)
    }

    /// Les jours où le Tikoun a été dit en entier : ce que regardent ses trophées (Trophees.Pratique.tikkun).
    public var joursDits: Set<JourCivil> {
        Store.tikkunJournal(reglages: magasin.reglages)
    }

    /// « J'ai dit le Tikoun en entier » : tout dire d'un trait vaut les dix psaumes ; le jour entre au journal du
    /// Tikoun, et l'écran se ferme. Si l'écriture échoue, le changement reste en mémoire (le `Magasin` l'écrira à
    /// la suivante), l'écran se ferme quand même et l'erreur remonte.
    public func direEnEntier() async throws {
        guard let tikkun, !termine else { return }
        var numeros: [Int] = []
        for psaume in tikkun.psaumes {
            numeros.append(psaume.numero)
        }
        let maintenant = horloge.dateHeure
        defer { termine = true }
        try await magasin.modifierReglages { reglages in
            for numero in numeros {
                Store.setTikkunDone(reglages: &reglages, numero: numero, done: true, maintenant: maintenant)
            }
        }
    }

    // MARK: Le texte

    /// La page entière, dans l'ordre ; vide tant que rien n'est lu.
    public var elements: [TikkunElement] {
        guard let tikkun else { return [] }
        let mode = barre.langues
        let police = barre.police
        var liste: [TikkunElement] = []
        var premier = true

        for bloc in tikkun.avant {
            liste.append(TikkunElement(id: bloc.cle + ":titre",
                                       sorte: .titre(.hebreu(PoliceHebraique.masque(bloc.titre.he, police: police)),
                                                     premier: premier)))
            premier = false
            TikkunModele.paragraphes(bloc, mode: mode, police: police, dans: &liste)
        }

        for psaume in tikkun.psaumes {
            let base = "psaume" + String(psaume.numero)
            liste.append(TikkunElement(id: base + ":titre",
                                       sorte: .titre(.libelle(Libelle("tikkun_psalm_he",
                                                                      .texte(Reference.lettres(psaume.numero)))),
                                                     premier: premier)))
            premier = false
            for (rang, verset) in psaume.versets.enumerated() {
                let id = base + ":" + String(rang)
                // Les langues choisies (04/11) : l'hébreu, la traduction, ou les deux.
                let textes = LanguesTexte.textes(mode, verset.he, verset.fr, verset.en)
                let avecHebreu = textes.contains { $0.langue.egalUnites("he") }
                if avecHebreu {
                    // L'arrêt se marque dans le verset, avant « מִצַּר ».
                    if let coupe = verset.coupe(), let arret = verset.arret {
                        liste.append(TikkunElement(id: id, sorte: .verset(PoliceHebraique.masque(coupe.debut, police: police))))
                        liste.append(TikkunElement(id: id + ":arret",
                                                   sorte: .arret(PoliceHebraique.masque(arret.note, police: police))))
                        liste.append(TikkunElement(id: id + ":suite",
                                                   sorte: .verset(PoliceHebraique.masque(coupe.suite, police: police))))
                    } else {
                        liste.append(TikkunElement(id: id, sorte: .verset(PoliceHebraique.masque(verset.he, police: police))))
                        if let arret = verset.arret {
                            liste.append(TikkunElement(id: id + ":arret",
                                                       sorte: .arret(PoliceHebraique.masque(arret.note, police: police))))
                        }
                    }
                }
                TikkunModele.traductions(textes, id: id, avecHebreu: avecHebreu, base: 19, dans: &liste)
            }
        }

        if let bloc = tikkun.bloc(Tikkun.cloture) {
            liste.append(TikkunElement(id: bloc.cle + ":titre",
                                       sorte: .titre(.hebreu(PoliceHebraique.masque(bloc.titre.he, police: police)),
                                                     premier: false)))
            TikkunModele.paragraphes(bloc, mode: mode, police: police, dans: &liste)
        }

        // Après le Tikoun (04/11) : la kavana, puis la prière de Rabbi Natan.
        for cle in [Tikkun.kavana, Tikkun.priere] {
            guard let bloc = tikkun.bloc(cle) else { continue }
            liste.append(TikkunElement(id: bloc.cle + ":titre",
                                       sorte: .titre(.hebreu(PoliceHebraique.masque(bloc.titre.he, police: police)),
                                                     premier: false)))
            if let note = noteDe(bloc) {
                liste.append(TikkunElement(id: bloc.cle + ":note", sorte: .note(note)))
            }
            if let formule = bloc.formule {
                liste.append(TikkunElement(id: bloc.cle + ":formule",
                                           sorte: .paragraphe(PoliceHebraique.masque(formule, police: police), centre: true)))
            }
            TikkunModele.paragraphes(bloc, mode: mode, police: police, dans: &liste)
        }
        return liste
    }

    /// La note d'une partie dans la langue de l'app ; à défaut, son titre traduit s'il n'est pas l'hébreu même.
    private func noteDe(_ bloc: LiturgyBlock) -> String? {
        if let note = bloc.note?.pour(langue), !note.estBlanc { return note }
        let titre = bloc.titre.pour(langue)
        return titre.egalUnites(bloc.titre.he) ? nil : titre
    }

    /// Les paragraphes d'une partie liturgique, dans les langues choisies (04/11).
    private static func paragraphes(_ bloc: LiturgyBlock, mode: LanguesTexte.Mode, police: PoliceHebraique.Police,
                                    dans liste: inout [TikkunElement]) {
        for (rang, paragraphe) in bloc.paragraphes.enumerated() {
            let fr = rang < bloc.paragraphesFr.count ? bloc.paragraphesFr[rang] : nil
            let en = rang < bloc.paragraphesEn.count ? bloc.paragraphesEn[rang] : nil
            let textes = LanguesTexte.textes(mode, paragraphe, fr, en)
            let avecHebreu = textes.contains { $0.langue.egalUnites("he") }
            let id = bloc.cle + ":" + String(rang)
            if avecHebreu {
                liste.append(TikkunElement(id: id, sorte: .paragraphe(PoliceHebraique.masque(paragraphe, police: police),
                                                                      centre: false)))
            }
            traductions(textes, id: id, avecHebreu: avecHebreu, base: 18, dans: &liste)
        }
    }

    /// Les traductions d'un verset ou d'un paragraphe, à la suite de l'hébreu.
    private static func traductions(_ textes: [(langue: String, texte: String)], id: String, avecHebreu: Bool, base: Int,
                                    dans liste: inout [TikkunElement]) {
        var k = 0
        for t in textes where !t.langue.egalUnites("he") {
            liste.append(TikkunElement(id: id + ":" + t.langue,
                                       sorte: .traduction(t.texte, langue: t.langue, seule: !avecHebreu, base: base,
                                                          margeHaut: avecHebreu || k > 0 ? 4 : 12)))
            k += 1
        }
    }

    // MARK: Le défilement

    /// La vue signale l'élément en haut de l'écran.
    public func teteVisible(_ id: String) {
        tete = id
    }

    /// La taille, la nuit, la police ou les langues ont changé : l'élément de tête reste en tête (s'il existe
    /// encore : une traduction retirée ramène à son verset).
    private func garderPlace() {
        guard let tete else { return }
        let ids = Set(elements.map { $0.id })
        var cible = tete
        if !ids.contains(cible), let deuxPoints = cible.lastIndex(of: ":") {
            cible = String(cible[..<deuxPoints])
        }
        guard ids.contains(cible) else { return }
        jeton += 1
        defilement = TehilimDefilement(cible: cible, jeton: jeton)
    }
}
