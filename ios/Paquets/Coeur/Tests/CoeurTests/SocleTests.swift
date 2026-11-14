import Foundation
import Testing
@testable import Coeur

/// Le socle devant la JVM : `Tests/Vecteurs/socle.json` est écrit par le code Java et Kotlin lui-même
/// (tools/vecteurs_ios/VecteursSocle.kt) ; chaque fonction de `Sources/Coeur/Socle` doit rendre la même chose.
@Suite("Socle")
struct SocleTests {

    // MARK: Le fichier de vecteurs

    private struct Vecteurs: Decodable {
        struct Chaine: Decodable {
            let unites: [UInt16]
            let hash: Int32
            let longueur: Int
            let blanc: Bool
            let rogne: [UInt16]
            let minuscules: [UInt16]
            let majuscules: [UInt16]
            let prend2: [UInt16]
            let retire2: [UInt16]
            let dernier2: [UInt16]
        }
        struct Recherche: Decodable {
            let s: [UInt16]
            let a: [UInt16]
            let b: [UInt16]
            let contientA: Bool
            let commenceA: Bool
            let finitB: Bool
            let indiceA: Int
            let dernierIndiceB: Int
            let egalA: Bool
            let remplaceAParB: [UInt16]
            let avantB: [UInt16]
            let apresA: [UInt16]
        }
        struct Hasard: Decodable {
            let graine: Int32
            let entiers: [Int32]
            let bornes: [Int32]
            let intervalles: [Int32]
            let longs: [String]
            let flottants: [Double]
            let doubles: [Double]
            let booleens: [Bool]
            let melange: [Int]
            let melangeCourt: [String]
            let tirage: [String]
        }
        struct HasardLong: Decodable {
            let graine: String
            let entiers: [Int32]
        }
        struct Modulo: Decodable {
            let a: Int
            let b: Int
            let reste: Int
            let quotient: Int
            let floorMod: Int
            let floorDiv: Int
            let mod: Int
        }
        struct Arrondi: Decodable {
            let x: Double
            let roundToInt: Int
            let roundToLong: String
            let mathRound: String
            let mathRoundFloat: Int
            let rint: Double
            let versInt: Int
            let versLong: String
            let f0: String
            let f1: String
            let f2: String
            let texte: String
        }
        struct ArrondiFlottant: Decodable {
            let a: Int
            let b: Int
            let arrondi: Int
            let quotient: Double
        }
        struct Format: Decodable {
            let m: Int
            let hhmm: String
            let hmm: String
        }
        struct NombreLu: Decodable {
            let texte: String
            let lu: Bool
            let valeur: String?
            let versInt: Int?
            let versLong: String?
        }
        struct NombreEcrit: Decodable {
            let bits: String
            let texte: String
            let json: String?
        }
        struct Trouvee: Decodable {
            let valeur: String
            let debut: Int
            let fin: Int
            let groupes: [String]
            let plages: [[Int]?]
        }
        struct TexteCherche: Decodable {
            let texte: String
            let premiere: Trouvee?
            let depuis2: Trouvee?
            let toutes: [Trouvee]
            let presente: Bool
            let entiere: Bool
            let sans: String
            let gabarit: String?
            let crochets: String
            let morceaux: [String]
        }
        struct Expression: Decodable {
            let motif: String
            let options: [String]
            let gabarit: String?
            let textes: [TexteCherche]
        }
        struct Lectures: Decodable {
            let cle: String?
            let present: Bool
            let nul: Bool
            let optInt: Int
            let optLong: String
            let optDouble: String
            let optBooleanFaux: Bool
            let optBooleanVrai: Bool
            let optString: String
            let objet: Bool
            let tableau: Bool
        }
        struct Tableau: Decodable {
            let cle: String
            let elements: [Lectures]
        }
        struct Lecture: Decodable {
            let texte: String
            let strict: Bool
            let ios: Bool
            let android: Bool
            let cles: [String]?
            let valeurs: [Lectures]?
            let tableaux: [Tableau]?
            let compact: String?
            let indente: String?
        }
        struct Ecrit: Decodable {
            let nom: String
            let compact: String
            let indente2: String
            let indente4: String
        }

