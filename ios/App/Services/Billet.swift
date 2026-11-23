import CoreGraphics
import Ecrans
import Foundation
import ImageIO
import PDFKit
import UIKit
import Vision

/// Le lecteur de billet (LecteurBillet.kt, 04/11) : dans un billet en PDF ou en photo, le code-barres de la carte
/// d'embarquement (PDF417, Aztec, QR, Data Matrix), lu par Vision sur le téléphone — rien ne part, aucune autorisation
/// (le fichier est choisi par l'utilisateur). Les pages d'un PDF se rendent et se lisent une à une, quatre au plus,
/// et la lecture s'arrête au premier code ; une image se lit telle quelle, puis tournée d'un quart de tour. Le
/// contenu du code est ensuite lu par `CarteEmbarquement` (Coeur), dans `VolModele`.
struct LecteurBilletSysteme: VolLecteurBillet {

    /// LecteurBillet.PAGES_MAX et COTE_MAX : le plus grand côté d'une page rendue ou d'une image lue, en pixels.
    static let pagesMax = 4
    static let coteMax: CGFloat = 2400

    func code(_ fichier: URL) async -> String? {
        // Hors du fil de l'interface : le rendu d'une page et la lecture de Vision prennent leur temps.
        await Task.detached(priority: .userInitiated) {
            LecteurBilletSysteme.lire(fichier)
        }.value
    }

    private static func lire(_ fichier: URL) -> String? {
        let accede = fichier.startAccessingSecurityScopedResource()
        defer { if accede { fichier.stopAccessingSecurityScopedResource() } }
        if fichier.pathExtension.lowercased() == "pdf" {
            return codeDuPdf(fichier)
        }
        guard let image = image(fichier) else { return nil }
        return decoder(image)
    }

    private static func codeDuPdf(_ fichier: URL) -> String? {
        guard let pdf = PDFDocument(url: fichier) else { return nil }
        for i in 0..<min(pdf.pageCount, pagesMax) {
            guard let page = pdf.page(at: i) else { continue }
            let boite = page.bounds(for: .mediaBox)
            let echelle = coteMax / max(boite.width, boite.height, 1)
            let taille = CGSize(width: max(boite.width * echelle, 1), height: max(boite.height * echelle, 1))
            // Sur fond blanc, comme RENDER_MODE_FOR_PRINT sur un bitmap effacé en blanc.
            guard let rendue = page.thumbnail(of: taille, for: .mediaBox).cgImage else { continue }
            if let code = decoder(rendue) { return code }
        }
        return nil
    }

    /// L'image du fichier, réduite pour que son plus grand côté ne dépasse pas `coteMax`, son orientation appliquée.
    private static func image(_ fichier: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(fichier as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(coteMax),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Le texte du premier code de l'image, puis de l'image tournée d'un quart de tour.
    private static func decoder(_ image: CGImage) -> String? {
        for orientation in [CGImagePropertyOrientation.up, .right] {
            let requete = VNDetectBarcodesRequest()
            requete.symbologies = [.pdf417, .aztec, .qr, .dataMatrix]
            let lecteur = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            do {
                try lecteur.perform([requete])
            } catch {
                continue
            }
            if let texte = requete.results?.lazy.compactMap({ $0.payloadStringValue }).first {
                return texte
            }
        }
        return nil
    }
}
