import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Les aéroports et le catalogue du dépôt, lus une fois pour toute la suite (l'index plié d'Aeroports reconnaît
/// ainsi le même tableau).
private enum VolDepot {
    static let aeroports: [Vol.Aeroport] = {
        guard let lignes = try? Fichiers.donnees("ios/Ressources/Contenu/aeroports.json"),
              let noms = try? Fichiers.donnees("ios/Ressources/Contenu/aeroports_noms.json") else { return [] }
        let liste = (try? Aeroports.parse(String(decoding: lignes, as: UTF8.self),
                                          noms: String(decoding: noms, as: UTF8.self))) ?? []
        Aeroports.preparer(liste)
        return liste
    }()

    static let traducteur: Traducteur? = {
        guard let catalogue = try? Fichiers.catalogue() else { return nil }
        return try? Traducteur(catalogue: catalogue, langue: "fr")
    }()

    /// Une réponse d'adsbdb : `response.flightroute` (comme RouteVolTests).
    static func route(_ icao: String, _ escales: String...) -> String {
        func p(_ iata: String) -> String { "{\"iata_code\":\"" + iata + "\"}" }
        let milieu = escales.count == 3 ? ",\"midpoint\":" + p(escales[1]) : ""
        return "{\"response\":{\"flightroute\":{\"callsign_icao\":\"" + icao + "\",\"airline\":{\"name\":\"Cie\"}," +
            "\"origin\":" + p(escales[0]) + milieu + ",\"destination\":" + p(escales[escales.count - 1]) + "}}}"
    }
}

/// L'écran du vol (VolActivity.kt) : ce qu'il montre et ce que font ses actions, avec les vrais aéroports, le vrai
/// catalogue et le calcul de Coeur ; l'horloge, les notifications, le réseau, le billet et la position sont des faux.
/// Le critère de la feuille de route (tâche 26) : la phrase « El Al Lyon TLV demain 11h » donne la carte du vol puis
/// la frise ; les notifications posées égalent le plan (VolRappels) ; sans relais, rien des services en ligne
/// n'apparaît et aucune requête ne part.
@Suite("Modèle de l'écran du vol")
@MainActor
struct VolModeleTests {

    private struct Banc {
        let modele: VolModele
        let magasin: Magasin
        let notifications: FauxVolNotifications
    }

    /// Un modèle dont l'horloge est arrêtée à `heure:minute` du jour `iso`, à Paris.
    private func fabriquer(_ iso: String, heure: Int, minute: Int = 0, reglages: Reglages = Reglages(),
                           enLigne: VolEnLigne? = nil, billet: (any VolLecteurBillet)? = nil,
                           localisation: (any Localisation)? = nil,
                           notifications: FauxVolNotifications = FauxVolNotifications()) throws -> Banc {
        let jour = try #require(JourCivil(iso: iso))
        let paris = try #require(Fuseau("Europe/Paris"))
        let horloge = HorlogeFixe(DateHeure(jour, heure: heure, minute: minute), fuseau: paris)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let traducteur = try #require(VolDepot.traducteur)
        let modele = VolModele(magasin: magasin, horloge: horloge, aeroports: { VolDepot.aeroports },
                               notificateur: notifications, retrait: notifications, localisation: localisation,
                               lecteurBillet: billet, enLigne: enLigne, traducteur: traducteur)
        return Banc(modele: modele, magasin: magasin, notifications: notifications)
    }

    private func aeroport(_ iata: String) throws -> Vol.Aeroport {
        try #require(Aeroports.parIata(VolDepot.aeroports, iata))
    }

    /// Aucun vol calculé là où le test en attend un.
    private struct SansCartes: Error {}

    /// Les cartes du vol calculé.
    private func cartes(_ modele: VolModele) throws -> VolCartes {
        guard case .cartes(let c) = modele.resultats else { throw SansCartes() }
        return c
    }

    /// Le vol Lyon → Tel-Aviv du mardi 17 novembre 2026 à 11 h (heure de Lyon), arrivée 16 h 30 (heure d'Israël),
    /// gardé dans les réglages.
    private func reglagesAvecVol() throws -> Reglages {
        let lys = try aeroport("LYS")
        let tlv = try aeroport("TLV")
        let jour = try #require(JourCivil(iso: "2026-11-17"))
        let t1 = try #require(Vol.instant(DateHeure(jour, heure: 11), lys))
        let t2 = try #require(Vol.instant(DateHeure(jour, heure: 16, minute: 30), tlv))
        return VolStockage.avecPlan(Reglages(), Vol.Plan(numero: "LY382", depart: lys, arrivee: tlv, decollage: t1,
                                                         atterrissage: t2))
    }

    // MARK: Le critère : la phrase, la carte du vol, la frise

    @Test func laPhraseDonneLaCarteDuVolPuisLaFrise() async throws {
        let banc = try fabriquer("2026-11-16", heure: 8)
        let modele = banc.modele
        await modele.apparaitre()
        #expect(modele.pret)
        // Aucun vol : le formulaire et la saisie rapide, rien en résultat.
        #expect(modele.formulaireOuvert)
        #expect(modele.resultats == .aucun)
        #expect(modele.bandeau == Libelle("vol_carte_sous"))

        modele.phrase = "El Al Lyon TLV demain 11h"
        await modele.remplir()

        let lys = try aeroport("LYS")
        let tlv = try aeroport("TLV")
        #expect(modele.depart?.iata == "LYS")
        #expect(modele.arrivee?.iata == "TLV")
        let mardi = try #require(JourCivil(iso: "2026-11-17"))
        #expect(modele.decollage == DateHeure(mardi, heure: 11))
        // L'arrivée, que la phrase ne donne pas, est estimée d'après la distance.
        let i1 = try #require(Vol.instant(DateHeure(mardi, heure: 11), lys))
        let israel = try #require(Fuseau("Asia/Jerusalem"))
        let estimee = israel.dateHeure(millis: i1 + SaisieVol.dureeEstimee(lys, tlv))
        #expect(modele.atterrissage == estimee)
        #expect(modele.arriveeEstimee)
        #expect(modele.noteArriveeEstimee)
        let compris = Libelle("vol_rapide_compris", .texte("LY · LYS \u{2192} TLV · 2026-11-17 · 11:00"))
        #expect(modele.rapide == [compris, Libelle("vol_rapide_estimee")])

        // Complet, le vol s'est calculé aussitôt : le résumé (la carte du vol) remplace le formulaire.
        let plan = try #require(modele.plan)
        #expect(plan.decollage == i1)
        #expect(!modele.formulaireOuvert)
        let resume = try #require(modele.resume)
        #expect(resume.titre == Libelle("vol_carte_vol", .texte("\u{2708}"), .texte("LYS"), .texte("TLV")))
        #expect(resume.depart == "2026-11-17 \u{2066}11:00 LYS\u{2069}")
        #expect(modele.bandeau == resume.titre)
        // Le vol est gardé dans les réglages.
        let garde = VolStockage.plan(banc.magasin.reglages, VolDepot.aeroports)
        #expect(garde == plan)

        // Puis la frise : du décollage à l'atterrissage.
        let c = try cartes(modele)
        #expect(!c.frise.vide)
        let premier = try #require(c.frise.points.first)
        let dernier = try #require(c.frise.points.last)
        #expect(premier.ciel == .bout)
        #expect(premier.nom == Libelle("vol_frise_decollage", .texte("LYS")))
        #expect(premier.heureDepart == "2026-11-17 \u{2066}11:00 LYS\u{2069}")
        #expect(dernier.nom == Libelle("vol_frise_atterrissage", .texte("TLV")))
        #expect(dernier.dernier)
        let calcul = try #require(modele.calcul)
        // Un point par zman du vol, plus les deux bouts ; « maintenant » (la veille) n'y est pas.
        #expect(c.frise.points.count == calcul.enVol.count + 2)
        // La veille, loin du vol : la prière du moment n'est pas couverte.
        #expect(c.priere.ciel == .aucun)
        #expect(c.priere.message == Libelle("vol_hors_fenetre"))
        // Sans relevé : la pastille de la route prévue.
        #expect(c.fiabilite.pastille)
    }

    @Test func lesNotificationsPoseesEgalentLePlan() async throws {
        let banc = try fabriquer("2026-11-16", heure: 8)
        let modele = banc.modele
        await modele.apparaitre()
        modele.phrase = "El Al Lyon TLV demain 11h"
        await modele.remplir()
        let calcul = try #require(modele.calcul)
        let rappels = VolRappels.rappels(calcul, enIsrael: false)
        #expect(!rappels.isEmpty)
        #expect(rappels.count <= VolNotifications.part)
        // Les rappels du calcul sont gardés avec le vol (Store.setVolRappels).
        let gardes = VolStockage.rappels(banc.magasin.reglages)
        #expect(gardes == rappels)
        // Chaque rappel (tous à venir) a sa notification, dans l'ordre, sous l'identifiant du plan.
        let prevues = await banc.notifications.prevues
        let identifiants = prevues.map { $0.identifiant }
        let attendus: [String] = rappels.enumerated().map { "vol-" + String($0.offset) + "-" + $0.element.type.rawValue + "-" +
            String($0.element.instant) }
        #expect(identifiants == attendus)
        let plan = modele.notificationsPrevues.map { $0.prevue }
        #expect(prevues == plan)
        // Tefilat haDerekh, cinq minutes après le décollage.
        let premiere = try #require(prevues.first)
        #expect(premiere.titre == Libelle("vol_rappel_derekh_titre"))
        #expect(premiere.instant == calcul.plan.decollage + VolRappels.apresDecollage)
        // La carte des rappels les montre tous, à venir.
        let carte = try cartes(modele).rappels
        #expect(carte.actifs)
        #expect(carte.lignes.count == rappels.count)
        #expect(!carte.sansPermission)
    }

    @Test func rappelsEteintsPuisRallumesSansAutorisation() async throws {
        let notifications = FauxVolNotifications(accordee: false)
        let banc = try fabriquer("2026-11-16", heure: 8, reglages: reglagesAvecVol(), notifications: notifications)
        let modele = banc.modele
        await modele.apparaitre()
        await modele.basculerRappels(false)
        let eteintes = await notifications.prevues
        #expect(eteintes.isEmpty)
        let carte = try cartes(modele).rappels
        #expect(!carte.actifs)
        #expect(carte.lignes.isEmpty)
        #expect(!banc.magasin.reglages.volRappelsActifs)

        await modele.basculerRappels(true)
        let demandes = await notifications.demandes
        #expect(demandes == 1)
        let rallumee = try cartes(modele).rappels
        #expect(rallumee.sansPermission)
        let reposees = await notifications.prevues
        #expect(!reposees.isEmpty)
    }

    // MARK: Le critère : sans relais, rien en ligne

    @Test func sansRelaisRienDesServicesEnLigneEtAucuneRequete() async throws {
        let reseau = FauxVolReseau([RouteVol.adsbdb + "/callsign/LY81": RouteVol.Reponse(code: 200,
                                                                                         corps: VolDepot.route("ELY81", "TLV", "BKK"))])
        var reglages = try reglagesAvecVol()
        // Même l'interrupteur déjà allumé (une sauvegarde d'Android) n'ouvre rien sans relais.
        reglages.setSuiviDirect(true)
        for relais in ["", "http://relais.exemple"] {
            let banc = try fabriquer("2026-11-17", heure: 13, reglages: reglages,
                                     enLigne: VolEnLigne(relais: relais, reseau: reseau))
            let modele = banc.modele
            await modele.apparaitre()
            #expect(!modele.enLigneDisponible)
            #expect(!modele.enLigneActif)
            #expect(!modele.loupeActive)
            #expect(modele.aideRoute == nil)
            #expect(modele.sources == [Libelle("zmanim_a_valider"), Libelle("vol_source_aeroports")])
            let fiabilite = try cartes(modele).fiabilite
            #expect(fiabilite.direct == nil)
            // La loupe, un numéro sans route, la position en direct : rien ne part.
            modele.modifierVol()
            modele.phrase = "LY81"
            await modele.remplir()
            await modele.loupe()
            modele.indicatifSaisi = "ELY81"
            await modele.demanderDirect()
            #expect(modele.dialogue == nil)
            #expect(modele.routeTexte == nil)
        }
        let demandes = await reseau.demandes
        #expect(demandes.isEmpty)
    }

    @Test func sansServicesEnLigneDuToutRienNApparait() async throws {
        let banc = try fabriquer("2026-11-16", heure: 8, reglages: reglagesAvecVol())
        let modele = banc.modele
        await modele.apparaitre()
        #expect(!modele.enLigneDisponible)
        #expect(modele.sources.count == 2)
        let fiabilite = try cartes(modele).fiabilite
        #expect(fiabilite.direct == nil)
    }

    // MARK: Les services en ligne, avec un relais

    @Test func laLoupeDemandeLAccordPuisRemplitLaRoute() async throws {
        let reseau = FauxVolReseau([RouteVol.adsbdb + "/callsign/LY81": RouteVol.Reponse(code: 200,
                                                                                         corps: VolDepot.route("ELY81", "TLV", "BKK"))])
        let banc = try fabriquer("2026-11-16", heure: 8, enLigne: VolEnLigne(relais: "https://relais.exemple", reseau: reseau))
        let modele = banc.modele
        await modele.apparaitre()
        #expect(modele.enLigneDisponible)
        #expect(!modele.enLigneActif)
        #expect(modele.sources.last == Libelle("vol_source_adsbdb"))
        modele.numeroSaisi = "LY81"
        await modele.loupe()
        // Éteints, les services demandent d'abord l'accord : rien n'est parti.
        #expect(modele.dialogue == .enLigne)
        let avant = await reseau.demandes
        #expect(avant.isEmpty)

        await modele.confirmerEnLigne()
        #expect(banc.magasin.reglages.suiviDirect)
        #expect(modele.depart?.iata == "TLV")
        #expect(modele.arrivee?.iata == "BKK")
        #expect(modele.routeTexte == Libelle("vol_route_trouvee", .texte("LY81"), .texte("Cie"), .texte("TLV"), .texte("BKK")))
        #expect(banc.magasin.reglages.volIndicatif == "ELY81")
        #expect(modele.indicatifSaisi == "ELY81")
        let demandes = await reseau.demandes
        #expect(demandes == [RouteVol.adsbdb + "/callsign/LY81"])
    }

    @Test func laRouteRejoueLesDemandesDeCoeur() async throws {
        // QF9 refusé en IATA : la compagnie, puis son indicatif OACI (RouteVol.chercher).
        let reseau = FauxVolReseau([
            RouteVol.adsbdb + "/callsign/QF9": RouteVol.Reponse(code: 400, corps: "{}"),
            RouteVol.adsbdb + "/airline/QF": RouteVol.Reponse(code: 200, corps: "{\"response\":[{\"icao\":\"QFA\"}]}"),
            RouteVol.adsbdb + "/callsign/QFA9": RouteVol.Reponse(code: 200, corps: VolDepot.route("QFA9", "MEL", "PER", "LHR")),
        ])
        let resultat = await VolRequetes.route("QF9", depart: "PER", reseau: reseau)
        #expect(resultat == .trouve(indicatif: "QFA9", compagnie: "Cie", escales: ["MEL", "PER", "LHR"], de: "PER", vers: "LHR"))
        let demandes = await reseau.demandes
        #expect(demandes == [RouteVol.adsbdb + "/callsign/QF9", RouteVol.adsbdb + "/airline/QF",
                             RouteVol.adsbdb + "/callsign/QFA9"])

        let horsLigne = FauxVolReseau(horsLigne: true)
        let echec = await VolRequetes.route("LY81", depart: nil, reseau: horsLigne)
        #expect(echec == .erreur(raison: SuiviVol.Raison.horsLigne))
        let tentatives = await horsLigne.demandes
        #expect(tentatives.count == 1)
    }

    @Test func uneRouteHorsLigneLeDit() async throws {
        var reglages = Reglages()
        reglages.setSuiviDirect(true)
        let banc = try fabriquer("2026-11-16", heure: 8, reglages: reglages,
                                 enLigne: VolEnLigne(relais: "https://relais.exemple", reseau: FauxVolReseau(horsLigne: true)))
        let modele = banc.modele
        await modele.apparaitre()
        modele.numeroSaisi = "LY81"
        await modele.loupe()
        #expect(modele.routeTexte == Libelle("vol_route_erreur", .libelle(Libelle("vol_erreur_hors_ligne"))))
        #expect(!modele.routeEnCours)
        modele.numeroSaisi = "bonjour"
        await modele.loupe()
        #expect(modele.routeTexte == Libelle("vol_route_invalide"))
    }

    @Test func laPositionEnDirectPasseParLeRelais() async throws {
        var reglages = try reglagesAvecVol()
        reglages.setSuiviDirect(true)
        let relais = "https://relais.exemple"
        let lys = try aeroport("LYS")
        let tlv = try aeroport("TLV")
        let mardi = try #require(JourCivil(iso: "2026-11-17"))
        let t1 = try #require(Vol.instant(DateHeure(mardi, heure: 11), lys))
        let t2 = try #require(Vol.instant(DateHeure(mardi, heure: 16, minute: 30), tlv))
        let plan = Vol.Plan(numero: "LY382", depart: lys, arrivee: tlv, decollage: t1, atterrissage: t2)
        // À 13 h à Paris (12 h UTC), en vol.
        let paris = try #require(Fuseau("Europe/Paris"))
        let maintenant = paris.millis(DateHeure(mardi, heure: 13))
        let adresse = SuiviVol.adresse(relais, "ELY382", Vol.position(plan, maintenant))
        let reseau = FauxVolReseau([adresse: RouteVol.Reponse(code: 200, corps:
            "{\"trouve\":true,\"latitude\":42.5,\"longitude\":14.2,\"altitude_geo\":11000,\"instant\":\"2026-11-17T11:58:00Z\"}")])
        let banc = try fabriquer("2026-11-17", heure: 13, reglages: reglages, enLigne: VolEnLigne(relais: relais, reseau: reseau))
        let modele = banc.modele
        await modele.apparaitre()
        let avantDirect = try cartes(modele).fiabilite
        let direct = try #require(avantDirect.direct)
        #expect(direct.actif)
        modele.indicatifSaisi = "ely 382"
        await modele.demanderDirect()
        let demandes = await reseau.demandes
        #expect(demandes == [adresse])
        let releve = try #require(modele.plan?.releve)
        #expect(releve.latitude == 42.5)
        #expect(modele.plan?.sourceReleve == .direct)
        #expect(modele.calcul?.fiabilite == .releveDirect)
        let fiabilite = try cartes(modele).fiabilite
        #expect(!fiabilite.pastille)
        #expect(fiabilite.oublier)
        #expect(banc.magasin.reglages.volIndicatif == "ELY382")
    }

    @Test func unRelaisEnPanneLeDit() async throws {
        var reglages = try reglagesAvecVol()
        reglages.setSuiviDirect(true)
        let reseau = FauxVolReseau()
        let banc = try fabriquer("2026-11-17", heure: 13, reglages: reglages,
                                 enLigne: VolEnLigne(relais: "https://relais.exemple", reseau: reseau))
        let modele = banc.modele
        await modele.apparaitre()
        modele.indicatifSaisi = "ELY382"
        // 404 se lit (de 200 à 499) : un corps sans « trouve » n'est pas l'avion.
        await modele.demanderDirect()
        #expect(modele.dialogue == .message(Libelle("vol_direct_introuvable")))
        modele.fermerDialogue()
        modele.indicatifSaisi = "12"
        await modele.demanderDirect()
        #expect(modele.dialogue == .message(Libelle("vol_indicatif_invalide")))
    }

    // MARK: La saisie rapide et le billet

    @Test func rienDeReconnu() async throws {
        let modele = try fabriquer("2026-11-16", heure: 8).modele
        await modele.apparaitre()
        modele.phrase = "bonjour"
        await modele.remplir()
        #expect(modele.rapide == [Libelle("vol_rapide_rien")])
        #expect(modele.plan == nil)
    }

    @Test func sansHeureLeChoixDeLHeureSOuvreDeLuiMeme() async throws {
        let modele = try fabriquer("2026-11-16", heure: 8).modele
        await modele.apparaitre()
        modele.phrase = "El Al Lyon TLV demain"
        await modele.remplir()
        let mardi = try #require(JourCivil(iso: "2026-11-17"))
        #expect(modele.decollage == nil)
        #expect(modele.dateSeule == mardi)
        #expect(modele.dialogue == .heure(.saisieRapide, initiale: DateHeure(mardi, heure: 12)))
        let manque = Libelle("vol_rapide_manque", .texte("l\u{2019}heure de départ"))
        #expect(modele.rapide?.last == manque)
        await modele.choisirHeure(DateHeure(mardi, heure: 11, minute: 30))
        #expect(modele.decollage == DateHeure(mardi, heure: 11, minute: 30))
        #expect(modele.plan != nil)
        #expect(modele.dialogue == nil)
    }

    @Test func leBilletDonneLaRouteEtLaDate() async throws {
        let code = "M1DUPONT/JEAN         EABC123 LYSTLVLY 0382 316Y012A0001 100"
        let billet = FauxVolLecteurBillet(code)
        let modele = try fabriquer("2026-11-04", heure: 9, billet: billet).modele
        await modele.apparaitre()
        #expect(modele.billetDisponible)
        let fichier = URL(fileURLWithPath: "/tmp/billet.pdf")
        await modele.importerBillet(fichier)
        let lus = await billet.lus
        #expect(lus == [fichier])
        let jeudi = try #require(JourCivil(iso: "2026-11-12"))
        #expect(modele.numeroSaisi == "LY382")
        #expect(modele.depart?.iata == "LYS")
        #expect(modele.arrivee?.iata == "TLV")
        #expect(modele.dateSeule == jeudi)
        #expect(modele.rapide?.first == Libelle("vol_rapide_billet_lu"))
        // Le code ne porte pas l'heure : elle se choisit, sur le jour du billet.
        #expect(modele.dialogue == .heure(.saisieRapide, initiale: DateHeure(jeudi, heure: 12)))
    }

    @Test func unBilletSansCodeOuIllisible() async throws {
        let sans = try fabriquer("2026-11-04", heure: 9, billet: FauxVolLecteurBillet(nil)).modele
        await sans.apparaitre()
        await sans.importerBillet(URL(fileURLWithPath: "/tmp/photo.jpg"))
        #expect(sans.rapide == [Libelle("vol_rapide_billet_sans_code")])
        let autre = try fabriquer("2026-11-04", heure: 9, billet: FauxVolLecteurBillet("https://exemple.org")).modele
        await autre.apparaitre()
        await autre.importerBillet(URL(fileURLWithPath: "/tmp/photo.jpg"))
        #expect(autre.rapide == [Libelle("vol_rapide_billet_illisible")])
        let aucun = try fabriquer("2026-11-04", heure: 9).modele
        #expect(!aucun.billetDisponible)
    }

    // MARK: Les tuiles et le calcul

    @Test func lesTuilesLaRechercheEtLesRefus() async throws {
        let modele = try fabriquer("2026-11-16", heure: 8).modele
        await modele.apparaitre()
        let deux = modele.tuiles.map { $0.genre }
        #expect(deux == [.depart, .arrivee])
        #expect(!modele.peutEffacer)
        await modele.calculer()
        #expect(modele.dialogue == .message(Libelle("vol_incomplet")))
        modele.fermerDialogue()

        modele.toucher(.depart)
        #expect(modele.dialogue == .aeroport(.depart))
        modele.chercherAeroport("TLV")
        #expect(modele.lignesAeroports.first?.iata == "TLV")
        modele.validerRecherche()
        #expect(modele.depart?.iata == "TLV")
        #expect(modele.dialogue == nil)
        modele.toucher(.arrivee)
        modele.chercherAeroport("zzzzzz")
        #expect(modele.rechercheVide)
        let tlv = try aeroport("TLV")
        modele.choisirAeroport(tlv)
        let quatre = modele.tuiles.map { $0.genre }
        #expect(quatre == [.depart, .arrivee, .decollage, .atterrissage])
        #expect(modele.tuiles.first?.valeur == "TLV · " + (tlv.ville.isEmpty ? tlv.nom : tlv.ville))
        #expect(modele.peutEffacer)

        let jour = try #require(JourCivil(iso: "2026-11-20"))
        modele.toucher(.decollage)
        await modele.choisirHeure(DateHeure(jour, heure: 9))
        modele.toucher(.atterrissage)
        #expect(modele.dialogue == .heure(.atterrissage, initiale: DateHeure(jour, heure: 9)))
        await modele.choisirHeure(DateHeure(jour, heure: 12))
        await modele.calculer()
        #expect(modele.dialogue == .message(Libelle("vol_invalide_meme_aeroport")))
        #expect(modele.plan == nil)
    }

    @Test func leVolGardeSeRouvreEnResumeEtSEfface() async throws {
        let banc = try fabriquer("2026-11-16", heure: 8, reglages: reglagesAvecVol())
        let modele = banc.modele
        await modele.apparaitre()
        let mardi = try #require(JourCivil(iso: "2026-11-17"))
        #expect(modele.numeroSaisi == "LY382")
        #expect(modele.decollage == DateHeure(mardi, heure: 11))
        #expect(modele.atterrissage == DateHeure(mardi, heure: 16, minute: 30))
        #expect(!modele.formulaireOuvert)
        #expect(modele.bandeau == Libelle("vol_carte_vol", .texte("LY382"), .texte("LYS"), .texte("TLV")))
        modele.modifierVol()
        #expect(modele.formulaireOuvert)
        #expect(modele.resume == nil)
        let avant = await banc.notifications.prevues
        #expect(!avant.isEmpty)

        await modele.effacer()
        #expect(modele.plan == nil)
        #expect(modele.calcul == nil)
        #expect(modele.resultats == .aucun)
        #expect(modele.numeroSaisi.isEmpty)
        #expect(VolStockage.plan(banc.magasin.reglages, VolDepot.aeroports) == nil)
        let gardes = VolStockage.rappels(banc.magasin.reglages)
        #expect(gardes.isEmpty)
        let apres = await banc.notifications.prevues
        #expect(apres.isEmpty)
        let retraits = await banc.notifications.retraits
        #expect(retraits.last == VolNotifications.prefixe)
    }

    // MARK: Pendant le vol

    @Test func pendantLeVolLaPriereEtMaintenantSurLaFrise() async throws {
        let banc = try fabriquer("2026-11-17", heure: 13, reglages: reglagesAvecVol())
        let modele = banc.modele
        await modele.apparaitre()
        let calcul = try #require(modele.calcul)
        let c = try cartes(modele)
        // La prière du moment est celle de VolPriere, avec son compte à rebours.
        let moment = try #require(VolPriere.priere(calcul, modele.maintenant))
        #expect(c.priere.nom == VolMiseEnPage.nomPriere(moment.priere))
        if let limite = moment.limite {
            let minutes = Int(max(0, VolMiseEnPage.minutes(de: modele.maintenant, a: limite)))
            #expect(c.priere.compte == Libelle("vol_dans", .libelle(VolMiseEnPage.dureeEnMots(minutes))))
            #expect(c.priere.limite == limite)
        } else {
            #expect(c.priere.message == Libelle("vol_sans_limite"))
        }
        // « Maintenant » juste avant le premier zman à venir, s'il y en a un.
        let rangs = c.frise.points.filter { $0.ciel == .maintenant }.map { $0.id }
        if let suivant = calcul.enVol.firstIndex(where: { $0.instant > modele.maintenant }) {
            #expect(rangs == [suivant + 1])
        } else {
            #expect(rangs.isEmpty)
        }
        // Les rappels montrés sont ceux à venir.
        let aVenir = VolRappels.rappels(calcul, enIsrael: false).filter { $0.instant > modele.maintenant }
        #expect(c.rappels.lignes.count == aVenir.count)
        #expect(c.rappels.aucun == aVenir.isEmpty)
    }

    @Test func leReleveGpsRecaleLaRoute() async throws {
        let localisation = FausseLocalisation(.position(PositionApprochee(latitude: 42.5, longitude: 14.2)))
        let banc = try fabriquer("2026-11-17", heure: 13, reglages: reglagesAvecVol(), localisation: localisation)
        let modele = banc.modele
        await modele.apparaitre()
        let bouton = try cartes(modele).fiabilite.gps
        #expect(bouton == Libelle("vol_gps"))
        await modele.releverGps()
        let releve = try #require(modele.plan?.releve)
        let paris = try #require(Fuseau("Europe/Paris"))
        let mardi = try #require(JourCivil(iso: "2026-11-17"))
        #expect(releve.instant == paris.millis(DateHeure(mardi, heure: 13)))
        #expect(modele.calcul?.fiabilite == .releveGps)
        let fiabilite = try cartes(modele).fiabilite
        #expect(!fiabilite.pastille)
        #expect(fiabilite.oublier)
        // Le relevé est gardé avec le vol.
        let garde = VolStockage.plan(banc.magasin.reglages, VolDepot.aeroports)?.releve
        #expect(garde == releve)
        await modele.oublierReleve()
        #expect(modele.plan?.releve == nil)
        #expect(modele.calcul?.fiabilite == .routePrevue)
    }

    @Test func leGpsHorsDuVolOuRefuse() async throws {
        let avant = try fabriquer("2026-11-16", heure: 8, reglages: reglagesAvecVol(),
                                  localisation: FausseLocalisation(.position(PositionApprochee(latitude: 45.7, longitude: 5.1))))
        await avant.modele.apparaitre()
        await avant.modele.releverGps()
        #expect(avant.modele.dialogue == .message(Libelle("vol_gps_hors_vol")))
        #expect(avant.modele.plan?.releve == nil)
        let refuse = try fabriquer("2026-11-17", heure: 13, reglages: reglagesAvecVol(),
                                   localisation: FausseLocalisation(.refusee))
        await refuse.modele.apparaitre()
        await refuse.modele.releverGps()
        #expect(refuse.modele.dialogue == .message(Libelle("vol_gps_refuse")))
        let sans = try fabriquer("2026-11-17", heure: 13, reglages: reglagesAvecVol())
        await sans.modele.apparaitre()
        let sansBouton = try cartes(sans.modele).fiabilite.gps
        #expect(sansBouton == nil)
    }

    // MARK: Le vol gardé et les textes

    @Test func leVolEtSesRappelsSeGardentCommeSurAndroid() throws {
        let lys = try aeroport("LYS")
        let tlv = try aeroport("TLV")
        let plan = Vol.Plan(numero: "LY382", depart: lys, arrivee: tlv, decollage: 1_000, atterrissage: 2_000,
                            releve: Vol.Point(instant: 1_500, latitude: 42.5, longitude: -0.25), sourceReleve: .direct)
        let reglages = VolStockage.avecPlan(Reglages(), plan)
        let relu = VolStockage.plan(reglages, VolDepot.aeroports)
        #expect(relu == plan)
        let source = reglages.brut["vol_releve_source"]
        #expect(source == JSON.chaine("DIRECT"))
        let longitude = reglages.brut["vol_releve_longitude"]
        #expect(longitude == JSON.chaine("-0.25"))
        let sansReleve = VolStockage.avecPlan(reglages, Vol.Plan(numero: "", depart: lys, arrivee: tlv, decollage: 1_000,
                                                                atterrissage: 2_000))
        #expect(!sansReleve.brut.a("vol_releve_latitude"))

        let rappels = [VolRappels.Rappel(type: .tefilatHaderekh, instant: 1_300, priere: "minha", limite: 1_900),
                       VolRappels.Rappel(type: .omer, instant: 1_800, omer: 12)]
        let avec = VolStockage.avecRappels(reglages, rappels)
        let ecrits = avec.brut["vol_rappels"]
        #expect(ecrits == JSON.chaine("TEFILAT_HADEREKH|1300|minha|1900|0\nOMER|1800|||12"))
        #expect(VolStockage.rappels(avec) == rappels)
        let efface = VolStockage.avecPlan(avec, nil)
        #expect(!efface.brut.a("vol_rappels"))
        #expect(VolStockage.plan(efface, VolDepot.aeroports) == nil)
    }

    @Test func lesTextesDeVolActivity() throws {
        #expect(VolMiseEnPage.dureeEnMots(1) == Libelle("vol_duree_une_minute"))
        #expect(VolMiseEnPage.dureeEnMots(10) == Libelle("vol_duree_minutes", .texte("10")))
        #expect(VolMiseEnPage.dureeEnMots(120) == Libelle("vol_duree_heures", .texte("2")))
        #expect(VolMiseEnPage.dureeEnMots(71) == Libelle("vol_duree_heures_minutes", .texte("1"), .texte("11")))
        // `Duration.toMinutes` : les secondes vers moins l'infini, puis la division tronquée.
        #expect(VolMiseEnPage.minutes(de: 0, a: 119_999) == 1)
        #expect(VolMiseEnPage.minutes(de: 0, a: -119_999) == -2)
        #expect(VolMiseEnPage.minutes(de: 0, a: -60_000) == -1)
        #expect(VolMiseEnPage.ecart(-720_000, recale: false) == Libelle("vol_ecart", .texte("\u{2212}12")))
        #expect(VolMiseEnPage.ecart(300_000, recale: true) == Libelle("vol_ecart_gps", .texte("+5")))
        let position = VolMiseEnPage.position(48.86, -2.35, VolFormats.langue("fr"))
        #expect(position == Libelle("vol_position", .libelle(Libelle("vol_lat_nord", .texte("48,9"))),
                                    .libelle(Libelle("vol_lon_ouest", .texte("2,4")))))
        #expect(VolMiseEnPage.raison("serveur_503") == Libelle("vol_erreur_serveur", .entier(503)))
        #expect(VolMiseEnPage.raison(SuiviVol.Raison.quota) == Libelle("vol_erreur_quota"))
        #expect(VolMiseEnPage.raison("inconnue") == Libelle("vol_erreur_service"))
        #expect(VolMiseEnPage.nomZman("tset") == Libelle("zman_tset"))
        let traducteur = try #require(VolDepot.traducteur)
        let texte = traducteur.texte(Libelle("vol_dans", .libelle(VolMiseEnPage.dureeEnMots(71))))
        #expect(texte == "encore 1 h 11 min")
    }

    @Test func lesHeuresAuxDeuxAeroports() throws {
        let lys = try aeroport("LYS")
        let jfk = try aeroport("JFK")
        let jour = try #require(JourCivil(iso: "2026-11-17"))
        let t1 = try #require(Vol.instant(DateHeure(jour, heure: 18), lys))
        let plan = Vol.Plan(numero: "", depart: lys, arrivee: jfk, decollage: t1, atterrissage: t1 + 9 * 3_600_000)
        // 18 h à Lyon, 12 h à New York : le même jour, l'arrivée sans jour.
        let memeJour = VolMiseEnPage.texteDeuxHeures(plan, t1, .neutre)
        #expect(memeJour == "2026-11-17 \u{2066}18:00 LYS\u{2069} · \u{2066}12:00 JFK\u{2069}")
        // 2 h à Lyon le 18, 20 h à New York le 17 : le jour de l'arrivée est dit.
        let nuit = VolMiseEnPage.texteDeuxHeures(plan, t1 + 8 * 3_600_000, .neutre)
        #expect(nuit == "2026-11-18 \u{2066}02:00 LYS\u{2069} · 2026-11-17 \u{2066}20:00 JFK\u{2069}")
    }
}
