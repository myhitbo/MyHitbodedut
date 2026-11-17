import Foundation

/// Ce que l'onglet Zmanim et le calendrier montrent d'un jour (JourAffiche.kt) : les ajouts à
/// nommer, les horaires avec l'entrée et la sortie de Chabbat ou de fête, la grille d'un mois.
public enum JourAffiche {

    private typealias C = CalendrierJuif.C

    /// L'illustration d'un jour de fête ou de Chabbat, par son nom de ressource ; nil un jour
    /// ordinaire. La fête passe avant Chabbat.
    public static func illustration(fetes: [String], date: JourCivil) -> String? {
        let un = { (noms: Set<String>) in fetes.contains(where: { noms.contains($0) }) }
        if un(["erev_soukkot", "soukkot", "hol_hamoed_soukkot", "hochaana_rabba"]) { return "scene_sukkot" }
        if un(["erev_pessah", "pessah", "hol_hamoed_pessah"]) { return "char_matsa" }
        if fetes.contains("hanouka") { return "scene_hanukkah" }
        if un(["pourim", "chouchan_pourim", "pourim_ailleurs", "pourim_jerusalem"]) { return "char_purim" }
        return date.jourDeSemaine == 7 ? "char_shabbat" : nil
    }

    /// Les ajouts du jour, dans l'ordre de l'Amida : des clés de libellé. Le nusah change trois
    /// choses (ZMANIM.md) : Morid hatal hors d'Israël chez les Ashkénazes, la bénédiction du Hallel
    /// partiel, et l'Anénou du particulier (Ashkenaz et Sfard : à Min'ha seulement, Rema O.H.
    /// 565:3 ; Edot : à Cha'harit et à Min'ha, et à Arvit le soir de Tich'a bèAv).
    public static func ajouts(_ c0: Set<String>, nusah: Nusah = .edot, enIsrael: Bool = false,
                              sansTahanounFinTichri: Bool? = nil, sud: Bool = false) -> [String] {
        let c = SiddurJour.conditionsPour(nusah, enIsrael: enIsrael, c0, sansTahanounFinTichri: sansTahanounFinTichri, sud: sud)
        var a: [String] = []
        if c.contains(C.asseretYemeiTechouva) { a.append("ajout_asseret_yemei_techouva") }
        // Les jours de bascule, les deux formules ; sinon l'une ou l'autre.
        if c.contains(C.machivHarouah) { a.append("ajout_machiv_harouah") }
        if c.contains(C.moridHatal) && (!c.contains(C.machivHarouah) || c.contains(C.basculePluie)) { a.append("ajout_morid_hatal") }
        // La 9ᵉ bénédiction : les Edot changent de texte (ברך עלינו / ברכנו) ; rien le Chabbat ni un Yom Tov,
        // Kippour compris, où l'Amida n'a pas de bénédiction de semaine.
        if !c.contains(C.chabbat) && !c.contains(C.yomTov) {
            if nusah == .edot {
                a.append(c.contains(C.talOumatar) ? "ajout_barekh_alenou" : "ajout_barkhenou")
            } else {
                a.append(c.contains(C.talOumatar) ? "ajout_tal_oumatar" : "ajout_berakha")
            }
        }
        if c.contains(C.jeune) {
            a.append("ajout_anenou_officiant")
            // Edot : à Tich'a bèAv, le jeûne commence la veille au soir, et Arvit en est.
            if nusah != .edot {
                a.append("ajout_anenou_particulier_minha")
            } else if c.contains(C.tichaBeav) {
                a.append("ajout_anenou_particulier_trois")
            } else {
                a.append("ajout_anenou_particulier_matin_minha")
            }
        }
        // Na'hem (audit du 16/11) : Edot à Arvit, Cha'harit et Min'ha (Kitsour Yalkut Yosef 557:1) ; Sfard et
        // Ashkenaz à Min'ha seulement (Rema 557:1).
        if c.contains(C.tichaBeav) { a.append(nusah == .edot ? "ajout_ticha_beav_trois" : "ajout_ticha_beav_minha") }
        if c.contains(C.yaaleVeyavo) { a.append("ajout_yaale_veyavo") }
        if c.contains(C.alHanissim) { a.append("ajout_al_hanissim") }
        if let hallel = SiddurJour.libelleHallel(nusah, c) { a.append(hallel) }
        // Le Chabbat et un Yom Tov (Kippour compris), il n'y a pas d'Amida de semaine où dire ou taire Ta'hanoun
        // (audit du 12/11, FCALENDRIER-12). Le dimanche d'un Pourim triple hors de Jérusalem, l'Ashkenaz suit le
        // Halikhot Chlomo contre le Michna Beroura (131:33) : le libellé le dit.
        if !c.contains(C.chabbat) && !c.contains(C.yomTov) {
            if c.contains(C.tahanounChaharit) {
                a.append("ajout_tahanoun")
            } else if c.contains(C.sansTahanounPonctuel) {
                // Le réglage ponctuel (deuil, brit, 'hatan ; audit du 16/11) : on dit d'où vient l'absence.
                a.append("ajout_sans_tahanoun_ponctuel")
            } else if nusah == .ashkenaz && c.contains(C.pourimTripleHorsJerusalem) {
                a.append("ajout_sans_tahanoun_halikhot_chlomo")
            } else if nusah == .ashkenaz && c.contains(C.jourPessahCheni) {
                // Pessa'h chéni : l'ancien usage ashkénaze disait Ta'hanoun (Chaarei Techouva 131:19).
                a.append("ajout_sans_tahanoun_pessah_cheni")
            } else {
                a.append("ajout_sans_tahanoun")
            }
        }
        // La veille de Kippour : Vidouï et « על חטא » après l'Amida de Min'ha, que l'app n'a pas (O.H. 607:1).
        if c.contains(C.erevKippour) { a.append("ajout_vidoui_erev_kippour") }
        return a
    }

