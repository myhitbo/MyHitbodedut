import Foundation
import Testing
@testable import Coeur

/// MusicLibrary rejoué contre Android (`interface_b.json`, VecteursInterfaceB.kt) : pour chaque état des
/// préférences (noms donnés, morceaux ajoutés, morceau choisi, lisibles ou non), la liste des morceaux,
/// le morceau retenu, la recherche par id, les noms donnés, et ce que deviennent les préférences après
/// un renommage, un ajout ou un retrait. Les titres livrés sont rendus en français par le catalogue.
@Suite("MusicLibrary")
struct MusicLibraryTests {

    private struct Fichier: Decodable {
        let bibliotheque: Bibliotheque
    }

    private struct Bibliotheque: Decodable {
        let titresLivres: [Ligne]
        let cas: [Cas]
    }

    private struct Cas: Decodable {
        let names: String
        let userTracks: String
        let trackId: String?
        let tous: [Element]
        let selected: String?
        let byId: [Ligne]
        let customName: [Ligne]
        let rename: [Ligne]
        let addUserTrack: [Ligne]
        let removeUserTrack: [Ligne]
    }

    /// Un tableau de chaînes, chacune peut-être nulle.
    private struct Ligne: Decodable {
        let valeurs: [String?]

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            var v: [String?] = []
            while !c.isAtEnd {
                if try c.decodeNil() {
                    v.append(nil)
                } else {
                    v.append(try c.decode(String.self))
                }
            }
            valeurs = v
        }

