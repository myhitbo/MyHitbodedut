// swift-tools-version: 6.0
// Paquet « Coeur » : Swift pur, Foundation seule, compilable et testé sous Linux
// (PORTAGE.md § 7.1 et § 7.2). Aucune dépendance à UIKit ni à SwiftUI.

import PackageDescription

let package = Package(
    name: "Coeur",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: [
        .library(name: "Coeur", targets: ["Coeur"]),
    ],
    targets: [
        .target(name: "Coeur"),
        .testTarget(name: "CoeurTests", dependencies: ["Coeur"]),
    ],
    swiftLanguageModes: [.v6]
)
