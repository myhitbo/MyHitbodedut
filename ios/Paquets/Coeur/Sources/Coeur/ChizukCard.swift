/// Ce qui est pur dans la carte de 'hizouk (ChizukCard.kt) : la traduction affichée sous l'hébreu,
/// et la langue de l'interface qui la choisit.
///
/// Le reste du fichier Kotlin remplit une vue d'Android (view_chizuk.xml) et reviendra avec l'écran
/// d'iOS. Le tirage qui l'alimente est dans ChizukBag et ChizukRules.
/// Jugée par `Tests/Vecteurs/chizuk.json` (tools/vecteurs_ios/VecteursChizuk.kt).
public enum ChizukCard {

    /// La traduction dans la langue de l'interface. En hébreu il n'y en a pas à donner : l'hébreu
    /// affiché au-dessus est le texte lui-même, et la répéter mangerait la moitié de la carte.
    ///
    /// La langue est passée plutôt que lue, pour que la règle se vérifie sans appareil. Elle se
    /// compare telle quelle : « EN » ou « en-US » ne sont pas l'anglais.
    public static func translationOf(_ item: ChizukItem, _ language: String) -> String {
        if language.egalUnites("he") || language.egalUnites("iw") { return "" }
        if language.egalUnites("en") { return item.en }
        // L'espagnol, l'arabe tunisien (17/11) : l'interface est traduite, pas les textes ; l'hébreu seul.
        if language.egalUnites("es") || language.egalUnites("ar") { return "" }
        // Le français et toute langue que l'application ne parle pas : c'est la langue de values/,
        // donc celle de l'interface qui entoure la carte.
        return item.fr
    }

    /// `language(context)` sans Context : la langue du premier Locale de la configuration
    /// (`Locale.language`, passée), en minuscules. « iw » est l'ancien code d'Android pour l'hébreu,
    /// encore rendu par Locale : il devient « he ».
    public static func language(_ langueDuLocale: String) -> String {
        let tag = langueDuLocale.lowercased()
        return tag.egalUnites("iw") ? "he" : tag
    }
}

/// Le texte partagé d'une carte (ChizukPartage, déclaré dans ChizukActivity.kt), vérifiable sans
/// appareil : l'hébreu, la traduction s'il y en a une, la source, le lien, séparés d'une ligne vide.
/// Les blancs rognés sont ceux de Kotlin (`trim`, `ifBlank`).
public enum ChizukPartage {

    public static func texte(_ hebreu: String, _ traduction: String, _ source: String, _ lien: String) -> String {
        let traductionRognee = traduction.rogne
        var parties = [hebreu.rogne]
        if !traductionRognee.estBlanc { parties.append(traductionRognee) }
        parties.append("— " + source)
        parties.append(lien)
        return parties.joined(separator: "\n\n")
    }
}
