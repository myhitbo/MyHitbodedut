import Foundation
import Testing
@testable import Coeur

/// CategoriesSiddurTest d'Android (et web/test/categories.test.mjs), porté sur les contenus exportés : les ajouts du
/// siddour en deux catégories (demande du 26/11 et réponses Q1-Q15 du propriétaire). Un ajout du calendrier ne
/// s'affiche que le jour où il se dit, retiré sans bandeau les autres jours ; un ajout d'occasion reste replié mais
/// visible. Reste à Android : la lecture de tools/siddur_annotations.py (la liste OCCASIONS du générateur) ; ici, les
/// occasions ne sont jamais vraies, et le fichier d'annotations dit la règle.
@Suite("Siddour, les deux catégories")
struct CategoriesSiddurTests {

    private typealias C = CalendrierJuif.C

    private struct Donnees: Sendable {
        let json: String
        let siddourim: [Nusah: Siddur]
        let annotations: [Nusah: [String: [SiddurJour.Annotation]]]
    }

    private static let charges: Result<Donnees, any Error> = Result {
        let json = String(decoding: try Depot.contenu("siddur_annotations.json"), as: UTF8.self)
        var siddourim: [Nusah: Siddur] = [:]
        var annotations: [Nusah: [String: [SiddurJour.Annotation]]] = [:]
        for n in Nusah.allCases {
            siddourim[n] = try JSONDecoder().decode(Siddur.self, from: Depot.contenu(n.fichier))
            annotations[n] = try SiddurJour.parse(json, n)
        }
        return Donnees(json: json, siddourim: siddourim, annotations: annotations)
    }

    private func c(_ iso: String, israel: Bool = false) -> Set<String> {
        CalendrierJuif.jour(.du(iso), enIsrael: israel).conditions
    }

    private func lignes(_ n: Nusah, _ id: String, _ conditions: Set<String>, ouverts: Set<String> = [], israel: Bool = false,
                        voisin: Set<String> = []) throws -> [SiddurJour.Ligne] {
        let d = try Self.charges.get()
        let texte = try #require(d.siddourim[n]?.texte(id), "\(n.rawValue)/\(id)")
        let annotations = try #require(d.annotations[n]?[id], "\(n.rawValue)/\(id)")
        return SiddurJour.lignes(texte, annotations, conditions, ouverts: ouverts, nusah: n, enIsrael: israel, voisin: voisin)
    }

    /// Tous les replis ouverts, jusqu'aux replis imbriqués.
    private func tout(_ n: Nusah, _ id: String, _ conditions: Set<String>, israel: Bool = false,
                      voisin: Set<String> = []) throws -> [SiddurJour.Ligne] {
        var cles = Set<String>()
        while true {
            let l = try lignes(n, id, conditions, ouverts: cles, israel: israel, voisin: voisin)
            let plus = cles.union(replis(l).map { $0.cle })
            if plus == cles { return l }
            cles = plus
        }
    }

    private struct Repli {
        let cle: String
        let condition: String
        let libelle: String
        let pasAujourdhui: Bool
    }

    private func replis(_ l: [SiddurJour.Ligne]) -> [Repli] {
        l.compactMap {
            if case let .replie(cle, condition, _, libelle, pas) = $0 {
                return Repli(cle: cle, condition: condition, libelle: libelle, pasAujourdhui: pas)
            }
            return nil
        }
    }

    private static let balises = ExpressionReguliere("<[^>]+>")
    /// `[֑-ׇ\s״׳"'()]` de la JVM : les signes, les blancs ASCII (le `\s` de Java, écrit en toutes lettres), les
    /// guillemets et les parenthèses.
    private static let signes = ExpressionReguliere("[\\u0591-\\u05C7\\u0009-\\u000D\\u0020\\u05F4\\u05F3\"'()]")

    private func plat(_ t: String) -> String {
        Self.signes.remplace(Self.balises.remplace(t, par: ""), par: "")
    }

