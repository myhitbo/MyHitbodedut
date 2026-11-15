import Foundation
import Testing
@testable import Coeur

/// TraductionAffichageTest d'Android, porté : le texte qui atteint l'écran sans passer par les chaînes — les
/// références des données dans les trois langues, les nombres en lettres hébraïques, les titres des morceaux, les
/// données de la bibliothèque, « hitbodedout » au lieu de « séance ». Les tests qui lisent le code d'Android
/// (écrans qui appellent `Reference.localise`, `Store.formatDuration`, services enveloppés, `NoteDialog`) y restent.
@Suite("TraductionAffichage")
struct TraductionAffichageTests {

    private func refs() throws -> [String] {
        let motif = ExpressionReguliere("\"ref\": \"([^\"]+)\"")
        var resultat: [String] = []
        for f in ["chizuk.json", "bibliotheque.json"] {
            let texte = try Depot.texte(f)
            resultat += motif.toutes(texte).map { $0.groupes[1] }
        }
        return resultat
    }

    @Test func chaqueReferenceDesDonneesASaFormeAnglaiseEtHebraique() throws {
        let r = try refs()
        #expect(r.count > 60, "aucune référence lue : la lecture est cassée")
        var vues = Set<String>()
        let inconnues = r.filter { !Reference.connue($0) && vues.insert($0).inserted }
        #expect(inconnues.isEmpty, "livres absents de Reference.livres : \(inconnues)")
    }

    @Test func enHebreuUneReferenceNeGardeAucuneLettreLatineNiAucunChiffre() throws {
        let latin = ExpressionReguliere("[A-Za-z0-9]")
        for ref in try refs() {
            let he = Reference.localise(ref, "iw")
            #expect(!latin.presente(dans: he), "« \(ref) » → « \(he) »")
        }
        #expect(Reference.localise("Likoutei Moharan II, 25", "he") == "ליקוטי מוהר״ן תניינא, כ״ה")
        #expect(Reference.localise("Michlé 24:16", "he") == "משלי כ״ד, ט״ז")
        // En anglais, les chiffres restent.
        #expect(Reference.localise("Michlé 24:16", "en") == "Mishlei 24:16")
    }

    @Test func lesNombresEnLettresHebraiques() {
        let cas: [(Int, String)] = [
            (1, "א׳"), (7, "ז׳"), (10, "י׳"), (15, "ט״ו"), (16, "ט״ז"), (25, "כ״ה"),
            (39, "ל״ט"), (100, "ק׳"), (145, "קמ״ה"), (261, "רס״א"), (437, "תל״ז"), (400, "ת׳"),
        ]
        for (n, attendu) in cas { #expect(Reference.lettres(n) == attendu, "\(n)") }
    }

    @Test func lesNombresDeMauvaisAugureSontInverses() {
        let cas: [(Int, String)] = [
            (270, "ע״ר"), (272, "ער״ב"), (274, "ער״ד"), (275, "ער״ה"), (298, "רח״צ"), (304, "ד״ש"), (344, "שד״מ"),
        ]
        for (n, attendu) in cas { #expect(Reference.lettres(n) == attendu, "\(n)") }
        // Les voisins restent dans l'ordre habituel.
        #expect(Reference.lettres(271) == "רע״א")
        #expect(Reference.lettres(345) == "שמ״ה")
        #expect(Reference.localise("Si'hot HaRan 275", "he") == "שיחות הר״ן ער״ה")
    }

    @Test func enAnglaisUneReferenceNeGardeAucuneGraphieFrancaise() throws {
        let francais = ExpressionReguliere("Likoutei|Si'hot|'Hayé|Chiv'hei|Michlé|Hit'hazkout|(?<![A-Za-z])Tefila(?![A-Za-z])| ; ")
        for ref in try refs() {
            let en = Reference.localise(ref, "en")
            #expect(!francais.presente(dans: en), "« \(ref) » → « \(en) »")
        }
        #expect(Reference.localise("Likoutei Moharan II, 78", "en") == "Likutei Moharan II, 78")
        #expect(Reference.localise("Likoutei Moharan II, 78", "fr") == "Likoutei Moharan II, 78")
    }

    @Test func aucunTitreDeMorceauNeResteEnFrancais() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let valeurs = Array(catalogue.simples(langue).values) + Array(catalogue.pluriels(langue).values)
            let restes = valeurs.filter { $0.contientUnites("titre à préciser") }
            #expect(restes.isEmpty, "\(langue) : « titre à préciser »")
        }
        #expect(catalogue.simples("en")["track_niggoun_01"] == "Niggun 01")
    }

    @Test func lesDonneesDeLaBibliothequeNePortentPasDePhraseFrancaiseHorsDesChampsFr() throws {
        let biblio = try Depot.texte("bibliotheque.json")
        #expect(!biblio.contientUnites("cité dans l'article"))
        // Publiés sans nommer les auteurs, avec leur accord (28/09).
        #expect(!ExpressionReguliere("\"auteur\": \"[^\"]").presente(dans: biblio), "un auteur est nommé")
        for nom in ["סלמה", "Moharach", "מוהרא"] { #expect(!biblio.contientUnites(nom), "nom « \(nom) » resté") }
        #expect(!ExpressionReguliere("\"date\": \"[0-9]{2}/[0-9]{2}/[0-9]{4}\"").presente(dans: biblio), "date ambiguë jour/mois")
    }

    /// « Séance » et « session » deviennent « hitbodedout » et « hitbodedut » dans tout ce qui s'affiche (29/09).
    @Test func onNeDitPlusSeanceNiSession() throws {
        let catalogue = try Catalogue.lire()
        for (langue, mot) in [("fr", "(?i)(?<![\\p{L}])séances?(?![\\p{L}])"), ("en", "(?i)(?<![\\p{L}])sessions?(?![\\p{L}])")] {
            let motif = ExpressionReguliere(mot)
            let valeurs = Array(catalogue.simples(langue).values) + Array(catalogue.pluriels(langue).values)
            let textes = valeurs.filter { motif.presente(dans: $0) }
            #expect(textes.isEmpty, "\(langue) : \(textes)")
        }
    }
}
