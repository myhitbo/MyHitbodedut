import Testing
@testable import Coeur

/// BasculeTest et HemisphereSudTest d'Android, portés : les jours de bascule de la pluie, Avinou
/// malkénou la veille de Kippour un vendredi, Jérusalem la ville, les conditions déduites du relevé
/// du 19/10, et l'hémisphère sud des Edot.
@Suite("Bascule et hémisphère sud")
struct BasculeTests {

    private typealias C = CalendrierJuif.C

    private func c(_ iso: String, israel: Bool = true) -> Set<String> {
        CalendrierJuif.jour(.du(iso), enIsrael: israel).conditions
    }

    @Test func le22TichriEtLe15NissanOntLesDeuxFormules() {
        for iso in ["2026-10-03", "2027-04-22"] {
            let s = SiddurJour.conditionsPour(.edot, enIsrael: true, c(iso))
            #expect(s.isSuperset(of: [C.machivHarouah, C.moridHatal]), "\(iso)")
            let a = JourAffiche.ajouts(c(iso), nusah: .edot, enIsrael: true)
            #expect(a.contains("ajout_machiv_harouah") && a.contains("ajout_morid_hatal"), "\(iso)")
        }
        let a = JourAffiche.ajouts(c("2026-10-04"), nusah: .edot, enIsrael: true)
        #expect(a.contains("ajout_machiv_harouah") && !a.contains("ajout_morid_hatal"))
        #expect(!SiddurJour.conditionsPour(.ashkenaz, enIsrael: false, c("2026-10-03", israel: false)).contains(C.moridHatal))
    }

    @Test func avinouMalkenouLaVeilleDeKippourUnVendredi() {
        #expect(SiddurJour.avinouMalkenou(c("2028-09-29", israel: false)))
        #expect(!SiddurJour.avinouMalkenou(c("2026-09-20", israel: false)))
    }

    @Test func jerusalemLaVillePasLesLocalitesVoisines() {
        let dedans = [(31.7767, 35.2345), (31.8466, 35.1975), (31.735, 35.188), (31.768, 35.159), (31.722, 35.226),
                      (31.825, 35.238), (31.796, 35.249)]
        let dehors = [(31.777, 35.298), (31.8017, 35.1478), (31.705, 35.2), (31.762, 35.262), (31.696, 35.115), (32.08, 34.78)]
        for (la, lo) in dedans { #expect(CalendrierJuif.aJerusalem(latitude: la, longitude: lo), "\(la),\(lo)") }
        for (la, lo) in dehors { #expect(!CalendrierJuif.aJerusalem(latitude: la, longitude: lo), "\(la),\(lo)") }
    }

    @Test func conditionsDeduitesDuReleveDu19Octobre() {
        #expect(c("2026-10-19").contains(C.lamnatseah))
        #expect(!c("2026-10-11").contains(C.lamnatseah))
        #expect(!c("2027-04-21").contains(C.lamnatseah))
        #expect(c("2026-08-20").contains(C.ledavid) && c("2026-10-02").contains(C.ledavid))
        #expect(!c("2026-10-19").contains(C.ledavid))
        #expect(c("2026-10-02").contains(C.techouvaHochaana))
        #expect(c("2027-04-22").isSuperset(of: [C.yomTov, C.moed]))
        #expect(c("2027-04-23").contains(C.motsaeChabbatYT))
        #expect(!c("2027-04-24").contains(C.motsaeChabbatYT))
        #expect(c("2026-10-19").isDisjoint(with: [C.beitAvel, C.oubli]))
    }

    /// Hémisphère sud, Edot : Yalkut Yosef, Kitsour Choulhan Aroukh, O.H. 117:20 — « מוריד הטל »
    /// toute l'année ; ותן טל ומטר comme la diaspora. Les autres noussa'h ne changent pas.
    @Test func edotAuSudMoridHatalEnHiverTalOumatarInchange() {
        let hiver = c("2027-01-10", israel: false)
        #expect(hiver.isSuperset(of: [C.machivHarouah, C.talOumatar]))
        let sud = SiddurJour.conditionsPour(.edot, enIsrael: false, hiver, sansTahanounFinTichri: true, sud: true)
        #expect(!sud.contains(C.machivHarouah))
        #expect(sud.isSuperset(of: [C.moridHatal, C.talOumatar]))
        #expect(JourAffiche.ajouts(hiver, nusah: .edot, enIsrael: false, sansTahanounFinTichri: true, sud: true)
            .contains("ajout_morid_hatal"))
        #expect(SiddurJour.conditionsPour(.edot, enIsrael: false, hiver, sansTahanounFinTichri: true, sud: false)
            .contains(C.machivHarouah))
        #expect(SiddurJour.conditionsPour(.ashkenaz, enIsrael: false, hiver, sansTahanounFinTichri: false, sud: true)
            .contains(C.machivHarouah))
        #expect(SiddurJour.conditionsPour(.sefard, enIsrael: false, hiver, sansTahanounFinTichri: false, sud: true)
            .contains(C.machivHarouah))
    }
}
