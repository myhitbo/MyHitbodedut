// swift-tools-version: 6.0
// Paquet « Coeur » : Swift pur, Foundation et KosherSwift, compilable et testé sous Linux
// (PORTAGE.md § 7.1 et § 7.2). Aucune dépendance à UIKit ni à SwiftUI.

import PackageDescription

// Les fichiers en chantier : versionnés pour ne rien perdre, mais pas encore construits, tant que la
// grappe qui les écrit n'a pas fini (chemins relatifs au dossier de la cible). Vides quand tout est intégré.
let enChantierSources: [String] = [
    "Aeration.swift",
    "BilanSemaine.swift",
    "Boussole.swift",
    "DanseMesure.swift",
    "DirectionJerusalem.swift",
    "Hilloulot.swift",
    "Langues.swift",
    "LanguesTexte.swift",
    "Libelles.swift",
    "LibraryRules.swift",
    "Magnetisme.swift",
    "MarquesPages.swift",
    "MelangeMusique.swift",
    "Onboarding.swift",
    "Paliers.swift",
    "Personnage.swift",
    "PoliceHebraique.swift",
    "RechercheGlobale.swift",
    "Reference.swift",
    "RegleLangue.swift",
    "TerritoireIsrael.swift",
    "Tips.swift",
    "Trophees.swift",
    "VillePlusProche.swift",
    "Vol.swift",
    "VolCalendrier.swift",
    "VolPriere.swift",
]
let enChantierTests: [String] = [
    "BoussoleTests.swift",
    "DirectionJerusalemTests.swift",
    "IlanotTests.swift",
    "LanguesTests.swift",
    "LanguesTexteTests.swift",
    "LibellesTests.swift",
    "LibraryRulesTests.swift",
    "MagnetismeTests.swift",
    "MegilaTests.swift",
    "OnboardingTests.swift",
    "PersonnageTests.swift",
    "PoliceHebraiqueTests.swift",
    "RegleLangueTests.swift",
    "SiddurJourTests.swift",
    "TerritoireIsraelTests.swift",
    "TipsTests.swift",
    "TraductionAffichageTests.swift",
    "VillePlusProcheTests.swift",
    "VolTests.swift",
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
