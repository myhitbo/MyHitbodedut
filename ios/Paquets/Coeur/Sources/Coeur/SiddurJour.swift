import Foundation

/// Le siddour du jour (SiddurJour.kt) : ce que le nusah, le lieu et l'hémisphère changent aux
/// conditions du jour. Ici, la part dont le calendrier et l'onglet Zmanim ont besoin (tâche 10) ;
/// le reste (annotations, libellés, empreintes) viendra avec la tâche 11.
public enum SiddurJour {

    private typealias C = CalendrierJuif.C

    /// Les conditions du jour pour un nusah. Les jours de bascule ont les deux formules ; hors
    /// d'Israël, les Ashkénazes ne disent pas Morid hatal ; au sud, les Edot disent מוריד הטל toute
    /// l'année (Yalkut Yosef, O.H. 117:19) ; sans Ta'hanoun de la fin de Tichri, coutume des Edot,
    /// au choix en Sfard (par défaut : `nusah == .edot`).
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

    /// Hallel complet, ou partiel avec ou sans bénédiction selon le nusah (O.H. 422:2) ; nil hors Hallel.
    public static func libelleHallel(_ nusah: Nusah, _ conditions: Set<String>) -> String? {
        if conditions.contains(C.hallelComplet) { return "ajout_hallel_complet" }
        if !conditions.contains(C.hallel) { return nil }
        return nusah == .edot ? "ajout_hallel_partiel_sans_berakha" : "ajout_hallel_partiel_avec_berakha"
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
}

// MARK: Les annotations et les lignes du jour (SiddurJour.kt, tâche 11)

// Ce que le jour change à la lecture du siddour (demande du 10/10) : les ajouts du jour mis en
// évidence, les autres repliés derrière une flèche, jamais retirés. Les annotations viennent de
// siddur_annotations.json (tools/siddur_annotations.py) ; les conditions, de CalendrierJuif.
// Jugé par `Tests/Vecteurs/siddur_jour.json` (tools/vecteurs_ios/VecteursSiddurJour.kt).
extension SiddurJour {

    /// Ce qu'une annotation désigne : un bloc d'un groupe, une section entière, une variante enchâssée
    /// dans un bloc (« המלך הקדוש »), un renvoi vers un autre texte, une carte pour qui prie seul.
    public enum Sorte: String, Sendable, CaseIterable {
        case bloc, section, indice, renvoi, seul
    }

    /// Une annotation de siddur_annotations.json.
    public struct Annotation: Sendable, Equatable {
        public let sorte: Sorte
        public let section: Int
        public let bloc: Int?
        /// Clé de CalendrierJuif.C ; « ! » devant : quand la clé est fausse.
        public let condition: String
        /// Le début du texte annoté, pour vérifier qu'il n'a pas bougé.
        public let empreinte: String
        /// Pour un indice : la variante à signaler (« המלך הקדוש »).
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

    /// Les annotations d'un nusah, par identifiant de texte. Lu comme org.json d'Android : un nombre
    /// écrit en chaîne se lit, un champ facultatif vide ou blanc vaut nil, `null` y vaut « null » ; un
    /// nusah absent rend un dictionnaire vide ; un champ obligatoire absent ou illisible lève.
    public static func parse(_ json: String, _ nusah: Nusah) throws -> [String: [Annotation]] {
        guard let racine = try ObjetJSON(texte: json).objet(nusah.rawValue) else { return [:] }
        var sortie: [String: [Annotation]] = [:]
        for cle in racine.cles {
            guard let elements = racine.tableau(cle) else {
                throw ErreurJSON(position: 0, raison: "« \(cle) » n'est pas un tableau")
            }
            var annotations: [Annotation] = []
            annotations.reserveCapacity(elements.count)
            for element in elements {
                guard case .objet(let a) = element else {
                    throw ErreurJSON(position: 0, raison: "« \(cle) » : une annotation n'est pas un objet")
                }
                annotations.append(try annotation(a))
            }
            sortie[cle] = annotations
        }
        return sortie
    }

