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
