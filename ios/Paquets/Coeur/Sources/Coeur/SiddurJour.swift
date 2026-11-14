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
