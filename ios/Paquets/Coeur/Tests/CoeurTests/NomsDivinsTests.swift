import Foundation
import Testing
@testable import Coeur

/// NomsDivinsTest d'Android, porté : le Nom en toutes lettres dans les prières et les versets
/// (demande du 04/10/2026) : siddour des trois nusa'him, Tehilim, Tikoun. Dans les livres
/// (citations du 'hizouk, bibliothèque), il est abrégé ה' hors des versets cités (demande du
/// 04/11/2026, tools/noms_abreges.py). Les consignes (« c »), les dates et les notes peuvent
/// garder ה׳ (« ה׳ בכסלו »).
@Suite("Noms divins")
struct NomsDivinsTests {

    /// Parcourt un JSON et relève chaque chaîne qui abrège le Nom.
    private struct Releve {
        let ignores: Set<String> = ["_meta", "meta", "note", "notes", "c", "date", "source", "sources"]
        let abreges: [Motif]
        /// יְיָ ou יי nu : cherché sur le texte vocalisé, pour ne pas confondre avec un mot comme
        /// בִּכְיִי (« mes pleurs »).
        let yudYud: Motif
        /// Voyelles et signes de cantillation, maqaf et sof pasouq gardés.
        let signes: Motif

        init() throws {
            abreges = try [
                Motif(#"(?:^|[\s(\[>־])[ובלמשכה]{0,2}ה['׳](?!["'״])"#),
                Motif(#"(?:^|[\s(\[>־])[ובלמשכה]{0,2}אלק(?:ים|י|ינו|יך|יכם|יהם|יו)(?=$|[\s,.:;!?)\]׃<־])"#),
                Motif(#"אד[-־]ני"#),
            ]
            yudYud = try Motif(#"(?:^|[\s(\[>־])(?:[ובלמשכה][\u05B0-\u05BC\u05C1\u05C2]*){0,2}(?:יְיָ|יי)(?=$|[\s,.:;!?)\]׃<])"#.nfc)
            signes = try Motif(#"[\u0591-\u05BD\u05BF-\u05C2\u05C4\u05C5\u05C7]"#)
        }

        func fautes(_ nom: String, _ donnees: Data) throws -> [String] {
            let racine = try JSONSerialization.jsonObject(with: donnees)
            var sortie: [String] = []
            parcours(racine, nom, &sortie)
            return sortie
        }

        private func parcours(_ o: Any, _ chemin: String, _ sortie: inout [String]) {
            if let objet = o as? [String: Any] {
                for (cle, valeur) in objet where !ignores.contains(cle) {
                    parcours(valeur, "\(chemin).\(cle)", &sortie)
                }
            } else if let liste = o as? [Any] {
                for (i, valeur) in liste.enumerated() {
                    parcours(valeur, "\(chemin)[\(i)]", &sortie)
                }
            } else if let texte = o as? String {
                let normal = texte.nfc
                let nu = signes.remplace(normal)
                for motif in abreges {
                    if let trouve = motif.trouve(nu) {
                        sortie.append("\(chemin) : « \(trouve.trimmingCharacters(in: .whitespacesAndNewlines)) »")
                    }
                }
                if let trouve = yudYud.trouve(normal) {
                    sortie.append("\(chemin) : « \(trouve.trimmingCharacters(in: .whitespacesAndNewlines)) »")
                }
            }
        }
    }

    private func verifie(_ nom: String, _ fichier: String) throws {
        let trouves = try Releve().fautes(nom, Depot.contenu(fichier))
        #expect(trouves.isEmpty, "Nom abrégé :\n\(trouves.joined(separator: "\n"))")
    }

    private func texte(_ fichier: String) throws -> String {
        let donnees = try Depot.contenu(fichier)
        return String(decoding: donnees, as: UTF8.self)
    }

    @Test func siddurDesTroisNusahimEnToutesLettres() throws {
        for n in Nusah.allCases {
            try verifie("siddur_\(n.rawValue)", n.fichier)
        }
    }

    /// Les livres (04/11) : « לִפְנֵי ה' יִתְבָּרַךְ », jamais le Nom entier devant « יתברך » (aucun
    /// verset ne le dit) ; les versets cités gardent le Nom entier.
    @Test func livresAbregesHorsDesVersets() throws {
        let entier = try Motif(#"י\p{M}*ה\p{M}*ו\p{M}*ה\p{M}*\s+יִתְבָּרַךְ|יהוה\s+יתברך"#.nfc)
        for (nom, fichier) in [("chizuk", "chizuk.json"), ("bibliotheque", "bibliotheque.json")] {
            let t = try texte(fichier).nfc
            #expect(!entier.present(dans: t), "\(nom) : le Nom entier devant יתברך")
            #expect(t.contient("ה' יִתְבָּרַךְ".nfc) || t.contient("ה' יתברך"), "\(nom) : ה' manquant")
            #expect(t.contient("קָרוֹב יְהֹוָה לְכָל".nfc), "\(nom) : le verset de Tehilim 145:18 a perdu le Nom")
        }
    }

    @Test func tehilimEtTikkunEnToutesLettres() throws {
        try verifie("tehilim", "tehilim.json")
        try verifie("tikkun", "tikkun_haklali.json")
    }

    /// Un préfixe sans voyelle reprend celle du Tanakh : לַיהֹוָה, et non ליְהֹוָה.
    @Test func prefixesVocalisesCommeDansLeTanakh() throws {
        let prefixe = try Motif(#"(?:^|[\s"])[לבכו]יְהֹוָה"#.nfc)
        let chizuk = try texte("chizuk.json").nfc, bibliotheque = try texte("bibliotheque.json").nfc
        #expect(!prefixe.present(dans: chizuk))
        #expect(!prefixe.present(dans: bibliotheque))
        // Abrégé, le préfixe garde sa voyelle : לַה'.
        #expect(bibliotheque.contient("לַה'".nfc) || chizuk.contient("לַה'".nfc))
    }

    /// Le seul ה׳ gardé dans la bibliothèque est une date, hors du texte.
    @Test func laDateDu5KislevResteEcriteEnChiffreHebreu() throws {
        let bibliotheque = try texte("bibliotheque.json")
        #expect(bibliotheque.contient("ה׳ בכסלו"))
    }
}