        let chaines: [Chaine]
        let recherches: [Recherche]
        let hasard: [Hasard]
        let hasardLong: [HasardLong]
        let modulo: [Modulo]
        let arrondis: [Arrondi]
        let arrondisFlottants: [ArrondiFlottant]
        let formats: [Format]
        let nombresLus: [NombreLu]
        let nombresEcrits: [NombreEcrit]
        let expressions: [Expression]
        let json: [Lecture]
        let jsonEcrit: [Ecrit]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/socle.json"))
    }

    /// Les unités d'une chaîne de Kotlin, sans les moitiés de paire restées seules : Swift ne les porte pas.
    private func saines(_ unites: [UInt16]) -> [UInt16] {
        Array(Unites.texte(unites).utf16)
    }

    private func texte(_ unites: [UInt16]) -> String {
        String(decoding: unites, as: UTF16.self)
    }

    /// Le nombre tel que les vecteurs l'écrivent : « NaN », ou `Double.toString` de Java.
    private func ecrit(_ d: Double) -> String {
        d.isNaN ? "NaN" : Java.texte(d)
    }

    // MARK: Chaînes

    @Test func chainesEnUnitesUTF16() throws {
        for c in try vecteurs().chaines {
            let s = texte(c.unites)
            let ou = "« \(s) »"
            let hash = Kotlin.hashCode(s)
            #expect(hash == c.hash, "\(ou) : hashCode")
            let longueur = s.utf16.count
            #expect(longueur == c.longueur, "\(ou) : length")
            let blanc = s.estBlanc
            #expect(blanc == c.blanc, "\(ou) : isBlank")
            let rogne = Array(s.rogne.utf16)
            #expect(rogne == c.rogne, "\(ou) : trim")
            let minuscules = Array(s.lowercased().utf16)
            #expect(minuscules == c.minuscules, "\(ou) : lowercase")
            let majuscules = Array(s.uppercased().utf16)
            #expect(majuscules == c.majuscules, "\(ou) : uppercase")
            let prend = Array(s.premieresUnites(2).utf16)
            let prendAttendu = saines(c.prend2)
            #expect(prend == prendAttendu, "\(ou) : take(2)")
            let retire = Array(s.sansPremieresUnites(2).utf16)
            let retireAttendu = saines(c.retire2)
            #expect(retire == retireAttendu, "\(ou) : drop(2)")
            let dernier = Array(s.dernieresUnites(2).utf16)
            let dernierAttendu = saines(c.dernier2)
            #expect(dernier == dernierAttendu, "\(ou) : takeLast(2)")
        }
    }

    @Test func recherchesUniteParUnite() throws {
        for r in try vecteurs().recherches {
            let s = texte(r.s), a = texte(r.a), b = texte(r.b)
            let ou = "« \(s) », « \(a) », « \(b) »"
            let contient = s.contientUnites(a)
            #expect(contient == r.contientA, "\(ou) : contains")
            let commence = s.commenceParUnites(a)
            #expect(commence == r.commenceA, "\(ou) : startsWith")
            let finit = s.finitParUnites(b)
            #expect(finit == r.finitB, "\(ou) : endsWith")
            let indice = s.positionUnites(de: a) ?? -1
            #expect(indice == r.indiceA, "\(ou) : indexOf")
            let dernier = s.dernierePositionUnites(de: b) ?? -1
            #expect(dernier == r.dernierIndiceB, "\(ou) : lastIndexOf")
            let egal = s.egalUnites(a)
            #expect(egal == r.egalA, "\(ou) : ==")
            let remplace = Array(s.remplacantUnites(a, par: b).utf16)
            #expect(remplace == r.remplaceAParB, "\(ou) : replace")
            let avant = Array(s.avantUnites(b).utf16)
            #expect(avant == r.avantB, "\(ou) : substringBefore")
            let apres = Array(s.apresUnites(a).utf16)
            #expect(apres == r.apresA, "\(ou) : substringAfter")
        }
    }