    private func blocsAvecStyle(_ l: [SiddurJour.Ligne]) -> [(texte: String, style: SiddurJour.Style, consigne: Bool)] {
        l.compactMap {
            if case let .bloc(b, style, _) = $0 { return (texte: b.texte, style: style, consigne: b.consigne) }
            return nil
        }
    }

    private func clair(_ l: [SiddurJour.Ligne]) -> [String] {
        blocsAvecStyle(l).filter { $0.style != .hors }.map { plat($0.texte) }
    }

    private func blocs(_ l: [SiddurJour.Ligne]) -> [String] {
        blocsAvecStyle(l).map { plat($0.texte) }
    }

    private func a(_ l: [String], _ p: String) -> Bool {
        let cherche = plat(p)
        return l.contains { $0.contientUnites(cherche) }
    }

    /// Un jour de semaine : aucun ajout du calendrier, ni en clair ni replié ; les occasions, repliées.
    @Test func semaineLeBirkatSansAjoutDuJourLesOccasionsRepliees() throws {
        for n in Nusah.allCases {
            let l = try lignes(n, "birkat_hamazon", c("2026-11-17"))
            let t = blocs(try tout(n, "birkat_hamazon", c("2026-11-17")))
            #expect(!a(t, "רצה והחליצנו"), "\(n.rawValue)")
            #expect(!a(t, "יעלה ויבא"), "\(n.rawValue)")
            #expect(!a(t, "על הנסים"), "\(n.rawValue)")
            // Les consignes d'oubli (Q5) : pas de Retsé ni de Ya'alé ce jour-là, retirées.
            let oubli = replis(l).contains { $0.condition == C.oubli }
            #expect(!oubli, "\(n.rawValue)")
            // Le zimoun, les Chéva bérakhot, les הרחמן de la table : repliés, « toucher pour lire ».
            let zimun = replis(l).contains { $0.condition == C.zimun && !$0.pasAujourdhui }
            #expect(zimun, "\(n.rawValue)")
            let occasions = replis(l).allSatisfy { SiddurJour.occasions.contains($0.condition) && !$0.pasAujourdhui }
            #expect(occasions, "\(n.rawValue)")
        }
    }

    /// Chabbat : Retsé en évidence ; les bénédictions de qui a oublié, repliées, avec les seules lignes du Chabbat (Q11).
    @Test func chabbatRetseEnEvidenceLOubliReplieAvecSesLignesDuJour() throws {
        let chabbat = c("2026-11-21")
        for n in Nusah.allCases {
            let l = try lignes(n, "birkat_hamazon", chabbat)
            let etiquette = l.contains(.etiquette(condition: C.chabbat, libelle: "ajout_chabbat"))
            #expect(etiquette, "\(n.rawValue)")
            #expect(a(clair(l), "רצה והחליצנו"), "\(n.rawValue)")
            let oubli = replis(l).contains { $0.condition == C.oubli }
            #expect(oubli, "\(n.rawValue)")
        }
        for n in [Nusah.sefard, .ashkenaz] {
            let t = blocs(try tout(n, "birkat_hamazon", chabbat))
            #expect(a(t, "אשר נתן שבתות למנוחה"), "\(n.rawValue)")
            #expect(!a(t, "אשר נתן ראשי חדשים"), "\(n.rawValue)")
        }
        let e = blocs(try tout(.edot, "birkat_hamazon", chabbat))
        #expect(a(e, "לשבת שבתות למנוחה") && !a(e, "לראש חודש (ו)ראשי חדשים"))
    }

    /// Roch 'Hodech : Ya'alé véyavo avec sa ligne ; le renvoi au Moussaf.
    @Test func rochHodechYaaleVeyavoMoussaf() throws {
        let rh = c("2026-10-12")
        for n in Nusah.allCases {
            let l = try lignes(n, "birkat_hamazon", rh)
            let etiquette = l.contains(.etiquette(condition: C.yaaleVeyavo, libelle: "ajout_yaale_veyavo"))
            #expect(etiquette, "\(n.rawValue)")
            #expect(!a(blocs(l), "חג המצות הזה"), "\(n.rawValue)")
            let moussaf = try lignes(n, "chaharit", rh).contains {
                if case .renvoi(_, "moussaf_rosh_hodech") = $0 { true } else { false }
            }
            #expect(moussaf, "\(n.rawValue)")
        }
    }

