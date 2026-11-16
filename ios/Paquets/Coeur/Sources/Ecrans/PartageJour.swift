import Foundation
import Coeur

// Partager un jour (PartageJour.kt, 14/10) : une image de 1080 × 1350 — la date hébraïque et civile, les fêtes et
// la paracha, la hilloula, le début de la halakha du jour avec sa source — envoyée par la feuille de partage
// (WhatsApp…). Rien ne part sans ce geste ; l'image reste dans le cache de l'app.
//
// Ici, le contenu (`PartageContenu.pour`, le `contenu` testé sans dessin d'Android) et la mise en page, bloc par
// bloc (`PartageImage.blocs`, le `image` d'Android) ; la vue dessine les blocs (ImageRenderer) et ouvre la
// feuille de partage, titrée « Partager ce jour ».

/// Le texte de l'image, ligne par ligne (PartageJour.Contenu).
public struct PartageContenu: Sendable, Equatable {
    public let date: JourCivil
    /// « א׳ חשון תשפ״ז ».
    public let dateHebraique: String
    /// Les fêtes puis la paracha (sans l'omer, à la différence de la carte du jour) ; jointes par
    /// `ZmanimVueJour.separateurMarques`.
    public let marques: [Libelle]
    /// Les trois premiers noms hébreux de la hilloula du jour, joints par « · » ; vide s'il n'y en a pas. Montrée
    /// même quand la carte du jour masque la hilloula (Android ne lit pas ce réglage ici).
    public let hilloula: String
    /// Le début de la halakha du jour : 420 unités UTF-16 au plus, « … » au bout s'il est coupé ; vide sans
    /// halakha. Même règle : le réglage de la carte n'y fait rien, seul le livre choisi compte.
    public let halakha: String
    /// Le livre de la halakha ; nil sans halakha.
    public let source: Libelle?

    public init(date: JourCivil, dateHebraique: String, marques: [Libelle], hilloula: String, halakha: String,
                source: Libelle?) {
        self.date = date
        self.dateHebraique = dateHebraique
        self.marques = marques
        self.hilloula = hilloula
        self.halakha = halakha
        self.source = source
    }

    /// Le nom du fichier de l'image (`jour-2026-10-12.png`).
    public var nomFichier: String {
        "jour-" + date.iso + ".png"
    }

    /// Au plus tant d'unités UTF-16 du début de la halakha (`debut.take(420)`).
    public static let longueurHalakha = 420
    /// Au plus tant de noms de la hilloula.
    public static let nomsHilloula = 3

    /// PartageJour.contenu : ce jour, avec les réglages et les contenus lus.
    public static func pour(_ date: JourCivil, _ c: ZmanimContexte) -> PartageContenu {
        let enIsrael = c.enIsrael
        let j = CalendrierJuif.jour(date, enIsrael: enIsrael, mukafChoma: c.reglages.mukafChoma)
        var marques: [Libelle] = []
        for fete in j.fetes {
            if let chaine = Libelles.res("fete_" + fete) { marques.append(Libelle(chaine)) }
        }
        if let paracha = j.paracha { marques.append(Libelle("zmanim_paracha", .texte(paracha))) }
        var noms: [String] = []
        if let table = c.sources.hilloulot {
            let liste = Hilloulot.pour(table, date: date, enIsrael: enIsrael, ashkenaz: c.reglages.siddurNusah == .ashkenaz)
            noms = liste.prefix(nomsHilloula).map { $0.he }
        }
        let apercu = ZmanimVueJour.apercuHalakha(date, enIsrael: enIsrael, source: c.reglages.sourceHalakha,
                                                 sources: c.sources)
        var halakha = ""
        if let debut = apercu?.texte {
            halakha = debut.premieresUnites(longueurHalakha)
            if debut.utf16.count > longueurHalakha { halakha += "…" }
        }
        return PartageContenu(date: date, dateHebraique: j.dateHebraique, marques: marques,
                              hilloula: noms.joined(separator: " · "), halakha: halakha, source: apercu?.livre)
    }
}

/// Un bloc de texte de l'image (PartageJour.image, `bloc`) : posé à `PartageImage.marge` du bord gauche, sur la
/// largeur `PartageImage.largeurTexte`, interligne 1,25, puis `apres` points d'espace avant le suivant.
public struct PartageBloc: Sendable, Equatable {

    /// Ce que dit le bloc.
    public enum Texte: Sendable, Equatable {
        /// Un texte déjà écrit (la date hébraïque, les noms, la halakha).
        case brut(String)
        /// Des libellés résolus dans la langue de l'app, puis joints par le séparateur.
        case libelles([Libelle], separateur: String)
        /// La date civile en toutes lettres dans la langue de l'app : « lundi 12 octobre 2026 »
        /// (« EEEE d MMMM yyyy »).
        case dateCivile(JourCivil)
    }

