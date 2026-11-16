import Foundation
import Testing
@testable import Coeur

/// Les règles de Store.kt qui calculent (Store.swift). D'abord `Tests/Vecteurs/store.json`
/// (tools/vecteurs_ios/VecteursStore.kt) : des scénarios faits par le vrai Store sur la JVM, l'horloge figée
/// réglée pas à pas (Chabbat et Yom Tov en Israël et en diaspora, nuits des changements d'heure, fenêtre de
/// nuit un vendredi, minuit, 4 h pour le Tikoun, une note seule), rejoués ici opération par opération sur Journal et
/// Reglages, et comparés après chacune : série, semaine, exemptions, fenêtre, report, séance, Tikoun,
/// lecture, 'hizouk, bravo, lieu, paliers, trophées, anneaux, la préférence « days » et les réglages
/// écrits. Puis fenetreFaite, repriseValable, jourTikkun (et ceux de horloge.json), formatMinutes et
/// formatDuration dans les trois langues du catalogue. Enfin ce que Fiabilite2Test vérifie en lisant le
/// code et qui se vérifie ici par des valeurs ; le reste de Fiabilite2Test (le service de séance, les
/// écrans, le manifeste, la vignette) lit le code d'Android et reste à Android.
@Suite("Store")
struct StoreTests {

    // MARK: Les vecteurs

    private struct Fichier: Decodable {
        let constantes: Constantes
        let scenarios: [Scenario]
        let ensembles: [[String]]
        let fenetre: [CasFenetre]
        let reprises: [CasReprise]
        let jourTikkun: [CasJourTikkun]
        let formats: [CasFormat]
    }

    private struct Constantes: Decodable {
        let noteMax: Int
        let defaultTarget: Int
        let priereRepriseMs: Int64
        let clesLecture: [String]
    }

    private struct Scenario: Decodable {
        let nom: String
        let etapes: [Etape]
    }

    private struct Etape: Decodable {
        let op: Op
        let millis: Int64
        let zone: String
        let seance: Close?
        let pose: Bool?
        let celebration: Bravo?
        let etat: Etat
        let prefs: Trace?
        let days: Trace?
    }

    /// Une opération : son nom, et ceux de ses champs qui la concernent.
    private struct Op: Decodable {
        let op: String
        let jour: String?
        let heure: Int?
        let minute: Int?
        let seconde: Int?
        let zone: String?
        let minutes: Int?
        let note: String?
        let theme: String?
        let date: String?
        let jours: [String]?
        let durees: [Int]?
        let valeur: Bool?
        let debut: Int?
        let fin: Int?
        let numeros: [Int]?
        let cle: String?
        let position: Int?
        let nusah: String?
        let section: Int?
        let bloc: Int?
        let apercu: String?
        let moment: String?
        let sac: [String]?
        let dernier: String?
        let dateNote: String?
        let texte: String?
        let nom: String?
        let latitude: Double?
        let longitude: Double?
        let altitude: Double?
        let fuseau: String?
        let ville: Int64?
        let pays: String?
    }

    private struct Close: Decodable {
        let minutes: Int
        let date: String
    }

    private struct Bravo: Decodable {
        let existe: Bool
        let minutes: Int?
        let dateNote: String?
    }

    /// Un texte : sa longueur en unités UTF-16, son empreinte (String.hashCode), lui-même s'il est court.
    private struct Trace: Decodable {
        let longueur: Int
        let empreinte: Int32
        let texte: String?
    }

    private struct Semaine: Decodable {
        let dimanche: String
        let faits: String
        let exempts: String
        let chabbats: String
        let futurs: String
    }

    /// Des minutes par jour : leur nombre, et l'empreinte de « jour=minutes » triés, joints par des virgules.
    private struct Empreinte: Decodable, Equatable {
        let jours: Int
        let empreinte: Int32
    }

    private struct BilanVecteur: Decodable {
        let aujourdhui: String
        let serie: Int
        let debutMoisHebreu: String
        let objectifJour: Int
        let minutes: Empreinte
    }

    private struct PratiqueVecteur: Decodable {
        let notes: Int
        let meilleureSerie: Int
        let tikkun: [String]
        let minutes: Empreinte
    }

