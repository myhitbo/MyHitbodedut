import CoreGraphics
import Ecrans
import Foundation
import ImageIO
import PDFKit
import UIKit
import Vision

/// La lecture d'un billet choisi par l'utilisateur, PDF ou photo (LecteurBillet.kt d'Android) : le texte du
/// premier code-barres de carte d'embarquement trouvé (PDF417, Aztec, QR, Data Matrix), sur les quatre premières
/// pages d'un PDF (rendues par PDFKit) ou dans l'image, tournée d'un quart de tour au besoin ; nil s'il n'y en a
/// pas. Vision lit sur l'appareil : rien ne part. Le texte est ensuite lu par `CarteEmbarquement` (Coeur).
struct SystemeLecteurBillet: VolLecteurBillet {

    /// Les pages d'un PDF parcourues (LecteurBillet.PAGES_MAX).
    static let pagesMax = 4
    /// Le côté du rendu d'une page : assez pour un PDF417 d'une carte d'embarquement.
    static let cote: CGFloat = 2_000

    init() {}

    func code(_ fichier: URL) async -> String? {
        let ouvert = fichier.startAccessingSecurityScopedResource()
        defer {
            if ouvert { fichier.stopAccessingSecurityScopedResource() }
        }
        for image in SystemeLecteurBillet.images(fichier) {
            if let texte = SystemeLecteurBillet.lire(image) {
                return texte
            }
        }
        return nil
    }

    /// Les images où chercher : les premières pages d'un PDF, sinon l'image elle-même.
    private static func images(_ fichier: URL) -> [CGImage] {
        if let document = PDFDocument(url: fichier) {
            var images: [CGImage] = []
            for rang in 0..<min(document.pageCount, pagesMax) {
                guard let page = document.page(at: rang) else { continue }
                let bornes = page.bounds(for: .mediaBox)
                let echelle = cote / max(bornes.width, bornes.height, 1)
                let taille = CGSize(width: bornes.width * echelle, height: bornes.height * echelle)
                if let image = page.thumbnail(of: taille, for: .mediaBox).cgImage {
                    images.append(image)
                }
            }
            return images
        }
        guard let source = CGImageSourceCreateWithURL(fichier as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return [] }
        return [image]
    }

    /// Le premier code d'une image, droite puis tournée d'un quart de tour.
    private static func lire(_ image: CGImage) -> String? {
        for orientation in [CGImagePropertyOrientation.up, .right] {
            let requete = VNDetectBarcodesRequest()
            requete.symbologies = [.pdf417, .aztec, .qr, .dataMatrix]
            let gestionnaire = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            do {
                try gestionnaire.perform([requete])
            } catch {
                continue
            }
            for observation in requete.results ?? [] {
                if let texte = observation.payloadStringValue, !texte.isEmpty {
                    return texte
                }
            }
        }
        return nil
    }
}
