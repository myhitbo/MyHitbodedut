import Foundation
import Testing
@testable import Coeur

/// TraductionAffichageTest d'Android, porté : le texte qui atteint l'écran sans passer par les
/// chaînes — les références des données, en anglais et en hébreu — et ce que les chaînes et les
/// données livrées ne doivent plus dire ; puis tout le chapitre « reference » de
/// `Tests/Vecteurs/langues.json` (tools/vecteurs_ios/VecteursLangues.kt).
///
/// Restent à Android, parce qu'ils lisent son code : `chaque ecran qui montre une reference la
/// traduit` (ChizukCard.kt, LibraryEntryActivity.kt…), `les durees prennent leurs unites dans les
/// chaines` (Store.kt), `les services et receveurs parlent la langue de l application` et, dans
/// `on ne dit plus seance ni session`, l'image de NoteDialog.kt. Ce qui lisait strings.xml se vérifie
/// sur le catalogue exporté (Localizable.xcstrings, Tableaux.json), ce qui lisait res/raw sur
/// ios/Ressources/Contenu, octet pour octet les mêmes fichiers. `\b` et `(?i)` de la JVM ne voient que
/// l'ASCII : la frontière de mot s'écrit ici en toutes lettres ; la casse d'ICU, plus large, ne peut
/// que trouver plus de fautes.
@Suite("TraductionAffichage")
struct TraductionAffichageTests {

    private func lire(_ nom: String) throws -> String {
        try String(decoding: Depot.contenu(nom), as: UTF8.self)
    }

    private static let motifRef = ExpressionReguliere("\"ref\": \"([^\"]+)\"")

    /// Les références des données, lues dans le texte brut comme Android les lit.
    private func refs() throws -> [String] {
        var resultat: [String] = []
        for fichier in ["chizuk.json", "bibliotheque.json"] {
            let texte = try lire(fichier)
            for correspondance in TraductionAffichageTests.motifRef.toutes(texte) {
                resultat.append(correspondance.groupes[1])
            }
        }
        return resultat
    }

    @Test func chaqueReferenceDesDonneesASaFormeAnglaiseEtHebraique() throws {
        let toutes = try refs()
        let nombre = toutes.count
        #expect(nombre > 60, "aucune référence lue : la lecture est cassée")
        var inconnues: [String] = []
        for ref in toutes where !Reference.connue(ref) && !inconnues.contains(ref) {
            inconnues.append(ref)
        }
        let aucune = inconnues.isEmpty
        #expect(aucune, "livres absents de Reference.livres : \(inconnues)")
    }

    @Test func enHebreuUneReferenceNeGardeAucuneLettreLatineNiAucunChiffre() throws {
        let latin = ExpressionReguliere("[A-Za-z0-9]")
        let toutes = try refs()
        for ref in toutes {
            let he = Reference.localise(ref, "iw")
            let reste = latin.presente(dans: he)
            #expect(!reste, "« \(ref) » → « \(he) »")
        }
        let tinyana = Reference.localise("Likoutei Moharan II, 25", "he")
        #expect(tinyana == "ליקוטי מוהר״ן תניינא, כ״ה")
        let michle = Reference.localise("Michlé 24:16", "he")
        #expect(michle == "משלי כ״ד, ט״ז")
        // En anglais, les chiffres restent.
        let anglais = Reference.localise("Michlé 24:16", "en")
        #expect(anglais == "Mishlei 24:16")
    }

    @Test func lesNombresEnLettresHebraiques() {
        let cas: [(Int, String)] = [
            (1, "א׳"), (7, "ז׳"), (10, "י׳"), (15, "ט״ו"), (16, "ט״ז"), (25, "כ״ה"),
            (39, "ל״ט"), (100, "ק׳"), (145, "קמ״ה"), (261, "רס״א"), (437, "תל״ז"), (400, "ת׳"),
        ]
        for (n, attendu) in cas {
            let lettres = Reference.lettres(n)
            #expect(lettres == attendu, "\(n)")
        }
    }

    @Test func lesNombresDeMauvaisAugureSontInverses() {
        let cas: [(Int, String)] = [
            (270, "ע״ר"), (272, "ער״ב"), (274, "ער״ד"), (275, "ער״ה"),
            (298, "רח״צ"), (304, "ד״ש"), (344, "שד״מ"),
        ]
        for (n, attendu) in cas {
            let lettres = Reference.lettres(n)
            #expect(lettres == attendu, "\(n)")
        }
        // Les voisins restent dans l'ordre habituel.
        let rentUn = Reference.lettres(271)
        #expect(rentUn == "רע״א")
        let quarante = Reference.lettres(345)
        #expect(quarante == "שמ״ה")
        let sihot = Reference.localise("Si'hot HaRan 275", "he")
        #expect(sihot == "שיחות הר״ן ער״ה")
    }

    @Test func enAnglaisUneReferenceNeGardeAucuneGraphieFrancaise() throws {
        let francais = ExpressionReguliere(
            "Likoutei|Si'hot|'Hayé|Chiv'hei|Michlé|Hit'hazkout|(?<![A-Za-z0-9_])Tefila(?![A-Za-z0-9_])| ; ")
        let toutes = try refs()
        for ref in toutes {
            let en = Reference.localise(ref, "en")
            let reste = francais.presente(dans: en)
            #expect(!reste, "« \(ref) » → « \(en) »")
        }
        let anglais = Reference.localise("Likoutei Moharan II, 78", "en")
        #expect(anglais == "Likutei Moharan II, 78")
        let francaise = Reference.localise("Likoutei Moharan II, 78", "fr")
        #expect(francaise == "Likoutei Moharan II, 78")
    }