    /// Ce que ces fonctions évitent : pour Swift, une lettre et ses signes ne font qu'un caractère.
    @Test func swiftCompareDesCaracteresEntiers() {
        let mot = "מָה"
        let natif = mot.contains("מ")
        #expect(!natif, "Swift ne trouve pas le mem sous son qamats")
        let unites = mot.contientUnites("מ")
        #expect(unites)
        let accents = "e\u{301}" == "\u{E9}"
        #expect(accents, "Swift tient « e » et son accent pour « é »")
        let memesUnites = "e\u{301}".egalUnites("\u{E9}")
        #expect(!memesUnites)
    }

    // MARK: Hasard

    @Test func hasardDeKotlin() throws {
        for h in try vecteurs().hasard {
            var r = HasardKotlin(graine: h.graine)
            let ou = "graine \(h.graine)"
            var entiers: [Int32] = []
            for _ in 0..<6 { entiers.append(r.nextInt()) }
            #expect(entiers == h.entiers, "\(ou) : nextInt()")
            var bornes: [Int32] = []
            for borne in [1, 2, 3, 4, 10, 100, 1000, 65536, 1_000_000] as [Int32] { bornes.append(r.nextInt(jusqua: borne)) }
            #expect(bornes == h.bornes, "\(ou) : nextInt(until)")
            var intervalles: [Int32] = []
            for (debut, fin) in [(0, 10), (-5, 5), (100, 101), (3, 1000)] as [(Int32, Int32)] {
                intervalles.append(r.nextInt(de: debut, jusqua: fin))
            }
            #expect(intervalles == h.intervalles, "\(ou) : nextInt(from, until)")
            var longs: [String] = []
            for _ in 0..<3 { longs.append(String(r.nextLong())) }
            #expect(longs == h.longs, "\(ou) : nextLong()")
            var flottants: [Double] = []
            for _ in 0..<4 { flottants.append(Double(r.nextFloat())) }
            #expect(flottants == h.flottants, "\(ou) : nextFloat()")
            var doubles: [Double] = []
            for _ in 0..<4 { doubles.append(r.nextDouble()) }
            #expect(doubles == h.doubles, "\(ou) : nextDouble()")
            var booleens: [Bool] = []
            for _ in 0..<8 { booleens.append(r.nextBoolean()) }
            #expect(booleens == h.booleens, "\(ou) : nextBoolean()")
            var neuf = HasardKotlin(graine: h.graine)
            let melange = neuf.melange(Array(0..<12))
            #expect(melange == h.melange, "\(ou) : shuffled")
            var court = HasardKotlin(graine: h.graine)
            let melangeCourt = court.melange(["a", "b", "c"])
            #expect(melangeCourt == h.melangeCourt, "\(ou) : shuffled, trois éléments")
            var tirage: [String] = []
            for _ in 0..<5 { tirage.append(r.tirage(["a", "b", "c", "d", "e"])) }
            #expect(tirage == h.tirage, "\(ou) : random")
        }
    }

    @Test func hasardDeKotlinAGraineLongue() throws {
        for h in try vecteurs().hasardLong {
            let graine = try #require(Int64(h.graine))
            var r = HasardKotlin(graineLongue: graine)
            var entiers: [Int32] = []
            for _ in 0..<4 { entiers.append(r.nextInt()) }
            #expect(entiers == h.entiers, "graine \(h.graine)")
        }
    }

    // MARK: Nombres

    @Test func moduloEtDivision() throws {
        for m in try vecteurs().modulo {
            let ou = "\(m.a) et \(m.b)"
            let reste = m.a % m.b
            #expect(reste == m.reste, "\(ou) : %")
            let quotient = m.a / m.b
            #expect(quotient == m.quotient, "\(ou) : /")
            let floorMod = Kotlin.floorMod(m.a, m.b)
            #expect(floorMod == m.floorMod, "\(ou) : floorMod")
            #expect(floorMod == m.mod, "\(ou) : mod")
            let floorDiv = Kotlin.floorDiv(m.a, m.b)
            #expect(floorDiv == m.floorDiv, "\(ou) : floorDiv")
        }
    }

