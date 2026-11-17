import Foundation
import Testing
@testable import Coeur

/// Celebrations (Confettis.kt) n'a pas de test d'Android : la règle se juge ici sur quelques cas qui la
/// disent, sur les clés de ses libellés (relevées dans PaliersActivity.kt et résolues sur le catalogue
/// exporté), puis sur tout `Tests/Vecteurs/celebrations.json`, écrit par la JVM
/// (tools/vecteurs_ios/VecteursCelebrations.kt). Restent à Android les confettis, la fiche du trophée,
/// les étincelles de l'accueil et l'envoi de la notification.
@Suite("Celebrations")
struct CelebrationsTests {

    /// Un mercredi, 3 'Hechvan 5787 : dix minutes aujourd'hui, la série à un jour.
    private func premierJour() -> (Paliers.Bilan, Trophees.Pratique) {
        let aujourdhui = JourCivil.du("2026-10-14")
        let minutes: [JourCivil: Int] = [aujourdhui: 10]
        let bilan = Paliers.Bilan(aujourdhui: aujourdhui, minutes: minutes, serie: 1,
                                  debutMoisHebreu: JourCivil.du("2026-10-12"), objectifJour: 15)
        return (bilan, Trophees.Pratique(minutes: minutes, notes: 0, meilleureSerie: 1))
    }

    @Test func lePremierPassageNeFeteRien() {
        let (bilan, pratique) = premierJour()
        let r = Celebrations.neuf(bilan, pratique, paliersVus: nil, tropheesVus: nil)
        let icone = r.icone
        #expect(icone == "")
        let message = r.message
        #expect(message == nil)
        // L'état à retenir est là quand même : la prochaine fois, seul le neuf sera fêté.
        let marques = r.marques
        let marquesAttendues: Set<String> = ["jour:2026-10-14:10", "jours:1"]
        #expect(marques == marquesAttendues)
        let trophees = r.trophees
        let tropheesAttendus: Set<String> = ["premier_pas:1", "seance_longue:1"]
        #expect(trophees == tropheesAttendus)
    }

    @Test func unTropheeNeufPasseAvantUnPalier() {
        let (bilan, pratique) = premierJour()
        let r = Celebrations.neuf(bilan, pratique, paliersVus: [], tropheesVus: [])
        let icone = r.icone
        #expect(icone == "premier_pas")
        let message = r.message
        // Sans métal depuis le 13/11 (FDONNEES-06) : celui de la famille n'est plus celui que l'écran montre.
        let attendu = Libelle("trophee_niveau_gagne", .libelle(Libelle("trophee_premier_pas")), .entier(1))
        #expect(message == attendu)
    }

    @Test func unPalierQuandLesTropheesSontVusOuDAvantLesNiveaux() {
        let (bilan, pratique) = premierJour()
        let attendu = Libelle("palier_nouveau", .libelle(Libelle("palier_jour")),
                              .libelle(Libelle("duration_minutes", .entier(10))))
        // Le jour et les jours de pratique sont neufs, au même rang : le premier de la liste l'emporte.
        let vus = Celebrations.neuf(bilan, pratique, paliersVus: [], tropheesVus: ["premier_pas:1", "seance_longue:1"])
        let icone = vus.icone
        #expect(icone == "\u{1F389}")
        let message = vus.message
        #expect(message == attendu)
        let avant = Celebrations.neuf(bilan, pratique, paliersVus: [], tropheesVus: ["premier_pas"]).message
        #expect(avant == attendu)
        let jamais = Celebrations.neuf(bilan, pratique, paliersVus: [], tropheesVus: nil).message
        #expect(jamais == attendu)
    }

    @Test func toutVuNeFeteRien() {
        let (bilan, pratique) = premierJour()
        let r = Celebrations.neuf(bilan, pratique, paliersVus: ["jour:2026-10-14:10", "jours:1"],
                                  tropheesVus: ["premier_pas:1", "seance_longue:1"])
        let icone = r.icone
        #expect(icone == "")
        let message = r.message
        #expect(message == nil)
    }

