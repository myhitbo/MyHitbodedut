import Foundation
import Testing
@testable import Coeur

/// ChizukRulesTest d'Android, porté : la règle de publication est bloquante — aucune publication ne montre un texte
/// non relevé de la source ou non relu ; l'hébreu suit le nikkoud de l'édition ; chaque moment a de quoi tirer.
@Suite("ChizukRules")
struct ChizukRulesTests {

    private func chizuk() throws -> Chizuk { try JSONDecoder().decode(Chizuk.self, from: Depot.contenu("chizuk.json")) }

    private func gabarit(statut: String, relu: Bool) -> ChizukItem {
        ChizukItem(id: "t", moments: [.ouverture], theme: nil, edition: "lm", ref: "ref", he: "he", heSansNikkoud: nil,
                   fr: "fr", en: "en", note: nil, dureeLectureSec: 5, statutVerif: statut, relu: relu)
    }

    private func seul(_ item: ChizukItem) -> Chizuk { Chizuk(version: "t", editions: [:], items: [item]) }

    @Test func laReleaseNeMontreQueDuVerifieEtRelu() throws {
        let c = try chizuk()
        for item in ChizukRules.visibles(c, debug: false) {
            #expect(item.statutVerif == ChizukRules.statutPubliable, "\(item.id) : « \(item.statutVerif) »")
            #expect(item.relu, "\(item.id) visible alors que relu est faux")
        }
    }

    @Test func laReleaseRefuseUnTexteVerifieMaisNonRelu() {
        let item = gabarit(statut: "verifie_texte", relu: false)
        #expect(!ChizukRules.publiable(item))
        #expect(ChizukRules.visibles(seul(item), debug: false).isEmpty)
    }

    @Test func laReleaseRefuseUnTexteReluMaisNonVerifie() {
        let item = gabarit(statut: "a_verifier", relu: true)
        #expect(!ChizukRules.publiable(item))
        #expect(ChizukRules.visibles(seul(item), debug: false).isEmpty)
    }

    @Test func laReleaseAccepteUnTexteVerifieEtRelu() {
        let item = gabarit(statut: "verifie_texte", relu: true)
        #expect(ChizukRules.publiable(item))
        #expect(ChizukRules.visibles(seul(item), debug: false).count == 1)
    }

    @Test func leDebugMontreToutEtSignaleCeQuiResteARelire() throws {
        let c = try chizuk()
        #expect(ChizukRules.visibles(c, debug: true).count == c.items.count)
        let aRelire = Set(c.items.filter { ChizukRules.aRelire($0) }.map { $0.id })
        let nonPubliables = Set(c.items.filter { !ChizukRules.publiable($0) }.map { $0.id })
        #expect(aRelire == nonPubliables)
    }

    @Test func lHebreuSuitLeNikkoudDeLEdition() throws {
        let c = try chizuk()
        for item in c.items {
            let affiche = ChizukRules.hebreu(c, item)
            let edition = try #require(c.editions[item.edition], "\(item.id) : édition « \(item.edition) » inconnue")
            if edition.nikkoudOk {
                #expect(affiche == item.he, "\(item.id) : devrait afficher he")
            } else {
                #expect(affiche == item.heSansNikkoud, "\(item.id) : devrait afficher he_sans_nikkoud")
            }
            #expect(!affiche.estBlanc, "\(item.id) : hébreu vide")
        }
    }

    @Test func touteEditionSansNikkoudFournitSonTexteSansNikkoud() throws {
        let c = try chizuk()
        for item in c.items where !(c.editions[item.edition]?.nikkoudOk ?? false) {
            #expect(item.heSansNikkoud != nil, "\(item.id) : édition « \(item.edition) », he_sans_nikkoud manquant")
        }
    }

    /// Reculer un seul `relu` peut vider un moment, et rien d'autre ne le signalerait.
    @Test func chaqueMomentADeQuoiTirerEnRelease() throws {
        let c = try chizuk()
        for moment in Moment.allCases {
            #expect(!ChizukRules.pourMoment(c, moment, debug: false).isEmpty, "aucun texte publiable pour « \(moment.rawValue) »")
        }
    }

    /// Le fichier doit dire lui-même d'où vient sa confiance.
    @Test func leFichierPorteLaTraceDeSaVerification() throws {
        let racine = try ObjetJSON(texte: Depot.texte("chizuk.json"))
        #expect(racine.objet("_meta")?.a("verification") == true)
    }

    @Test func chaqueMomentADeQuoiTirerEnDebug() throws {
        let c = try chizuk()
        for moment in Moment.allCases {
            #expect(!ChizukRules.pourMoment(c, moment, debug: true).isEmpty, "aucun texte pour « \(moment.rawValue) »")
        }
    }

    /// L'écran de porte s'ouvre sur un téléphone qu'on vient d'attraper : 15 s de lecture au plus.
    @Test func lesTextesDeLaPorteRestentCourts() throws {
        let c = try chizuk()
        for item in ChizukRules.pourMoment(c, .porte, debug: true) {
            #expect(item.dureeLectureSec <= 15, "\(item.id) : \(item.dureeLectureSec) s")
        }
    }

    /// « J'ai besoin de 'hizouk » (19/10) : tout le publiable, et un partage qui garde la source.
    @Test func aLaDemandeToutLePubliableEtLePartageGardeLaSource() throws {
        let c = try chizuk()
        let visibles = ChizukRules.visibles(c, debug: false).map { $0.id }
        let demande = ChizukRules.pourMoment(c, .demande, debug: false).map { $0.id }
        #expect(visibles == demande)
        let partage = ChizukPartage.texte("עִקַּר", "", "Likoutei Moharan II, 25", "https://x")
        #expect(partage == "עִקַּר\n\n— Likoutei Moharan II, 25\n\nhttps://x")
        #expect(ChizukPartage.texte("א", "trad", "s", "l").contains("\n\ntrad\n\n"))
    }
}
