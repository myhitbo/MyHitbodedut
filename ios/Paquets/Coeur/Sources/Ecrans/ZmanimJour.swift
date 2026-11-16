import Foundation
import Coeur

// Ce qu'ont en commun l'onglet Zmanim et le calendrier (VueJour.kt, 10/10) : la carte d'un jour (date hébraïque,
// fêtes, ajouts), la liste de ses horaires avec leur méthode, Birkat haLevana, la hilloula et la halakha du jour,
// le pied. Ce qui est montré vient des règles de Coeur (JourAffiche, CalendrierJuif, Levana, Hilloulot,
// YalkutYosef, Halakha) ; ici, ce que la vue affiche, en `Libelle` et en valeurs (jours, heures civiles), sans
// aucune mise en forme : la vue met en forme les dates dans la langue de l'app.
//
// Les deux modèles (ZmanimModele, CalendrierModele) lisent les réglages du `Magasin` à chaque fois et
// construisent un `ZmanimContexte` ; les fonctions de `ZmanimVueJour` n'ont aucun état.

// MARK: Les routes

/// Les écrans qu'ouvrent l'onglet Zmanim et le calendrier, avec leurs paramètres.
public enum ZmanimRoute: Sendable, Hashable {
    /// HalakhaActivity, `EXTRA_DATE` : la halakha de ce jour.
    case halakha(JourCivil)
    /// HilloulotActivity, `EXTRA_DATE` : les hilloulot de ce jour.
    case hilloulot(JourCivil)
    /// CalendrierActivity, sans paramètre : il s'ouvre sur aujourd'hui.
    case calendrier
    /// VolActivity : les zmanim en vol.
    case vol
    /// BoussoleActivity : la direction de Jérusalem.
    case boussole
    /// SiddurLectureActivity.ouvrir(c, id) : un texte du siddour dans le noussa'h choisi (« birkat_halevana »).
    case siddour(String)
    /// AjoutTemps.ouvrir(activity, date) : le dialogue « Ajouter du temps fait hors du téléphone » pour ce jour.
    case ajouterTemps(JourCivil)
}

// MARK: Les contenus lus

/// `hilloulot.json`, lu à la première demande puis gardé (Hilloulot.table). À rejoindre `ContenusApp` quand
/// Hilloulot y sera intégré (voir Contenus.swift), comme `HilloulotContenus` de l'écran des hilloulot.
public actor ZmanimHilloulotTable {

    private let lire: ContenusApp.Lecteur
    private var lue: Hilloulot.Table?

    public init(lecteur: @escaping ContenusApp.Lecteur) {
        lire = lecteur
    }

    /// Les contenus d'un dossier : `Contenu/` du paquet de l'app, ou `ios/Ressources/Contenu` du dépôt.
    public init(dossier: URL) {
        lire = ContenusApp.lecteur(dossier: dossier)
    }

    /// La table sans les biographies. Lève si le fichier manque ou ne se lit pas ; il sera relu à la demande
    /// suivante.
    public func table() throws -> Hilloulot.Table {
        if let lue { return lue }
        guard let donnees = try lire("hilloulot.json") else { throw ErreurContenu.absent("hilloulot.json") }
        let table = try Hilloulot.parse(donnees)
        lue = table
        return table
    }
}

/// Les contenus que la carte du jour et le choix du lieu lisent : les villes, les deux livres de la halakha, la
/// table des hilloulot. Un contenu qui n'a pu être lu reste vide : son bloc ne paraît pas (Android : la carte
/// n'a rien à montrer).
public struct ZmanimSources: Sendable {
    /// `villes.json`, dans l'ordre du fichier (celui de la liste du choix du lieu).
    public var villes: [Ville]
    public var yalkut: YalkutYosef.Livre?
    public var benIshHai: Halakha.Livre?
    public var hilloulot: Hilloulot.Table?

