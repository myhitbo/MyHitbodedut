import Foundation
import Testing
@testable import Coeur

/// SiddurTest d'Android, porté sur les contenus exportés : les textes de la liste CalJ, le Moussaf
/// de Roch 'Hodech et les bénédictions des occasions dans les trois nusah, leur balisage, et le
/// partage entre prière et consigne.
///
/// Restent à Android, parce qu'ils lisent le code de ses écrans : la bande de signets branchée dans
/// SiddurLectureActivity et l'onglet Textes qui ouvre le siddour ; ils reviendront avec ces écrans
/// (ROADMAP, tâche 21). Leurs chaînes sont vérifiées ici.
@Suite("Siddur")
struct SiddurTests {

    private static let charges: Result<[(Nusah, Siddur)], any Error> = Result {
        try Nusah.allCases.map { n in (n, try JSONDecoder().decode(Siddur.self, from: Depot.contenu(n.fichier))) }
    }

    private func tous() throws -> [(Nusah, Siddur)] { try Self.charges.get() }

    private func siddur(_ n: Nusah) throws -> Siddur {
        let recueils = try tous()
        return try #require(recueils.first { $0.0 == n }?.1)
    }

    private let attendus = [
        "birkot_hachahar", "chaharit", "minha", "arvit", "chema_coucher", "tikoun_hatsot",
        "acher_yatsar", "birkat_hamazon", "meen_chaloch", "bore_nefachot", "tefilat_haderekh",
        "birkat_halevana", "hallel", "moussaf_rosh_hodech", "parachat_haman", "kaddich", "hachkavot",
        // Les bénédictions des occasions (14/10, tools/siddur_occasions.py).
        "birkat_hailanot", "keshet", "barakim", "yam", "nehenin", "hagomel", "mezouza", "hala", "tevilat_kelim",
        "maakeh", "maasrot", "refoua", "nerot_hanouka", "megila", "sefirat_haomer", "soukka", "loulav",
        "bedikat_hamets", "erouv_tavchilin", "nerot_chabbat", "havdala",
    ]