        subscript(_ rang: Int) -> String? { rang < valeurs.count ? valeurs[rang] : nil }
    }

    /// Un morceau de la liste : l'id seul d'un morceau livré qui porte son titre, sinon [id, titre, livré].
    private struct Element: Decodable {
        let id: String
        let titre: String?
        let livre: Bool

        init(from decoder: any Decoder) throws {
            if let seul = try? decoder.singleValueContainer().decode(String.self) {
                id = seul
                titre = nil
                livre = true
                return
            }
            var c = try decoder.unkeyedContainer()
            id = try c.decode(String.self)
            titre = try c.decode(String.self)
            livre = try c.decode(Bool.self)
        }
    }

    private func bibliotheque() throws -> Bibliotheque {
        let donnees = try Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/interface_b.json")
        return try JSONDecoder().decode(Fichier.self, from: donnees).bibliotheque
    }

    private func etat(_ c: Cas) -> MusicLibrary.Etat {
        MusicLibrary.Etat(names: c.names, userTracks: c.userTracks, trackId: c.trackId)
    }

    /// L'égalité de Kotlin, unité UTF-16 par unité : le `==` de Swift tiendrait « é » pour « e » et son
    /// accent, et laisserait passer une adresse ou un JSON rendus sous une autre forme que celle d'Android.
    private func pareil(_ a: String?, _ b: String?) -> Bool {
        a.map { Array($0.utf16) } == b.map { Array($0.utf16) }
    }

    /// Le nom écrit d'un titre, nil pour un titre livré.
    private func nomEcrit(_ titre: MusicLibrary.Titre) -> String? {
        if case .nom(let nom) = titre { return nom }
        return nil
    }

    /// Le titre d'un morceau tel qu'Android l'écrit, résolu en français pour un titre livré.
    private func texte(_ titre: MusicLibrary.Titre, _ catalogue: Catalogue) -> String? {
        let simples = catalogue.simples("fr")
        let pluriels = catalogue.pluriels("fr")
        return titre.texte(langue: "fr", chaine: { simples[$0] }, pluriel: { pluriels["\($0)[\($1)]"] })
    }

    @Test func lesTitresLivresSontCeuxDAndroid() throws {
        let b = try bibliotheque()
        let catalogue = try Catalogue.lire()
        let tous = MusicLibrary.all(MusicLibrary.Etat())
        // Ceux qu'iOS ne livre pas encore (MusiquePlay.horsIOS, 26/11) n'y sont pas.
        let titresLivres = b.titresLivres.filter { ligne in !MusiquePlay.horsIOS.contains { pareil($0, ligne[0]) } }
        #expect(tous.count == titresLivres.count)
        for (rang, ligne) in titresLivres.enumerated() where rang < tous.count {
            let m = tous[rang]
            #expect(pareil(m.id, ligne[0]), "rang \(rang) : \(m.id)")
            let attendu = MusicLibrary.Titre.libelle(Libelle(MusiquePlay.morceaux[rang].titleRes))
            #expect(m.title == attendu, "\(m.id)")
            let t = texte(m.title, catalogue)
            #expect(pareil(t, ligne[1]), "\(m.id) : \(t ?? "nil")")
        }
    }

    @Test func laBibliothequeRepondCommeAndroid() throws {
        let b = try bibliotheque()
        let catalogue = try Catalogue.lire()
        #expect(b.cas.count > 20)
        for (n, c) in b.cas.enumerated() {
            let e = etat(c)
            // La liste : les livrés dans l'ordre de MusiquePlay, puis les ajoutés.
            let tous = MusicLibrary.all(e)
            // Ceux qu'iOS ne livre pas encore (MusiquePlay.horsIOS, 26/11) n'y sont pas.
            let attendus = c.tous.filter { !(MusiquePlay.horsIOS.contains($0.id) && $0.livre) }
            #expect(tous.count == attendus.count, "cas \(n) : \(tous.count) morceaux")
            for (rang, attendu) in attendus.enumerated() where rang < tous.count {
                let m = tous[rang]
                #expect(pareil(m.id, attendu.id), "cas \(n), rang \(rang) : \(m.id)")
                #expect(m.isBundled == attendu.livre, "cas \(n), \(attendu.id)")
                let titreAttendu: MusicLibrary.Titre
                if let titre = attendu.titre {
                    titreAttendu = .nom(titre)
                } else {
                    let livre = MusiquePlay.morceaux.first { $0.id == attendu.id }
                    titreAttendu = .libelle(Libelle(livre?.titleRes ?? "?"))
                }
                #expect(m.title == titreAttendu, "cas \(n), \(attendu.id)")
                #expect(pareil(nomEcrit(m.title), attendu.titre), "cas \(n), \(attendu.id) : titre")
                if m.isBundled {
                    #expect(m.rawRes == m.id && m.uri == nil, "cas \(n), \(m.id)")
                } else {
                    #expect(m.uri == m.id && m.rawRes == nil, "cas \(n), \(m.id)")
                }
            }
            let choisi = MusicLibrary.selected(e)?.id
            #expect(pareil(choisi, c.selected), "cas \(n) : selected \(choisi ?? "nil")")
            for ligne in c.byId {
                let trouve = MusicLibrary.byId(e, ligne[0])
                let idTrouve = trouve?.id
                #expect(pareil(idTrouve, ligne[1]), "cas \(n) : byId(\(ligne[0] ?? "null")) : \(idTrouve ?? "nil")")
                // Le titre tel qu'Android l'écrit : le nom donné, ou le titre livré résolu en français.
                let titre: String?
                if let trouve {
                    titre = texte(trouve.title, catalogue)
                } else {
                    titre = nil
                }
                #expect(pareil(titre, ligne[2]), "cas \(n) : titre de byId(\(ligne[0] ?? "null")) : \(titre ?? "nil")")
            }
            for ligne in c.customName {
                let nom = MusicLibrary.customName(e, id: ligne[0] ?? "")
                #expect(pareil(nom, ligne[1]), "cas \(n) : customName(\(ligne[0] ?? "")) : \(nom ?? "nil")")
            }
            for ligne in c.rename {
                var apres = e
                MusicLibrary.rename(&apres, id: ligne[0] ?? "", title: ligne[1] ?? "")
                #expect(pareil(apres.names, ligne[2]), "cas \(n) : rename(\(ligne[0] ?? ""), « \(ligne[1] ?? "") ») : \(apres.names)")
                #expect(apres.userTracks == e.userTracks && apres.trackId == e.trackId, "cas \(n) : rename")
            }
            for ligne in c.addUserTrack {
                var apres = e
                MusicLibrary.addUserTrack(&apres, uri: ligne[0] ?? "", title: ligne[1] ?? "")
                #expect(pareil(apres.userTracks, ligne[2]), "cas \(n) : addUserTrack(\(ligne[0] ?? "")) : \(apres.userTracks)")
                #expect(apres.names == e.names && apres.trackId == e.trackId, "cas \(n) : addUserTrack")
            }
            for ligne in c.removeUserTrack {
                var apres = e
                MusicLibrary.removeUserTrack(&apres, id: ligne[0] ?? "")
                #expect(pareil(apres.userTracks, ligne[1]), "cas \(n) : removeUserTrack(\(ligne[0] ?? "")) : \(apres.userTracks)")
                #expect(pareil(apres.trackId, ligne[2]), "cas \(n) : removeUserTrack(\(ligne[0] ?? "")), trackId \(apres.trackId ?? "nil")")
                #expect(apres.names == e.names, "cas \(n) : removeUserTrack")
            }
        }
    }

    @Test func lesValeursParDefautSontCellesDeStore() {
        let e = MusicLibrary.Etat()
        #expect(e.names == "{}")
        #expect(e.userTracks == "[]")
        #expect(e.trackId == nil)
        let premier = MusicLibrary.selected(e)?.id
        #expect(premier == MusiquePlay.morceaux.first?.id)
    }

    @Test func unMorceauAjouteSeRetrouveEtSeRetire() throws {
        var e = MusicLibrary.Etat()
        MusicLibrary.addUserTrack(&e, uri: "file:///Documents/niggoun.m4a", title: "Mon niggoun")
        e.trackId = "file:///Documents/niggoun.m4a"
        let choisi = try #require(MusicLibrary.selected(e))
        let titreAttendu = MusicLibrary.Titre.nom("Mon niggoun")
        #expect(choisi.title == titreAttendu)
        #expect(!choisi.isBundled)
        let compte = MusicLibrary.all(e).count
        #expect(compte == MusiquePlay.morceaux.count + 1)
        MusicLibrary.removeUserTrack(&e, id: "file:///Documents/niggoun.m4a")
        #expect(e.trackId == nil)
        #expect(e.userTracks == "[]")
    }
}