    public init(villes: [Ville] = [], yalkut: YalkutYosef.Livre? = nil, benIshHai: Halakha.Livre? = nil,
                hilloulot: Hilloulot.Table? = nil) {
        self.villes = villes
        self.yalkut = yalkut
        self.benIshHai = benIshHai
        self.hilloulot = hilloulot
    }

    /// Rien de lu : ni ville, ni halakha, ni hilloula.
    public static let vide = ZmanimSources()

    /// Lit chaque contenu à part : l'un qui manque n'empêche pas les autres.
    public static func lire(contenus: ContenusApp?, hilloulot: ZmanimHilloulotTable?) async -> ZmanimSources {
        var sources = ZmanimSources()
        if let contenus {
            sources.villes = (try? await contenus.villes()) ?? []
            sources.yalkut = try? await contenus.yalkutYosef()
            sources.benIshHai = try? await contenus.benIshHai()
        }
        if let hilloulot {
            sources.hilloulot = try? await hilloulot.table()
        }
        return sources
    }
}

/// Ce dont dépend ce qu'on montre d'un jour : les réglages (lieu, Israël ou diaspora, ville murée, noussa'h,
/// Ta'hanoun de fin de Tichri, allumage, ce qui est masqué), le fuseau du téléphone, la langue de l'app et les
/// contenus lus.
public struct ZmanimContexte: Sendable {
    public let reglages: Reglages
    /// `ZoneId.systemDefault()` : Israël ou diaspora sans réglage, et le fuseau de Levana sans lieu.
    public let fuseauTelephone: Fuseau
    /// « fr », « en » ou « he » : la virgule décimale des méthodes.
    public let langue: String
    public let sources: ZmanimSources

    public init(reglages: Reglages, fuseauTelephone: Fuseau, langue: String, sources: ZmanimSources) {
        self.reglages = reglages
        self.fuseauTelephone = fuseauTelephone
        self.langue = langue
        self.sources = sources
    }

    /// Store.inIsrael : le réglage, sinon ce que dit le fuseau du téléphone.
    public var enIsrael: Bool {
        reglages.inIsrael(fuseauTelephone: fuseauTelephone.identifiant)
    }
}

// MARK: Ce qui s'affiche

/// La carte d'un jour (VueJour.carteJour) : l'illustration d'une fête ou de Chabbat, la date hébraïque, la date
/// civile, les fêtes, la paracha et l'omer, ce que le jour change aux prières, le lien de partage.
public struct ZmanimCarteJour: Sendable, Equatable {
    public let date: JourCivil
    /// L'illustration du jour de fête ou de Chabbat (`scene_sukkot`, `char_matsa`, `scene_hanukkah`,
    /// `char_purim`, `char_shabbat`) ; nil un jour ordinaire.
    public let illustration: String?
    /// « א׳ חשון תשפ״ז » : de droite à gauche, police hébraïque, en gras.
    public let dateHebraique: String
    /// Les fêtes, puis la paracha (« Paracha … »), puis l'omer de ce soir ; la vue les joint par
    /// `ZmanimVueJour.separateurMarques`. Vide : rien ne paraît.
    public let marques: [Libelle]
    /// « Dans les prières ».
    public let ajoutsTitre: Libelle
    /// Les ajouts, dans l'ordre de l'Amida ; joints par `ZmanimVueJour.separateurAjouts`.
    public let ajouts: [Libelle]
    /// « Rien de particulier », à la place des ajouts quand il n'y en a aucun.
    public let aucunAjout: Libelle?
    /// « Partager ce jour », suivi dans la vue de « ↗ ».
    public let partage: Libelle
}

