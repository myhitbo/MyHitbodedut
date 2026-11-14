import Foundation
import Testing
@testable import Coeur

/// TehilimTest d'Android, porté : le livre entier (demande du 04/10), ses conventions, les deux
/// cycles qui le disent en un mois ou en une semaine, puis tout `Tests/Vecteurs/tehilim.json`, écrit
/// par la JVM (tools/vecteurs_ios/VecteursTehilim.kt). Reste à Android, dans `l onglet textes mene au
/// livre et les ecrans existent`, ce qui lit MainActivity.kt et le manifeste ; les chaînes se
/// vérifient ici sur le catalogue exporté.
@Suite("Tehilim")
struct TehilimTests {

    /// Le livre lu une fois pour toute la suite (860 Ko), comme les livres de LivresTests.
    private static let charge: Result<Tehilim, any Error> = Result { try TehilimLoader.load(Depot.lire) }

    private func lireLivre() throws -> Tehilim {
        try TehilimTests.charge.get()
    }

    /// `v.trimEnd().endsWith("׃")` de Kotlin.
    private static func finitParSofPasouq(_ verset: String) -> Bool {
        var unites = Array(verset.utf16)
        while let derniere = unites.last, Kotlin.estEspace(derniere) {
            unites.removeLast()
        }
        return unites.last == 0x05C3
    }

    /// `split(' ', '־')` de Kotlin : sur l'espace et le maqaf, les morceaux vides gardés.
    private static func mots(_ verset: String) -> [String] {
        var mots: [String] = []
        var courant: [UInt16] = []
        for unite in verset.utf16 {
            if unite == 0x0020 || unite == 0x05BE {
                mots.append(Unites.texte(courant))
                courant = []
            } else {
                courant.append(unite)
            }
        }
        mots.append(Unites.texte(courant))
        return mots
    }

    /// Une voyelle, de ְ à ּ, ou un point de shin ou de sin.
    private static func vocalise(_ mot: String) -> Bool {
        for unite in mot.utf16 where (0x05B0...0x05BC).contains(unite) || unite == 0x05C1 || unite == 0x05C2 {
            return true
        }
        return false
    }

    @Test func leLivreASes150PsaumesEtSes2527Versets() throws {
        let livre = try lireLivre()
        let psaumes = livre.psaumes.count
        #expect(psaumes == 150)
        let total = livre.versetsTotal
        #expect(total == 2527)
        let v119 = livre.versets(119).count
        #expect(v119 == 176)
        let v117 = livre.versets(117).count
        #expect(v117 == 2)
        let v150 = livre.versets(150).count
        #expect(v150 == 6)
    }

    @Test func chaqueVersetEstLuEtNonEcrit() throws {
        let livre = try lireLivre()
        var fautes: [String] = []
        for (i, versets) in livre.psaumes.enumerated() {
            for (j, v) in versets.enumerated() {
                let ou = "Tehilim \(i + 1):\(j + 1)"
                if !TehilimTests.finitParSofPasouq(v) { fautes.append("\(ou) ne finit pas par un sof pasouq") }
                if v.contientUnites("[") || v.contientUnites("]") { fautes.append("\(ou) garde un crochet de qere") }
                if v.contientUnites("\u{200D}") { fautes.append("\(ou) garde un caractère invisible") }
                // Un mot sans aucune voyelle serait un ketiv resté en place.
                for mot in TehilimTests.mots(v) where mot.lettres.utf16.count >= 2 && !mot.egalUnites("ה'") {
                    if !TehilimTests.vocalise(mot) { fautes.append("\(ou) : « \(mot) » sans voyelles") }
                }
            }
        }
        let aucune = fautes.isEmpty
        let detail = fautes.prefix(20).joined(separator: "\n")
        #expect(aucune, "\(fautes.count) faute(s) :\n\(detail)")
    }

    @Test func leNomEstEcritEnToutesLettresDansLeLivre() throws {
        let livre = try lireLivre()
        let v23 = try #require(livre.versets(23).first)
        let nomEntier = v23.contientUnites("יְהוָה".formeNFC)
        #expect(nomEntier)
        let v42 = livre.versets(42)
        let assez = v42.count > 6
        try #require(assez)
        let elohai = v42[6].commenceParUnites("אֱלֹהַי".formeNFC)
        #expect(elohai)
        var substitues: [String] = []
        for (i, versets) in livre.psaumes.enumerated() {
            for (j, v) in versets.enumerated() where v.contientUnites("ה'") {
                substitues.append("Tehilim \(i + 1):\(j + 1)")
            }
        }
        let aucun = substitues.isEmpty
        let detail = substitues.joined(separator: ", ")
        #expect(aucun, "substituent le Nom : \(detail)")
    }

