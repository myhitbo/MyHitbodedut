import Foundation
import Observation
import Coeur

// Le calendrier (CalendrierActivity.kt, 10/10) : un mois, du dimanche au samedi, chaque case avec le quantième
// hébreu et le quantième civil ; Chabbat et fêtes teintés, les fêtes marquées d'un point. Le mois hébreu est la
// vue principale, le mois civil au choix (Store.calendrierCivil) ; le quantième principal est en haut de la case.
// Le jour touché montre sa carte (complète : Levana, hilloula et halakha y sont) et ses horaires sous la grille.
// Les grilles viennent de JourAffiche.
//
// Israël ou diaspora, la ville murée, la vue (hébraïque ou civile) et le reste sont les réglages du `Magasin`,
// lus à chaque fois.

// MARK: Ce que l'écran montre

/// Un titre de l'en-tête du mois.
public enum CalendrierTitre: Sendable, Equatable {
    /// Un texte hébreu : « חשון תשפ״ז », ou « תשרי – חשון תשפ״ז » ; police hébraïque.
    case hebreu(String)
    /// Le mois civil de ce jour, « LLLL yyyy » dans la langue de l'app, l'initiale en majuscule : « Octobre 2026 ».
    case moisCivil(JourCivil)
    /// Les mois civils qu'un mois hébreu couvre, l'initiale en majuscule : « Septembre – octobre 2026 »
    /// (« LLLL – LLLL yyyy »), ou « Décembre 2026 – janvier 2027 » quand l'année change (`anneeAuDebut`).
    case plageCivile(debut: JourCivil, fin: JourCivil, anneeAuDebut: Bool)
}

/// L'en-tête : « ‹ », le titre et le sous-titre au centre, « › ».
public struct CalendrierEnTete: Sendable, Equatable {
    /// 20 pt en vue hébraïque (police hébraïque), 17 pt en vue civile ; gras, encre, centré.
    public let titre: CalendrierTitre
    /// 15 pt, couleur de la marque, centré ; police hébraïque en vue civile.
    public let sousTitre: CalendrierTitre
    /// « Mois précédent », « Mois suivant » : la description des flèches (48 × 48 pt).
    public let precedent: Libelle
    public let suivant: Libelle
}

/// Un quantième d'une case.
public enum CalendrierQuantieme: Sendable, Equatable {
    /// « כ״ט » : police hébraïque.
    case hebreu(String)
    /// « 12 ».
    case civil(Int)
    /// Le 1er d'un mois civil en vue hébraïque, pour qu'on lise où il bascule : « 1 » et le mois abrégé
    /// (« LLL ») dans la langue de l'app, « 1 oct. ».
    case premierDuMois(JourCivil)
}

/// Une case de la grille (52 pt de haut, toute la largeur d'une colonne, touchable).
public struct CalendrierCase: Sendable, Equatable, Identifiable {
    public var id: String { date.iso }
    public let date: JourCivil
    /// Le quantième principal : hébreu (17 pt) en vue hébraïque, civil (15 pt) en vue civile.
    public let haut: CalendrierQuantieme
    /// L'autre : 11 pt, atténué, une ligne.
    public let bas: CalendrierQuantieme
    /// Aujourd'hui : le quantième principal à la couleur de la marque, en gras.
    public let aujourdhui: Bool
    /// Le jour choisi : un contour de 2 pt à la couleur de la marque.
    public let choisie: Bool
    /// Chabbat ou Yom Tov : le fond à la couleur de la marque à 10 % (`0x1A`).
    public let chome: Bool
    /// Une fête : un point de 5 pt à la couleur de la marque sous le quantième principal.
    public let fete: Bool
    /// Pour la lecture d'écran : la date ISO, la date hébraïque, puis les fêtes, joints par « · ».
    public let dateHebraique: String
    public let fetes: [Libelle]
}

/// Une semaine de la grille, du dimanche au samedi ; nil hors du mois.
public struct CalendrierSemaine: Sendable, Equatable, Identifiable {
    public let id: Int
    public let cases: [CalendrierCase?]
}

