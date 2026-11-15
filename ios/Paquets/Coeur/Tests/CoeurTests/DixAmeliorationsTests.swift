import Foundation
import Testing
@testable import Coeur

/// DixAmeliorationsTest d'Android, porté : les dix améliorations du 14/10, ce qui se teste sans écran — le rappel de
/// Birkat haLevana, la prière du moment de la vignette, la recherche sans voyelles ni balises, les minutes du mois
/// et le résumé du journal. Les littéraux hébreux sont recopiés du test Kotlin octet pour octet.
@Suite("DixAmeliorations")
struct DixAmeliorationsTests {

    private func zone() throws -> Fuseau { try #require(Fuseau("Asia/Jerusalem")) }

    @Test func rappelLevanaPremierSoirPuisMotsaeChabbatPuisDernier() throws {
        let z = try zone()
        let heure = { (d: JourCivil) -> DateHeureZonee in DateHeureZonee(DateHeure(d, heure: 19), fuseau: z) }
        let debut = DateHeureZonee(DateHeure(JourCivil.du("2026-10-14"), heure: 9), fuseau: z)
        let p1 = LevanaAlerte.prochain(debut, usage: .troisMiMois, heure: heure)
        let r1 = try #require(p1)
        #expect(r1.quand.jour == JourCivil.du("2026-10-14"))
        #expect(r1.soir == .premier)
        let p2 = LevanaAlerte.prochain(r1.quand.plus(minutes: 1), usage: .troisMiMois, heure: heure)
        let r2 = try #require(p2)
        #expect(r2.quand.jour == JourCivil.du("2026-10-17"))
        #expect(r2.soir == .motsae)
        let p3 = LevanaAlerte.prochain(r2.quand.plus(minutes: 1), usage: .troisMiMois, heure: heure)
        let r3 = try #require(p3)
        #expect(r3.quand.jour == JourCivil.du("2026-10-25"))
        #expect(r3.soir == .dernier)
        // Après le dernier soir : le premier soir du mois suivant.
        let p4 = LevanaAlerte.prochain(r3.quand.plus(minutes: 1), usage: .troisMiMois, heure: heure)
        let r4 = try #require(p4)
        #expect(r4.quand.jour > JourCivil.du("2026-11-05"))
        #expect(r4.soir == .premier)
    }

    @Test func widgetLaPriereDuMomentEtSaLimite() throws {
        let z = try zone()
        let j = JourCivil.du("2026-10-14")
        func t(_ h: Int, _ m: Int) -> DateHeureZonee { DateHeureZonee(DateHeure(j, heure: h, minute: m), fuseau: z) }
        let horaires = ["szt_gra": t(10, 30), "chkia": t(17, 50), "chatsot_layla": t(23, 40)]
        let matin = ZmanimWidget.prochaine(horaires, maintenant: t(7, 0))
        #expect(matin.priere == "chaharit" && matin.limite == t(10, 30))
        let midi = ZmanimWidget.prochaine(horaires, maintenant: t(13, 0))
        #expect(midi.priere == "minha" && midi.limite == t(17, 50))
        let soir = ZmanimWidget.prochaine(horaires, maintenant: t(19, 0))
        #expect(soir.priere == "arvit" && soir.limite == t(23, 40))
        let tard = ZmanimWidget.prochaine(horaires, maintenant: t(23, 50))
        #expect(tard.priere == "arvit" && tard.limite == nil)
        // Après minuit, avant l'aube : encore Arvit (jusqu'au milieu de la nuit d'hier s'il n'est pas passé).
        let nuit = ["alot": t(5, 20), "szt_gra": t(10, 30), "chkia": t(17, 50), "chatsot_layla": t(23, 40).plus(minutes: 70)]
        let minuitPasse = ZmanimWidget.prochaine(nuit, maintenant: t(0, 20))
        #expect(minuitPasse.priere == "arvit" && minuitPasse.limite == t(0, 50))
        let deuxHeures = ZmanimWidget.prochaine(nuit, maintenant: t(2, 0))
        #expect(deuxHeures.priere == "arvit" && deuxHeures.limite == nil)
        let aube = ZmanimWidget.prochaine(nuit, maintenant: t(6, 0))
        #expect(aube.priere == "chaharit" && aube.limite == t(10, 30))
    }

    /// Le recueil du test d'Android : un texte « t », titré עלינו / Alénou / Aleinu, d'un seul bloc de prière.
    private func recueil() throws -> Siddur {
        let objet: [String: Any] = [
            "groupes": [[String: Any]](),
            "textes": [[
                "id": "t", "groupe": "g", "titre": ["he": "עלינו", "fr": "Alénou", "en": "Aleinu"], "source": "",
                "sections": [["titre": "", "blocs": [["t": "וַאֲנַחְנוּ כּוֹרְעִים"]]]],
            ]],
        ]
        let donnees = try JSONSerialization.data(withJSONObject: objet)
        return try JSONDecoder().decode(Siddur.self, from: donnees)
    }

    @Test func rechercheSansVoyellesNiBalises() throws {
        #expect(RechercheGlobale.nu("<b>בָּרוּךְ</b> אַתָּה") == "ברוך אתה")
        let s = try recueil()
        let parMot = RechercheGlobale.dansRecueil(s, RechercheGlobale.nu("כורעים"), sorte: .siddour, langue: "fr")
        let idsMot = parMot.map { $0.id }
        #expect(idsMot == ["t"])
        let parTitre = RechercheGlobale.dansRecueil(s, RechercheGlobale.nu("alénou"), sorte: .siddour, langue: "fr")
        let idsTitre = parTitre.map { $0.id }
        #expect(idsTitre == ["t"])
        // Sans accents ni apostrophe typographique (29/10) : « alenou », « hachahar ».
        let sansAccent = RechercheGlobale.dansRecueil(s, RechercheGlobale.nu("Alenou"), sorte: .siddour, langue: "fr")
        let idsSansAccent = sansAccent.map { $0.id }
        #expect(idsSansAccent == ["t"])
        #expect(RechercheGlobale.nu("Birkot hacha’har Prières") == "birkot hachahar prieres")
        let rien = RechercheGlobale.dansRecueil(s, "שבת", sorte: .siddour, langue: "fr")
        #expect(rien.isEmpty)
    }

    @Test func journalLesMinutesDuMoisEtLeResume() {
        let jours: [JourCivil: Journee] = [
            JourCivil.du("2026-10-01"): Journee(minutes: 20),
            JourCivil.du("2026-10-03"): Journee(minutes: 0, note: "note", noteSeule: true),
            JourCivil.du("2026-10-31"): Journee(minutes: 45),
        ]
        let m = JournalPlus.minutesDuMois(jours, annee: 2026, mois: 10)
        #expect(m.count == 31)
        #expect(m[0] == 20 && m[2] == 0 && m[30] == 45)
        let resume = JournalPlus.resume(JournalPlus(avant: 2, apres: 4, gratitude: "merci"), gratitude: "G")
        #expect(resume == "\u{2066}🙁 → 🙂\u{2069}\nG : merci")
        #expect(JournalPlus.resume(JournalPlus(), gratitude: "G") == "")
    }
}
