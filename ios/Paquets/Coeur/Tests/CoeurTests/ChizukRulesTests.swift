import Foundation
import Testing
@testable import Coeur

/// ChizukRulesTest d'Android, porté sur le chizuk.json exporté (ios/Ressources/Contenu, le même que
/// res/raw) : la règle de publication, l'hébreu selon l'édition, chaque moment pourvu. Puis tout
/// `Tests/Vecteurs/chizuk.json`, écrit par la JVM (tools/vecteurs_ios/VecteursChizuk.kt) : pour chaque
/// moment et chaque valeur de debug, les identifiants publiés ; texte par texte, la règle et
/// l'hébreu affiché ; et les recueils écrits à la main. Rien ne reste à Android : le partage du dernier
/// test (ChizukPartage, de ChizukActivity.kt, porté dans ChizukCard.swift) n'a pas de vecteurs, l'oracle
/// ne compilant pas ChizukActivity.kt.
@Suite("'Hizouk : règle de publication")
struct ChizukRulesTests {

    private func livre() throws -> Chizuk {
        try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json"))
    }

    /// Le `gabarit(statut, relu)` du test Kotlin, écrit en JSON : ChizukItem ne se construit que par
    /// son décodage.
    private func gabaritJSON(statut: String, relu: Bool) -> String {
        """
        {"id":"t","moments":["ouverture"],"edition":"lm","ref":"ref","he":"he","fr":"fr","en":"en",\
        "duree_lecture_sec":5,"statut_verif":"\(statut)","relu":\(relu)}
        """
    }

    private func gabarit(statut: String, relu: Bool) throws -> ChizukItem {
        try JSONDecoder().decode(ChizukItem.self, from: Data(gabaritJSON(statut: statut, relu: relu).utf8))
    }

    /// `Chizuk("t", emptyMap(), listOf(item))`.
    private func recueilDuGabarit(statut: String, relu: Bool) throws -> Chizuk {
        let json = #"{"_meta":{"version":"t"},"items":["# + gabaritJSON(statut: statut, relu: relu) + "]}"
        return try JSONDecoder().decode(Chizuk.self, from: Data(json.utf8))
    }

    @Test func laReleaseNeMontreQueDuVerifieEtRelu() throws {
        let c = try livre()
        for item in ChizukRules.visible(c, debug: false) {
            let verifie = item.statutVerif.egalUnites(ChizukRules.statutPubliable)
            #expect(verifie, "\(item.id) visible en release alors que statut_verif vaut « \(item.statutVerif) »")
            let relu = item.relu
            #expect(relu, "\(item.id) visible en release alors que relu est faux")
        }
    }

    @Test func laReleaseRefuseUnTexteVerifieMaisNonRelu() throws {
        let item = try gabarit(statut: "verifie_texte", relu: false)
        let publiable = ChizukRules.isPublishable(item)
        #expect(!publiable)
        let recueil = try recueilDuGabarit(statut: "verifie_texte", relu: false)
        let visibles = ChizukRules.visible(recueil, debug: false)
        let vide = visibles.isEmpty
        #expect(vide)
    }

    @Test func laReleaseRefuseUnTexteReluMaisNonVerifie() throws {
        let item = try gabarit(statut: "a_verifier", relu: true)
        let publiable = ChizukRules.isPublishable(item)
        #expect(!publiable)
        let recueil = try recueilDuGabarit(statut: "a_verifier", relu: true)
        let visibles = ChizukRules.visible(recueil, debug: false)
        let vide = visibles.isEmpty
        #expect(vide)
    }

    @Test func laReleaseAccepteUnTexteVerifieEtRelu() throws {
        let item = try gabarit(statut: "verifie_texte", relu: true)
        let publiable = ChizukRules.isPublishable(item)
        #expect(publiable)
        let recueil = try recueilDuGabarit(statut: "verifie_texte", relu: true)
        let visibles = ChizukRules.visible(recueil, debug: false)
        let nombre = visibles.count
        #expect(nombre == 1)
    }

    @Test func leDebugMontreToutEtSignaleCeQuiResteARelire() throws {
        let c = try livre()
        let visibles = ChizukRules.visible(c, debug: true).count
        let tous = c.items.count
        #expect(visibles == tous)
        let aRelire = Set(c.items.filter { ChizukRules.needsProofreading($0) }.map(\.id))
        let nonPubliables = Set(c.items.filter { !ChizukRules.isPublishable($0) }.map(\.id))
        #expect(aRelire == nonPubliables)
    }

