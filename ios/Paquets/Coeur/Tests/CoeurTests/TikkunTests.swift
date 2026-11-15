import Foundation
import Testing
@testable import Coeur

/// TikkunTest d'Android : le Tikoun HaKlali, l'ordre des dix psaumes et l'intégrité du texte.
///
/// L'ordre n'est pas un détail d'affichage : c'est ce qui fait le Tikoun. Il est donc figé ici plutôt que laissé
/// à la bonne tenue du fichier.
@Suite("Tikkun")
struct TikkunTests {

    /// Ordre établi, recoupé le 20/09/2026 sur deux sources indépendantes (Wikipedia « Tikkun HaKlali » et
    /// breslov.org).
    private let ordre = [16, 32, 41, 42, 59, 77, 90, 105, 137, 150]

    private func lireTikkun() throws -> Tikkun { try Tikkun.lire(Depot.contenu("tikkun_haklali.json")) }

    private func psaume(_ tikkun: Tikkun, _ numero: Int) throws -> Psaume {
        try #require(tikkun.psaume(numero), "psaume \(numero) absent")
    }

    private func verset(_ psaume: Psaume, _ numero: Int) throws -> Verset {
        let trouve = psaume.versets.first { $0.numero == numero }
        return try #require(trouve, "\(psaume.ref):\(numero) absent")
    }

    /// `trimEnd().endsWith(…)` de Kotlin, pour une seule unité UTF-16.
    private func finitPar(_ texte: String, _ unite: UInt16) -> Bool {
        var unites = Array(texte.utf16)
        while let derniere = unites.last, Kotlin.estEspace(derniere) { unites.removeLast() }
        return unites.last == unite
    }

    @Test func lesDixPsaumesSontLaDansLOrdre() throws {
        let numeros = try lireTikkun().psaumes.map(\.numero)
        #expect(numeros == ordre)
        #expect(Tikkun.ordre == ordre)
    }

    @Test func chaquePsaumePorteSesVersetsNumerotesSansTrou() throws {
        for p in try lireTikkun().psaumes {
            #expect(!p.versets.isEmpty, "\(p.id) : aucun verset")
            let numeros = p.versets.map(\.numero)
            let attendus = Array(stride(from: 1, through: p.versets.count, by: 1))
            #expect(numeros == attendus, "\(p.id) : numérotation des versets")
            for v in p.versets {
                #expect(!v.he.estBlanc, "\(p.id):\(v.numero) vide")
            }
        }
    }

    @Test func leTotalDeVersetsEstCeluiDuTexteMassoretique() throws {
        // 11+11+14+12+18+21+17+45+9+6
        let total = try lireTikkun().versets
        #expect(total == 164)
    }