    @Test func arrondisDeKotlinEtDeJava() throws {
        for a in try vecteurs().arrondis {
            // Le fichier écrit le zéro négatif « -0.0 » ; on s'en assure par son texte.
            let x = a.texte == "-0.0" ? -0.0 : a.x
            let ou = "x = \(a.texte)"
            let arrondi = Kotlin.arrondi(x)
            #expect(arrondi == a.roundToInt, "\(ou) : roundToInt")
            let long = String(Kotlin.arrondiLong(x))
            #expect(long == a.roundToLong, "\(ou) : roundToLong")
            #expect(long == a.mathRound, "\(ou) : Math.round")
            let flottant = Kotlin.arrondiFlottant(Float(x))
            #expect(flottant == a.mathRoundFloat, "\(ou) : Math.round(float)")
            let pair = x.rounded(.toNearestOrEven)
            #expect(pair == a.rint, "\(ou) : Math.rint")
            let versInt = Kotlin.versInt(x)
            #expect(versInt == a.versInt, "\(ou) : toInt")
            let versLong = String(Kotlin.versLong(x))
            #expect(versLong == a.versLong, "\(ou) : toLong")
            let f0 = Java.format(x, decimales: 0)
            #expect(f0 == a.f0, "\(ou) : %.0f")
            let f1 = Java.format(x, decimales: 1)
            #expect(f1 == a.f1, "\(ou) : %.1f")
            let f2 = Java.format(x, decimales: 2)
            #expect(f2 == a.f2, "\(ou) : %.2f")
            let ecritJava = Java.texte(x)
            #expect(ecritJava == a.texte, "\(ou) : Double.toString")
        }
    }

    @Test func arrondisEnSimplePrecision() throws {
        for a in try vecteurs().arrondisFlottants {
            let quotient = Float(a.a) / Float(a.b)
            let arrondi = Kotlin.arrondiFlottant(quotient)
            #expect(arrondi == a.arrondi, "\(a.a) / \(a.b)")
            let enDouble = Double(quotient)
            #expect(enDouble == a.quotient, "\(a.a) / \(a.b) : le quotient")
        }
    }

    /// `String(format:)` rend les heures comme `String.format` de Java, sous Linux comme sur iOS.
    @Test func heuresEtMinutes() throws {
        for f in try vecteurs().formats {
            let hhmm = String(format: "%02d:%02d", (f.m / 60) % 24, f.m % 60)
            #expect(hhmm == f.hhmm)
            let hmm = String(format: "%d:%02d", f.m / 60, f.m % 60)
            #expect(hmm == f.hmm)
        }
    }

    @Test func nombresLusCommeJava() throws {
        for n in try vecteurs().nombresLus {
            let lu = Java.parseDouble(n.texte)
            let ou = "« \(n.texte) »"
            let accepte = lu != nil
            #expect(accepte == n.lu, "\(ou) : Double.parseDouble")
            guard let d = lu, let valeur = n.valeur, let versInt = n.versInt, let versLong = n.versLong else { continue }
            let texteLu = ecrit(d)
            #expect(texteLu == valeur, "\(ou) : la valeur")
            let entier = Kotlin.versInt(d)
            #expect(entier == versInt, "\(ou) : toInt")
            let long = String(Kotlin.versLong(d))
            #expect(long == versLong, "\(ou) : toLong")
        }
    }

    @Test func nombresEcritsCommeJava() throws {
        for n in try vecteurs().nombresEcrits {
            let bits = try #require(Int64(n.bits))
            let d = Double(bitPattern: UInt64(bitPattern: bits))
            let texteJava = Java.texte(d)
            #expect(texteJava == n.texte, "Double.toString")
            let attendu = try #require(n.json, "\(n.texte) : Android refuse de l'écrire")
            let texteJSON = JSON.decimal(d).texte()
            #expect(texteJSON == attendu, "\(n.texte) : numberToString")
        }
    }

    // MARK: Expressions régulières

    private func memeCorrespondance(_ obtenue: ExpressionReguliere.Correspondance?, _ attendue: Vecteurs.Trouvee?,
                                    _ ou: String) {
        guard let attendue else {
            let rien = obtenue == nil
            #expect(rien, "\(ou) : aucune correspondance attendue")
            return
        }
        guard let obtenue else {
            Issue.record("\(ou) : correspondance « \(attendue.valeur) » attendue")
            return
        }
        #expect(obtenue.valeur == attendue.valeur, "\(ou) : value")
        let plage = attendue.debut..<attendue.fin
        #expect(obtenue.plage == plage, "\(ou) : range")
        #expect(obtenue.groupes == attendue.groupes, "\(ou) : groupValues")
        let plages = attendue.plages.map { bornes in bornes.map { $0[0]..<$0[1] } }
        #expect(obtenue.plages == plages, "\(ou) : groups")
    }

