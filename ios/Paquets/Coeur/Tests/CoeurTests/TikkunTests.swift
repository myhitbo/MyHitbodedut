import Foundation
import Testing
@testable import Coeur

/// TikkunTest d'Android, porté en entier : l'ordre des dix psaumes, l'intégrité du texte, les
/// parties liturgiques, puis tout `Tests/Vecteurs/tikkun.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursTikkun.kt).
///
/// L'ordre n'est pas un détail d'affichage — c'est ce qui fait le Tikoun. Il est donc figé ici
/// plutôt que laissé à la bonne tenue du fichier.
@Suite("Tikoun HaKlali")
struct TikkunTests {

    /// Ordre établi, recoupé le 20/09/2026 sur deux sources indépendantes (Wikipedia « Tikkun
    /// HaKlali » et breslov.org).
    private let ordre = [16, 32, 41, 42, 59, 77, 90, 105, 137, 150]

    private func lireTikkun() throws -> Tikkun {
        try TikkunLoader.load(Depot.lire)
    }

    /// Un verset du Tikoun, ou l'échec du test s'il manque.
    private func verset(_ tikkun: Tikkun, _ psaume: Int, _ numero: Int) throws -> Verse {
        let p = try #require(tikkun.byNumero(psaume))
        let trouve = p.versets.first { $0.numero == numero }
        return try #require(trouve)
    }

    /// `trimEnd()` de Kotlin, puis `endsWith`.
    private static func finitPar(_ texte: String, _ fin: String) -> Bool {
        var unites = Array(texte.utf16)
        while let derniere = unites.last, Kotlin.estEspace(derniere) {
            unites.removeLast()
        }
        return Unites.texte(unites).finitParUnites(fin)
    }

    @Test func lesDixPsaumesSontLaDansLOrdre() throws {
        let tikkun = try lireTikkun()
        let numeros = tikkun.psaumes.map { $0.numero }, attendu = ordre
        #expect(numeros == attendu)
        let constante = Tikkun.ordre
        #expect(constante == attendu)
    }

    @Test func chaquePsaumePorteSesVersetsNumerotesSansTrou() throws {
        let tikkun = try lireTikkun()
        for p in tikkun.psaumes {
            let vide = p.versets.isEmpty
            #expect(!vide, "\(p.id) : aucun verset")
            let attendus = (0..<p.versets.count).map { $0 + 1 }
            let numeros = p.versets.map { $0.numero }
            #expect(numeros == attendus, "\(p.id) : numérotation des versets")
            for v in p.versets {
                let blanc = v.he.estBlanc
                #expect(!blanc, "\(p.id):\(v.numero) vide")
            }
        }
    }

    @Test func leTotalDeVersetsEstCeluiDuTexteMassoretique() throws {
        // 11+11+14+12+18+21+17+45+9+6
        let versets = try lireTikkun().versets
        #expect(versets == 164)
    }

    @Test func lesIdentifiantsSontUniques() throws {
        let ids = try lireTikkun().psaumes.map { Array($0.id.utf16) }
        let distincts = Set(ids).count
        #expect(ids.count == distincts)
    }

    @Test func lEditionEstDuDomainePublicEtVocalisee() throws {
        let edition = try lireTikkun().edition
        let licence = edition.licence.egalUnites("Public Domain")
        #expect(licence)
        let nikkoud = edition.nikkoudOk
        #expect(nikkoud, "l'édition doit autoriser le nikkoud")
    }

