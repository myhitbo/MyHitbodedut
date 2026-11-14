import Foundation

/// Ce que le jour change à la lecture du siddour (SiddurJour.kt, demande du 10/10) : les ajouts du jour
/// mis en évidence, les autres repliés derrière une flèche, jamais retirés. Les annotations viennent de
/// `siddur_annotations.json` (tools/siddur_annotations.py) ; les conditions, de CalendrierJuif. Le même
/// code existe côté web (web/src/js/siddur-jour.js).
public enum SiddurJour {

    private typealias C = CalendrierJuif.C

    public enum Sorte: String, Sendable {
        case bloc, section, indice, renvoi, seul
    }

    public struct Annotation: Sendable, Equatable {
        public let sorte: Sorte
        public let section: Int
        public let bloc: Int?
        /// Clé de CalendrierJuif.C ; « ! » devant : quand la clé est fausse.
        public let condition: String
        /// Le début du texte annoté, pour vérifier qu'il n'a pas bougé.
        public let empreinte: String
        /// Pour un indice : la variante à signaler (« המלך הקדוש ») ; pour une carte « seul », son texte.
        public let texte: String?
        /// Pour un bloc : son groupe, et la condition qui ouvre ou replie le groupe.
        public let groupe: Int?
        public let racine: String?
        /// Un libellé propre (« ajout_anenou_officiant »), sinon celui de la condition.
        public let libelle: String?
        /// Pour un renvoi : l'identifiant du texte à ouvrir (« hallel »).
        public let cible: String?
        /// Pour une carte « seul » : la consigne qui précède son texte.
        public let consigne: String?
        /// Pour un indice : le passage brut du bloc, replié hors du jour (« המלך הקדוש », 28/10).
        public let retire: String?

        public init(sorte: Sorte, section: Int, bloc: Int?, condition: String, empreinte: String, texte: String? = nil,
                    groupe: Int? = nil, racine: String? = nil, libelle: String? = nil, cible: String? = nil,
                    consigne: String? = nil, retire: String? = nil) {
            self.sorte = sorte
            self.section = section
            self.bloc = bloc
            self.condition = condition
            self.empreinte = empreinte
            self.texte = texte
            self.groupe = groupe
            self.racine = racine
            self.libelle = libelle
            self.cible = cible
            self.consigne = consigne
            self.retire = retire
        }
    }

    /// Les annotations d'un nusah : par identifiant de texte, dans l'ordre du fichier.
    public struct Annotations: Sendable, Equatable {
        public let textes: [String]
        public let parTexte: [String: [Annotation]]

        public subscript(id: String) -> [Annotation]? { parTexte[id] }
    }

    /// `parse(json, nusah)` : les annotations d'un nusah ; aucune s'il n'est pas dans le fichier.
    public static func parse(_ json: String, nusah: Nusah) throws -> Annotations {
        guard let racine = try ObjetJSON(texte: json).objet(nusah.rawValue) else { return Annotations(textes: [], parTexte: [:]) }
        var parTexte: [String: [Annotation]] = [:]
        for cle in racine.cles {
            let liste = racine.tableau(cle) ?? []
            parTexte[cle] = liste.indices.compactMap { i in liste.objet(i).map(annotation) }
        }
        return Annotations(textes: racine.cles, parTexte: parTexte)
    }

    private static func annotation(_ a: ObjetJSON) -> Annotation {
        func texte(_ cle: String) -> String? {
            let t = a.texte(cle)
            return t.estBlanc ? nil : t
        }
        let sorte: Sorte = switch a.texte("sorte") {
        case "section": .section
        case "indice": .indice
        case "renvoi": .renvoi
        case "seul": .seul
        default: .bloc
        }
        return Annotation(sorte: sorte, section: a.entier("s"), bloc: a.a("b") ? a.entier("b") : nil,
                          condition: a.texte("si"), empreinte: a.texte("empreinte"), texte: texte("texte"),
                          groupe: a.a("g") ? a.entier("g") : nil, racine: texte("racine"), libelle: texte("libelle"),
                          cible: texte("cible"), consigne: texte("consigne"), retire: texte("retire"))
    }

    public enum Style: Int, Sendable {
        case normal, duJour, hors
    }

