import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le modèle de la boussole de Jérusalem (BoussoleActivity.kt, BoussoleView.kt, BoussoleDessin.kt,
/// ChoixLieu.kt) : ce que l'écran montre dans chaque état (sans lieu, sans capteur, en attente du cap, à
/// calibrer, aligné), les directions et la déclinaison, la scène dessinée, les choix et la reprise. Les
/// règles elles-mêmes (DirectionJerusalem, Boussole, Magnetisme, Villes) sont jugées dans CoeurTests ; ici,
/// que l'écran s'en sert comme Android. Les deux cas de la boussole de RepriseBoussoleTest (à plat, droit)
/// sont rejoués à travers le modèle, déclinaison comprise.
///
/// Reste au test d'interface : les captures pour six caps, le Canvas, le retour haptique joué, VoiceOver,
/// les dialogues et le Toast à l'écran.
@Suite("Modèle de la boussole")
@MainActor
struct BoussoleModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)
    private static let catalogue: Result<Data, any Error> = Result { try Fichiers.catalogue() }
    private static let tableaux: Result<Data, any Error> = Result {
        try Fichiers.donnees("ios/Ressources/Chaines/Tableaux.json")
    }

    private let newYork = Zmanim.Lieu(nom: "New York", latitude: 40.71427, longitude: -74.00597, fuseau: "America/New_York")
    private let paris = Zmanim.Lieu(nom: "Paris", latitude: 48.85341, longitude: 2.3488, fuseau: "Europe/Paris")
    private let idNewYork: Int64 = 5_128_581
    private let idJerusalem: Int64 = 281_184

    /// Le modèle et ses faux.
    private struct Banc {
        let modele: BoussoleModele
        let magasin: Magasin
        let horloge: HorlogeFixe
        let traducteur: Traducteur
        let capteur: BoussoleFauxCapteur
        let localisation: FausseLocalisation
        let autorisation: BoussoleFausseAutorisationLieu
        let rafraichissement: BoussoleFauxRafraichissement
    }

    /// Le lieu donné (une position du téléphone, sauf `ville`), l'horloge arrêtée le 15/11/2026 à midi dans le
    /// fuseau du lieu (New York sans lieu).
    private func banc(_ lieu: Zmanim.Lieu?, ville: Ville? = nil, langue: String = "fr", capteur: Bool = true,
                      reponse: ReponseLocalisation = .indisponible, permise: Bool = true,
                      regler: (inout Reglages) -> Void = { _ in }) throws -> Banc {
        var reglages = Reglages()
        if let lieu {
            reglages.setLieuZmanim(lieu, ville: ville, maintenant: 1)
        }
        regler(&reglages)
        let fuseau = try #require(Fuseau(lieu?.fuseau ?? "America/New_York"))
        let jour = try #require(JourCivil(iso: "2026-11-15"))
        let horloge = HorlogeFixe(DateHeure(jour, heure: 12), fuseau: fuseau)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let traducteur = try Traducteur(catalogue: Self.catalogue.get(), langue: langue)
        let tableaux = try BoussoleTableaux(donnees: Self.tableaux.get(), langue: langue)
        let faux = BoussoleFauxCapteur(disponible: capteur)
        let localisation = FausseLocalisation(reponse)
        let autorisation = BoussoleFausseAutorisationLieu(permise: permise)
        let rafraichissement = BoussoleFauxRafraichissement()
        let modele = BoussoleModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, traducteur: traducteur,
                                    tableaux: tableaux, capteur: faux, localisation: localisation,
                                    autorisationLieu: autorisation, rafraichissement: rafraichissement)
        return Banc(modele: modele, magasin: magasin, horloge: horloge, traducteur: traducteur, capteur: faux,
                    localisation: localisation, autorisation: autorisation, rafraichissement: rafraichissement)
    }

    private func ville(_ id: Int64) async throws -> Ville {
        let villes = try await Self.contenus.villes()
        let trouvee = villes.first { $0.id == id }
        let ville = try #require(trouvee)
        return ville
    }

    /// La matrice Est-Nord-Haut ← téléphone de la spécification DeviceOrientation (Z·X·Y), ligne par ligne :
    /// celle de RepriseBoussoleTest et de BoussoleTests.
    private func matrice(_ alpha: Double, _ beta: Double, _ gamma: Double) -> [Float] {
        let r = Double.pi / 180
        let cA = cos(alpha * r)
        let sA = sin(alpha * r)
        let cB = cos(beta * r)
        let sB = sin(beta * r)
        let cG = cos(gamma * r)
        let sG = sin(gamma * r)
        let lignes: [Double] = [
            cA * cG - sA * sB * sG, -cB * sA, cG * sA * sB + cA * sG,
            cG * sA + cA * sB * sG, cA * cB, sA * sG - cA * cG * sB,
            -cB * sG, sB, cB * cG,
        ]
        return lignes.map { Float($0) }
    }

    private func proche(_ attendu: Double, _ mesure: Double) -> Bool {
        abs(DirectionJerusalem.ecart(attendu, mesure)) <= 0.01
    }

    /// Attend qu'une condition se vérifie, en laissant tourner les autres tâches de l'acteur principal. La
    /// condition est isolée à l'acteur principal : une fermeture non `Sendable` appelée d'ici sans cela partirait
    /// vers un appelé non isolé (« sending 'condition' risks causing data races » en Swift 6).
    private func attendre(_ condition: @MainActor () async -> Bool) async -> Bool {
        for _ in 0..<10_000 {
            if await condition() { return true }
            await Task.yield()
        }
        return false
    }

    // MARK: Sans lieu

    @Test func sansLieuLEtatVide() throws {
        let modele = try banc(nil).modele
        #expect(modele.etat == .sansLieu)
        #expect(modele.pastille == nil)
        #expect(modele.scene == nil)
        #expect(modele.directionSuivie == nil)
        #expect(modele.directionAutre == nil)
        #expect(modele.distance == nil)
        #expect(modele.legende == nil)
        #expect(modele.consigne == Libelle("zmanim_choisir_lieu"))
        #expect(modele.consigneAccessible == Libelle("zmanim_choisir_lieu"))
        // Le capteur tourne, mais sans lieu rien ne s'affiche ni ne vibre.
        modele.recevoir(.cap(10))
        modele.recevoir(.precision(.basse))
        #expect(modele.cap == nil)
        #expect(!modele.montrerCalibrage)
        #expect(modele.alignements == 0)
    }

    @Test func laPastilleDuBandeau() throws {
        let nomme = try banc(newYork).modele
        #expect(nomme.pastille == .nom("New York"))
        let sansNom = Zmanim.Lieu(nom: "", latitude: 40.71427, longitude: -74.00597, fuseau: "America/New_York")
        let anonyme = try banc(sansNom).modele
        #expect(anonyme.pastille == .libelle(Libelle("zmanim_choisir_lieu")))
    }

    @Test func leHassidAuFeminin() throws {
        let hassid = try banc(newYork).modele.imageHassid
        #expect(hassid == "char_standing_back")
        let feminin = try banc(newYork, regler: { $0.setAdresse("f") }).modele.imageHassid
        #expect(feminin == "char_f_standing_back")
    }

    // MARK: Les directions

    @Test func lesDeuxDirectionsDeNewYork() throws {
        let b = try banc(newYork)
        let modele = b.modele
        let grandCercle = DirectionJerusalem.grandCercle(newYork.latitude, newYork.longitude)
        let carte = DirectionJerusalem.carte(newYork.latitude, newYork.longitude)
        #expect(modele.principale == grandCercle)
        #expect(modele.autre == carte)
        // De New York : environ 54° et 96° (DirectionJerusalem.kt).
        #expect(modele.directionSuivie == Libelle("boussole_grand_cercle", .entier(54), .texte("NE")))
        #expect(modele.directionAutre == Libelle("boussole_cap_constant", .entier(96), .texte("E")))
        #expect(modele.legende == Libelle("boussole_legende"))
        #expect(modele.methodeChoisie == Libelle("boussole_methode_reelle"))
        #expect(modele.affichageChoisi == Libelle("boussole_affichage_hassid"))
        #expect(modele.distanceKm == 9169)
        #expect(modele.distance == Libelle("boussole_distance", .texte("9\u{202F}169")))
        let suivie = b.traducteur.texte(try #require(modele.directionSuivie))
        #expect(suivie == "Direction réelle (grand cercle)\u{00A0}: 54° NE")
        let distance = b.traducteur.texte(try #require(modele.distance))
        #expect(distance == "Distance\u{00A0}: 9\u{202F}169 km")
    }

    @Test func selonLaCarteLesLignesSEchangent() async throws {
        let b = try banc(newYork)
        let modele = b.modele
        modele.ouvrirMethode()
        #expect(modele.dialogue == .methode)
        #expect(modele.dialogue?.titre == Libelle("boussole_methode"))
        let avant = modele.optionsMethode.map { $0.choisie }
        #expect(avant == [true, false])
        try await modele.choisirMethode(selonCarte: true)
        #expect(modele.dialogue == nil)
        #expect(b.magasin.reglages.boussoleCarte)
        #expect(modele.principale == DirectionJerusalem.carte(newYork.latitude, newYork.longitude))
        #expect(modele.autre == DirectionJerusalem.grandCercle(newYork.latitude, newYork.longitude))
        #expect(modele.directionSuivie == Libelle("boussole_cap_constant", .entier(96), .texte("E")))
        #expect(modele.directionAutre == Libelle("boussole_grand_cercle", .entier(54), .texte("NE")))
        #expect(modele.legende == Libelle("boussole_legende_carte"))
        #expect(modele.methodeChoisie == Libelle("boussole_methode_carte"))
        let apres = modele.optionsMethode.map { $0.choisie }
        #expect(apres == [false, true])
        let valeurs = modele.optionsMethode.map { $0.valeur }
        #expect(valeurs == [false, true])
        // Le widget suit la méthode (BoussoleWidget.refresh).
        let rafraichi = await b.rafraichissement.rafraichissements
        #expect(rafraichi == 1)
    }

    @Test func lesPointsEtLesChiffresSuiventLaLangue() throws {
        let hebreu = try BoussoleTableaux(donnees: Self.tableaux.get(), langue: "he")
        let he = try banc(newYork, langue: "he").modele
        #expect(he.directionSuivie == Libelle("boussole_grand_cercle", .entier(54), .texte(hebreu.points[1])))
        #expect(he.cardinaux == hebreu.cardinaux)
        #expect(he.distance == Libelle("boussole_distance", .texte("9,169")))
        let b = try banc(paris, langue: "en")
        // 112,48° / 45 = 2,4996 : le point le plus proche est l'est, pas le sud-est (DirectionJerusalem.point).
        #expect(b.modele.directionSuivie == Libelle("boussole_grand_cercle", .entier(112), .texte("E")))
        #expect(b.modele.directionAutre == Libelle("boussole_cap_constant", .entier(124), .texte("SE")))
        #expect(b.modele.cardinaux == ["N", "E", "S", "W"])
        let distance = b.traducteur.texte(try #require(b.modele.distance))
        #expect(distance == "Distance: 3,333 km")
    }

    @Test func lesNombresGroupesCommeAndroid() {
        #expect(BoussoleModele.entierGroupe(2, langue: "fr") == "2")
        #expect(BoussoleModele.entierGroupe(999, langue: "fr") == "999")
        #expect(BoussoleModele.entierGroupe(1000, langue: "fr") == "1\u{202F}000")
        #expect(BoussoleModele.entierGroupe(14128, langue: "fr") == "14\u{202F}128")
        #expect(BoussoleModele.entierGroupe(14128, langue: "en") == "14,128")
        #expect(BoussoleModele.entierGroupe(9169, langue: "he") == "9,169")
        #expect(BoussoleModele.entierGroupe(1_234_567, langue: "en") == "1,234,567")
    }

    @Test func lesTableauxDeTableauxJson() throws {
        let fr = try BoussoleTableaux(donnees: Self.tableaux.get(), langue: "fr")
        #expect(fr.points == ["N", "NE", "E", "SE", "S", "SO", "O", "NO"])
        #expect(fr.cardinaux == ["N", "E", "S", "O"])
        let en = try BoussoleTableaux(donnees: Self.tableaux.get(), langue: "en")
        #expect(en.points == ["N", "NE", "E", "SE", "S", "SW", "W", "NW"])
        let he = try BoussoleTableaux(donnees: Self.tableaux.get(), langue: "he")
        #expect(he.points.count == 8)
        #expect(he.cardinaux.count == 4)
        // Une langue que le fichier n'a pas se lit en français.
        let autre = try BoussoleTableaux(donnees: Self.tableaux.get(), langue: "de")
        #expect(autre == fr)
        // Le point le plus proche, 337,5° compris (DirectionJerusalem.point).
        #expect(fr.point(0) == "N")
        #expect(fr.point(54.06) == "NE")
        #expect(fr.point(337.6) == "N")
        let incomplet = Data(#"{"fr":{"boussole_points":["N"],"boussole_cardinaux":["N","E","S","O"]}}"#.utf8)
        #expect(throws: BoussoleTableaux.Erreur.incomplet("boussole_points")) {
            try BoussoleTableaux(donnees: incomplet, langue: "fr")
        }
    }

    // MARK: Le cap et la déclinaison

    @Test func laDeclinaisonDonneLeNordVrai() throws {
        let b = try banc(newYork)
        let modele = b.modele
        let d = try #require(modele.declinaison)
        let attendue = Magnetisme.declinaison(newYork.latitude, newYork.longitude, millis: b.horloge.maintenant)
        #expect(d == attendue)
        // À New York, le nord magnétique est à une douzaine de degrés à l'ouest du nord vrai.
        #expect(d < -10 && d > -15)
        modele.recevoir(.cap(100))
        let premier = try #require(modele.cap)
        #expect(premier == DirectionJerusalem.norm(100 + d))
        // Puis le filtre doux : un cinquième du chemin.
        modele.recevoir(.cap(120))
        #expect(modele.cap == Boussole.lisser(premier, DirectionJerusalem.norm(120 + d)))
    }

    @Test func laDeclinaisonSuitLeLieu() async throws {
        let b = try banc(newYork)
        let avant = try #require(b.modele.declinaison)
        await b.modele.ouvrirChoixLieu()
        let idParis: Int64 = 2_988_507
        try await b.modele.choisirVille(id: idParis)
        let apres = try #require(b.modele.declinaison)
        #expect(apres == Magnetisme.declinaison(paris.latitude, paris.longitude, millis: b.horloge.maintenant))
        #expect(apres != avant)
    }

    /// RepriseBoussoleTest.aPlatLeHautDeLEcran, à travers le modèle : le cap magnétique de la matrice, plus la
    /// déclinaison du lieu.
    @Test func aPlatLeHautDeLEcran() throws {
        for a in [0.0, 30.0, 90.0, 200.0, 359.0] {
            let modele = try banc(newYork).modele
            let d = try #require(modele.declinaison)
            let m = matrice(a, 0, 0)
            modele.recevoir(.orientation(m))
            let cap = try #require(modele.cap)
            #expect(cap == DirectionJerusalem.norm(Boussole.capDevant(m) + d))
            let juste = proche(DirectionJerusalem.norm(360 - a + d), cap)
            #expect(juste, "alpha \(a) : \(cap)")
        }
    }

    /// RepriseBoussoleTest.droitLeDosDuTelephone : tenu droit, le cap ne s'affole pas (bug du 02/11).
    @Test func droitLeDosDuTelephone() throws {
        var cas: [(alpha: Double, beta: Double, cap: Double)] = [
            (alpha: 0, beta: 90, cap: 0), (alpha: 180, beta: 90, cap: 180),
        ]
        // De 30° à la verticale : toujours l'est, sans saut.
        for beta in [30.0, 45.0, 60.0, 80.0, 89.0, 89.9, 90.0] {
            cas.append((alpha: 270, beta: beta, cap: 90))
        }
        for c in cas {
            let modele = try banc(newYork).modele
            let d = try #require(modele.declinaison)
            modele.recevoir(.orientation(matrice(c.alpha, c.beta, 0)))
            let cap = try #require(modele.cap)
            let juste = proche(DirectionJerusalem.norm(c.cap + d), cap)
            #expect(juste, "(\(c.alpha), \(c.beta)) : \(cap)")
        }
    }

    @Test func uneMesureInvalideEstIgnoree() throws {
        let modele = try banc(newYork).modele
        modele.recevoir(.orientation([1, 0, 0]))
        modele.recevoir(.cap(.nan))
        modele.recevoir(.cap(.infinity))
        #expect(modele.capLisse == nil)
        #expect(modele.etat == .attenteDuCap)
    }

    // MARK: Les états

    @Test func enAttenteDuCapLaRoseFixe() throws {
        let modele = try banc(newYork).modele
        let p = try #require(modele.principale)
        #expect(modele.etat == .attenteDuCap)
        #expect(modele.aide == Libelle("boussole_a_plat"))
        #expect(modele.scene == .roseFixe(BoussoleRoseFixe(principale: p, degres: 54)))
        #expect(modele.consigne == Libelle("boussole_par_rapport_nord", .entier(54)))
        #expect(modele.consigneAccessible == Libelle("boussole_par_rapport_nord", .entier(54)))
        #expect(modele.nord == Libelle("boussole_nord"))
    }

    @Test func sansCapteurLaRoseFixeAuNord() async throws {
        let b = try banc(newYork, capteur: false)
        let modele = b.modele
        // Sans capteur, l'écoute rend la main tout de suite.
        await modele.suivreCapteur()
        #expect(!modele.avecCapteur)
        #expect(modele.etat == .sansCapteur)
        #expect(modele.aide == Libelle("boussole_sans_capteur"))
        let p = try #require(modele.principale)
        #expect(modele.scene == .roseFixe(BoussoleRoseFixe(principale: p, degres: 54)))
        #expect(modele.consigne == Libelle("boussole_par_rapport_nord", .entier(54)))
        let abonnements = await b.capteur.abonnements
        #expect(abonnements == 0)
        modele.recevoir(.cap(10))
        #expect(modele.cap == nil)
    }

    @Test func aCalibrerQuandLaPrecisionEstBasse() throws {
        let modele = try banc(newYork).modele
        #expect(!modele.montrerCalibrage)
        let attendus: [(BoussolePrecision, Bool)] = [(.nonFiable, true), (.basse, true), (.moyenne, false), (.haute, false)]
        for (precision, calibrer) in attendus {
            modele.recevoir(.precision(precision))
            #expect(modele.montrerCalibrage == calibrer, "\(precision)")
            #expect(precision.aCalibrer == calibrer, "\(precision)")
        }
    }

    @Test func laConsigneDitDeCombienTourner() throws {
        // Le cap vrai voulu, moins la déclinaison : la mesure magnétique qui l'y amène.
        func consigne(ecart: Double) throws -> Libelle {
            let modele = try banc(newYork).modele
            let p = try #require(modele.principale)
            let d = try #require(modele.declinaison)
            modele.recevoir(.cap(p - ecart - d))
            return modele.consigne
        }
        #expect(try consigne(ecart: 30) == Libelle("boussole_droite", .entier(30)))
        #expect(try consigne(ecart: -50) == Libelle("boussole_gauche", .entier(50)))
        #expect(try consigne(ecart: 3) == Libelle("boussole_face"))
        #expect(try consigne(ecart: -3) == Libelle("boussole_face"))
        #expect(try consigne(ecart: 170) == Libelle("boussole_droite", .entier(170)))
    }

    @Test func alignementRetourHaptiqueEtVoiceOver() throws {
        let modele = try banc(newYork).modele
        let p = try #require(modele.principale)
        let d = try #require(modele.declinaison)
        #expect(modele.alignements == 0)
        modele.recevoir(.cap(p - d))
        #expect(modele.alignee)
        #expect(modele.alignements == 1)
        #expect(modele.consigne == Libelle("boussole_face"))
        #expect(modele.consigneAccessible == Libelle("boussole_face"))
        guard case .hassid(let face) = modele.scene else {
            Issue.record("la scène du hassid était attendue")
            return
        }
        #expect(face.face)
        #expect(face.yHassid == -68)
        // Rester face à Jérusalem ne vibre pas de nouveau.
        modele.recevoir(.cap(p - d))
        #expect(modele.alignements == 1)
        // Le départ : le cap fait un cinquième du chemin, 18°, et VoiceOver l'apprend.
        modele.recevoir(.cap(p + 90 - d))
        #expect(!modele.alignee)
        let depart = modele.consigne
        #expect(depart == Libelle("boussole_gauche", .entier(18)))
        #expect(modele.consigneAccessible == depart)
        // Les mesures suivantes changent la consigne affichée, pas celle que lit VoiceOver.
        modele.recevoir(.cap(p + 90 - d))
        #expect(modele.consigne == Libelle("boussole_gauche", .entier(32)))
        #expect(modele.consigneAccessible == depart)
        // Le retour face à Jérusalem vibre une seconde fois.
        var mesures = 0
        while !modele.alignee && mesures < 50 {
            modele.recevoir(.cap(p - d))
            mesures += 1
        }
        #expect(modele.alignee)
        #expect(modele.alignements == 2)
        #expect(modele.consigneAccessible == Libelle("boussole_face"))
    }

    // MARK: La scène

    @Test func laSceneDuHassid() throws {
        let modele = try banc(newYork).modele
        let p = try #require(modele.principale)
        let a = try #require(modele.autre)
        let d = try #require(modele.declinaison)
        modele.recevoir(.cap(p - 12 - d))
        let cap = try #require(modele.cap)
        guard case .hassid(let hassid) = modele.scene else {
            Issue.record("la scène du hassid était attendue")
            return
        }
        #expect(abs(hassid.ecart - 12) < 1e-9)
        #expect(!hassid.face)
        #expect(hassid.yHassid == -62)
        #expect(hassid.xJerusalem == BoussoleScene.xHorizon(hassid.ecart))
        #expect(abs(hassid.xJerusalem - 26.4) < 1e-4)
        #expect(hassid.xEtiquette == hassid.xJerusalem)
        #expect(hassid.xAutre == BoussoleScene.xHorizon(DirectionJerusalem.ecart(a, cap)))
        #expect(hassid.consigne == Libelle("boussole_droite", .entier(12)))
        #expect(modele.etat == .orientee)
    }

    /// Les six caps des captures de la feuille de route (0°, 60°… 300° depuis le nord vrai, de New York) : la
    /// consigne, et où le hassid voit Jérusalem et l'autre direction sur l'horizon. La capture elle-même reste
    /// au test d'interface.
    @Test func sixCaps() throws {
        struct Cas {
            let cap: Double
            let consigne: Libelle
            let xJerusalem: Double
            let xEtiquette: Double
            let xAutre: Double
        }
        let cas = [
            Cas(cap: 0, consigne: Libelle("boussole_droite", .entier(54)), xJerusalem: 118.925, xEtiquette: 118.925,
                xAutre: 150),
            Cas(cap: 60, consigne: Libelle("boussole_gauche", .entier(6)), xJerusalem: -13.075, xEtiquette: -13.075,
                xAutre: 78.769),
            Cas(cap: 120, consigne: Libelle("boussole_gauche", .entier(66)), xJerusalem: -145.075, xEtiquette: -124,
                xAutre: -53.231),
            Cas(cap: 180, consigne: Libelle("boussole_gauche", .entier(126)), xJerusalem: -150, xEtiquette: -124,
                xAutre: -150),
            Cas(cap: 240, consigne: Libelle("boussole_droite", .entier(174)), xJerusalem: 150, xEtiquette: 124,
                xAutre: -150),
            Cas(cap: 300, consigne: Libelle("boussole_droite", .entier(114)), xJerusalem: 150, xEtiquette: 124,
                xAutre: 150),
        ]
        for c in cas {
            let modele = try banc(newYork).modele
            let d = try #require(modele.declinaison)
            modele.recevoir(.cap(c.cap - d))
            #expect(modele.etat == .orientee)
            #expect(!modele.alignee)
            #expect(modele.consigne == c.consigne, "cap \(c.cap)")
            guard case .hassid(let hassid) = modele.scene else {
                Issue.record("la scène du hassid était attendue, cap \(c.cap)")
                continue
            }
            let x = abs(hassid.xJerusalem - c.xJerusalem) < 0.01
            #expect(x, "cap \(c.cap) : \(hassid.xJerusalem)")
            let etiquette = abs(hassid.xEtiquette - c.xEtiquette) < 0.01
            #expect(etiquette, "cap \(c.cap) : \(hassid.xEtiquette)")
            let autre = abs(hassid.xAutre - c.xAutre) < 0.01
            #expect(autre, "cap \(c.cap) : \(hassid.xAutre)")
            #expect(hassid.yHassid == -62)
            #expect(hassid.consigne == c.consigne)
        }
    }

    @Test func lHorizonEtLEtiquetteRestentDansLeCadre() {
        #expect(BoussoleScene.xHorizon(0) == 0)
        #expect(BoussoleScene.xHorizon(10) == Double(Float(10) * Float(2.2)))
        #expect(BoussoleScene.xHorizon(90) == 150)
        #expect(BoussoleScene.xHorizon(-179) == -150)
        #expect(BoussoleScene.xEtiquette(140) == 124)
        #expect(BoussoleScene.xEtiquette(-150) == -124)
        #expect(BoussoleScene.xEtiquette(30) == 30)
        #expect(BoussoleScene.jerusalem == "ירושלים")
    }

    @Test func laRoseDesVents() async throws {
        let b = try banc(newYork, regler: { $0.setBoussoleRose(true) })
        let modele = b.modele
        #expect(modele.affichageChoisi == Libelle("boussole_affichage_rose"))
        let coches = modele.optionsAffichage.map { $0.choisie }
        #expect(coches == [false, true])
        let p = try #require(modele.principale)
        let d = try #require(modele.declinaison)
        modele.recevoir(.cap(p + 40 - d))
        let cap = try #require(modele.cap)
        guard case .roseVivante(let rose) = modele.scene else {
            Issue.record("la rose des vents était attendue")
            return
        }
        #expect(rose.cap == cap)
        #expect(rose.principale == p)
        #expect(rose.autre == modele.autre)
        #expect(!rose.face)
        #expect(rose.tolerance == 4)
        #expect(rose.consigne == Libelle("boussole_gauche", .entier(40)))
        // Revenir au hassid.
        modele.ouvrirAffichage()
        #expect(modele.dialogue == .affichage)
        try await modele.choisirAffichage(rose: false)
        #expect(modele.dialogue == nil)
        #expect(!b.magasin.reglages.boussoleRose)
        guard case .hassid = modele.scene else {
            Issue.record("la scène du hassid était attendue")
            return
        }
        // L'affichage ne change rien au widget.
        let rafraichi = await b.rafraichissement.rafraichissements
        #expect(rafraichi == 0)
    }

    // MARK: Le capteur et la reprise

    @Test func leFluxDuCapteurEtSaReprise() async throws {
        let b = try banc(newYork)
        let modele = b.modele
        let capteur = b.capteur
        let p = try #require(modele.principale)
        let d = try #require(modele.declinaison)

        let ecoute = Task { await modele.suivreCapteur() }
        let abonne = await attendre { await capteur.abonnements == 1 }
        #expect(abonne)
        await capteur.envoyer(.precision(.basse))
        await capteur.envoyer(.cap(p - d))
        let recu = await attendre { modele.capLisse != nil && modele.montrerCalibrage }
        #expect(recu)
        #expect(modele.alignee)
        #expect(modele.alignements == 1)
        let capRecu = try #require(modele.cap)

        // L'écran s'en va : le flux se ferme, plus rien n'arrive.
        ecoute.cancel()
        await ecoute.value
        let recues = await capteur.envoyer(.cap(p + 90 - d))
        #expect(recues == 0)
        #expect(modele.cap == capRecu)

        // L'écran revient (onResume) : le cap lissé reste, l'avertissement repart caché, l'arrivée face à
        // Jérusalem se signale de nouveau.
        let reprise = Task { await modele.suivreCapteur() }
        let reabonne = await attendre { await capteur.abonnements == 2 }
        #expect(reabonne)
        #expect(!modele.montrerCalibrage)
        #expect(modele.cap == capRecu)
        #expect(modele.alignements == 2)
        await capteur.envoyer(.precision(.nonFiable))
        let calibrer = await attendre { modele.montrerCalibrage }
        #expect(calibrer)
        reprise.cancel()
        await reprise.value
    }

    @Test func enPartantLeWidgetSeRedessine() async throws {
        let b = try banc(newYork)
        await b.modele.suspendre()
        let rafraichi = await b.rafraichissement.rafraichissements
        #expect(rafraichi == 1)
        // Sans widget (un aperçu), rien ne se passe.
        let tableaux = try BoussoleTableaux(donnees: Self.tableaux.get(), langue: "fr")
        let sansWidget = BoussoleModele(magasin: b.magasin, contenus: Self.contenus, horloge: b.horloge,
                                        traducteur: b.traducteur, tableaux: tableaux, capteur: b.capteur,
                                        localisation: b.localisation, autorisationLieu: b.autorisation)
        await sansWidget.suspendre()
        let toujours = await b.rafraichissement.rafraichissements
        #expect(toujours == 1)
    }

    @Test func laRepriseReprendSansBruitLaPosition() async throws {
        let jerusalem = PositionApprochee(latitude: 31.76904, longitude: 35.21633)
        let b = try banc(paris, reponse: .position(jerusalem))
        let modele = b.modele
        try await modele.reprendre()
        let lieu = try #require(modele.lieu)
        #expect(lieu.nom == "Ma position · près de Jérusalem")
        // Gardée au kilomètre près (ChoixLieu.PositionSol, examen du 14/11).
        #expect(lieu.latitude == 31.77)
        #expect(lieu.longitude == 35.22)
        #expect(lieu.altitude == 0)
        // Le fuseau reste celui du téléphone ; Israël se lit sur le territoire, et ne fait que poser la question
        // (audit du 16/11 : le statut suit la résidence).
        #expect(lieu.fuseau == b.horloge.fuseau.identifiant)
        #expect(!b.magasin.reglages.inIsrael(fuseauTelephone: "Europe/Paris"))
        #expect(b.magasin.reglages.regionProposee == true)
        #expect(b.magasin.reglages.lieuVille == -1)
        #expect(b.magasin.reglages.lieuDepuis == b.horloge.maintenant)
        #expect(modele.message == nil)
        #expect(!modele.rechercheEnCours)
        let questions = await b.autorisation.questions
        #expect(questions == 1)
        let demandes = await b.localisation.demandes
        #expect(demandes == 1)
        let rafraichi = await b.rafraichissement.rafraichissements
        #expect(rafraichi == 1)
    }

    @Test func laRepriseNeTouchePasAUneVille() async throws {
        let newYorkVille = try await ville(idNewYork)
        let b = try banc(newYork, ville: newYorkVille, reponse: .position(PositionApprochee(latitude: 0, longitude: 0)))
        try await b.modele.reprendre()
        #expect(b.modele.lieu?.nom == "New York")
        let questions = await b.autorisation.questions
        #expect(questions == 0)
        let demandes = await b.localisation.demandes
        #expect(demandes == 0)
    }

    @Test func laRepriseNeDemandeRienSansAutorisation() async throws {
        let b = try banc(paris, reponse: .position(PositionApprochee(latitude: 0, longitude: 0)), permise: false)
        try await b.modele.reprendre()
        #expect(b.modele.lieu?.nom == "Paris")
        let demandes = await b.localisation.demandes
        #expect(demandes == 0)
    }

    @Test func laRepriseSansLieuOuSansPositionNeDitRien() async throws {
        let sansLieu = try banc(nil, reponse: .position(PositionApprochee(latitude: 0, longitude: 0)))
        try await sansLieu.modele.reprendre()
        #expect(sansLieu.modele.lieu == nil)
        let questions = await sansLieu.autorisation.questions
        #expect(questions == 0)

        let indisponible = try banc(paris, reponse: .indisponible)
        try await indisponible.modele.reprendre()
        #expect(indisponible.modele.lieu?.nom == "Paris")
        #expect(indisponible.modele.message == nil)
        let demandes = await indisponible.localisation.demandes
        #expect(demandes == 1)
    }

    // MARK: Le choix du lieu

    @Test func maPositionRefusee() async throws {
        let b = try banc(nil, reponse: .refusee)
        try await b.modele.utiliserMaPosition()
        #expect(b.modele.lieu == nil)
        #expect(b.modele.message == BoussoleMessage(libelle: Libelle("zmanim_position_refusee"), long: true))
        #expect(!b.modele.rechercheEnCours)
        b.modele.effacerMessage()
        #expect(b.modele.message == nil)
        // Aucune position en un temps raisonnable : le même Toast (ChoixLieu.echec).
        let indisponible = try banc(nil, reponse: .indisponible)
        await indisponible.modele.ouvrirChoixLieu()
        try await indisponible.modele.utiliserMaPosition()
        #expect(indisponible.modele.dialogue == nil)
        #expect(indisponible.modele.lieu == nil)
        #expect(indisponible.modele.message == BoussoleMessage(libelle: Libelle("zmanim_position_refusee"), long: true))
        let rafraichi = await indisponible.rafraichissement.rafraichissements
        #expect(rafraichi == 0)
    }

    @Test func fermerUnDialogueSansChoisir() async throws {
        let b = try banc(newYork)
        b.modele.ouvrirAffichage()
        #expect(b.modele.dialogue == .affichage)
        #expect(b.modele.dialogue?.titre == Libelle("boussole_affichage"))
        b.modele.fermerDialogue()
        #expect(b.modele.dialogue == nil)
        #expect(!b.magasin.reglages.boussoleRose)
        let ecritures = await b.rafraichissement.rafraichissements
        #expect(ecritures == 0)
    }

    @Test func maPositionAJerusalem() async throws {
        let b = try banc(nil, reponse: .position(PositionApprochee(latitude: 31.76904, longitude: 35.21633)))
        try await b.modele.utiliserMaPosition()
        let lieu = try #require(b.modele.lieu)
        #expect(lieu.nom == "Ma position · près de Jérusalem")
        #expect(b.modele.pastille == .nom("Ma position · près de Jérusalem"))
        #expect(b.magasin.reglages.inIsrael(fuseauTelephone: "America/New_York"))
        #expect(b.modele.message == nil)
        #expect(b.modele.etat == .attenteDuCap)
        #expect(b.modele.distanceKm == 2)
    }

    @Test func maPositionEnHebreu() async throws {
        let b = try banc(nil, langue: "he", reponse: .position(PositionApprochee(latitude: 48.85341, longitude: 2.3488)))
        try await b.modele.utiliserMaPosition()
        let parisVille = try await ville(2_988_507)
        let attendu = b.traducteur.texte(Libelle("zmanim_position_pres", .texte(parisVille.nom.he)))
        #expect(b.modele.lieu?.nom == attendu)
        #expect(!b.magasin.reglages.inIsrael(fuseauTelephone: "America/New_York"))
    }

    @Test func enPleineMerLaPositionSansVille() async throws {
        let b = try banc(nil, reponse: .position(PositionApprochee(latitude: 0, longitude: -30)))
        try await b.modele.utiliserMaPosition()
        let lieu = try #require(b.modele.lieu)
        #expect(lieu.nom == "Ma position")
        #expect(lieu.altitude == 0)
        #expect(!b.magasin.reglages.inIsrael(fuseauTelephone: "America/New_York"))
    }

    @Test func choisirUneVille() async throws {
        let b = try banc(nil)
        let modele = b.modele
        await modele.ouvrirChoixLieu()
        #expect(modele.dialogue == .choixLieu)
        #expect(modele.dialogue?.titre == Libelle("zmanim_choisir_lieu"))
        #expect(modele.maPosition == Libelle("zmanim_position"))
        #expect(modele.villesProposees.count == 51)
        #expect(modele.villesProposees.first == BoussoleVilleProposee(id: idJerusalem, nom: "Jérusalem"))
        // Une ville inconnue ne change rien.
        try await modele.choisirVille(id: 1)
        #expect(modele.lieu == nil)
        try await modele.choisirVille(id: idNewYork)
        #expect(modele.dialogue == nil)
        let lieu = try #require(modele.lieu)
        #expect(lieu.nom == "New York")
        #expect(lieu.fuseau == "America/New_York")
        #expect(b.magasin.reglages.lieuVille == idNewYork)
        #expect(!b.magasin.reglages.inIsrael(fuseauTelephone: "Asia/Jerusalem"))
        #expect(modele.etat == .attenteDuCap)
        let rafraichi = await b.rafraichissement.rafraichissements
        #expect(rafraichi == 1)
    }

    @Test func choisirUneVilleEnHebreu() async throws {
        let b = try banc(nil, langue: "he")
        await b.modele.ouvrirChoixLieu()
        #expect(b.modele.villesProposees.first?.nom == BoussoleScene.jerusalem)
        try await b.modele.choisirVille(id: idJerusalem)
        #expect(b.modele.lieu?.nom == BoussoleScene.jerusalem)
        #expect(b.magasin.reglages.inIsrael(fuseauTelephone: "America/New_York"))
    }

    // MARK: La note et les chaînes

    @Test func laSourceEtSonLien() throws {
        let b = try banc(newYork)
        let titre = try #require(CatalogueBrut.lire().valeur("boussole_source_titre", langue: "fr"))
        #expect(b.modele.source == Libelle("boussole_source", .texte("\u{2066}" + titre + "\u{2069}")))
        let ligne = b.traducteur.texte(b.modele.source)
        #expect(ligne == "Source\u{00A0}: \u{2066}" + titre + "\u{2069}")
        #expect(b.modele.lienSource?.absoluteString == BoussoleModele.adresseSource)
    }

    @Test func lesClesDeLEcranSontDansLesTroisLangues() throws {
        let catalogue = try CatalogueBrut.lire()
        let cles = [
            "boussole_title", "boussole_a_plat", "boussole_sans_capteur", "boussole_calibrer",
            "boussole_actualiser_position", "boussole_grand_cercle", "boussole_cap_constant", "boussole_distance",
            "boussole_legende", "boussole_legende_carte", "boussole_methode", "boussole_methode_reelle",
            "boussole_methode_carte", "boussole_affichage", "boussole_affichage_hassid", "boussole_affichage_rose",
            "boussole_note_titre", "boussole_note", "boussole_source", "boussole_source_titre",
            "boussole_vide_titre", "boussole_carte_sous", "boussole_vide_position", "boussole_vide_ville",
            "boussole_face", "boussole_droite", "boussole_gauche", "boussole_par_rapport_nord", "boussole_nord",
            "zmanim_choisir_lieu", "zmanim_source_villes", "zmanim_position", "zmanim_position_pres",
            "zmanim_position_attente", "zmanim_position_refusee",
        ]
        for cle in cles {
            for langue in Traducteur.langues {
                let presente = catalogue.valeur(cle, langue: langue) != nil
                #expect(presente, "\(cle) manque en \(langue)")
            }
        }
    }
}
