import Foundation
import Testing
@testable import Coeur

/// MarquesPagesTest d'Android, porté avec les mêmes cas. Puis tout `Tests/Vecteurs/texte.json` pour les
/// marque-pages, écrit par la JVM (tools/vecteurs_ios/VecteursTexte.kt) : aperçus (cas construits et
/// paragraphes du siddour), écriture et lecture du texte enregistré, lignes abîmées comprises, bascule
/// jusqu'au-delà de la limite, tri des marques d'un texte. Rien ne reste à Android.
@Suite("Marque-pages")
struct MarquesPagesTests {

    private typealias Marque = MarquesPages.Marque

    private let a = Marque(cle: "s:chaharit", nusah: "edot", section: 3, bloc: 12, apercu: "ברוך שאמר")
    private let b = Marque(cle: "s:chaharit", nusah: "edot", section: 1, bloc: 4, apercu: "הודו ליהוה")

    /// `copy(…)` de la data class de Kotlin.
    private func copie(_ m: Marque, nusah: String? = nil, bloc: Int? = nil, apercu: String? = nil) -> Marque {
        Marque(cle: m.cle, nusah: nusah ?? m.nusah, section: m.section, bloc: bloc ?? m.bloc, apercu: apercu ?? m.apercu)
    }

    @Test func poserPuisRetirerLaMemePlace() {
        let une = MarquesPages.basculer([], a)
        #expect(une == [a])
        let aucune = MarquesPages.basculer(une, copie(a, apercu: "autre"))
        #expect(aucune.isEmpty)
    }

    @Test func allerRetourParLeTexteEnregistre() {
        let l = [a, b, Marque(cle: "l:likoutei_etsot", nusah: "", section: 0, bloc: 0, apercu: "אמת")]
        let relues = MarquesPages.decoder(MarquesPages.encoder(l))
        #expect(relues == l)
        let rien = MarquesPages.decoder(nil)
        #expect(rien.isEmpty)
    }

    @Test func cellesDuTexteDansLOrdreDuTexteEtPasDUnAutreNoussah() {
        let l = [a, b, copie(a, nusah: "sefard")]
        let duTexte = MarquesPages.duTexte(l, cle: "s:chaharit", nusah: "edot")
        #expect(duTexte == [b, a])
    }

    @Test func apercuSansVoyellesNiBalises() {
        let apercu = MarquesPages.apercu("<b>בָּרוּךְ</b> שֶׁאָמַר וְהָיָה הָעוֹלָם", mots: 4)
        let egal = apercu.egalUnites("ברוך שאמר והיה העולם")
        #expect(egal, "« \(apercu) »")
    }

    @Test func laListeNeGrossitPasSansFin() throws {
        var l: [Marque] = []
        for i in 0..<(MarquesPages.max + 5) {
            l = MarquesPages.basculer(l, copie(a, bloc: i))
        }
        let taille = l.count
        #expect(taille == MarquesPages.max)
        let premiere = try #require(l.first)
        let bloc = premiere.bloc
        #expect(bloc == MarquesPages.max + 4)
    }

    // MARK: Les vecteurs de la JVM

    private struct Vecteurs: Decodable {
        struct Constantes: Decodable {
            let max: Int
        }
        struct M: Decodable {
            let cle: String
            let nusah: String
            let section: Int
            let bloc: Int
            let apercu: String

            var marque: MarquesPages.Marque {
                MarquesPages.Marque(cle: cle, nusah: nusah, section: section, bloc: bloc, apercu: apercu)
            }
        }
        struct Apercu: Decodable {
            let texte: String
            let mots: Int
            let apercu: String
        }
        /// Un paragraphe du siddour Edot HaMizra'h, par son rang parmi ceux du fichier.
        struct ApercuDuSiddur: Decodable {
            let rang: Int
            let mots: Int
            let apercu: String
        }
        struct ApercuParDefaut: Decodable {
            let texte: String
            let apercu: String
        }
        struct Encodage: Decodable {
            let marques: [M]
            let texte: String
            let relues: [M]
        }
        struct Decodage: Decodable {
            let texte: String?
            let marques: [M]
        }
        /// Une bascule : la marque, puis la liste qui en sort (taille, `hashCode` de son texte, première marque).
        struct Etape: Decodable {
            let marque: M
            let taille: Int
            let empreinte: Int32
            let premiere: M?
        }
        struct Bascules: Decodable {
            let etapes: [Etape]
            let finale: [M]
        }
        struct Requete: Decodable {
            let cle: String
            let nusah: String
            let resultat: [M]
        }
        struct DuTexte: Decodable {
            let liste: [M]
            let requetes: [Requete]
        }