    /// Les horaires du jour, avec ceux de Chabbat et des fêtes (isAssurBemelacha) :
    /// - la veille d'un jour chômé : l'allumage, `minutes` avant la chki'a ;
    /// - un jour chômé suivi d'un autre : l'allumage, pas avant la sortie du jour, à tsét ; sauf un vendredi de
    ///   fête (audit du 12/11, FCALENDRIER-01) : les bougies de Chabbat s'allument avant la chki'a ;
    /// - le dernier jour chômé : la sortie, à tsét.
    /// Le profil suit le `nusah` (audit du 16/11) : pour les Edot, la sortie est Rabbénou Tam en 72 min zmaniyot
    /// (Kitsour YY 293:3, 7), précédée d'une sortie « selon les Gueonim » à leur tsét ; l'allumage d'un deuxième
    /// jour de fête suit le tsét du rite, après Chabbat la sortie. À titre d'information : un jeûne public (début à
    /// l'aube, fin à tsét ; la veille du 9 Av, début à la chki'a, Kitsour YY 550:2) ; la veille de Pessa'h, les
    /// heures du 'hamets (le vendredi, la fin du bi'our quand elle tombe un Chabbat, O.H. 444:2).
    public static func horaires(lieu: Zmanim.Lieu, date: JourCivil, enIsrael: Bool, minutes: Int,
                                nusah: Nusah? = nil) -> [Zmanim.Zman] {
        let jourJ = CalendrierJuif.jour(date, enIsrael: enIsrael)
        let jourDemain = CalendrierJuif.jour(date.plus(jours: 1), enIsrael: enIsrael)
        let aujourdhui = jourJ.chome
        let demain = jourDemain.chome
        let veilleDeChabbat = date.jourDeSemaine == 6
        let samedi = date.jourDeSemaine == 7
        let edot = nusah == .edot
        let base = Zmanim.jour(lieu: lieu, date: date, nusah: nusah)
        guard let tset = base.first(where: { $0.cle == "tset" }) else { return base }
        let fin = edot ? (base.first { $0.cle == "tset_rt" } ?? tset) : tset
        let jeune = jourJ.conditions.contains(C.jeune)
        let veilleAv = jourDemain.conditions.contains(C.tichaBeav)
        var hamets: [Zmanim.Zman] = []
        if jourJ.fetes.contains("erev_pessah") {
            hamets = Zmanim.hamets(lieu: lieu, date: date, nusah: nusah)
        } else if veilleDeChabbat && jourDemain.fetes.contains("erev_pessah") {
            hamets = Zmanim.hamets(lieu: lieu, date: date, nusah: nusah).filter { $0.cle == "hamets_biour" }
        }
        func copie(_ z: Zmanim.Zman, _ cle: String, _ methode: Zmanim.Methode? = nil) -> Zmanim.Zman {
            Zmanim.Zman(cle: cle, methode: methode ?? z.methode, statut: z.statut, instant: z.instant)
        }
        var sortie: [Zmanim.Zman] = []
        for z in base {
            if z.cle == "chkia" && demain && (!aujourdhui || veilleDeChabbat) {
                sortie.append(Zmanim.allumage(lieu: lieu, date: date, minutes: minutes))
            }
            if z.cle == "chkia" && veilleAv { sortie.append(copie(z, "debut_jeune")) }
            sortie.append(z)
            if z.cle == "alot" && jeune && !jourJ.conditions.contains(C.tichaBeav) { sortie.append(copie(z, "debut_jeune")) }
            if z.cle == "szt_gra" { sortie.append(contentsOf: hamets) }
            if z.cle == "tset" && jeune { sortie.append(copie(z, "fin_jeune")) }
            // Edot : les deux sorties, au choix du propriétaire (17/11) : tsét des Gueonim, puis Rabbénou Tam.
            if edot && z.cle == "tset" && aujourdhui && !demain { sortie.append(copie(z, "sortie_gueonim")) }
            if z.cle == fin.cle && aujourdhui && !demain {
                sortie.append(edot ? copie(fin, "sortie", Zmanim.Methode("rabbenou_tam_zmaniyot", fin.methode.parametres))
                                   : copie(fin, "sortie"))
            }
            let apres = samedi ? fin : tset
            if z.cle == apres.cle && aujourdhui && demain && !veilleDeChabbat {
                sortie.append(copie(apres, "allumage", Zmanim.Methode(edot ? "apres_sortie" : "apres_tset", "")))
            }
        }
        return sortie
    }

