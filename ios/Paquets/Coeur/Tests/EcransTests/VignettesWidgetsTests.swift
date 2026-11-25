import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les widgets de la série et des zmanim (StreakWidget.kt, ZmanimVignette.kt) : ce qu'ils montrent dans chaque état,
/// quand ils changent, et que leurs clés sont au catalogue. Ce que Chronologies calcule (la prière du moment, la
/// bascule du jour hébreu à tsét) est jugé dans CoeurTests par les vecteurs de la JVM ; restent aux captures le
/// dessin des trois familles et de l'écran verrouillé.
@Suite("Widgets de la série et des zmanim")
struct VignettesWidgetsTests {

    /// Lundi 16 novembre 2026 ; Chabbat le 21.
    static let lundi = "2026-11-16"

    static func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    static func instant(_ iso: String, _ heure: Int, _ minute: Int = 0) throws -> Int64 {
        let date = try jour(iso)
        return Fuseau.utc.millis(DateHeure(date, heure: heure, minute: minute))
    }

    // MARK: La série

    @Test func sansRienFait() throws {
        var r = Reglages()
        r.setShabbatMode(true)
        let maintenant = try Self.instant(Self.lundi, 10)
        let a = VignetteSerie.affichage(journal: Journal(), reglages: r, maintenant: maintenant,
                                        fuseauTelephone: .utc, chizuk: nil, langue: "fr")
        let lundi = try Self.jour(Self.lundi)
        #expect(a.aujourdhui == lundi)
        #expect(a.serie == 0)
        #expect(!a.fait)
        #expect(!a.repos)
        #expect(!a.flammeAllumee)
        #expect(a.seance == nil)
        #expect(!a.compteurMontre)
        #expect(a.salutation == Libelle("widget_todo"))
        #expect(a.lectureSerie == Libelle("status_streak_none"))
        #expect(a.bouton == Libelle("widget_start"))
        #expect(a.destinationBouton == .commencer)
        #expect(a.destination == .accueil)
        #expect(a.personnage == "char_welcome")
        #expect(a.texteDuJour == nil)
        let objectif = r.dailyGoal
        #expect(a.minutes == Libelle("widget_minutes", .entier(0), .entier(objectif)))
        #expect(a.minutesFaites == 0)
        // La semaine, du dimanche au samedi : dimanche passé, lundi aujourd'hui, la suite à venir, Chabbat au repos.
        let etats = a.semaine.map(\.etat)
        #expect(etats == [.passe, .aujourdhui, .avenir, .avenir, .avenir, .avenir, .repos])
        let marques = a.semaine.map(\.marque)
        #expect(marques == [.aucune, .aucune, .aucune, .aucune, .aucune, .aucune, .chabbat])
        let aujourdhui = a.semaine.map(\.estAujourdhui)
        #expect(aujourdhui == [false, true, false, false, false, false, false])
    }

