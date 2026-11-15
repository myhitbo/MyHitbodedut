import Foundation

/// Les préférences d'Android que la barrière, le planificateur et les alertes lisent et que `Reglages` ne nomme pas
/// encore : elles vivent dans `reglages.json` sous leurs clés d'Android (PORTAGE.md § 3.2), parmi les clés gardées
/// telles quelles (`autres`), et ne sortent pas dans la sauvegarde exportée, comme sur Android. Les défauts sont
/// ceux de `Store.kt`.
extension Reglages {

    /// `enabled` (`Store.isEnabled`) : le mode « Je suis avec Hachem » est allumé.
    public var modeBarriere: Bool {
        get { autres.booleen("enabled") }
        set { autres["enabled"] = .booleen(newValue) }
    }

    /// `snoozed_until` (`Store.snoozedUntil`) : la fin du report de la barrière, en millisecondes Unix ; 0 sans report.
    public var reporteJusqua: Int64 {
        get { autres.long("snoozed_until") }
        set { autres["snoozed_until"] = .entier(newValue) }
    }

    /// `seance_faite_a` : l'instant que couvre la dernière séance inscrite (`Store.addSession`), pour la fenêtre de
    /// nuit (`Store.fenetreFaite`) ; 0 si aucun.
    public var faiteA: Int64 {
        get { autres.long("seance_faite_a") }
        set { autres["seance_faite_a"] = .entier(newValue) }
    }

    /// `reminder_snoozed_until` (`Store.reminderSnoozedUntil`) : un rappel reporté par « Plus tard » ; 0 sans report.
    public var rappelReporteJusqua: Int64 {
        get { autres.long("reminder_snoozed_until") }
        set { autres["reminder_snoozed_until"] = .entier(newValue) }
    }

    /// `levana_rappel` (`Store.levanaRappel`) : le rappel de Birkat haLevana, oui par défaut.
    public var levanaRappel: Bool {
        get { autres.booleen("levana_rappel", defaut: true) }
        set { autres["levana_rappel"] = .booleen(newValue) }
    }

    /// `levana_usage` (`Store.levanaUsage`) : l'usage choisi, nil pour celui du noussa'h.
    public var levanaUsage: Levana.Usage? {
        get { autres.estNul("levana_usage") ? nil : Levana.Usage(rawValue: autres.texte("levana_usage")) }
        set { autres["levana_usage"] = newValue.map { .chaine($0.rawValue) } }
    }

    /// `siddur_nusah` (`Store.siddurNusah`) : Edot haMizra'h par défaut.
    public var nusah: Nusah {
        get { Nusah.de(autres.estNul("siddur_nusah") ? nil : autres.texte("siddur_nusah")) }
        set { autres["siddur_nusah"] = .chaine(newValue.rawValue) }
    }

    /// `allumage_minutes` (`Store.allumage`) : les minutes d'allumage avant la chki'a, une des valeurs proposées,
    /// 18 sinon.
    public var allumage: Int {
        get {
            let m = autres.entier("allumage_minutes", defaut: Zmanim.allumageDefaut)
            return Zmanim.allumages.contains(m) ? m : Zmanim.allumageDefaut
        }
        set { autres["allumage_minutes"] = .entier(Int64(newValue)) }
    }

    /// `vol_rappels_actifs` (`Store.volRappelsActifs`) : les rappels du vol, oui par défaut.
    public var volRappelsActifs: Bool {
        get { autres.booleen("vol_rappels_actifs", defaut: true) }
        set { autres["vol_rappels_actifs"] = .booleen(newValue) }
    }

    /// `vol_rappel_vu` (`Store.volRappelVu`) : l'instant du dernier rappel du vol montré.
    public var volRappelVu: Int64 {
        get { autres.long("vol_rappel_vu") }
        set { autres["vol_rappel_vu"] = .entier(newValue) }
    }
}