    @Test func seulesLesMentionsImposeesParLesLicencesRestentSansSefaria() throws {
        let edot = try siddur(.edot)
        #expect(edot.mentions.isEmpty)
        for (n, s) in try tous() {
            #expect(s.mentions.allSatisfy { $0.contains("CC-BY") && !$0.contains("Sefaria") && !$0.contains("Public Domain") },
                    "\(n)")
            #expect(s.sources.filter { $0.contains("CC-BY") }.count == s.mentions.count, "\(n)")
        }
    }

    @Test func chaqueNusahALesTextesDemandes() throws {
        for (n, s) in try tous() {
            #expect(s.textes.map(\.id) == attendus, "\(n)")
            #expect(!s.nusah.he.blanc && !s.sources.isEmpty, "\(n) sans nom")
            for t in s.textes {
                #expect(!t.sections.isEmpty && t.sections.allSatisfy { !$0.blocs.isEmpty }, "\(n)/\(t.id) vide")
                #expect(!t.titre.he.blanc && !t.titre.fr.blanc && !t.titre.en.blanc, "\(n)/\(t.id) sans titre")
                #expect(s.groupes.contains { $0.cle == t.groupe }, "\(n)/\(t.id) : groupe inconnu")
                #expect(!t.source.blanc, "\(n)/\(t.id) sans source")
            }
        }
    }

    /// Le Hallel (12/10) dans les trois nusah, avec le saut de Roch 'Hodech (Tehilim 115 et 116,
    /// 1-11) ; le Moussaf de Roch 'Hodech, celui de semaine seulement : rien sur Chabbat Roch 'Hodech.
    @Test func leHallelEtUnMoussafDeRochHodechSansChabbat() throws {
        // Le maqaf (« מָה־אָשִׁיב ») sépare les mots comme une espace.
        let maqaf = try Motif(#"\u05BE"#), balise = try Motif("<[^>]+>")
        let signes = try Motif(#"[\u0591-\u05C7]"#), espaces = try Motif(#"\s+"#)
        let numero = try Motif("(^|[.:] )[א-ת]{1,2} ")
        let nu = { (s: String) -> String in
            espaces.remplace(signes.remplace(balise.remplace(maqaf.remplace(s, par: " "))), par: " ")
        }
        for (n, s) in try tous() {
            let texteHallel = try #require(s.texte("hallel"))
            let hallel = texteHallel.sections.flatMap(\.blocs)
            let tout = hallel.map { nu($0.texte) }.joined(separator: " ")
            for attendu in ["בצאת ישראל ממצרים", "מה אשיב", "אנא יהוה הושיעה נא", "יהללוך"] {
                #expect(tout.contient(attendu), "\(n) : \(attendu)")
            }
            #expect(hallel.filter { $0.consigne && $0.texte.contient("מדלג") }.count >= 2, "\(n) : saut de Roch 'Hodech")
            // Ni renvois de versets ni numéros collés au texte.
            #expect(!hallel.contains { $0.texte.contient("(תהילים") }, "\(n) : renvois")
            #expect(!hallel.contains { !$0.consigne && numero.present(dans: $0.texte) }, "\(n) : numéros")
            let texteMoussaf = try #require(s.texte("moussaf_rosh_hodech"))
            let moussaf = texteMoussaf.sections.flatMap(\.blocs)
            #expect(!moussaf.contains { $0.consigne && nu($0.texte).contient("שבת") }, "\(n) : Chabbat")
        }
    }

    /// Le Moussaf de Roch 'Hodech (11/10) : la bénédiction du milieu, puis la consigne du Bnei
    /// Yissaschar et les douze צירופי הוי״ה des mois.
    @Test func leMoussafDeRochHodechPorteLesTseroufimDuBneiYissaschar() throws {
        let balise = try Motif("<[^>]+>"), signes = try Motif(#"[\u0591-\u05C7]"#), saut = try Motif("<br>")
        for (n, s) in try tous() {
            let moussaf = try #require(s.texte("moussaf_rosh_hodech"))
            let blocs = moussaf.sections.flatMap(\.blocs)
            let i = try #require(blocs.firstIndex { $0.consigne && $0.texte.contient("בני יששכר") }, "\(n) : consigne")
            #expect(i > 0, "\(n) : consigne")
            guard i > 0 else { continue }
            // Juste après la fin de la bénédiction du milieu.
            #expect(signes.remplace(balise.remplace(blocs[i - 1].texte)).contient("מקדש ישראל וראשי חדשים"), "\(n) : placement")
            let c = blocs[i].texte
            // Avec leur nikkoud et la ligne אהי״ה (12/10, tools/siddur_construction.py).
            for attendu in ["ניסן: <b>יִהַוְהָ</b> · <b>אִהַיְהָ</b>", "תשרי: <b>וַהֹיָהַ</b> · <b>יַהֹאָהַ</b>",
                            "אדר: <b>הִהְיְוֲ</b>", "אלול: <b>הוּהִוָיִ</b>", "באדר ב׳ יכוון בכללות כל י״ב הצירופים"] {
                #expect(c.contient(attendu.nfc), "\(n) : \(attendu)")
            }
            // Les צירופים se pensent, ne se prononcent pas : dit avant la liste.
            #expect(c.contient("אין להוציא צירופים אלו בפה כלל"), "\(n) : avertissement")
            #expect(saut.compte(c) == 15, "\(n)")
        }
    }

    /// Le nikkoud des kavanot sur le Nom des 'hatimot de la Amida (11/10) : celui d'Edot, reporté
    /// sur Sfard (tools/noms_kavanot.py), recoupé avec le Chaar HaKavanot et le Pri Etz 'Haïm.
    @Test func lesHatimotDeLaAmidaSfardPortentLeNikkoudDesKavanot() throws {
        let sfard = try siddur(.sefard)
        let balise = try Motif("<[^>]+>"), cantillation = try Motif(#"[\u0591-\u05AF\u05BD]"#)
        let patah = try Motif("יַהַוַהַ".nfc), chourouq = try Motif("יוּהוּווּהוּ".nfc)
        let devantMagen = try Motif(#"יְהֹוָה[,.]?\s*מָגֵן"#.nfc)
        for id in ["chaharit", "minha", "arvit"] {
            let office = try #require(sfard.texte(id))
            let texte = balise.remplace(office.sections.filter { $0.titre.contient("עמידה") }
                .flatMap(\.blocs).map(\.texte).joined(separator: " "))
            // Avot et Da'at en patah, Refoua en holam, Michpat, Tsadikim et Chalom en chourouq.
            #expect(patah.compte(texte) >= 2, "\(id) : patah")
            #expect(texte.contient("יֹהֹוֹהֹ".nfc), "\(id) : holam")
            #expect(chourouq.compte(texte) >= 3, "\(id) : chourouq")
            #expect(!devantMagen.present(dans: cantillation.remplace(texte)), "\(id) : plus de יְהֹוָה avant « מגן אברהם »")
        }
    }

    /// Ce qui manque aux sources libres d'un nusah est emprunté à un autre, et le dit.
    @Test func lesEmpruntsSontMarques() throws {
        func empruntes(_ n: Nusah) throws -> [String] { try siddur(n).textes.filter { $0.emprunt != nil }.map(\.id) }
        // Les bénédictions des occasions (14/10) : ce qu'une source libre n'a pas est emprunté.
        let edot = try empruntes(.edot), sefard = try empruntes(.sefard), ashkenaz = try empruntes(.ashkenaz)
        #expect(edot == ["yam", "soukka", "loulav", "bedikat_hamets", "erouv_tavchilin"])
        #expect(sefard == ["tikoun_hatsot", "maakeh", "refoua", "sefirat_haomer"])
        #expect(ashkenaz == ["tikoun_hatsot", "birkat_hailanot", "keshet", "barakim", "yam", "nehenin", "hagomel",
                            "mezouza", "hala", "tevilat_kelim", "maakeh", "maasrot", "refoua", "megila",
                            "sefirat_haomer", "bedikat_hamets", "erouv_tavchilin", "nerot_chabbat", "havdala"])
        // Les Hachkavot, coutume séfarade, deviennent l'El malé ra'hamim du souvenir, pour un homme
        // et pour une femme ; jamais l'élégie du 20 Sivan (Rabbi Ye'hiel Mikhal de Nemirov).
        let balise = try Motif("<[^>]+>"), signes = try Motif(#"[\u0591-\u05C7]"#)
        for n in [Nusah.sefard, .ashkenaz] {
            let recueil = try siddur(n)
            let t = try #require(recueil.texte("hachkavot"))
            #expect(t.titre.fr == "El malé ra’hamim")
            let blocs = t.sections.flatMap(\.blocs)
            let texte = signes.remplace(balise.remplace(blocs.map(\.texte).joined(separator: " ")))
            #expect(texte.contient("אל מלא רחמים שוכן במרומים") || texte.contient("אל מלא רחמים, שוכן במרומים"), "\(n)")
            #expect(!texte.contient("יחיאל") && !texte.contient("סיון"), "\(n)")
            #expect(blocs.filter { !$0.consigne }.count == 2, "\(n)")
        }
    }

    /// La bande de signets (10/10) : la section qu'on lit, en haut de page comme tout en bas.
    @Test func leSignetSuitLaSectionQuOnLit() {
        let debuts = [0, 11, 14, 40]
        #expect(SignetsSiddur.courant(debuts, premiere: 0, derniere: 6, enBas: false) == 0)
        #expect(SignetsSiddur.courant(debuts, premiere: 10, derniere: 13, enBas: false) == 0)
        #expect(SignetsSiddur.courant(debuts, premiere: 11, derniere: 16, enBas: false) == 1)
        #expect(SignetsSiddur.courant(debuts, premiere: 39, derniere: 45, enBas: false) == 2)
        #expect(SignetsSiddur.courant(debuts, premiere: 40, derniere: 45, enBas: false) == 3)
        // Tout en bas, la dernière section, trop courte pour monter en haut, se marque quand même.
        #expect(SignetsSiddur.courant(debuts, premiere: 35, derniere: 45, enBas: true) == 3)
        // Avant le premier titre, le premier signet plutôt que rien.
        #expect(SignetsSiddur.courant([3, 9], premiere: 1, derniere: 4, enBas: false) == 0)
    }

    /// Les trois offices ont plusieurs sections titrées dans chaque nusah : leur bande existe.
    @Test func lesOfficesOntLeurBandeDeSignets() throws {
        for (n, s) in try tous() {
            for id in ["chaharit", "minha", "arvit"] {
                let office = try #require(s.texte(id))
                #expect(office.sections.filter { !$0.titre.blanc }.count > 1, "\(n)/\(id)")
            }
        }
    }

    /// Sfard (Ari z"l) n'est pas Sefarad : le libellé dit lequel, dans les trois langues.
    @Test func sfardEtSefaradNeSeConfondentPas() throws {
        let catalogue = try Catalogue.lire()
        let fr = catalogue.simples("fr"), he = catalogue.simples("he")
        #expect(fr["siddur_nusah_edot"] == "Séfarade (Edot HaMizra’h)")
        #expect(fr["siddur_nusah_sefard"] == "Sfard (Arizal)")
        #expect(he["siddur_nusah_sefard"] == "ספרד (האר״י)")
        let sfard = try siddur(.sefard), edot = try siddur(.edot)
        #expect(sfard.nusah.fr.contient("Sfard (Arizal)"))
        #expect(edot.nusah.fr.nfc.contient("séfarade".nfc))
    }

    /// Les chaînes de l'onglet Textes et du choix du nusah, dans les trois langues.
    @Test func lesChainesDuSiddourExistentDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        for langue in Catalogue.langues {
            let chaines = catalogue.simples(langue)
            for cle in ["siddur_title", "siddur_hint", "siddur_books", "siddur_choose", "siddur_nusah_edot",
                        "siddur_nusah_sefard", "siddur_nusah_ashkenaz", "siddur_sources"] {
                #expect(chaines[cle].map { !$0.blanc } == true, "\(langue) : \(cle)")
            }
        }
    }

    @Test func leBalisageSeLimiteAuGrasAuxPetitsCaracteresEtAuxSauts() throws {
        let ouvrante = try Motif("</?([a-z]+)"), balise = try Motif("<[^>]+>"), latin = try Motif("[A-Za-z]{4,}")
        let paires = try ["b", "small"].map { ($0, try Motif("<\($0)>"), try Motif("</\($0)>")) }
        for (n, s) in try tous() {
            for t in s.textes {
                for b in t.sections.flatMap(\.blocs) {
                    let balises = Set(ouvrante.groupes(b.texte, 1))
                    #expect(balises.subtracting(["b", "small", "br"]).isEmpty, "\(n)/\(t.id) : balise interdite \(balises.sorted())")
                    for (tag, ouvre, ferme) in paires {
                        #expect(ouvre.compte(b.texte) == ferme.compte(b.texte), "\(n)/\(t.id) : <\(tag)> mal fermée")
                    }
                    #expect(!latin.present(dans: balise.remplace(b.texte)), "\(n)/\(t.id) : du latin")
                }
            }
        }
    }

    /// La prière est vocalisée, la consigne non : c'est la règle de tools/siddur_construction.py.
    @Test func lesConsignesNeSontPasVocaliseesEtLesPrieresLeSont() throws {
        let balise = try Motif("<[^>]+>")
        func proportion(_ s: String) -> Double {
            var lettres = 0, voyelles = 0
            for u in balise.remplace(s).unicodeScalars {
                if (0x05D0...0x05EA).contains(u.value) { lettres += 1 }
                if (0x05B0...0x05BC).contains(u.value) || [0x05C1, 0x05C2, 0x05C7].contains(u.value) { voyelles += 1 }
            }
            return lettres == 0 ? 1 : Double(voyelles) / Double(lettres)
        }
        for (n, s) in try tous() {
            for t in s.textes {
                for b in t.sections.flatMap(\.blocs) {
                    // Seule exception : la consigne des צירופים, dont les Noms et les versets portent leur nikkoud (12/10).
                    if b.consigne && b.texte.contient("צירוף שם הוי״ה ואהי״ה") { continue }
                    if b.consigne {
                        #expect(proportion(b.texte) < 0.2, "\(n)/\(t.id) : consigne vocalisée")
                    } else {
                        #expect(proportion(b.texte) >= 0.2, "\(n)/\(t.id) : prière non vocalisée « \(b.texte.prefix(40)) »")
                    }
                }
            }
        }
    }

    @Test func parachatHamaneEstChemot16Versets4A36() throws {
        for (n, s) in try tous() {
            let texte = try #require(s.texte("parachat_haman"))
            #expect(texte.sections.count == 1, "\(n)")
            let section = try #require(texte.sections.first)
            let p = section.blocs
            #expect(p.count == 33, "\(n)")
            #expect(p.first?.texte.lettres.hasPrefix("ויאמריהוהאלמשההנניממטיר") == true, "\(n)")
            #expect(p.last?.texte.lettres.hasSuffix("עשריתהאיפההוא") == true, "\(n)")
        }
    }

    @Test func leKaddichEstCompletDansChaqueNusah() throws {
        let balise = try Motif("<[^>]+>"), signes = try Motif(#"[\u0591-\u05C7]"#)
        let nu = { (blocs: [SiddurBloc]) in signes.remplace(balise.remplace(blocs.map(\.texte).joined(separator: " "))) }
        for (n, s) in try tous() {
            let kaddich = try #require(s.texte("kaddich"))
            let k = nu(kaddich.sections.flatMap(\.blocs))
            for attendu in ["יתגדל ויתקדש", "רבא מברך", "עושה שלום"] {
                #expect(k.contient(attendu), "\(n) : le Kaddich n'a pas « \(attendu) »")
            }
        }
        let recueilEdot = try siddur(.edot)
        let kaddich = try #require(recueilEdot.texte("kaddich"))
        #expect(kaddich.sections.count == 1)
        let section = try #require(kaddich.sections.first)
        let edot = nu(section.blocs)
        #expect(edot.contient("על ישראל ועל רבנן") && edot.contient("יהא שלמא רבא"))
    }
}