    @Test func faitAvecPrenom() throws {
        var j = Journal()
        j.addSession(minutes: 10, date: try Self.jour("2026-11-15"))
        j.addSession(minutes: 25, date: try Self.jour(Self.lundi))
        j.setFirstName("David")
        let r = Reglages()
        let lundi = try Self.jour(Self.lundi)
        let a = VignetteSerie.affichage(journal: j, reglages: r, maintenant: try Self.instant(Self.lundi, 10),
                                        fuseauTelephone: .utc, chizuk: nil, langue: "fr")
        #expect(a.serie == 2)
        #expect(a.fait)
        #expect(a.flammeAllumee)
        #expect(a.salutation == Libelle("hero_greeting_morning", .texte("David")))
        #expect(a.lectureSerie == Libelle.pluriel("status_streak", quantite: 2, .entier(2)))
        #expect(a.personnage == Poses.greeting(true, jour: lundi))
        #expect(a.minutesFaites == 25)
        let anneaux = Store.anneaux(journal: j, reglages: r, aujourdhui: lundi, fuseauTelephone: "UTC")
        #expect(a.anneaux == anneaux)
        #expect(a.libelleSemaine == Libelle.pluriel("week_gauge", quantite: anneaux.semaine.fait,
                                                    .entier(anneaux.semaine.fait), .entier(anneaux.semaine.objectif)))
        #expect(a.lectureAnneaux == Libelle("rings_description",
                                            .libelle(Store.formatDuration(25)),
                                            .libelle(Store.formatDuration(anneaux.jour.objectif)),
                                            .entier(anneaux.semaine.fait), .entier(anneaux.semaine.objectif),
                                            .entier(2), .entier(anneaux.serie.objectif)))
        let marques = a.semaine.prefix(2).map(\.marque)
        #expect(marques == [.coche, .coche])
        // Le soir, la salutation change ; sans prénom, l'état du jour la remplace.
        let soir = VignetteSerie.affichage(journal: j, reglages: r, maintenant: try Self.instant(Self.lundi, 19),
                                           fuseauTelephone: .utc, chizuk: nil, langue: "fr")
        #expect(soir.salutation == Libelle("hero_greeting_evening", .texte("David")))
        j.setFirstName("  ")
        let anonyme = VignetteSerie.affichage(journal: j, reglages: r, maintenant: try Self.instant(Self.lundi, 19),
                                              fuseauTelephone: .utc, chizuk: nil, langue: "fr")
        #expect(anonyme.salutation == Libelle("widget_done"))
    }

    @Test func reposUnJourDeChabbat() throws {
        var r = Reglages()
        r.setShabbatMode(true)
        let a = VignetteSerie.affichage(journal: Journal(), reglages: r,
                                        maintenant: try Self.instant("2026-11-21", 11), fuseauTelephone: .utc,
                                        chizuk: nil, langue: "fr")
        #expect(a.repos)
        #expect(!a.fait)
        #expect(a.flammeAllumee)
        #expect(a.salutation == Libelle("widget_rest"))
        let samedi = try #require(a.semaine.last)
        #expect(samedi.etat == .repos)
        #expect(samedi.marque == .chabbat)
        #expect(samedi.estAujourdhui)
    }

    @Test func enSeance() throws {
        var r = Reglages()
        let debut = try Self.instant(Self.lundi, 9, 55)
        Store.beginSession(reglages: &r, minutes: 15, millis: debut)
        let lundi = try Self.jour(Self.lundi)
        let a = VignetteSerie.affichage(journal: Journal(), reglages: r, maintenant: try Self.instant(Self.lundi, 10),
                                        fuseauTelephone: .utc, chizuk: nil, langue: "fr")
        let seance = try #require(a.seance)
        #expect(seance.compteur == .reste)
        #expect(seance.debut == debut)
        #expect(seance.fin == debut + 15 * 60_000)
        #expect(a.compteurMontre)
        #expect(a.salutation == Libelle("widget_running"))
        #expect(a.bouton == Libelle("session_finish_now"))
        #expect(a.destinationBouton == .terminer)
        #expect(a.destination == .seance)
        #expect(a.personnage == Poses.during(lundi))
        // Le compteur masqué ne se montre pas ; une séance ouverte compte le temps passé.
        r.setHideCountdown(true)
        let masque = VignetteSerie.affichage(journal: Journal(), reglages: r,
                                             maintenant: try Self.instant(Self.lundi, 10), fuseauTelephone: .utc,
                                             chizuk: nil, langue: "fr")
        #expect(!masque.compteurMontre)
        var ouverte = Reglages()
        Store.beginSession(reglages: &ouverte, minutes: 0, millis: debut)
        let libre = VignetteSerie.affichage(journal: Journal(), reglages: ouverte,
                                            maintenant: try Self.instant(Self.lundi, 10), fuseauTelephone: .utc,
                                            chizuk: nil, langue: "fr")
        #expect(libre.seance?.compteur == .ecoule)
        #expect(libre.seance?.fin == 0)
        // Passée sa fin, la séance n'est plus en cours.
        let apres = VignetteSerie.affichage(journal: Journal(), reglages: r,
                                            maintenant: try Self.instant(Self.lundi, 10, 11), fuseauTelephone: .utc,
                                            chizuk: nil, langue: "fr")
        #expect(apres.seance == nil)
    }

    @Test func chronologieDeLaSerie() throws {
        var r = Reglages()
        let maintenant = try Self.instant(Self.lundi, 10)
        let c = VignetteSerie.chronologie(reglages: r, maintenant: maintenant, fuseauTelephone: .utc)
        let attendus = [
            maintenant,
            try Self.instant(Self.lundi, 12), try Self.instant(Self.lundi, 18),
            try Self.instant("2026-11-17", 0), try Self.instant("2026-11-17", 5),
            try Self.instant("2026-11-17", 12), try Self.instant("2026-11-17", 18),
        ]
        #expect(c.instants == attendus)
        let mercredi = try Self.instant("2026-11-18", 0)
        #expect(c.recharge == mercredi)
        // La fin prévue d'une séance est un changement de plus.
        Store.beginSession(reglages: &r, minutes: 15, millis: try Self.instant(Self.lundi, 9, 55))
        let avecSeance = VignetteSerie.chronologie(reglages: r, maintenant: maintenant, fuseauTelephone: .utc)
        #expect(avecSeance.instants.count == attendus.count + 1)
        let fin = try Self.instant(Self.lundi, 10, 10)
        let deuxieme = avecSeance.instants.dropFirst().first
        #expect(deuxieme == fin)
    }

    @Test func texteDuJour() throws {
        let chizuk = try JSONDecoder().decode(Chizuk.self, from: Fichiers.donnees("ios/Ressources/Contenu/chizuk.json"))
        let lundi = try Self.jour(Self.lundi)
        let a = VignetteSerie.affichage(journal: Journal(), reglages: Reglages(),
                                        maintenant: try Self.instant(Self.lundi, 10), fuseauTelephone: .utc,
                                        chizuk: chizuk, langue: "en")
        let textes = ChizukRules.forMoment(chizuk, .ouverture, debug: false)
        try #require(!textes.isEmpty)
        let item = textes[(lundi.jourJulien - 2_440_588) % textes.count]
        let texte = try #require(a.texteDuJour)
        #expect(texte.hebreu == ChizukRules.hebrew(chizuk, item))
        #expect(texte.reference == Reference.localise(item.ref, "en"))
        // Le même toute la journée.
        let soir = VignetteSerie.affichage(journal: Journal(), reglages: Reglages(),
                                           maintenant: try Self.instant(Self.lundi, 23, 59), fuseauTelephone: .utc,
                                           chizuk: chizuk, langue: "en")
        #expect(soir.texteDuJour == texte)
    }

    // MARK: Les zmanim

    static let lieu = Zmanim.Lieu(nom: "Essai", latitude: 31.78, longitude: 35.22, altitude: 0, fuseau: "UTC")

    /// Des zmanim fixes, les mêmes chaque jour, à l'heure dite en UTC.
    static func horaires(_ lieu: Zmanim.Lieu, _ jour: JourCivil) -> [String: Int64] {
        let heures: [(String, Int, Int)] = [
            ("alot", 4, 0), ("netz", 5, 30), ("szks_gra", 8, 30), ("szt_gra", 9, 30), ("chatsot", 11, 45),
            ("minha_gedola", 12, 15), ("plag", 16, 30), ("chkia", 18, 0), ("tset", 18, 30), ("chatsot_layla", 23, 45),
        ]
        var res: [String: Int64] = [:]
        for (cle, heure, minute) in heures {
            res[cle] = Fuseau.utc.millis(DateHeure(jour, heure: heure, minute: minute))
        }
        return res
    }

    static func chrono(_ famille: Chronologies.Famille, lieu: Zmanim.Lieu?, _ maintenant: Int64) -> Chronologies.Affichage {
        Chronologies.affichage(famille: famille, lieu: lieu, maintenant: maintenant, fuseauTelephone: .utc,
                               enIsrael: true, horaires: Self.horaires)
    }

    @Test func zmanimMoyenne() throws {
        let maintenant = try Self.instant(Self.lundi, 10)
        let a = Self.chrono(.moyenne, lieu: Self.lieu, maintenant)
        let v = VignetteZmanim.affichage(a, famille: .moyenne, maintenant: maintenant, fuseau: .utc, serie: 3)
        #expect(v.aLieu)
        #expect(v.date == a.dateHebraique)
        #expect(v.pastille == a.pastille)
        #expect(v.titre == Libelle("widget_zmanim_minha"))
        #expect(v.heureLimite == "18:00")
        #expect(v.jusqua == Libelle("widget_jusqua", .texte("18:00")))
        let chkia = try Self.instant(Self.lundi, 18)
        let finChaharit = try Self.instant(Self.lundi, 9, 30)
        #expect(v.limite == chkia)
        #expect(v.debut == finChaharit)
        #expect(v.ligne == Libelle("widget_zmanim_jusqua", .libelle(Libelle("widget_zmanim_minha")), .texte("18:00")))
        #expect(v.serie == Libelle.pluriel("widget_zmanim_serie", quantite: 3, .entier(3)))
        let attendus: [VignetteZmanim.Ligne?] = [
            VignetteZmanim.Ligne(nom: Libelle("zman_chatsot"), heure: "11:45", etat: .prochain),
            VignetteZmanim.Ligne(nom: Libelle("zman_minha_gedola"), heure: "12:15", etat: .avenir),
            VignetteZmanim.Ligne(nom: Libelle("zman_plag"), heure: "16:30", etat: .avenir),
        ]
        #expect(v.prochains == attendus)
        #expect(v.journee.isEmpty)
        #expect(v.prochainZman == VignetteZmanim.Ligne(nom: Libelle("zman_chatsot"), heure: "11:45", etat: .prochain))
    }

    @Test func zmanimGrandeEtPetite() throws {
        let maintenant = try Self.instant(Self.lundi, 10)
        let grande = VignetteZmanim.affichage(Self.chrono(.grande, lieu: Self.lieu, maintenant), famille: .grande,
                                              maintenant: maintenant, fuseau: .utc, serie: 1)
        let etats = grande.journee.map(\.etat)
        #expect(etats == [.passe, .passe, .passe, .passe, .prochain, .avenir, .avenir, .avenir, .avenir])
        let heures = grande.journee.map(\.heure)
        #expect(heures == ["04:00", "05:30", "08:30", "09:30", "11:45", "12:15", "16:30", "18:00", "18:30"])
        #expect(grande.journee.first?.nom == Libelle("zman_alot"))
        #expect(grande.serie == Libelle.pluriel("widget_zmanim_serie", quantite: 1, .entier(1)))
        #expect(grande.prochainZman?.heure == "11:45")
        let petite = VignetteZmanim.affichage(Self.chrono(.petite, lieu: Self.lieu, maintenant), famille: .petite,
                                              maintenant: maintenant, fuseau: .utc, serie: 1)
        #expect(petite.serie == nil)
        #expect(petite.prochains.isEmpty)
        #expect(petite.journee.isEmpty)
        #expect(petite.titre == Libelle("widget_zmanim_minha"))
    }

    @Test func zmanimLaNuit() throws {
        // Après minuit du lieu passé de la nuit : Arvit, sans limite affichée ; la journée est celle de demain.
        let nuit = try Self.instant(Self.lundi, 23, 50)
        let v = VignetteZmanim.affichage(Self.chrono(.moyenne, lieu: Self.lieu, nuit), famille: .moyenne,
                                         maintenant: nuit, fuseau: .utc, serie: nil)
        #expect(v.titre == Libelle("widget_zmanim_arvit"))
        #expect(v.heureLimite == nil)
        #expect(v.jusqua == nil)
        #expect(v.debut == nil)
        #expect(v.ligne == Libelle("widget_zmanim_arvit"))
        #expect(v.serie == nil)
        #expect(v.prochainZman == VignetteZmanim.Ligne(nom: Libelle("zman_alot"), heure: "04:00", etat: .prochain))
    }

    @Test func zmanimSansLieu() throws {
        let maintenant = try Self.instant(Self.lundi, 10)
        let v = VignetteZmanim.affichage(Self.chrono(.moyenne, lieu: nil, maintenant), famille: .moyenne,
                                         maintenant: maintenant, fuseau: .utc, serie: 0)
        #expect(!v.aLieu)
        #expect(v.titre == Libelle("zmanim_choisir_lieu"))
        #expect(v.ligne == Libelle("zmanim_choisir_lieu"))
        #expect(v.prochainZman == nil)
        #expect(v.heureLimite == nil)
        #expect(!v.date.isEmpty)
    }

    @Test func fuseauDesHeures() throws {
        let paris = Zmanim.Lieu(nom: "Paris", latitude: 48.85, longitude: 2.35, altitude: 0, fuseau: "Europe/Paris")
        let inconnu = Zmanim.Lieu(nom: "?", latitude: 0, longitude: 0, altitude: 0, fuseau: "Nulle/Part")
        #expect(VignetteZmanim.fuseau(lieu: paris, fuseauTelephone: .utc).identifiant == "Europe/Paris")
        #expect(VignetteZmanim.fuseau(lieu: inconnu, fuseauTelephone: .utc) == .utc)
        #expect(VignetteZmanim.fuseau(lieu: nil, fuseauTelephone: .utc) == .utc)
        // 10 h UTC en novembre : 11 h à Paris.
        let zone = try #require(Fuseau("Europe/Paris"))
        let instant = try Self.instant(Self.lundi, 10, 5)
        #expect(VignetteZmanim.heure(instant, fuseau: zone) == "11:05")
    }

    // MARK: Les clés

    @Test func clesAuCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        let simples = ["widget_todo", "widget_done", "widget_rest", "widget_running", "widget_start", "session_finish_now",
                       "widget_minutes", "status_streak_none", "rings_description", "week_shabbat_mark",
                       "hero_greeting_morning", "hero_greeting_afternoon", "hero_greeting_evening",
                       "widget_jusqua", "widget_reste", "widget_zmanim_jusqua", "widget_paracha",
                       "widget_zmanim_chaharit", "widget_zmanim_minha", "widget_zmanim_arvit", "zmanim_choisir_lieu",
                       "widget_label", "widget_description", "widget_zmanim_label", "widget_zmanim_description"]
            + ZmanimVignette.journee.map { "zman_" + $0 }
        for cle in simples {
            for langue in Traducteur.langues {
                let valeur = catalogue.valeur(cle, langue: langue)
                #expect(valeur != nil, "\(cle) en \(langue)")
            }
        }
        for cle in ["status_streak", "week_gauge", "widget_zmanim_serie"] {
            for langue in Traducteur.langues {
                let forme = catalogue.forme(cle, "other", langue: langue)
                #expect(forme != nil, "\(cle) en \(langue)")
            }
        }
    }
}