    private static func annotation(_ a: ObjetJSON) throws -> Annotation {
        let nom = try chaineRequise(a, "sorte")
        let sorte: Sorte
        if nom.egalUnites("section") {
            sorte = .section
        } else if nom.egalUnites("indice") {
            sorte = .indice
        } else if nom.egalUnites("renvoi") {
            sorte = .renvoi
        } else if nom.egalUnites("seul") {
            sorte = .seul
        } else {
            sorte = .bloc
        }
        return try Annotation(
            sorte: sorte,
            section: entierRequis(a, "s"),
            bloc: a.a("b") ? entierRequis(a, "b") : nil,
            condition: chaineRequise(a, "si"),
            empreinte: chaineRequise(a, "empreinte"),
            texte: texteOuNil(a, "texte"),
            groupe: a.a("g") ? entierRequis(a, "g") : nil,
            racine: texteOuNil(a, "racine"),
            libelle: texteOuNil(a, "libelle"),
            cible: texteOuNil(a, "cible"),
            consigne: texteOuNil(a, "consigne"),
            retire: texteOuNil(a, "retire"))
    }

    /// `getString` d'org.json : le texte de la valeur (« null » pour null) ; lève si la clé manque.
    private static func chaineRequise(_ o: ObjetJSON, _ cle: String) throws -> String {
        guard let valeur = o[cle] else { throw ErreurJSON(position: 0, raison: "« \(cle) » manque") }
        return valeur.commeTexte
    }

    /// `getInt` d'org.json : un nombre (tronqué), ou une chaîne qui se lit comme un nombre ; lève sinon.
    private static func entierRequis(_ o: ObjetJSON, _ cle: String) throws -> Int {
        guard let valeur = o[cle]?.commeEntier else { throw ErreurJSON(position: 0, raison: "« \(cle) » n'est pas un entier") }
        return Int(valeur)
    }

    /// `optString(cle, "").ifBlank { null }`.
    private static func texteOuNil(_ o: ObjetJSON, _ cle: String) -> String? {
        let texte = o.texte(cle, defaut: "")
        return texte.estBlanc ? nil : texte
    }

    /// Le style d'un bloc : ordinaire, ajout du jour mis en évidence, ajout d'un autre jour estompé.
    public enum Style: Sendable {
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
        /// Qui prie seul (19/10) : la braïta à la place de Barekhou, ou où la dire ; `consigne` avant.
        case seul(texte: String, consigne: String?)
        /// Un ajout hors du jour, replié ; `ouvert` quand on l'a déplié.
        case replie(cle: String, condition: String, ouvert: Bool, libelle: String)
    }

    /// Une place dans un texte : la section, et le bloc (nil pour la section entière).
    private struct Place: Hashable {
        let section: Int
        let bloc: Int?
    }

