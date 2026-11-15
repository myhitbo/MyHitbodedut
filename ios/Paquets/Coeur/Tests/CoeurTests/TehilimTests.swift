import Foundation
import Testing
@testable import Coeur

/// TehilimTest d'Android : le livre de Tehilim entier (demande du 04/10), le texte, ses conventions, et les deux
/// cycles qui le disent en un mois ou en une semaine. De « l'onglet textes mène au livre », qui lit MainActivity, le
/// manifeste et les strings.xml, l'écran reste à Android ; les chaînes se vérifient ici dans le catalogue exporté.
@Suite("Tehilim")
struct TehilimTests {

    private func lireLivre() throws -> Tehilim { try Tehilim.lire(Depot.contenu("tehilim.json")) }
    private func lireTikkun() throws -> Tikkun { try Tikkun.lire(Depot.contenu("tikkun_haklali.json")) }

    /// `trimEnd().endsWith(…)` de Kotlin, pour une seule unité UTF-16.
    private func finitPar(_ texte: String, _ unite: UInt16) -> Bool {
        var unites = Array(texte.utf16)
        while let derniere = unites.last, Kotlin.estEspace(derniere) { unites.removeLast() }
        return unites.last == unite
    }

    /// Un point-voyelle (U+05B0 à U+05BC), ou le point du shin ou du sin.
    private func estVoyelle(_ x: Unicode.Scalar) -> Bool {
        (0x05B0...0x05BC).contains(x.value) || x.value == 0x05C1 || x.value == 0x05C2
    }

    @Test func leLivreASes150PsaumesEtSes2527Versets() throws {
        let livre = try lireLivre()
        #expect(livre.psaumes.count == 150)
        #expect(Tehilim.nombreDePsaumes == 150)
        #expect(livre.versetsTotal == 2527)
        #expect(livre.versets(119).count == 176)
        #expect(livre.versets(117).count == 2)
        #expect(livre.versets(150).count == 6)
    }

    @Test func chaqueVersetEstLuEtNonEcrit() throws {
        let livre = try lireLivre()
        var fautes: [String] = []
        for (i, versets) in livre.psaumes.enumerated() {
            for (j, v) in versets.enumerated() {
                let ou = "Tehilim \(i + 1):\(j + 1)"
                if !finitPar(v, 0x05C3) { fautes.append("\(ou) ne finit pas par un sof pasouq") }
                if v.utf16.contains(0x5B) || v.utf16.contains(0x5D) { fautes.append("\(ou) garde un crochet de qere") }
                if v.utf16.contains(0x200D) { fautes.append("\(ou) garde un caractère invisible") }
                // Un mot sans aucune voyelle serait un ketiv resté en place.
                let mots = v.unicodeScalars.split(omittingEmptySubsequences: false) { $0 == " " || $0 == "\u{05BE}" }
                for morceau in mots {
                    let mot = String(String.UnicodeScalarView(morceau))
                    if mot.lettres.utf16.count < 2 || mot.egalUnites("ה'") { continue }
                    let vocalise = mot.unicodeScalars.contains { estVoyelle($0) }
                    if !vocalise { fautes.append("\(ou) : « \(mot) » sans voyelles") }
                }
            }
        }
        #expect(fautes.isEmpty, "\(fautes.prefix(20))")
    }

    @Test func leNomEstEcritEnToutesLettresDansLeLivre() throws {
        let livre = try lireLivre()
        let premier = try #require(livre.versets(23).first)
        #expect(premier.contientUnites("יְהוָה".formeNFC))
        let psaume42 = livre.versets(42)
        try #require(psaume42.count > 6)
        #expect(psaume42[6].commenceParUnites("אֱלֹהַי".formeNFC))
        var fautes: [String] = []
        for (i, versets) in livre.psaumes.enumerated() {
            for (j, v) in versets.enumerated() where v.contientUnites("ה'") {
                fautes.append("Tehilim \(i + 1):\(j + 1) substitue le Nom")
            }
        }
        #expect(fautes.isEmpty, "\(fautes)")
    }

    /// Les dix psaumes du Tikoun et le livre entier disent exactement le même texte, Nom compris.
    @Test func leTikounEtLeLivreConcordentVersetParVerset() throws {
        let livre = try lireLivre()
        let tikkun = try lireTikkun()
        var compares = 0
        var fautes: [String] = []
        for p in tikkun.psaumes {
            let versets = livre.versets(p.numero)
            for v in p.versets {
                let ici = v.numero >= 1 && v.numero <= versets.count ? versets[v.numero - 1] : ""
                if !ici.formeNFC.egalUnites(v.he.formeNFC) { fautes.append("Tehilim \(p.numero):\(v.numero)") }
                compares += 1
            }
        }
        #expect(fautes.isEmpty, "\(fautes)")
        #expect(compares == 164)
    }