    private struct Etat: Decodable {
        let today: String
        let streak: Int
        let meilleureSerie: Int
        let semaine: Semaine
        let exempt: Bool
        let veille: Bool
        let isDone: Bool
        let record: Int?
        let total: Int
        let dejaPratique: Bool
        let inWindow: Bool
        let fenetreFaite: Bool
        let isSnoozed: Bool
        let dailyGoal: Int
        let running: Bool
        let open: Bool
        let elapsed: Int
        let hasRecord: Bool
        let compteur: String
        let bilan: BilanVecteur
        let pratique: PratiqueVecteur
        /// Écrits à l'étape qui les change seulement.
        let trophees: [String: String]?
        let anneaux: [Int]
        let jourTikkun: String
        let tikkunDone: [Int]
        let tikkunJournal: [String]
        let positions: [Int?]
        let favoris: [String]
        let chizukFavoris: [String]
        let marques: String
        let sac: [String]
        let dernier: String?
        let celebration: Bool
        /// lieuPerime, lieuAlertes non nul, mukafChoma, hemisphereSud.
        let lieu: String
    }

    private struct CasFenetre: Decodable {
        let debut: Int
        let fin: Int
        let maintenant: String
        let faitA: String?
        /// Un drapeau par ensemble de jours faits (`ensembles`).
        let faites: String
    }

    private struct CasReprise: Decodable {
        let cle: String
        let quand: Int64
        let maintenant: Int64
        let valable: Bool
    }

    private struct CasJourTikkun: Decodable {
        let civile: String
        let milli: Int
        let jour: String
    }

    private struct CasFormat: Decodable {
        let minutes: Int
        let formatMinutes: String
        let fr: String
        let en: String
        let he: String
    }

    private struct FichierHorloge: Decodable {
        struct Defaut: Decodable {
            let today: String
            let jourTikkun: String
        }
        struct Regle: Decodable {
            let civile: String
            let fuseau: String
            let today: String
            let jourTikkun: String
            let millis: Int64
        }
        let defaut: Defaut
        let regles: [Regle]
    }

