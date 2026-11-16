import Foundation
import Observation
import Coeur

// La halakha du jour (HalakhaActivity.kt, 11/10), sur le modèle de l'écran des hilloulot : le jour, ses halakhot
// (hors ligne, en hébreu) du livre choisi — Yalkut Yosef, Ben Ish 'Haï ou les deux (14/10) —, chacune avec sa
// source ; le jour précédent ou suivant ; la recherche dans tout le livre ; l'interrupteur de la carte du jour ;
// le lien vers halachayomit.co.il.
//
// La langue est celle de l'app (`Traducteur.langue`) : `ChizukCard.language(context)` d'Android. Israël ou
// diaspora, le livre choisi, l'interrupteur, la taille et la police des lettres sont les réglages du `Magasin`,
// lus à chaque fois : un changement fait ailleurs se voit ici.

// MARK: Les textes

/// Ce que les écrans de la halakha et des hilloulot lisent de la même façon.
public enum HalakhaTexte {

    /// `VueJour.paragraphes` : le texte coupé à chaque suite de retours à la ligne (`split(Regex("\\n+"))`), chaque
    /// morceau rogné, les morceaux vides ôtés. Moins de deux : un seul paragraphe, le texte rogné (vide s'il est
    /// blanc). La vue les sépare d'une demi-ligne vide (la `RelativeSizeSpan(0.5f)` d'Android).
    public static func paragraphes(_ texte: String) -> [String] {
        var morceaux: [String] = []
        var courant: [UInt16] = []
        for u in texte.utf16 {
            if u == 0x0A {
                morceaux.append(Unites.texte(courant))
                courant.removeAll()
            } else {
                courant.append(u)
            }
        }
        morceaux.append(Unites.texte(courant))
        var gardes: [String] = []
        for m in morceaux {
            let r = m.rogne
            if !r.isEmpty { gardes.append(r) }
        }
        if gardes.count < 2 { return [texte.rogne] }
        return gardes
    }
}

// MARK: Ce que l'écran montre

/// Où en est la lecture des deux livres.
public enum HalakhaEtat: Sendable, Equatable {
    case chargement
    case pret
    /// Ni le Yalkut Yosef ni le Ben Ish 'Haï n'ont pu être lus : « Pas de halakha pour ce jour », la recherche ne
    /// trouve rien. Un seul illisible : l'écran fait comme s'il était vide.
    case erreur
}

/// Un lien externe : son libellé, suivi dans la vue de « ↗ », et l'adresse qu'ouvre le navigateur.
public struct HalakhaLien: Sendable, Equatable {
    public let libelle: Libelle
    public let url: String
}

/// Une carte de halakha (HalakhaActivity.carte) : sa source en hébreu, puis le texte, en hébreu lui aussi.
public struct HalakhaCarte: Sendable, Equatable, Identifiable {
    /// Unique dans l'écran.
    public let id: String
    /// « ילקוט יוסף · סימן א - הלכות השכמת הבוקר » ou « בן איש חי · שנה ראשונה · לך לך · אות א׳ » : 13 sp, gras,
    /// couleur de marque, de droite à gauche, police hébraïque.
    public let titre: String
    /// Le texte (`VueJour.paragraphes`) : 18 sp, encre, interligne 1,4, de droite à gauche, police hébraïque,
    /// sélectionnable.
    public let paragraphes: [String]
}

/// Un livre proposé (les puces de Store.SourceHalakha) : un seul choisi, toujours un.
public struct HalakhaChoixSource: Sendable, Equatable, Identifiable {
    public var id: String { source.rawValue }
    public let source: Reglages.SourceHalakha
    /// « Yalkut Yosef », « Ben Ish ’Haï », « Les deux ».
    public let libelle: Libelle
    public let choisie: Bool
}