    /// Une ligne de la lecture, le jour donné.
    public enum Ligne: Sendable, Equatable {
        case titre(texte: String, fr: String?, en: String?)
        case bloc(SiddurBloc, Style)
        /// « Aujourd'hui · Ya'alé véyavo », au-dessus d'un ajout mis en évidence ; `libelle` : la clé de chaîne.
        case etiquette(condition: String, libelle: String)
        /// « Aujourd'hui : המלך הקדוש », sous un bloc qui mêle une variante.
        case indice(String)
        /// « Aujourd'hui · Hallel › » : le texte à dire ici ce jour-là, ouvert d'un geste ; `cible` : son identifiant.
        case renvoi(condition: String, cible: String)
        /// Qui prie seul (19/10) : la braïta à la place de Barekhou, ou où la dire ; la consigne avant.
        case seul(texte: String, consigne: String?)
        /// Un ajout hors du jour, replié ; `ouvert` quand on l'a déplié.
        case replie(cle: String, condition: String, ouvert: Bool, libelle: String)
    }

    private struct Place: Hashable {
        let section: Int
        let bloc: Int?
    }

    /// Les lignes d'un texte le jour où valent `conditionsDuJour`. Un ajout du jour est précédé de son
    /// étiquette ; un ajout hors du jour tient en une ligne repliée, et ses blocs suivent si sa clé est
    /// dans `ouverts`. Dans un ajout du jour, une variante d'un autre jour (« בחוה״מ פסח » un Roch
    /// 'Hodech) reste lisible, estompée. `sansTahanounFinTichri` : par défaut, `nusah == .edot`.
    public static func lignes(_ texte: SiddurTexte, _ annotations: [Annotation], _ conditionsDuJour: Set<String>,
                              ouverts: Set<String> = [], nusah: Nusah = .edot, enIsrael: Bool = false,
                              sansTahanounFinTichri: Bool? = nil, sud: Bool = false) -> [Ligne] {
        let conditions = conditionsPour(nusah, enIsrael: enIsrael, conditionsDuJour,
                                        sansTahanounFinTichri: sansTahanounFinTichri, sud: sud)
        func nom(_ a: Annotation, _ condition: String) -> String { libelleJour(a.libelle, condition, nusah, conditions) }

        // associateBy de Kotlin : la dernière l'emporte ; groupBy : l'ordre du fichier est gardé.
        var sections: [Int: Annotation] = [:]
        var blocs: [Place: Annotation] = [:]
        var indices: [Place: [Annotation]] = [:]
        var renvois: [Place: [Annotation]] = [:]
        var seuls: [Place: [Annotation]] = [:]
        for a in annotations {
            switch a.sorte {
            case .section: sections[a.section] = a
            case .bloc: if let b = a.bloc { blocs[Place(section: a.section, bloc: b)] = a }
            case .indice: if let b = a.bloc { indices[Place(section: a.section, bloc: b), default: []].append(a) }
            // Les renvois et les cartes du jour seulement : hors du jour, rien (le texte renvoyé n'est pas d'ici).
            case .renvoi:
                if a.cible != nil && vrai(a.condition, conditions) { renvois[Place(section: a.section, bloc: a.bloc), default: []].append(a) }
            case .seul:
                if a.texte != nil && vrai(a.condition, conditions) { seuls[Place(section: a.section, bloc: a.bloc), default: []].append(a) }
            }
        }

        var sortie: [Ligne] = []
        func seul(_ si: Int, _ bi: Int) {
            for a in seuls[Place(section: si, bloc: bi)] ?? [] { sortie.append(.seul(texte: a.texte ?? "", consigne: a.consigne)) }
        }
        func renvoyer(_ si: Int, _ bi: Int?) {
            for a in renvois[Place(section: si, bloc: bi)] ?? [] { sortie.append(.renvoi(condition: a.condition, cible: a.cible ?? "")) }
        }

        for (si, s) in texte.sections.enumerated() {
            // Une section seule porte déjà le nom du texte : pas de titre répété.
            if texte.sections.count > 1 && !s.titre.estBlanc { sortie.append(.titre(texte: s.titre, fr: s.titreFr, en: s.titreEn)) }
            if let section = sections[si] {
                if vrai(section.condition, conditions) {
                    sortie.append(.etiquette(condition: section.condition, libelle: nom(section, section.condition)))
                    for b in s.blocs { sortie.append(.bloc(b, .duJour)) }
                } else {
                    let cle = "§\(si)"
                    sortie.append(.replie(cle: cle, condition: section.condition, ouvert: ouverts.contains(cle),
                                          libelle: nom(section, section.condition)))
                    if ouverts.contains(cle) { for b in s.blocs { sortie.append(.bloc(b, .hors)) } }
                }
                renvoyer(si, nil)
                continue
            }
            var i = 0
            while i < s.blocs.count {
                guard let a = blocs[Place(section: si, bloc: i)] else {
                    // Une variante enchâssée hors du jour (המלך הקדוש, מוריד הטל…) : retirée du bloc, et une
                    // ligne repliée la rend d'un geste (demande du 28/10).
                    let ind = indices[Place(section: si, bloc: i)] ?? []
                    let horsJour = ind.filter { $0.retire != nil && !vrai($0.condition, conditions) }
                    let cleVariante = "v\(si):\(i)"
                    let ouverte = ouverts.contains(cleVariante)
                    var bloc = s.blocs[i]
                    var reduitFait = false
                    if !ouverte {
                        let reduit = horsJour.reduce(bloc.texte) { t, v in sansPremiere(t, v.retire ?? "") }.rogne
                        if !reduit.egalUnites(bloc.texte) {
                            bloc = SiddurBloc(texte: reduit, consigne: bloc.consigne, fr: bloc.fr, en: bloc.en)
                            reduitFait = true
                        }
                    }
                    sortie.append(.bloc(bloc, .normal))
                    // Le texte du jour se lit dans le bloc même ; l'ancien « Aujourd'hui : … » ne reste que
                    // pour les variantes qu'on ne sait pas replier.
                    for v in ind where v.texte != nil && v.retire == nil && vrai(v.condition, conditions) {
                        sortie.append(.indice(v.texte ?? ""))
                    }
                    if let v = horsJour.first, ouverte || reduitFait {
                        sortie.append(.replie(cle: cleVariante, condition: v.condition, ouvert: ouverte, libelle: nom(v, v.condition)))
                    }
                    seul(si, i)
                    renvoyer(si, i)
                    i += 1
                    continue
                }
                var membres: [(SiddurBloc, Annotation)] = []
                while i < s.blocs.count, let m = blocs[Place(section: si, bloc: i)], m.groupe == a.groupe {
                    membres.append((s.blocs[i], m))
                    i += 1
                }
                let racine = a.racine ?? a.condition
                if vrai(racine, conditions) {
                    sortie.append(.etiquette(condition: racine, libelle: nom(a, racine)))
                    for (b, m) in membres { sortie.append(.bloc(b, vrai(m.condition, conditions) ? .duJour : .hors)) }
                } else {
                    let cle = "\(si):\(a.groupe.map(String.init) ?? "null")"
                    sortie.append(.replie(cle: cle, condition: racine, ouvert: ouverts.contains(cle), libelle: nom(a, racine)))
                    if ouverts.contains(cle) { for (b, _) in membres { sortie.append(.bloc(b, .hors)) } }
                }
                seul(si, i - 1)
            }
            renvoyer(si, nil)
        }
        return sortie
    }

