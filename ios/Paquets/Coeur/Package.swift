// swift-tools-version: 6.0
// Paquet « Coeur » : Swift pur, Foundation et KosherSwift, compilable et testé sous Linux
// (PORTAGE.md § 7.1 et § 7.2). Aucune dépendance à UIKit ni à SwiftUI.

import PackageDescription

// Les fichiers en chantier : versionnés pour ne rien perdre, mais pas encore construits, tant que la
// grappe qui les écrit n'a pas fini (chemins relatifs au dossier de la cible). Vides quand tout est intégré.
let enChantierSources: [String] = [
    "Adresse.swift",
    "Anneaux.swift",
    "Boussole.swift",
    "ChabbatAlerte.swift",
    "DirectionJerusalem.swift",
    "GuideSujets.swift",
    "Halakha.swift",
    "Hitbodedut.swift",
    "JaugeSemaine.swift",
    "Langues.swift",
    "Levana.swift",
    "LevanaAlerte.swift",
    "Libelles.swift",
    "Magnetisme.swift",
    "Modele.swift",
    "Onboarding.swift",
    "Personnage.swift",
    "Plaque.swift",
    "PoliceHebraique.swift",
    "Poses.swift",
    "QuestionsBlocage.swift",
    "Reglages.swift",
    "Reminder.swift",
    "ReminderRule.swift",
    "Salutation.swift",
    "Tefilot.swift",
    "Tehilim.swift",
    "TerritoireIsrael.swift",
    "Theme.swift",
    "Tikkun.swift",
    "Tips.swift",
    "VillePlusProche.swift",
    "Vol.swift",
    "VolCalendrier.swift",
    "VolPriere.swift",
    "YalkutYosef.swift",
    "ZmanimVignette.swift",
    "ZmanimWidget.swift",
]
let enChantierTests: [String] = [
    "AdresseTests.swift",
    "AnneauxTests.swift",
    "BoussoleTests.swift",
    "ChabbatAlerteTests.swift",
    "DirectionJerusalemTests.swift",
    "DureeCourteTests.swift",
    "GuideSujetsTests.swift",
    "HalakhaTests.swift",
    "HitbodedutTests.swift",
    "IlanotTests.swift",
    "JaugeSemaineTests.swift",
    "LanguesTests.swift",
    "LevanaAlerteTests.swift",
    "LevanaTests.swift",
    "LibellesTests.swift",
    "MagnetismeTests.swift",
    "MegilaTests.swift",
    "ModeleTests.swift",
    "OnboardingTests.swift",
    "PersonnageTests.swift",
    "PlaqueTests.swift",
    "PoliceHebraiqueTests.swift",
    "PosesTests.swift",
    "QuestionsBlocageTests.swift",
    "ReglagesTests.swift",
    "ReminderRuleTests.swift",
    "ReminderTests.swift",
    "ReminderTimesTests.swift",
    "SalutationTests.swift",
    "SiddurJourTests.swift",
    "TefilotTests.swift",
    "TehilimTests.swift",
    "TerritoireIsraelTests.swift",
    "ThemeTests.swift",
    "TikkunTests.swift",
    "TipsTests.swift",
    "VillePlusProcheTests.swift",
    "VolTests.swift",
    "YalkutYosefTests.swift",
    "ZmanimVignetteTests.swift",
    "ZmanimWidgetTests.swift",
]

let package = Package(
    name: "Coeur",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: [
        .library(name: "Coeur", targets: ["Coeur"]),
        // Les modèles d'écran de l'app : Observation et Coeur, sans SwiftUI, testés sous Linux.
        .library(name: "Ecrans", targets: ["Ecrans"]),
    ],
    dependencies: [
        // KosherSwift 1.10.11 (LGPL 2.1) : la dernière étiquette à l'API et aux définitions de
        // KosherJava 2.5.0, celui d'Android (PORTAGE.md § 5.1, décision D4). Fork public de
        // l'organisation (décision D12), branche linux-1.10.11 : l'étiquette 1.10.11 et un seul
        // commit, qui la fait compiler sous Linux sans toucher aux calculs (ios/KOSHERSWIFT.md).
        .package(url: "https://github.com/myhitbo/KosherSwift.git",
                 revision: "97551b47c3682fbf97ec95adae891d5c3e7dd076"),
    ],
    targets: [
        .target(
            name: "Coeur",
            dependencies: [.product(name: "KosherSwift", package: "KosherSwift")],
            exclude: enChantierSources),
        .testTarget(
            name: "CoeurTests",
            dependencies: ["Coeur", .product(name: "KosherSwift", package: "KosherSwift")],
            exclude: enChantierTests),
        .target(
            name: "Ecrans",
            dependencies: ["Coeur"]),
        .testTarget(
            name: "EcransTests",
            dependencies: ["Ecrans", "Coeur"]),
    ],
    swiftLanguageModes: [.v6]
)
