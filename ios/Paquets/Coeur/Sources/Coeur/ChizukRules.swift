/// Ce qu'une compilation a le droit d'afficher, et sous quelle forme (ChizukRules.kt).
///
/// Deux règles, toutes deux tirées de `_meta.regle_publication` :
///
///  - en release, seul passe un texte relevé de la source ET relu par un humain. Un texte non relu
///    peut porter une coquille, et une coquille dans un verset n'est pas une coquille ordinaire ;
///  - l'hébreu affiché dépend de l'édition. Quand la licence de l'édition numérique n'est pas
///    déclarée, on n'en reprend pas la vocalisation, qui est un travail éditorial : on affiche le
///    texte sans nikkoud.
///
/// Les fonctions prennent `debug` en paramètre plutôt que de lire la configuration de la
/// compilation : c'est ce qui les rend vérifiables sans appareil. Les chaînes se comparent unité
/// UTF-16 par unité, comme en Kotlin : un statut ou une clé d'édition écrits avec un « é » décomposé
/// ne valent pas les mêmes écrits avec un « é » composé.
/// Jugée par `Tests/Vecteurs/chizuk.json` (tools/vecteurs_ios/VecteursChizuk.kt).
public enum ChizukRules {

    /// Le seul `statut_verif` qu'une release accepte (STATUT_PUBLIABLE).
    public static let statutPubliable = "verifie_texte"

    /// La règle de publication, telle quelle.
    public static func isPublishable(_ item: ChizukItem) -> Bool {
        item.statutVerif.egalUnites(statutPubliable) && item.relu
    }

    /// Un item retenu en debug mais que la release refuserait porte un badge.
    public static func needsProofreading(_ item: ChizukItem) -> Bool {
        !isPublishable(item)
    }

    /// Ce qu'une compilation affiche : tout en debug, le publiable en release.
    public static func visible(_ chizuk: Chizuk, debug: Bool) -> [ChizukItem] {
        if debug { return chizuk.items }
        return chizuk.items.filter { isPublishable($0) }
    }

    /// Ce qu'un moment donné a le droit de tirer. « J'ai besoin de 'hizouk » (`demande`) tire dans
    /// tout ce qui est visible : aucun texte ne porte ce moment dans chizuk.json.
    public static func forMoment(_ chizuk: Chizuk, _ moment: Moment, debug: Bool) -> [ChizukItem] {
        let visibles = visible(chizuk, debug: debug)
        if moment == .demande { return visibles }
        return visibles.filter { $0.moments.contains(moment) }
    }

    /// L'hébreu à afficher. Pour une édition dont `nikkoud_ok` est faux, le fichier livre déjà `he` sans
    /// vocalisation (LicencesEditionsTest d'Android l'impose) : il n'y a rien à retirer à l'affichage.
    public static func hebrew(_ chizuk: Chizuk, _ item: ChizukItem) -> String {
        item.he
    }

    /// `editions[cle]?.nikkoudOk ?: false`, la clé comparée comme Kotlin compare deux chaînes : un
    /// dictionnaire de Swift trouverait « é » décomposé sous « é » composé.
    private static func nikkoudOk(_ chizuk: Chizuk, _ cle: String) -> Bool {
        for (nom, edition) in chizuk.editions where nom.egalUnites(cle) {
            return edition.nikkoudOk
        }
        return false
    }
}