    /// Le Nom est écrit en toutes lettres, comme dans les sources (décision du propriétaire,
    /// 04/10/2026) : plus aucune forme substituée, ni dans les psaumes ni dans la liturgie.
    @Test func leNomEstEcritEnToutesLettres() throws {
        let tikkun = try lireTikkun()
        let substitues = [ExpressionReguliere("ה'(?![\"״])"), ExpressionReguliere("אל\u{05B9}?ק"),
                          ExpressionReguliere("אֲדֹ-נָי")]
        var fautes: [String] = []
        for p in tikkun.psaumes {
            for v in p.versets {
                let nu = v.he.formeNFC
                for motif in substitues where motif.presente(dans: nu) {
                    fautes.append("\(p.ref):\(v.numero) substitue le Nom")
                }
            }
        }
        for cle in [Tikkun.ouverture, Tikkun.cloture, Tikkun.kavana, Tikkun.priere] {
            guard let bloc = tikkun.bloc(cle) else { continue }
            for (i, para) in bloc.paragraphes.enumerated() {
                let nu = para.formeNFC
                for motif in substitues where motif.presente(dans: nu) {
                    fautes.append("\(bloc.cle)[\(i)] substitue le Nom")
                }
            }
        }
        let aucune = fautes.isEmpty
        let detail = fautes.joined(separator: "\n")
        #expect(aucune, "\(detail)")
        // Le premier psaume du Tikoun s'ouvre sur le Nom (16:1 dit אֵל ; 16:2 le Tétragramme).
        let p16 = try #require(tikkun.byNumero(16))
        let assez = p16.versets.count > 1
        try #require(assez)
        let tetragramme = p16.versets[1].he.contientUnites("יהוָה")
        #expect(tetragramme)
    }

    /// Les quatre parties liturgiques reprises de la page fournie : ce qui se dit avant, les versets
    /// de clôture, la kavana, la prière de Rabbi Natan.
    @Test func lesPartiesLiturgiquesSontChargees() throws {
        let tikkun = try lireTikkun()
        for cle in [Tikkun.ouverture, Tikkun.cloture, Tikkun.kavana, Tikkun.priere] {
            let bloc = try #require(tikkun.bloc(cle), "bloc « \(cle) » absent")
            let vide = bloc.paragraphes.isEmpty
            #expect(!vide, "bloc « \(cle) » vide")
            let sansTitre = bloc.titre.he.estBlanc
            #expect(!sansTitre, "bloc « \(cle) » sans titre")
            for paragraphe in bloc.paragraphes {
                let blanc = paragraphe.estBlanc
                #expect(!blanc, "bloc « \(cle) » : paragraphe vide")
            }
        }
        let avant = tikkun.avant.count, apres = tikkun.apres.count
        #expect(avant == 1)
        #expect(apres == 3)
    }

    /// La kavana est la seule exception à la substitution des noms divins, et c'est délibéré : elle
    /// enseigne l'épellation des deux Noms et leur milouy, dont la guematria 485 vaut תהלים. Le
    /// fichier doit porter cette justification, sans quoi l'exception passerait pour un oubli.
    @Test func lExceptionDeLaKavanaEstJustifieeDansLeFichier() throws {
        let donnees = try Depot.contenu("tikkun_haklali.json")
        let racine = try ObjetJSON(texte: String(decoding: donnees, as: UTF8.self))
        let kavana = try #require(racine.objet(Tikkun.kavana))
        let justifiee = kavana.a("note_substitution")
        #expect(justifiee, "la kavana garde l'écriture de sa source sans dire pourquoi")
    }

    /// L'indication d'arrêt de Tehilim 32:7 : ce qu'elle dit, et d'où elle vient. Le pictogramme et
    /// le mot « הפסק » de la page fournie ne doivent plus y figurer — elle se lit comme une
    /// parenthèse, pas comme une alerte.
    @Test func lIndicationDArretEstUneParentheseAvecSaSource() throws {
        let v = try verset(lireTikkun(), 32, 7)
        let arret = try #require(v.arret, "aucune indication d'arrêt en 32:7")
        let source = arret.note.contientUnites("ליקוטי מוהר") && arret.note.contientUnites("רי\"ג")
        #expect(source, "l'indication ne dit pas d'où elle vient")
        let parentheses = arret.note.contientUnites("(") && arret.note.contientUnites(")")
        #expect(parentheses, "la source doit être entre parenthèses")
        let pictogramme = arret.note.contientUnites("\u{23F8}")
        #expect(!pictogramme, "le pictogramme d'arrêt subsiste")
        let dansLeVerset = v.he.contientUnites(arret.avant)
        #expect(dansLeVerset, "le mot d'arrêt doit se trouver dans le verset")
    }

