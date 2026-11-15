import Foundation
import Testing
@testable import Coeur

/// CoffreTest d'Android, porté, et ce que le Swift seul doit prouver de ses briques : SHA-256, PBKDF2,
/// AES-256 et GCM devant leurs vecteurs publiés (FIPS 180-4, RFC 7914 § 11, FIPS 197 C.3, cas 13 et 14
/// de NIST pour GCM), puis la sauvegarde chiffrée du site (web/test/vecteur_coffre.json), que Coffre.kt
/// et coffre.js relisent aussi.
@Suite("Coffre")
struct CoffreTests {

    private func hexa(_ octets: [UInt8]) -> String {
        octets.map { o -> String in
            let s = String(o, radix: 16)
            return s.count == 1 ? "0" + s : s
        }.joined()
    }

    private func octets(_ hexa: String) -> [UInt8] {
        let u = Array(hexa.utf8)
        return stride(from: 0, to: u.count, by: 2).map { UInt8(String(decoding: u[$0..<($0 + 2)], as: UTF8.self), radix: 16) ?? 0 }
    }

    private struct Vecteur {
        let motDePasse: String
        let clair: String
        let chiffre: ObjetJSON
    }

    private func vecteur() throws -> Vecteur {
        let o = try ObjetJSON(texte: Depot.texte("web/test/vecteur_coffre.json"))
        return Vecteur(motDePasse: o.texte("mot_de_passe"), clair: o.texte("clair"), chiffre: try #require(o.objet("chiffre")))
    }

    // MARK: Les briques

    @Test func sha256() {
        #expect(hexa(SHA256.octets(SHA256.hacher(Array("abc".utf8)))) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(hexa(SHA256.octets(SHA256.hacher([]))) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        let deuxBlocs = Array("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)
        #expect(hexa(SHA256.octets(SHA256.hacher(deuxBlocs))) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test func pbkdf2() {
        let p = Array("password".utf8), s = Array("salt".utf8)
        #expect(hexa(SHA256.pbkdf2(p, sel: s, iterations: 1)) == "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
        #expect(hexa(SHA256.pbkdf2(p, sel: s, iterations: 2)) == "ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43")
        #expect(hexa(SHA256.pbkdf2(p, sel: s, iterations: 4096)) == "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
        // Une clé plus longue qu'un bloc est d'abord hachée.
        let longue = [UInt8](repeating: 0x61, count: 100)
        #expect(SHA256.pbkdf2(longue, sel: s, iterations: 3) == SHA256.pbkdf2(SHA256.octets(SHA256.hacher(longue)), sel: s, iterations: 3))
    }

    @Test func aes256() {
        let aes = AES256(cle: octets("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"))
        #expect(hexa(aes.chiffrer(octets("00112233445566778899aabbccddeeff"))) == "8ea2b7ca516745bfeafc49904b496089")
    }

    @Test func gcm() {
        let gcm = AESGCM(cle: [UInt8](repeating: 0, count: 32))
        let iv = [UInt8](repeating: 0, count: 12)
        let vide = gcm.sceller([], iv: iv)
        #expect(vide.chiffre.isEmpty && hexa(vide.sceau) == "530f8afbc74536b9a963b4f1c4cb738b")
        let bloc = gcm.sceller([UInt8](repeating: 0, count: 16), iv: iv)
        #expect(hexa(bloc.chiffre) == "cea7403d4d606b6e074ec5d3baf39d18")
        #expect(hexa(bloc.sceau) == "d0d1c8a799996bf0265b98b5d48ab919")
        #expect(gcm.ouvrir(bloc.chiffre, sceau: bloc.sceau, iv: iv) == [UInt8](repeating: 0, count: 16))
        var abime = bloc.chiffre
        abime[3] ^= 1
        #expect(gcm.ouvrir(abime, sceau: bloc.sceau, iv: iv) == nil)
        #expect(gcm.ouvrir(bloc.chiffre, sceau: Array(bloc.sceau.dropLast()), iv: iv) == nil)
    }

    @Test func base64CommeJava() {
        for n in 0..<8 {
            let o = (0..<n).map { UInt8($0 * 37 & 255) }
            let t = Base64Java.coder(o)
            #expect(t == Data(o).base64EncodedString(), "\(n)")
            #expect(Base64Java.decoder(t) == o, "\(n)")
        }
        // java.util.Base64 : le bourrage est facultatif, tout autre signe refusé.
        #expect(Base64Java.decoder("YWI") == Array("ab".utf8))
        #expect(Base64Java.decoder("YWJj") == Array("abc".utf8))
        #expect(Base64Java.decoder("YQ==") == Array("a".utf8))
        #expect(Base64Java.decoder("YQ=") == nil)
        #expect(Base64Java.decoder("Y") == nil)
        #expect(Base64Java.decoder("YW Jj") == nil)
        #expect(Base64Java.decoder("YWJj\n") == nil)
        #expect(Base64Java.decoder("YQ==YQ==") == nil)
    }

    // MARK: CoffreTest d'Android

    /// Le fichier écrit par la version web (coffre.js) se lit ici : même format, même dérivation.
    @Test func uneSauvegardeChiffreeParLeWebSeLitSurIOS() throws {
        let v = try vecteur()
        #expect(Coffre.estChiffre(v.chiffre.texte()))
        #expect(Coffre.dechiffrer(v.chiffre.texte(), motDePasse: v.motDePasse) == v.clair)
    }

    /// Au même sel et au même vecteur, iOS écrit exactement ce que le site a écrit.
    @Test func leChiffrementRendLesOctetsDuSite() throws {
        let v = try vecteur()
        let sel = try #require(Base64Java.decoder(v.chiffre.texte("salt")))
        let iv = try #require(Base64Java.decoder(v.chiffre.texte("iv")))
        let ecrit = try ObjetJSON(texte: Coffre.chiffrer(v.clair, motDePasse: v.motDePasse, iterations: v.chiffre.entier("iterations"),
                                                        sel: sel, iv: iv))
        #expect(ecrit.cles == ["format", "version", "kdf", "iterations", "salt", "iv", "data"])
        #expect(ecrit == v.chiffre)
    }

    @Test func leBonMotDePasseRendLeTexteUnAutreNeRendRien() throws {
        let clair = #"{"format":"myhitbodedut","days":{"2026-11-12":{"note":"שלום, une note intime"}}}"#
        let chiffre = Coffre.chiffrer(clair, motDePasse: "mot de passe é", iterations: 100_000)
        #expect(Coffre.estChiffre(chiffre))
        #expect(!chiffre.contains("intime"), "la note se lit dans le fichier")
        // Le mot de passe est mis en forme NFC : « é » décomposé ouvre aussi.
        #expect(Coffre.dechiffrer(chiffre, motDePasse: "mot de passe e\u{301}") == clair)
        #expect(Coffre.dechiffrer(chiffre, motDePasse: "mot de passe e") == nil)
        // Écrit comme Android : indenté de deux espaces, « / » de base64 échappé.
        #expect(chiffre.hasPrefix("{\n  \"format\": \"myhitbodedut-chiffre\",\n  \"version\": 1,"))
        #expect(!chiffre.contains("/") || chiffre.contains("\\/"))
    }

    @Test func deuxExportsDuMemeTexteNeSeRessemblentPas() throws {
        // Sel et vecteur neufs à chaque fois ; la clé n'est pas calculée ici.
        let a = try ObjetJSON(texte: Coffre.chiffrer("x", motDePasse: "a", iterations: 100_000))
        let b = try ObjetJSON(texte: Coffre.chiffrer("x", motDePasse: "a", iterations: 100_000))
        #expect(a.texte("salt") != b.texte("salt") && a.texte("iv") != b.texte("iv"))
        #expect(Base64Java.decoder(a.texte("salt"))?.count == 16 && Base64Java.decoder(a.texte("iv"))?.count == 12)
    }

    @Test func unFichierModifieOuFabriqueEstRefuse() throws {
        let v = try vecteur()
        var r = v.chiffre
        let data = r.texte("data")
        r["data"] = .chaine((data.hasPrefix("A") ? "B" : "A") + data.dropFirst())
        #expect(Coffre.dechiffrer(r.texte(), motDePasse: v.motDePasse) == nil)
        // Une clé presque gratuite à deviner, ou un calcul sans fin : refusés avant tout calcul.
        for n in [1, 99_999, 5_000_001, 2_000_000_000] {
            var faux = v.chiffre
            faux["iterations"] = .entier(Int64(n))
            #expect(Coffre.dechiffrer(faux.texte(), motDePasse: v.motDePasse) == nil, "\(n)")
        }
        let alterations: [(String, JSON)] = [("version", .entier(2)), ("kdf", .chaine("PBKDF2-HMAC-SHA1")), ("iv", .chaine("AAAA")),
                                             ("salt", .chaine("AAAA")), ("data", .chaine("pas du base64 !"))]
        for (cle, valeur) in alterations {
            var faux = v.chiffre
            faux[cle] = valeur
            #expect(Coffre.dechiffrer(faux.texte(), motDePasse: v.motDePasse) == nil, "\(cle)")
        }
        #expect(Coffre.dechiffrer(v.clair, motDePasse: v.motDePasse) == nil)
        #expect(!Coffre.estChiffre(v.clair))
        #expect(!Coffre.estChiffre("pas du json"))
    }

    /// Ce qu'Android répond à `Coffre.estChiffre` (Tests/Vecteurs/sauvegarde.json).
    @Test func estChiffreCommeAndroid() throws {
        let cas = try #require(Depot.vecteurs("sauvegarde.json").objet("coffre")?.tableau("estChiffre"))
        #expect(cas.count == 5)
        for i in cas.indices {
            let paire = try #require(cas.tableau(i))
            #expect(Coffre.estChiffre(paire.texte(0)) == paire.booleen(1), "\(paire.texte(0))")
        }
    }
}
