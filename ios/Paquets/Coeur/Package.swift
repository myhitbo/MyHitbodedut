// swift-tools-version: 6.0
// Paquet « Coeur » : Swift pur, Foundation, KosherSwift et SQLite, compilable et testé sous Linux
// (PORTAGE.md § 7.1 et § 7.2). Aucune dépendance à UIKit ni à SwiftUI.

import PackageDescription

let package = Package(
    name: "Coeur",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: [
        .library(name: "Coeur", targets: ["Coeur"]),
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
        // L'index de la recherche (RechercheGlobale.swift) : SQLite fait partie d'iOS (module SQLite3) ;
        // sous Linux, celui de la machine (paquet libsqlite3-dev).
        .systemLibrary(
            name: "CSQLite",
            pkgConfig: "sqlite3",
            providers: [.apt(["libsqlite3-dev"])]),
        .target(
            name: "Coeur",
            dependencies: [
                .product(name: "KosherSwift", package: "KosherSwift"),
                .target(name: "CSQLite", condition: .when(platforms: [.linux])),
            ]),
        .testTarget(
            name: "CoeurTests",
            dependencies: ["Coeur", .product(name: "KosherSwift", package: "KosherSwift")]),
    ],
    swiftLanguageModes: [.v6]
)