    @Test func lesIdentifiantsSontUniques() throws {
        let ids = try lireTikkun().psaumes.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test func lEditionEstDuDomainePublicEtVocalisee() throws {
        let edition = try lireTikkun().edition
        #expect(edition.licence == "Public Domain")
        #expect(edition.nikkoudOk, "l'édition doit autoriser le nikkoud")
    }

    /// Le Nom est écrit en toutes lettres, comme dans les sources (décision du propriétaire, 04/10/2026) : plus
    /// aucune forme substituée, ni dans les psaumes ni dans la liturgie.
    @Test func leNomEstEcritEnToutesLettres() throws {
        let tikkun = try lireTikkun()
        let substitues = [ExpressionReguliere("ה'(?![\"״])"), ExpressionReguliere("אל\u{05B9}?ק"),
                          ExpressionReguliere("אֲדֹ-נָי")]
        var fautes: [String] = []
        for p in tikkun.psaumes {
            for v in p.versets {
                let nu = v.he.formeNFC
                for motif in substitues where motif.presente(dans: nu) { fautes.append("\(p.ref):\(v.numero) substitue le Nom") }
            }
        }
        for bloc in tikkun.blocs {
            for (i, paragraphe) in bloc.paragraphes.enumerated() {
                let nu = paragraphe.formeNFC
                for motif in substitues where motif.presente(dans: nu) { fautes.append("\(bloc.cle)[\(i)] substitue le Nom") }
            }
        }
        #expect(fautes.isEmpty, "\(fautes)")
        // Le premier psaume du Tikoun s'ouvre sur le Nom (16:1 dit אֵל ; 16:2 le Tétragramme).
        let p16 = try psaume(tikkun, 16)
        try #require(p16.versets.count > 1)
        #expect(p16.versets[1].he.contientUnites("יהוָה"))
    }

    /// Les quatre parties liturgiques reprises de la page fournie : ce qui se dit avant, les versets de clôture,
    /// la kavana, la prière de Rabbi Natan.
    @Test func lesPartiesLiturgiquesSontChargees() throws {
        let tikkun = try lireTikkun()
        for cle in [Tikkun.ouverture, Tikkun.cloture, Tikkun.kavana, Tikkun.priere] {
            let bloc = try #require(tikkun.bloc(cle), "bloc « \(cle) » absent")
            #expect(!bloc.paragraphes.isEmpty, "bloc « \(cle) » vide")
            #expect(!bloc.titre.he.estBlanc, "bloc « \(cle) » sans titre")
            for paragraphe in bloc.paragraphes {
                #expect(!paragraphe.estBlanc, "bloc « \(cle) » : paragraphe vide")
            }
        }
        #expect(tikkun.avant.count == 1)
        #expect(tikkun.apres.count == 3)
    }

    /// La kavana est la seule exception à la substitution des noms divins, et c'est délibéré : elle enseigne
    /// l'épellation des deux Noms et leur milouy, dont la guematria 485 vaut תהלים. Y changer le ה en ק donnerait
    /// un autre milouy et ferait tomber le compte. Le fichier doit porter cette justification, sans quoi
    /// l'exception passerait pour un oubli.
    @Test func lExceptionDeLaKavanaEstJustifieeDansLeFichier() throws {
        let racine = try ObjetJSON(texte: Depot.texte("tikkun_haklali.json"))
        let kavana = try #require(racine.objet(Tikkun.kavana))
        let justifiee = kavana.a("note_substitution")
        #expect(justifiee, "la kavana garde l'écriture de sa source sans dire pourquoi")
    }

    /// L'indication d'arrêt de Tehilim 32:7 : ce qu'elle dit, et d'où elle vient. Le pictogramme et le mot « הפסק »
    /// de la page fournie ne doivent plus y figurer : elle se lit comme une parenthèse, pas comme une alerte.
    @Test func lIndicationDArretEstUneParentheseAvecSaSource() throws {
        let tikkun = try lireTikkun()
        let v = try verset(psaume(tikkun, 32), 7)
        let arret = try #require(v.arret, "aucune indication d'arrêt en 32:7")
        #expect(arret.note.contientUnites("ליקוטי מוהר") && arret.note.contientUnites("רי\"ג"),
                "l'indication ne dit pas d'où elle vient")
        #expect(arret.note.contientUnites("(") && arret.note.contientUnites(")"), "la source doit être entre parenthèses")
        #expect(!arret.note.contientUnites("\u{23F8}"), "le pictogramme d'arrêt subsiste")
        #expect(v.he.contientUnites(arret.avant), "le mot d'arrêt doit se trouver dans le verset")
    }

    /// L'arrêt se marque dans le verset : après « אַתָּה סֵתֶר לִי », avant « מִצַּר ».
    @Test func lArretCoupeLeVersetAvantMitsar() throws {
        let tikkun = try lireTikkun()
        let v = try verset(psaume(tikkun, 32), 7)
        let coupe = try #require(v.coupe(), "pas de coupe en 32:7")
        #expect(coupe.avant.egalUnites("אַתָּה סֵתֶר לִי"), "« \(coupe.avant) »")
        #expect(coupe.apres.commenceParUnites("מִצַּר"))
        let recousu = coupe.avant + " " + coupe.apres
        #expect(recousu.egalUnites(v.he))
        #expect(Verset(numero: 1, he: "א ב").coupe() == nil)
    }

    /// Le texte des psaumes ne vient pas de la page fournie mais d'une édition massorétique. La page porte une
    /// coquille confirmée sur trois éditions (105:20, dagesh manquant) et c'est la forme correcte qui doit être ici.
    @Test func lePsaume105Verset20PorteLeDagesh() throws {
        let tikkun = try lireTikkun()
        let v = try verset(psaume(tikkun, 105), 20)
        #expect(v.he.contientUnites("וַיַּתִּירֵהוּ"), "105:20 doit lire וַיַּתִּירֵהוּ et non וַיַתִּירֵהוּ")
    }

    /// Graphie massorétique. La page fournie s'en écartait sur cinq points ; les trois éditions consultées
    /// s'accordent contre elle sur tous, et ce sont elles qui tranchent. Repasser à la graphie de siddour ne
    /// casserait rien d'autre, d'où ce garde-fou.
    @Test func lesPsaumesSuiventLaGraphieMassoretique() throws {
        let tikkun = try lireTikkun()
        let tout = tikkun.psaumes.flatMap { p in p.versets.map(\.he) }.joined(separator: " ")
        #expect(tout.utf16.contains(0x05BE), "aucun maqqef : la graphie n'est plus massorétique")
        #expect(tout.utf16.contains(0x05C3), "aucun sof-pasuk : la graphie n'est plus massorétique")
        var siddour: [String] = []
        for p in tikkun.psaumes {
            for v in p.versets where finitPar(v.he, 0x3A) { siddour.append("\(p.ref):\(v.numero)") }
        }
        #expect(siddour.isEmpty, "un verset finit par « : » : c'est la ponctuation de siddour \(siddour)")
    }

