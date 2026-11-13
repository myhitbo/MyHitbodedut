import Foundation
import Testing
@testable import Coeur

/// LivresTest d'Android, porté : les livres entiers de la bibliothèque (12/10,
/// tools/livres_construction.py), lus comme l'app les lira, par l'index puis livre par livre,
/// entiers ou chapitre par chapitre quand l'export les a découpés.
@Suite("Livres")
struct LivresTests {

    private static let charges: Result<Siddur, any Error> = Result { try Livres.tous(Depot.lire) }

    private func livres() throws -> Siddur { try Self.charges.get() }

    private func livre(_ id: String) throws -> SiddurTexte {
        let tous = try livres()
        return try #require(tous.texte(id), "\(id) absent")
    }

    private let voyelles = #"[\u05B0-\u05BC\u05C1\u05C2\u05C7]"#

    /// Le livres.json d'Android, d'où sortent livres_titres.json et les livre_<id>.json, puis la
    /// découpe de l'export : ce que l'app lit redonne exactement la source, livre par livre.
    @Test func laDecoupeRedonneLaSourceLivreParLivre() throws {
        let source = try JSONDecoder().decode(Siddur.self, from: Depot.donnees("android/app/src/main/livres/livres.json"))
        let lus = try livres()
        #expect(lus.groupes == source.groupes)
        #expect(lus.textes.map(\.id) == source.textes.map(\.id))
        for (lu, attendu) in zip(lus.textes, source.textes) {
            let pareil = lu == attendu
            #expect(pareil, "\(attendu.id) : le livre lu n'est pas celui de la source")
        }
        // L'index a chaque livre, dans l'ordre, avec son nombre de chapitres et sans texte.
        let index = try Livres.index(Depot.lire)
        #expect(index.groupes == source.groupes)
        #expect(index.textes.map(\.id) == source.textes.map(\.id))
        #expect(index.textes.map(\.chapitres) == source.textes.map(\.sections.count))
        #expect(index.textes.allSatisfy(\.sections.isEmpty))
        // Chaque livre a son fichier, ou son dossier s'il est découpé, et il n'y en a pas d'autre.
        let contenu = Depot.racine.appendingPathComponent("ios/Ressources/Contenu")
        let entiers = try FileManager.default.contentsOfDirectory(atPath: contenu.path)
            .filter { $0.hasPrefix("livre_") && $0.hasSuffix(".json") }
            .map { String($0.dropFirst("livre_".count).dropLast(".json".count)) }
        let decoupes = try FileManager.default.contentsOfDirectory(atPath: contenu.appendingPathComponent("livres").path)
            .filter { !$0.hasPrefix(".") }
        #expect(Set(entiers).isDisjoint(with: decoupes))
        #expect((entiers + decoupes).sorted() == source.textes.map(\.id).sorted())
    }

