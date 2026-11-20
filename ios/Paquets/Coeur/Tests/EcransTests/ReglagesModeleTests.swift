import Foundation
import Testing
import Coeur
import Barriere
@testable import Ecrans

/// L'onglet Réglages (SettingsActivity.kt) : chaque réglage écrit sa clé d'Android, chaque liste coche la valeur
/// réglée, les autorisations et la carte d'état disent ce que le système a dit, l'export rend le JSON d'Android et
/// l'import d'un fichier d'or le fusionne et donne la série attendue ; les vecteurs de `sauvegarde.json` (le vrai
/// Store.importJson et Store.exportJson) passent par l'écran. Ce que la vue fait des valeurs (fenêtres, défilement,
/// sélecteurs du système) reste au test d'interface.
@Suite("Modèle de l'onglet Réglages")
@MainActor
struct ReglagesModeleTests {

    /// Ce qu'un test construit : le modèle et chacun de ses doubles.
    struct Banc {
        let modele: ReglagesModele
        let magasin: Magasin
        let persistance: PersistanceEnMemoire
        let notificateur: FauxNotificateur
        let tempsEcran: FauxTempsEcran
        let activite: FausseActiviteEnDirect
        let barriere: ReglagesFausseBarriere
        let icone: ReglagesFausseIcone
        let effets: ReglagesFauxEffets
    }

    /// Le lundi 16 novembre 2026, 9 h : dans la fenêtre par défaut (6 h – 11 h), un jour ordinaire.
    private static let lundi = "2026-11-16"