    /// `replaceFirst` de Kotlin sur un texte : la première occurrence, en unités UTF-16, retirée.
    private static func sansPremiere(_ texte: String, _ motif: String) -> String {
        guard let p = texte.positionUnites(de: motif) else { return texte }
        return texte.premieresUnites(p) + texte.sansPremieresUnites(p + motif.utf16.count)
    }

    /// Les conditions du jour pour un nusah. Les jours de bascule ont les deux formules ; hors d'Israël,
    /// les Ashkénazes ne disent pas Morid hatal (Rema, O.H. 114:3) ; au sud, les Edot disent מוריד הטל
    /// toute l'année, jamais « מוריד הגשם » (Yalkut Yosef, O.H. 117:19) ; sans Ta'hanoun de la fin de
    /// Tichri, coutume des Edot, au choix en Sfard (par défaut : `nusah == .edot`).
    public static func conditionsPour(_ nusah: Nusah, enIsrael: Bool, _ conditions: Set<String>,
                                      sansTahanounFinTichri: Bool? = nil, sud: Bool = false) -> Set<String> {
        var c = conditions
        if c.contains(C.basculePluie) { c.formUnion([C.machivHarouah, C.moridHatal]) }
        if nusah == .ashkenaz && !enIsrael { c.remove(C.moridHatal) }
        if sud && nusah == .edot && c.contains(C.machivHarouah) {
            c.remove(C.machivHarouah)
            c.insert(C.moridHatal)
        }
        if (sansTahanounFinTichri ?? (nusah == .edot)) && c.contains(C.finTichri) {
            c.subtract([C.tahanounChaharit, C.tahanounMinha, C.lundiJeudi])
        }
        if avinouMalkenou(conditions) { c.insert(C.avinouMalkenou) }
        return c
    }

