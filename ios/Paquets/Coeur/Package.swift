// swift-tools-version: 6.0
// Paquet « Coeur » : Swift pur, Foundation et KosherSwift, compilable et testé sous Linux
// (PORTAGE.md § 7.1 et § 7.2). Aucune dépendance à UIKit ni à SwiftUI.

import Foundation
import PackageDescription

// COEUR_SANS_VUES : la CI construit et teste le cœur sans les vues (travail « coeur ») ; un second travail
// (« vues ») construit les vues contre SwiftUI de papier. Sans la variable (Xcode), tout est là.
let avecVues = ProcessInfo.processInfo.environment["COEUR_SANS_VUES"] == nil

// Les fichiers en chantier : versionnés pour ne rien perdre, mais pas encore construits, tant que la
// grappe qui les écrit n'a pas fini (chemins relatifs au dossier de la cible). Vides quand tout est intégré.
let enChantierSources: [String] = [
    "Aeroports.swift",
    "Ambiance.swift",
    "Autorisation.swift",
    "Depot.swift",
    "Hilloulot.swift",
    "MusicLibrary.swift",
    "MusiquePlay.swift",
    "RechercheGlobale.swift",
    "SaisieVol.swift",
    "Sauvegarde.swift",
    "VignetteDecor.swift",
    "WidgetTaille.swift",
]
let enChantierTests: [String] = [
    "AmbianceTests.swift",
    "AutorisationTests.swift",
    "DepotTests.swift",
    "HilloulotTests.swift",
    "MusicLibraryTests.swift",
    "MusiquePlayTests.swift",
    "RechercheGlobaleTests.swift",
    "RenameTrackTests.swift",
    "SauvegardeTests.swift",
    "VignetteDecorTests.swift",
    "WidgetTailleTests.swift",
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

if avecVues {
    // Les vues SwiftUI de l'app. Sous Linux, elles se type-checkent contre SwiftUIDePapier (signatures seules).
    package.products.append(.library(name: "Vues", targets: ["Vues"]))
    package.targets.append(.target(name: "SwiftUIDePapier"))
    package.targets.append(.target(
        name: "Vues",
        dependencies: ["Ecrans", "Coeur", .target(name: "SwiftUIDePapier", condition: .when(platforms: [.linux]))]))
}