    /// Les lignes d'un texte le jour où valent `conditionsDuJour`. Un ajout du jour est précédé de son
    /// étiquette ; un ajout hors du jour tient en une ligne repliée, et ses blocs suivent si sa clé est
    /// dans `ouverts`. Dans un ajout du jour, une variante d'un autre jour (« בחוה״מ פסח » un Roch
    /// 'Hodech) reste lisible, estompée. `sansTahanounFinTichri` : nil pour la coutume du nusah.
    public static func lignes(_ texte: SiddurTexte, _ annotations: [Annotation], _ conditionsDuJour: Set<String>,
                              ouverts: Set<String> = [], nusah: Nusah = .edot, enIsrael: Bool = false,
                              sansTahanounFinTichri: Bool? = nil, sud: Bool = false) -> [Ligne] {
        let conditions = conditionsPour(nusah, enIsrael: enIsrael, conditionsDuJour,
                                        sansTahanounFinTichri: sansTahanounFinTichri, sud: sud)
        func nom(_ a: Annotation, _ condition: String) -> String {
            libelleJour(a.libelle, condition, nusah, conditions)
        }
        // Rangées comme le font associateBy (la dernière l'emporte) et groupBy (dans l'ordre) de Kotlin.
        var sections: [Int: Annotation] = [:]
        var blocs: [Place: Annotation] = [:]
        var indices: [Place: [Annotation]] = [:]
        var renvois: [Place: [Annotation]] = [:]
        var seuls: [Place: [Annotation]] = [:]
        for a in annotations {
            switch a.sorte {
            case .section:
                sections[a.section] = a
            case .bloc:
                // Un bloc annoté sans rang ne désigne rien (Android s'arrêterait sur `bloc!!`).
                if let b = a.bloc { blocs[Place(section: a.section, bloc: b)] = a }
            case .indice:
                if let b = a.bloc { indices[Place(section: a.section, bloc: b), default: []].append(a) }
            case .renvoi:
                // Les renvois du jour seulement : hors du jour, rien (le texte renvoyé n'est pas d'ici).
                if a.cible != nil && vrai(a.condition, conditions) {
                    renvois[Place(section: a.section, bloc: a.bloc), default: []].append(a)
                }
            case .seul:
                if a.texte != nil && vrai(a.condition, conditions) {
                    seuls[Place(section: a.section, bloc: a.bloc), default: []].append(a)
                }
            }
        }
        var sortie: [Ligne] = []
        func cartesSeul(_ si: Int, _ bi: Int) {
            for a in seuls[Place(section: si, bloc: bi)] ?? [] {
                if let t = a.texte { sortie.append(.seul(texte: t, consigne: a.consigne)) }
            }
        }
        func renvoyer(_ si: Int, _ bi: Int?) {
            for a in renvois[Place(section: si, bloc: bi)] ?? [] {
                if let cible = a.cible { sortie.append(.renvoi(condition: a.condition, cible: cible)) }
            }
        }
        let plusieurs = texte.sections.count > 1
        for (si, s) in texte.sections.enumerated() {
            // Une section seule porte déjà le nom du texte : pas de titre répété.
            if plusieurs && !s.titre.estBlanc { sortie.append(.titre(texte: s.titre, fr: s.titreFr, en: s.titreEn)) }
            if let section = sections[si] {
                if vrai(section.condition, conditions) {
                    sortie.append(.etiquette(condition: section.condition, libelle: nom(section, section.condition)))
                    for b in s.blocs { sortie.append(.bloc(b, .duJour)) }
                } else {
                    let cle = "\u{00A7}\(si)"
                    let ouvert = ouverts.contains(cle)
                    sortie.append(.replie(cle: cle, condition: section.condition, ouvert: ouvert,
                                          libelle: nom(section, section.condition)))
                    if ouvert { for b in s.blocs { sortie.append(.bloc(b, .hors)) } }
                }
                renvoyer(si, nil)
                continue
            }
            var i = 0
            while i < s.blocs.count {
                if let a = blocs[Place(section: si, bloc: i)] {
                    // Un groupe : les blocs qui suivent, tant qu'ils sont du même groupe.
                    var membres: [(bloc: SiddurBloc, annotation: Annotation)] = []
                    while i < s.blocs.count, let m = blocs[Place(section: si, bloc: i)], m.groupe == a.groupe {
                        membres.append((bloc: s.blocs[i], annotation: m))
                        i += 1
                    }
                    let racine = a.racine ?? a.condition
                    if vrai(racine, conditions) {
                        sortie.append(.etiquette(condition: racine, libelle: nom(a, racine)))
                        for m in membres { sortie.append(.bloc(m.bloc, vrai(m.annotation.condition, conditions) ? .duJour : .hors)) }
                    } else {
                        let groupe = a.groupe.map { String($0) } ?? "null"
                        let cle = "\(si):\(groupe)"
                        let ouvert = ouverts.contains(cle)
                        sortie.append(.replie(cle: cle, condition: racine, ouvert: ouvert, libelle: nom(a, racine)))
                        if ouvert { for m in membres { sortie.append(.bloc(m.bloc, .hors)) } }
                    }
                    cartesSeul(si, i - 1)
                } else {
                    // Une variante enchâssée hors du jour (המלך הקדוש, מוריד הטל…) : retirée du bloc, et une
                    // ligne repliée la rend d'un geste (demande du 28/10).
                    let ind = indices[Place(section: si, bloc: i)] ?? []
                    let horsJour = ind.filter { $0.retire != nil && !vrai($0.condition, conditions) }
                    let cleVariante = "v\(si):\(i)"
                    let ouverte = ouverts.contains(cleVariante)
                    var bloc = s.blocs[i]
                    var reduit = false
                    if !ouverte {
                        var t = bloc.texte
                        for v in horsJour {
                            if let passage = v.retire { t = sansPremier(passage, dans: t) }
                        }
                        t = t.rogne
                        if !t.egalUnites(bloc.texte) {
                            bloc = SiddurBloc(texte: t, consigne: bloc.consigne, fr: bloc.fr, en: bloc.en)
                            reduit = true
                        }
                    }
                    sortie.append(.bloc(bloc, .normal))
                    // Le texte du jour se lit dans le bloc même ; l'ancien « Aujourd'hui : … » ne reste que
                    // pour les variantes qu'on ne sait pas replier.
                    for v in ind where v.retire == nil && vrai(v.condition, conditions) {
                        if let variante = v.texte { sortie.append(.indice(variante)) }
                    }
                    if let v = horsJour.first, ouverte || reduit {
                        sortie.append(.replie(cle: cleVariante, condition: v.condition, ouvert: ouverte, libelle: nom(v, v.condition)))
                    }
                    cartesSeul(si, i)
                    renvoyer(si, i)
                    i += 1
                }
            }
            renvoyer(si, nil)
        }
        return sortie
    }

