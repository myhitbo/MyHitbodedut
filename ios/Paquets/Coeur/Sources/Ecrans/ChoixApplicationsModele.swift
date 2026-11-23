import Foundation
import Observation
import Coeur
import Barriere

// Le choix des applications à retenir (AppPickerActivity.kt, activity_apps.xml). Sur iOS le sélecteur est celui d'Apple
// (`FamilyActivityPicker`, PORTAGE.md § 2.1.3) : il rend des jetons opaques, applications, catégories entières et sites,
// que l'app enregistre sans en connaître les noms ; la vue (ios/App) montre chaque choix par `Label(jeton)`, que le
// système dessine. Ce modèle dit ce qui est compté, prévient au-delà de cinquante applications (la limite d'un
// bouclier, au-delà de laquelle rien ne signale l'échec), et rappelle la liste venue d'Android, qui ne peut pas migrer
// (§ 3.7).

/// L'écran du choix des applications.
@MainActor
@Observable
public final class ChoixApplicationsModele {

    /// « Your app can shield up to 50 application tokens at once » (§ 2.1.3).
    public static let limiteApplications = 50

    private let magasin: Magasin
    private let systeme: any BarriereSysteme

    /// La sélection enregistrée.
    public private(set) var selection = SelectionResume()
    /// L'autorisation de Temps d'écran : sans elle, le sélecteur d'Apple ne s'ouvre pas.
    public private(set) var autorise = false
    public private(set) var systemeLu = false

    public init(magasin: Magasin, systeme: any BarriereSysteme) {
        self.magasin = magasin
        self.systeme = systeme
    }

    public func rafraichir() async {
        autorise = await systeme.autorise()
        selection = await systeme.selection()
        systemeLu = true
    }

    /// La vue a enregistré une nouvelle sélection (onPause → Store.setBlockedApps).
    public func selectionEnregistree(_ resume: SelectionResume) {
        selection = resume
    }

    // MARK: Ce que l'écran montre

    /// « Applications à bloquer ».
    public var titre: Libelle { Libelle("apps_title") }

    public var explication: Libelle { Libelle("apps_ios_explication") }

    /// Le compte (renderCount) : « 3 applications choisies », puis les catégories et les sites s'il y en a ; sans
    /// rien, l'avertissement des réglages.
    public var comptes: [Libelle] {
        if selection.vide { return [Libelle("apps_none_warning")] }
        var lignes = [Libelle.pluriel("apps_selected", quantite: selection.applications, .entier(selection.applications))]
        if selection.categories > 0 { lignes.append(Libelle("apps_ios_categories", .entier(selection.categories))) }
        if selection.sites > 0 { lignes.append(Libelle("apps_ios_sites", .entier(selection.sites))) }
        return lignes
    }

    /// La couleur du compte : « warning » sans rien de choisi, « muted » sinon (comme la ligne des réglages).
    public var couleurComptes: String {
        selection.vide ? "warning" : "muted"
    }

    /// Au-delà de cinquante applications, iOS ne retient plus rien sans le dire : l'écran le dit.
    public var avertissementLimite: Libelle? {
        selection.applications > ChoixApplicationsModele.limiteApplications
            ? Libelle("apps_ios_limite", .entier(ChoixApplicationsModele.limiteApplications)) : nil
    }

    /// « Choisir les applications » n'ouvre le sélecteur qu'avec l'accès à Temps d'écran ; sans lui, la ligne le dit.
    public var choixPossible: Bool {
        !systemeLu || autorise
    }

    public var sansAcces: Libelle? {
        systemeLu && !autorise ? Libelle("bouclier_essai_sans_acces") : nil
    }

    /// « Tout retirer » (apps_clear) n'a de sens qu'avec une sélection.
    public var retraitPossible: Bool {
        !selection.vide
    }

    /// L'aide-mémoire de la liste d'Android (§ 3.7) : « Sur Android, vous reteniez : instagram, whatsapp » ; nil sans
    /// liste importée.
    public var aideMemoire: Libelle? {
        let noms = ChoixApplicationsModele.nomsCourts(magasin.reglages.blockedApps)
        guard !noms.isEmpty else { return nil }
        return Libelle("apps_ios_android", .texte(noms.joined(separator: ", ")))
    }

    /// Le nom lisible d'un paquet Android : le mot qui le distingue (« com.instagram.android » → « instagram »,
    /// « com.google.android.youtube » → « youtube », « org.telegram.messenger » → « telegram »), sans les mots que tous
    /// les paquets partagent. Un paquet fait de ces seuls mots garde son dernier.
    public static func nomCourt(_ paquet: String) -> String {
        let communs: Set<String> = ["com", "org", "net", "io", "app", "apps", "android", "google", "mobile", "messenger",
                                    "katana", "lite", "client", "free", "pro", "www", "co", "fr", "il", "us"]
        let mots = paquet.lowercased().split(separator: ".").map(String.init).filter { !$0.isEmpty }
        return mots.first { !communs.contains($0) } ?? mots.last ?? paquet
    }

    /// Les noms courts de la liste d'Android, sans doublon, dans l'ordre alphabétique.
    public static func nomsCourts(_ paquets: Set<String>) -> [String] {
        Array(Set(paquets.map(nomCourt))).sorted()
    }
}