    /// Les dix psaumes du Tikoun et le livre entier disent exactement le même texte, Nom compris.
    @Test func leTikounEtLeLivreConcordentVersetParVerset() throws {
        let livre = try lireLivre()
        let tikkun = try TikkunLoader.load(Depot.lire)
        var compares = 0
        var ecarts: [String] = []
        for p in tikkun.psaumes {
            let versets = livre.versets(p.numero)
            for v in p.versets {
                let ou = "Tehilim \(p.numero):\(v.numero)"
                if v.numero >= 1 && v.numero <= versets.count {
                    if !versets[v.numero - 1].formeNFC.egalUnites(v.he.formeNFC) { ecarts.append(ou) }
                } else {
                    ecarts.append("\(ou) absent du livre")
                }
                compares += 1
            }
        }
        let aucun = ecarts.isEmpty
        let detail = ecarts.joined(separator: ", ")
        #expect(aucun, "\(detail)")
        let nombre = compares
        #expect(nombre == 164)
    }

    /// Les corrections du 04/10 dans le Tikoun : les mots que la résolution du qere avait perdus.
    @Test func leQereNeFaitPlusPerdreDeMot() throws {
        let livre = try lireLivre()
        let v77 = try #require(livre.versets(77).first)
        let lamnatseah = v77.lettres.commenceParUnites("למנצחעלידותון")
        #expect(lamnatseah)
        let v105 = livre.versets(105)
        let assez105 = v105.count > 27
        try #require(assez105)
        let devaro = v105[27].lettres.finitParUnites("אתדברו")
        #expect(devaro)
        let v21 = livre.versets(21)
        let assez21 = v21.count > 1
        try #require(assez21)
        let mahYagel = v21[1].lettres.contientUnites("מהיגל")
        #expect(mahYagel)
    }

    @Test func leCycleDuMoisCouvreToutLeLivreEnTrenteJours() {
        let mois = CycleTehilim.mois
        #expect(mois.count == 30)
        var attendu = 1
        for p in mois where !p.partielle {
            if p.debut == 120 { attendu = 120 }  // 119 est coupé en deux portions
            let debut = p.debut, voulu = attendu
            #expect(debut == voulu, "portion qui commence à \(debut)")
            attendu = p.fin + 1
        }
        let apres = attendu
        #expect(apres == 151)
        let coupe = mois.filter { $0.partielle }
        #expect(coupe == [Portion(119, 119, 1, 96), Portion(119, 119, 97, 176)])
        let premier = CycleTehilim.duMois(1, 30)
        #expect(premier == Portion(1, 9))
        let trentieme = CycleTehilim.duMois(30, 30)
        #expect(trentieme == Portion(145, 150))
        // Un mois de 29 jours finit le livre le 29.
        let finCourt = CycleTehilim.duMois(29, 29)
        #expect(finCourt == Portion(140, 150))
        let finLong = CycleTehilim.duMois(29, 30)
        #expect(finLong == Portion(140, 144))
    }

    @Test func leCycleDeLaSemaineCouvreToutLeLivreDuDimancheAuShabbat() {
        let semaine = CycleTehilim.semaine
        #expect(semaine.count == 7)
        for k in semaine.indices where k > 0 {
            let suite = semaine[k - 1].fin + 1, debut = semaine[k].debut
            #expect(suite == debut)
        }
        let premier = semaine.first?.debut
        #expect(premier == 1)
        let dernier = semaine.last?.fin
        #expect(dernier == 150)
        // JourCivil.jourDeSemaine : 1 = dimanche, 6 = vendredi, 7 = samedi.
        let dimanche = CycleTehilim.deLaSemaine(1)
        #expect(dimanche == Portion(1, 29))
        let vendredi = CycleTehilim.deLaSemaine(6)
        #expect(vendredi == Portion(107, 119))
        let samedi = CycleTehilim.deLaSemaine(7)
        #expect(samedi == Portion(120, 150))
    }

    @Test func unePortionPartielleNeLitQueSesVersets() {
        let p = Portion(119, 119, 97, 176)
        let versets = p.versets(119, 176)
        #expect(versets == Portion.Intervalle(97, 176))
        let premiers = Portion(1, 9).versets(1, 6)
        #expect(premiers == Portion.Intervalle(1, 6))
        let partielle = p.partielle
        #expect(partielle)
        let entiere = Portion(5, 5).partielle
        #expect(!entiere)
    }

