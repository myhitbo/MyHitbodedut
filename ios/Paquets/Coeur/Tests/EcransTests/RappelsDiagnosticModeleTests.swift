import Foundation
import Testing
import Coeur
@testable import Ecrans

/// L'écran de diagnostic des notifications en attente (propre à iOS, ROADMAP tâche 19 ; recette R3, geste 6) : ce
/// que le centre tient en attente, comparé au plan que le planificateur poserait maintenant, les rappels qui
/// tomberaient un jour de repos ou un jour fait, et le compte de chaque catégorie. Le plan lui-même est jugé dans
/// CoeurTests (PlanNotificationsTests).
@Suite("Diagnostic des notifications")
@MainActor
struct RappelsDiagnosticModeleTests {

    /// Lundi 23 novembre 2026, 8 h, en temps universel.
    private static func horloge() throws -> HorlogeFixe {
        let lundi = try #require(JourCivil(annee: 2026, mois: 11, jour: 23))
        return HorlogeFixe(DateHeure(lundi, heure: 8), fuseau: .utc)
    }

    /// Le rappel allumé à 21 h, Chabbat chômé (le réglage par défaut).
    private static func reglages() -> Reglages {
        var r = Reglages()
        r.setReminderEnabled(true)
        r.setReminderTimes([21 * 60])
        return r
    }