/// Une ligne des horaires (VueJour.horaires) : le nom, l'heure à droite, la méthode dessous.
public struct ZmanimLigne: Sendable, Equatable, Identifiable {
    public var id: String { cle }
    /// « alot », « netz »… « allumage », « sortie ».
    public let cle: String
    /// « Alot hacha'har » : `zman_<clé>`.
    public let nom: Libelle
    /// L'heure civile du lieu ; nil quand le zman n'a pas lieu ou ne se calcule pas (« — »).
    public let heure: DateHeure?
    /// « soleil à 16,1° sous l'horizon » ; « n'a pas lieu ce jour » ; « calcul impossible » ; nil si la méthode
    /// n'a pas de libellé (Android : un texte vide).
    public let methode: Libelle?
    /// L'allumage et la sortie : le nom et l'heure à la couleur de la marque, en gras.
    public let misEnAvant: Bool

    /// « 05:28 », les secondes tronquées comme `DateTimeFormatter.ofPattern("HH:mm")` ; « — » sans heure.
    public var heureTexte: String {
        guard let heure else { return "—" }
        let h = heure.heure, m = heure.minute
        return (h < 10 ? "0" : "") + String(h) + ":" + (m < 10 ? "0" : "") + String(m)
    }
}

/// La jauge du mois lunaire : un fil, la fenêtre en or (`ring_streak`), le soir du jour en point de la couleur
/// de la marque cerclé de la couleur des cartes. Chaque valeur va de 0 (molad) à 1 (molad suivant) ; en
/// hébreu, le mois va de droite à gauche.
public struct ZmanimJauge: Sendable, Equatable {
    public let debut: Float
    public let fin: Float
    public let point: Float
}

/// Birkat haLevana (VueJour.levana, 13/10 et 14/10).
public struct ZmanimLevana: Sendable, Equatable {
    /// La lune de ce soir (20 h), à dessiner (Levana.Dessin) : la part éclairée et le côté.
    public let lune: Levana.Lune
    /// Au sud de l'équateur, le dessin en miroir : le côté éclairé est à gauche quand elle croît.
    public let sud: Bool
    /// « Birkat haLevana » : 12 pt, gras, atténué.
    public let titre: Libelle
    /// « Dans 3 jours », « Possible ce soir », « Dernier soir » : 17 pt, gras.
    public let etat: Libelle
    /// Vrai : l'état à la couleur de la marque (ce soir, dernier soir) ; faux : à l'encre (dans n jours).
    public let etatMisEnAvant: Bool
    /// « Lune ce soir : 42 % éclairée, croissante ».
    public let luneTexte: Libelle
    /// La fenêtre, à l'heure du lieu : « Du <début> au <fin> » (`levana_fenetre`, chaque borne au format
    /// « EEE d MMM, HH:mm » de la langue de l'app), par `ZmanimLevana.fenetre(debut:fin:)`.
    public let debut: DateHeure
    public let fin: DateHeure
    /// Le motsaé Chabbat conseillé (« EEE d MMM »), par `ZmanimLevana.motsae(_:)` ; nil s'il n'y en a pas.
    public let motsae: JourCivil?
    /// « Pas avant la sortie de Kippour… » ou « … de Ticha bèAv » ; nil sinon.
    public let restriction: Libelle?
    public let jauge: ZmanimJauge
    /// « Choul'han Aroukh O.H. 426 ; Michna Beroura 426. Usage : … » : 11 pt, atténué.
    public let source: Libelle
    /// « Lire Birkat haLevana › » : un lien, qui ouvre `route`.
    public let lire: Libelle
    public let route: ZmanimRoute

    /// « Du … au … », les deux bornes déjà mises en forme par la vue.
    public static func fenetre(debut: String, fin: String) -> Libelle {
        Libelle("levana_fenetre", .texte(debut), .texte(fin))
    }

    /// « Conseillé : motsaé Chabbat … », le jour déjà mis en forme par la vue.
    public static func motsae(_ jour: String) -> Libelle {
        Libelle("levana_motsae", .texte(jour))
    }
}

