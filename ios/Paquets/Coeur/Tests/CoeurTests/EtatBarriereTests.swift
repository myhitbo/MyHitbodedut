import Foundation
import Testing
import Barriere
@testable import Coeur

// GateStatus.kt n'a pas de test d'Android. Ici : titleOf, colorOf et detailOf rejouent barriere.json
// (VecteursBarriere.kt : noms de ressources, détail résolu dans les trois langues pour 0, 1, 2, 3 et 51
// applications) ; les chaînes des cinq états d'iOS sont dans ios.xcstrings ; l'instantané que l'app dépose
// (EtatBarriere) est confronté aux règles de Store qu'il remplace dans les extensions. Reste à Android :
// `shouldRunService` et `Permissions.allGranted`, qui lisent le téléphone (iOS : `Constat.autorise`).

/// ios.xcstrings : le catalogue des chaînes propres à iOS, au format String Catalog.
private struct CatalogueIos: Decodable {
    struct Unite: Decodable {
        let state: String
        let value: String
    }
    struct Localisation: Decodable { let stringUnit: Unite }
    struct Entree: Decodable { let localizations: [String: Localisation] }
    let sourceLanguage: String
    let strings: [String: Entree]

    static func lire() throws -> CatalogueIos {
        try JSONDecoder().decode(CatalogueIos.self, from: Depot.donnees("ios/Ressources/Chaines/ios.xcstrings"))
    }

    func simples(_ langue: String) -> [String: String] {
        strings.compactMapValues { $0.localizations[langue]?.stringUnit.value }
    }
}

/// Une langue de l'app : les deux catalogues, repli sur le français comme Android sur values/.
private struct LangueBarriere {
    let code: String
    let simples: [String: String]
    let pluriels: [String: String]
    let simplesFr: [String: String]
    let plurielsFr: [String: String]

    init(_ code: String, _ catalogue: Catalogue, _ ios: CatalogueIos) {
        self.code = code
        simples = catalogue.simples(code).merging(ios.simples(code)) { android, _ in android }
        pluriels = catalogue.pluriels(code)
        simplesFr = catalogue.simples("fr").merging(ios.simples("fr")) { android, _ in android }
        plurielsFr = catalogue.pluriels("fr")
    }

    func texte(_ libelle: Libelle) -> String? {
        libelle.texte(langue: code,
                      chaine: { simples[$0] ?? simplesFr[$0] },
                      pluriel: { pluriels["\($0)[\($1)]"] ?? plurielsFr["\($0)[\($1)]"] })
    }
}

@Suite struct EtatBarriereTests {

    private struct Vecteurs: Decodable {
        struct Ligne: Decodable {
            let etat: String
            let titre: String
            let couleur: String
        }
        struct Detail: Decodable {
            let langue: String
            let debut: Int
            let fin: Int
            let applications: Int
            let textes: [String]
        }
        let etats: [Ligne]
        let details: [Detail]
    }

    // MARK: GateStatus : la carte d'état