    @Test func laNotificationNAnnonceQueDuNeuf() throws {
        let (bilan, pratique) = premierJour()
        let (annonce, r) = Celebrations.notification(bilan, pratique, paliersNotifies: [], tropheesNotifies: [])
        let lue = try #require(annonce)
        let titre = lue.titre
        let titreAttendu = Libelle("celebration_titre")
        #expect(titre == titreAttendu)
        let texte = lue.texte
        let message = r.message
        #expect(texte == message)
        let icone = lue.icone
        #expect(icone == "premier_pas")
        let marquees = Celebrations.marquerNotifies(bilan, pratique, paliersNotifies: [], tropheesNotifies: [])
        #expect(marquees == r)
        let (rien, premier) = Celebrations.notification(bilan, pratique, paliersNotifies: nil, tropheesNotifies: nil)
        #expect(rien == nil)
        let trophees = premier.trophees
        let tropheesAttendus = r.trophees
        #expect(trophees == tropheesAttendus)
    }

    @Test func lesValeursDesPaliers() {
        let serie = Celebrations.valeurPalier(.serie, 1)
        let unJour = Libelle.pluriel("palier_n_jours", quantite: 1, .entier(1))
        #expect(serie == unJour)
        let jours = Celebrations.valeurPalier(.jours, 613)
        let six13 = Libelle.pluriel("palier_n_jours", quantite: 613, .entier(613))
        #expect(jours == six13)
        let minutes = Celebrations.valeurPalier(.jour, 59)
        let cinquanteNeuf = Libelle("duration_minutes", .entier(59))
        #expect(minutes == cinquanteNeuf)
        let heures = Celebrations.valeurPalier(.semaine, 120)
        let deuxHeures = Libelle("duration_hours", .entier(2))
        #expect(heures == deuxHeures)
        let lesDeux = Celebrations.valeurPalier(.cumul, 61)
        let uneHeureUne = Libelle("duration_hours_minutes", .entier(1), .entier(1))
        #expect(lesDeux == uneHeureUne)
        let zero = Celebrations.valeurPalier(.mois, 0)
        let zeroMinute = Libelle("duration_minutes", .entier(0))
        #expect(zero == zeroMinute)
    }

    // MARK: Le catalogue

    /// Un libellé résolu dans une langue du catalogue, le français à défaut d'une chaîne.
    private struct Langue {
        let code: String
        let simples: [String: String]
        let pluriels: [String: String]
        let simplesFr: [String: String]
        let plurielsFr: [String: String]

        init(_ code: String, _ c: Catalogue) {
            self.code = code
            simples = c.simples(code)
            pluriels = c.pluriels(code)
            simplesFr = c.simples("fr")
            plurielsFr = c.pluriels("fr")
        }

        func texte(_ l: Libelle) -> String? {
            l.texte(langue: code,
                    chaine: { simples[$0] ?? simplesFr[$0] },
                    pluriel: { pluriels["\($0)[\($1)]"] ?? plurielsFr["\($0)[\($1)]"] })
        }
    }

    @Test func chaqueMessageSeResoutDansLesTroisLangues() throws {
        let c = try Catalogue.lire()
        let (bilan, _) = premierJour()
        for code in Catalogue.langues {
            let langue = Langue(code, c)
            let titre = langue.simples["celebration_titre"]
            #expect(titre != nil, "\(code) : celebration_titre")
            for f in Trophees.Famille.allCases {
                for rang in 1...f.seuils.count {
                    let n = Trophees.Niveau(famille: f, rang: rang)
                    let message = Libelle("trophee_niveau_gagne", .libelle(Celebrations.nomTrophee(f)), .entier(rang))
                    let texte = langue.texte(message)
                    #expect(texte != nil, "\(code) : \(n.cle)")
                }
            }
            for piste in Paliers.Piste.allCases {
                for v in [1, 2, 3, 59, 60, 61, 90, 120, 613, 1500] {
                    let message = Libelle("palier_nouveau", .libelle(Celebrations.libellePalier(piste, bilan)),
                                          .libelle(Celebrations.valeurPalier(piste, v)))
                    let texte = langue.texte(message)
                    #expect(texte != nil, "\(code) : \(piste.rawValue) \(v)")
                }
            }
        }
        // Le mois porte le mois hébreu d'aujourd'hui, isolé du reste de la phrase.
        let mois = Langue("fr", c).texte(Celebrations.libellePalier(.mois, bilan)) ?? ""
        let isole = mois.contient("\u{2068}") && mois.contient("\u{2069}")
        #expect(isole, "\(mois)")
    }

