// La présentation du premier lancement (Onboarding.kt d'Android) : la table des sept écrans et les règles
// du parcours. L'écran lui-même (OnboardingActivity) reste à Android ; celui d'iOS viendra avec son jalon.
// Les ressources portent les noms d'Android : R.string.x devient la clé « x » du catalogue
// (Localizable.xcstrings), R.drawable.x l'image « x » (ios/Ressources/Images).

/// Un écran d'accueil au premier lancement.
public struct OnboardingEcran: Sendable, Hashable {
    public let cle: String
    /// La clé de la chaîne du titre.
    public let titre: String
    /// La clé de la chaîne du texte.
    public let corps: String
    /// Le nom de l'image.
    public let illustration: String
    /// L'écran porte les deux boutons צדיק / צדקת.
    public let choixAdresse: Bool
    /// L'écran propose la durée habituelle (16/10, point 10) : 5, 10, 15 ou 30 min.
    public let choixDuree: Bool
    /// L'écran propose le rappel quotidien et son heure (16/10, point 10).
    public let choixRappel: Bool

    public init(cle: String, titre: String, corps: String, illustration: String,
                choixAdresse: Bool = false, choixDuree: Bool = false, choixRappel: Bool = false) {
        self.cle = cle
        self.titre = titre
        self.corps = corps
        self.illustration = illustration
        self.choixAdresse = choixAdresse
        self.choixDuree = choixDuree
        self.choixRappel = choixRappel
    }
}

/// Les écrans du premier lancement : ce qu'est la hitbodedout, puis ce que fait l'application, une fonction
/// par écran, et enfin sa promesse.
///
/// Une application de pratique religieuse qui s'ouvre sur un tableau de bord muet demande à celui qui
/// l'installe de deviner ce qu'on attend de lui. Le dernier écran est le seul que personne d'autre ne peut
/// dire à sa place : ce qu'on y écrit ne quitte pas le téléphone, et l'application ne se connecte que si on
/// le lui demande. Sur Android, un test tient cette phrase aux manifestes.
///
/// On peut passer, et on ne les revoit plus, sauf depuis les réglages.
public enum Onboarding {

    /// À augmenter quand la présentation change assez pour être remontrée à tous. 1 : le booléen de la
    /// v1.96 ; 2 : l'adresse n'est plus demandée qu'ici, et la présentation revient aux installations
    /// existantes. `Reglages.hasOnboarded` compare la version vue à la même (`Reglages.versionPresentation`).
    public static let version = 2

    /// Les durées proposées à l'accueil, en minutes : les quatre premières de l'écran de pratique.
    public static let durees = [5, 10, 15, 30]

    /// Recopiés par programme d'Onboarding.kt ; les tests les comparent entrée par entrée à `interface_a.json`.
    public static let ecrans: [OnboardingEcran] = [
        OnboardingEcran(
            cle: "pratique",
            titre: "onboarding_practice",
            corps: "onboarding_practice_body",
            illustration: "char_open_arms"
        ),
        OnboardingEcran(
            cle: "seance",
            titre: "onboarding_session",
            corps: "onboarding_session_body",
            illustration: "char_praying",
            choixDuree: true
        ),
        OnboardingEcran(
            cle: "jours",
            titre: "onboarding_days",
            corps: "onboarding_days_body",
            illustration: "char_writing",
            choixRappel: true
        ),
        OnboardingEcran(
            cle: "textes",
            titre: "onboarding_texts",
            corps: "onboarding_texts_body",
            illustration: "char_tehilim"
        ),
        // La barrière du matin, la promesse centrale de l'édition complète (13/11, FACCUEIL-04). Android ne la
        // présente que là où elle existe (BuildConfig.HAS_GATE) ; l'iOS a la sienne (Sources/Barriere).
        OnboardingEcran(
            cle: "barriere",
            titre: "onboarding_gate",
            corps: "onboarding_gate_body",
            illustration: "char_thinking"
        ),
        OnboardingEcran(
            cle: "reglages",
            titre: "onboarding_yours",
            corps: "onboarding_yours_body",
            illustration: "char_pointing"
        ),
        OnboardingEcran(
            cle: "adresse",
            titre: "onboarding_adresse",
            corps: "onboarding_adresse_body",
            illustration: "char_dancing",
            choixAdresse: true
        ),
        OnboardingEcran(
            cle: "prive",
            titre: "onboarding_private",
            // Sans suivi en direct, OpenSky n'est pas nommé (Android : construction Play sans relais). L'iOS n'appelle
            // jamais OpenSky directement et aucune construction ne lui donne encore de relais (VolEnLigne).
            corps: "onboarding_private_body_route",
            illustration: "char_thumbs_up"
        ),
    ]

    /// Les écrans d'une édition : la construction sans barrière (SANS_BARRIERE, l'édition légère d'Android sans
    /// HAS_GATE) n'a pas la page qui la présente (FACCUEIL-04). Les règles sans `avecBarriere` sont celles de
    /// l'édition complète.
    public static func ecrans(avecBarriere: Bool) -> [OnboardingEcran] {
        avecBarriere ? ecrans : ecrans.filter { $0.cle != "barriere" }
    }

    /// Le rang du dernier écran (`ECRANS.lastIndex`).
    public static let dernier = ecrans.count - 1

    public static func dernier(avecBarriere: Bool) -> Int {
        ecrans(avecBarriere: avecBarriere).count - 1
    }

    /// L'écran de ce rang, ramené dans les bornes.
    public static func ecran(_ index: Int, avecBarriere: Bool = true) -> OnboardingEcran {
        ecrans(avecBarriere: avecBarriere)[borne(index, avecBarriere)]
    }

    /// Le rang suivant, ramené dans les bornes. `index + 1` se compte sur les 32 bits d'un Int de Kotlin :
    /// Int.MAX_VALUE + 1 y repasse à Int.MIN_VALUE, donc au premier écran, comme sur Android.
    public static func suivant(_ index: Int, avecBarriere: Bool = true) -> Int {
        borne(Int(Int32(truncatingIfNeeded: index) &+ 1), avecBarriere)
    }

    /// Le rang précédent, ramené dans les bornes ; Int.MIN_VALUE − 1 repasse à Int.MAX_VALUE, comme sur Android.
    public static func precedent(_ index: Int, avecBarriere: Bool = true) -> Int {
        borne(Int(Int32(truncatingIfNeeded: index) &- 1), avecBarriere)
    }

    public static func estPremier(_ index: Int) -> Bool {
        index <= 0
    }

    public static func estDernier(_ index: Int, avecBarriere: Bool = true) -> Bool {
        index >= dernier(avecBarriere: avecBarriere)
    }

    /// `coerceIn(0, DERNIER)`.
    private static func borne(_ index: Int, _ avecBarriere: Bool) -> Int {
        min(max(index, 0), dernier(avecBarriere: avecBarriere))
    }
}