/// La hilloula du jour (VueJour.blocHilloula) : cinq noms au plus, puis les autres et l'écran des hilloulot.
public struct ZmanimHilloula: Sendable, Equatable {
    /// « Hilloula du jour » : 12 pt, gras, atténué.
    public let titre: Libelle
    /// Les noms hébreux, un par ligne : 14 pt, de droite à gauche, police hébraïque, interligne 1,25.
    public let noms: [String]
    /// « ועוד אחד », suivi dans la vue de « › » : 12 pt, atténué, de droite à gauche, touchable (48 pt), ouvre
    /// `route` ; nil s'il n'y en a pas plus de cinq.
    public let autres: Libelle?
    /// « Toutes les hilloulot › » : un lien, qui ouvre `route`.
    public let tout: Libelle
    public let route: ZmanimRoute
}

/// Le début de la halakha du jour dans le livre choisi (VueJour.apercuHalakha).
public struct ZmanimApercuHalakha: Sendable, Equatable {
    /// « Yalkut Yosef, Kitsour Choul'han Aroukh » ou « Ben Ish 'Haï, paracha de la semaine ».
    public let livre: Libelle
    public let texte: String
}

/// La halakha du jour (VueJour.blocHalakha).
public struct ZmanimHalakha: Sendable, Equatable {
    /// « Halakha yomit », suivi dans la vue de « · » et du livre : 12 pt, gras, atténué.
    public let titre: Libelle
    public let livre: Libelle
    /// Le début : 16 pt, de droite à gauche, police hébraïque, quatre lignes au plus, « … » au bout.
    public let debut: String
    /// « Toute la halakha du jour › » : un lien, qui ouvre `route`.
    public let tout: Libelle
    public let route: ZmanimRoute
}

// MARK: Les règles de VueJour

public enum ZmanimVueJour {

    /// Entre les fêtes, la paracha et l'omer : deux espaces, un point médian, deux espaces.
    public static let separateurMarques = "  ·  "
    /// Entre les ajouts.
    public static let separateurAjouts = " · "

    /// Le pied (VueJour.pied) : la méthode est écrite sous chaque horaire ; la source des villes, comme CC-BY le
    /// demande. 12 pt, atténués, 6 pt entre les deux.
    public static let pied: [Libelle] = [Libelle("zmanim_a_valider"), Libelle("zmanim_source_villes")]

    /// La carte d'un jour (VueJour.carteJour), sans Levana, hilloula ni halakha : l'onglet Zmanim les pose sous
    /// les horaires, le calendrier dans la carte (`levana`, `hilloula`, `halakha`).
    public static func carte(_ date: JourCivil, _ c: ZmanimContexte) -> ZmanimCarteJour {
        let enIsrael = c.enIsrael
        let j = CalendrierJuif.jour(date, enIsrael: enIsrael, mukafChoma: c.reglages.mukafChoma)
        // L'omer se compte le soir, pour le jour hébreu qui commence : celui de demain.
        let omerCeSoir = CalendrierJuif.jour(date.plus(jours: 1), enIsrael: enIsrael).omer
        var marques: [Libelle] = []
        for fete in j.fetes {
            if let chaine = Libelles.res("fete_" + fete) { marques.append(Libelle(chaine)) }
        }
        if let paracha = j.paracha { marques.append(Libelle("zmanim_paracha", .texte(paracha))) }
        if omerCeSoir > 0 { marques.append(Libelle("zmanim_omer_ce_soir", .entier(omerCeSoir))) }
        let cles = JourAffiche.ajouts(j.conditions, nusah: c.reglages.siddurNusah, enIsrael: enIsrael,
                                      sansTahanounFinTichri: c.reglages.sansTahanounFinTichri,
                                      sud: c.reglages.hemisphereSud)
        var ajouts: [Libelle] = []
        for cle in cles {
            if let chaine = Libelles.res(cle) { ajouts.append(Libelle(chaine)) }
        }
        return ZmanimCarteJour(date: date,
                               illustration: JourAffiche.illustration(fetes: j.fetes, date: date),
                               dateHebraique: j.dateHebraique,
                               marques: marques,
                               ajoutsTitre: Libelle("zmanim_ajouts_titre"),
                               ajouts: ajouts,
                               aucunAjout: ajouts.isEmpty ? Libelle("zmanim_aucun_ajout") : nil,
                               partage: Libelle("partage_jour"))
    }