    /// Tout barriere.json : le titre et la couleur des huit états d'Android, puis le détail résolu sur le
    /// catalogue exporté, langue par langue.
    @Test func rejoueLesVecteursDeGateStatus() throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Depot.donnees("ios/Paquets/Coeur/Tests/Vecteurs/barriere.json"))
        let nombreDEtats = v.etats.count
        #expect(nombreDEtats == 8)
        var etats: [GateState] = []
        for ligne in v.etats {
            let etat = try #require(GateState(rawValue: ligne.etat), "\(ligne.etat)")
            etats.append(etat)
            let titre = GateStatus.titleOf(etat).cle
            #expect(titre == ligne.titre, "\(ligne.etat)")
            let couleur = GateStatus.colorOf(etat)
            #expect(couleur == ligne.couleur, "\(ligne.etat)")
            #expect(etat.android, "\(ligne.etat)")
        }

        let catalogue = try Catalogue.lire()
        let ios = try CatalogueIos.lire()
        var langues: [String: LangueBarriere] = [:]
        for code in Catalogue.langues {
            langues[code] = LangueBarriere(code, catalogue, ios)
        }
        let nombreDeDetails = v.details.count
        #expect(nombreDeDetails == 3 * 5 * 5)
        for d in v.details {
            let langue = try #require(langues[d.langue], "\(d.langue)")
            let nombreDeTextes = d.textes.count
            #expect(nombreDeTextes == etats.count)
            for (rang, etat) in etats.enumerated() where rang < d.textes.count {
                let libelle = GateStatus.detailOf(etat, applications: d.applications, windowStart: d.debut, windowEnd: d.fin)
                let texte = langue.texte(libelle)
                #expect(texte == d.textes[rang], "\(d.langue), \(etat.rawValue), \(d.applications) applications, \(d.debut)–\(d.fin)")
            }
        }
    }

    /// Sur iOS, « N applications » compte les jetons de la sélection (une catégorie vaut un).
    @Test func leDetailDeLInstantaneCompteLesJetons() throws {
        var etat = Etat()
        etat.nombreDeJetons = 51
        etat.windowStart = 21 * 60
        etat.windowEnd = 2 * 60
        let langue = try LangueBarriere("fr", Catalogue.lire(), CatalogueIos.lire())
        let veille = langue.texte(GateStatus.detailOf(.armed, etat: etat))
        #expect(veille == "51 applications sont bloquées jusqu’à 02:00 ou jusqu’à votre hitbodedout.")
        let dehors = langue.texte(GateStatus.detailOf(.outsideWindow, etat: etat))
        #expect(dehors == "Le mode agit entre 21:00 et 02:00. En dehors, rien n’est retenu.")
    }

    /// Les treize états ont chacun leur titre et leur détail ; ceux d'iOS sont dans ios.xcstrings, dans les
    /// trois langues, à relire par le propriétaire ; ceux d'Android dans le catalogue exporté.
    @Test func chaqueEtatADesChainesDansLesTroisLangues() throws {
        let catalogue = try Catalogue.lire()
        let ios = try CatalogueIos.lire()
        #expect(ios.sourceLanguage == "fr")
        var titres = Set<String>()
        var details = Set<String>()
        var cles: [(cle: String, android: Bool)] = []
        for etat in GateState.allCases {
            let titre = GateStatus.titleOf(etat).cle
            let detail = GateStatus.detailOf(etat, applications: 3, windowStart: 360, windowEnd: 660).cle
            titres.insert(titre)
            details.insert(detail)
            cles.append((titre, etat.android))
            cles.append((detail, etat.android))
        }
        let nombreDeTitres = titres.count
        #expect(nombreDeTitres == 13)
        let nombreDeDetails = details.count
        #expect(nombreDeDetails == 13)
        cles.append(("bouclier_autre_reponse", false))
        cles.append(("bouclier_notification_commencer", false))
        for code in Catalogue.langues {
            let simples = catalogue.simples(code)
            let pluriels = catalogue.pluriels(code)
            for (cle, android) in cles {
                if android {
                    let presente = simples[cle] != nil || pluriels["\(cle)[other]"] != nil
                    #expect(presente, "\(code) : \(cle)")
                    let doublon = ios.strings[cle] != nil
                    #expect(!doublon, "\(cle) est une chaîne d'Android")
                } else {
                    let unite = ios.strings[cle]?.localizations[code]?.stringUnit
                    let valeur = unite?.value ?? ""
                    #expect(!valeur.isEmpty, "\(code) : \(cle)")
                    let etatDeRelecture = unite?.state
                    #expect(etatDeRelecture == "needs_review", "\(code) : \(cle)")
                    let absente = simples[cle] == nil
                    #expect(absente, "\(cle) existe déjà dans Localizable.xcstrings")
                }
            }
        }
    }

    @Test func lesCouleursDesEtatsDIos() {
        let attendu: [GateState: String] = [
            .autorisationRetiree: "warning", .selectionARefaire: "warning", .surveillanceAbsente: "warning",
            .surveillanceMuette: "warning", .bouclierDesaccorde: "muted",
        ]
        for (etat, couleur) in attendu {
            let lue = GateStatus.colorOf(etat)
            #expect(lue == couleur, "\(etat.rawValue)")
        }
    }

    // MARK: Les jours exemptés des deux années à venir (§ 2.1.7)

    @Test func lesJoursExemptesDesDeuxAnneesAVenir() throws {
        let depuis = JourCivil.du("2026-11-16")
        var diaspora = Reglages()
        diaspora.setInIsrael(false)
        let jours = EtatBarriere.joursExemptes(reglages: diaspora, depuis: depuis, fuseauTelephone: "Europe/Paris")
        let ensemble = Set(jours)
        var samedis = 0
        var ecarts: [String] = []
        for n in 0..<EtatBarriere.horizon {
            let jour = depuis.plus(jours: n)
            let chome = Holidays.isRestDay(jour, inIsrael: false)
            if ensemble.contains(jour) != chome { ecarts.append(jour.iso) }
            if jour.jourDeSemaine == 7 {
                samedis += 1
                if !ensemble.contains(jour) { ecarts.append("samedi " + jour.iso) }
            }
        }
        #expect(ecarts.isEmpty, "\(ecarts)")
        #expect(samedis == 104)
        let nombre = jours.count
        #expect(nombre > 110 && nombre < 160, "\(nombre) jours")
        let tries = jours.sorted()
        #expect(jours == tries)
        let premier = jours.first
        let premierSamedi = JourCivil.du("2026-11-21")
        #expect(premier == premierSamedi)

        // En Israël, pas de deuxième jour de fête : moins de jours.
        var israel = Reglages()
        israel.setInIsrael(true)
        let enIsrael = EtatBarriere.joursExemptes(reglages: israel, depuis: depuis, fuseauTelephone: "Europe/Paris").count
        #expect(enIsrael < nombre)
        #expect(enIsrael >= 104)

        // « Chabbat et Yom Tov » éteint : aucun.
        var sansChabbat = Reglages()
        sansChabbat.setShabbatMode(false)
        let aucun = EtatBarriere.joursExemptes(reglages: sansChabbat, depuis: depuis, fuseauTelephone: "Europe/Paris")
        #expect(aucun.isEmpty)
    }

    // MARK: L'instantané

    @Test func lInstantaneDeLApp() throws {
        let paris = try #require(Fuseau("Europe/Paris"))
        let catalogue = try Catalogue.lire()
        let fr = try LangueBarriere("fr", catalogue, CatalogueIos.lire())
        let lundi = JourCivil.du("2026-11-16")
        var reglages = Reglages()
        reglages.setEnabled(true)
        reglages.setWindow(startMinutes: 21 * 60, endMinutes: 2 * 60)
        reglages.setSnoozeMinutes(5)
        reglages.setTargetMinutes(20)
        reglages.togglePausedDate("2026-12-01")
        reglages.togglePausedDate("2026-11-30")
        var journal = Journal()
        Store.addSession(journal: &journal, reglages: &reglages, minutes: 15,
                         millis: paris.millis(DateHeure(lundi.plus(jours: -1), heure: 8)), fuseau: paris)
        let seance = paris.millis(DateHeure(lundi, heure: 21, minute: 30))
        Store.addSession(journal: &journal, reglages: &reglages, minutes: 15, millis: seance, fuseau: paris)
        let maintenant = paris.millis(DateHeure(lundi, heure: 22))
        Store.snooze(reglages: &reglages, millis: maintenant)

        let etat = EtatBarriere.etat(journal: journal, reglages: reglages, millis: maintenant, fuseau: paris,
                                     nombreDeJetons: 4) { fr.texte($0) ?? "?" }
        #expect(etat.version == Etat.versionActuelle)
        #expect(etat.ecritA == maintenant)
        #expect(etat.enabled)
        #expect(etat.windowStart == 21 * 60)
        #expect(etat.windowEnd == 2 * 60)
        #expect(etat.snoozeMinutes == 5)
        #expect(etat.snoozedUntil == maintenant + 5 * 60_000)
        #expect(etat.chabbat)
        #expect(etat.exemptesDepuis == "2026-11-16")
        let jusquau = lundi.plus(jours: EtatBarriere.horizon - 1).iso
        #expect(etat.exemptesJusquau == jusquau)
        #expect(etat.exemptesJusquau == "2028-11-15")
        let premierExempte = etat.joursExemptes.first
        #expect(premierExempte == "2026-11-21")
        #expect(etat.joursEnPause == ["2026-11-30", "2026-12-01"])
        #expect(etat.journee.jours == ["2026-11-15", "2026-11-16"])
        let faitA = etat.journee.faitA
        #expect(faitA == Horodatage(millis: seance, jour: "2026-11-16", minutes: 21 * 60 + 30))
        #expect(etat.seance == nil)
        #expect(etat.nombreDeJetons == 4)
        #expect(etat.bouclier.question == "Avez-vous fait votre hitbodedout\u{202F}?")
        #expect(etat.bouclier.serie == "Série en cours\u{00A0}: 2 jours")
        #expect(etat.bouclier.commencer == "Commencer maintenant, 20 min")
        #expect(etat.bouclier.plusTard == "Plus tard (5 min)")
        #expect(etat.bouclier.dejaFaite == "Je l’ai déjà faite")
        #expect(etat.bouclier.autreReponse == "Autre réponse")
        #expect(etat.bouclier.apercu == "APERÇU, AUCUN EFFET")
        #expect(etat.bouclier.notificationCommencer == "Touchez pour commencer votre hitbodedout")

        // La séance de 21 h 30 valide la nuit ; l'extension le voit sans le journal.
        let donnees = try etat.donnees()
        let lu = try #require(Etat.lire(donnees))
        let verdict = GateStatus.evaluate(lu, maintenant: EtatBarriere.horodatage(millis: maintenant, fuseau: paris))
        #expect(verdict == .alreadyDone)

        // Une séance en cours est déposée ; aucune série : la phrase du premier jour.
        var enSeance = Reglages()
        Store.beginSession(reglages: &enSeance, minutes: 20, millis: maintenant)
        let pendant = EtatBarriere.etat(journal: Journal(), reglages: enSeance, millis: maintenant + 60_000, fuseau: paris,
                                        nombreDeJetons: -1) { fr.texte($0) ?? "?" }
        let debut = pendant.seance?.debut
        #expect(debut == maintenant)
        let duree = pendant.seance?.minutes
        #expect(duree == 20)
        #expect(pendant.nombreDeJetons == 0)
        #expect(pendant.bouclier.serie == "Première journée de la série.")
        #expect(!pendant.enabled)
    }

    /// L'instant vu par Fuseau (règles de java.time) et par TimeZone (l'extension) : le même jour, la même minute.
    @Test func lesDeuxLecturesDUnInstantSAccordent() throws {
        for identifiant in ["Europe/Paris", "Asia/Jerusalem", "America/New_York", "Australia/Melbourne", "UTC"] {
            let fuseau = try #require(Fuseau(identifiant))
            let zone = try #require(TimeZone(identifier: identifiant))
            for millis: Int64 in [0, -1, 1_774_746_000_000, 1_774_749_600_000, 1_792_890_000_000, 1_792_893_600_000,
                                  1_794_810_000_000, 1_800_000_000_000] {
                let parFuseau = EtatBarriere.horodatage(millis: millis, fuseau: fuseau)
                let parZone = Horodatage(millis: millis, fuseau: zone)
                #expect(parFuseau == parZone, "\(identifiant) \(millis)")
            }
        }
    }

    /// GateStatus.evaluate, sur l'instantané, contre la chaîne de GateStatus.kt écrite avec les règles de
    /// Store déjà portées (fenetreFaite, isExempt, isSnoozed, inWindow) : une fenêtre de nuit, trois semaines
    /// autour de Pessa'h 5787, des séances, des reports et une pause, onze instants par jour.
    @Test func laBarriereSuitLesReglesDuStore() throws {
        let paris = try #require(Fuseau("Europe/Paris"))
        var reglages = Reglages()
        reglages.setEnabled(true)
        reglages.setWindow(startMinutes: 21 * 60, endMinutes: 2 * 60)
        reglages.setSnoozeMinutes(60)
        reglages.togglePausedDate("2027-04-28")
        var journal = Journal()
        let debut = JourCivil.du("2027-04-12")
        let fixe = EtatBarriere.etat(journal: journal, reglages: reglages, millis: paris.millis(DateHeure(debut, heure: 12)),
                                     fuseau: paris, nombreDeJetons: 2) { $0.cle }
        let heures: [(Int, Int)] = [(0, 30), (1, 59), (2, 0), (12, 0), (20, 59), (21, 0), (21, 31), (22, 1), (22, 30),
                                     (23, 15), (23, 59)]
        var ecarts: [String] = []
        var vus = Set<GateState>()
        var compte = 0
        for n in 0..<21 {
            let jour = debut.plus(jours: n)
            for (heure, minute) in heures {
                if heure == 21, minute == 31, n % 3 == 0 {
                    Store.addSession(journal: &journal, reglages: &reglages, minutes: 10,
                                     millis: paris.millis(DateHeure(jour, heure: 21, minute: 30)), fuseau: paris)
                }
                if heure == 22, minute == 1, n % 4 == 1 {
                    Store.snooze(reglages: &reglages, millis: paris.millis(DateHeure(jour, heure: 22)))
                }
                let millis = paris.millis(DateHeure(jour, heure: heure, minute: minute))
                var etat = fixe
                etat.snoozedUntil = reglages.snoozedUntil
                etat.journee = EtatBarriere.journee(journal: journal, reglages: reglages, millis: millis, fuseau: paris)
                let maintenant = EtatBarriere.horodatage(millis: millis, fuseau: paris)
                let barriere = GateStatus.evaluate(etat, maintenant: maintenant)
                let attendu = regleDuStore(journal, reglages, millis, paris)
                if barriere != attendu {
                    ecarts.append("\(maintenant.jour) \(heure):\(minute) : \(barriere.rawValue) au lieu de \(attendu.rawValue)")
                }
                vus.insert(barriere)
                compte += 1
            }
        }
        #expect(ecarts.isEmpty, "\(ecarts)")
        #expect(compte == 21 * 11)
        let attendus: Set<GateState> = [.alreadyDone, .exemptDay, .snoozed, .outsideWindow, .armed]
        #expect(vus == attendus)
    }

    /// La chaîne de GateStatus.evaluate après les autorisations, avec les règles de Store.
    private func regleDuStore(_ journal: Journal, _ reglages: Reglages, _ millis: Int64, _ fuseau: Fuseau) -> GateState {
        if !reglages.isEnabled { return .disabled }
        if Store.fenetreFaite(journal: journal, reglages: reglages, millis: millis, fuseau: fuseau) { return .alreadyDone }
        if Store.isExempt(reglages: reglages, date: fuseau.jour(millis: millis), fuseauTelephone: fuseau.identifiant) {
            return .exemptDay
        }
        if Store.isSnoozed(reglages: reglages, millis: millis) { return .snoozed }
        if !Store.inWindow(reglages: reglages, maintenant: fuseau.dateHeure(millis: millis)) { return .outsideWindow }
        return .armed
    }
}