/// Un bouton du choix de la vue (une pilule) : actif, fond de la marque et texte `on_brand` en gras ; sinon texte
/// de la marque sur la pilule commune (la marque à 9 %, `0x17`).
public struct CalendrierChoixVue: Sendable, Equatable, Identifiable {
    /// Vrai : la vue civile.
    public let civil: Bool
    public let libelle: Libelle
    public let actif: Bool
    public var id: Bool { civil }
}

// MARK: Le modèle

@MainActor
@Observable
public final class CalendrierModele {

    private let magasin: Magasin
    private let horloge: any Horloge
    private let contenus: ContenusApp?
    private let tableHilloulot: ZmanimHilloulotTable?

    /// Le choix du lieu, partagé avec l'onglet Zmanim : la carte des horaires sans lieu l'ouvre.
    public let choixLieu: LieuModele?
    /// « fr », « en » ou « he ».
    public let langue: String

    /// Le 1er du mois civil affiché (vue civile).
    public private(set) var mois: JourCivil
    /// Le jour touché (`ETAT_JOUR` : la vue le garde pour le rendre à la restauration).
    public private(set) var choisi: JourCivil
    /// Le 1er du mois hébreu affiché ; nil : celui du jour choisi (`ETAT_MOIS_HEBREU`).
    public private(set) var moisHebreu: JourCivil?

    public private(set) var sources: ZmanimSources = .vide
    public private(set) var charge = false
    @ObservationIgnored private var quitteLe: JourCivil?

    /// `jour` et `moisHebreu` : l'état gardé à la restauration (sinon aujourd'hui, dans le fuseau du téléphone).
    public init(magasin: Magasin, horloge: any Horloge, contenus: ContenusApp? = nil,
                hilloulot: ZmanimHilloulotTable? = nil, choixLieu: LieuModele? = nil,
                langue: String = Traducteur.repli, jour: JourCivil? = nil, moisHebreu: JourCivil? = nil) {
        self.magasin = magasin
        self.horloge = horloge
        self.contenus = contenus
        tableHilloulot = hilloulot
        self.choixLieu = choixLieu
        self.langue = langue
        let choisi = jour ?? horloge.aujourdhui
        self.choisi = choisi
        mois = CalendrierModele.premierDuMois(choisi)
        self.moisHebreu = moisHebreu
    }

    // MARK: Le bandeau

    /// « Calendrier ».
    public var titre: Libelle {
        Libelle("calendrier_title")
    }

    /// L'illustration du bandeau : le personnage qui réfléchit.
    public var image: String {
        "char_thinking"
    }

    // MARK: La grille

    public var enIsrael: Bool {
        magasin.reglages.inIsrael(fuseauTelephone: horloge.fuseau.identifiant)
    }

    /// La police hébraïque des réglages de lecture (PoliceHebraique.appliquer) : les quantièmes hébreux, le titre
    /// du mois hébreu, la date hébraïque de la carte, les noms de la hilloula, le début de la halakha.
    public var police: PoliceHebraique.Police {
        PoliceHebraique.Police(rawValue: magasin.reglages.lecturePolice) ?? .serif
    }

    /// La vue civile (Store.calendrierCivil) ; hébraïque par défaut.
    public var civil: Bool {
        magasin.reglages.calendrierCivil
    }

    /// Le 1er du mois hébreu affiché.
    public var debutHebreu: JourCivil {
        moisHebreu ?? JourAffiche.debutMoisHebreu(choisi)
    }

    /// « Vue du calendrier » : la description du choix de la vue.
    public var vueDescription: Libelle {
        Libelle("calendrier_vue")
    }

    /// « Hébraïque », « Grégorien », centrés en haut de la carte.
    public var vues: [CalendrierChoixVue] {
        let civil = self.civil
        return [CalendrierChoixVue(civil: false, libelle: Libelle("calendrier_vue_hebreu"), actif: !civil),
                CalendrierChoixVue(civil: true, libelle: Libelle("calendrier_vue_civil"), actif: civil)]
    }

    /// Les jours affichés, semaine par semaine.
    private var grilleBrute: [[JourCivil?]] {
        civil ? JourAffiche.semaines(annee: mois.annee, mois: mois.mois) : JourAffiche.semainesHebreu(debutHebreu)
    }

