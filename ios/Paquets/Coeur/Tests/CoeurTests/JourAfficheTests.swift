import Foundation
import Testing
@testable import Coeur

/// JourAfficheTest d'Android, porté : l'onglet Zmanim et le calendrier, ajouts nommés, entrée et
/// sortie, grille du mois, texte du siddour suggéré par les zmanim du lieu.
@Suite("Jour affiché")
struct JourAfficheTests {

    private typealias C = CalendrierJuif.C

    private func horaires(_ lieu: Zmanim.Lieu, _ iso: String, israel: Bool) -> [String: Zmanim.Zman] {
        var r: [String: Zmanim.Zman] = [:]
        for z in JourAffiche.horaires(lieu: lieu, date: .du(iso), enIsrael: israel, minutes: 18) { r[z.cle] = z }
        return r
    }

    private func conditions(_ iso: String, israel: Bool = false) -> Set<String> {
        CalendrierJuif.jour(.du(iso), enIsrael: israel).conditions
    }

    @Test func vendrediLAllumageDixHuitMinutesAvantLaChkiaSamediLaSortie() throws {
        let vendredi = horaires(Lieux.jerusalem, "2026-10-16", israel: true)
        let allumage = try #require(vendredi["allumage"]?.instant), chkia = try #require(vendredi["chkia"]?.instant)
        #expect(abs(chkia.timeIntervalSince(allumage) - 18 * 60) < 0.001)
        #expect(vendredi["sortie"] == nil)
        let samedi = horaires(Lieux.jerusalem, "2026-10-17", israel: true)
        #expect(samedi["sortie"]?.instant != nil && samedi["sortie"]?.instant == samedi["tset"]?.instant)
        #expect(samedi["allumage"] == nil)
        let mercredi = horaires(Lieux.jerusalem, "2026-10-14", israel: true)
        #expect(mercredi["allumage"] == nil && mercredi["sortie"] == nil)
    }

    /// Une fête un vendredi (FCALENDRIER-01) : 2e jour de Pessa'h (diaspora), Chavouot, 2e jour de Roch Hachana.
    @Test func feteUnVendrediLesBougiesDeChabbatAvantLaChkiaJamaisATset() throws {
        for (iso, israel) in [("2027-04-23", false), ("2027-06-11", false), ("2027-06-11", true), ("2028-09-22", false)] {
            let h = horaires(israel ? Lieux.jerusalem : Lieux.paris, iso, israel: israel)
            let allumage = try #require(h["allumage"], "\(iso)")
            #expect(allumage.methode.cle == "avant_chkia", "\(iso)")
            let instant = try #require(allumage.instant), chkia = try #require(h["chkia"]?.instant)
            #expect(instant < chkia, "\(iso)")
            #expect(h["sortie"] == nil, "\(iso)")
        }
    }

    /// Roch Hachana 5787, diaspora : samedi 12 et dimanche 13 septembre 2026.
    @Test func deuxiemeJourDeFeteAllumerPasAvantLaSortieDuPremier() {
        let premier = horaires(Lieux.paris, "2026-09-12", israel: false)
        #expect(premier["allumage"]?.methode.cle == "apres_tset")
        #expect(premier["allumage"]?.instant != nil && premier["allumage"]?.instant == premier["tset"]?.instant)
        #expect(premier["sortie"] == nil)
        #expect(horaires(Lieux.paris, "2026-09-13", israel: false)["sortie"] != nil)
        #expect(horaires(Lieux.paris, "2026-09-11", israel: false)["allumage"]?.methode.cle == "avant_chkia")
    }