    /// La note du Yom tov chéni pour un voyageur (audit du 16/11) : une clé de chaîne, ou nil. Le calendrier suit
    /// le statut (`statutIsrael`, la résidence) ; la note dit ce qui change quand le lieu (`lieuEnIsrael`) est de
    /// l'autre région un jour qui n'est chômé qu'en diaspora (O.H. 496:3 ; Kitsour YY 31:3 ; MB 496:13).
    public static func noteYomTovCheni(_ date: JourCivil, statutIsrael: Bool, lieuEnIsrael: Bool, nusah: Nusah) -> String? {
        if statutIsrael == lieuEnIsrael { return nil }
        if !CalendrierJuif.jour(date, enIsrael: false).chome || CalendrierJuif.jour(date, enIsrael: true).chome { return nil }
        if statutIsrael { return "note_ytc_ben_israel" }
        return nusah == .ashkenaz ? "note_ytc_ben_houl_ashkenaz" : "note_ytc_ben_houl"
    }

    /// Un lieu où la ligne de date halakhique est discutée (audit du 16/11) : à l'est de 125,2° E (la ligne du
    /// 'Hazon Ich) ou à l'ouest de 150° O. L'application suit le jour civil ; l'écran le dit, sans trancher.
    public static func ligneDateDiscutee(_ longitude: Double) -> Bool {
        longitude >= 125.2 || longitude <= -150.0
    }

    /// Les minutes d'allumage d'usage à Jérusalem, hors Edot (calendrier de Rav Toukatchinsky).
    public static let allumageJerusalem = 40
    /// Les minutes d'allumage que le Yalkut Yosef donne aux Edot, à Jérusalem comme ailleurs.
    public static let allumageEdot = 20

    /// La proposition sous le réglage d'allumage, à Jérusalem seulement : une clé de chaîne, ou nil (audit du
    /// 16/11 : les 40 min pour Sfard et Ashkenaz ; environ 20 min pour les Edot, Kitsour YY 263:47).
    public static func propositionAllumage(nusah: Nusah, mukafChoma: Bool, minutes: Int) -> String? {
        if !mukafChoma { return nil }
        if nusah == .edot { return minutes != allumageEdot ? "reglage_allumage_proposition_edot" : nil }
        return minutes != allumageJerusalem ? "reglage_allumage_proposition" : nil
    }