/// Le jour montré, hors recherche, dans l'ordre de l'écran.
public struct HalakhaDuJour: Sendable, Equatable {
    public let jour: JourCivil
    /// « כ״ה חשון תשפ״ז » : 20 sp, gras, couleur de marque, centrée, police hébraïque. La date civile dessous
    /// (« lundi 16 novembre 2026 », `VueJour.dateCivile`) se met en forme dans la vue, d'après `jour`.
    public let dateHebraique: String
    /// Les deux se'ifim du Yalkut Yosef en une seule carte (YalkutYosef.titreCarte et texteCarte) ; nil si le
    /// livre n'est pas choisi ou n'a rien ce jour.
    public let yalkut: HalakhaCarte?
    /// « Pas de halakha pour ce jour » : ni Yalkut Yosef ni Ben Ish 'Haï ; nil sinon.
    public let aucune: Libelle?
    /// « Ben Ish ’Haï, paracha de la semaine », au-dessus de ses cartes ; nil sans elles.
    public let benIshHaiTitre: Libelle?
    /// La part du jour du Ben Ish 'Haï (Halakha.pour), une carte par halakha.
    public let benIshHai: [HalakhaCarte]
    /// La source et la licence du Yalkut Yosef, dès qu'il est choisi (même un jour sans se'if) ; nil sinon.
    public let yalkutSource: Libelle?
    /// « Texte original en hébreu, verbatim. »
    public let note: Libelle
    /// « La halakha du jour sur halachayomit.co.il ↗ », dans la langue de l'app.
    public let lien: HalakhaLien
}

/// La recherche (deux unités au moins, une fois rognée).
public struct HalakhaResultats: Sendable, Equatable {
    /// « Résultats : 12 » : toutes les trouvailles des livres choisis, même au-delà des cartes montrées.
    public let nombre: Libelle
    /// Les quarante premières du Yalkut Yosef, puis les quarante premières du Ben Ish 'Haï.
    public let cartes: [HalakhaCarte]
}

/// Ce que montre la liste, sous la carte des réglages (interrupteur, livre, champ de recherche).
public enum HalakhaContenu: Sendable, Equatable {
    /// Les livres se lisent, ou la première recherche tourne.
    case chargement
    case jour(HalakhaDuJour)
    case recherche(HalakhaResultats)
}

// MARK: Le modèle

/// Ce qu'a trouvé une recherche, dans les livres choisis.
private struct HalakhaTrouvees: Sendable {
    let yalkut: [YalkutYosef.Seif]
    let benIshHai: [Halakha.Choisie]
}

/// L'écran de la halakha du jour. Il s'ouvre sur aujourd'hui, sur une date (`EXTRA_DATE`, la carte du jour) ou sur
/// une recherche (`EXTRA_RECHERCHE`, un résultat « halakha » de la recherche globale).
@MainActor
@Observable
public final class HalakhaModele {

    /// Au plus tant de cartes montrées par livre dans la recherche (`take(40)`).
    public static let resultatsMontres = 40

    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    /// « fr », « en » ou « he ».
    public let langue: String

    /// Le jour montré (`ETAT_JOUR` d'Android : la vue le garde pour le rendre à la restauration).
    public private(set) var jour: JourCivil
    /// Le texte du champ de recherche.
    public private(set) var recherche: String
    public private(set) var etat: HalakhaEtat = .chargement

    /// Les deux livres ; nil tant qu'ils se lisent, ou s'ils n'ont pu l'être.
    private var yalkut: YalkutYosef.Livre?
    private var benIshHai: Halakha.Livre?
    private var charge = false
    /// Les trouvailles de la dernière recherche finie.
    private var trouvees: HalakhaTrouvees?

    @ObservationIgnored private var quitteLe: JourCivil?
    @ObservationIgnored private var tacheRecherche: Task<Void, Never>?
    @ObservationIgnored private var demande = 0

