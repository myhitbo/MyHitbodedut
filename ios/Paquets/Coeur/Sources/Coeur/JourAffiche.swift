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
        // La 9ᵉ bénédiction : les Edot changent de texte (ברך עלינו / ברכנו) ; rien le Chabbat.
        if !c.contains(C.chabbat) {
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
        if c.contains(C.tichaBeav) { a.append("ajout_ticha_beav") }
        if c.contains(C.yaaleVeyavo) { a.append("ajout_yaale_veyavo") }
        if c.contains(C.alHanissim) { a.append("ajout_al_hanissim") }
        if let hallel = SiddurJour.libelleHallel(nusah, c) { a.append(hallel) }
        // Le Chabbat, il n'y a pas d'Amida de semaine où dire ou taire Ta'hanoun.
        if !c.contains(C.chabbat) { a.append(c.contains(C.tahanounChaharit) ? "ajout_tahanoun" : "ajout_sans_tahanoun") }
        return a
    }

    /// Les horaires du jour, avec ceux de Chabbat et des fêtes (isAssurBemelacha) :
    /// - la veille d'un jour chômé : l'allumage, `minutes` avant la chki'a ;
    /// - un jour chômé suivi d'un autre : l'allumage, pas avant la sortie du jour, à tsét 8,5° ;
    /// - sauf un vendredi de fête : les bougies de Chabbat s'allument avant la chki'a, d'une flamme
    ///   existante, et jamais à tsét, qui est déjà Chabbat (FCALENDRIER-01) ;
    /// - le dernier jour chômé : la sortie, à tsét 8,5°.
    public static func horaires(lieu: Zmanim.Lieu, date: JourCivil, enIsrael: Bool, minutes: Int) -> [Zmanim.Zman] {
        let aujourdhui = CalendrierJuif.jour(date, enIsrael: enIsrael).chome
        let demain = CalendrierJuif.jour(date.plus(jours: 1), enIsrael: enIsrael).chome
        let veilleDeChabbat = date.jourDeSemaine == 6
        let base = Zmanim.jour(lieu: lieu, date: date)
        var sortie: [Zmanim.Zman] = []
        for z in base {
            if z.cle == "chkia" && demain && (!aujourdhui || veilleDeChabbat) { sortie.append(Zmanim.allumage(lieu: lieu, date: date, minutes: minutes)) }
            sortie.append(z)
            if z.cle == "tset" {
                if aujourdhui && !demain {
                    sortie.append(Zmanim.Zman(cle: "sortie", methode: z.methode, statut: z.statut, instant: z.instant))
                }
                if aujourdhui && demain && !veilleDeChabbat {
                    sortie.append(Zmanim.Zman(cle: "allumage", methode: Zmanim.Methode("apres_tset", ""),
                                              statut: z.statut, instant: z.instant))
                }
            }
        }
        return sortie
    }

    /// Le texte du siddour que suggère l'instant `maintenant`, d'après les zmanim du `lieu` :
    /// Tikoun 'hatsot de 'hatsot de la nuit à l'aube ; Birkot hacha'har de l'aube à michéyakir ;
    /// Cha'harit jusqu'à 'hatsot ; Min'ha de min'ha guedola à la chki'a ; Arvit dès tsét, puis le
    /// Chema du coucher après 22 h 30. nil dans les deux creux (de 'hatsot à min'ha guedola, de la
    /// chki'a à tsét). Sans les zmanim du jour (soleil de minuit), les heures fixes de SiddurMoment.
    public static func momentDuSiddour(lieu: Zmanim.Lieu, maintenant: Date) -> String? {
        var gregorien = Calendar(identifier: .gregorian)
        gregorien.timeZone = TimeZone(identifier: lieu.fuseau) ?? TimeZone(secondsFromGMT: 0)!
        let local = gregorien.dateComponents([.year, .month, .day, .hour, .minute, .second], from: maintenant)
        guard let date = JourCivil(annee: local.year ?? 0, mois: local.month ?? 0, jour: local.day ?? 0) else { return nil }
        let heure = local.hour ?? 0, minute = local.minute ?? 0
        let secondes = heure * 3600 + minute * 60 + (local.second ?? 0)
        func instants(_ d: JourCivil) -> [String: Date] {
            var r: [String: Date] = [:]
            for z in Zmanim.jour(lieu: lieu, date: d) { r[z.cle] = z.instant }
            return r
        }
        let z = instants(date), hier = instants(date.plus(jours: -1))
        let cles = ["alot", "misheyakir", "chatsot", "minha_gedola", "chkia", "tset", "chatsot_layla"]
        guard cles.allSatisfy({ z[$0] != nil }), let minuitHier = hier["chatsot_layla"] else {
            return SiddurMoment.suggestion(heure: heure, minute: minute)
        }
        func avant(_ cle: String) -> Bool { maintenant < (z[cle] ?? maintenant) }
        let soir = secondes < 22 * 3600 + 30 * 60 && secondes > 12 * 3600 ? "arvit" : "chema_coucher"
        if avant("alot") { return maintenant >= minuitHier ? "tikoun_hatsot" : "chema_coucher" }
        if avant("misheyakir") { return "birkot_hachahar" }
        if avant("chatsot") { return "chaharit" }
        if avant("minha_gedola") { return nil }
        if avant("chkia") { return "minha" }
        if avant("tset") { return nil }
        if avant("chatsot_layla") { return soir }
        return "tikoun_hatsot"
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