    /// L'arrêt se marque dans le verset : après « אַתָּה סֵתֶר לִי », avant « מִצַּר ».
    @Test func lArretCoupeLeVersetAvantMitsar() throws {
        let v = try verset(lireTikkun(), 32, 7)
        let coupe = try #require(v.coupe(), "pas de coupe en 32:7")
        let debut = coupe.debut.egalUnites("אַתָּה סֵתֶר לִי")
        #expect(debut)
        let suite = coupe.suite.commenceParUnites("מִצַּר")
        #expect(suite)
        let recousu = (coupe.debut + " " + coupe.suite).egalUnites(v.he)
        #expect(recousu)
        let sansArret = Verse(numero: 1, he: "א ב").coupe() == nil
        #expect(sansArret)
    }

    /// Le texte des psaumes ne vient pas de la page fournie mais d'une édition massorétique. La page
    /// porte une coquille confirmée sur trois éditions — 105:20, dagesh manquant — et c'est la forme
    /// correcte qui doit être ici.
    @Test func lePsaume105Verset20PorteLeDagesh() throws {
        let v = try verset(lireTikkun(), 105, 20)
        let dagesh = v.he.contientUnites("וַיַּתִּירֵהוּ")
        #expect(dagesh, "105:20 doit lire וַיַּתִּירֵהוּ et non וַיַתִּירֵהוּ")
    }

    /// Graphie massorétique. La page fournie s'en écartait sur cinq points ; les trois éditions
    /// consultées s'accordent contre elle sur tous, et ce sont elles qui tranchent.
    @Test func lesPsaumesSuiventLaGraphieMassoretique() throws {
        let tikkun = try lireTikkun()
        var textes: [String] = []
        var deuxPoints: [String] = []
        for p in tikkun.psaumes {
            for v in p.versets {
                textes.append(v.he)
                if TikkunTests.finitPar(v.he, ":") { deuxPoints.append("\(p.ref):\(v.numero)") }
            }
        }
        let tout = textes.joined(separator: " ")
        let maqqef = tout.contientUnites("\u{05BE}")
        #expect(maqqef, "aucun maqqef : la graphie n'est plus massorétique")
        let sofPasuk = tout.contientUnites("\u{05C3}")
        #expect(sofPasuk, "aucun sof-pasuk : la graphie n'est plus massorétique")
        let aucun = deuxPoints.isEmpty
        let detail = deuxPoints.joined(separator: ", ")
        #expect(aucun, "un verset finit par « : » : c'est la ponctuation de siddour (\(detail))")
    }

    /// La lecture d'un trait a besoin de sa consigne : c'est elle qui dit pourquoi cet écran n'a
    /// aucun bouton entre les psaumes.
    @Test func laConsigneDeContinuiteEstChargee() throws {
        let continuite = try lireTikkun().continuite
        let hebreu = continuite.he.egalUnites("להמשיך מזה לזה ברצף אחד, ללא הפסק")
        #expect(hebreu)
        for langue in ["fr", "en"] {
            let blanc = continuite.pour(langue).estBlanc
            #expect(!blanc, "consigne de continuité absente en « \(langue) »")
        }
    }

    /// Ce que l'écran de lecture continue enchaîne : l'ouverture, les dix psaumes, la clôture. La
    /// kavana et la prière de Rabbi Natan restent hors du trait — elles se disent après.
    @Test func leTraitCouvreLOuvertureLesDixPsaumesEtLaCloture() throws {
        let tikkun = try lireTikkun()
        let avant = tikkun.avant.map { $0.cle }
        #expect(avant == [Tikkun.ouverture])
        let cloture = tikkun.bloc(Tikkun.cloture) != nil
        #expect(cloture, "la clôture manque")
        let psaumes = tikkun.psaumes.count
        #expect(psaumes == 10)
        // Présentes, mais pas dans le trait.
        let kavana = tikkun.bloc(Tikkun.kavana) != nil, priere = tikkun.bloc(Tikkun.priere) != nil
        #expect(kavana)
        #expect(priere)
    }