    /// La lecture d'un trait a besoin de sa consigne : c'est elle qui dit pourquoi cet écran n'a aucun bouton entre
    /// les psaumes.
    @Test func laConsigneDeContinuiteEstChargee() throws {
        let continuite = try lireTikkun().continuite
        #expect(continuite.he.egalUnites("להמשיך מזה לזה ברצף אחד, ללא הפסק"))
        for langue in ["fr", "en"] {
            #expect(!continuite.pour(langue).estBlanc, "consigne de continuité absente en « \(langue) »")
        }
    }

    /// Ce que l'écran de lecture continue enchaîne : l'ouverture, les dix psaumes, la clôture. La kavana et la
    /// prière de Rabbi Natan restent hors du trait : elles se disent après.
    @Test func leTraitCouvreLOuvertureLesDixPsaumesEtLaCloture() throws {
        let tikkun = try lireTikkun()
        #expect(tikkun.avant.count == 1)
        #expect(tikkun.avant.first?.cle == Tikkun.ouverture)
        #expect(tikkun.bloc(Tikkun.cloture) != nil, "la clôture manque")
        #expect(tikkun.psaumes.count == 10)
        // Présentes, mais pas dans le trait.
        #expect(tikkun.bloc(Tikkun.kavana) != nil)
        #expect(tikkun.bloc(Tikkun.priere) != nil)
    }

    /// Les deux graphies lexicales où les éditions contredisent la page.
    ///
    /// Le pointage de ירושלם varie d'un verset à l'autre dans l'édition massorétique (qamats en 137:5, patah en
    /// 137:6) : la forme ne se vérifie donc pas par une chaîne littérale mais par ce qui distingue les deux
    /// graphies : le plene insère un yod avant le mem, le défectif non.
    @Test func yerushalayimEstDefectifEtHalleluyahEnDeuxMots() throws {
        let tikkun = try lireTikkun()
        let plene = ExpressionReguliere("י\u{05B0}רו\u{05BC}ש\u{05B8}\u{05C1}ל\u{05B7}י\u{05B4}ם")
        let defectif = ExpressionReguliere("י\u{05B0}רו\u{05BC}ש\u{05B8}\u{05C1}ל\u{05B4}[\u{05B7}\u{05B8}]ם")
        let p137 = try psaume(tikkun, 137)
        let defectifs = p137.versets.filter { defectif.presente(dans: $0.he) }
        #expect(defectifs.count == 3, "ירושלם doit apparaître dans trois versets du psaume 137")
        for v in p137.versets {
            #expect(!plene.presente(dans: v.he), "137:\(v.numero) porte la graphie plene ירושלים")
        }
        let v105 = try verset(psaume(tikkun, 105), 45)
        let v150 = try verset(psaume(tikkun, 150), 6)
        for v in [v105, v150] {
            #expect(v.he.contientUnites("הַלְלוּ־יָהּ"), "הללו־יה doit rester en deux mots")
        }
    }

    /// La marque d'arrêt vit dans son propre champ. Dans la page fournie elle est écrite au milieu du verset ; l'y
    /// laisser aurait mis « ⏸ הפסק » dans le texte hébreu lui-même.
    @Test func aucuneMarqueDeLectureNAFuiDansLeTexte() throws {
        for p in try lireTikkun().psaumes {
            for v in p.versets {
                #expect(!v.he.contientUnites("\u{23F8}"), "\(p.ref):\(v.numero) contient le pictogramme d'arrêt")
                #expect(!v.he.contientUnites("הפסק"), "\(p.ref):\(v.numero) contient le mot « הפסק »")
            }
        }
    }

    /// Le qere est retenu : aucune notation « ketiv [qere] » ne doit subsister.
    @Test func aucuneNotationKetivQereNeSubsiste() throws {
        for p in try lireTikkun().psaumes {
            for v in p.versets {
                #expect(!v.he.contientUnites("["), "\(p.ref):\(v.numero) porte un crochet")
            }
        }
    }

    @Test func chaquePsaumeRenvoieASaSource() throws {
        for p in try lireTikkun().psaumes {
            #expect(p.refSefaria == "Psalms \(p.numero)")
            #expect((p.url ?? "").commenceParUnites("https://"), "\(p.id) : pas de lien")
        }
    }
}
