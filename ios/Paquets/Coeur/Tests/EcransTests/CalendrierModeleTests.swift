import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le calendrier (CalendrierActivity.kt) : le mois hébreu par défaut, le mois civil au choix, les cases (quantième
/// principal en haut, aujourd'hui, le jour choisi, Chabbat et fêtes), l'en-tête, les flèches, « Aujourd'hui », le
/// jour choisi sous la grille ; la capture `captures-calendrier/calendrier-pourim-jerusalem.png`.
@Suite("Calendrier")
@MainActor
struct CalendrierModeleTests {

    private func fabriquer(_ reglages: Reglages, _ iso: String, fuseau: String = "Asia/Jerusalem")
        async throws -> (CalendrierModele, Magasin) {
        let jour = try #require(JourCivil(iso: iso))
        let telephone = try #require(Fuseau(fuseau))
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let modele = CalendrierModele(magasin: magasin, horloge: HorlogeFixe(DateHeure(jour, heure: 10), fuseau: telephone),
                                      contenus: ZmanimEssais.contenus, hilloulot: ZmanimEssais.hilloulot)
        await modele.apparaitre()
        return (modele, magasin)
    }

    private func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    /// Toutes les cases du mois affiché.
    private func cases(_ modele: CalendrierModele) -> [CalendrierCase] {
        modele.semaines.flatMap { $0.cases }.compactMap { $0 }
    }

    private func laCase(_ modele: CalendrierModele, _ iso: String) throws -> CalendrierCase {
        let trouvee = cases(modele).first { $0.date.iso == iso }
        return try #require(trouvee)
    }

    // MARK: Le mois hébreu

    @Test func leMoisHebreuParDefaut() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville), "2026-10-12")
        #expect(!modele.civil)
        #expect(modele.titre == Libelle("calendrier_title"))
        #expect(modele.image == "char_thinking")
        let debut = try jour("2026-10-12")
        #expect(modele.debutHebreu == debut)
        let jours = JourAffiche.joursMoisHebreu(debut)
        let premier = try #require(jours.first)
        let dernier = try #require(jours.last)
        let enTete = modele.enTete
        #expect(enTete.titre == CalendrierTitre.hebreu(CalendrierJuif.jour(debut, enIsrael: true).moisEtAnnee))
        #expect(enTete.sousTitre == CalendrierTitre.plageCivile(debut: premier, fin: dernier, anneeAuDebut: false))
        #expect(enTete.precedent == Libelle("calendrier_precedent"))
        #expect(enTete.suivant == Libelle("calendrier_suivant"))
        // Du dimanche au samedi, et tous les jours du mois.
        let semaines = modele.semaines
        let largeurs = Set(semaines.map { $0.cases.count })
        #expect(largeurs == [7])
        let tous = cases(modele).map { $0.date }
        #expect(tous == jours)
        // Le 1er 'Hechvan 5787 est un lundi.
        let premiereSemaine = try #require(semaines.first)
        #expect(premiereSemaine.cases[0] == nil)
        #expect(premiereSemaine.cases[1]?.date == debut)
        #expect(modele.joursDeSemaine == [1, 2, 3, 4, 5, 6, 7])
        // Le jour d'aujourd'hui, choisi, Roch 'Hodech : le quantième hébreu en haut.
        let aujourdhui = try laCase(modele, "2026-10-12")
        #expect(aujourdhui.aujourdhui)
        #expect(aujourdhui.choisie)
        #expect(aujourdhui.fete)
        let jourHebreu = CalendrierJuif.jour(debut, enIsrael: true)
        #expect(aujourdhui.haut == CalendrierQuantieme.hebreu(jourHebreu.jourEnLettres))
        #expect(aujourdhui.bas == CalendrierQuantieme.civil(12))
        #expect(aujourdhui.dateHebraique == jourHebreu.dateHebraique)
        let fetes = ZmanimEssais.cles(aujourdhui.fetes)
        #expect(fetes.contains("fete_roch_hodech"))
        // Le 1er novembre porte le nom de son mois.
        let novembre = try laCase(modele, "2026-11-01")
        let premierNovembre = try jour("2026-11-01")
        #expect(novembre.bas == CalendrierQuantieme.premierDuMois(premierNovembre))
        #expect(!novembre.aujourdhui)
        #expect(!novembre.choisie)
        // Chabbat est teinté ; un mardi ordinaire, non.
        let chabbat = try laCase(modele, "2026-10-17")
        #expect(chabbat.chome)
        let mardi = try laCase(modele, "2026-10-20")
        #expect(!mardi.chome)
        #expect(!mardi.fete)
    }

    @Test func lesFlechesDuMoisHebreu() async throws {
        let (modele, _) = try await fabriquer(Reglages(), "2026-10-12")
        let debut = try jour("2026-10-12")
        modele.moisSuivant()
        let suivant = JourAffiche.moisHebreuVoisin(debut, sens: 1)
        #expect(modele.moisHebreu == suivant)
        #expect(modele.debutHebreu == suivant)
        #expect(modele.choisi == debut)
        modele.moisPrecedent()
        modele.moisPrecedent()
        let tichri = try jour("2026-09-12")
        #expect(modele.debutHebreu == tichri)
        let premiere = cases(modele).first?.date
        #expect(premiere == tichri)
        // Le jour choisi n'est pas dans ce mois : aucune case ne l'est.
        let choisies = cases(modele).filter { $0.choisie }.count
        #expect(choisies == 0)
        modele.allerAujourdhui()
        #expect(modele.moisHebreu == nil)
        #expect(modele.debutHebreu == debut)
        #expect(modele.aujourdhuiLibelle == Libelle("calendrier_aujourdhui"))
    }

    // MARK: Le mois civil

    @Test func leMoisCivilAuChoix() async throws {
        let (modele, magasin) = try await fabriquer(Reglages(), "2026-10-12")
        let vues = modele.vues.map { $0.actif }
        #expect(vues == [true, false])
        #expect(modele.vueDescription == Libelle("calendrier_vue"))
        try await modele.basculer(civil: true)
        #expect(magasin.reglages.calendrierCivil)
        #expect(modele.civil)
        let apres = modele.vues.map { $0.actif }
        #expect(apres == [false, true])
        let octobre = try jour("2026-10-01")
        #expect(modele.mois == octobre)
        let enTete = modele.enTete
        #expect(enTete.titre == CalendrierTitre.moisCivil(octobre))
        let premier = CalendrierJuif.jour(octobre, enIsrael: true).moisEtAnnee
        let trenteEtUn = try jour("2026-10-31")
        let dernier = CalendrierJuif.jour(trenteEtUn, enIsrael: true).moisEtAnnee
        #expect(premier != dernier)
        #expect(enTete.sousTitre == CalendrierTitre.hebreu(premier + " – " + dernier))
        // Octobre 2026 : cinq semaines, le 1er un jeudi ; le quantième civil en haut, sans nom de mois.
        let semaines = modele.semaines
        #expect(semaines.count == 5)
        let premiereSemaine = try #require(semaines.first)
        #expect(premiereSemaine.cases[4]?.date == octobre)
        let un = try laCase(modele, "2026-10-01")
        #expect(un.haut == CalendrierQuantieme.civil(1))
        let douze = try laCase(modele, "2026-10-12")
        #expect(douze.haut == CalendrierQuantieme.civil(12))
        let lettres = CalendrierJuif.jour(douze.date, enIsrael: true).jourEnLettres
        #expect(douze.bas == CalendrierQuantieme.hebreu(lettres))
        // Les flèches passent l'année.
        modele.moisSuivant()
        modele.moisSuivant()
        modele.moisSuivant()
        let janvier = try jour("2027-01-01")
        let decembre = try jour("2026-12-01")
        #expect(modele.mois == janvier)
        modele.moisPrecedent()
        #expect(modele.mois == decembre)
        // Revenir à la vue hébraïque : le mois du jour choisi.
        try await modele.basculer(civil: false)
        #expect(modele.mois == octobre)
        #expect(modele.moisHebreu == nil)
        #expect(!magasin.reglages.calendrierCivil)
    }

    @Test func lesMoisVoisins() throws {
        let decembre = try jour("2026-12-01")
        let janvier = try jour("2027-01-01")
        let mars = try jour("2026-03-01")
        let janvierAvant = try jour("2025-01-01")
        let fin = try jour("2026-02-28")
        let fevrier = try jour("2026-02-01")
        #expect(CalendrierModele.moisVoisin(decembre, 1) == janvier)
        #expect(CalendrierModele.moisVoisin(janvier, -1) == decembre)
        #expect(CalendrierModele.moisVoisin(mars, -14) == janvierAvant)
        #expect(CalendrierModele.premierDuMois(fin) == fevrier)
    }

    // MARK: Le jour choisi

    @Test func leJourTouche() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville), "2026-10-12")
        // Aujourd'hui : on peut y ajouter du temps.
        #expect(modele.ajouterTemps == Libelle("jour_ajouter_temps"))
        let mardi = try jour("2026-10-20")
        modele.choisir(mardi)
        #expect(modele.choisi == mardi)
        #expect(modele.moisHebreu == nil)
        #expect(modele.carte.date == mardi)
        #expect(modele.partage.date == mardi)
        // Un jour à venir : non.
        #expect(modele.ajouterTemps == nil)
        let passe = try jour("2026-10-01")
        modele.choisir(passe)
        #expect(modele.ajouterTemps == Libelle("jour_ajouter_temps"))
        #expect(modele.routeAjouterTemps == ZmanimRoute.ajouterTemps(passe))
        // Les horaires et la carte sont ceux du jour choisi ; la carte est complète.
        let contexte = modele.contexte
        #expect(modele.lignes == ZmanimVueJour.lignes(passe, contexte))
        #expect(modele.levana == ZmanimVueJour.levana(passe, contexte))
        #expect(modele.halakha == ZmanimVueJour.halakha(passe, contexte))
        #expect(modele.hilloula == ZmanimVueJour.hilloula(passe, contexte))
        let halakha = try #require(modele.halakha)
        #expect(halakha.route == ZmanimRoute.halakha(passe))
        #expect(!modele.sansLieu)
        let pied = ZmanimEssais.cles(modele.pied)
        #expect(pied == ["zmanim_a_valider", "zmanim_source_villes"])
    }

    @Test func sansLieuLaCarteDesHorairesInvite() async throws {
        let (modele, _) = try await fabriquer(Reglages(), "2026-10-12")
        #expect(modele.sansLieu)
        let lignes = modele.lignes
        #expect(lignes.isEmpty)
        #expect(modele.invitationLieu == Libelle("zmanim_sans_lieu"))
        #expect(modele.choisirLieuLibelle == Libelle("zmanim_choisir_lieu"))
    }

    /// Laissé ouvert jusqu'au lendemain (bug du 02/11) : le jour d'alors passe à aujourd'hui ; un autre jour choisi
    /// exprès reste affiché.
    @Test func leLendemainLeJourSuit() async throws {
        let veille = try jour("2026-10-31")
        let fuseau = try #require(Fuseau("Europe/Paris"))
        let horloge = ZmanimHorlogeMobile(DateHeure(veille, heure: 23), fuseau: fuseau)
        let modele = CalendrierModele(magasin: .enMemoire(), horloge: horloge, jour: nil)
        await modele.apparaitre()
        modele.disparaitre()
        horloge.avancer(heures: 2)
        await modele.apparaitre()
        #expect(modele.choisi.iso == "2026-11-01")
        #expect(modele.mois.iso == "2026-11-01")
        let choisi = try jour("2026-11-05")
        modele.choisir(choisi)
        modele.disparaitre()
        horloge.avancer(heures: 24)
        await modele.apparaitre()
        #expect(modele.choisi == choisi)
    }

    /// L'état gardé à la restauration (ETAT_JOUR, ETAT_MOIS_HEBREU).
    @Test func laRestauration() throws {
        let choisi = try jour("2026-12-20")
        let tichri = try jour("2026-09-12")
        let aujourdhui = try jour("2026-10-12")
        let decembre = try jour("2026-12-01")
        let horloge = HorlogeFixe(DateHeure(aujourdhui, heure: 9), fuseau: .utc)
        let modele = CalendrierModele(magasin: .enMemoire(), horloge: horloge, jour: choisi, moisHebreu: tichri)
        #expect(modele.choisi == choisi)
        #expect(modele.mois == decembre)
        #expect(modele.debutHebreu == tichri)
    }

    // MARK: La capture

    /// calendrier-pourim-jerusalem.png : Jérusalem, vue civile, mars 2027, le mercredi 24 (15 Adar II) choisi.
    @Test func pourimAJerusalemDansLeMoisCivil() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        var reglages = ZmanimEssais.reglages(ville)
        reglages.setCalendrierCivil(true)
        let (modele, _) = try await fabriquer(reglages, "2027-03-24")
        let mars = try jour("2027-03-01")
        #expect(modele.mois == mars)
        let enTete = modele.enTete
        #expect(enTete.titre == CalendrierTitre.moisCivil(mars))
        let premier = CalendrierJuif.jour(mars, enIsrael: true).moisEtAnnee
        let finMars = try jour("2027-03-31")
        let dernier = CalendrierJuif.jour(finMars, enIsrael: true).moisEtAnnee
        #expect(enTete.sousTitre == CalendrierTitre.hebreu(premier + " – " + dernier))
        let semaines = modele.semaines
        #expect(semaines.count == 5)
        // Les points des fêtes : Roch 'Hodech Adar II (9 et 10), Pourim (23 et 24).
        for iso in ["2027-03-09", "2027-03-10", "2027-03-23", "2027-03-24"] {
            let c = try laCase(modele, iso)
            #expect(c.fete, "\(iso)")
        }
        // Chabbat teinté.
        for iso in ["2027-03-06", "2027-03-13", "2027-03-20", "2027-03-27"] {
            let c = try laCase(modele, iso)
            #expect(c.chome, "\(iso)")
        }
        let quinze = try laCase(modele, "2027-03-24")
        #expect(quinze.aujourdhui)
        #expect(quinze.choisie)
        let fetesQuinze = ZmanimEssais.cles(quinze.fetes)
        #expect(fetesQuinze.contains("fete_pourim_jerusalem"))
        let quatorze = try laCase(modele, "2027-03-23")
        let fetesQuatorze = ZmanimEssais.cles(quatorze.fetes)
        #expect(fetesQuatorze.contains("fete_pourim_ailleurs"))
        let carte = modele.carte
        let marques = ZmanimEssais.cles(carte.marques)
        #expect(marques.contains("fete_pourim_jerusalem"))
        #expect(carte.illustration == "char_purim")
        let ajouts = ZmanimEssais.cles(carte.ajouts)
        #expect(ajouts.contains("ajout_al_hanissim"))
        #expect(ajouts.contains("ajout_sans_tahanoun"))
        var heures: [String: String] = [:]
        for ligne in modele.lignes { heures[ligne.cle] = ligne.heureTexte }
        // Les heures loin d'une minute ronde (à plus de deux secondes) ; Michéyakir (04:48:00) et Min'ha ketana (15:19:59) en sont trop près.
        let attendues = ["netz": "05:38", "szt_mga": "09:19", "szt_gra": "09:43", "minha_gedola": "12:16",
                         "plag": "16:36", "tset": "18:29"]
        for (cle, heure) in attendues {
            #expect(heures[cle] == heure, "\(cle)")
        }
    }
}