    public var enTete: CalendrierEnTete {
        let jours = grilleBrute.flatMap { $0 }.compactMap { $0 }
        let israel = enIsrael
        let premierJour = jours.first ?? choisi
        let dernierJour = jours.last ?? choisi
        let titre: CalendrierTitre
        let sousTitre: CalendrierTitre
        if civil {
            let premier = CalendrierJuif.jour(premierJour, enIsrael: israel).moisEtAnnee
            let dernier = CalendrierJuif.jour(dernierJour, enIsrael: israel).moisEtAnnee
            titre = .moisCivil(mois)
            sousTitre = .hebreu(premier == dernier ? premier : premier + " – " + dernier)
        } else {
            titre = .hebreu(CalendrierJuif.jour(debutHebreu, enIsrael: israel).moisEtAnnee)
            sousTitre = .plageCivile(debut: premierJour, fin: dernierJour, anneeAuDebut: premierJour.annee != dernierJour.annee)
        }
        return CalendrierEnTete(titre: titre, sousTitre: sousTitre, precedent: Libelle("calendrier_precedent"),
                                suivant: Libelle("calendrier_suivant"))
    }

    /// Les jours de la semaine, du dimanche (1) au samedi (7) : leur initiale (`TextStyle.NARROW`) dans la langue
    /// de l'app, 12 pt, atténuée, 24 pt de haut.
    public var joursDeSemaine: [Int] {
        Array(1...7)
    }

    /// Les semaines du mois affiché.
    public var semaines: [CalendrierSemaine] {
        let israel = enIsrael
        let mukafChoma = magasin.reglages.mukafChoma
        let civil = self.civil
        let aujourdhui = horloge.aujourdhui
        let choisi = self.choisi
        var semaines: [CalendrierSemaine] = []
        for (i, semaine) in grilleBrute.enumerated() {
            var cases: [CalendrierCase?] = []
            for jour in semaine {
                guard let d = jour else {
                    cases.append(nil)
                    continue
                }
                let j = CalendrierJuif.jour(d, enIsrael: israel, mukafChoma: mukafChoma)
                let quantieme: CalendrierQuantieme = !civil && d.jour == 1 ? .premierDuMois(d) : .civil(d.jour)
                let hebreu = CalendrierQuantieme.hebreu(j.jourEnLettres)
                var fetes: [Libelle] = []
                for fete in j.fetes {
                    if let chaine = Libelles.res("fete_" + fete) { fetes.append(Libelle(chaine)) }
                }
                cases.append(CalendrierCase(date: d,
                                            haut: civil ? quantieme : hebreu,
                                            bas: civil ? hebreu : quantieme,
                                            aujourdhui: d == aujourdhui,
                                            choisie: d == choisi,
                                            chome: j.chome,
                                            fete: !j.fetes.isEmpty,
                                            dateHebraique: j.dateHebraique,
                                            fetes: fetes))
            }
            semaines.append(CalendrierSemaine(id: i, cases: cases))
        }
        return semaines
    }

    /// « Aujourd'hui », sous la grille : 15 pt, gras, couleur de la marque, centré.
    public var aujourdhuiLibelle: Libelle {
        Libelle("calendrier_aujourdhui")
    }

    // MARK: Le jour choisi

    public var contexte: ZmanimContexte {
        ZmanimContexte(reglages: magasin.reglages, fuseauTelephone: horloge.fuseau, langue: langue, sources: sources)
    }

    /// La carte du jour choisi ; Levana, hilloula et halakha s'y ajoutent, dans cet ordre, après les ajouts et
    /// avant le lien de partage.
    public var carte: ZmanimCarteJour {
        ZmanimVueJour.carte(choisi, contexte)
    }

    public var levana: ZmanimLevana? {
        ZmanimVueJour.levana(choisi, contexte)
    }

    public var hilloula: ZmanimHilloula? {
        ZmanimVueJour.hilloula(choisi, contexte)
    }

    public var halakha: ZmanimHalakha? {
        ZmanimVueJour.halakha(choisi, contexte)
    }