    /// Le libellé « · coutume de Jérusalem » : 40 min, à Jérusalem, hors Edot (audit du 16/11).
    public static func coutumeJerusalem(nusah: Nusah, mukafChoma: Bool, minutes: Int) -> Bool {
        mukafChoma && nusah != .edot && minutes == allumageJerusalem
    }

    /// Les offices de semaine du siddour (audit du 16/11).
    public static let offices: Set<String> = ["chaharit", "minha", "arvit"]

    /// La carte « Pour cette heure » ne propose pas Cha'harit, Min'ha ni Arvit quand la prière relève d'un Chabbat
    /// ou d'un Yom tov (le siddour n'a que les offices de semaine ; audit du 16/11) ; `moment` sinon. `heure` :
    /// l'heure de la journée.
    public static func momentOuvrable(_ moment: String?, date: JourCivil, heure: Int, enIsrael: Bool) -> String? {
        guard let moment, offices.contains(moment) else { return moment }
        let jour = CalendrierJuif.jourDeLaPriere(moment, date: date, heure: heure)
        return CalendrierJuif.jour(jour, enIsrael: enIsrael).chome ? nil : moment
    }

    /// Le texte du siddour que suggère l'instant `maintenant`, d'après les zmanim du `lieu` :
    /// Tikoun 'hatsot de 'hatsot de la nuit à l'aube ; Birkot hacha'har de l'aube à michéyakir ;
    /// Cha'harit jusqu'à 'hatsot ; Min'ha de min'ha guedola à la chki'a ; Arvit dès tsét, puis le
    /// Chema du coucher après 22 h 30. nil dans les deux creux (de 'hatsot à min'ha guedola, sauf le Tikoun
    /// Ra'hel de Bein hamétsarim, et de la chki'a à tsét). Sans les zmanim du jour, les heures fixes de
    /// SiddurMoment. `enIsrael` : le Tikoun 'hatsot de la nuit ; `nusah` : le profil des zmanim et le Tikoun Ra'hel
    /// (audit du 16/11). Sans aube (autour du solstice au nord), michéyakir puis le lever en tiennent lieu.
    public static func momentDuSiddour(lieu: Zmanim.Lieu, maintenant: Date, enIsrael: Bool = true,
                                       nusah: Nusah? = nil) -> String? {
        var gregorien = Calendar(identifier: .gregorian)
        gregorien.timeZone = TimeZone(identifier: lieu.fuseau) ?? TimeZone(secondsFromGMT: 0)!
        let local = gregorien.dateComponents([.year, .month, .day, .hour, .minute, .second], from: maintenant)
        guard let date = JourCivil(annee: local.year ?? 0, mois: local.month ?? 0, jour: local.day ?? 0) else { return nil }
        let heure = local.hour ?? 0, minute = local.minute ?? 0
        let secondes = heure * 3600 + minute * 60 + (local.second ?? 0)
        // La nuit appartient au jour hébreu civil après minuit, au lendemain avant minuit (audit du 16/11).
        let nuit = secondes < 12 * 3600 ? date : date.plus(jours: 1)
        let sansTikoun = sansTikounHatsot(nuit, enIsrael: enIsrael)
        let tikoun = sansTikoun ? "chema_coucher" : "tikoun_hatsot"
        func instants(_ d: JourCivil) -> [String: Date] {
            var r: [String: Date] = [:]
            for z in Zmanim.jour(lieu: lieu, date: d, nusah: nusah) { r[z.cle] = z.instant }
            return r
        }
        var z = instants(date)
        if z["alot"] == nil { z["alot"] = z["misheyakir"] ?? z["netz"] }
        if z["misheyakir"] == nil { z["misheyakir"] = z["netz"] }
        let hier = instants(date.plus(jours: -1))
        let cles = ["alot", "misheyakir", "chatsot", "minha_gedola", "chkia", "tset", "chatsot_layla"]
        guard cles.allSatisfy({ z[$0] != nil }), let minuitHier = hier["chatsot_layla"] else {
            return SiddurMoment.suggestion(heure: heure, minute: minute, sansTikoun: sansTikoun)
        }
        func avant(_ cle: String) -> Bool { maintenant < (z[cle] ?? maintenant) }
        let soir = secondes < 22 * 3600 + 30 * 60 && secondes > 12 * 3600 ? "arvit" : "chema_coucher"
        if avant("alot") { return maintenant >= minuitHier ? tikoun : "chema_coucher" }
        if avant("misheyakir") { return "birkot_hachahar" }
        if avant("chatsot") { return "chaharit" }
        if avant("minha_gedola") { return tikounRahelDeMidi(date, nusah: nusah) ? "tikoun_hatsot" : nil }
        if avant("chkia") { return "minha" }
        if avant("tset") { return nil }
        if avant("chatsot_layla") { return soir }
        return tikoun
    }

