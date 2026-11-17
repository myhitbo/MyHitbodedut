import Foundation
import Observation
import Coeur

// Le siddour (SiddurActivity.kt, demandes du 04/10) : en tête, le texte que suggère l'heure, avec son hassid ;
// puis Tehilim et le Tikoun HaKlali côte à côte ; puis les textes par groupe, en lignes de section, le nom
// hébreu dans la police des textes saints et sa traduction dessous. Le nusah se choisit sur le bandeau.
//
// L'heure et le jour sont pris à `actualiser()` (onResume d'Android) : la suggestion suit les zmanim du lieu,
// ou les heures fixes sans lieu. Le nusah, le lieu, Israël, la police et les marque-pages sont les réglages du
// `Magasin`. Les illustrations sont celles de la liste, pas d'un texte : on ne prie pas ici.

/// Une suggestion en tête (« Pour cette heure ») : la prière du moment, le Hallel de 'Hanouka, Birkat
/// haIlanot, la Méguila.
public struct SiddourSuggestion: Sendable, Equatable, Identifiable {
    /// L'identifiant du texte.
    public let id: String
    /// Le titre hébreu, en 26, dans la police choisie (masqué pour elle).
    public let hebreu: String
    /// Sa traduction dans la langue de l'app, en 14, discrète ; nil quand elle répète l'hébreu.
    public let traduction: String?
    /// Le personnage ou la scène, sur son panneau clair (bg_stage), 72 × 86.
    public let image: String
    public let route: LectureRoute
}

/// Une tuile de livre : Tehilim ou le Tikoun HaKlali.
public struct SiddourLivre: Sendable, Equatable, Identifiable {
    public let id: String
    /// Le nom hébreu vocalisé (siddur_tehilim_he, siddur_tikkun_he), en 19, centré, dans la police choisie.
    public let hebreu: Libelle
    /// Le nom dans la langue de l'app, en 13, discret, centré.
    public let traduction: Libelle
    /// Le personnage, 56 × 66, sur son panneau clair.
    public let image: String
    public let route: LectureRoute
}

/// Une ligne de section : un texte du siddour.
public struct SiddourTexteLigne: Sendable, Equatable, Identifiable {
    public let id: String
    /// Le titre hébreu, en 20, dans la police choisie.
    public let hebreu: String
    /// La traduction et, pour un texte emprunté à un autre nusah, ce nusah : « Matin · Edot HaMizra'h » ; nil si vide.
    public let detail: String?
    public var route: LectureRoute { .lecture(.siddour(id)) }
}

/// Un groupe du siddour : son en-tête et la carte de ses textes.
public struct SiddourGroupe: Sendable, Equatable, Identifiable {
    /// La clé du groupe.
    public let id: String
    /// Le nom hébreu, en 17 gras, couleur de marque.
    public let hebreu: String
    /// Dans la police hébraïque : seulement s'il y a des lettres hébraïques.
    public let hebreuPolice: Bool
    /// Sa traduction à côté, en 13, discrète ; nil quand elle répète l'hébreu.
    public let traduction: String?
    public let textes: [SiddourTexteLigne]
}

/// La ligne « סימניות · n » des marque-pages du siddour, en tête de la liste.
public struct SiddourSignets: Sendable, Equatable {
    public let titre: Libelle
    public let nombre: Int
    /// L'icône des prières, teinte de la couleur de marque, au bout de la ligne.
    public let icone: String
    public let route: LectureRoute
}

/// Où en est la liste.
public enum SiddourEtat: Sendable, Equatable {
    case chargement
    case pret
    case erreur
}