    /// Roch Hachana 5787 tombe le 12/09/2026 ; Tichri a toujours 30 jours.
    @Test func leJourHebreuVientDuCalendrier() {
        let rochHachana = CycleTehilim.jourHebreu(.du("2026-09-12"))
        #expect(rochHachana.jour == 1)
        #expect(rochHachana.longueur == 30)
        let octobre = CycleTehilim.jourHebreu(.du("2026-10-04"))
        #expect(octobre.jour == 23)
        #expect(octobre.longueur == 30)
    }

    /// Les chaînes des deux écrans, dans les trois langues (values, values-en, values-iw d'Android).
    @Test func lOngletTextesMeneAuLivreEtLesEcransExistent() throws {
        let catalogue = try Catalogue.lire()
        let cles = ["tehilim_title", "tehilim_month", "tehilim_week", "tehilim_single", "tehilim_range",
                    "tehilim_range_verses", "tehilim_verses", "tehilim_today"]
        for langue in Catalogue.langues {
            let simples = catalogue.simples(langue)
            var pluriels = Set<String>()
            for cle in catalogue.pluriels(langue).keys {
                pluriels.insert(cle.avantUnites("["))
            }
            for cle in cles {
                let presente = simples[cle] != nil || pluriels.contains(cle)
                #expect(presente, "\(langue) : \(cle)")
            }
        }
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Psaume117: Decodable {
            let he: [String]
            let fr: [String?]
            let en: [String?]
        }
        struct Livre: Decodable {
            let PSAUMES: Int
            let psaumes: Int
            let versetsTotal: Int
            let langues: [String]
            let psaume117: Psaume117
        }
        /// L'empreinte (`String.hashCode`) de chaque verset ; celle de ses traductions, versets joints
        /// par un saut de ligne, « ∅ » pour un verset sans traduction.
        struct Psaume: Decodable {
            let numero: Int
            let versets: Int
            let he: [Int32]
            let fr: Int32
            let en: Int32
        }
        struct Nombre: Decodable {
            let numero: Int
            let versets: Int
        }
        struct Traduction: Decodable {
            let langue: String
            let numero: Int
            let verset: Int
            let texte: String?
        }
        /// `resultats[numero][verset]` : `traduction(langue, numero, verset)`, de 0 à un de trop.
        struct Traduit: Decodable {
            let langue: String
            let resultats: [[String?]]
        }
        struct Document: Decodable {
            let nom: String
            let json: String
            let lu: Bool
            let psaumes: [[String]]?
            let versetsTotal: Int?
            let langues: [String]?
            let nombres: [Int]?
            let traduit: [Traduit]?
        }
        /// `psaumes` : [premier, dernier, nombre] ; `versets` : [psaume, total, premier, dernier, nombre].
        struct CasPortion: Decodable {
            let portion: [Int?]
            let partielle: Bool
            let psaumes: [Int]
            let versets: [[Int]]
        }
        struct DuMois: Decodable {
            let jour: Int
            let longueur: Int
            let portion: [Int?]
        }
        struct DeLaSemaine: Decodable {
            let jour: String
            let jourDeSemaine: Int
            let portion: [Int?]
        }
        /// d : la date ; s : le jour de la semaine (1 = dimanche) ; j, l : le jour du mois hébreu et la
        /// longueur de ce mois ; m, h : les portions du jour selon le mois et selon la semaine.
        struct JourDuCycle: Decodable {
            let d: String
            let s: Int
            let j: Int
            let l: Int
            let m: [Int?]
            let h: [Int?]
        }
        struct Borne: Decodable {
            let d: String
            let j: Int
            let l: Int
        }

        let livre: Livre
        let psaumes: [Psaume]
        let nombres: [Nombre]
        let traductions: [Traduction]
        let documents: [Document]
        let mois: [[Int?]]
        let semaine: [[Int?]]
        let portions: [CasPortion]
        let duMois: [DuMois]
        let deLaSemaine: [DeLaSemaine]
        let dates: [JourDuCycle]
        let bornesDeMois: [Borne]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/tehilim.json"))
    }

    /// [début, fin, premier verset, dernier verset ou null] → la portion.
    private static func portion(_ t: [Int?]) -> Portion? {
        guard t.count == 4, let debut = t[0], let fin = t[1], let debutVerset = t[2] else { return nil }
        return Portion(debut, fin, debutVerset, t[3])
    }