    /// Avinou malkénou (Ashkenaz, Sfard) : les jeûnes publics sauf le 9 Av et les dix jours de
    /// pénitence, Roch Hachana et Kippour compris, jamais le Chabbat ; la veille de Kippour un
    /// vendredi aussi (Rema O.H. 604:2).
    public static func avinouMalkenou(_ conditions: Set<String>) -> Bool {
        if conditions.contains(C.chabbat) { return false }
        if conditions.contains(C.erevKippourVendredi) { return true }
        if conditions.contains(C.jeune) && !conditions.contains(C.tichaBeav) { return true }
        return conditions.contains(C.asseretYemeiTechouva)
            && (conditions.contains(C.tahanounChaharit) || conditions.contains(C.rochHachana) || conditions.contains(C.kippour))
    }

    /// Le libellé d'un ajout un jour donné : celui de l'annotation s'il en a un ; pour l'annonce du
    /// Hallel, complet ou partiel, et la bénédiction du Hallel partiel selon le nusah (O.H. 422:2) ;
    /// chez les Edot, toute la 9ᵉ bénédiction (ברך עלינו / ברכנו, demande du 28/10).
    public static func libelleJour(_ libelleAnnotation: String?, _ condition: String, _ nusah: Nusah,
                                   _ conditions: Set<String>) -> String {
        if let libelleAnnotation { return libelleAnnotation }
        if condition == C.hallel { return libelleHallel(nusah, conditions) ?? libelle(condition) }
        let nie = condition.hasPrefix("!")
        if nusah == .edot && (nie ? String(condition.dropFirst()) : condition) == C.talOumatar {
            return nie ? "ajout_barkhenou" : "ajout_barekh_alenou"
        }
        if nusah == .edot && condition == "berakha" { return "ajout_barkhenou" }
        return libelle(condition)
    }

    /// Hallel complet, ou partiel avec ou sans bénédiction selon le nusah (O.H. 422:2) ; nil hors Hallel.
    public static func libelleHallel(_ nusah: Nusah, _ conditions: Set<String>) -> String? {
        if conditions.contains(C.hallelComplet) { return "ajout_hallel_complet" }
        if !conditions.contains(C.hallel) { return nil }
        return nusah == .edot ? "ajout_hallel_partiel_sans_berakha" : "ajout_hallel_partiel_avec_berakha"
    }

    /// Une condition vaut ce jour : sa clé est là, ou, niée (« ! » devant), elle manque.
    public static func vrai(_ condition: String, _ conditions: Set<String>) -> Bool {
        condition.hasPrefix("!") ? !conditions.contains(String(condition.dropFirst())) : conditions.contains(condition)
    }

    private static let fetes: Set<String> = ["pessah", "soukkot", "chavouot", "roch_hachana", "chemini_atseret", "hanouka", "pourim"]

    /// Le nom de la chaîne qui nomme une condition, dans les trois langues.
    public static func libelle(_ condition: String) -> String {
        let c = condition.hasPrefix("!") ? String(condition.dropFirst()) : condition
        if condition.hasPrefix("!tahanoun") { return "ajout_sans_tahanoun" }
        if c.hasPrefix("tahanoun") { return "ajout_tahanoun" }
        if c == "kippour" { return "fete_yom_kippour" }
        // « אומרים כאן הלל » : le Hallel, complet ou non selon le jour.
        if c == "hallel" { return "ajout_hallel_annonce" }
        if c.hasPrefix("embolismique") { return "ajout_embolismique" }
        if fetes.contains(c) { return "fete_\(c)" }
        return "ajout_\(c)"
    }