    @Test func lesAjoutsNommesSuiventLesConditions() throws {
        let rc = JourAffiche.ajouts(conditions("2026-10-12"))
        #expect(rc == ["ajout_machiv_harouah", "ajout_barkhenou", "ajout_yaale_veyavo", "ajout_hallel_partiel_sans_berakha",
                       "ajout_sans_tahanoun"])
        // Les Edot disent ברכנו / ברך עלינו ; les autres noussa'h ותן ברכה / ותן טל ומטר ; rien le Chabbat.
        #expect(JourAffiche.ajouts(conditions("2026-10-12"), nusah: .ashkenaz).contains("ajout_berakha"))
        let hanouka = JourAffiche.ajouts(conditions("2026-12-07"))
        #expect(["ajout_al_hanissim", "ajout_hallel_complet", "ajout_barekh_alenou"].allSatisfy { hanouka.contains($0) })
        let chabbat = JourAffiche.ajouts(conditions("2026-10-10"))
        #expect(!chabbat.contains { $0.contains("tahanoun") })
        // Chaque clé a son libellé, dans les trois langues.
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in rc + hanouka { #expect(chaines[cle] != nil, "\(langue) : \(cle)") }
        }
    }

    @Test func leNusahHallelPartielMoridHatalAnenou() {
        let rc = conditions("2026-10-12")
        // Bénédiction du Hallel partiel : sans, même en communauté (O.H. 422:2, Edot), avec (Rema).
        #expect(JourAffiche.ajouts(rc, nusah: .edot).contains("ajout_hallel_partiel_sans_berakha"))
        #expect(JourAffiche.ajouts(rc, nusah: .sefard).contains("ajout_hallel_partiel_avec_berakha"))
        #expect(JourAffiche.ajouts(rc, nusah: .ashkenaz).contains("ajout_hallel_partiel_avec_berakha"))
        // Morid hatal, l'été : beaucoup d'Ashkénazes ne le disent pas hors d'Israël.
        let ete = conditions("2027-06-01")
        #expect(JourAffiche.ajouts(ete, nusah: .edot).contains("ajout_morid_hatal"))
        #expect(JourAffiche.ajouts(ete, nusah: .sefard).contains("ajout_morid_hatal"))
        #expect(!JourAffiche.ajouts(ete, nusah: .ashkenaz).contains("ajout_morid_hatal"))
        #expect(JourAffiche.ajouts(ete, nusah: .ashkenaz, enIsrael: true).contains("ajout_morid_hatal"))
        // Anénou : l'officiant partout ; le particulier, à Min'ha seulement chez Ashkenaz et Sfard.
        let anenou = { (c: Set<String>, n: Nusah) in JourAffiche.ajouts(c, nusah: n).filter { $0.hasPrefix("ajout_anenou") } }
        let jeune = conditions("2026-12-20")
        #expect(anenou(jeune, .edot) == ["ajout_anenou_officiant", "ajout_anenou_particulier_matin_minha"])
        #expect(anenou(jeune, .ashkenaz) == ["ajout_anenou_officiant", "ajout_anenou_particulier_minha"])
        // Tich'a bèAv 5787 (12/08/2027) : chez les Edot, Arvit aussi.
        let av = conditions("2027-08-12")
        #expect(av.contains(C.tichaBeav))
        #expect(anenou(av, .edot) == ["ajout_anenou_officiant", "ajout_anenou_particulier_trois"])
        #expect(anenou(av, .sefard) == ["ajout_anenou_officiant", "ajout_anenou_particulier_minha"])
    }

    @Test func laGrilleDOctobre2026CommenceUnJeudiDuDimancheAuSamedi() {
        let s = JourAffiche.semaines(annee: 2026, mois: 10)
        #expect(s.allSatisfy { $0.count == 7 })
        #expect(s.first?[4] == JourCivil.du("2026-10-01"))
        #expect(s.first?.prefix(4).allSatisfy { $0 == nil } == true)
        #expect(s.flatMap { $0 }.compactMap { $0 }.count == 31)
        #expect(s.count == 5)
    }

    /// Bornes relevées dans le calendrier hébreu d'ICU et dans Hebcal.
    @Test func leMoisDeTichri5787EtSesVoisinsAdarIEtAdarIICompris() {
        let d = JourCivil.du("2026-10-10")
        let t = JourAffiche.joursMoisHebreu(d)
        #expect(t.count == 30)
        #expect(t.first == JourCivil.du("2026-09-12"))
        #expect(t.last == JourCivil.du("2026-10-11"))
        #expect(JourAffiche.semainesHebreu(d).first?[6] == JourCivil.du("2026-09-12"))
        #expect(JourAffiche.moisHebreuVoisin(d, sens: 1) == JourCivil.du("2026-10-12"))
        #expect(JourAffiche.moisHebreuVoisin(d, sens: -1) == JourCivil.du("2026-08-14"))
        #expect(JourAffiche.moisHebreuVoisin(.du("2027-01-15"), sens: 1) == JourCivil.du("2027-02-08"))
        #expect(JourAffiche.moisHebreuVoisin(.du("2027-02-08"), sens: 1) == JourCivil.du("2027-03-10"))
        #expect(JourAffiche.moisHebreuVoisin(.du("2027-03-10"), sens: 1) == JourCivil.du("2027-04-08"))
        #expect(JourAffiche.moisHebreuVoisin(.du("2027-03-10"), sens: -1) == JourCivil.du("2027-02-08"))
    }

    @Test func leSiddourSuitLesZmanimDuLieu() throws {
        let jer = Lieux.jerusalem
        var z: [String: Date] = [:]
        for zman in Zmanim.jour(lieu: jer, date: .du("2026-10-16")) { z[zman.cle] = zman.instant }
        #expect(z.count == 15)
        // Un zman absent donnerait une date lointaine : l'attendu échouerait.
        func juste(_ cle: String, _ secondes: Double) -> Date { (z[cle] ?? .distantPast).addingTimeInterval(secondes) }
        let moment = { (instant: Date) in JourAffiche.momentDuSiddour(lieu: jer, maintenant: instant) }
        #expect(moment(juste("alot", 60)) == "birkot_hachahar")
        #expect(moment(juste("misheyakir", 60)) == "chaharit")
        #expect(moment(juste("chatsot", -60)) == "chaharit")
        #expect(moment(juste("chatsot", 60)) == nil)
        #expect(moment(juste("minha_gedola", 60)) == "minha")
        #expect(moment(juste("chkia", -60)) == "minha")
        #expect(moment(juste("chkia", 60)) == nil)
        #expect(moment(juste("tset", 60)) == "arvit")
        let iso = ISO8601DateFormatter()
        let soir = try #require(iso.date(from: "2026-10-16T22:45:00+03:00"))
        let nuit = try #require(iso.date(from: "2026-10-16T02:00:00+03:00"))
        #expect(moment(soir) == "chema_coucher")
        #expect(moment(nuit) == "tikoun_hatsot")
        // Soleil de minuit à Tromsø : les heures fixes.
        let juin = try #require(iso.date(from: "2026-06-21T14:00:00+02:00"))
        #expect(JourAffiche.momentDuSiddour(lieu: Lieux.tromso, maintenant: juin) == SiddurMoment.suggestion(heure: 14, minute: 0))
    }

    /// L'horaire des bannières (HorairePriere.kt) : les heures locales des bornes, à la minute.
    @Test func lHorairePriereDonneLesBornesDuJour() throws {
        let zmanim = Zmanim.jour(lieu: Lieux.jerusalem, date: .du("2026-10-16"))
        let fuseau = try #require(TimeZone(identifier: "Asia/Jerusalem"))
        #expect(HorairePriere.heures("chaharit", zmanim: zmanim, fuseau: fuseau)?.count == 1)
        #expect(HorairePriere.heures("minha", zmanim: zmanim, fuseau: fuseau)?.count == 2)
        #expect(HorairePriere.heures("arvit", zmanim: zmanim, fuseau: fuseau)?.first?.count == 5)
        #expect(HorairePriere.heures("hallel", zmanim: zmanim, fuseau: fuseau) == nil)
    }
}