    /// 'Hanouka et Pourim : Al hanissim avec la seule ligne du jour.
    @Test func hanoukaEtPourimAlHanissimAvecLaLigneDuJour() throws {
        for n in Nusah.allCases {
            let h = clair(try lignes(n, "chaharit", c("2026-12-07")))
            #expect(a(h, "בימי מתתיה"), "\(n.rawValue)")
            #expect(!a(h, "בימי מרדכי ואסתר"), "\(n.rawValue)")
            let p = clair(try lignes(n, "minha", c("2027-03-23")))
            #expect(a(p, "בימי מרדכי ואסתר"), "\(n.rawValue)")
            #expect(!a(p, "בימי מתתיה"), "\(n.rawValue)")
            #expect(!a(clair(try lignes(n, "minha", c("2026-11-17"))), "על הנסים"), "\(n.rawValue)")
        }
    }

    /// Un jeûne public (10 Tévèt) : Anénou du particulier en clair (Q2) ; Avinou malkénou (Sfard, Ashkenaz).
    @Test func jeunePublicAnenouAvinouMalkenou() throws {
        let jeune = c("2026-12-20")
        for n in Nusah.allCases {
            let l = try lignes(n, "minha", jeune)
            let particulier = l.contains { if case .etiquette(_, "ajout_anenou_particulier") = $0 { true } else { false } }
            #expect(particulier, "\(n.rawValue)")
            let individuel = replis(l).contains { $0.libelle == "ajout_jeune_individuel" }
            #expect(!individuel, "\(n.rawValue)")
        }
        for n in [Nusah.sefard, .ashkenaz] {
            let am = try lignes(n, "chaharit", jeune).contains { if case .etiquette(C.avinouMalkenou, _) = $0 { true } else { false } }
            #expect(am, "\(n.rawValue)")
        }
    }

    /// Les dix jours : « המלך הקדוש » seul, « לעילא ולעילא » dans le Kaddich (Q8).
    @Test func dixJoursLaSeuleFormuleDuJourKaddichCompris() throws {
        let dix = c("2027-10-05")
        let ordinaire = c("2026-11-17")
        let sceauRoi = ExpressionReguliere("ברוךאתה[^,:]{4,12},?המלךהקדוש:?$")
        let sceauDieu = ExpressionReguliere("ברוךאתה[^,:]{4,12},?האלהקדוש:?$")
        for n in [Nusah.sefard, .ashkenaz, .edot] {
            let t = blocs(try tout(n, "chaharit", dix))
            #expect(t.contains { sceauRoi.trouve($0) != nil }, "\(n.rawValue)")
            #expect(!t.contains { sceauDieu.trouve($0) != nil }, "\(n.rawValue)")
            #expect(!a(blocs(try tout(n, "chaharit", ordinaire)), "המלך הקדוש"), "\(n.rawValue)")
        }
        let sfard = blocs(try tout(.sefard, "chaharit", dix))
        #expect(a(sfard, "לעלא ולעלא מכל"))
        #expect(!a(sfard, "לעלא מן כל"))
        #expect(a(blocs(try tout(.sefard, "chaharit", ordinaire)), "לעלא מן כל"))
        let ashkenaz = blocs(try tout(.ashkenaz, "chaharit", dix))
        #expect(a(ashkenaz, "לעלא לעלא מכל"))
        #expect(a(ashkenaz, "עושה השלום במרומיו"))
    }

