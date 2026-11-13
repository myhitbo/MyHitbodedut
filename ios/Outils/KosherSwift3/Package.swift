// swift-tools-version: 6.0
// Mesure KosherSwift 3.1.2 devant les vecteurs d'Android (tâche 2, décision D4).
// Un outil, pas une dépendance de l'app : il ne fait que chiffrer l'écart avec la 1.10.11.

import PackageDescription

let package = Package(
    name: "KosherSwift3",
    dependencies: [
        .package(url: "https://github.com/Elyahu41/KosherSwift.git",
                 revision: "6b12b4089f2a8b198971b793e6d29e171c3f1b37"),  // étiquette 3.1.2
    ],
    targets: [
        .executableTarget(
            name: "Ecarts312",
            dependencies: [.product(name: "KosherSwift", package: "KosherSwift")]),
    ],
    swiftLanguageModes: [.v5]
)