/// La liste du siddour.
@MainActor
@Observable
public final class SiddourModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    /// « fr », « en » ou « he ».
    public let langue: String

    public private(set) var etat: SiddourEtat = .chargement
    private var siddur: Siddur? = nil
    /// L'index des livres, lu seulement quand la Méguila se propose.
    private var livresIndex: Siddur? = nil
    /// L'instant de l'affichage (onResume) : la suggestion de l'heure en dépend.
    private var instant: Int64
    /// Le choix du nusah est ouvert (le dialogue du bandeau).
    public var choixNusahOuvert = false

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, langue: String) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.langue = ChizukCard.language(langue)
        instant = horloge.maintenant
    }

    /// Lit le siddour du nusah choisi, et prend l'heure : à chaque apparition de l'écran (le nusah a pu changer
    /// depuis une lecture, et l'heure a passé).
    public func actualiser() async {
        instant = horloge.maintenant
        do {
            siddur = try await contenus.siddur(magasin.reglages.siddurNusah)
            if meguila {
                livresIndex = try? await contenus.livres()
            }
            etat = .pret
        } catch {
            etat = .erreur
        }
    }

    // MARK: Le bandeau

    /// « Siddour », en blanc gras (hero_title) ; le hassid qui prie (char_praying) à droite.
    public var titre: Libelle {
        Libelle("siddur_title")
    }

    public var image: String {
        "char_praying"
    }

    /// Le nom du nusah, sur la pastille du bandeau ; vide tant que rien n'est lu.
    public var nusah: String {
        siddur?.nusah.pour(langue) ?? ""
    }

    /// Pour la lecture d'écran : « Noussa'h : <nom> » (la vue joint les deux d'un « : »).
    public var descriptionNusah: Libelle {
        Libelle("siddur_choose")
    }

    /// Le dialogue du choix : titre `siddur_choose`, un choix unique.
    public var optionsNusah: [LectureOption<Nusah>] {
        let actuel = magasin.reglages.siddurNusah
        return Nusah.allCases.map {
            LectureOption(valeur: $0, nom: Libelle("siddur_nusah_" + $0.rawValue), choisi: $0 == actuel)
        }
    }

    /// Le nusah choisi est gardé, et vaut aussi dans les lectures ; la liste se refait.
    public func choisirNusah(_ choix: Nusah) async throws {
        choixNusahOuvert = false
        guard choix != magasin.reglages.siddurNusah else { return }
        do {
            try await magasin.modifierReglages { $0.setSiddurNusah(choix) }
        } catch {
            await actualiser()
            throw error
        }
        await actualiser()
    }

    // MARK: Les marque-pages

    /// La ligne des marque-pages du siddour (28/10) ; nil sans marque-page d'un texte de ce siddour.
    public var signets: SiddourSignets? {
        guard let siddur else { return nil }
        let nombre = LecturePreferences.marques(magasin.reglages).filter { m in
            m.cle.commenceParUnites("s:") && siddur.texte(m.cle.apresUnites(":")) != nil
        }.count
        guard nombre > 0 else { return nil }
        return SiddourSignets(titre: Libelle("marques_titre"), nombre: nombre,
                              icone: LectureModele.icone(etude: false), route: .marquesPages(recueil: "s"))
    }

    // MARK: Les suggestions

    private var reglages: Reglages {
        magasin.reglages
    }

    private var enIsrael: Bool {
        reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// Le jour civil de l'affichage, dans le fuseau du téléphone.
    private var aujourdhui: JourCivil {
        horloge.fuseau.jour(millis: instant)
    }

    /// Le texte que suggère l'heure : avec un lieu, d'après ses zmanim (nil dans les creux) ; sans lieu, les
    /// heures fixes de SiddurMoment.
    /// La nuit de Chabbat, de fête ou de 'Hol hamoed Pessa'h, pas de Tikoun 'hatsot (audit du 16/11).
    public var moment: String? {
        if let lieu = reglages.lieuZmanim {
            return JourAffiche.momentDuSiddour(lieu: lieu, maintenant: Date(timeIntervalSince1970: Double(instant) / 1000),
                                               enIsrael: enIsrael, nusah: reglages.siddurNusah)
        }
        let heure = horloge.fuseau.dateHeure(millis: instant)
        return SiddurMoment.suggestion(heure: heure.heure, minute: heure.minute,
                                       sansTikoun: JourAffiche.sansTikounHatsot(aujourdhui, enIsrael: enIsrael))
    }

    /// La Méguila se propose : sous Arvit la nuit qui ouvre Pourim, sous Cha'harit le jour même.
    private var meguila: Bool {
        SiddurMoment.megila(moment, aujourdhui: aujourdhui, israel: enIsrael, mukafChoma: reglages.mukafChoma)
    }

    /// Les suggestions, dans l'ordre : la prière de l'heure ; le Hallel sous Cha'harit pendant 'Hanouka ; Birkat
    /// haIlanot le mois où on la dit ; la Méguila à Pourim. Un texte absent n'est pas proposé.
    public var suggestions: [SiddourSuggestion] {
        guard let siddur else { return [] }
        var sortie: [SiddourSuggestion] = []
        let moment = self.moment
        // Pas d'office de semaine proposé un Chabbat ou un Yom tov (audit du 16/11).
        let heure = horloge.fuseau.dateHeure(millis: instant).heure
        if let id = JourAffiche.momentOuvrable(moment, date: aujourdhui, heure: heure, enIsrael: enIsrael), let texte = siddur.texte(id) {
            sortie.append(suggestion(texte, image: SiddurMoment.illustration(texte.id), route: .lecture(.siddour(texte.id))))
        }
        if moment == "chaharit",
           CalendrierJuif.jour(aujourdhui, enIsrael: enIsrael).fetes.contains(CalendrierJuif.C.hanouka),
           let hallel = siddur.texte("hallel") {
            sortie.append(suggestion(hallel, image: "scene_hanukkah", route: .lecture(.siddour(hallel.id))))
        }
        if SiddurMoment.ilanot(aujourdhui, latitude: reglages.lieuZmanim?.latitude, nusah: reglages.siddurNusah),
           let ilanot = siddur.texte("birkat_hailanot") {
            sortie.append(suggestion(ilanot, image: "scene_nature", route: .lecture(.siddour(ilanot.id))))
        }
        if meguila, let esther = livresIndex?.texte("meguilat_esther") {
            sortie.append(suggestion(esther, image: "char_purim", route: .lecture(.livre(esther.id))))
        }
        return sortie
    }

    /// « Pour cette heure », en 12, en capitales espacées (0,06), couleur de marque, au-dessus de chaque titre.
    public var libelleSuggestion: Libelle {
        Libelle("siddur_maintenant")
    }

    private func suggestion(_ texte: SiddurTexte, image: String, route: LectureRoute) -> SiddourSuggestion {
        SiddourSuggestion(id: texte.id, hebreu: PoliceHebraique.masque(texte.titre.he, police: police),
                          traduction: traduction(texte.titre), image: image, route: route)
    }

    // MARK: Les livres

    /// L'en-tête « Livres ».
    public var titreLivres: Libelle {
        Libelle("siddur_books")
    }

    /// Tehilim et le Tikoun HaKlali, côte à côte.
    public var livres: [SiddourLivre] {
        [
            SiddourLivre(id: "tehilim", hebreu: Libelle("siddur_tehilim_he"), traduction: Libelle("tehilim_title"),
                         image: "char_tehilim", route: .tehilim),
            SiddourLivre(id: "tikkun", hebreu: Libelle("siddur_tikkun_he"), traduction: Libelle("tikkun_title"),
                         image: "char_torah", route: .tikkun),
        ]
    }

    // MARK: Les groupes

    /// Les groupes du siddour, chacun avec ses textes dans l'ordre du fichier.
    public var groupes: [SiddourGroupe] {
        guard let siddur else { return [] }
        let police = self.police
        return siddur.groupes.map { groupe in
            let textes = siddur.du(groupe.cle).map { texte in
                var details: [String] = []
                if let t = traduction(texte.titre) { details.append(t) }
                // Un texte absent des sources de ce nusah, emprunté à un autre, le dit.
                if let emprunt = texte.emprunt { details.append(emprunt.pour(langue)) }
                let detail = details.joined(separator: " · ")
                return SiddourTexteLigne(id: texte.id, hebreu: PoliceHebraique.masque(texte.titre.he, police: police),
                                         detail: detail.estBlanc ? nil : detail)
            }
            let hebreu = groupe.titre.he
            let avecPolice = SiddourModele.contientHebreu(hebreu)
            return SiddourGroupe(id: groupe.cle, hebreu: avecPolice ? PoliceHebraique.masque(hebreu, police: police) : hebreu,
                                 hebreuPolice: avecPolice, traduction: traduction(groupe.titre), textes: textes)
        }
    }

    /// Les seules mentions que les licences demandent (CC-BY), en 12, discrètes, au pied ; nil sans mention.
    public var mentions: Libelle? {
        guard let siddur, !siddur.mentions.isEmpty else { return nil }
        return Libelle("siddur_sources", .texte(siddur.mentions.joined(separator: " ; ")))
    }

    // MARK: Les aides

    /// La police hébraïque des réglages de lecture.
    public var police: PoliceHebraique.Police {
        LecturePreferences.police(magasin.reglages)
    }

    /// La traduction d'un titre ; nil quand elle répète l'hébreu (`takeIf { it != titre.he }`).
    private func traduction(_ titre: TexteLocalise) -> String? {
        let t = titre.pour(langue)
        return t.egalUnites(titre.he) ? nil : t
    }

    /// `hebreu.any { it in '֐'..'׿' }` : une lettre ou un signe de l'hébreu (U+0590 à U+05FF).
    static func contientHebreu(_ texte: String) -> Bool {
        texte.utf16.contains { $0 >= 0x0590 && $0 <= 0x05FF }
    }
}