    @Test func expressionsCommeKotlin() throws {
        for e in try vecteurs().expressions {
            var options: ExpressionReguliere.Options = []
            if e.options.contains("IGNORE_CASE") { options.insert(.sansCasse) }
            if e.options.contains("MULTILINE") { options.insert(.multiligne) }
            if e.options.contains("DOT_MATCHES_ALL") { options.insert(.pointPartout) }
            let expression = ExpressionReguliere(e.motif, options)
            for t in e.textes {
                let ou = "« \(e.motif) » sur « \(t.texte) »"
                memeCorrespondance(expression.trouve(t.texte), t.premiere, "\(ou), find")
                if t.texte.utf16.count >= 2 {
                    memeCorrespondance(expression.trouve(t.texte, depuis: 2), t.depuis2, "\(ou), find(2)")
                }
                let toutes = expression.toutes(t.texte)
                let nombre = toutes.count
                #expect(nombre == t.toutes.count, "\(ou) : findAll")
                for (obtenue, attendue) in zip(toutes, t.toutes) {
                    memeCorrespondance(obtenue, attendue, "\(ou), findAll")
                }
                let presente = expression.presente(dans: t.texte)
                #expect(presente == t.presente, "\(ou) : containsMatchIn")
                let couvre = expression.couvre(t.texte)
                #expect(couvre == t.entiere, "\(ou) : matches")
                let sans = expression.remplace(t.texte, par: "")
                #expect(sans == t.sans, "\(ou) : replace par rien")
                if let gabarit = e.gabarit, let attendu = t.gabarit {
                    let rendu = expression.remplace(t.texte, gabarit: gabarit)
                    #expect(rendu == attendu, "\(ou) : replace par « \(gabarit) »")
                }
                let crochets = expression.remplace(t.texte) { "[" + $0.valeur + "]" }
                #expect(crochets == t.crochets, "\(ou) : replace par une fonction")
                let morceaux = expression.decoupe(t.texte)
                #expect(morceaux == t.morceaux, "\(ou) : split")
            }
        }
    }

    // MARK: JSON

    private func memesLectures(_ a: Vecteurs.Lectures, _ ou: String, present: Bool, nul: Bool, entier: Int, long: Int64,
                               double: Double, faux: Bool, vrai: Bool, texte: String, objet: Bool, tableau: Bool) {
        #expect(present == a.present, "\(ou) : has")
        #expect(nul == a.nul, "\(ou) : isNull")
        #expect(entier == a.optInt, "\(ou) : optInt")
        let texteLong = String(long)
        #expect(texteLong == a.optLong, "\(ou) : optLong")
        let texteDouble = ecrit(double)
        #expect(texteDouble == a.optDouble, "\(ou) : optDouble")
        #expect(faux == a.optBooleanFaux, "\(ou) : optBoolean, défaut faux")
        #expect(vrai == a.optBooleanVrai, "\(ou) : optBoolean, défaut vrai")
        #expect(texte == a.optString, "\(ou) : optString")
        #expect(objet == a.objet, "\(ou) : optJSONObject")
        #expect(tableau == a.tableau, "\(ou) : optJSONArray")
    }