    private static func modele(_ attente: [RappelsNotificationEnAttente],
                               accordee: Bool = true) throws -> RappelsDiagnosticModele {
        try RappelsDiagnosticModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages())),
                                    horloge: horloge(), notificateur: FauxNotificateur(accordee: accordee),
                                centre: RappelsFauxCentreNotifications(attente), langue: "fr")
    }

    /// Le plan d'aujourd'hui tel que le centre le tiendrait s'il venait d'être posé.
    private static func plan() throws -> [NotificationPlanifiee] {
        let h = try horloge()
        return RappelsDiagnosticModele.planAttendu(reglages: reglages(), journal: Journal(), maintenant: h.maintenant,
                                                   fuseau: h.fuseau)
    }

    private static func enAttente(_ n: NotificationPlanifiee, decalage: Int64 = 0) -> RappelsNotificationEnAttente {
        RappelsNotificationEnAttente(identifiant: n.identifiant, titre: "titre", corps: "corps",
                                     instant: n.instant + decalage, instantFixe: true,
                                     categorie: n.categorie.rawValue)
    }

    /// Samedi 28 novembre 2026 à 21 h, en millisecondes Unix.
    private static func samedi21h() throws -> Int64 {
        let samedi = try #require(JourCivil(annee: 2026, mois: 11, jour: 28))
        return Fuseau.utc.millis(DateHeure(samedi, heure: 21))
    }

    // MARK: Le plan

    /// Le plan du banc : des rappels de 21 h sur dix jours, ni le vendredi soir (veille de Chabbat, après midi) ni
    /// le samedi.
    @Test func lePlanDuBancTaitLeVendrediSoirEtLeSamedi() throws {
        let plan = try Self.plan()
        let rappels = plan.filter { $0.categorie == .rappel }
        #expect(!rappels.isEmpty)
        let jours = Set(rappels.map { Fuseau.utc.jour(millis: $0.instant).jourDeSemaine })
        #expect(!jours.contains(6))
        #expect(!jours.contains(7))
    }

    // MARK: La comparaison

    @Test func unCentreConformeAuPlan() async throws {
        let plan = try Self.plan()
        let m = try Self.modele(plan.map { Self.enAttente($0) })
        #expect(!m.charge)
        await m.charger()
        #expect(m.charge)
        #expect(!m.enCours)
        #expect(m.nombreEnAttente == plan.count)
        #expect(m.lignes.count == plan.count)
        let ecarts = Set(m.lignes.map { $0.ecart })
        #expect(ecarts == [.conforme])
        #expect(m.nombreDeProblemes == 0)
        #expect(m.verdict == Libelle("rappels_diagnostic_verdict_conforme"))
        #expect(m.resume == Libelle("rappels_diagnostic_resume", .entier(plan.count), .entier(64)))
        #expect(m.avertissement == nil)
        #expect(m.lecture == "2026-11-23 08:00")
        let instants = m.lignes.compactMap { $0.instant }
        #expect(instants == instants.sorted())
    }

    @Test func lesEcartsAvecLePlan() async throws {
        let plan = try Self.plan()
        #expect(plan.count >= 3)
        let absente = plan[0]
        let decalee = plan[1]
        var attente = [Self.enAttente(decalee, decalage: 60_000)]
        attente += plan.dropFirst(2).map { Self.enAttente($0) }
        // Une pose ancienne, hors du plan, un samedi : rien ne doit sonner le Chabbat.
        let samedi = try Self.samedi21h()
        attente.append(RappelsNotificationEnAttente(identifiant: "rappel-" + String(samedi), titre: "t", corps: "c",
                                                    instant: samedi, instantFixe: true, categorie: "rappel"))
        // Le « Mazal tov ! » de la fin de séance, posé hors du plan, sur un délai.
        attente.append(RappelsNotificationEnAttente(identifiant: SeanceEnCours.identifiantFete, titre: "Mazal tov",
                                                    corps: "", instant: nil, instantFixe: false, categorie: nil))
        let m = try Self.modele(attente)
        await m.charger()

        let parId = Dictionary(uniqueKeysWithValues: m.lignes.map { ($0.identifiant, $0) })
        let lAbsente = try #require(parId[absente.identifiant])
        #expect(lAbsente.ecart == .absente)
        #expect(lAbsente.titre == .libelle(absente.titre))
        #expect(lAbsente.instant == absente.instant)
        let lDecalee = try #require(parId[decalee.identifiant])
        #expect(lDecalee.ecart == .instantDifferent)
        #expect(lDecalee.titre == .brut("titre"))
        let lSamedi = try #require(parId["rappel-" + String(samedi)])
        #expect(lSamedi.ecart == .horsPlan)
        #expect(lSamedi.silenceEnfreint)
        #expect(lSamedi.categorie == .rappel)
        #expect(lSamedi.quand == "Samedi 2026-11-28 21:00")
        let lFete = try #require(parId[SeanceEnCours.identifiantFete])
        #expect(lFete.ecart == .gardee)
        #expect(!lFete.probleme)
        #expect(lFete.categorie == nil)
        #expect(lFete.quand == "—")
        #expect(lFete.libelleCategorie == Libelle("rappels_categorie_autre"))

        // L'absente, la décalée, celle du samedi.
        #expect(m.nombreDeProblemes == 3)
        #expect(m.verdict == Libelle("rappels_diagnostic_verdict_ecarts", .entier(3)))
        #expect(m.nombreEnAttente == attente.count)
        // La fête, sans instant, en dernier.
        let derniere = try #require(m.lignes.last)
        #expect(derniere.identifiant == SeanceEnCours.identifiantFete)
    }

    /// Un délai : iOS compte son prochain déclenchement depuis la lecture, il ne se compare pas au plan.
    @Test func unDelaiNeSeComparePasALInstantDuPlan() async throws {
        let plan = try Self.plan()
        let premiere = try #require(plan.first)
        let delai = RappelsNotificationEnAttente(identifiant: premiere.identifiant, titre: "t", corps: "c",
                                                 instant: premiere.instant + 3_600_000, instantFixe: false,
                                                 categorie: premiere.categorie.rawValue)
        let m = try Self.modele([delai] + plan.dropFirst().map { Self.enAttente($0) })
        await m.charger()
        let trouvee = m.lignes.first { $0.identifiant == premiere.identifiant }
        let ligne = try #require(trouvee)
        #expect(ligne.ecart == .conforme)
    }

    /// Une seconde d'écart au plus : le déclencheur de calendrier garde la seconde.
    @Test func moinsDUneSecondeDEcartEstConforme() async throws {
        let plan = try Self.plan()
        let m = try Self.modele(plan.map { Self.enAttente($0, decalage: 999) })
        await m.charger()
        #expect(m.nombreDeProblemes == 0)
    }

    @Test func unRappelPermisNEstPasSignale() async throws {
        let plan = try Self.plan()
        let m = try Self.modele(plan.map { Self.enAttente($0) })
        await m.charger()
        let silences = m.lignes.filter { $0.silenceEnfreint }
        #expect(silences.isEmpty)
    }

    /// Un rappel un jour déjà fait : signalé.
    @Test func unRappelUnJourFaitEstSignale() throws {
        let lundi = try #require(JourCivil(annee: 2026, mois: 11, jour: 23))
        var journal = Journal()
        var reglages = Self.reglages()
        let h = try Self.horloge()
        Store.addSession(journal: &journal, reglages: &reglages, minutes: 10, millis: h.maintenant, fuseau: h.fuseau)
        let soir = DateHeure(lundi, heure: 21)
        let fait = RappelsDiagnosticModele.permis(soir, reglages: reglages, journal: journal, fuseau: .utc)
        #expect(!fait)
        let libre = RappelsDiagnosticModele.permis(soir, reglages: reglages, journal: Journal(), fuseau: .utc)
        #expect(libre)
    }

    // MARK: Le résumé

    @Test func lesComptesSuiventLesCategoriesDuPlan() async throws {
        let plan = try Self.plan()
        var attente = plan.map { Self.enAttente($0) }
        attente.append(RappelsNotificationEnAttente(identifiant: "autre", titre: "", corps: "", instant: nil,
                                                    instantFixe: false, categorie: nil))
        let m = try Self.modele(attente)
        await m.charger()
        let comptes = m.comptes
        let categories = comptes.map { $0.categorie }
        let attendues: [NotificationPlanifiee.Categorie?] = NotificationPlanifiee.Categorie.allCases + [nil]
        #expect(categories == attendues)
        let rappel = try #require(comptes.first)
        let nombreDeRappels = plan.filter { $0.categorie == .rappel }.count
        #expect(rappel.nombre == nombreDeRappels)
        #expect(rappel.part == 30)
        #expect(rappel.texte == String(nombreDeRappels) + " / 30")
        let autre = try #require(comptes.last)
        #expect(autre.texte == "1")
        #expect(autre.libelleCategorie == Libelle("rappels_categorie_autre"))
    }

    @Test func sansNotificationHorsDuPlanPasDeCompteAutre() async throws {
        let m = try Self.modele([])
        await m.charger()
        let categories = m.comptes.map { $0.categorie }
        let attendues: [NotificationPlanifiee.Categorie?] = NotificationPlanifiee.Categorie.allCases
        #expect(categories == attendues)
        #expect(m.nombreEnAttente == 0)
    }

    @Test func lesNotificationsRefuseesSontDites() async throws {
        let m = try Self.modele([], accordee: false)
        await m.charger()
        #expect(m.avertissement == Libelle("reminders_permission_missing"))
    }

    @Test func lesJoursSEcriventDansLaLangueDeLApp() async throws {
        let samedi = try Self.samedi21h()
        let attente = [RappelsNotificationEnAttente(identifiant: "x", titre: "", corps: "", instant: samedi,
                                                    instantFixe: true, categorie: "chabbat")]
        let m = try RappelsDiagnosticModele(magasin: Magasin.enMemoire(), horloge: Self.horloge(),
                                            notificateur: FauxNotificateur(),
                                            centre: RappelsFauxCentreNotifications(attente), langue: "en")
        await m.charger()
        // Le plan des réglages par défaut peut tenir des rappels de Birkat haLevana : la ligne se cherche.
        let trouvee = m.lignes.first { $0.identifiant == "x" }
        let ligne = try #require(trouvee)
        #expect(ligne.quand == "Saturday 2026-11-28 21:00")
        #expect(ligne.categorie == .chabbat)
        // Ni rappel ni Chabbat chômé : la règle du silence ne vaut que pour les rappels de hitbodedout.
        #expect(!ligne.silenceEnfreint)
    }

    // MARK: Les chaînes

    /// Les chaînes neuves sont dans ios.xcstrings, en trois langues, sans doubler une clé d'Android.
    @Test func chaqueCleEstAuCatalogueEnTroisLangues() async throws {
        let android = try CatalogueBrut.lire()
        let ios = try JSONDecoder().decode(CatalogueBrut.self,
                                           from: Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings"))
        let m = try Self.modele([])
        await m.charger()
        var neuves = [m.titre.cle, m.resume.cle, m.verdict.cle, "rappels_diagnostic_verdict_ecarts",
                      m.libelleActualiser.cle, m.libelleVide.cle, "rappels_diagnostic_silence",
                      "rappels_categorie_autre"]
        neuves += RappelsEcart.allCases.map { "rappels_diagnostic_" + $0.rawValue }
        neuves += NotificationPlanifiee.Categorie.allCases.map { "rappels_categorie_" + $0.rawValue }
        #expect(neuves.count == 18)
        for cle in neuves {
            let chezAndroid = android.strings[cle] != nil
            #expect(!chezAndroid, "« \(cle) » existe déjà chez Android")
            for langue in Traducteur.langues {
                let valeur = ios.valeur(cle, langue: langue) ?? ""
                #expect(!valeur.isEmpty, "« \(cle) » manque en \(langue)")
            }
        }
    }
}
