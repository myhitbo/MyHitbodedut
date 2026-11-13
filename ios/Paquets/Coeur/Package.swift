// swift-tools-version: 6.0
// Paquet « Coeur » : Swift pur, Foundation et KosherSwift, compilable et testé sous Linux
// (PORTAGE.md § 7.1 et § 7.2). Aucune dépendance à UIKit ni à SwiftUI.

import PackageDescription

let package = Package(
    name: "Coeur",
    platforms: [.iOS("26.5"), .macOS("26.0")],
    products: [
        .library(name: "Coeur", targets: ["Coeur"]),
    ],
    dependencies: [
        // KosherSwift 1.10.11 (LGPL 2.1), épinglé par révision : la dernière étiquette à l'API
        // et aux définitions de KosherJava 2.5.0, celui d'Android (PORTAGE.md § 5.1, décision D4).
        // À remplacer par le fork public de l'organisation, même révision (décision D12).
        .package(url: "https://github.com/Elyahu41/KosherSwift.git",
                 revision: "1fb606ea5b02c87b0a02931ecf3c06503134b6fc"),
    ],
    targets: [
        .target(
            name: "Coeur",
            dependencies: [.product(name: "KosherSwift", package: "KosherSwift")]),
        .testTarget(
            name: "CoeurTests",
            dependencies: ["Coeur", .product(name: "KosherSwift", package: "KosherSwift")]),
    ],
    swiftLanguageModes: [.v6]
)
