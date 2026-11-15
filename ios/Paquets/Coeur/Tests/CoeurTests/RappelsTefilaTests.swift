import Testing
@testable import Coeur

/// RappelsTefilaTest d'Android, porté : les dates des changements de la prière, en Israël et en
/// diaspora, au nord et au sud.
@Suite("Rappels de tefila")
struct RappelsTefilaTests {

    private func rappels(_ iso: String, israel: Bool, avance: Int = 3, sansGuechem: Bool = false) -> [RappelsTefila.Rappel] {
        RappelsTefila.prochains(.du(iso), avance: avance, sansGuechem: sansGuechem) { CalendrierJuif.jour($0, enIsrael: israel) }
    }

    /// CalJ (Jérusalem) l'annonce pour Motsaé Chabbat, à Arvit : le soir qui ouvre le 7 'Hechvan.
    @Test func laBenedictionDHiverEnIsraelLe7Hechvan5787() {
        #expect(rappels("2026-10-16", israel: true) == [RappelsTefila.Rappel(.pluieDebut, .du("2026-10-18"))])
        #expect(CalendrierJuif.jour(.du("2026-10-18"), enIsrael: true).jourHebreu == 7)
    }

    @Test func enDiasporaRienEnOctobreEtLeDebutEnDecembre() {
        #expect(!rappels("2026-10-16", israel: false).contains { $0.genre == .pluieDebut })
        let dec = rappels("2026-12-02", israel: false, avance: 6).filter { $0.genre == .pluieDebut }
        // Premier jour le samedi 5 décembre : pas d'Arvit de vendredi soir, on commence à motsaé Chabbat
        // (rappel daté du dimanche 6, FCALENDRIER-04) ; il reste affiché le samedi.
        #expect(dec.map(\.date) == [JourCivil.du("2026-12-06")])
        for jour in ["2026-12-02", "2026-12-04", "2026-12-05"] {
            let r = rappels(jour, israel: false).filter { $0.genre == .pluieDebut }
            #expect(r.map(\.date) == [JourCivil.du("2026-12-06")], "5/12/2026 vu le \(jour)")
        }
        #expect(!rappels("2026-12-06", israel: false).contains { $0.genre == .pluieDebut })
        // 2031 : le premier jour est le samedi 6 décembre, rappel au 7.
        let r2031 = rappels("2031-12-05", israel: false).filter { $0.genre == .pluieDebut }
        #expect(r2031.map(\.date) == [JourCivil.du("2031-12-07")])
    }

    /// 15 Nissan 5787 : jeudi 22 avril 2027.
    @Test func pessah5787EnIsraelFinDeLaPluieEtDeMachivHarouahDebutDeLOmer() {
        let r = Set(rappels("2027-04-20", israel: true))
        let p = JourCivil.du("2027-04-22")
        #expect(r.contains(RappelsTefila.Rappel(.pluieFin, p)))
        #expect(r.contains(RappelsTefila.Rappel(.guechemFin, p)))
        #expect(r.contains(RappelsTefila.Rappel(.omer, p.plus(jours: 1))))
    }

    /// 1 Tichri 5788 : samedi 2 octobre 2027 ; 22 Tichri : samedi 23 octobre 2027.
    @Test func rochHachanaEtCheminiAtseret5788() {
        #expect(rappels("2027-09-30", israel: false).contains(RappelsTefila.Rappel(.dixJours, .du("2027-10-02"))))
        #expect(rappels("2027-10-21", israel: true).contains(RappelsTefila.Rappel(.guechemDebut, .du("2027-10-23"))))
    }

    @Test func nordEtSudIsraelEtDiaspora() {
        let genres = { (israel: Bool, sud: Bool) in Set(rappels("2027-10-21", israel: israel, sansGuechem: sud).map(\.genre)) }
        // Nord : Israël et diaspora annoncent מַשִּׁיב הָרוּחַ ; sud (Edot) : rien à annoncer.
        #expect(genres(true, false).contains(.guechemDebut))
        #expect(genres(false, false).contains(.guechemDebut))
        #expect(!genres(false, true).contains(.guechemDebut))
        // La demande de pluie suit la diaspora au sud : début en décembre, pas le 7 'Hechvan.
        #expect(!rappels("2026-10-16", israel: false, sansGuechem: true).contains { $0.genre == .pluieDebut })
    }

    @Test func chaqueRappelASaSourceEtSonMoment() {
        #expect(RappelsTefila.Genre.allCases.map(\.source) == ["117:1", "117:1", "114:1", "114:1", "582:1", "489:1"])
        #expect(RappelsTefila.Genre.allCases.filter(\.leSoir) == [.pluieDebut, .dixJours, .omer])
    }
}