    /// `replaceFirst(motif, "")` de Kotlin : la première occurrence retirée, unité UTF-16 par unité.
    private static func sansPremier(_ motif: String, dans texte: String) -> String {
        let unites = Array(texte.utf16)
        let cherche = Array(motif.utf16)
        guard let debut = Unites.position(de: cherche, dans: unites) else { return texte }
        var reste = Array(unites[..<debut])
        reste.append(contentsOf: unites[(debut + cherche.count)...])
        return Unites.texte(reste)
    }

    /// Le libellé d'un ajout, un jour donné : celui de l'annotation s'il en a un ; pour l'annonce du
    /// Hallel, complet ou partiel, et la bénédiction du Hallel partiel selon le nusah (Choul'han Aroukh
    /// et Rema, O.H. 422:2) ; les Edot changent toute la 9ᵉ bénédiction (ברך עלינו / ברכנו, 28/10).
    public static func libelleJour(_ libelleAnnotation: String?, _ condition: String, _ nusah: Nusah,
                                   _ conditions: Set<String>) -> String {
        if let propre = libelleAnnotation { return propre }
        if condition.egalUnites(C.hallel) { return libelleHallel(nusah, conditions) ?? libelle(condition) }
        if nusah == .edot && sansNegation(condition).egalUnites(C.talOumatar) {
            return condition.commenceParUnites("!") ? "ajout_barkhenou" : "ajout_barekh_alenou"
        }
        if nusah == .edot && condition.egalUnites(C.berakha) { return "ajout_barkhenou" }
        return libelle(condition)
    }

    /// Vrai si la condition vaut ce jour-là ; « ! » devant : si la clé manque.
    public static func vrai(_ condition: String, _ conditions: Set<String>) -> Bool {
        if condition.commenceParUnites("!") { return !conditions.contains(condition.sansPremieresUnites(1)) }
        return conditions.contains(condition)
    }

    /// Le nom de la chaîne qui nomme une condition, dans les trois langues.
    public static func libelle(_ condition: String) -> String {
        let c = sansNegation(condition)
        if condition.commenceParUnites("!tahanoun") { return "ajout_sans_tahanoun" }
        if c.commenceParUnites("tahanoun") { return "ajout_tahanoun" }
        if c.egalUnites("kippour") { return "fete_yom_kippour" }
        // « אומרים כאן הלל » : le Hallel, complet ou non selon le jour.
        if c.egalUnites("hallel") { return "ajout_hallel_annonce" }
        if c.commenceParUnites("embolismique") { return "ajout_embolismique" }
        for fete in fetesNommees where fete.egalUnites(c) { return "fete_" + c }
        return "ajout_" + c
    }

    /// Les conditions dont le libellé est celui de la fête (« fete_<clé> »).
    private static let fetesNommees = ["pessah", "soukkot", "chavouot", "roch_hachana", "chemini_atseret", "hanouka", "pourim"]

    /// `removePrefix("!")`.
    private static func sansNegation(_ condition: String) -> String {
        condition.commenceParUnites("!") ? condition.sansPremieresUnites(1) : condition
    }