    private static func intervalle(_ i: Portion.Intervalle) -> [Int] {
        [i.premier, i.dernier, i.nombre]
    }

    /// `==` de Kotlin : les mêmes unités UTF-16, ou deux absences.
    private static func memeTexte(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return x.egalUnites(y)
        default: return false
        }
    }

    private static func memesTextes(_ a: [String], _ b: [String]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) where !x.egalUnites(y) {
            return false
        }
        return true
    }

    private static func ecrit(_ texte: String?) -> String {
        texte ?? "nil"
    }

    /// L'empreinte d'une liste de traductions, comme le générateur la calcule.
    private static func empreinte(_ textes: [String?]) -> Int32 {
        var morceaux: [String] = []
        for texte in textes {
            morceaux.append(texte ?? "∅")
        }
        return Kotlin.hashCode(morceaux.joined(separator: "\n"))
    }

    @Test func leLivreEstLuCommeSurAndroid() throws {
        let v = try vecteurs()
        let livre = try lireLivre()
        let nombreDePsaumes = Tehilim.nombreDePsaumes
        #expect(nombreDePsaumes == v.livre.PSAUMES)
        let psaumes = livre.psaumes.count, total = livre.versetsTotal, langues = livre.langues
        #expect(psaumes == v.livre.psaumes)
        #expect(total == v.livre.versetsTotal)
        #expect(langues == v.livre.langues)
        let he117 = TehilimTests.memesTextes(livre.versets(117), v.livre.psaume117.he)
        #expect(he117)
        for verset in 1...2 {
            let fr = TehilimTests.memeTexte(livre.traduction("fr", 117, verset), v.livre.psaume117.fr[verset - 1])
            #expect(fr, "117:\(verset) fr")
            let en = TehilimTests.memeTexte(livre.traduction("en", 117, verset), v.livre.psaume117.en[verset - 1])
            #expect(en, "117:\(verset) en")
        }

        let nombre = v.psaumes.count
        #expect(nombre == 150)
        for p in v.psaumes {
            let versets = livre.versets(p.numero)
            #expect(versets.count == p.versets, "Tehilim \(p.numero) : nombre de versets")
            var empreintes: [Int32] = []
            for texte in versets {
                empreintes.append(Kotlin.hashCode(texte))
            }
            #expect(empreintes == p.he, "Tehilim \(p.numero) : texte hébreu")
            var fr: [String?] = [], en: [String?] = []
            for verset in 0..<versets.count {
                fr.append(livre.traduction("fr", p.numero, verset + 1))
                en.append(livre.traduction("en", p.numero, verset + 1))
            }
            let empreinteFr = TehilimTests.empreinte(fr), empreinteEn = TehilimTests.empreinte(en)
            #expect(empreinteFr == p.fr, "Tehilim \(p.numero) : traduction française")
            #expect(empreinteEn == p.en, "Tehilim \(p.numero) : traduction anglaise")
        }

        for n in v.nombres {
            let versets = livre.versets(n.numero).count
            #expect(versets == n.versets, "versets(\(n.numero))")
        }
        for t in v.traductions {
            let texte = livre.traduction(t.langue, t.numero, t.verset)
            let meme = TehilimTests.memeTexte(texte, t.texte)
            #expect(meme, "traduction(« \(t.langue) », \(t.numero), \(t.verset)) : \(TehilimTests.ecrit(texte)), Android \(TehilimTests.ecrit(t.texte))")
        }
    }

    /// Ce que TehilimLoader accepte, refuse et convertit : nombres, booléens et null lus en texte,
    /// clé répétée, texte après l'objet, blancs de Kotlin dans les traductions, hébreu vocalisé.
    @Test func lesDocumentsSontLusCommeSurAndroid() throws {
        let documents = try vecteurs().documents
        #expect(documents.count > 20)
        for doc in documents {
            let lu = try? TehilimLoader.parse(doc.json)
            let accepte = lu != nil
            #expect(accepte == doc.lu, "\(doc.nom) : lu")
            guard let lu, doc.lu else { continue }
            let attendus = doc.psaumes ?? []
            var memes = lu.psaumes.count == attendus.count
            for (a, b) in zip(lu.psaumes, attendus) where !TehilimTests.memesTextes(a, b) {
                memes = false
            }
            let tousMemes = memes
            #expect(tousMemes, "\(doc.nom) : psaumes")
            let total = lu.versetsTotal, totalAttendu = doc.versetsTotal ?? -1
            #expect(total == totalAttendu, "\(doc.nom) : versetsTotal")
            let langues = lu.langues, languesAttendues = doc.langues ?? []
            #expect(langues == languesAttendues, "\(doc.nom) : langues")
            var nombres: [Int] = []
            for numero in 0...(lu.psaumes.count + 1) {
                nombres.append(lu.versets(numero).count)
            }
            let nombresAttendus = doc.nombres ?? []
            #expect(nombres == nombresAttendus, "\(doc.nom) : nombres")
            for t in doc.traduit ?? [] {
                for (numero, ligne) in t.resultats.enumerated() {
                    for (verset, attendu) in ligne.enumerated() {
                        let texte = lu.traduction(t.langue, numero, verset)
                        let meme = TehilimTests.memeTexte(texte, attendu)
                        #expect(meme, "\(doc.nom) : traduction(« \(t.langue) », \(numero), \(verset)) : \(TehilimTests.ecrit(texte)), Android \(TehilimTests.ecrit(attendu))")
                    }
                }
            }
        }
    }

    @Test func lesPortionsSontCellesDAndroid() throws {
        let v = try vecteurs()
        // Une ligne illisible manquerait au compte : les deux tables se comparent en entier.
        let mois = v.mois.compactMap { TehilimTests.portion($0) }, tableMois = CycleTehilim.mois
        #expect(mois == tableMois)
        let semaine = v.semaine.compactMap { TehilimTests.portion($0) }, tableSemaine = CycleTehilim.semaine
        #expect(semaine == tableSemaine)

        #expect(v.portions.count > 40)
        for c in v.portions {
            let p = try #require(TehilimTests.portion(c.portion))
            let partielle = p.partielle
            #expect(partielle == c.partielle, "\(p) : partielle")
            let psaumes = TehilimTests.intervalle(p.psaumes)
            #expect(psaumes == c.psaumes, "\(p) : psaumes")
            for ligne in c.versets where ligne.count == 5 {
                let versets = TehilimTests.intervalle(p.versets(ligne[0], ligne[1]))
                let attendus = [ligne[2], ligne[3], ligne[4]]
                #expect(versets == attendus, "\(p) : versets(\(ligne[0]), \(ligne[1]))")
            }
        }
        for c in v.duMois {
            let calcule = CycleTehilim.duMois(c.jour, c.longueur)
            let attendu = try #require(TehilimTests.portion(c.portion))
            #expect(calcule == attendu, "duMois(\(c.jour), \(c.longueur))")
        }
        for c in v.deLaSemaine {
            let calcule = CycleTehilim.deLaSemaine(c.jourDeSemaine)
            let attendu = try #require(TehilimTests.portion(c.portion))
            #expect(calcule == attendu, "deLaSemaine(\(c.jour))")
        }
    }

    /// L'année 5787 jour après jour, et les 1er, 29 et 30 de chaque mois hébreu de 2025 à 2030 : le
    /// jour du mois et la longueur du mois que rend KosherJava, puis les portions du jour.
    @Test func leJourHebreuEstCeluiDeKosherJava() throws {
        let v = try vecteurs()
        #expect(v.dates.count > 400)
        for c in v.dates {
            let date = JourCivil.du(c.d)
            let semaine = date.jourDeSemaine
            #expect(semaine == c.s, "\(c.d) : jour de la semaine")
            let hebreu = CycleTehilim.jourHebreu(date)
            #expect(hebreu.jour == c.j, "\(c.d) : jour hébreu")
            #expect(hebreu.longueur == c.l, "\(c.d) : longueur du mois")
            let duMois = CycleTehilim.duMois(hebreu.jour, hebreu.longueur)
            let attenduMois = try #require(TehilimTests.portion(c.m))
            #expect(duMois == attenduMois, "\(c.d) : portion du mois")
            let deLaSemaine = CycleTehilim.deLaSemaine(semaine)
            let attenduSemaine = try #require(TehilimTests.portion(c.h))
            #expect(deLaSemaine == attenduSemaine, "\(c.d) : portion de la semaine")
        }
        #expect(v.bornesDeMois.count > 100)
        for c in v.bornesDeMois {
            let hebreu = CycleTehilim.jourHebreu(.du(c.d))
            #expect(hebreu.jour == c.j, "\(c.d) : jour hébreu")
            #expect(hebreu.longueur == c.l, "\(c.d) : longueur du mois")
        }
    }
}