    /// Les corrections du 04/10 dans le Tikoun : les mots que la résolution du qere avait perdus.
    @Test func leQereNeFaitPlusPerdreDeMot() throws {
        let livre = try lireLivre()
        let p77 = livre.versets(77), p105 = livre.versets(105), p21 = livre.versets(21)
        try #require(p77.count > 0 && p105.count > 27 && p21.count > 1)
        #expect(p77[0].lettres.commenceParUnites("למנצחעלידותון"))
        #expect(p105[27].lettres.finitParUnites("אתדברו"))
        #expect(p21[1].lettres.contientUnites("מהיגל"))
    }

    @Test func leCycleDuMoisCouvreToutLeLivreEnTrenteJours() {
        #expect(CycleTehilim.mois.count == 30)
        var attendu = 1
        for p in CycleTehilim.mois where !p.partielle {
            if p.debut == 120 { attendu = 120 } // 119 est coupé en deux portions
            #expect(p.debut == attendu, "portion qui commence à \(p.debut)")
            attendu = p.fin + 1
        }
        #expect(attendu == 151)
        let coupe = CycleTehilim.mois.filter(\.partielle)
        #expect(coupe == [Portion(119, 119, 1, 96), Portion(119, 119, 97, 176)])
        #expect(CycleTehilim.duMois(1, longueur: 30) == Portion(1, 9))
        #expect(CycleTehilim.duMois(30, longueur: 30) == Portion(145, 150))
        // Un mois de 29 jours finit le livre le 29.
        #expect(CycleTehilim.duMois(29, longueur: 29) == Portion(140, 150))
        #expect(CycleTehilim.duMois(29, longueur: 30) == Portion(140, 144))
    }

    @Test func leCycleDeLaSemaineCouvreToutLeLivreDuDimancheAuShabbat() throws {
        let semaine = CycleTehilim.semaine
        #expect(semaine.count == 7)
        for (a, b) in zip(semaine, semaine.dropFirst()) {
            #expect(a.fin + 1 == b.debut, "\(a) puis \(b)")
        }
        let premiere = try #require(semaine.first), derniere = try #require(semaine.last)
        #expect(premiere.debut == 1)
        #expect(derniere.fin == 150)
        // Le 04/10/2026 est un dimanche, le 09 un vendredi, le 10 un samedi.
        #expect(CycleTehilim.deLaSemaine(JourCivil.du("2026-10-04")) == Portion(1, 29))
        #expect(CycleTehilim.deLaSemaine(JourCivil.du("2026-10-09")) == Portion(107, 119))
        #expect(CycleTehilim.deLaSemaine(JourCivil.du("2026-10-10")) == Portion(120, 150))
        #expect(CycleTehilim.deLaSemaine(jourDeSemaine: 1) == Portion(1, 29))
        #expect(CycleTehilim.deLaSemaine(jourDeSemaine: 6) == Portion(107, 119))
        #expect(CycleTehilim.deLaSemaine(jourDeSemaine: 7) == Portion(120, 150))
    }

    @Test func unePortionPartielleNeLitQueSesVersets() {
        let p = Portion(119, 119, 97, 176)
        // 97..176 et 1..6 de Kotlin, en demi-ouvert.
        #expect(p.versets(119, total: 176) == 97..<177)
        #expect(Portion(1, 9).versets(1, total: 6) == 1..<7)
        #expect(p.partielle)
        #expect(!Portion(5, 5).partielle)
    }

    /// Roch Hachana 5787 tombe le 12/09/2026 ; Tichri a toujours 30 jours.
    @Test func leJourHebreuVientDuCalendrier() {
        let rochHachana = CycleTehilim.jourHebreu(JourCivil.du("2026-09-12"))
        #expect(rochHachana.jour == 1)
        #expect(rochHachana.longueur == 30)
        let quatreOctobre = CycleTehilim.jourHebreu(JourCivil.du("2026-10-04"))
        #expect(quatreOctobre.jour == 23)
        #expect(quatreOctobre.longueur == 30)
    }

    @Test func lesChainesDuLivreExistentDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let cles = ["tehilim_title", "tehilim_month", "tehilim_week", "tehilim_single", "tehilim_range",
                    "tehilim_range_verses", "tehilim_verses", "tehilim_today"]
        for langue in Catalogue.langues {
            // « tehilim_verses » est un pluriel (<plurals> d'Android).
            let chaines = catalogue.simples(langue)
            let pluriels = catalogue.pluriels(langue)
            for cle in cles {
                let present = chaines[cle] != nil || pluriels["\(cle)[other]"] != nil
                #expect(present, "\(langue) : \(cle)")
            }
        }
    }
}