    /// La police hébraïque de l'image (`R.font.frank_ruhl`, serif à défaut), ou celle du système.
    public enum Police: Sendable, Equatable {
        case hebraique
        case systeme
    }

    /// Le blanc plein, ou le blanc à 80 % (`0xCCFFFFFF`).
    public enum Teinte: Sendable, Equatable {
        case encre
        case douce
    }

    /// Le sens du paragraphe. `droiteAGauche` : forcé de droite à gauche, aligné à l'opposé de son début
    /// (`ALIGN_OPPOSITE` avec `TextDirectionHeuristics.RTL`), donc contre la marge gauche. `premierFort` : le sens
    /// de la première lettre forte (`FIRSTSTRONG_LTR`), aligné à son début (à gauche en français, à droite pour un
    /// texte hébreu).
    public enum Sens: Sendable, Equatable {
        case droiteAGauche
        case premierFort
    }

    public let texte: Texte
    /// La taille de la police, en pixels de l'image.
    public let taille: Double
    public let teinte: Teinte
    public let police: Police
    public let gras: Bool
    public let sens: Sens
    /// L'espace après le bloc, en pixels de l'image.
    public let apres: Double
}

/// L'image de partage (PartageJour.image) : sa taille, son fond, ses blocs et sa signature.
public enum PartageImage {
    public static let largeur = 1080
    public static let hauteur = 1350
    /// La marge de gauche et de droite ; la signature est à `marge / 2` du bas.
    public static let marge = 84.0
    /// Le haut du premier bloc : `MARGE + 40`.
    public static let haut = 124.0
    /// La largeur des blocs : `L - 2 * MARGE`.
    public static let largeurTexte = 912.0
    /// L'interligne de chaque bloc (`setLineSpacing(0f, 1.25f)`).
    public static let interligne = 1.25
    /// Le fond, d'un aplat : la couleur sombre de l'accent choisi (`R.color.brand_dark`).
    public static let fond: Jeton = .brandDark
    /// L'opacité du blanc « doux » (`0xCC` sur 255).
    public static let opaciteDouce = 0.8
    /// La signature en bas à gauche : le nom de l'app, 30 px, gras, blanc doux, sa ligne de base à
    /// `hauteur - marge / 2` (1308 px).
    public static let signature = Libelle("app_name")
    public static let signatureTaille = 30.0
    public static let signatureLigneDeBase = 1308.0

    /// Les blocs, de haut en bas ; un texte vide ne fait pas de bloc (`if (texte.isBlank()) return`).
    public static func blocs(_ x: PartageContenu) -> [PartageBloc] {
        var blocs: [PartageBloc] = []
        blocs.append(PartageBloc(texte: .brut(x.dateHebraique), taille: 92, teinte: .encre, police: .hebraique,
                                 gras: true, sens: .droiteAGauche, apres: 8))
        blocs.append(PartageBloc(texte: .dateCivile(x.date), taille: 40, teinte: .douce, police: .systeme,
                                 gras: false, sens: .premierFort, apres: 22))
        if !x.marques.isEmpty {
            blocs.append(PartageBloc(texte: .libelles(x.marques, separateur: ZmanimVueJour.separateurMarques),
                                     taille: 40, teinte: .encre, police: .systeme, gras: true, sens: .premierFort,
                                     apres: 40))
        }
        if !x.hilloula.estBlanc {
            blocs.append(PartageBloc(texte: .libelles([Libelle("hilloula_titre")], separateur: ""), taille: 30,
                                     teinte: .douce, police: .systeme, gras: true, sens: .premierFort, apres: 6))
            blocs.append(PartageBloc(texte: .brut(x.hilloula), taille: 44, teinte: .encre, police: .hebraique,
                                     gras: false, sens: .droiteAGauche, apres: 40))
        }
        if !x.halakha.estBlanc {
            var titre = [Libelle("halakha_yomit_titre")]
            if let source = x.source { titre.append(source) }
            blocs.append(PartageBloc(texte: .libelles(titre, separateur: " · "), taille: 30, teinte: .douce,
                                     police: .systeme, gras: true, sens: .premierFort, apres: 6))
            blocs.append(PartageBloc(texte: .brut(x.halakha), taille: 42, teinte: .encre, police: .hebraique,
                                     gras: false, sens: .droiteAGauche, apres: 20))
        }
        return blocs
    }
}