    /// L'hébreu affiché est `he`, sans vocalisation si l'édition l'interdit : le fichier la livre déjà nue
    /// (ChizukRulesTest et LicencesEditionsTest d'Android, audit du 12/11 ; `he_sans_nikkoud` a disparu).
    @Test func lHebreuAfficheEstHeSansVocalisationSiLEditionLInterdit() throws {
        let c = try livre()
        for item in c.items {
            let affiche = ChizukRules.hebrew(c, item)
            let edition = try #require(c.editions[item.edition], "\(item.id) : édition « \(item.edition) » non déclarée")
            #expect(affiche.egalUnites(item.he), "\(item.id) : devrait afficher he")
            #expect(!affiche.estBlanc, "\(item.id) : hébreu vide")
            if !edition.nikkoudOk {
                let vocalise = affiche.utf16.contains { u in (0x0591...0x05BD).contains(u) || (0x05BF...0x05C2).contains(u) || (0x05C4...0x05C7).contains(u) }
                #expect(!vocalise, "\(item.id) : édition « \(item.edition) » non vocalisable, mais he est vocalisé")
            }
        }
    }

    /// Depuis que les textes sont relus, la release en affiche : aucun moment ne doit se retrouver
    /// muet sur un téléphone. Reculer un seul `relu` peut vider un moment, et rien d'autre ne le
    /// signalerait : la carte se masquerait, sans erreur.
    @Test func chaqueMomentADeQuoiTirerEnRelease() throws {
        let c = try livre()
        for moment in Moment.allCases {
            let vivier = ChizukRules.forMoment(c, moment, debug: false)
            let pourvu = !vivier.isEmpty
            #expect(pourvu, "aucun texte publiable pour le moment « \(moment.rawValue) » : la carte resterait masquée sur l'appareil")
        }
    }

    /// Le fichier doit dire lui-même d'où vient sa confiance.
    @Test func leFichierPorteLaTraceDeSaVerification() throws {
        let donnees = try Depot.contenu("chizuk.json")
        let racine = try ObjetJSON(texte: String(decoding: donnees, as: UTF8.self))
        let meta = try #require(racine.objet("_meta"))
        let trace = meta.a("verification")
        #expect(trace, "relu=true sans bloc _meta.verification : le fichier ne dit plus sur quoi repose sa publication")
    }

    @Test func chaqueMomentADeQuoiTirerEnDebug() throws {
        let c = try livre()
        for moment in Moment.allCases {
            let vivier = ChizukRules.forMoment(c, moment, debug: true)
            let pourvu = !vivier.isEmpty
            #expect(pourvu, "aucun texte pour le moment « \(moment.rawValue) »")
        }
    }

    /// L'écran de porte s'ouvre sur un téléphone qu'on vient d'attraper : _meta limite ce moment aux
    /// textes de 15 s de lecture ou moins.
    @Test func lesTextesDeLaPorteRestentCourts() throws {
        let c = try livre()
        for item in ChizukRules.forMoment(c, .porte, debug: true) {
            let duree = item.dureeLectureSec
            #expect(duree <= 15, "\(item.id) : \(duree) s, trop long pour l'écran de porte")
        }
    }