    /// Les deux graphies lexicales où les éditions contredisent la page. Le pointage de ירושלם varie
    /// d'un verset à l'autre dans l'édition massorétique — qamats en 137:5, patah en 137:6 — donc la
    /// forme ne se vérifie pas par une chaîne littérale mais par ce qui distingue les deux graphies :
    /// le plene insère un yod avant le mem, le défectif non.
    @Test func yerushalayimEstDefectifEtHalleluyahEnDeuxMots() throws {
        let tikkun = try lireTikkun()
        let plene = ExpressionReguliere("י\\u05B0רו\\u05BCש\\u05B8\\u05C1ל\\u05B7י\\u05B4ם")
        let defectif = ExpressionReguliere("י\\u05B0רו\\u05BCש\\u05B8\\u05C1ל\\u05B4[\\u05B7\\u05B8]ם")
        let p137 = try #require(tikkun.byNumero(137))
        var defectifs = 0
        for v in p137.versets {
            if defectif.presente(dans: v.he) { defectifs += 1 }
            let pleine = plene.presente(dans: v.he)
            #expect(!pleine, "137:\(v.numero) porte la graphie plene ירושלים")
        }
        let nombreDeDefectifs = defectifs
        #expect(nombreDeDefectifs == 3, "ירושלם doit apparaitre dans trois versets du psaume 137")
        let v105 = try verset(tikkun, 105, 45)
        let v150 = try verset(tikkun, 150, 6)
        for v in [v105, v150] {
            let deuxMots = v.he.contientUnites("הַלְלוּ־יָהּ")
            #expect(deuxMots, "הללו־יה doit rester en deux mots")
        }
    }

    /// La marque d'arrêt vit dans son propre champ. Dans la page fournie elle est écrite au milieu du
    /// verset ; l'y laisser aurait mis « ⏸ הפסק » dans le texte hébreu lui-même.
    @Test func aucuneMarqueDeLectureNAFuiDansLeTexte() throws {
        let tikkun = try lireTikkun()
        for p in tikkun.psaumes {
            for v in p.versets {
                let pictogramme = v.he.contientUnites("\u{23F8}")
                #expect(!pictogramme, "\(p.ref):\(v.numero) contient le pictogramme d'arrêt")
                let mot = v.he.contientUnites("הפסק")
                #expect(!mot, "\(p.ref):\(v.numero) contient le mot « הפסק »")
            }
        }
    }

    /// Le qere est retenu : aucune notation « ketiv [qere] » ne doit subsister.
    @Test func aucuneNotationKetivQereNeSubsiste() throws {
        let tikkun = try lireTikkun()
        for p in tikkun.psaumes {
            for v in p.versets {
                let crochet = v.he.contientUnites("[")
                #expect(!crochet, "\(p.ref):\(v.numero) porte un crochet")
            }
        }
    }

    @Test func chaquePsaumeRenvoieASaSource() throws {
        let tikkun = try lireTikkun()
        for p in tikkun.psaumes {
            let sefaria = TikkunTests.memeTexte(p.refSefaria, "Psalms \(p.numero)")
            #expect(sefaria, "\(p.id) : ref_sefaria")
            let lien = (p.url ?? "").commenceParUnites("https://")
            #expect(lien, "\(p.id) : pas de lien")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let ouverture: String
            let cloture: String
            let kavana: String
            let priere: String
            let ordre: [Int]
        }
        struct Localise: Decodable {
            let he: String
            let fr: String
            let en: String
        }
        struct EditionLue: Decodable {
            let cle: String
            let titre: String
            let licence: String
            let nikkoudOk: Bool
        }
        struct ArretLu: Decodable {
            let avant: String
            let note: String
        }
        /// Le fichier livré : chaque texte long par son empreinte (`String.hashCode`).
        struct BlocLivre: Decodable {
            let cle: String
            let titre: Localise
            let note: Localise?
            let formule: String?
            let paragraphes: [Int32]
            let paragraphesFr: [Int32]
            let paragraphesEn: [Int32]
        }
        struct Livre: Decodable {
            let version: String
            let titre: Localise
            let edition: EditionLue
            let continuite: Localise
            let versets: Int
            let avant: [String]
            let apres: [String]
            let blocs: [BlocLivre]
        }
        struct VersetLivre: Decodable {
            let n: Int
            let he: Int32
            let arret: ArretLu?
            let fr: Int32?
            let en: Int32?
            let coupe: [Int32]?
        }
        struct PsaumeLivre: Decodable {
            let id: String
            let numero: Int
            let ref: String
            let refSefaria: String?
            let url: String?
            let versets: [VersetLivre]
        }
        struct ParNumero: Decodable {
            let numero: Int
            let id: String?
        }
        struct ParCle: Decodable {
            let cle: String
            let trouve: String?
        }
        /// Un verset écrit à la main, `Verse(1, he, Pause(avant, "note"))` ; sans arrêt si `avant` est null.
        struct Coupe: Decodable {
            let he: String
            let avant: String?
            let coupe: [String]?
        }
        /// Un document écrit à la main : tout en clair.
        struct Verset: Decodable {
            let n: Int
            let he: String
            let arret: ArretLu?
            let fr: String?
            let en: String?
            let coupe: [String]?
        }
        struct Psaume: Decodable {
            let id: String
            let numero: Int
            let ref: String
            let refSefaria: String?
            let url: String?
            let versets: [Verset]
        }
        struct Bloc: Decodable {
            let cle: String
            let titre: Localise
            let note: Localise?
            let formule: String?
            let paragraphes: [String]
            let paragraphesFr: [String]
            let paragraphesEn: [String]
        }
        struct Lu: Decodable {
            let version: String
            let titre: Localise
            let edition: EditionLue
            let continuite: Localise
            let versets: Int
            let psaumes: [Psaume]
            let blocs: [Bloc]
            let avant: [String]
            let apres: [String]
            let byNumero: [ParNumero]
        }
        struct Document: Decodable {
            let nom: String
            let json: String
            let lu: Bool
            let tikkun: Lu?
        }

        let constantes: Constantes
        let livre: Livre
        let psaumes: [PsaumeLivre]
        let byNumero: [ParNumero]
        let bloc: [ParCle]
        let coupes: [Coupe]
        let documents: [Document]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/tikkun.json"))
    }