    private static let balise = ExpressionReguliere("<[^>]+>")
    private static let voyelles = ExpressionReguliere("[\\u0591-\\u05C7]")
    /// `(?U)\s` de Java : les blancs d'Unicode (la fine U+2009 du siddour Edot compte), comme `\s` de Python et de JS.
    private static let blancs = ExpressionReguliere("[\\p{White_Space}]+")

    /// Comme tools/siddur_annotations.py : sans balises ni voyelles, quarante unités UTF-16.
    public static func empreinte(_ texte: String) -> String {
        let sansBalises = balise.remplace(texte, par: " ")
        let sansVoyelles = voyelles.remplace(sansBalises, par: "")
        return blancs.remplace(sansVoyelles, par: " ").rogne.premieresUnites(40)
    }
}

/// Le texte que l'heure suggère, en tête de la liste du siddour (SiddurMoment) : une indication
/// d'après l'horloge, non un horaire de zmanim.
public enum SiddurMoment {
    public static func suggestion(heure: Int, minute: Int) -> String {
        let minutes = heure * 60 + minute
        switch minutes {
        case ..<(5 * 60): return "tikoun_hatsot"
        case ..<(6 * 60 + 30): return "birkot_hachahar"
        case ..<(12 * 60 + 30): return "chaharit"
        case ..<(18 * 60 + 30): return "minha"
        case ..<(22 * 60 + 30): return "arvit"
        default: return "chema_coucher"
        }
    }

    /// La Méguila d'Esther avec la prière (13/10) : sous Arvit la nuit qui ouvre Pourim (le jour hébreu
    /// de demain), sous Cha'harit le jour même. Dans une ville murée, le 15 Adar ; quand il tombe un
    /// Chabbat (Pourim mechoulach), la Méguila se lit le vendredi 14.
    public static func megila(_ moment: String?, _ aujourdhui: JourCivil, israel: Bool, mukafChoma: Bool) -> Bool {
        let jour: JourCivil
        switch moment ?? "" {
        case "chaharit": jour = aujourdhui
        case "arvit": jour = aujourdhui.plus(jours: 1)
        default: return false
        }
        let fetes = CalendrierJuif.jour(jour, enIsrael: israel, mukafChoma: mukafChoma).fetes
        if fetes.contains("pourim") || (fetes.contains("pourim_jerusalem") && jour.jourDeSemaine != 7) { return true }
        return mukafChoma && fetes.contains("pourim_ailleurs") && jour.jourDeSemaine == 6
    }

    /// Birkat haIlanot (14/10) : une fois l'an, en voyant des arbres fruitiers en fleur, en Nissan dans
    /// l'hémisphère nord (Choulhan Aroukh O.H. 226). `latitude` : celle du lieu des zmanim, ou nil.
    public static func ilanot(_ date: JourCivil, latitude: Double?) -> Bool {
        let mois = CalendrierJuif.dateJuive(date).mois
        if let latitude, latitude < 0 { return moisIlanotSud(mois) }
        return mois == CalendrierJuif.Mois.nissan
    }

    /// L'hémisphère sud (14/10) : on bénit quand les arbres y fleurissent (Har Tsvi O.H. 1:118 ; Min'hat
    /// Yits'hak 10:16) ; en Australie en Eloul et Tichri. La floraison locale prime sur le mois.
    public static func moisIlanotSud(_ mois: Int) -> Bool {
        mois == CalendrierJuif.Mois.eloul || mois == CalendrierJuif.Mois.tichri
    }

    /// Le hassid qui accompagne la suggestion, parmi les illustrations de l'application (nom de l'image).
    public static func illustration(_ id: String) -> String {
        switch id {
        case "tikoun_hatsot": "char_praying"
        case "birkot_hachahar": "char_welcome"
        // Les tefillin et le lit (planche du 11/10).
        case "chaharit": "char_tefillin"
        case "chema_coucher": "scene_sleeping"
        // L'aéroport, décor gardé (demande du 11/10).
        case "tefilat_haderekh": "scene_airport"
        case "minha": "char_standing_back"
        case "arvit": "char_tehilim"
        default: "char_thinking"
        }
    }
}