    /// « J'ai besoin de 'hizouk » (19/10) : tout le publiable, et un partage qui garde la source.
    @Test func aLaDemandeToutLePubliableEtLePartageGardeLaSource() throws {
        let c = try livre()
        let visibles = ChizukRules.visible(c, debug: false).map(\.id)
        let demande = ChizukRules.forMoment(c, .demande, debug: false).map(\.id)
        let egaux = Self.memes(visibles, demande)
        #expect(egaux, "\(visibles) ≠ \(demande)")
        let partage = ChizukPartage.texte("עִקַּר", "", "Likoutei Moharan II, 25", "https://x")
        let partageEgal = partage.egalUnites("עִקַּר\n\n— Likoutei Moharan II, 25\n\nhttps://x")
        #expect(partageEgal, "« \(partage) »")
        let avecTraduction = ChizukPartage.texte("א", "trad", "s", "l")
        let traductionEntreDeuxLignes = avecTraduction.contientUnites("\n\ntrad\n\n")
        #expect(traductionEntreDeuxLignes, "« \(avecTraduction) »")
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let statutPubliable: String
        }
        struct Livre: Decodable {
            let version: String
            let items: Int
        }
        /// `visible(chizuk, debug)`.
        struct Visibles: Decodable {
            let debug: Bool
            let ids: [String]
        }
        /// `forMoment(chizuk, moment, debug)`.
        struct ParMoment: Decodable {
            let moment: String
            let debug: Bool
            let ids: [String]
        }
        /// Un texte du fichier livré : l'hébreu affiché en empreinte (String.hashCode) et en longueur.
        struct TexteLivre: Decodable {
            let id: String
            let publiable: Bool
            let aRelire: Bool
            let hebreu: Int32
            let longueurHebreu: Int
        }
        /// Un texte d'un recueil écrit à la main : l'hébreu affiché en clair.
        struct Texte: Decodable {
            let id: String
            let publiable: Bool
            let aRelire: Bool
            let hebreu: String
        }
        struct Recueil: Decodable {
            let nom: String
            let json: String
            let visible: [Visibles]
            let moments: [ParMoment]
            let textes: [Texte]
        }
        let constantes: Constantes
        let livre: Livre
        let visibles: [Visibles]
        let moments: [ParMoment]
        let textes: [TexteLivre]
        let recueils: [Recueil]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/chizuk.json"))
    }

    /// Deux listes d'identifiants égales unité UTF-16 par unité, comme `==` de Kotlin.
    private static func memes(_ a: [String], _ b: [String]) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0.egalUnites($1) }
    }

    /// Les identifiants publiés, en debug et en release, puis moment par moment.
    private func verifie(_ c: Chizuk, visibles: [Vecteurs.Visibles], moments: [Vecteurs.ParMoment], contexte: String) throws {
        for v in visibles {
            let ids = ChizukRules.visible(c, debug: v.debug).map(\.id)
            let egaux = Self.memes(ids, v.ids)
            #expect(egaux, "\(contexte), visible(debug: \(v.debug)) : \(ids) ≠ \(v.ids)")
        }
        let couverts = moments.count
        let attendus = 2 * Moment.allCases.count
        #expect(couverts == attendus, "\(contexte) : chaque moment, en debug et en release")
        for m in moments {
            let moment = try #require(Moment(rawValue: m.moment), "\(contexte) : moment inconnu « \(m.moment) »")
            let ids = ChizukRules.forMoment(c, moment, debug: m.debug).map(\.id)
            let egaux = Self.memes(ids, m.ids)
            #expect(egaux, "\(contexte), forMoment(\(m.moment), debug: \(m.debug)) : \(ids) ≠ \(m.ids)")
        }
    }

    @Test func lesVecteursDuFichierLivre() throws {
        let v = try vecteurs()
        let constante = ChizukRules.statutPubliable
        #expect(constante == v.constantes.statutPubliable)

        let c = try livre()
        let version = c.version
        #expect(version == v.livre.version)
        let nombre = c.items.count
        #expect(nombre == v.livre.items)
        try verifie(c, visibles: v.visibles, moments: v.moments, contexte: "livre")

        let textes = v.textes.count
        #expect(textes == nombre)
        for (item, t) in zip(c.items, v.textes) {
            let id = item.id
            #expect(id == t.id)
            let publiable = ChizukRules.isPublishable(item)
            #expect(publiable == t.publiable, "\(t.id) : isPublishable")
            let aRelire = ChizukRules.needsProofreading(item)
            #expect(aRelire == t.aRelire, "\(t.id) : needsProofreading")
            let hebreu = ChizukRules.hebrew(c, item)
            let empreinte = Kotlin.hashCode(hebreu)
            #expect(empreinte == t.hebreu, "\(t.id) : hebrew, empreinte")
            let longueur = hebreu.utf16.count
            #expect(longueur == t.longueurHebreu, "\(t.id) : hebrew, longueur")
        }
    }

    @Test func lesVecteursDesRecueils() throws {
        let v = try vecteurs()
        let nombre = v.recueils.count
        #expect(nombre == 6)
        for r in v.recueils {
            let c = try JSONDecoder().decode(Chizuk.self, from: Data(r.json.utf8))
            try verifie(c, visibles: r.visible, moments: r.moments, contexte: r.nom)
            let textes = c.items.count
            #expect(textes == r.textes.count, "\(r.nom) : nombre de textes")
            for (item, t) in zip(c.items, r.textes) {
                let id = item.id
                #expect(id == t.id, "\(r.nom)")
                let publiable = ChizukRules.isPublishable(item)
                #expect(publiable == t.publiable, "\(r.nom), \(t.id) : isPublishable")
                let aRelire = ChizukRules.needsProofreading(item)
                #expect(aRelire == t.aRelire, "\(r.nom), \(t.id) : needsProofreading")
                let hebreu = ChizukRules.hebrew(c, item)
                let egal = hebreu.egalUnites(t.hebreu)
                #expect(egal, "\(r.nom), \(t.id) : hebrew « \(hebreu) » ≠ « \(t.hebreu) »")
            }
        }
    }
}