    /// `==` de Kotlin : les mêmes unités UTF-16, ou deux absences.
    private static func memeTexte(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.egalUnites(y)
        default: return false
        }
    }

    private static func memesTextes(_ a: [String], _ b: [String]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) where !x.egalUnites(y) {
            return false
        }
        return true
    }

    private static func memeLocalise(_ a: TexteLocalise?, _ b: Vecteurs.Localise?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.he.egalUnites(y.he) && x.fr.egalUnites(y.fr) && x.en.egalUnites(y.en)
        default: return false
        }
    }

    private static func memeEdition(_ a: Edition, _ b: Vecteurs.EditionLue) -> Bool {
        a.cle.egalUnites(b.cle) && a.titre.egalUnites(b.titre) && a.licence.egalUnites(b.licence) && a.nikkoudOk == b.nikkoudOk
    }

    private static func memeArret(_ a: Pause?, _ b: Vecteurs.ArretLu?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.avant.egalUnites(y.avant) && x.note.egalUnites(y.note)
        default: return false
        }
    }

    private static func empreintes(_ textes: [String]) -> [Int32] {
        var resultat: [Int32] = []
        for texte in textes {
            resultat.append(Kotlin.hashCode(texte))
        }
        return resultat
    }

    /// La coupe en clair, comme le générateur l'écrit : [début, suite], ou nil.
    private static func coupe(_ v: Verse) -> [String]? {
        guard let c = v.coupe() else { return nil }
        return [c.debut, c.suite]
    }

    private static func memeCoupe(_ a: [String]?, _ b: [String]?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return memesTextes(x, y)
        default: return false
        }
    }

    @Test func leFichierLivreEstLuCommeSurAndroid() throws {
        let v = try vecteurs()
        let c = v.constantes
        let cles = [Tikkun.ouverture, Tikkun.cloture, Tikkun.kavana, Tikkun.priere]
        let clesAndroid = [c.ouverture, c.cloture, c.kavana, c.priere]
        #expect(cles == clesAndroid)
        let constante = Tikkun.ordre
        #expect(constante == c.ordre)

        let tikkun = try lireTikkun()
        let l = v.livre
        let version = tikkun.version.egalUnites(l.version)
        #expect(version)
        let titre = TikkunTests.memeLocalise(tikkun.titre, l.titre)
        #expect(titre)
        let edition = TikkunTests.memeEdition(tikkun.edition, l.edition)
        #expect(edition)
        let continuite = TikkunTests.memeLocalise(tikkun.continuite, l.continuite)
        #expect(continuite)
        let versets = tikkun.versets
        #expect(versets == l.versets)
        let avant = tikkun.avant.map { $0.cle }, apres = tikkun.apres.map { $0.cle }
        #expect(avant == l.avant)
        #expect(apres == l.apres)
        let nombreDeBlocs = tikkun.blocs.count
        #expect(nombreDeBlocs == l.blocs.count)
        for b in l.blocs {
            let bloc = try #require(tikkun.bloc(b.cle), "bloc « \(b.cle) »")
            let cle = bloc.cle.egalUnites(b.cle)
            #expect(cle, "\(b.cle) : clé")
            let titreBloc = TikkunTests.memeLocalise(bloc.titre, b.titre)
            #expect(titreBloc, "\(b.cle) : titre")
            let note = TikkunTests.memeLocalise(bloc.note, b.note)
            #expect(note, "\(b.cle) : note")
            let formule = TikkunTests.memeTexte(bloc.formule, b.formule)
            #expect(formule, "\(b.cle) : formule")
            let paragraphes = TikkunTests.empreintes(bloc.paragraphes)
            #expect(paragraphes == b.paragraphes, "\(b.cle) : paragraphes")
            let fr = TikkunTests.empreintes(bloc.paragraphesFr), en = TikkunTests.empreintes(bloc.paragraphesEn)
            #expect(fr == b.paragraphesFr, "\(b.cle) : paragraphes_fr")
            #expect(en == b.paragraphesEn, "\(b.cle) : paragraphes_en")
        }

        let nombreDePsaumes = tikkun.psaumes.count
        #expect(nombreDePsaumes == v.psaumes.count)
        for (p, attendu) in zip(tikkun.psaumes, v.psaumes) {
            let ou = attendu.id
            let identite = p.id.egalUnites(attendu.id) && p.numero == attendu.numero && p.ref.egalUnites(attendu.ref)
            let liens = TikkunTests.memeTexte(p.refSefaria, attendu.refSefaria) && TikkunTests.memeTexte(p.url, attendu.url)
            #expect(identite, "\(ou) : id, numero, ref")
            #expect(liens, "\(ou) : ref_sefaria, url")
            let nombre = p.versets.count
            #expect(nombre == attendu.versets.count, "\(ou) : nombre de versets")
            for (verset, a) in zip(p.versets, attendu.versets) {
                let numero = verset.numero, he = Kotlin.hashCode(verset.he)
                #expect(numero == a.n, "\(ou):\(a.n) : numéro")
                #expect(he == a.he, "\(ou):\(a.n) : texte")
                let arret = TikkunTests.memeArret(verset.arret, a.arret)
                #expect(arret, "\(ou):\(a.n) : arrêt")
                let fr = verset.fr.map { Kotlin.hashCode($0) }, en = verset.en.map { Kotlin.hashCode($0) }
                #expect(fr == a.fr, "\(ou):\(a.n) : fr")
                #expect(en == a.en, "\(ou):\(a.n) : en")
                let coupe = TikkunTests.coupe(verset).map { TikkunTests.empreintes($0) }
                #expect(coupe == a.coupe, "\(ou):\(a.n) : coupe")
            }
        }

        for n in v.byNumero {
            let id = tikkun.byNumero(n.numero)?.id
            let meme = TikkunTests.memeTexte(id, n.id)
            #expect(meme, "byNumero(\(n.numero))")
        }
        for b in v.bloc {
            let trouve = tikkun.bloc(b.cle)?.cle
            let meme = TikkunTests.memeTexte(trouve, b.trouve)
            #expect(meme, "bloc(« \(b.cle) »)")
        }
    }

    /// La coupe d'un verset : mot vide, en tête ou absent, blancs de Kotlin (insécable compris,
    /// espace sans chasse et NEL exclus), voyelles et ordre des signes comparés unité par unité.
    @Test func laCoupeEstCelleDAndroid() throws {
        let coupes = try vecteurs().coupes
        #expect(coupes.count > 20)
        for c in coupes {
            let v = Verse(numero: 1, he: c.he, arret: c.avant.map { Pause(avant: $0, note: "note") })
            let coupe = TikkunTests.coupe(v)
            let meme = TikkunTests.memeCoupe(coupe, c.coupe)
            let avant = c.avant ?? "nil"
            #expect(meme, "coupe de « \(c.he) » avant « \(avant) »")
        }
    }

    /// Ce que TikkunLoader accepte, refuse et convertit : clés requises, nombres lus en texte, null
    /// lu « null » par optString, textes blancs écartés par Json.nullable, blocs mal formés ignorés.
    @Test func lesDocumentsSontLusCommeSurAndroid() throws {
        let documents = try vecteurs().documents
        #expect(documents.count > 30)
        for doc in documents {
            let lu = try? TikkunLoader.parse(doc.json)
            let accepte = lu != nil
            #expect(accepte == doc.lu, "\(doc.nom) : lu")
            guard let lu, let t = doc.tikkun else { continue }
            let entete = lu.version.egalUnites(t.version) && TikkunTests.memeLocalise(lu.titre, t.titre)
            let edition = TikkunTests.memeEdition(lu.edition, t.edition) && TikkunTests.memeLocalise(lu.continuite, t.continuite)
            #expect(entete, "\(doc.nom) : version, titre")
            #expect(edition, "\(doc.nom) : édition, continuité")
            let versets = lu.versets
            #expect(versets == t.versets, "\(doc.nom) : versets")
            let nombre = lu.psaumes.count
            #expect(nombre == t.psaumes.count, "\(doc.nom) : psaumes")
            for (p, a) in zip(lu.psaumes, t.psaumes) {
                let identite = p.id.egalUnites(a.id) && p.numero == a.numero && p.ref.egalUnites(a.ref)
                let liens = TikkunTests.memeTexte(p.refSefaria, a.refSefaria) && TikkunTests.memeTexte(p.url, a.url)
                #expect(identite, "\(doc.nom) : psaume « \(a.id) » : id, numero, ref")
                #expect(liens, "\(doc.nom) : psaume « \(a.id) » : ref_sefaria, url")
                let nombreDeVersets = p.versets.count
                #expect(nombreDeVersets == a.versets.count, "\(doc.nom) : versets de « \(a.id) »")
                for (verset, attendu) in zip(p.versets, a.versets) {
                    let texte = verset.numero == attendu.n && verset.he.egalUnites(attendu.he)
                        && TikkunTests.memeArret(verset.arret, attendu.arret)
                    let traductions = TikkunTests.memeTexte(verset.fr, attendu.fr) && TikkunTests.memeTexte(verset.en, attendu.en)
                    let coupe = TikkunTests.memeCoupe(TikkunTests.coupe(verset), attendu.coupe)
                    #expect(texte, "\(doc.nom) : « \(a.id) » verset \(attendu.n) : n, he, arrêt")
                    #expect(traductions, "\(doc.nom) : « \(a.id) » verset \(attendu.n) : fr, en")
                    #expect(coupe, "\(doc.nom) : « \(a.id) » verset \(attendu.n) : coupe")
                }
            }
            let nombreDeBlocs = lu.blocs.count
            #expect(nombreDeBlocs == t.blocs.count, "\(doc.nom) : blocs")
            for b in t.blocs {
                let bloc = try #require(lu.bloc(b.cle), "\(doc.nom) : bloc « \(b.cle) »")
                let entete = bloc.cle.egalUnites(b.cle) && TikkunTests.memeLocalise(bloc.titre, b.titre)
                    && TikkunTests.memeLocalise(bloc.note, b.note) && TikkunTests.memeTexte(bloc.formule, b.formule)
                let paragraphes = TikkunTests.memesTextes(bloc.paragraphes, b.paragraphes)
                    && TikkunTests.memesTextes(bloc.paragraphesFr, b.paragraphesFr)
                    && TikkunTests.memesTextes(bloc.paragraphesEn, b.paragraphesEn)
                #expect(entete, "\(doc.nom) : bloc « \(b.cle) » : clé, titre, note, formule")
                #expect(paragraphes, "\(doc.nom) : bloc « \(b.cle) » : paragraphes")
            }
            let avant = lu.avant.map { $0.cle }, apres = lu.apres.map { $0.cle }
            #expect(avant == t.avant, "\(doc.nom) : avant")
            #expect(apres == t.apres, "\(doc.nom) : après")
            for n in t.byNumero {
                let id = lu.byNumero(n.numero)?.id
                let meme = TikkunTests.memeTexte(id, n.id)
                #expect(meme, "\(doc.nom) : byNumero(\(n.numero))")
            }
        }
    }
}