    @Test func aucunTitreDeMorceauNeResteEnFrancais() throws {
        let catalogue = try Catalogue.lire()
        // strings.xml porte aussi les <string-array>, exportés dans Tableaux.json.
        let tableaux = try JSONDecoder().decode([String: [String: [String]]].self,
                                                from: Depot.donnees("ios/Ressources/Chaines/Tableaux.json"))
        for langue in Catalogue.langues {
            var textes = Array(catalogue.simples(langue).values)
            textes.append(contentsOf: catalogue.pluriels(langue).values)
            for (_, elements) in tableaux[langue] ?? [:] {
                textes.append(contentsOf: elements)
            }
            var restes = 0
            for texte in textes where texte.contientUnites("titre à préciser") {
                restes += 1
            }
            let nombre = restes
            #expect(nombre == 0, "\(langue) : « titre à préciser »")
        }
        let niggoun = catalogue.simples("en")["track_niggoun_01"]
        #expect(niggoun == "Niggun 01")
    }

    @Test func lesDonneesDeLaBibliothequeNePortentPasDePhraseFrancaiseHorsDesChampsFr() throws {
        let biblio = try lire("bibliotheque.json")
        let phrase = biblio.contientUnites("cité dans l'article")
        #expect(!phrase)
        // Publiés sans nommer les auteurs, avec leur accord (28/09).
        let auteur = ExpressionReguliere("\"auteur\": \"[^\"]").presente(dans: biblio)
        #expect(!auteur, "un auteur est nommé")
        for nom in ["סלמה", "Moharach", "מוהרא"] {
            let reste = biblio.contientUnites(nom)
            #expect(!reste, "nom « \(nom) » resté")
        }
        let date = ExpressionReguliere("\"date\": \"[0-9]{2}/[0-9]{2}/[0-9]{4}\"").presente(dans: biblio)
        #expect(!date, "date ambiguë jour/mois")
    }

    /// « Séance » et « session » deviennent « hitbodedout » et « hitbodedut » dans tout ce qui
    /// s'affiche (demande du 29/09) : les chaînes, les pluriels et les tableaux du français et de l'anglais.
    @Test func onNeDitPlusSeanceNiSession() throws {
        let catalogue = try Catalogue.lire()
        let tableaux = try JSONDecoder().decode([String: [String: [String]]].self,
                                                from: Depot.donnees("ios/Ressources/Chaines/Tableaux.json"))
        let mots: [(String, ExpressionReguliere)] = [
            ("fr", ExpressionReguliere("(?<![A-Za-z0-9_])séances?(?![A-Za-z0-9_])", .sansCasse)),
            ("en", ExpressionReguliere("(?<![A-Za-z0-9_])sessions?(?![A-Za-z0-9_])", .sansCasse)),
        ]
        for (langue, mot) in mots {
            var textes = Array(catalogue.simples(langue).values)
            textes.append(contentsOf: catalogue.pluriels(langue).values)
            for (_, elements) in tableaux[langue] ?? [:] {
                textes.append(contentsOf: elements)
            }
            let nombre = textes.count
            #expect(nombre > 200, "\(langue) : aucune chaîne lue")
            var trouves: [String] = []
            for texte in textes where mot.presente(dans: texte) {
                trouves.append(texte)
            }
            let aucun = trouves.isEmpty
            #expect(aucun, "\(langue) : \(trouves.sorted())")
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        let reference: Chapitre
    }

    /// `lettres[i]` : `Reference.lettres(nombres[i])` ; `localisees[j]` : `localise(ref, languesRef[j])`.
    private struct Chapitre: Decodable {
        let nombres: [Int]
        let lettres: [String]
        let languesRef: [String]
        let nombreDeRefsDesDonnees: Int
        let donnees: [Cas]
        let manuelles: [Cas]
    }

    private struct Cas: Decodable {
        let ref: String
        let connue: Bool
        let localisees: [String]
    }

    @Test func lesVecteursDeLaJVM() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/langues.json"))
        let c = v.reference
        let nombreLettres = c.lettres.count
        #expect(nombreLettres == c.nombres.count, "lettres : vecteur incomplet")
        #expect(nombreLettres > 1100, "lettres : de -1 à 1100 au moins")
        for (n, attendu) in zip(c.nombres, c.lettres) {
            let lettres = Reference.lettres(n)
            let ok = lettres.egalUnites(attendu)
            #expect(ok, "lettres(\(n)) = « \(lettres) », attendu « \(attendu) »")
        }

        // Les vecteurs couvrent chaque référence des données, dans l'ordre où elles paraissent.
        let toutes = try refs()
        let nombre = toutes.count
        #expect(nombre == c.nombreDeRefsDesDonnees, "les données ont changé depuis les vecteurs")
        var distinctes: [String] = []
        for ref in toutes where !distinctes.contains(where: { $0.egalUnites(ref) }) {
            distinctes.append(ref)
        }
        var couvertes: [String] = []
        for cas in c.donnees {
            couvertes.append(cas.ref)
        }
        #expect(distinctes == couvertes, "références des données et des vecteurs")

        for cas in c.donnees + c.manuelles {
            let connue = Reference.connue(cas.ref)
            #expect(connue == cas.connue, "connue(« \(cas.ref) »)")
            let nombreLangues = cas.localisees.count
            #expect(nombreLangues == c.languesRef.count, "« \(cas.ref) » : vecteur incomplet")
            for (langue, attendu) in zip(c.languesRef, cas.localisees) {
                let rendu = Reference.localise(cas.ref, langue)
                let ok = rendu.egalUnites(attendu)
                #expect(ok, "localise(« \(cas.ref) », « \(langue) ») = « \(rendu) », attendu « \(attendu) »")
            }
        }
    }
}