    /// Pas de Tikoun 'hatsot la nuit du jour hébreu `nuit` : Chabbat, Yom tov (le second jour en diaspora), 'Hol
    /// hamoed Pessa'h (audit du 16/11 : Kitsour Yalkut Yosef, דיני תיקון חצות, se'if נה).
    public static func sansTikounHatsot(_ nuit: JourCivil, enIsrael: Bool) -> Bool {
        if nuit.jourDeSemaine == 7 { return true }
        let j = CalendrierJuif.jour(nuit, enIsrael: enIsrael)
        return j.conditions.contains(C.yomTov) || j.fetes.contains("hol_hamoed_pessah")
    }

    /// Bein hamétsarim, du 17 Tamouz au 8 Av, sauf Chabbat et Roch 'Hodech Av : beaucoup disent le Tikoun Ra'hel
    /// après 'hatsot du jour (Kitsour Yalkut Yosef) ; usage des Edot et du Sfard, pas de l'Ashkenaz (MB 1:9).
    public static func tikounRahelDeMidi(_ date: JourCivil, nusah: Nusah?) -> Bool {
        if nusah == .ashkenaz || date.jourDeSemaine == 7 { return false }
        let j = CalendrierJuif.jour(date, enIsrael: false)
        return (j.moisHebreu == CalendrierJuif.Mois.tamouz && j.jourHebreu >= 17)
            || (j.moisHebreu == CalendrierJuif.Mois.av && (2...8).contains(j.jourHebreu))
    }

    /// Les semaines d'un mois civil, du dimanche au samedi comme le calendrier juif ; nil hors du mois.
    public static func semaines(annee: Int, mois: Int) -> [[JourCivil?]] {
        let jours = (1...JourCivil.joursDansLeMois(mois, annee: annee)).compactMap { JourCivil(annee: annee, mois: mois, jour: $0) }
        return grille(jours)
    }

    /// Le premier jour (1er) du mois hébreu qui contient `date`. Le mois ne dépend pas du lieu.
    public static func debutMoisHebreu(_ date: JourCivil) -> JourCivil {
        date.plus(jours: -(CalendrierJuif.jour(date, enIsrael: false).jourHebreu - 1))
    }

    /// Les 29 ou 30 jours du mois hébreu qui contient `date`.
    public static func joursMoisHebreu(_ date: JourCivil) -> [JourCivil] {
        let debut = debutMoisHebreu(date)
        let mois = CalendrierJuif.jour(debut, enIsrael: false).moisHebreu
        var jours = [debut]
        while let dernier = jours.last, CalendrierJuif.jour(dernier.plus(jours: 1), enIsrael: false).moisHebreu == mois {
            jours.append(dernier.plus(jours: 1))
        }
        return jours
    }

    /// Les semaines du mois hébreu qui contient `date`, du dimanche au samedi ; nil hors du mois.
    public static func semainesHebreu(_ date: JourCivil) -> [[JourCivil?]] { grille(joursMoisHebreu(date)) }

    /// Le 1er du mois hébreu suivant (`sens` = 1) ou précédent (`sens` = -1).
    public static func moisHebreuVoisin(_ date: JourCivil, sens: Int) -> JourCivil {
        if sens > 0 { return (joursMoisHebreu(date).last ?? date).plus(jours: 1) }
        return debutMoisHebreu(debutMoisHebreu(date).plus(jours: -1))
    }

    private static func grille(_ jours: [JourCivil]) -> [[JourCivil?]] {
        guard let premier = jours.first else { return [] }
        let cases: [JourCivil?] = Array(repeating: nil, count: premier.jourDeSemaine - 1) + jours.map { Optional($0) }
        return stride(from: 0, to: cases.count, by: 7).map { debut in
            let semaine = Array(cases[debut..<min(debut + 7, cases.count)])
            return semaine + Array(repeating: nil, count: 7 - semaine.count)
        }
    }
}