    /// Une liste de morceaux livrés, au format de musique.json.
    private static func lecteurMusique(_ ids: [String]) -> ContenusApp.Lecteur {
        let objets = ids.map { #"{"id":"\#($0)","titre":"track_\#($0)","fichier":"Musique/\#($0).m4a","octets":1}"# }
        let texte = "[" + objets.joined(separator: ",") + "]"
        return { chemin in chemin == "musique.json" ? Data(texte.utf8) : nil }
    }

    private func fabriquer(_ enregistrement: Enregistrement = Enregistrement(), jour: String = ReglagesModeleTests.lundi,
                           heure: Int = 9, fuseau: String = "UTC", avecBarriere: Bool = true, langue: String = "fr",
                           notificationsAccordees: Bool = true, constat: Constat = Constat(), jetons: Int = 3,
                           morceaux: [String] = ["hamelech_basade"], icone: String? = nil) throws -> Banc {
        let date = try #require(JourCivil(iso: jour))
        let zone = try #require(Fuseau(fuseau))
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let notificateur = FauxNotificateur(accordee: notificationsAccordees)
        let tempsEcran = FauxTempsEcran()
        let activite = FausseActiviteEnDirect()
        let barriere = ReglagesFausseBarriere(constat: constat, jetons: jetons)
        let fausseIcone = ReglagesFausseIcone(nom: icone)
        let effets = ReglagesFauxEffets()
        let modele = ReglagesModele(magasin: magasin, contenus: ContenusApp(lecteur: ReglagesModeleTests.lecteurMusique(morceaux)),
                                    horloge: HorlogeFixe(DateHeure(date, heure: heure), fuseau: zone),
                                    notificateur: notificateur, tempsEcran: tempsEcran, activite: activite,
                                    barriere: barriere, icone: fausseIcone, effets: effets, avecBarriere: avecBarriere,
                                    langue: langue, version: ReglagesVersion(nom: "2.4", numero: 87))
        return Banc(modele: modele, magasin: magasin, persistance: persistance, notificateur: notificateur,
                    tempsEcran: tempsEcran, activite: activite, barriere: barriere, icone: fausseIcone, effets: effets)
    }

    /// La valeur écrite sous `cle` dans les réglages que la persistance garde.
    private func ecrit(_ banc: Banc, _ cle: String) async -> JSON? {
        let enregistre = await banc.persistance.enregistrement
        return enregistre.reglages.brut[cle]
    }

    // MARK: Les valeurs montrées

    @Test func lesValeursParDefautSontCellesDAndroid() throws {
        let m = try fabriquer().modele
        #expect(m.adresse == Libelle("adresse_none"))
        #expect(m.mode == Libelle("mode_auto"))
        #expect(m.fond == Libelle("fond_vert"))
        #expect(m.accent == Libelle("accent_vert"))
        #expect(m.police == Libelle("police_serif"))
        #expect(m.ouverture == Libelle("nav_today"))
        #expect(m.sourceHalakha == Libelle("halakha_source_yalkut"))
        // Sans usage choisi : « Selon le noussa'h · » et celui d'Edot haMizra'h, le noussa'h par défaut : le Yalkut
        // Yosef depuis l'audit du 16/11 d'Android (la nuit du 15 incluse ; le Choul'han Aroukh avant).
        #expect(m.usageLevana == Libelle("zmanim_lieu_detail", .libelle(Libelle("levana_usage_auto")),
                                         .libelle(Libelle("levana_usage_sept_nuit_quinze"))))
        #expect(m.prenom == .libelle(Libelle("settings_name_empty")))
        #expect(m.texteHeure(.debut) == .brut("06:00"))
        #expect(m.texteHeure(.fin) == .brut("11:00"))
        #expect(m.report == Libelle("duration_minutes", .entier(15)))
        #expect(m.duree == Libelle("duration_minutes", .entier(15)))
        // L'objectif non réglé vaut la durée habituelle.
        #expect(m.objectif == Libelle("duration_minutes", .entier(15)))
        #expect(m.region == Libelle("region_diaspora"))
        #expect(m.nomLangue == .brut("Français"))
        #expect(m.texteVersion == Libelle("app_version", .texte("2.4"), .entier(87), .libelle(Libelle("edition_full"))))
        let actifs = ReglagesInterrupteur.allCases.filter { m.estActif($0) }
        // Affichés par défaut : Levana, son rappel, les hilloulot, la halakha ; Chabbat et Yom Tov compté.
        #expect(actifs == [.levana, .levanaRappel, .hilloulot, .halakha, .chabbat])
        // Avant la première lecture du système : ni résumé ni carte d'état.
        #expect(m.resume == nil)
        #expect(m.carteBarriere == nil)
    }

    @Test func lEditionLegereNAPasDeBarriere() async throws {
        let banc = try fabriquer(avecBarriere: false, notificationsAccordees: false)
        let m = banc.modele
        await m.rafraichir()
        #expect(m.carteBarriere == nil)
        #expect(m.interrupteurs.contains(.barriere) == false)
        #expect(m.autorisations.map { $0.autorisation } == [.notifications])
        #expect(m.resume == Libelle.pluriel("permissions_missing", quantite: 1, .entier(1)))
        #expect(m.texteVersion == Libelle("app_version", .texte("2.4"), .entier(87), .libelle(Libelle("edition_light"))))
        // L'interrupteur de la barrière n'agit pas.
        try await m.basculer(.barriere, true)
        let enabled = await ecrit(banc, "enabled")
        #expect(enabled == nil)
        let lectures = await banc.barriere.lectures
        #expect(lectures == 0)
    }

    @Test func laRegionSuitLeFuseauPuisLeChoix() async throws {
        let israel = try fabriquer(fuseau: "Asia/Jerusalem")
        #expect(israel.modele.region == Libelle("region_israel"))

        let banc = try fabriquer()
        try await banc.modele.basculerRegion()
        #expect(banc.modele.region == Libelle("region_israel"))
        let cle = await ecrit(banc, "in_israel")
        #expect(cle == .booleen(true))
        try await banc.modele.basculerRegion()
        let retour = await ecrit(banc, "in_israel")
        #expect(retour == .booleen(false))
    }

    @Test func laLangueEtLaConfidentialiteSuiventLaLangueDeLApp() throws {
        let hebreu = try fabriquer(langue: "he").modele
        #expect(hebreu.nomLangue == .brut("עברית"))
        #expect(hebreu.routeConfidentialite == .navigateur(ReglagesModele.lienConfidentialite + "#he"))
        #expect(hebreu.routeLangue == .reglagesApp)
        let francais = try fabriquer(langue: "fr-CA").modele
        #expect(francais.nomLangue == .brut("Français"))
        #expect(francais.routeConfidentialite == .navigateur(ReglagesModele.lienConfidentialite + "#fr"))
        // Une langue que l'app ne parle pas : l'anglais (LangueApp, Traducteur.langueApp).
        let autre = try fabriquer(langue: "de").modele
        #expect(autre.nomLangue == .brut("English"))
        #expect(autre.routeConfidentialite == .navigateur(ReglagesModele.lienConfidentialite + "#en"))
    }

    /// L'espagnol et l'arabe de Tunisie (17/11) : leur nom dans leur langue ; un arabe d'ailleurs passe en anglais.
    @Test func lEspagnolEtLArabeDeTunisie() throws {
        let espagnol = try fabriquer(langue: "es-MX").modele
        #expect(espagnol.nomLangue == .brut("Español"))
        let tunisien = try fabriquer(langue: "ar-TN").modele
        #expect(tunisien.nomLangue == .brut("تونسي"))
        let egyptien = try fabriquer(langue: "ar-EG").modele
        #expect(egyptien.nomLangue == .brut("English"))
    }

    // MARK: Chaque réglage écrit sa clé d'Android

    @Test func chaqueInterrupteurEcritSaCleDAndroid() async throws {
        let attendus: [(ReglagesInterrupteur, Bool, String, JSON)] = [
            (.barriere, true, "enabled", .booleen(true)),
            (.grandTexte, true, "lecture_echelle", .decimal(Double(Float(1.4)))),
            (.levana, false, "levana_affichee", .booleen(false)),
            (.levanaRappel, false, "levana_rappel", .booleen(false)),
            (.hilloulot, false, "hilloulot_affichees", .booleen(false)),
            (.halakha, false, "halakha_affichee", .booleen(false)),
            (.chabbat, false, "pause_shabbat", .booleen(false)),
            (.masquerDecompte, true, "hide_countdown", .booleen(true)),
            (.guidee, true, "guided_hitbodedut", .booleen(true)),
            (.pauseAujourdhui, true, "paused_dates", .tableau([.chaine(ReglagesModeleTests.lundi)])),
        ]
        #expect(attendus.count == ReglagesInterrupteur.allCases.count)
        let banc = try fabriquer()
        for (interrupteur, valeur, cle, json) in attendus {
            try await banc.modele.basculer(interrupteur, valeur)
            let lu = await ecrit(banc, cle)
            #expect(lu == json, "\(interrupteur) → \(cle)")
            let actif = banc.modele.estActif(interrupteur)
            #expect(actif == valeur, "\(interrupteur)")
        }
        // Le grand texte éteint revient à la taille de base ; la pause retirée vide la liste.
        try await banc.modele.basculer(.grandTexte, false)
        let echelle = await ecrit(banc, "lecture_echelle")
        #expect(echelle == .decimal(1))
        try await banc.modele.basculer(.pauseAujourdhui, false)
        let pauses = await ecrit(banc, "paused_dates")
        #expect(pauses == .tableau([]))
    }

    @Test func chaqueListeEcritSaCleDAndroid() async throws {
        let attendus: [(ReglagesListe, Int, String, JSON)] = [
            (.adresse, 1, "adresse", .chaine("f")),
            (.mode, 2, "apparence_mode", .chaine("sombre")),
            (.fond, 2, "apparence_fond", .chaine("sable")),
            (.accent, 3, "apparence_accent", .chaine("bordeaux")),
            (.police, 3, "lecture_police", .chaine("frank")),
            (.ouverture, 2, "ecran_ouverture", .chaine("zmanim")),
            (.usageLevana, 1, "levana_usage", .chaine("trois_mi_mois")),
            (.sourceHalakha, 1, "halakha_source", .chaine("ben_ish_hai")),
            (.report, 3, "snooze_minutes", .entier(30)),
            (.duree, 4, "target_minutes", .entier(60)),
            (.objectif, 5, "daily_goal_minutes", .entier(90)),
        ]
        #expect(attendus.count == ReglagesListe.allCases.count)
        let banc = try fabriquer()
        for (liste, rang, cle, json) in attendus {
            banc.modele.dialogue = .choix(liste)
            try await banc.modele.choisir(rang, dans: liste)
            let lu = await ecrit(banc, cle)
            #expect(lu == json, "\(liste) → \(cle)")
            #expect(banc.modele.dialogue == nil, "\(liste) : la liste se referme")
        }
        let m = banc.modele
        #expect(m.adresse == Libelle("adresse_tsadeket"))
        #expect(m.mode == Libelle("mode_sombre"))
        #expect(m.fond == Libelle("fond_sable"))
        #expect(m.accent == Libelle("accent_bordeaux"))
        #expect(m.police == Libelle("police_frank"))
        #expect(m.ouverture == Libelle("nav_zmanim"))
        #expect(m.usageLevana == Libelle("levana_usage_trois_mi_mois"))
        #expect(m.sourceHalakha == Libelle("halakha_source_bih"))
        #expect(m.report == Libelle("duration_minutes", .entier(30)))
        #expect(m.duree == Libelle("duration_hours", .entier(1)))
        #expect(m.objectif == Libelle("duration_hours_minutes", .entier(1), .entier(30)))

        // « Pas choisi » et « Selon le noussa'h » retirent la clé, comme Android.
        try await m.choisir(2, dans: .adresse)
        let adresse = await ecrit(banc, "adresse")
        #expect(adresse == nil)
        try await m.choisir(0, dans: .usageLevana)
        let usage = await ecrit(banc, "levana_usage")
        #expect(usage == nil)
        // Un rang hors de la liste ne fait rien.
        try await m.choisir(9, dans: .fond)
        #expect(m.fond == Libelle("fond_sable"))
    }

    @Test func lesListesCochentLaValeurReglee() async throws {
        var reglages = Reglages()
        reglages.setAdresse("f")
        reglages.setAccent(.ambre)
        reglages.setSiddurNusah(.ashkenaz)
        let m = try fabriquer(Enregistrement(reglages: reglages)).modele

        let adresse = m.choix(.adresse)
        #expect(adresse.titre == Libelle("settings_adresse"))
        #expect(adresse.options.map { $0.libelle } == [Libelle("adresse_tsadik"), Libelle("adresse_tsadeket"), Libelle("adresse_none")])
        #expect(adresse.options.filter { $0.cochee }.map { $0.rang } == [1])
        #expect(adresse.aCocher)

        let accent = m.choix(.accent)
        #expect(accent.options.count == 6)
        #expect(accent.options.filter { $0.cochee }.map { $0.rang } == [4])

        // Sans usage choisi, « Selon le noussa'h » est coché ; le noussa'h ashkénaze donne la Michna Beroura.
        let usage = m.choix(.usageLevana)
        #expect(usage.options.map { $0.libelle.cle } == ["levana_usage_auto", "levana_usage_trois_mi_mois",
                                                         "levana_usage_sept_mi_mois", "levana_usage_sept_quinze",
                                                         "levana_usage_sept_nuit_quinze"])
        #expect(usage.options.filter { $0.cochee }.map { $0.rang } == [0])
        #expect(m.usageLevana == Libelle("zmanim_lieu_detail", .libelle(Libelle("levana_usage_auto")),
                                         .libelle(Libelle("levana_usage_trois_mi_mois"))))

        let polices = m.choix(.police)
        #expect(polices.options.count == 7)
        #expect(polices.options.filter { $0.cochee }.map { $0.rang } == [0])

        // Le report et les durées : une simple liste, rien de coché.
        let report = m.choix(.report)
        #expect(report.aCocher == false)
        #expect(report.titre == Libelle("settings_snooze"))
        #expect(report.options.map { $0.libelle } == [5, 10, 15, 30, 60].map { Store.formatDuration($0) })
        #expect(report.options.filter { $0.cochee }.isEmpty)
        let duree = m.choix(.duree)
        #expect(duree.titre == Libelle("settings_target"))
        #expect(duree.options.count == DureeSeance.proposees.count + 1)
        #expect(duree.options.last?.libelle == Libelle("duration_custom"))
        #expect(m.choix(.objectif).titre == Libelle("settings_daily_goal"))
    }

    @Test func laDureeReglableOuvreLaSaisieEtBorne() async throws {
        let banc = try fabriquer()
        let m = banc.modele
        try await m.choisir(DureeSeance.proposees.count, dans: .duree)
        #expect(m.dialogue == .dureeLibre(.duree))
        #expect(m.dureeLibreInitiale == "15")
        try await m.validerDureeLibre(" 45 ", pour: .duree)
        #expect(m.dialogue == nil)
        let cible = await ecrit(banc, "target_minutes")
        #expect(cible == .entier(45))
        // Hors de 1 à 240, ou pas un nombre : rien ne change, la boîte reste ouverte et le dit (FACCUEIL-15).
        try await m.choisir(DureeSeance.proposees.count, dans: .duree)
        try await m.validerDureeLibre("500", pour: .duree)
        #expect(m.dialogue == .dureeLibre(.duree))
        #expect(m.erreurSaisie == Libelle("duration_custom_hint"))
        try await m.validerDureeLibre("abc", pour: .duree)
        let inchangee = await ecrit(banc, "target_minutes")
        #expect(inchangee == .entier(45))
        try await m.validerDureeLibre("240", pour: .duree)
        #expect(m.dialogue == nil)
        #expect(m.erreurSaisie == nil)
        // L'objectif aussi, prérempli de la durée habituelle.
        try await m.choisir(DureeSeance.proposees.count, dans: .objectif)
        #expect(m.dialogue == .dureeLibre(.objectif))
        #expect(m.dureeLibreInitiale == "240")
        try await m.validerDureeLibre("0", pour: .objectif)
        #expect(m.dialogue == .dureeLibre(.objectif))
        try await m.validerDureeLibre("1", pour: .objectif)
        let objectif = await ecrit(banc, "daily_goal_minutes")
        #expect(objectif == .entier(1))
    }

    @Test func laFenetreEtLePrenom() async throws {
        let banc = try fabriquer()
        let m = banc.modele
        let initiale = m.heureInitiale(.fin)
        #expect(initiale.heure == 11)
        #expect(initiale.minute == 0)
        try await m.choisirHeure(.debut, heure: 5, minute: 30)
        let debut = await ecrit(banc, "window_start")
        let fin = await ecrit(banc, "window_end")
        #expect(debut == .entier(330))
        #expect(fin == .entier(660))
        #expect(m.texteHeure(.debut) == .brut("05:30"))
        try await m.choisirHeure(.fin, heure: 23, minute: 5)
        #expect(m.texteHeure(.fin) == .brut("23:05"))

        #expect(m.prenomInitial == "")
        try await m.enregistrerPrenom("  David  ")
        #expect(banc.magasin.journal.firstName == "David")
        #expect(m.prenom == .brut("David"))
        let enregistre = await banc.persistance.enregistrement
        #expect(enregistre.journal.firstName == "David")
        // Vide est une réponse.
        try await m.enregistrerPrenom("")
        #expect(m.prenom == .libelle(Libelle("settings_name_empty")))
    }

    // MARK: Ce que chaque changement fait réécrire

    @Test func chaqueChangementReecritCeQuIlTouche() async throws {
        let banc = try fabriquer()
        let m = banc.modele
        try await m.basculer(.chabbat, false)
        try await m.basculer(.levanaRappel, false)
        try await m.choisir(1, dans: .mode)
        try await m.choisir(1, dans: .police)
        try await m.choisirHeure(.debut, heure: 7, minute: 0)
        try await m.basculer(.barriere, true)
        try await m.basculer(.pauseAujourdhui, true)
        let demandes = await banc.effets.demandes
        // La police ne touche rien hors de l'écran.
        let attendues: [ReglagesRepercussions] = [.tout, .rappels, .widgets, .barriere, [.barriere, .rappels], .tout]
        #expect(demandes == attendues)
        let derniers = await banc.effets.derniersReglages
        let pauses = derniers?.pausedDates
        #expect(pauses == Set([ReglagesModeleTests.lundi]))
        // Un choix qui ne change rien n'écrit rien et ne fait rien réécrire.
        let ecritures = await banc.persistance.ecrituresReglages
        try await m.choisir(1, dans: .mode)
        let apres = await banc.effets.demandes
        #expect(apres.count == attendues.count)
        let ecrituresApres = await banc.persistance.ecrituresReglages
        #expect(ecrituresApres == ecritures)
    }

    // MARK: Les autorisations

    @Test func leResumeDitCeQuiManque() async throws {
        let banc = try fabriquer(notificationsAccordees: false, constat: Constat(autorise: false))
        let m = banc.modele
        await m.rafraichir()
        #expect(m.resume == Libelle.pluriel("permissions_missing", quantite: 2, .entier(2)))
        let lignes = m.autorisations
        #expect(lignes.map { $0.autorisation } == [.notifications, .tempsEcran])
        #expect(lignes.map { $0.titre.cle } == ["permission_notifications", "reglages_autorisation_temps_ecran"])
        #expect(lignes.map { $0.pourquoi.cle } == ["permission_notifications_why", "reglages_autorisation_temps_ecran_pourquoi"])
        #expect(lignes.map { $0.etat } == [Libelle("permission_missing"), Libelle("permission_missing")])
        #expect(lignes.map { $0.couleurEtat } == ["warning", "warning"])
        #expect(lignes.map { $0.boutonActif } == [true, true])

        let tout = try fabriquer()
        await tout.modele.rafraichir()
        #expect(tout.modele.resume == Libelle("settings_all_granted"))
        #expect(tout.modele.autorisations.map { $0.etat } == [Libelle("permission_granted"), Libelle("permission_granted")])
        #expect(tout.modele.autorisations.map { $0.couleurEtat } == ["brand", "brand"])
        #expect(tout.modele.autorisations.map { $0.boutonActif } == [false, false])
    }

    @Test func lesNotificationsSeDemandentUneFoisPuisParLesReglagesDIOS() async throws {
        let banc = try fabriquer(notificationsAccordees: false)
        let m = banc.modele
        let premiere = await m.accorder(.notifications)
        #expect(premiere == nil)
        let demandes = await banc.notificateur.demandes
        #expect(demandes == 1)
        // Refusée : la suivante mène aux réglages des notifications de l'app, sans redemander.
        let seconde = await m.accorder(.notifications)
        #expect(seconde == .reglagesNotifications)
        let encore = await banc.notificateur.demandes
        #expect(encore == 1)
        // Allumer la barrière demande les notifications (askNotifications) : déjà demandées, les réglages d'iOS.
        let route = try await m.basculer(.barriere, true)
        #expect(route == .reglagesNotifications)
    }

    @Test func tempsEcranPasseParLaDivulgation() async throws {
        let banc = try fabriquer(constat: Constat(autorise: false))
        let m = banc.modele
        await m.accorder(.tempsEcran)
        #expect(m.dialogue == .divulgationTempsEcran)
        let avant = await banc.tempsEcran.demandes
        #expect(avant == 0)
        // « Pas maintenant » ne demande rien.
        m.fermerDialogue()
        let toujours = await banc.tempsEcran.demandes
        #expect(toujours == 0)
        // « Continuer » demande, puis relit l'état.
        await m.accorder(.tempsEcran)
        await banc.barriere.regler(constat: Constat(), jetons: 3)
        let route = try await m.continuerDivulgation()
        #expect(route == nil)
        #expect(m.dialogue == nil)
        let apres = await banc.tempsEcran.demandes
        #expect(apres == 1)
        #expect(m.autorisations.last?.accordee == true)
        // Venue de la carte des autorisations, la divulgation n'allume pas le mode.
        #expect(m.estActif(.barriere) == false)
    }

    /// Sur iOS, le mode ne s'allume qu'avec l'accès à Temps d'écran (PORTAGE.md § 2.1.13) : allumé sans lui, la
    /// carte dirait « Accès retiré par iOS ».
    @Test func lInterrupteurDeLaBarrierePasseParLaDivulgationSansAcces() async throws {
        let banc = try fabriquer(notificationsAccordees: false, constat: Constat(autorise: false))
        let m = banc.modele
        await m.rafraichir()
        let refus = try await m.basculer(.barriere, true)
        #expect(refus == nil)
        #expect(m.dialogue == .divulgationTempsEcran)
        #expect(m.estActif(.barriere) == false)
        let rien = await ecrit(banc, "enabled")
        #expect(rien == nil)
        // « Pas maintenant » : rien ne change, et un « Continuer » venu de la carte n'allumerait rien.
        m.fermerDialogue()
        #expect(m.estActif(.barriere) == false)

        // L'accès accordé après « Continuer » allume le mode, qui demande alors les notifications.
        try await m.basculer(.barriere, true)
        await banc.barriere.regler(constat: Constat(), jetons: 3)
        let route = try await m.continuerDivulgation()
        #expect(route == nil)
        let demandesTempsEcran = await banc.tempsEcran.demandes
        #expect(demandesTempsEcran == 1)
        let notifications = await banc.notificateur.demandes
        #expect(notifications == 1)
        let enabled = await ecrit(banc, "enabled")
        #expect(enabled == .booleen(true))
        #expect(m.carteBarriere?.etat == .armed)
        let effets = await banc.effets.demandes
        let attendus: [ReglagesRepercussions] = [[.barriere, .rappels]]
        #expect(effets == attendus)
    }

    // MARK: La carte d'état de la barrière

    @Test func laCarteDEtatSuitGateStatus() async throws {
        let banc = try fabriquer(constat: Constat(autorise: false), jetons: 0)
        let m = banc.modele
        await m.rafraichir()
        // Sans Temps d'écran et le mode éteint : « désactivé » d'abord (GateRule du 13/11, FACCUEIL-06 : on ne
        // réclame pas un accès pour une fonction que personne n'a allumée ; l'allumer demande l'accès).
        let eteinte = try #require(m.carteBarriere)
        #expect(eteinte.etat == .disabled)
        #expect(eteinte.titreVisible)
        #expect(eteinte.boutonAutorisations == false)
        #expect(eteinte.titre == GateStatus.titleOf(.disabled))
        #expect(eteinte.couleurTitre == "muted")
        m.montrerAutorisations()
        #expect(m.cibleDefilement == .autorisations)
        m.defilementFait()
        #expect(m.cibleDefilement == nil)

        // Autorisée, éteinte : désactivée ; allumée sans application : aucune application.
        await banc.barriere.regler(constat: Constat(), jetons: 0)
        await m.rafraichir()
        #expect(m.carteBarriere?.etat == .disabled)
        #expect(m.carteBarriere?.titreVisible == true)
        #expect(m.carteBarriere?.boutonAutorisations == false)
        try await m.basculer(.barriere, true)
        #expect(m.carteBarriere?.etat == .noAppsSelected)
        #expect(m.applications == Libelle("apps_none_warning"))
        #expect(m.couleurApplications == "warning")

        // Trois applications, 9 h d'un lundi, rien de fait : la barrière veille jusqu'à 11 h.
        await banc.barriere.regler(constat: Constat(), jetons: 3)
        await m.rafraichir()
        let veille = try #require(m.carteBarriere)
        #expect(veille.etat == .armed)
        #expect(veille.couleurTitre == "brand")
        #expect(veille.detail == Libelle.pluriel("gate_armed_detail", quantite: 3, .entier(3), .texte("11:00")))
        #expect(m.applications == Libelle.pluriel("apps_selected", quantite: 3, .entier(3)))
        #expect(m.couleurApplications == "muted")

        // La pause d'aujourd'hui se voit tout de suite ; une fenêtre déplacée aussi.
        try await m.basculer(.pauseAujourdhui, true)
        #expect(m.carteBarriere?.etat == .exemptDay)
        try await m.basculer(.pauseAujourdhui, false)
        try await m.choisirHeure(.debut, heure: 10, minute: 0)
        #expect(m.carteBarriere?.etat == .outsideWindow)
        #expect(m.carteBarriere?.detail == Libelle("gate_window_detail", .texte("10:00"), .texte("11:00")))
    }

    @Test func unAccesRetireSeRendDepuisLaCarte() async throws {
        var reglages = Reglages()
        reglages.setEnabled(true)
        let banc = try fabriquer(Enregistrement(reglages: reglages), constat: Constat(autorise: false))
        await banc.modele.rafraichir()
        let carte = try #require(banc.modele.carteBarriere)
        #expect(carte.etat == .autorisationRetiree)
        #expect(carte.titreVisible)
        #expect(carte.boutonAutorisations)
    }

    // MARK: L'icône

    @Test func lIconeSuitLAdresseEtLAccentSurUnGesteSeulement() async throws {
        let banc = try fabriquer()
        let m = banc.modele
        #expect(m.iconeProposee == nil)
        await m.rafraichir()
        #expect(m.iconeAJour)
        try await m.choisir(1, dans: .adresse)
        try await m.choisir(1, dans: .accent)
        #expect(m.iconeProposee == "Icone_f_bleu")
        #expect(m.iconeAJour == false)
        // Rien ne change l'icône sans le geste.
        let avant = await banc.icone.changements
        #expect(avant.isEmpty)
        await m.mettreIconeAuxCouleurs()
        let apres = await banc.icone.changements
        #expect(apres == ["Icone_f_bleu"])
        #expect(m.iconeAJour)
        // Revenir au hassid sur le vert : l'icône principale.
        try await m.choisir(2, dans: .adresse)
        try await m.choisir(0, dans: .accent)
        #expect(m.iconeProposee == nil)
        await m.mettreIconeAuxCouleurs()
        let retour = await banc.icone.nom
        #expect(retour == nil)
    }

    // MARK: L'export

    @Test func lExportRendLeJSONDAndroid() throws {
        var journal = Journal()
        journal.setFirstName("Hillel")
        let jour = try #require(JourCivil(iso: "2026-11-15"))
        journal[jour] = Journee(minutes: 20, note: "Merci", themes: ["gratitude"])
        var reglages = Reglages()
        reglages.setTargetMinutes(30)
        reglages.setAdresse("m")
        reglages.togglePausedDate("2026-11-14")
        let banc = try fabriquer(Enregistrement(journal: journal, reglages: reglages))
        let export = banc.modele.preparerExport()
        #expect(export.nomDeFichier == "myhitbodedut-2026-11-16.json")
        let date = try #require(JourCivil(iso: ReglagesModeleTests.lundi))
        let horloge = HorlogeFixe(DateHeure(date, heure: 9), fuseau: .utc)
        let attendu = Sauvegarde.exporter(journal: journal, reglages: reglages, maintenant: horloge.maintenant,
                                          fuseauTelephone: "UTC")
        #expect(export.donnees == Data(attendu.utf8))
        // Les clés d'Android, dans son ordre, et exported_at à l'heure de l'horloge.
        let objet = try ObjetJSON(texte: String(decoding: export.donnees, as: UTF8.self))
        #expect(objet.cles == ["format", "version", "exported_at", "days", "settings", "paused_dates", "blocked_apps",
                               "journal_plus", "tikkun_journal", "favoris", "chizuk_favoris", "marques_pages"])
        #expect(objet.texte("exported_at") == "2026-11-16T09:00:00.000Z")
        let settings = try #require(objet.objet("settings"))
        #expect(settings.cles == Sauvegarde.clesReglages)
        #expect(settings.texte("first_name") == "Hillel")
        #expect(settings.entier("target_minutes") == 30)

        banc.modele.exportTermine(reussi: true)
        #expect(banc.modele.message == Libelle("export_ok"))
        banc.modele.messageVu()
        #expect(banc.modele.message == nil)
        banc.modele.exportTermine(reussi: false)
        #expect(banc.modele.message == Libelle("export_failed"))
    }

    // MARK: L'import

    /// Un fichier d'or : six journées du lundi 9 au dimanche 15 novembre, sans le Chabbat, des réglages
    /// d'Android et un jour de pause. Le 15 est déjà noté ici.
    private static let fichierDOr = #"""
        {"format":"myhitbodedut","version":1,"exported_at":"2026-11-15T20:00:00.000Z",
         "days":{"2026-11-09":{"minutes":15,"note":""},"2026-11-10":{"minutes":20,"note":"Le matin"},
          "2026-11-11":{"minutes":15,"note":"","themes":["famille"]},"2026-11-12":{"minutes":30,"note":""},
          "2026-11-13":{"minutes":10,"note":""},"2026-11-15":{"minutes":45,"note":"","themes":["gratitude"]},
          "2026-11-20":{"minutes":15,"note":"à venir"}},
         "settings":{"window_start":360,"window_end":660,"snooze_minutes":10,"target_minutes":20,"daily_goal_minutes":0,
          "pause_shabbat":true,"in_israel":false,"reminder_enabled":true,"reminder_minutes":420,"reminder_times":[420],
          "first_name":"Hillel","hide_countdown":false,"guided_hitbodedut":true,"music_enabled":true,"music_volume":50,
          "music_shuffle":false,"music_track":"hamelech_basade","adresse":"f","apparence_mode":"sombre",
          "apparence_fond":"sable","apparence_accent":"violet"},
         "paused_dates":["2026-10-01"],"blocked_apps":[]}
        """#

    @Test func unFichierDOrImporteParLEcranDonneLaSerieAttendue() async throws {
        var journal = Journal()
        let dimanche = try #require(JourCivil(iso: "2026-11-15"))
        journal[dimanche] = Journee(minutes: 30, note: "ici", themes: ["emotions"])
        let banc = try fabriquer(Enregistrement(journal: journal))
        let m = banc.modele
        await m.importer(Data(ReglagesModeleTests.fichierDOr.utf8))
        // Six journées lues (le 20, à venir, est ignoré).
        #expect(m.message == Libelle.pluriel("import_ok", quantite: 6, .entier(6)))
        let aujourdhui = try #require(JourCivil(iso: ReglagesModeleTests.lundi))
        let serie = Store.streak(journal: banc.magasin.journal, reglages: banc.magasin.reglages, aujourdhui: aujourdhui,
                                 fuseauTelephone: "UTC")
        // Du 15 au 9, le Chabbat du 14 exempté : six jours.
        #expect(serie == 6)
        // La fusion : la séance la plus longue, la note d'ici, les sujets réunis.
        #expect(banc.magasin.journal[dimanche] == Journee(minutes: 45, note: "ici", themes: ["emotions", "gratitude"]))
        let avenir = try #require(JourCivil(iso: "2026-11-20"))
        #expect(banc.magasin.journal[avenir] == nil)
        // Les réglages du fichier se voient à l'écran, et sont écrits.
        #expect(m.prenom == .brut("Hillel"))
        #expect(m.adresse == Libelle("adresse_tsadeket"))
        #expect(m.fond == Libelle("fond_sable"))
        #expect(m.mode == Libelle("mode_sombre"))
        #expect(m.report == Libelle("duration_minutes", .entier(10)))
        #expect(m.estActif(.guidee))
        let enregistre = await banc.persistance.enregistrement
        #expect(enregistre.journal == banc.magasin.journal)
        #expect(enregistre.reglages == banc.magasin.reglages)
        #expect(enregistre.reglages.musicTrackId == "hamelech_basade")
        #expect(enregistre.reglages.pausedDates == ["2026-10-01"])
        // Tout ce qui dépend des réglages est réécrit.
        let demandes = await banc.effets.demandes
        #expect(demandes == [.tout])
    }

    @Test func unFichierRefuseNeChangeRien() async throws {
        let banc = try fabriquer()
        let m = banc.modele
        await m.importer(Data(#"{"format":"autre","days":{}}"#.utf8))
        #expect(m.message == Libelle("import_invalid"))
        await m.importer(Data("pas du JSON".utf8))
        #expect(m.message == Libelle("import_invalid"))
        // Illisible, ou plus de 2 Mo : ce n'est pas une sauvegarde de cette application.
        await m.importer(nil)
        #expect(m.message == Libelle("import_failed"))
        await m.importer(Data(count: Sauvegarde.importMaxOctets + 1))
        #expect(m.message == Libelle("import_failed"))
        let ecritures = await banc.persistance.ecrituresJournal + banc.persistance.ecrituresReglages
        #expect(ecritures == 0)
        let demandes = await banc.effets.demandes
        #expect(demandes.isEmpty)
    }

    @Test func unImportQueLeDisqueRefuseLeDit() async throws {
        let banc = try fabriquer()
        await banc.persistance.faireEchouer(true)
        await banc.modele.importer(Data(ReglagesModeleTests.fichierDOr.utf8))
        #expect(banc.modele.message == Libelle("import_failed"))
    }

    // MARK: Les vecteurs d'Android, par l'écran

    /// Une préférence d'Android : [clé, type, valeur] (comme SauvegardeTests).
    private struct Pref: Decodable {
        let cle: String
        let valeur: JSON

        init(from decoder: any Decoder) throws {
            var c = try decoder.unkeyedContainer()
            cle = try c.decode(String.self)
            let type = try c.decode(String.self)
            switch type {
            case "int", "long":
                valeur = try .entier(c.decode(Int64.self))
            case "bool":
                valeur = try .booleen(c.decode(Bool.self))
            case "string":
                valeur = try .chaine(c.decode(String.self))
            case "float":
                valeur = try .decimal(c.decode(Double.self))
            case "set":
                valeur = try .tableau(c.decode([String].self).map { JSON.chaine($0) })
            default:
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "type inconnu : " + type)
            }
        }
    }

    private struct EtatJournal: Decodable {
        let days: String?
        let journalPlus: String?
        let firstName: String?
        let daysCorrompu: String?

        enum CodingKeys: String, CodingKey {
            case days
            case journalPlus = "journal_plus"
            case firstName = "first_name"
            case daysCorrompu = "days_corrompu"
        }
    }

    private struct Etat: Decodable {
        let prefs: [Pref]
        let journal: EtatJournal
    }

    private struct Scenario: Decodable {
        let nom: String
        let fuseau: String
        let avant: Etat
        let fichier: String
        let importe: Int?
        let apres: Etat
        let export: String
    }

    private struct Meta: Decodable {
        let aujourdhui: String
        let morceauxLivres: [String]
    }

    private struct Vecteurs: Decodable {
        let meta: Meta
        let scenarios: [Scenario]

        enum CodingKeys: String, CodingKey {
            case meta = "_meta"
            case scenarios
        }
    }

    private static func objet(_ prefs: [Pref]) -> ObjetJSON {
        ObjetJSON(prefs.map { ($0.cle, $0.valeur) })
    }

    /// Un ensemble dans l'ordre des unités UTF-16, comme `sorted()` de Kotlin.
    private static func trie(_ textes: [String]) -> [String] {
        textes.sorted { $0.utf16.lexicographicallyPrecedes($1.utf16) }
    }

    /// L'export d'Android, ses journées dans l'ordre des dates et ses ensembles dans l'ordre des unités UTF-16 :
    /// c'est ainsi qu'iOS les écrit (un ensemble d'Android sort dans l'ordre de son HashSet).
    private static func normalise(_ android: ObjetJSON) -> ObjetJSON {
        var o = android
        if let days = android.objet("days") {
            var paires: [(JourCivil, String)] = []
            for cle in days.cles {
                if let jour = Journal.dateValide(cle) {
                    paires.append((jour, cle))
                }
            }
            paires.sort { $0.0 < $1.0 }
            var tries = ObjetJSON()
            for (_, cle) in paires {
                tries[cle] = days[cle]
            }
            o["days"] = .objet(tries)
        }
        for cle in ["paused_dates", "blocked_apps"] {
            if let elements = android.tableau(cle) {
                var textes: [String] = []
                for rang in elements.indices {
                    textes.append(elements.texte(rang))
                }
                o[cle] = .tableau(trie(textes).map { JSON.chaine($0) })
            }
        }
        return o
    }

    /// Chaque scénario de `sauvegarde.json` (le vrai Store.importJson, puis Store.exportJson d'Android) passe par
    /// l'écran : le message, le journal et les réglages écrits, puis l'export, au JSON d'Android près des ordres.
    @Test func lesVecteursDAndroidPassentParLEcran() async throws {
        let v = try JSONDecoder().decode(Vecteurs.self, from: Fichiers.donnees("ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde.json"))
        let nombre = v.scenarios.count
        #expect(nombre >= 80)
        for s in v.scenarios {
            let journal = Journal(daysTexte: s.avant.journal.days, journalPlusTexte: s.avant.journal.journalPlus,
                                  prenom: s.avant.journal.firstName ?? "", corrompu: s.avant.journal.daysCorrompu)
            let reglages = Reglages(brut: ReglagesModeleTests.objet(s.avant.prefs))
            let banc = try fabriquer(Enregistrement(journal: journal, reglages: reglages), jour: v.meta.aujourdhui,
                                     heure: 12, fuseau: s.fuseau, morceaux: v.meta.morceauxLivres)
            let m = banc.modele
            await m.importer(Data(s.fichier.utf8))

            let message: Libelle
            if s.fichier.utf8.count > Sauvegarde.importMaxOctets {
                message = Libelle("import_failed")
            } else if let n = s.importe {
                message = Libelle.pluriel("import_ok", quantite: n, .entier(n))
            } else {
                message = Libelle("import_invalid")
            }
            #expect(m.message == message, "\(s.nom) : le message")

            let enregistre = await banc.persistance.enregistrement
            let days = enregistre.journal.daysTexte
            let daysConformes = days.egalUnites(s.apres.journal.days ?? "{}")
            #expect(daysConformes, "\(s.nom) : la préférence days\n\(days)")
            let prenom = enregistre.journal.prenom
            let prenomConforme = prenom.egalUnites(s.apres.journal.firstName ?? "")
            #expect(prenomConforme, "\(s.nom) : le prénom « \(prenom) »")
            let attendus = ReglagesModeleTests.objet(s.apres.prefs)
            let reglagesConformes = enregistre.reglages.brut == attendus
            #expect(reglagesConformes, "\(s.nom) : les réglages\n\(enregistre.reglages.texte())\n\(attendus.texte())")

            // L'export de l'écran, sans exported_at ; journal_plus compris, que l'export d'Android a depuis la
            // version 2 (FDONNEES-01).
            var ios = try ObjetJSON(texte: String(decoding: m.preparerExport().donnees, as: UTF8.self))
            ios["exported_at"] = nil
            let texteIos = ios.texte(indentation: 2)
            let android = try ObjetJSON(texte: s.export)
            let texteAndroid = ReglagesModeleTests.normalise(android).texte(indentation: 2)
            let exportConforme = texteIos.egalUnites(texteAndroid)
            #expect(exportConforme, "\(s.nom) : l'export\n\(texteIos)\n\(texteAndroid)")
        }
    }

    // MARK: Réinitialiser

    @Test func reinitialiserEffaceToutEtRepartDeLaPresentation() async throws {
        var journal = Journal()
        journal.setFirstName("David")
        var reglages = Reglages()
        reglages.setEnabled(true)
        reglages.setOnboarded()
        let banc = try fabriquer(Enregistrement(journal: journal, reglages: reglages))
        let m = banc.modele
        await banc.activite.commencer(debut: 0, fin: 60_000)
        m.demanderReinitialisation()
        #expect(m.dialogue == .confirmationReinitialisation)
        let route = try await m.reinitialiser()
        #expect(route == .recommencer)
        #expect(m.dialogue == nil)
        #expect(banc.magasin.journal == Journal())
        #expect(banc.magasin.reglages == Reglages())
        let enregistre = await banc.persistance.enregistrement
        #expect(enregistre == Enregistrement())
        let annulations = await banc.notificateur.annulations
        #expect(annulations == 1)
        let levees = await banc.tempsEcran.levees
        #expect(levees == 1)
        let seance = await banc.activite.seance
        let finie = seance == nil
        #expect(finie)
        let demandes = await banc.effets.demandes
        #expect(demandes == [.tout])
        #expect(banc.magasin.reglages.hasOnboarded == false)
    }

    // MARK: Les routes et les messages

    @Test func lesRoutes() throws {
        let m = try fabriquer().modele
        #expect(m.routePresentation == .presentation)
        #expect(m.routeApercuBarriere == .apercuBarriere)
        #expect(m.routeChoixApplications == .choixApplications)
        #expect(m.routeDedicace == .dedicace)
        #expect(m.routeConcentration == .aideConcentration)
        m.routeImpossible()
        #expect(m.message == Libelle("settings_screen_missing"))
    }

    // MARK: Les clés du catalogue

    /// Chaque clé que l'écran montre existe dans le catalogue d'Android, sauf les chaînes neuves d'iOS, qui vont
    /// dans ios.xcstrings.
    @Test func lesClesMontreesSontDansLeCatalogue() async throws {
        let catalogue = try CatalogueBrut.lire()
        let neuves: Set<String> = ["reglages_autorisation_temps_ecran", "reglages_autorisation_temps_ecran_pourquoi"]
        let banc = try fabriquer(notificationsAccordees: false, constat: Constat(autorise: false))
        let m = banc.modele
        await m.rafraichir()
        var libelles: [Libelle] = [m.adresse, m.mode, m.fond, m.accent, m.police, m.ouverture, m.usageLevana,
                                   m.sourceHalakha, m.report, m.duree, m.objectif, m.region, m.applications,
                                   m.texteVersion]
        libelles += [m.resume, m.carteBarriere?.titre, m.carteBarriere?.detail].compactMap { $0 }
        for ligne in m.autorisations {
            libelles += [ligne.titre, ligne.pourquoi, ligne.etat]
        }
        for liste in ReglagesListe.allCases {
            let choix = m.choix(liste)
            libelles.append(choix.titre)
            libelles += choix.options.map { $0.libelle }
        }
        for etat in GateState.allCases where etat.android {
            libelles.append(GateStatus.titleOf(etat))
        }
        libelles += ["settings_all_granted", "permission_granted", "export_ok", "export_failed", "import_failed",
                     "import_invalid", "settings_screen_missing", "settings_name_empty", "apps_none_warning",
                     "edition_light"].map { Libelle($0) }
        var cles: [String] = []
        func ajouter(_ libelle: Libelle) {
            cles.append(libelle.cle)
            for argument in libelle.arguments {
                if case .libelle(let interieur) = argument {
                    ajouter(interieur)
                }
            }
        }
        for libelle in libelles {
            ajouter(libelle)
        }
        let absentes = Set(cles).subtracting(neuves).filter { catalogue.strings[$0] == nil }.sorted()
        #expect(absentes.isEmpty, "\(absentes)")
    }
}
