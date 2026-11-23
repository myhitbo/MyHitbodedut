import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Coeur
import Ecrans
#if canImport(VisionKit) && os(iOS)
import VisionKit
#endif

/// Le billet du vol (VolActivity.carteRapide, « Importer le billet (PDF ou photo) ») : le bouton de la saisie rapide,
/// qui propose de lire la carte d'embarquement avec l'appareil photo (VisionKit, là où le téléphone le permet), de
/// choisir une photo du billet (la photothèque), ou un fichier, PDF ou image (Fichiers, le sélecteur d'Android). Le
/// code-barres est lu sur le téléphone ; `VolModele` en tire la route, le numéro et la date (CarteEmbarquement), et
/// dit ce qui manque. Rien ne paraît sans lecteur de billet (`billetDisponible`).
struct VolBilletBouton: View {
    let modele: VolModele
    @Environment(\.traducteur) private var traducteur
    @State private var choix = false
    @State private var fichier = false
    @State private var photo = false
    @State private var photoChoisie: PhotosPickerItem? = nil
    @State private var scanner = false

    var body: some View {
        Button {
            choix = true
        } label: {
            Label {
                Text(Libelle("vol_rapide_billet"), traducteur: traducteur)
            } icon: {
                Image(systemName: "airplane.departure")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.secondaire)
        .confirmationDialog(Text(Libelle("vol_rapide_billet"), traducteur: traducteur), isPresented: $choix,
                            titleVisibility: .visible) {
            if VolBilletBouton.scanPossible {
                Button {
                    scanner = true
                } label: {
                    Text(Libelle("ios_vol_billet_scanner"), traducteur: traducteur)
                }
            }
            Button {
                photo = true
            } label: {
                Text(Libelle("ios_vol_billet_photo"), traducteur: traducteur)
            }
            Button {
                fichier = true
            } label: {
                Text(Libelle("ios_vol_billet_fichier"), traducteur: traducteur)
            }
        }
        .fileImporter(isPresented: $fichier, allowedContentTypes: [.pdf, .image]) { resultat in
            guard case .success(let url) = resultat else { return }
            Task { await modele.importerBillet(url) }
        }
        .photosPicker(isPresented: $photo, selection: $photoChoisie, matching: .images)
        .onChange(of: photoChoisie) { _, item in
            guard let item else { return }
            photoChoisie = nil
            Task {
                // La photo copiée dans un fichier provisoire, que le lecteur de billet lit comme un fichier choisi.
                guard let image = try? await item.loadTransferable(type: VolBilletImage.self) else { return }
                await modele.importerBillet(image.url)
                try? FileManager.default.removeItem(at: image.url)
            }
        }
        .fullScreenCover(isPresented: $scanner) {
            VolBilletScanneur { code in
                scanner = false
                Task { await modele.lireCodeBillet(code) }
            } fermer: {
                scanner = false
            }
        }
    }

    /// La lecture en direct par l'appareil photo est possible sur ce téléphone (DataScannerViewController : une puce
    /// assez récente, l'appareil photo autorisé ou pas encore demandé).
    static var scanPossible: Bool {
        #if canImport(VisionKit) && os(iOS)
        return DataScannerViewController.isSupported
        #else
        return false
        #endif
    }
}

/// Une photo de la photothèque, reçue comme un fichier (son type d'image gardé), copiée dans le dossier provisoire.
struct VolBilletImage: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { recu in
            let nom = "billet-" + UUID().uuidString + "." + (recu.file.pathExtension.isEmpty ? "jpg" : recu.file.pathExtension)
            let copie = URL.temporaryDirectory.appending(path: nom)
            try FileManager.default.copyItem(at: recu.file, to: copie)
            return VolBilletImage(url: copie)
        }
    }
}

/// La lecture de la carte d'embarquement par l'appareil photo : l'image en direct, la consigne, « Retour ». Le
/// premier code-barres reconnu (PDF417, Aztec, QR, Data Matrix) ferme l'écran et passe son texte au modèle.
struct VolBilletScanneur: View {
    let trouve: @MainActor (String) -> Void
    let fermer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            #if canImport(VisionKit) && os(iOS)
            VolBilletCamera(trouve: trouve)
                .ignoresSafeArea()
            #endif
            VStack(spacing: 12) {
                Text(Libelle("ios_vol_billet_viser"), traducteur: traducteur)
                    .font(Font.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.55), in: Capsule())
                Spacer()
                Button(action: fermer) {
                    Text(Libelle("action_back"), traducteur: traducteur)
                        .font(Font.body.weight(.semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 28)
                        .frame(minHeight: 50)
                        .background(Color.black.opacity(0.55), in: Capsule())
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}

#if canImport(VisionKit) && os(iOS)
/// L'image de l'appareil photo et la reconnaissance des codes-barres (DataScannerViewController de VisionKit).
private struct VolBilletCamera: UIViewControllerRepresentable {
    let trouve: @MainActor (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vue = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.pdf417, .aztec, .qr, .dataMatrix])],
                                            qualityLevel: .accurate, recognizesMultipleItems: false,
                                            isHighFrameRateTrackingEnabled: false, isHighlightingEnabled: true)
        vue.delegate = context.coordinator
        return vue
    }

    func updateUIViewController(_ vue: DataScannerViewController, context: Context) {
        context.coordinator.trouve = trouve
        // La lecture commence quand l'écran est posé ; un refus de l'appareil photo laisse l'image noire et « Retour ».
        if !vue.isScanning { try? vue.startScanning() }
    }

    static func dismantleUIViewController(_ vue: DataScannerViewController, coordinator: Coordinateur) {
        vue.stopScanning()
    }

    func makeCoordinator() -> Coordinateur {
        Coordinateur(trouve: trouve)
    }

    @MainActor
    final class Coordinateur: NSObject, DataScannerViewControllerDelegate {
        var trouve: @MainActor (String) -> Void
        private var lu = false

        init(trouve: @escaping @MainActor (String) -> Void) {
            self.trouve = trouve
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !lu else { return }
            for item in addedItems {
                if case .barcode(let code) = item, let texte = code.payloadStringValue {
                    lu = true
                    dataScanner.stopScanning()
                    trouve(texte)
                    return
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            self.dataScanner(dataScanner, didAdd: [item], allItems: [item])
        }
    }
}
#endif