    private func fichier() throws -> Fichier {
        try JSONDecoder().decode(Fichier.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/store.json"))
    }

    // MARK: Les scénarios

    @Test func lesScenariosDeStoreSeRejouent() throws {
        let f = try fichier()
        #expect(f.scenarios.count == 8)
        for scenario in f.scenarios {
            try rejoue(scenario, clesLecture: f.constantes.clesLecture)
        }
    }

    private func rejoue(_ scenario: Scenario, clesLecture: [String]) throws {
        var journal = Journal()
        var reglages = Reglages()
        // L'horloge par défaut de l'oracle : le 1er janvier 2026 à midi, en UTC.
        var millis: Int64 = 1_767_268_800_000
        var fuseau = Fuseau.utc
        var prefs: Trace?
        var days: Trace?
        var trophees: [String: String] = [:]
        for (rang, etape) in scenario.etapes.enumerated() {
            let o = etape.op
            let lieu = "\(scenario.nom), étape \(rang + 1) (\(o.op))"
            switch o.op {
            case "horloge":
                let zone: Fuseau = try #require(Fuseau(o.zone ?? ""), "\(lieu) : fuseau")
                let civile = DateHeure(JourCivil.du(o.jour ?? ""), heure: o.heure ?? 0, minute: o.minute ?? 0, seconde: o.seconde ?? 0)
                let calcule = zone.millis(civile)
                #expect(calcule == etape.millis, "\(lieu) : l'instant de \(civile) [\(zone.identifiant)]")
                fuseau = zone
                millis = etape.millis
            case "avance":
                millis += Int64(o.minutes ?? 0) * 60_000
            case "fuseau":
                fuseau = try #require(Fuseau(o.zone ?? ""), "\(lieu) : fuseau")
            case "addSession":
                let theme = o.theme.flatMap { Theme(rawValue: $0) }
                let date = o.date.map { JourCivil.du($0) }
                Store.addSession(journal: &journal, reglages: &reglages, minutes: o.minutes ?? 0, note: o.note, theme: theme,
                                 date: date, millis: millis, fuseau: fuseau)
            case "seances":
                let jours = o.jours ?? []
                let durees = o.durees ?? []
                #expect(jours.count == durees.count, "\(lieu) : séances")
                for (k, jour) in jours.enumerated() where k < durees.count {
                    Store.addSession(journal: &journal, reglages: &reglages, minutes: durees[k], date: JourCivil.du(jour),
                                     millis: millis, fuseau: fuseau)
                }
            case "setNote":
                Store.setNote(journal: &journal, date: JourCivil.du(o.date ?? ""), note: o.note ?? "")
            case "unmarkToday":
                Store.unmarkToday(journal: &journal, reglages: &reglages, aujourdhui: Store.today(millis: millis, fuseau: fuseau))
            case "beginSession":
                Store.beginSession(reglages: &reglages, minutes: o.minutes ?? 0, millis: millis)
            case "endSession", "cloreSeance":
                let close = Store.endSession(reglages: &reglages, millis: millis, fuseau: fuseau)
                if o.op == "cloreSeance" {
                    // Ce que fait le service à la fin d'une séance : l'inscrire au jour où elle a commencé.
                    Store.addSession(journal: &journal, reglages: &reglages, minutes: close.minutes, date: close.date,
                                     millis: millis, fuseau: fuseau)
                }
                let attendue: Close = try #require(etape.seance, "\(lieu) : séance close")
                #expect(close.minutes == attendue.minutes, "\(lieu) : minutes inscrites")
                let date = close.date.iso
                #expect(date == attendue.date, "\(lieu) : jour de la séance")
            case "snooze":
                Store.snooze(reglages: &reglages, millis: millis)
            case "clearSnooze":
                Store.clearSnooze(reglages: &reglages)
            case "setSnoozeMinutes":
                reglages.setSnoozeMinutes(o.minutes ?? 0)
            case "togglePausedDate":
                reglages.togglePausedDate(o.date ?? "")
            case "setShabbatMode":
                reglages.setShabbatMode(o.valeur ?? false)
            case "setInIsrael":
                reglages.setInIsrael(o.valeur ?? false)
            case "setWindow":
                reglages.setWindow(startMinutes: o.debut ?? 0, endMinutes: o.fin ?? 0)
            case "setTargetMinutes":
                reglages.setTargetMinutes(o.minutes ?? 0)
            case "setDailyGoal":
                reglages.setDailyGoal(o.minutes ?? 0)
            case "setHideCountdown":
                reglages.setHideCountdown(o.valeur ?? false)
            case "setTikkunDone":
                let maintenant = fuseau.dateHeure(millis: millis)
                for numero in o.numeros ?? [] {
                    Store.setTikkunDone(reglages: &reglages, numero: numero, done: o.valeur ?? false, maintenant: maintenant)
                }
            case "resetTikkun":
                Store.resetTikkun(reglages: &reglages, maintenant: fuseau.dateHeure(millis: millis))
            case "setPositionLecture":
                Store.setPositionLecture(reglages: &reglages, cle: o.cle ?? "", position: o.position ?? 0, maintenant: millis)
            case "basculerFavori":
                Store.basculerFavori(reglages: &reglages, cle: o.cle ?? "")
            case "basculerChizukFavori":
                Store.basculerChizukFavori(reglages: &reglages, id: o.cle ?? "")
            case "basculerMarque":
                let m = MarquesPages.Marque(cle: o.cle ?? "", nusah: o.nusah ?? "", section: o.section ?? 0, bloc: o.bloc ?? 0,
                                            apercu: o.apercu ?? "")
                let posee = Store.basculerMarque(reglages: &reglages, m)
                let attendue: Bool = try #require(etape.pose, "\(lieu) : marque")
                #expect(posee == attendue, "\(lieu) : marque posée")
            case "setChizukBag":
                let moment: Moment = try #require(Moment(rawValue: o.moment ?? ""), "\(lieu) : moment")
                Store.setChizukBag(reglages: &reglages, moment: moment, bag: o.sac ?? [], last: o.dernier)
            case "setPendingCelebration":
                Store.setPendingCelebration(reglages: &reglages, minutes: o.minutes ?? 0, dateNote: o.dateNote)
            case "takePendingCelebration":
                let bravo = Store.takePendingCelebration(reglages: &reglages)
                let attendu: Bravo = try #require(etape.celebration, "\(lieu) : bravo")
                let existe = bravo != nil
                #expect(existe == attendu.existe, "\(lieu) : bravo en attente")
                if let bravo {
                    let minutesBravo: Int? = bravo.minutes
                    #expect(minutesBravo == attendu.minutes, "\(lieu) : minutes du bravo")
                    let dateNote = bravo.dateNote
                    #expect(dateNote == attendu.dateNote, "\(lieu) : jour de la note")
                }
            case "poseTexte":
                // Une préférence posée à la main (une version d'avant, un fichier abîmé).
                var brut = reglages.brut
                brut[o.cle ?? ""] = .chaine(o.texte ?? "")
                reglages = Reglages(brut: brut)
            case "setLieuZmanim":
                let nom = o.nom ?? ""
                let lieuZmanim = Zmanim.Lieu(nom: nom, latitude: o.latitude ?? 0, longitude: o.longitude ?? 0,
                                             altitude: o.altitude ?? 0, fuseau: o.fuseau ?? "")
                var ville: Ville?
                if let id = o.ville {
                    ville = try villeDe(id: id, pays: o.pays ?? "", lieu: lieuZmanim)
                }
                reglages.setLieuZmanim(lieuZmanim, ville: ville, maintenant: millis)
            default:
                Issue.record("\(lieu) : opération inconnue")
            }
            let instantCourant = millis
            #expect(instantCourant == etape.millis, "\(lieu) : l'instant")
            let fuseauCourant = fuseau.identifiant
            #expect(fuseauCourant == etape.zone, "\(lieu) : le fuseau")

            // La lecture d'Android fige Israël ou diaspora au premier accès, que l'état fait quand le mode
            // Chabbat est actif (Store.isEveOfRestDay le demande alors toujours) ; l'app d'iOS, à l'ouverture.
            if reglages.shabbatMode {
                reglages.figeInIsrael(fuseauTelephone: fuseau.identifiant)
            }
            if let changes = etape.etat.trophees {
                trophees = changes
            }
            verifie(etape.etat, journal: journal, reglages: reglages, millis: millis, fuseau: fuseau, trophees: trophees,
                    clesLecture: clesLecture, lieu: lieu)

            if let nouvelles = etape.prefs {
                prefs = nouvelles
            }
            if let attendues = prefs {
                verifie(prefsTexte(reglages), attendues, "\(lieu) : réglages écrits")
            }
            if let nouveaux = etape.days {
                days = nouveaux
            }
            if let attendus = days {
                verifie(journal.daysTexte, attendus, "\(lieu) : préférence days")
            }
        }
    }

    /// Ce que rendent les fonctions qui calculent, ici et maintenant, comparé à ce qu'Android rendait.
    private func verifie(_ e: Etat, journal: Journal, reglages: Reglages, millis: Int64, fuseau: Fuseau,
                         trophees: [String: String], clesLecture: [String], lieu: String) {
        let aujourdhui = Store.today(millis: millis, fuseau: fuseau)
        let maintenant = fuseau.dateHeure(millis: millis)
        let tel = fuseau.identifiant

        let today = aujourdhui.iso
        #expect(today == e.today, "\(lieu) : today")
        let streak = Store.streak(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: tel)
        #expect(streak == e.streak, "\(lieu) : streak")
        let meilleure = Store.meilleureSerie(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: tel)
        #expect(meilleure == e.meilleureSerie, "\(lieu) : meilleureSerie")

        let semaine = Store.currentWeek(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: tel)
        let dimanche = semaine.first?.date.iso ?? ""
        #expect(dimanche == e.semaine.dimanche, "\(lieu) : dimanche de la semaine")
        let faits = drapeaux(semaine.map { $0.done })
        #expect(faits == e.semaine.faits, "\(lieu) : jours faits de la semaine")
        let exempts = drapeaux(semaine.map { $0.exempt })
        #expect(exempts == e.semaine.exempts, "\(lieu) : jours exemptés de la semaine")
        let chabbats = drapeaux(semaine.map { $0.shabbat })
        #expect(chabbats == e.semaine.chabbats, "\(lieu) : samedis")
        let futurs = drapeaux(semaine.map { $0.future })
        #expect(futurs == e.semaine.futurs, "\(lieu) : jours à venir")

        let exempt = Store.isExempt(reglages: reglages, date: aujourdhui, fuseauTelephone: tel)
        #expect(exempt == e.exempt, "\(lieu) : isExempt")
        let veille = Store.isEveOfRestDay(reglages: reglages, date: aujourdhui, fuseauTelephone: tel)
        #expect(veille == e.veille, "\(lieu) : isEveOfRestDay")
        let fait = Store.isDone(journal: journal, date: aujourdhui)
        #expect(fait == e.isDone, "\(lieu) : isDone")
        let record = Store.record(journal: journal, date: aujourdhui)?.minutes
        #expect(record == e.record, "\(lieu) : record")
        let total = Store.totalMinutes(journal: journal)
        #expect(total == e.total, "\(lieu) : totalMinutes")
        let deja = Store.aDejaPratique(journal: journal)
        #expect(deja == e.dejaPratique, "\(lieu) : aDejaPratique")

        let dansLaFenetre = Store.inWindow(reglages: reglages, maintenant: maintenant)
        #expect(dansLaFenetre == e.inWindow, "\(lieu) : inWindow")
        let fenetreFaite = Store.fenetreFaite(journal: journal, reglages: reglages, millis: millis, fuseau: fuseau)
        #expect(fenetreFaite == e.fenetreFaite, "\(lieu) : fenetreFaite")
        let reporte = Store.isSnoozed(reglages: reglages, millis: millis)
        #expect(reporte == e.isSnoozed, "\(lieu) : isSnoozed")
        let objectif = Store.dailyGoal(reglages: reglages)
        #expect(objectif == e.dailyGoal, "\(lieu) : dailyGoal")

        let enCours = Store.isSessionRunning(reglages: reglages, millis: millis)
        #expect(enCours == e.running, "\(lieu) : isSessionRunning")
        let ouverte = Store.isSessionOpen(reglages: reglages)
        #expect(ouverte == e.open, "\(lieu) : isSessionOpen")
        let ecoulees = Store.sessionElapsedMinutes(reglages: reglages, millis: millis)
        #expect(ecoulees == e.elapsed, "\(lieu) : sessionElapsedMinutes")
        let inscrite = Store.hasSessionRecord(reglages: reglages)
        #expect(inscrite == e.hasRecord, "\(lieu) : hasSessionRecord")
        let compteur = nom(Store.sessionCounter(reglages: reglages))
        #expect(compteur == e.compteur, "\(lieu) : sessionCounter")

        let bilan = Store.bilan(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: tel)
        let bilanJour = bilan.aujourdhui.iso
        #expect(bilanJour == e.bilan.aujourdhui, "\(lieu) : bilan, aujourd'hui")
        #expect(bilan.serie == e.bilan.serie, "\(lieu) : bilan, série")
        let debutMois = bilan.debutMoisHebreu.iso
        #expect(debutMois == e.bilan.debutMoisHebreu, "\(lieu) : bilan, début du mois hébreu")
        #expect(bilan.objectifJour == e.bilan.objectifJour, "\(lieu) : bilan, objectif")
        let minutesBilan = empreinte(bilan.minutes)
        #expect(minutesBilan == e.bilan.minutes, "\(lieu) : bilan, minutes")

        let pratique = Store.pratique(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: tel)
        #expect(pratique.notes == e.pratique.notes, "\(lieu) : pratique, notes")
        #expect(pratique.meilleureSerie == e.pratique.meilleureSerie, "\(lieu) : pratique, meilleure série")
        let tikkunPratique = pratique.tikkun.sorted().map { $0.iso }
        #expect(tikkunPratique == e.pratique.tikkun, "\(lieu) : pratique, Tikoun")
        let minutesPratique = empreinte(pratique.minutes)
        #expect(minutesPratique == e.pratique.minutes, "\(lieu) : pratique, minutes")

        var dates: [String: String] = [:]
        for (cle, jour) in Store.datesTrophees(journal: journal, reglages: reglages, fuseauTelephone: tel) {
            dates[cle] = jour.iso
        }
        #expect(dates == trophees, "\(lieu) : datesTrophees")

        let a = Store.anneaux(journal: journal, reglages: reglages, aujourdhui: aujourdhui, fuseauTelephone: tel)
        let anneaux = [a.jour.fait, a.jour.objectif, a.semaine.fait, a.semaine.objectif, a.serie.fait, a.serie.objectif]
        #expect(anneaux == e.anneaux, "\(lieu) : anneaux")

        let jourTikkun = Store.jourTikkun(maintenant).iso
        #expect(jourTikkun == e.jourTikkun, "\(lieu) : jourTikkun")
        let tikkunDone = Store.tikkunDone(reglages: reglages, maintenant: maintenant).sorted()
        #expect(tikkunDone == e.tikkunDone, "\(lieu) : tikkunDone")
        let tikkunJournal = Store.tikkunJournal(reglages: reglages).sorted().map { $0.iso }
        #expect(tikkunJournal == e.tikkunJournal, "\(lieu) : tikkunJournal")

        var positions: [Int?] = []
        for cle in clesLecture {
            positions.append(Store.positionLecture(reglages: reglages, cle: cle, maintenant: millis))
        }
        #expect(positions == e.positions, "\(lieu) : positionLecture")
        let favoris = Store.favoris(reglages: reglages)
        #expect(favoris == e.favoris, "\(lieu) : favoris")
        let chizukFavoris = Store.chizukFavoris(reglages: reglages)
        #expect(chizukFavoris == e.chizukFavoris, "\(lieu) : chizukFavoris")
        let marques = MarquesPages.encoder(Store.marques(reglages: reglages))
        let marquesConformes = marques.egalUnites(e.marques)
        #expect(marquesConformes, "\(lieu) : marques \(marques)")
        let sac = Store.chizukBag(reglages: reglages, moment: .ouverture)
        #expect(sac == e.sac, "\(lieu) : chizukBag")
        let dernier = Store.chizukLast(reglages: reglages, moment: .ouverture)
        #expect(dernier == e.dernier, "\(lieu) : chizukLast")
        let bravo = Store.hasPendingCelebration(reglages: reglages)
        #expect(bravo == e.celebration, "\(lieu) : hasPendingCelebration")
        let alertes = Store.lieuAlertes(reglages: reglages, fuseauTelephone: tel) != nil
        let lieuZmanim = drapeaux([Store.lieuPerime(reglages: reglages, fuseauTelephone: tel), alertes,
                                   Store.mukafChoma(reglages: reglages), Store.hemisphereSud(reglages: reglages)])
        #expect(lieuZmanim == e.lieu, "\(lieu) : lieuPerime, lieuAlertes, mukafChoma, hemisphereSud")
    }

    /// Un texte jugé par sa trace.
    private func verifie(_ texte: String, _ trace: Trace, _ lieu: String) {
        let longueur = texte.utf16.count
        #expect(longueur == trace.longueur, "\(lieu) : longueur")
        let hache = Kotlin.hashCode(texte)
        #expect(hache == trace.empreinte, "\(lieu) : empreinte")
        if let attendu = trace.texte {
            let conforme = texte.egalUnites(attendu)
            #expect(conforme, "\(lieu) : \(texte) au lieu de \(attendu)")
        }
    }

    /// Les réglages écrits, clés triées, comme org.json les écrit (ce que l'oracle écrit de ses préférences).
    private func prefsTexte(_ reglages: Reglages) -> String {
        let paires = reglages.brut.paires.sorted { $0.cle.utf16.lexicographicallyPrecedes($1.cle.utf16) }
        var objet = ObjetJSON()
        for paire in paires {
            objet[paire.cle] = paire.valeur
        }
        return objet.texte()
    }

    private func empreinte(_ minutes: [JourCivil: Int]) -> Empreinte {
        var morceaux: [String] = []
        for jour in minutes.keys.sorted() {
            morceaux.append(jour.iso + "=" + String(minutes[jour] ?? 0))
        }
        return Empreinte(jours: minutes.count, empreinte: Kotlin.hashCode(morceaux.joined(separator: ",")))
    }

    private func drapeaux(_ valeurs: [Bool]) -> String {
        var texte = ""
        for v in valeurs {
            texte += v ? "1" : "0"
        }
        return texte
    }

    /// Le nom de l'énumération Kotlin (`SessionRule.Compteur.name`).
    private func nom(_ compteur: SessionRule.Compteur) -> String {
        switch compteur {
        case .reste: "RESTE"
        case .ecoule: "ECOULE"
        case .masque: "MASQUE"
        }
    }

    /// Une ville de la liste, lue comme villes.json l'écrit ; son nom dans les trois langues est celui du lieu.
    private func villeDe(id: Int64, pays: String, lieu: Zmanim.Lieu) throws -> Ville {
        let nom = ObjetJSON([("he", .chaine(lieu.nom)), ("fr", .chaine(lieu.nom)), ("en", .chaine(lieu.nom))])
        let objet = ObjetJSON([
            ("id", .entier(id)), ("nom", .objet(nom)), ("pays", .chaine(pays)), ("latitude", .decimal(lieu.latitude)),
            ("longitude", .decimal(lieu.longitude)), ("altitude", .decimal(lieu.altitude)), ("fuseau", .chaine(lieu.fuseau)),
        ])
        return try JSONDecoder().decode(Ville.self, from: Data(objet.texte().utf8))
    }

    /// « 2026-11-02T00:29:00 » ou « 2026-03-29T01:30 » : une heure civile.
    private func dateHeure(_ texte: String, milli: Int = 0) -> DateHeure {
        let jour = JourCivil.du(texte.premieresUnites(10))
        let heure = Int(texte.unites(11, 13)) ?? 0
        let minute = Int(texte.unites(14, 16)) ?? 0
        let seconde = Int(texte.unites(17, 19)) ?? 0
        return DateHeure(jour, heure: heure, minute: minute, seconde: seconde, milli: milli)
    }

    // MARK: Les règles pures

    @Test func lesConstantesSontCellesDAndroid() throws {
        let c = try fichier().constantes
        #expect(Store.noteMax == c.noteMax)
        #expect(Store.defaultTarget == c.defaultTarget)
        #expect(Store.priereRepriseMs == c.priereRepriseMs)
    }

    @Test func laFenetreFaiteCommeAndroid() throws {
        let f = try fichier()
        var ensembles: [Set<JourCivil>] = []
        for jours in f.ensembles {
            ensembles.append(Set(jours.map { JourCivil.du($0) }))
        }
        #expect(f.fenetre.count > 300)
        for cas in f.fenetre {
            let maintenant = dateHeure(cas.maintenant)
            let faitA = cas.faitA.map { dateHeure($0) }
            let attendus = Array(cas.faites.utf8)
            #expect(attendus.count == ensembles.count, "\(cas.maintenant)")
            for (k, jours) in ensembles.enumerated() where k < attendus.count {
                let faite = Store.fenetreFaite(start: cas.debut, end: cas.fin, maintenant: maintenant, faitA: faitA) { jours.contains($0) }
                let attendue = attendus[k] == UInt8(ascii: "1")
                #expect(faite == attendue, "\(cas.debut)–\(cas.fin) à \(cas.maintenant), faite à \(cas.faitA ?? "?"), ensemble \(k)")
            }
        }
    }

    @Test func laRepriseDeLectureCommeAndroid() throws {
        let cas = try fichier().reprises
        #expect(cas.count == 27)
        for c in cas {
            let valable = Store.repriseValable(c.cle, quand: c.quand, maintenant: c.maintenant)
            #expect(valable == c.valable, "\(c.cle) \(c.quand) \(c.maintenant)")
        }
    }

    @Test func leJourDuTikounCommeAndroid() throws {
        let cas = try fichier().jourTikkun
        #expect(cas.count == 18)
        for c in cas {
            let jour = Store.jourTikkun(dateHeure(c.civile, milli: c.milli)).iso
            #expect(jour == c.jour, "\(c.civile)")
        }
        // horloge.json : l'heure figée de l'oracle, et le jour du Tikoun qu'Android en tire.
        let h = try JSONDecoder().decode(FichierHorloge.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/horloge.json"))
        let midi: Int64 = 1_767_268_800_000
        let today = Store.today(millis: midi, fuseau: .utc).iso
        #expect(today == h.defaut.today)
        let tikkunDefaut = Store.jourTikkun(Fuseau.utc.dateHeure(millis: midi)).iso
        #expect(tikkunDefaut == h.defaut.jourTikkun)
        for r in h.regles {
            let fuseau: Fuseau = try #require(Fuseau(r.fuseau))
            let instant = fuseau.millis(dateHeure(r.civile))
            #expect(instant == r.millis, "\(r.civile) \(r.fuseau)")
            let jour = Store.today(millis: r.millis, fuseau: fuseau).iso
            #expect(jour == r.today, "\(r.civile) \(r.fuseau)")
            let tikkun = Store.jourTikkun(fuseau.dateHeure(millis: r.millis)).iso
            #expect(tikkun == r.jourTikkun, "\(r.civile) \(r.fuseau)")
        }
    }

    @Test func lesDureesSEcriventCommeSurAndroid() throws {
        let catalogue = try Catalogue.lire()
        var simplesParLangue: [String: [String: String]] = [:]
        var plurielsParLangue: [String: [String: String]] = [:]
        for langue in Catalogue.langues {
            simplesParLangue[langue] = catalogue.simples(langue)
            plurielsParLangue[langue] = catalogue.pluriels(langue)
        }
        let cas = try fichier().formats
        #expect(cas.count == 26)
        for c in cas {
            let heure = Store.formatMinutes(c.minutes)
            #expect(heure == c.formatMinutes, "formatMinutes(\(c.minutes))")
            for (langue, attendu) in [("fr", c.fr), ("en", c.en), ("he", c.he)] {
                let simples = simplesParLangue[langue] ?? [:]
                let pluriels = plurielsParLangue[langue] ?? [:]
                let texte = Store.formatDuration(c.minutes).texte(langue: langue, chaine: { simples[$0] }, pluriel: { pluriels["\($0)[\($1)]"] })
                let conforme = texte?.egalUnites(attendu) == true
                #expect(conforme, "formatDuration(\(c.minutes)) en \(langue) : \(texte ?? "nil") au lieu de \(attendu)")
            }
        }
    }

    @Test func uneDureeEstUnLibelleDesChaines() {
        let minutes = Store.formatDuration(45)
        let minutesAttendu = Libelle("duration_minutes", .entier(45))
        #expect(minutes == minutesAttendu)
        let heures = Store.formatDuration(120)
        let heuresAttendu = Libelle("duration_hours", .entier(2))
        #expect(heures == heuresAttendu)
        let melange = Store.formatDuration(90)
        let melangeAttendu = Libelle("duration_hours_minutes", .entier(1), .entier(30))
        #expect(melange == melangeAttendu)
    }

    @Test func ajouterDuTempsSeFaitJusquAAujourdhuiJamaisApres() {
        let aujourdhui = JourCivil.du("2026-11-15")
        let hier = AjoutTemps.possible(JourCivil.du("2026-11-14"), aujourdhui: aujourdhui)
        #expect(hier)
        let ceJour = AjoutTemps.possible(aujourdhui, aujourdhui: aujourdhui)
        #expect(ceJour)
        let demain = AjoutTemps.possible(JourCivil.du("2026-11-16"), aujourdhui: aujourdhui)
        #expect(!demain)
    }

    // MARK: Fiabilite2Test, par des valeurs

    @Test func uneNoteSeuleEffaceeDisparaitDuJournal() {
        var journal = Journal()
        let jour = JourCivil.du("2026-10-01")
        Store.setNote(journal: &journal, date: jour, note: "une pensée")
        let seule = journal.record(jour)?.noteSeule
        #expect(seule == true)
        Store.setNote(journal: &journal, date: jour, note: "   ")
        let apres = journal.record(jour)
        #expect(apres == nil)
        let texte = journal.daysTexte
        #expect(texte == "{}")
    }

    @Test func lesNotesOntUneLongueur() {
        #expect(Store.noteMax == 4000)
        var journal = Journal()
        let jour = JourCivil.du("2026-10-01")
        Store.setNote(journal: &journal, date: jour, note: String(repeating: "a", count: 4100))
        let longueur = journal.record(jour)?.note.utf16.count
        #expect(longueur == 4000)
    }

    @Test func israelOuDiasporaEstFigeAuPremierAcces() {
        var reglages = Reglages()
        let premier = reglages.figeInIsrael(fuseauTelephone: "Asia/Jerusalem")
        #expect(premier)
        // Un voyage ne change plus le deuxième jour de fête : la valeur figée l'emporte sur le fuseau.
        let apresVoyage = Store.isExempt(reglages: reglages, date: JourCivil.du("2026-09-27"), fuseauTelephone: "Europe/Paris")
        #expect(!apresVoyage)
        let diaspora = Store.isExempt(reglages: Reglages(), date: JourCivil.du("2026-09-27"), fuseauTelephone: "Europe/Paris")
        #expect(diaspora)
    }
}