        let constantes: Constantes
        let apercus: [Apercu]
        let apercusDuSiddur: [ApercuDuSiddur]
        let apercusParDefaut: [ApercuParDefaut]
        let encodages: [Encodage]
        let decodages: [Decodage]
        let bascules: Bascules
        let duTexte: [DuTexte]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/texte.json"))
    }

    private func marques(_ l: [Vecteurs.M]) -> [Marque] {
        l.map { $0.marque }
    }

    /// Les blocs du siddour, tels que VecteursTexte les lit.
    private struct Livre: Decodable {
        struct Bloc: Decodable {
            let t: String?
        }
        struct Section: Decodable {
            let blocs: [Bloc]
        }
        struct Texte: Decodable {
            let sections: [Section]
        }
        let textes: [Texte]
    }

    private func paragraphesDuSiddur() throws -> [String] {
        let livre = try JSONDecoder().decode(Livre.self, from: Depot.contenu("siddur_edot.json"))
        var sortie: [String] = []
        for texte in livre.textes {
            for section in texte.sections {
                for bloc in section.blocs {
                    if let t = bloc.t { sortie.append(t) }
                }
            }
        }
        return sortie
    }

    @Test func laLimiteEstCelleDAndroid() throws {
        let max = try vecteurs().constantes.max
        #expect(MarquesPages.max == max)
    }

    @Test func chaqueApercuEstCeluiDAndroid() throws {
        let v = try vecteurs()
        for c in v.apercus {
            let obtenu = MarquesPages.apercu(c.texte, mots: c.mots)
            let egal = obtenu.egalUnites(c.apercu)
            #expect(egal, "« \(c.texte) », \(c.mots) mots : « \(obtenu) » au lieu de « \(c.apercu) »")
        }
        for c in v.apercusParDefaut {
            let obtenu = MarquesPages.apercu(c.texte)
            let egal = obtenu.egalUnites(c.apercu)
            #expect(egal, "« \(obtenu) » au lieu de « \(c.apercu) »")
        }
        let siddur = try paragraphesDuSiddur()
        let nombre = v.apercusDuSiddur.count
        #expect(nombre > 50)
        for c in v.apercusDuSiddur {
            let present = c.rang < siddur.count
            #expect(present, "paragraphe \(c.rang) absent du siddour")
            if !present { continue }
            let obtenu = MarquesPages.apercu(siddur[c.rang], mots: c.mots)
            let egal = obtenu.egalUnites(c.apercu)
            #expect(egal, "paragraphe \(c.rang) : « \(obtenu) » au lieu de « \(c.apercu) »")
        }
    }

    @Test func leTexteEnregistreSEcritEtSeRelitCommeSurAndroid() throws {
        let v = try vecteurs()
        for c in v.encodages {
            let texte = MarquesPages.encoder(marques(c.marques))
            let egal = texte.egalUnites(c.texte)
            #expect(egal, "« \(texte) » au lieu de « \(c.texte) »")
            let relues = MarquesPages.decoder(c.texte)
            let attendues = marques(c.relues)
            #expect(relues == attendues, "relecture de « \(c.texte) »")
        }
        let nombre = v.decodages.count
        #expect(nombre > 40)
        for c in v.decodages {
            let lues = MarquesPages.decoder(c.texte)
            let attendues = marques(c.marques)
            let nom = c.texte ?? "null"
            #expect(lues == attendues, "lecture de « \(nom) »")
        }
    }

    @Test func laBasculeSuitAndroidAuDelaDeLaLimite() throws {
        let v = try vecteurs()
        var l: [Marque] = []
        for (i, e) in v.bascules.etapes.enumerated() {
            l = MarquesPages.basculer(l, e.marque.marque)
            let taille = l.count
            #expect(taille == e.taille, "étape \(i) : taille")
            let empreinte = Kotlin.hashCode(MarquesPages.encoder(l))
            #expect(empreinte == e.empreinte, "étape \(i) : texte enregistré")
            let premiere = l.first
            let attendue = e.premiere?.marque
            #expect(premiere == attendue, "étape \(i) : première marque")
        }
        let finale = marques(v.bascules.finale)
        #expect(l == finale)
    }

    @Test func lesMarquesDUnTexteSeTrientCommeSurAndroid() throws {
        let v = try vecteurs()
        for bloc in v.duTexte {
            let liste = marques(bloc.liste)
            for r in bloc.requetes {
                let obtenues = MarquesPages.duTexte(liste, cle: r.cle, nusah: r.nusah)
                let attendues = marques(r.resultat)
                #expect(obtenues == attendues, "« \(r.cle) », « \(r.nusah) »")
            }
        }
    }
}