    /// Un jour passé ou aujourd'hui (AjoutTemps.possible, 16/10) : « Ajouter du temps fait hors du téléphone »,
    /// sous la carte (15 pt, gras, couleur de la marque, centré, 48 pt de haut), qui ouvre `routeAjouterTemps`.
    /// nil pour un jour à venir.
    public var ajouterTemps: Libelle? {
        choisi <= horloge.aujourdhui ? Libelle("jour_ajouter_temps") : nil
    }

    public var routeAjouterTemps: ZmanimRoute {
        .ajouterTemps(choisi)
    }

    /// Les horaires du jour choisi ; vides sans lieu.
    public var lignes: [ZmanimLigne] {
        ZmanimVueJour.lignes(choisi, contexte)
    }

    public var sansLieu: Bool {
        magasin.reglages.lieuZmanim == nil
    }

    public var invitationLieu: Libelle {
        Libelle("zmanim_sans_lieu")
    }

    public var choisirLieuLibelle: Libelle {
        Libelle("zmanim_choisir_lieu")
    }

    public var pied: [Libelle] {
        ZmanimVueJour.pied
    }

    /// Le contenu de l'image de partage du jour choisi.
    public var partage: PartageContenu {
        PartageContenu.pour(choisi, contexte)
    }

    // MARK: Les actions

    /// À chaque apparition : lit les contenus la première fois ; laissé ouvert jusqu'au lendemain (bug du 02/11),
    /// l'écran qui montrait le jour d'alors passe à aujourd'hui, un autre jour choisi exprès reste affiché.
    public func apparaitre() async {
        if !charge {
            sources = await ZmanimSources.lire(contenus: contenus, hilloulot: tableHilloulot)
            charge = true
        }
        let aujourdhui = horloge.aujourdhui
        if let avant = quitteLe, avant != aujourdhui, choisi == avant {
            choisi = aujourdhui
            mois = CalendrierModele.premierDuMois(aujourdhui)
            moisHebreu = nil
        }
        quitteLe = nil
        await choixLieu?.charger()
    }

    /// L'écran est quitté (onPause).
    public func disparaitre() {
        quitteLe = horloge.aujourdhui
    }

    /// Une case touchée : son jour devient le jour choisi ; le mois affiché ne change pas.
    public func choisir(_ jour: JourCivil) {
        choisi = jour
    }

    /// « Aujourd'hui » : le jour et son mois.
    public func allerAujourdhui() {
        let aujourdhui = horloge.aujourdhui
        choisi = aujourdhui
        mois = CalendrierModele.premierDuMois(aujourdhui)
        moisHebreu = nil
    }

    /// Le choix de la vue (Store.setCalendrierCivil) : le mois affiché redevient celui du jour choisi.
    public func basculer(civil: Bool) async throws {
        mois = CalendrierModele.premierDuMois(choisi)
        moisHebreu = nil
        try await magasin.modifierReglages { $0.setCalendrierCivil(civil) }
    }

    /// « ‹ » : le mois précédent (civil ou hébreu, selon la vue).
    public func moisPrecedent() {
        decaler(-1)
    }

    /// « › » : le mois suivant.
    public func moisSuivant() {
        decaler(1)
    }

    private func decaler(_ sens: Int) {
        if civil {
            mois = CalendrierModele.moisVoisin(mois, sens)
        } else {
            moisHebreu = JourAffiche.moisHebreuVoisin(debutHebreu, sens: sens)
        }
    }

    /// La carte des horaires sans lieu : le choix du lieu.
    public func montrerChoixLieu() {
        choixLieu?.montrer()
    }

    // MARK: Les règles

    /// Le 1er du mois civil d'un jour (`YearMonth.from`).
    public static func premierDuMois(_ jour: JourCivil) -> JourCivil {
        jour.plus(jours: 1 - jour.jour)
    }

    /// Le 1er du mois civil `sens` mois plus loin (`YearMonth.plusMonths`).
    public static func moisVoisin(_ premier: JourCivil, _ sens: Int) -> JourCivil {
        let rang = premier.annee * 12 + (premier.mois - 1) + sens
        let annee = Kotlin.floorDiv(rang, 12)
        let mois = Kotlin.floorMod(rang, 12) + 1
        return JourCivil(annee: annee, mois: mois, jour: 1) ?? premier
    }
}