    /// Eloul : Ledavid dès le 30 Av (Q13) ; hors d'Eloul, retiré en Sfard et en Ashkenaz, replié en Edot (Q10).
    @Test func eloulLedavidDesLe30AvRepliEnEdotHorsDEloul() throws {
        #expect(c("2026-08-13").contains(C.ledavid))  // 30 Av, premier jour de Roch 'Hodech Eloul
        #expect(!c("2026-08-12").contains(C.ledavid))
        for n in Nusah.allCases {
            #expect(a(clair(try lignes(n, "chaharit", c("2026-08-13"))), "יהוה אורי וישעי"), "\(n.rawValue)")
        }
        for n in [Nusah.sefard, .ashkenaz] {
            #expect(!a(blocs(try tout(n, "chaharit", c("2026-11-17"))), "יהוה אורי וישעי"), "\(n.rawValue)")
        }
        let edot = try lignes(.edot, "chaharit", c("2026-11-17"))
        let replie = replis(edot).contains { $0.condition == C.ledavid && $0.pasAujourdhui }
        #expect(replie)
        #expect(a(blocs(try tout(.edot, "chaharit", c("2026-11-17"))), "יהוה אורי וישעי"))
    }

    /// Le soir (Q6) : le jour voisin, et ses ajouts gardés repliés au lieu d'être retirés.
    @Test func vendrediSoirRetseReplieEntreCoucherEtSortieLeSoirQuiSuitAussi() throws {
        let d = JourCivil.du("2026-11-20")  // vendredi
        #expect(CalendrierJuif.jourVoisin("birkat_hamazon", date: d, heure: 16, apresCoucher: true, apresSortie: false) == d.plus(jours: 1))
        #expect(CalendrierJuif.jourVoisin("birkat_hamazon", date: d, heure: 18, apresCoucher: true, apresSortie: true) == d)
        #expect(CalendrierJuif.jourVoisin("meen_chaloch", date: d, heure: 17, apresCoucher: nil, apresSortie: nil) == d.plus(jours: 1))
        #expect(CalendrierJuif.jourVoisin("birkat_hamazon", date: d, heure: 15, apresCoucher: nil, apresSortie: nil) == nil)
        #expect(CalendrierJuif.jourVoisin("birkat_hamazon", date: d, heure: 14, apresCoucher: false, apresSortie: false) == nil)
        #expect(CalendrierJuif.jourVoisin("chaharit", date: d, heure: 17, apresCoucher: true, apresSortie: false) == nil)
        let vendredi = c("2026-11-20")
        let samedi = c("2026-11-21")
        for n in Nusah.allCases {
            let sans = try lignes(n, "birkat_hamazon", vendredi)
            #expect(!replis(sans).contains { $0.condition == C.chabbat }, "\(n.rawValue)")
            let avec = try lignes(n, "birkat_hamazon", vendredi, voisin: samedi)
            #expect(replis(avec).contains { $0.condition == C.chabbat && $0.pasAujourdhui }, "\(n.rawValue)")
            #expect(replis(avec).contains { $0.condition == C.oubli }, "\(n.rawValue)")
            #expect(!a(clair(avec), "רצה והחליצנו"), "\(n.rawValue)")
            // Méèn chaloch aussi.
            #expect(replis(try lignes(n, "meen_chaloch", vendredi, voisin: samedi)).contains { $0.condition == C.chabbat },
                    "\(n.rawValue)")
            // Le samedi soir, après la sortie des étoiles : le dimanche, avec le Chabbat qui finit pour voisin.
            #expect(replis(try lignes(n, "birkat_hamazon", c("2026-11-22"), voisin: samedi))
                .contains { $0.condition == C.chabbat && $0.pasAujourdhui }, "\(n.rawValue)")
        }
    }

    /// Israël ou diaspora non confirmé (Q7) : la question n'a lieu d'être que si le texte en dépend ce jour-là.
    @Test func israelOuDiasporaLeTexteEnDependIlAujourdhui() throws {
        let d = try Self.charges.get()
        func depend(_ n: Nusah, _ id: String, _ iso: String) throws -> Bool {
            let texte = try #require(d.siddourim[n]?.texte(id))
            let annotations = try #require(d.annotations[n]?[id])
            return SiddurJour.dependDeLaRegion(texte, annotations, israel: c(iso, israel: true), diaspora: c(iso), nusah: n)
        }
        for n in Nusah.allCases {
            // Le 22 Nissan 5787 : Isrou 'hag en Israël, 8ᵉ jour de Pessa'h en diaspora.
            #expect(try depend(n, "chaharit", "2027-04-29"), "\(n.rawValue)")
            // Un mardi ordinaire d'hiver après le 4 décembre : rien ne diffère.
            #expect(try !depend(n, "chaharit", "2027-01-19"), "\(n.rawValue)")
            // Entre le 7 'Hechvan et le 4 décembre, « ותן טל ומטר » diffère.
            #expect(try depend(n, "chaharit", "2026-11-17"), "\(n.rawValue)")
        }
        // L'Ashkenaz ne dit pas מוריד הטל hors d'Israël : l'été, la question se pose ; pas en Sfard.
        #expect(try depend(.ashkenaz, "minha", "2027-06-01"))
        #expect(try !depend(.sefard, "minha", "2027-06-01"))
    }

    /// L'omer du soir (Q12) : le seul compte du soir ; hors de l'omer, la section d'Arvit et son titre retirés.
    @Test func omerLeCompteDuSoirSeulement() throws {
        let soir = CalendrierJuif.jourDeLaPriere("sefirat_haomer", date: .du("2027-04-29"), heure: 21)
        #expect(soir == JourCivil.du("2027-04-30"))
        let jour8 = c(soir.iso)
        #expect(jour8.contains("omer_8"))
        // `^\S+(ניסן|אייר|סיון)\d+\.` de la JVM : des classes ASCII, écrites en toutes lettres.
        let date = ExpressionReguliere("^[^\\u0009-\\u000D\\u0020]+(ניסן|אייר|סיון)[0-9]+\\.")
        for n in [Nusah.sefard, .ashkenaz] {
            let l = clair(try lignes(n, "arvit", jour8))
            #expect(l.contains { $0.contientUnites("8.היום") }, "\(n.rawValue)")
            #expect(!l.contains { $0.contientUnites("7.היום") || $0.contientUnites("9.היום") }, "\(n.rawValue)")
            let page = clair(try lignes(n, "sefirat_haomer", jour8))
            #expect(page.filter { date.trouve($0) != nil }.count == 1, "\(n.rawValue)")
            // Hors de l'omer : ni compte ni titre de section à Arvit ; la page garde les 49 jours repliés.
            let hors = try lignes(n, "arvit", c("2026-11-18"))
            let titre = hors.contains { if case let .titre(t, _, _) = $0 { plat(t) == plat("ספירת העומר") } else { false } }
            #expect(!titre, "\(n.rawValue)")
            let page49 = replis(try lignes(n, "sefirat_haomer", c("2026-11-18")))
            #expect(page49.count == 1 && page49.first?.pasAujourdhui == true, "\(n.rawValue)")
            #expect(blocs(try tout(n, "sefirat_haomer", c("2026-11-18"))).filter { date.trouve($0) != nil }.count == 49,
                    "\(n.rawValue)")
        }
        // Edot : la date, le compte et la séfira du soir.
        let edot = clair(try lignes(.edot, "sefirat_haomer", jour8))
        #expect(a(edot, "שמונה ימים לעמר"))
        #expect(!a(edot, "שבעה ימים לעמר"))
    }

    /// Pas de Ta'hanoun aujourd'hui (Q1) : le Ta'hanoun et les ajouts du lundi et du jeudi retirés, למנצח reste.
    @Test func pasDeTahanounAujourdhuiRetireLeTahanounSeul() throws {
        let lundi = c("2026-11-16")
        let sans = SiddurJour.avecSansTahanoun(lundi, true)
        for n in Nusah.allCases {
            let chomerIsrael = a(clair(try lignes(n, "chaharit", lundi)), "שומר ישראל")
            #expect(n == .edot || chomerIsrael, "\(n.rawValue)")
            let l = clair(try lignes(n, "chaharit", sans))
            #expect(!a(l, "ויאמר דוד אל גד"), "\(n.rawValue)")
            #expect(!a(l, "אנשי אמונה אבדו"), "\(n.rawValue)")
            #expect(a(l, "יענך יהוה ביום צרה"), "\(n.rawValue)")
        }
        // La section « תחנון » de Sfard, retirée avec son titre.
        let titre = try lignes(.sefard, "chaharit", sans).contains {
            if case let .titre(t, _, _) = $0 { plat(t) == plat("תחנון") } else { false }
        }
        #expect(!titre)
    }

    /// Le voyageur (Q3) : replié du 7 'Hechvan au 4 décembre, retiré le reste de l'année.
    @Test func voyageurReplieSeulementQuandIsraelEtLaDiasporaDifferent() throws {
        #expect(c("2026-11-17").contains(C.voyageurTalOumatar))
        #expect(!c("2027-01-19").contains(C.voyageurTalOumatar) && !c("2027-06-01").contains(C.voyageurTalOumatar))
        for n in [Nusah.edot, .ashkenaz] {
            #expect(replis(try lignes(n, "chaharit", c("2026-11-17"))).contains { $0.libelle == "ajout_voyageur_tal_oumatar" },
                    "\(n.rawValue)")
            #expect(!replis(try lignes(n, "chaharit", c("2027-01-19"))).contains { $0.libelle == "ajout_voyageur_tal_oumatar" },
                    "\(n.rawValue)")
        }
    }

    /// Les consignes d'oubli (Q5) : l'hiver, celle de « משיב הרוח », repliée ; l'été, retirée.
    @Test func oubliReplieLeJourOuLAjoutSeDit() throws {
        func oubli(_ n: Nusah, _ iso: String) throws -> Bool {
            blocsAvecStyle(try tout(n, "chaharit", c(iso))).contains {
                $0.consigne && plat($0.texte).contientUnites("משיבהרוח") && plat($0.texte).contientUnites("טעה")
            }
        }
        for n in Nusah.allCases {
            #expect(try oubli(n, "2027-01-19"), "\(n.rawValue)")
            #expect(try !oubli(n, "2027-06-01"), "\(n.rawValue)")
        }
    }

    /// Les usages datés (Q14) : Barekhi nafchi à Arvit (Edot), replié le soir de Roch 'Hodech, retiré les autres.
    @Test func usageDateReplieLeJourDitRetireLesAutres() throws {
        #expect(replis(try lignes(.edot, "arvit", c("2026-10-12"))).contains { $0.libelle == "ajout_roch_hodech_usage" })
        #expect(!replis(try lignes(.edot, "arvit", c("2026-11-18"))).contains { $0.libelle == "ajout_roch_hodech_usage" })
        // Le psaume 121 d'Arvit (Sfard) : en Israël seulement, replié.
        #expect(replis(try lignes(.sefard, "arvit", c("2026-11-18", israel: true), israel: true))
            .contains { $0.libelle == "ajout_israel_usage" })
        #expect(!replis(try lignes(.sefard, "arvit", c("2026-11-18"))).contains { $0.libelle == "ajout_israel_usage" })
    }

    /// Qui prie seul (Q4) : « יחיד אומר » et la braïta repliés sous « Sans minyan ».
    @Test func sansMinyanReplie() throws {
        for n in [Nusah.sefard, .ashkenaz] {
            let l = try lignes(n, "chaharit", c("2026-11-17"))
            #expect(replis(l).contains { $0.condition == SiddurJour.sansMinyan && $0.libelle == "ajout_sans_minyan" }, "\(n.rawValue)")
            #expect(!l.contains { if case .seul = $0 { true } else { false } }, "\(n.rawValue)")
            #expect(!a(clair(l), "אל מלך נאמן"), "\(n.rawValue)")
        }
    }

    /// Les formes de l'homme et de la femme (Q12) : selon צדיק / צדקת ; sans réglage, les deux.
    @Test func hommeEtFemmeLaSeuleFormeDuReglage() throws {
        let jour = c("2026-11-17")
        for n in [Nusah.sefard, .ashkenaz, .edot] {
            let femme = clair(try lignes(n, "birkot_hachahar", SiddurJour.avecAdresse(jour, "f")))
            let homme = clair(try lignes(n, "birkot_hachahar", SiddurJour.avecAdresse(jour, "m")))
            let aucun = clair(try lignes(n, "birkot_hachahar", jour))
            #expect(a(femme, "שעשני כרצונו") && !a(femme, "שלא עשני אשה"), "\(n.rawValue)")
            #expect(a(homme, "שלא עשני אשה") && !a(homme, "שעשני כרצונו"), "\(n.rawValue)")
            #expect(a(aucun, "שלא עשני אשה") && a(aucun, "שעשני כרצונו"), "\(n.rawValue)")
        }
        let e = clair(try lignes(.edot, "birkot_hachahar", SiddurJour.avecAdresse(jour, "f")))
        #expect(a(e, "שלא עשני גויה"))
        #expect(!a(e, "האשה אומרת"))
        // Reglages.conditionsDuJour : le réglage enregistré, et « Pas de Ta'hanoun aujourd'hui » du jour choisi.
        var r = Reglages()
        r.setAdresse("f")
        let j = CalendrierJuif.jour(.du("2026-11-16"), enIsrael: false)
        r.setSansTahanounLe(j.date, sans: true)
        let conditions = r.conditionsDuJour(j)
        #expect(conditions.contains(C.femme) && conditions.contains(C.sansTahanounPonctuel) && !conditions.contains(C.homme))
    }

    /// Les textes d'occasion ajoutés (Q15) : repliés, chaque jour, à leur place.
    @Test func occasionsAjouteesBritMilaMaisonEndeuilleeMiCheberakh() throws {
        let jour = c("2026-11-16")  // lundi, jour de lecture
        for n in [Nusah.sefard, .ashkenaz] {
            #expect(replis(try lignes(n, "birkat_hamazon", jour)).contains { $0.libelle == "ajout_brit_mila" }, "\(n.rawValue)")
            let l = try lignes(n, "chaharit", jour)
            for lib in ["ajout_mi_cheberakh_oleh", "ajout_mi_cheberakh_malade", "ajout_mi_cheberakh_yoledet", "ajout_hagomel"] {
                #expect(replis(l).contains { $0.libelle == lib }, "\(n.rawValue) \(lib)")
            }
            // Dans le Mi chébérakh de l'oleh, en semaine, pas « ולכבוד השבת » (Q11).
            let oleh = try #require(blocs(try tout(n, "chaharit", jour)).first { $0.contientUnites("בעבורשעלהלתורה") })
            #expect(!oleh.contientUnites("ולכבודהשבת"), "\(n.rawValue)")
        }
        let avel = replis(try lignes(.edot, "birkat_hamazon", jour)).filter { $0.condition == C.beitAvel }
        #expect(avel.count == 3)
        #expect(a(blocs(try tout(.edot, "birkat_hamazon", jour)), "מנחם אבלים שאכלנו משלו"))
    }

    /// Les occasions ne sont jamais vraies ; le fichier d'annotations dit la règle.
    @Test func lesOccasionsNeSontJamaisVraies() throws {
        let semaine = c("2026-11-17")
        for o in SiddurJour.occasions {
            #expect(!SiddurJour.conditionsPour(.edot, enIsrael: false, semaine).contains(o), "\(o)")
        }
        let json = try Self.charges.get().json
        let regle = json.components(separatedBy: "\"regle\"").dropFirst().first?.components(separatedBy: "\n").first ?? ""
        #expect(regle.contains("retiré"))
    }
}