    /// Les horaires d'un jour (VueJour.horaires), allumage et sortie compris ; vide sans lieu (la carte invite
    /// alors à en choisir un).
    public static func lignes(_ date: JourCivil, _ c: ZmanimContexte) -> [ZmanimLigne] {
        guard let lieu = c.reglages.lieuZmanim else { return [] }
        let fuseau = Fuseau(lieu.fuseau)
        var lignes: [ZmanimLigne] = []
        for z in JourAffiche.horaires(lieu: lieu, date: date, enIsrael: c.enIsrael, minutes: c.reglages.allumage) {
            var heure: DateHeure?
            if z.statut == .ok, let instant = z.instant, let fuseau {
                heure = fuseau.dateHeure(millis: millis(instant))
            }
            let methode: Libelle?
            switch z.statut {
            case .ok:
                if let chaine = Libelles.res("zman_methode_" + z.methode.cle) {
                    methode = Libelle(chaine, .texte(parametre(z.methode.parametres, langue: c.langue)))
                } else {
                    methode = nil
                }
            case .absent:
                methode = Libelle("zmanim_absent")
            case .erreur:
                methode = Libelle("zmanim_erreur")
            }
            lignes.append(ZmanimLigne(cle: z.cle,
                                      nom: Libelle(Libelles.res("zman_" + z.cle) ?? z.cle),
                                      heure: heure,
                                      methode: methode,
                                      misEnAvant: z.cle == "allumage" || z.cle == "sortie"))
        }
        return lignes
    }

    /// L'usage de Birkat haLevana : celui choisi, sinon celui du noussa'h (14/10).
    public static func usageLevana(_ reglages: Reglages) -> Levana.Usage {
        reglages.levanaUsage.flatMap(Levana.Usage.init(rawValue:)) ?? Levana.Usage.duNusah(reglages.siddurNusah)
    }

    /// Birkat haLevana pour le soir de `date` (VueJour.levana), dans le fuseau du lieu (du téléphone sans lieu) ;
    /// nil quand elle est masquée dans les réglages.
    public static func levana(_ date: JourCivil, _ c: ZmanimContexte) -> ZmanimLevana? {
        guard c.reglages.levanaAffichee else { return nil }
        let lieu = c.reglages.lieuZmanim
        let zone = lieu.flatMap { Fuseau($0.fuseau) } ?? c.fuseauTelephone
        let usage = usageLevana(c.reglages)
        let f = Levana.fenetre(date, fuseau: zone, usage: usage)
        let soir = Levana.soir(date, fuseau: zone)
        let lune = Levana.phase(soir)
        let etat: Libelle
        let misEnAvant: Bool
        switch Levana.etat(f, date, fuseau: zone) {
        case .dans(let jours):
            etat = Libelle.pluriel("levana_dans", quantite: jours, .entier(jours))
            misEnAvant = false
        case .ceSoir:
            etat = Libelle("levana_ce_soir")
            misEnAvant = true
        case .dernierSoir:
            etat = Libelle("levana_dernier_soir")
            misEnAvant = true
        }
        // "${Math.round(lune.eclairage * 100)} %"
        let pourcent = Kotlin.arrondiLong(lune.eclairage * 100)
        let phase = Libelle(lune.croissante ? "levana_croissante" : "levana_decroissante")
        var restriction: Libelle?
        if let r = f.restriction {
            restriction = Libelle(r == .kippour ? "levana_kippour" : "levana_tisha")
        }
        return ZmanimLevana(lune: lune,
                            sud: (lieu?.latitude ?? 1.0) < 0,
                            titre: Libelle("levana_titre"),
                            etat: etat,
                            etatMisEnAvant: misEnAvant,
                            luneTexte: Libelle("levana_lune", .texte(String(pourcent) + " %"), .libelle(phase)),
                            debut: zone.dateHeure(millis: f.debut),
                            fin: zone.dateHeure(millis: f.fin),
                            motsae: Levana.motsaeChabbat(f, date, fuseau: zone),
                            restriction: restriction,
                            jauge: ZmanimJauge(debut: Levana.part(f, f.debut), fin: Levana.part(f, f.fin),
                                               point: Levana.part(f, soir)),
                            source: Libelle("levana_source", .libelle(Libelle(usage.libelle))),
                            lire: Libelle("levana_lire"),
                            route: .siddour("birkat_halevana"))
    }