    @Test func lectureDuJSONCommeAndroid() throws {
        for cas in try vecteurs().json {
            let ou = "« \(cas.texte) »"
            let lu = try? ObjetJSON(texte: cas.texte)
            let accepte = lu != nil
            #expect(accepte == cas.ios, "\(ou) : accepté ou refusé")
            if cas.ios {
                #expect(cas.android, "\(ou) : iOS n'accepte rien qu'Android refuse")
            }
            guard let o = lu, let cles = cas.cles, let valeurs = cas.valeurs, let tableaux = cas.tableaux,
                  let compact = cas.compact, let indente = cas.indente else { continue }
            #expect(o.cles == cles, "\(ou) : l'ordre des clés")
            for a in valeurs {
                let cle = try #require(a.cle)
                memesLectures(a, "\(ou), clé « \(cle) »", present: o.a(cle), nul: o.estNul(cle),
                              entier: o.entier(cle, defaut: -1), long: o.long(cle, defaut: -1), double: o.double(cle),
                              faux: o.booleen(cle, defaut: false), vrai: o.booleen(cle, defaut: true),
                              texte: o.texte(cle, defaut: "∅"), objet: o.objet(cle) != nil, tableau: o.tableau(cle) != nil)
            }
            for t in tableaux {
                let elements = try #require(o.tableau(t.cle))
                for (rang, a) in t.elements.enumerated() {
                    memesLectures(a, "\(ou), « \(t.cle) »[\(rang)]", present: rang < elements.count, nul: elements.estNul(rang),
                                  entier: elements.entier(rang, defaut: -1), long: elements.long(rang, defaut: -1),
                                  double: elements.double(rang), faux: elements.booleen(rang, defaut: false),
                                  vrai: elements.booleen(rang, defaut: true), texte: elements.texte(rang, defaut: "∅"),
                                  objet: elements.objet(rang) != nil, tableau: elements.tableau(rang) != nil)
                }
            }
            let ecritCompact = o.texte()
            #expect(ecritCompact == compact, "\(ou) : toString()")
            let ecritIndente = o.texte(indentation: 2)
            #expect(ecritIndente == indente, "\(ou) : toString(2)")
        }
    }

    @Test func ecritureDuJSONCommeAndroid() throws {
        for e in try vecteurs().jsonEcrit {
            let o: ObjetJSON
            if e.nom == "nombres" {
                // Bâti ici comme dans le générateur : relu de son texte, « 20 » ne serait plus le décimal 20,0.
                o = ObjetJSON([
                    ("entier", .entier(20)), ("zero", .entier(0)), ("negatif", .entier(-5)), ("long", .entier(3_000_000_000)),
                    ("rond", .decimal(20.0)), ("demi", .decimal(0.5)), ("moinsZero", .decimal(-0.0)), ("grand", .decimal(1e21)),
                    ("petit", .decimal(1e-7)), ("tiers", .decimal(1.0 / 3)), ("flottant", .decimal(1.5)),
                    ("vrai", .booleen(true)), ("faux", .booleen(false)), ("nul", .nul),
                ])
            } else {
                o = try ObjetJSON(texte: e.compact)
            }
            let compact = o.texte()
            #expect(compact == e.compact, "\(e.nom) : toString()")
            let indente2 = o.texte(indentation: 2)
            #expect(indente2 == e.indente2, "\(e.nom) : toString(2)")
            let indente4 = o.texte(indentation: 4)
            #expect(indente4 == e.indente4, "\(e.nom) : toString(4)")
        }
    }

    @Test func objetJSONGardeLOrdreDEcriture() throws {
        var o = ObjetJSON()
        o["format"] = .chaine("myhitbodedut")
        o["version"] = .entier(1)
        o["days"] = .objet(ObjetJSON())
        o["version"] = .entier(2)
        #expect(o.cles == ["format", "version", "days"])
        let version = o.entier("version")
        #expect(version == 2)
        o["format"] = nil
        #expect(o.cles == ["version", "days"])
        let absent = o.a("format")
        #expect(!absent)
        let relu = try ObjetJSON(texte: o.texte(indentation: 2))
        #expect(relu == o)
    }

    @Test func lectureStricteDUneValeur() throws {
        let valeur = try JSON.lire(" [1, 2.5, \"x\", null, true] ")
        #expect(valeur == JSON.tableau([.entier(1), .decimal(2.5), .chaine("x"), .nul, .booleen(true)]))
        #expect(throws: ErreurJSON.self) { try JSON.lire("[1] suite") }
        #expect(throws: ErreurJSON.self) { try JSON.lire("") }
        // Un fichier fait d'un million de crochets ouvrants est refusé, sans faire déborder la pile.
        let profond = String(repeating: "[", count: 1_000_000)
        #expect(throws: ErreurJSON.self) { try JSON.lire(profond) }
    }
}