    /// Comme tools/siddur_annotations.py : sans balises ni voyelles, les blancs réduits à un espace,
    /// quarante unités UTF-16.
    public static func empreinte(_ texte: String) -> String {
        let sansBalises = balise.remplace(texte, par: " ")
        let sansSignes = signes.remplace(sansBalises, par: "")
        return blancs.remplace(sansSignes, par: " ").rogne.premieresUnites(40)
    }

    private static let balise = ExpressionReguliere("<[^>]+>")
    /// Voyelles, te'amim et signes de U+0591 à U+05C7.
    private static let signes = ExpressionReguliere("[\\u0591-\\u05C7]")
    /// `(?U)\s+` de la JVM : la propriété White_Space d'Unicode, écrite en toutes lettres (la fine
    /// U+2009 du siddour Edot y est, comme pour `\s` de Python et de JavaScript).
    private static let blancs = ExpressionReguliere(
        "[\\u0009-\\u000D\\u0020\\u0085\\u00A0\\u1680\\u2000-\\u200A\\u2028\\u2029\\u202F\\u205F\\u3000]+")
}

// MARK: La Méguila, Birkat haIlanot et l'illustration du moment (SiddurMoment de Siddur.kt)

extension SiddurMoment {

    /// La Méguila d'Esther avec la prière (13/10) : sous Arvit la nuit qui ouvre Pourim (le jour hébreu
    /// de demain), sous Cha'harit le jour même. Dans une ville murée, le 15 Adar ; quand il tombe un
    /// Chabbat (Pourim mechoulach), la Méguila se lit le vendredi 14.
    public static func megila(_ moment: String?, aujourdhui: JourCivil, israel: Bool, mukafChoma: Bool) -> Bool {
        let jour: JourCivil
        if moment == "chaharit" {
            jour = aujourdhui
        } else if moment == "arvit" {
            jour = aujourdhui.plus(jours: 1)
        } else {
            return false
        }
        let fetes = CalendrierJuif.jour(jour, enIsrael: israel, mukafChoma: mukafChoma).fetes
        let samedi = jour.jourDeSemaine == 7, vendredi = jour.jourDeSemaine == 6
        if fetes.contains("pourim") || (fetes.contains("pourim_jerusalem") && !samedi) { return true }
        return mukafChoma && fetes.contains("pourim_ailleurs") && vendredi
    }

    /// Birkat haIlanot (14/10) : on la dit une fois l'an, en voyant des arbres fruitiers en fleur — en
    /// Nissan dans l'hémisphère nord (Choulhan Aroukh O.H. 226). `latitude` : celle du lieu des zmanim, ou nil.
    public static func ilanot(_ date: JourCivil, latitude: Double?) -> Bool {
        let mois = CalendrierJuif.jour(date, enIsrael: false).moisHebreu
        if let latitude, latitude < 0 { return moisIlanotSud(mois) }
        return mois == CalendrierJuif.Mois.nissan
    }

    /// L'hémisphère sud (14/10) : on bénit quand les arbres y fleurissent (Har Tsvi O.H. 1:118 ; Min'hat
    /// Yits'hak 10:16, cités par Yeshivat Har Etzion) ; en Australie en Eloul et Tichri (Halachipedia).
    /// `mois` : la numérotation de KosherJava (`CalendrierJuif.Mois`).
    public static func moisIlanotSud(_ mois: Int) -> Bool {
        mois == CalendrierJuif.Mois.eloul || mois == CalendrierJuif.Mois.tichri
    }

    /// Le hassid qui accompagne la suggestion, parmi les illustrations de l'application : le nom de l'image.
    public static func illustration(_ id: String) -> String {
        switch id {
        case "tikoun_hatsot": return "char_praying"
        case "birkot_hachahar": return "char_welcome"
        // Les tefillin et le lit (planche du 11/10).
        case "chaharit": return "char_tefillin"
        case "chema_coucher": return "scene_sleeping"
        // L'aéroport, décor gardé (demande du 11/10).
        case "tefilat_haderekh": return "scene_airport"
        case "minha": return "char_standing_back"
        case "arvit": return "char_tehilim"
        default: return "char_thinking"
        }
    }
}