    // MARK: Les vecteurs de la JVM

    /// [jour, minutes]
    private struct MinutesV: Decodable {
        let jour: String
        let minutes: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            jour = try c.decode(String.self)
            minutes = try c.decode(Int.self)
        }
    }

    /// [piste, atteint, rang]
    private struct PalierV: Decodable {
        let piste: String
        let atteint: Int
        let rang: Int

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            piste = try c.decode(String.self)
            atteint = try c.decode(Int.self)
            rang = try c.decode(Int.self)
        }
    }

    private struct CasV: Decodable {
        let nom: String
        let aujourdhui: String
        let minutes: [MinutesV]
        let serie: Int
        let debutMoisHebreu: String
        let objectifJour: Int
        let notes: Int
        let meilleureSerie: Int
        let tikkun: [String]
        let paliersVus: [String]?
        let tropheesVus: [String]?
        let icone: String
        /// Le message d'Android, mis en forme avec les coquilles de l'oracle (TropheesVue et PaliersVue y rendent "").
        let message: String
        let marques: [String]
        let trophees: [String]
        /// [clé] du trophée fêté, annoncé sans métal (FDONNEES-06).
        let trophee: [String]?
        /// Les trophées gagnés à cet instant.
        let compte: Int
        let palier: PalierV?
        let moisEtAnnee: String?
    }

    /// Les clés des libellés relevées dans PaliersActivity.kt : [nom Kotlin, clé].
    private struct LibellesV: Decodable {
        let nom: [[String]]
        let metal: [[String]]
        let palier: [[String]]
    }

    private struct Vecteurs: Decodable {
        let libelles: LibellesV
        let cas: [CasV]
    }

    private func vecteurs() throws -> Vecteurs {
        try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/celebrations.json"))
    }

    private func jour(_ texte: String) throws -> JourCivil {
        try #require(JourCivil(iso: texte), "date illisible : \(texte)")
    }

    @Test func lesClesDesLibellesSontCellesDAndroid() throws {
        let v = try vecteurs()
        let (bilan, _) = premierJour()
        let familles = v.libelles.nom.count
        let famillesSwift = Trophees.Famille.allCases.count
        #expect(familles == famillesSwift)
        for paire in v.libelles.nom {
            let complete = paire.count == 2
            #expect(complete, "\(paire)")
            if !complete { continue }
            let lue = Trophees.Famille(rawValue: paire[0])
            let f = try #require(lue, "famille inconnue : \(paire[0])")
            let cle = Celebrations.nomTrophee(f).cle
            #expect(cle == paire[1], "\(paire[0])")
        }
        let metaux = v.libelles.metal.count
        let metauxSwift = Trophees.Metal.allCases.count
        #expect(metaux == metauxSwift)
        for paire in v.libelles.metal {
            let complete = paire.count == 2
            #expect(complete, "\(paire)")
            if !complete { continue }
            let lu = Trophees.Metal(rawValue: paire[0])
            let m = try #require(lu, "métal inconnu : \(paire[0])")
            let cle = Celebrations.metalTrophee(m).cle
            #expect(cle == paire[1], "\(paire[0])")
        }
        let pistes = v.libelles.palier.count
        let pistesSwift = Paliers.Piste.allCases.count
        #expect(pistes == pistesSwift)
        for paire in v.libelles.palier {
            let complete = paire.count == 2
            #expect(complete, "\(paire)")
            if !complete { continue }
            let lue = Paliers.Piste(rawValue: paire[0])
            let p = try #require(lue, "piste inconnue : \(paire[0])")
            let cle = Celebrations.libellePalier(p, bilan).cle
            #expect(cle == paire[1], "\(paire[0])")
        }
    }

    @Test func chaqueCasCommeSurAndroid() throws {
        let v = try vecteurs()
        let nombre = v.cas.count
        #expect(nombre > 70)
        let catalogue = try Catalogue.lire()
        let fr = Langue("fr", catalogue)
        for cas in v.cas {
            var minutes: [JourCivil: Int] = [:]
            for m in cas.minutes {
                let j = try jour(m.jour)
                minutes[j] = m.minutes
            }
            var tikkun = Set<JourCivil>()
            for t in cas.tikkun {
                let j = try jour(t)
                tikkun.insert(j)
            }
            let aujourdhui = try jour(cas.aujourdhui)
            let debutMois = try jour(cas.debutMoisHebreu)
            let bilan = Paliers.Bilan(aujourdhui: aujourdhui, minutes: minutes, serie: cas.serie,
                                      debutMoisHebreu: debutMois, objectifJour: cas.objectifJour)
            let pratique = Trophees.Pratique(minutes: minutes, notes: cas.notes, meilleureSerie: cas.meilleureSerie,
                                             tikkun: tikkun)
            let paliersVus = cas.paliersVus.map { Set($0) }
            let tropheesVus = cas.tropheesVus.map { Set($0) }
            let r = Celebrations.neuf(bilan, pratique, paliersVus: paliersVus, tropheesVus: tropheesVus)

            let icone = r.icone
            #expect(icone == cas.icone, "\(cas.nom) : icône")
            let marques = r.marques.sorted()
            #expect(marques == cas.marques, "\(cas.nom) : marques")
            let trophees = r.trophees.sorted()
            #expect(trophees == cas.trophees, "\(cas.nom) : trophées")
            #expect(r.compte == cas.compte, "\(cas.nom) : compte")

            // La phrase : ce que neuf a choisi.
            var attendu: Libelle?
            if let trophee = cas.trophee {
                let complet = trophee.count == 1
                #expect(complet, "\(cas.nom) : \(trophee)")
                if !complet { continue }
                let cle = trophee[0]
                let cleFamille = cle.avantUnites(":")
                let trouvee = Trophees.Famille.allCases.first { $0.cle == cleFamille }
                let famille = try #require(trouvee, "\(cas.nom) : famille de \(cle)")
                let rangLu = Int(cle.apresUnites(":"))
                let rang = try #require(rangLu, "\(cas.nom) : rang de \(cle)")
                attendu = Libelle("trophee_niveau_gagne", .libelle(Celebrations.nomTrophee(famille)), .entier(rang))
            } else if let palier = cas.palier {
                let pisteLue = Paliers.Piste(rawValue: palier.piste)
                let piste = try #require(pisteLue, "\(cas.nom) : piste \(palier.piste)")
                var rangs: [Int] = []
                for e in Paliers.etats(bilan) where e.piste == piste { rangs.append(e.rang) }
                let rangAttendu = [palier.rang]
                #expect(rangs == rangAttendu, "\(cas.nom) : rang du palier")
                attendu = Libelle("palier_nouveau", .libelle(Celebrations.libellePalier(piste, bilan)),
                                  .libelle(Celebrations.valeurPalier(piste, palier.atteint)))
                if piste == .mois {
                    let mois = try #require(cas.moisEtAnnee, "\(cas.nom) : mois hébreu")
                    let libelle = Celebrations.libellePalier(.mois, bilan)
                    let libelleAttendu = Libelle("palier_mois", .texte("\u{2068}" + mois + "\u{2069}"))
                    #expect(libelle == libelleAttendu, "\(cas.nom) : mois")
                }
            }
            let message = r.message
            #expect(message == attendu, "\(cas.nom) : message")

            // Mis en forme comme dans l'oracle, où TropheesVue et PaliersVue rendent "" : le texte d'Android.
            let commeLOracle = r.message?.texte(
                langue: "fr",
                chaine: { $0 == "trophee_niveau_gagne" || $0 == "palier_nouveau" ? fr.simples[$0] : "" },
                pluriel: { _, _ in "" }) ?? ""
            #expect(commeLOracle == cas.message, "\(cas.nom) : texte")

            // marquerNotifies et notification retiennent ce que neuf rend ; la notification n'annonce que du neuf.
            let marquees = Celebrations.marquerNotifies(bilan, pratique, paliersNotifies: paliersVus,
                                                        tropheesNotifies: tropheesVus)
            #expect(marquees == r, "\(cas.nom) : marquerNotifies")
            let (annonce, notifiee) = Celebrations.notification(bilan, pratique, paliersNotifies: paliersVus,
                                                                tropheesNotifies: tropheesVus)
            #expect(notifiee == r, "\(cas.nom) : notification")
            let annonceAttendue = r.message.map { Celebrations.Annonce(titre: Libelle("celebration_titre"), texte: $0, icone: r.icone) }
            #expect(annonce == annonceAttendue, "\(cas.nom) : annonce")
        }
    }
}