    @Test func lesLivresSontLaChapitreParChapitre() throws {
        let tous = try livres()
        #expect(tous.textes.map(\.id) == [
            "guide_hitbodedut", "likoutei_etsot", "sefer_hamidot", "likoutei_moharan", "hichtapkhout", "kokhvei_or",
            "tefila_lishlomo", "meguilat_esther", "chir_hachirim", "nichmat", "perek_chira", "yalkut_yosef_kitsour",
        ])
        // Le nombre de chapitres de chaque livre, tel que l'imprime son édition (13/10) ; les 1 048
        // simanim du Kitsour Yalkut Yosef (19/10) ; le guide du propriétaire, un chapitre par partie,
        // et les dix feuillets du Yanuka (19/10).
        let chapitres = [("likoutei_moharan", 286 + 125), ("hichtapkhout", 105), ("meguilat_esther", 10),
                         ("chir_hachirim", 8), ("nichmat", 1), ("perek_chira", 7), ("yalkut_yosef_kitsour", 1048),
                         ("guide_hitbodedut", 18), ("tefila_lishlomo", 10)]
        for (id, n) in chapitres {
            let nombre = try livre(id).sections.count
            #expect(nombre == n, "\(id)")
        }
        let etsot = try livre("likoutei_etsot"), midot = try livre("sefer_hamidot")
        #expect(etsot.sections.count > 50)
        #expect(midot.sections.count > 50)
        for t in tous.textes {
            #expect(t.sections.allSatisfy { !$0.titre.blanc && !$0.blocs.isEmpty }, "\(t.id)")
            #expect(!t.titre.he.blanc && !t.titre.fr.blanc && !t.titre.en.blanc, "\(t.id)")
        }
    }

    @Test func likouteiEtsotSansNikkoudSeferHamiddotVocalise() throws {
        let voyelle = try Motif(voyelles)
        let etsot = try livre("likoutei_etsot").sections.flatMap(\.blocs)
        #expect(!etsot.contains { voyelle.present(dans: $0.texte) })
        let midot = try livre("sefer_hamidot").sections.flatMap(\.blocs).filter { !$0.consigne }
        #expect(midot.filter { voyelle.present(dans: $0.texte) }.count > midot.count * 9 / 10)
    }

    @Test func lesAjoutsDu13OctobreSontVocalisesDeuxGroupes() throws {
        let voyelle = try Motif(voyelles)
        for id in ["likoutei_moharan", "hichtapkhout", "kokhvei_or", "meguilat_esther", "chir_hachirim", "nichmat", "perek_chira"] {
            let blocs = try livre(id).sections.flatMap(\.blocs).filter { !$0.consigne && $0.texte.utf16.count > 40 }
            #expect(blocs.filter { voyelle.present(dans: $0.texte) }.count > blocs.count * 9 / 10, "\(id)")
        }
        let tous = try livres()
        #expect(tous.groupes.map(\.cle) == ["livres", "meguilot", "halakha"])
        let esther = try livre("meguilat_esther"), nichmat = try livre("nichmat")
        #expect(esther.sections.first?.blocs.first?.texte.commencePar("(א) וַיְהִי בִּימֵי אֲחַשְׁוֵרוֹשׁ") == true)
        #expect(nichmat.sections.first?.blocs.first?.texte.contient("נִשְׁמַת כָּל חַי") == true)
    }

    /// Les deux textes du propriétaire (19/10, tools/livres_textes_proprietaire.py) : rien des notes
    /// de transcription en français n'y passe, et les feuillets du Yanuka ont le Nom abrégé hors des
    /// versets (04/11), entier dans les versets.
    @Test func leGuideEtLesFeuilletsDuYanukaSansNotesNiAbreviations() throws {
        let latin = try Motif("[A-Za-zÀ-ÿ]{3,}"), balise = try Motif("<[^>]+>")
        for id in ["guide_hitbodedut", "tefila_lishlomo"] {
            for b in try livre(id).sections.flatMap(\.blocs) {
                let nu = balise.remplace(b.texte).replacingOccurrences(of: "MyHitbodedut", with: "")
                #expect(!latin.present(dans: nu) && !nu.contient("**") && !nu.hasPrefix("#"), "\(id) : \(nu)")
            }
        }
        let abrege = try Motif(#"(?<![\u05D0-\u05EA\u0591-\u05C7])[\u05D5\u05D1\u05DC\u05DE\u05E9\u05DB]{0,2}[\u0591-\u05C7]*\u05D4['\u05F3]|\u05D0[\u0591-\u05C7]*-[\u05DC\u05D3]"#)
        let alefTiret = try Motif(#"\u05D0[\u0591-\u05C7]*-[\u05DC\u05D3]"#)
        let yanuka = try livre("tefila_lishlomo")
        // Depuis le 04/11 (tools/noms_abreges.py) : le Nom abrégé ה' hors des versets, entier dans
        // les versets cités (Habacuc 3 : « יְהֹוָה שָׁמַעְתִּי שִׁמְעֲךָ »). Pas de forme א-ל.
        let prieres = yanuka.sections.flatMap(\.blocs).filter { !$0.consigne }.map(\.texte)
        #expect(prieres.contains { abrege.present(dans: $0) })
        #expect(prieres.contains { $0.contient("יְהֹוָה שָׁמַעְתִּי") })
        for t in prieres {
            #expect(!alefTiret.present(dans: t), "\(t)")
        }
        #expect(yanuka.sections.allSatisfy { $0.blocs.first.map { $0.consigne && $0.texte.contient("שליט״א") } == true })
        let troisieme = try #require(yanuka.sections.dropFirst(2).first)
        let deuxiemeBloc = try #require(troisieme.blocs.dropFirst().first)
        #expect(deuxiemeBloc.texte.commencePar("אֱלֹהֵי אַבְרָהָם"))
    }
}