    /// La hilloula du jour (VueJour.blocHilloula) ; nil si elle est masquée, si la table n'a pu être lue ou s'il
    /// n'y a personne ce jour-là.
    public static func hilloula(_ date: JourCivil, _ c: ZmanimContexte) -> ZmanimHilloula? {
        guard c.reglages.hilloulotAffichees, let table = c.sources.hilloulot else { return nil }
        let liste = Hilloulot.pour(table, date: date, enIsrael: c.enIsrael, ashkenaz: c.reglages.siddurNusah == .ashkenaz)
        if liste.isEmpty { return nil }
        let reste = liste.count - 5
        return ZmanimHilloula(titre: Libelle("hilloula_titre"),
                              noms: liste.prefix(5).map { $0.he },
                              autres: reste > 0 ? Libelle.pluriel("hilloula_autres", quantite: reste, .entier(reste)) : nil,
                              tout: Libelle("hilloulot_tout"),
                              route: .hilloulot(date))
    }

    /// Le début de la halakha du jour, dans le livre choisi (14/10) : le Yalkut Yosef d'abord, sinon le Ben Ish
    /// 'Haï ; nil s'il n'y en a pas.
    public static func apercuHalakha(_ date: JourCivil, enIsrael: Bool, source: Reglages.SourceHalakha,
                                     sources: ZmanimSources) -> ZmanimApercuHalakha? {
        if source.montreYalkut, let livre = sources.yalkut,
           let seif = YalkutYosef.pour(livre, date: date, israel: enIsrael).first {
            return ZmanimApercuHalakha(livre: Libelle("halakha_livre"), texte: seif.texte)
        }
        if source.montreBenIshHai, let livre = sources.benIshHai,
           let halakha = Halakha.pour(livre, date: date, enIsrael: enIsrael).first {
            return ZmanimApercuHalakha(livre: Libelle("halakha_ben_ish_hai"), texte: halakha.texte)
        }
        return nil
    }

    /// La halakha du jour (VueJour.blocHalakha) ; nil si elle est masquée ou s'il n'y en a pas.
    public static func halakha(_ date: JourCivil, _ c: ZmanimContexte) -> ZmanimHalakha? {
        guard c.reglages.halakhaAffichee,
              let apercu = apercuHalakha(date, enIsrael: c.enIsrael, source: c.reglages.sourceHalakha,
                                         sources: c.sources) else { return nil }
        return ZmanimHalakha(titre: Libelle("halakha_yomit_titre"), livre: apercu.livre, debut: apercu.texte,
                             tout: Libelle("halakha_tout"), route: .halakha(date))
    }

    /// Le paramètre d'une méthode dans la langue de l'app (`NumberFormat.getInstance(locale)`) : « 16.1 » se lit
    /// « 16,1 » en français ; ce qui n'est pas un nombre reste tel quel.
    public static func parametre(_ p: String, langue: String) -> String {
        guard Java.parseDouble(p) != nil, langue == "fr" else { return p }
        return p.replacingOccurrences(of: ".", with: ",")
    }

    /// Les millisecondes Unix d'un instant de KosherSwift, à la milliseconde près.
    static func millis(_ instant: Date) -> Int64 {
        Int64((instant.timeIntervalSince1970 * 1000).rounded())
    }
}