    /// `date` : `EXTRA_DATE` (aujourd'hui sinon, dans le fuseau du téléphone) ; `recherche` : `EXTRA_RECHERCHE`,
    /// qui remplit le champ (RechercheActivity.preremplir). Rien ne se lit avant `charger()`.
    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String,
                date: JourCivil? = nil, recherche: String? = nil) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = langue
        jour = date ?? horloge.aujourdhui
        self.recherche = recherche ?? ""
    }

    // MARK: Les réglages

    /// Israël ou diaspora (Store.inIsrael) : le réglage, sinon ce que dit le fuseau du téléphone.
    public var enIsrael: Bool {
        magasin.reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// Le livre choisi : le Yalkut Yosef par défaut.
    public var source: Reglages.SourceHalakha {
        magasin.reglages.sourceHalakha
    }

    /// Les trois puces du livre, dans l'ordre de Store.SourceHalakha, sous « Livre de la halakha ».
    public var sources: [HalakhaChoixSource] {
        let choisie = source
        return Reglages.SourceHalakha.allCases.map {
            HalakhaChoixSource(source: $0, libelle: Libelle($0.libelle), choisie: $0 == choisie)
        }
    }

    /// L'interrupteur du haut : la halakha sur la carte du jour, à l'accueil.
    public var afficheeSurLaCarteDuJour: Bool {
        magasin.reglages.halakhaAffichee
    }

    /// La taille des lettres des écrans de lecture (0,8 à 2), qui multiplie celle de chaque texte de la liste
    /// (ReglagesLecture.retailler), hors champ de recherche.
    public var echelle: Float {
        magasin.reglages.lectureEchelle
    }

    /// La police hébraïque des réglages de lecture : la date hébraïque, les titres et les textes des cartes.
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

    public var contenu: HalakhaContenu {
        guard charge else { return .chargement }
        if enRecherche {
            guard let trouvees else { return .chargement }
            return .recherche(resultats(trouvees))
        }
        return .jour(duJour())
    }

    /// HalakhaActivity.remplir, hors recherche : le Yalkut Yosef d'abord (13/10), deux halakhot courtes en une
    /// carte ; puis le Ben Ish 'Haï de la semaine ; selon le livre choisi.
    private func duJour() -> HalakhaDuJour {
        let israel = enIsrael
        let choisie = source
        let police = self.police
        var carteYalkut: HalakhaCarte?
        if choisie.montreYalkut, let yalkut {
            let seifs = YalkutYosef.pour(yalkut, date: jour, israel: israel)
            if !seifs.isEmpty {
                carteYalkut = HalakhaModele.carte(id: "jour|yalkut", titre: YalkutYosef.titreCarte(seifs),
                                                  texte: YalkutYosef.texteCarte(seifs), police: police)
            }
        }
        var cartes: [HalakhaCarte] = []
        if choisie.montreBenIshHai, let benIshHai {
            for (i, h) in Halakha.pour(benIshHai, date: jour, enIsrael: israel).enumerated() {
                cartes.append(HalakhaModele.carte(id: "jour|bih#\(i)", titre: Halakha.source(h), texte: h.texte,
                                                  police: police))
            }
        }
        return HalakhaDuJour(jour: jour,
                             dateHebraique: CalendrierJuif.jour(jour, enIsrael: israel).dateHebraique,
                             yalkut: carteYalkut,
                             aucune: carteYalkut == nil && cartes.isEmpty ? Libelle("halakha_aucune") : nil,
                             benIshHaiTitre: cartes.isEmpty ? nil : Libelle("halakha_ben_ish_hai"),
                             benIshHai: cartes,
                             yalkutSource: choisie.montreYalkut ? Libelle("halakha_yalkut_source") : nil,
                             note: Libelle("halakha_note"),
                             lien: HalakhaLien(libelle: Libelle("halakha_yomit_lien"), url: Hilloulot.lienHalakha(langue)))
    }

    /// Le nombre de toutes les trouvailles, puis quarante cartes au plus de chaque livre.
    private func resultats(_ t: HalakhaTrouvees) -> HalakhaResultats {
        let police = self.police
        var cartes: [HalakhaCarte] = []
        for (i, s) in t.yalkut.prefix(HalakhaModele.resultatsMontres).enumerated() {
            cartes.append(HalakhaModele.carte(id: "r|yalkut#\(i)", titre: YalkutYosef.source(s), texte: s.texte,
                                              police: police))
        }
        for (i, h) in t.benIshHai.prefix(HalakhaModele.resultatsMontres).enumerated() {
            cartes.append(HalakhaModele.carte(id: "r|bih#\(i)", titre: Halakha.source(h), texte: h.texte, police: police))
        }
        return HalakhaResultats(nombre: Libelle("hilloulot_resultats", .entier(t.yalkut.count + t.benIshHai.count)),
                                cartes: cartes)
    }

    /// Une carte (HalakhaActivity.carte) : le titre et le texte en police hébraïque, leurs signes absents de la
    /// police masqués (PoliceHebraique.appliquer d'Android).
    private nonisolated static func carte(id: String, titre: String, texte: String,
                                          police: PoliceHebraique.Police) -> HalakhaCarte {
        HalakhaCarte(id: id, titre: PoliceHebraique.masque(titre, police: police),
                     paragraphes: HalakhaTexte.paragraphes(PoliceHebraique.masque(texte, police: police)))
    }

    // MARK: Les actions

    /// Lit les deux livres, puis lance la recherche reçue s'il y en a une. Rend la main une fois les livres lus ;
    /// la recherche suit (`attendre()`).
    public func charger() async {
        guard !charge else { return }
        let lu = try? await contenus.yalkutYosef()
        let luBis = try? await contenus.benIshHai()
        yalkut = lu
        benIshHai = luBis
        etat = lu == nil && luBis == nil ? .erreur : .pret
        charge = true
        if enRecherche { lancerRecherche() }
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
        }
    }

    public func jourPrecedent() {
        jour = jour.plus(jours: -1)
    }

    public func jourSuivant() {
        jour = jour.plus(jours: 1)
    }

    /// Une puce du livre (Store.setSourceHalakha) ; la recherche montrée se refait dans les livres choisis.
    public func choisirSource(_ choisie: Reglages.SourceHalakha) async throws {
        try await magasin.modifierReglages { $0.setSourceHalakha(choisie) }
        if enRecherche { lancerRecherche() }
    }

    /// L'interrupteur du haut (Store.setHalakhaAffichee).
    public func afficherSurLaCarteDuJour(_ oui: Bool) async throws {
        try await magasin.modifierReglages { $0.setHalakhaAffichee(oui) }
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
        jour = aujourdhui
    }

    /// Attend la fin de la recherche lancée (les tests, les aperçus).
    public func attendre() async {
        while true {
            let tache = tacheRecherche
            if let tache { await tache.value }
            if tache == tacheRecherche { return }
        }
    }

    // MARK: En arrière-plan

    /// La recherche dans les livres choisis, hors du fil principal ; seule la dernière demandée s'affiche. Les
    /// trouvailles précédentes restent montrées le temps qu'elle tourne.
    private func lancerRecherche() {
        demande += 1
        let numero = demande
        tacheRecherche?.cancel()
        guard charge, enRecherche else { return }
        let texte = recherche
        let livreYalkut = source.montreYalkut ? yalkut : nil
        let livreBenIshHai = source.montreBenIshHai ? benIshHai : nil
        tacheRecherche = Task {
            let trouvees = await Task.detached(priority: .userInitiated) {
                HalakhaTrouvees(yalkut: livreYalkut.map { YalkutYosef.recherche($0, texte: texte) } ?? [],
                                benIshHai: livreBenIshHai.map { Halakha.recherche($0, texte: texte) } ?? [])
            }.value
            guard numero == self.demande else { return }
            self.trouvees = trouvees
        }
    }
}
