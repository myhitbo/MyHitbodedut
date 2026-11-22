import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le panneau des textes (MainActivity.kt, `texts_scroll` d'activity_main.xml, RepriseFavoris.kt) : les mêmes
/// entrées, dans le même ordre, avec leurs états ; la reprise, les favoris et les marque-pages ; la source du jour
/// (SourceDuJour.carte) ; l'interrupteur de la musique. Les contenus sont ceux du dépôt (ios/Ressources/Contenu).
///
/// Restent au test d'interface : la mise en page (cartes, marges, police hébraïque, « › »), le toucher de chaque
/// ligne vers son écran, et l'interrupteur posé dans la ligne de la musique sans ouvrir son écran.
@Suite("Modèle de l'onglet Textes")
@MainActor
struct TextesModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)
    private static let catalogue: Result<Data, any Error> = Result { try Fichiers.catalogue() }

    private func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    /// Un modèle sur un magasin en mémoire, l'horloge arrêtée à `heure` du jour `iso` (UTC).
    private func fabriquer(_ reglages: Reglages = Reglages(), iso: String = "2026-11-16", heure: Int = 12,
                           contenus: ContenusApp? = nil, relecture: Bool = false,
                           signal: any TextesSignalMusique = TextesSignalMusiqueMuet())
        throws -> (TextesModele, Magasin, PersistanceEnMemoire) {
        let date = try jour(iso)
        let persistance = PersistanceEnMemoire(Enregistrement(reglages: reglages))
        let magasin = Magasin(persistance: persistance, enregistrement: Enregistrement(reglages: reglages))
        let horloge = HorlogeFixe(DateHeure(date, heure: heure), fuseau: .utc)
        let modele = TextesModele(magasin: magasin, contenus: contenus ?? Self.contenus, horloge: horloge,
                                  langue: "fr", signalMusique: signal, relecture: relecture)
        return (modele, magasin, persistance)
    }

    /// Le titre hébreu d'un texte du siddour (edot) ou de l'index des livres, masqué pour la police.
    private func titreHebreu(_ id: String, livre: Bool, police: PoliceHebraique.Police = .serif) async throws -> String {
        let recueil: Siddur
        if livre {
            recueil = try await Self.contenus.livres()
        } else {
            recueil = try await Self.contenus.siddur(.edot)
        }
        let texte = try #require(recueil.texte(id))
        return PoliceHebraique.masque(texte.titre.he, police: police)
    }

    // MARK: Les entrées, dans l'ordre d'Android

    @Test func lesEntreesSontCellesDuLayoutDansLeMemeOrdre() throws {
        let (modele, _, _) = try fabriquer()
        let ids = modele.entrees.map { $0.id }
        #expect(ids == ["tikkun_button", "siddur_button", "tehilim_button", "tefilot_button", "livres_button",
                        "library_button", "chizuk_button", "tips_button"])
        let titres = modele.entrees.map { $0.titre.cle }
        #expect(titres == ["tikkun_title", "siddur_title", "tehilim_title", "tefilot_title", "livres_title",
                           "library_title", "chizuk_demande_title", "tips_title"])
        let routes = modele.entrees.map { $0.route }
        let attendues: [TextesRoute] = [.tikkun, .siddour, .tehilim, .tefilot, .bibliotheque(livresSeuls: true),
                                        .bibliotheque(livresSeuls: false), .chizuk, .conseils]
        #expect(routes == attendues)
        // Les indications fixes du layout (SectionState avec android:text).
        let indications = modele.entrees.map { $0.etat?.cle }
        #expect(indications[1] == "siddur_hint")
        #expect(indications[3] == "tefilot_hint")
        #expect(indications[4] == "livres_hint")
        #expect(indications[5] == "library_hint")
        #expect(indications[6] == "chizuk_demande_hint")
        #expect(indications[7] == "tips_hint")
        // Seule la musique a un interrupteur.
        let interrupteurs = modele.entrees.compactMap { $0.interrupteur }
        #expect(interrupteurs.isEmpty)
    }

    @Test func lesTroisRayonsSontCeuxDuLayoutDansLeMemeOrdre() async throws {
        let (modele, _, _) = try fabriquer()
        await modele.actualiser()
        let rayons = modele.rayons
        let titres = rayons.map { $0.titre.cle }
        #expect(titres == ["rayon_prier", "rayon_etudier", "rayon_renforcer"])
        let ids = rayons.flatMap { $0.couvertures.map(\.id) }
        // Les couvertures dans l'ordre d'activity_main.xml (refonte du 13/11), lu en place.
        let octets = try Fichiers.donnees("android/app/src/main/res/layout/activity_main.xml")
        let layout = String(decoding: octets, as: UTF8.self)
        let livres = try #require(layout.range(of: "android:id=\"@+id/texts_scroll\""))
        let chemin = try #require(layout.range(of: "android:id=\"@+id/chemin_scroll\""))
        let panneau = String(layout[livres.upperBound..<chemin.lowerBound])
        let couvertures = ExpressionReguliere(#"android:id="@\+id/([a-z_]+)"\s+style="@style/Couverture""#)
            .toutes(panneau).map { $0.groupes[1] }
        #expect(ids == couvertures)
        #expect(ids == ["siddur_button", "tehilim_button", "tikkun_button", "tefilot_button", "library_button",
                        "livres_button", "halakha_button", "chizuk_button", "tips_button"])
        // Chaque couverture porte la couleur de son drawable (android:background="@drawable/couv_…").
        let fonds = ExpressionReguliere(#"style="@style/Couverture"\s+(?:android:layout_marginEnd="0dp"\s+)?android:background="@drawable/couv_([a-z]+)""#)
            .toutes(panneau).map { $0.groupes[1] }
        let couleurs = rayons.flatMap { $0.couvertures.map(\.couleur.rawValue) }
        #expect(couleurs == fonds)
        let routes = rayons.flatMap { $0.couvertures.map(\.route) }
        let attendues: [TextesRoute] = [.siddour, .tehilim, .tikkun, .tefilot, .bibliotheque(livresSeuls: false),
                                        .bibliotheque(livresSeuls: true), .halakha, .chizuk, .conseils]
        #expect(routes == attendues)
        // Quatre places au plus par rayon ; l'état du Tikoun et des Tehilim sous le premier.
        let pleins = rayons.allSatisfy { $0.couvertures.count <= TextesRayon.places }
        #expect(pleins)
        let etats = rayons[0].etats.map(\.cle)
        #expect(etats == ["tikkun_progress_none", "tehilim_today"])
        let autres = rayons[1].etats.count + rayons[2].etats.count
        #expect(autres == 0)
        // Les couvertures claires portent l'encre sombre.
        let claires = TextesCouleur.allCases.filter(\.claire)
        #expect(claires == [.clair, .parchemin, .menthe])
    }

    @Test func laRelectureSousLesRayonsEnDebugSeulement() throws {
        let (publie, _, _) = try fabriquer()
        #expect(publie.ligneRelecture == nil)
        let (debug, _, _) = try fabriquer(relecture: true)
        let route = debug.ligneRelecture?.route
        #expect(route == .relecture)
    }

    @Test func autourDeLaHitbodedoutLaMusiquePuisLesRappels() throws {
        let (modele, _, _) = try fabriquer()
        #expect(modele.titreAutour == Libelle("section_around"))
        let ids = modele.autour.map { $0.id }
        #expect(ids == ["music_button", "reminders_button"])
        let routes = modele.autour.map { $0.route }
        let attendues: [TextesRoute] = [.musique, .rappels]
        #expect(routes == attendues)
        let interrupteur = modele.autour.first?.interrupteur
        #expect(interrupteur == true)
        let rappels = modele.autour.last?.interrupteur
        #expect(rappels == nil)
    }

    @Test func lEnTeteEtLaRecherche() throws {
        let (modele, _, _) = try fabriquer()
        #expect(modele.titre == Libelle("nav_texts"))
        #expect(modele.recherche == Libelle("recherche_indice"))
        #expect(modele.routeRecherche == .recherche)
    }

    @Test func laRelectureNExisteQuEnDebug() throws {
        let (publiee, _, _) = try fabriquer()
        let ids = publiee.entrees.map { $0.id }
        #expect(!ids.contains("proofread_button"))
        let (debug, _, _) = try fabriquer(relecture: true)
        let derniere = try #require(debug.entrees.last)
        #expect(derniere.id == "proofread_button")
        #expect(derniere.titre == Libelle("proofread_open"))
        #expect(derniere.etat == nil)
        #expect(derniere.route == .relecture)
        #expect(debug.entrees.count == 9)
    }

    // MARK: Reprendre, favoris, marque-pages

    @Test func avantActualiserRienNeSAttendAuxContenus() throws {
        var reglages = Reglages()
        Store.setPositionLecture(reglages: &reglages, cle: "s:chaharit", position: 12, maintenant: 0)
        let (modele, _, _) = try fabriquer(reglages)
        #expect(modele.etat == .chargement)
        #expect(modele.reprise.isEmpty)
        #expect(modele.etatTikkun == nil)
        #expect(modele.sourceDuJour == nil)
        // Les lignes elles-mêmes sont là d'emblée.
        #expect(modele.entrees.count == 8)
    }

    @Test func sansLectureNiFavoriNiMarqueRienEnTete() async throws {
        let (modele, _, _) = try fabriquer()
        await modele.actualiser()
        #expect(modele.etat == .pret)
        #expect(modele.reprise.isEmpty)
    }

    @Test func reprendreLeDernierTexteLu() async throws {
        var reglages = Reglages()
        Store.setPositionLecture(reglages: &reglages, cle: "s:chaharit", position: 12, maintenant: 0)
        let (modele, _, _) = try fabriquer(reglages)
        await modele.actualiser()
        let lignes = modele.reprise
        #expect(lignes.count == 1)
        let ligne = try #require(lignes.first)
        #expect(ligne.genre == .reprise)
        #expect(ligne.entete == Libelle("reprise_titre"))
        let attendu = try await titreHebreu("chaharit", livre: false)
        #expect(ligne.titre == .hebreu(attendu))
        #expect(ligne.route == .lecture(id: "chaharit", livre: false))
        #expect(ligne.nombre == nil)
        #expect(ligne.icone == nil)
    }

    @Test func lesFavorisSuiventLaRepriseEtLePremierSeulPorteLEnTete() async throws {
        var reglages = Reglages()
        Store.setPositionLecture(reglages: &reglages, cle: "s:chaharit", position: 3, maintenant: 0)
        Store.basculerFavori(reglages: &reglages, cle: "l:likoutei_etsot")
        Store.basculerFavori(reglages: &reglages, cle: "s:minha")
        Store.basculerFavori(reglages: &reglages, cle: "s:inconnu")
        // Le plus récent en tête : inconnu (passé sous silence), minha, likoutei_etsot. L'en-tête va au premier
        // favori qui existe (minha), pas au premier de la liste (le `forEachIndexed` après `mapNotNull`).
        let (modele, _, _) = try fabriquer(reglages)
        await modele.actualiser()
        let lignes = modele.reprise
        let genres = lignes.map { $0.genre }
        #expect(genres == [.reprise, .favori, .favori])
        let entetes = lignes.map { $0.entete }
        #expect(entetes == [Libelle("reprise_titre"), Libelle("favoris_titre"), nil])
        let routes = lignes.map { $0.route }
        let attendues: [TextesRoute] = [.lecture(id: "chaharit", livre: false), .lecture(id: "minha", livre: false),
                                        .lecture(id: "likoutei_etsot", livre: true)]
        #expect(routes == attendues)
        let minha = try await titreHebreu("minha", livre: false)
        let etsot = try await titreHebreu("likoutei_etsot", livre: true)
        #expect(lignes[1].titre == .hebreu(minha))
        #expect(lignes[2].titre == .hebreu(etsot))
        let ids = Set(lignes.map { $0.id })
        #expect(ids.count == 3)
    }

    @Test func unTexteQuiNExistePlusEstPasseSousSilence() async throws {
        var reglages = Reglages()
        Store.setPositionLecture(reglages: &reglages, cle: "s:inconnu", position: 3, maintenant: 0)
        Store.basculerFavori(reglages: &reglages, cle: "l:inconnu")
        let (modele, _, _) = try fabriquer(reglages)
        await modele.actualiser()
        #expect(modele.reprise.isEmpty)
    }

    @Test func laLigneDesMarquePagesLesCompteTous() async throws {
        var reglages = Reglages()
        let marques = [
            MarquesPages.Marque(cle: "s:chaharit", nusah: "edot", section: 1, bloc: 2, apercu: "ברוך"),
            MarquesPages.Marque(cle: "l:likoutei_etsot", nusah: "", section: 3, bloc: 4, apercu: "אמת"),
            MarquesPages.Marque(cle: TextesModele.cleTehilim, nusah: "", section: 23, bloc: 1, apercu: "מזמור"),
            MarquesPages.Marque(cle: "s:inconnu", nusah: "edot", section: 0, bloc: 0, apercu: "x"),
        ]
        for m in marques {
            Store.basculerMarque(reglages: &reglages, m)
        }
        Store.basculerFavori(reglages: &reglages, cle: "s:arvit")
        let (modele, _, _) = try fabriquer(reglages)
        await modele.actualiser()
        let lignes = modele.reprise
        #expect(lignes.count == 2)
        let signets = try #require(lignes.last)
        #expect(signets.genre == .signets)
        #expect(signets.entete == nil)
        #expect(signets.titre == .libelle(Libelle("marques_titre")))
        // Le texte inconnu n'est pas compté.
        #expect(signets.nombre == 3)
        #expect(signets.icone == "ic_marque_priere")
        #expect(signets.route == .marquesPages(recueil: nil))
    }

    @Test func lesTehilimSeNommentEtOuvrentLeurLivre() async throws {
        var reglages = Reglages()
        Store.basculerFavori(reglages: &reglages, cle: TextesModele.cleTehilim)
        let (modele, _, _) = try fabriquer(reglages)
        await modele.actualiser()
        let ligne = try #require(modele.reprise.first)
        #expect(ligne.titre == .libelle(Libelle("tehilim_title")))
        #expect(ligne.route == .tehilim)
    }

    /// Les contenus du dépôt, dont le titre hébreu de chaharit (siddour edot) commence par un ta'am (U+0591) :
    /// aucun titre livré n'a de signe qu'une police masque, il en faut un pour voir le masque à l'œuvre.
    private func contenusAvecTaam() -> ContenusApp {
        let base = ContenusApp.lecteur(dossier: Fichiers.contenu)
        return ContenusApp(lecteur: { chemin in
            guard var donnees = try base(chemin) else { return nil }
            if chemin == Nusah.edot.fichier {
                let repere = Data("\"id\":\"chaharit\",\"groupe\":\"jour\",\"titre\":{\"he\":\"".utf8)
                if let place = donnees.range(of: repere) {
                    donnees.insert(contentsOf: Data("\u{0591}".utf8), at: place.upperBound)
                }
            }
            return donnees
        })
    }

    @Test func laPoliceChoisieMasqueLesTitres() async throws {
        let avecTaam = contenusAvecTaam()
        let edot = try await avecTaam.siddur(.edot)
        let chaharit = try #require(edot.texte("chaharit"))
        let brut = chaharit.titre.he
        let premier = brut.utf16.first
        #expect(premier == 0x0591)
        var reglages = Reglages()
        reglages.setLecturePolice("frank")
        Store.setPositionLecture(reglages: &reglages, cle: "s:chaharit", position: 3, maintenant: 0)
        let (modele, _, _) = try fabriquer(reglages, contenus: avecTaam)
        await modele.actualiser()
        #expect(modele.police == .frank)
        let ligne = try #require(modele.reprise.first)
        let masque = PoliceHebraique.masque(brut, police: .frank)
        // Frank Ruhl n'a pas les טעמים : le signe devient U+034F.
        #expect(!masque.egalUnites(brut))
        #expect(ligne.titre == .hebreu(masque))
        // La police par défaut (serif) les a : le titre reste tel quel.
        var serif = Reglages()
        Store.setPositionLecture(reglages: &serif, cle: "s:chaharit", position: 3, maintenant: 0)
        let (parDefaut, _, _) = try fabriquer(serif, contenus: avecTaam)
        await parDefaut.actualiser()
        let ligneSerif = try #require(parDefaut.reprise.first)
        #expect(ligneSerif.titre == .hebreu(brut))
    }

    @Test func leSiddourEstCeluiDuNusahChoisi() async throws {
        // « hachkavot » n'a pas le même titre dans les deux nusah : la ligne dit lequel a été lu.
        var reglages = Reglages()
        reglages.setSiddurNusah(.ashkenaz)
        Store.setPositionLecture(reglages: &reglages, cle: "s:hachkavot", position: 3, maintenant: 0)
        let (modele, _, _) = try fabriquer(reglages)
        await modele.actualiser()
        let ligne = try #require(modele.reprise.first)
        let ashkenaz = try await Self.contenus.siddur(.ashkenaz)
        let texte = try #require(ashkenaz.texte("hachkavot"))
        let edot = try await titreHebreu("hachkavot", livre: false)
        #expect(!edot.egalUnites(texte.titre.he))
        #expect(ligne.titre == .hebreu(PoliceHebraique.masque(texte.titre.he, police: .serif)))
    }

    @Test func unRecueilIlisibleTaitTouteLaListe() async throws {
        let base = ContenusApp.lecteur(dossier: Fichiers.contenu)
        let sansLivres = ContenusApp(lecteur: { chemin in
            if chemin == Livres.titres { return nil }
            return try base(chemin)
        })
        // Une clé de livre demande l'index illisible : toute la liste se tait (le runCatching de MainActivity).
        var reglages = Reglages()
        Store.setPositionLecture(reglages: &reglages, cle: "s:chaharit", position: 3, maintenant: 0)
        Store.basculerFavori(reglages: &reglages, cle: "l:likoutei_etsot")
        let (modele, _, _) = try fabriquer(reglages, contenus: sansLivres)
        await modele.actualiser()
        #expect(modele.reprise.isEmpty)
        // Sans clé de livre, l'index n'est pas demandé : la reprise reste.
        var siddourSeul = Reglages()
        Store.setPositionLecture(reglages: &siddourSeul, cle: "s:chaharit", position: 3, maintenant: 0)
        let (autre, _, _) = try fabriquer(siddourSeul, contenus: sansLivres)
        await autre.actualiser()
        #expect(autre.reprise.count == 1)
    }

    @Test func sansAucunContenuLePanneauResteEntier() async throws {
        let vide = ContenusApp(lecteur: { _ in nil })
        var reglages = Reglages()
        Store.setPositionLecture(reglages: &reglages, cle: "s:chaharit", position: 3, maintenant: 0)
        let (modele, _, _) = try fabriquer(reglages, contenus: vide)
        await modele.actualiser()
        #expect(modele.etat == .pret)
        #expect(modele.reprise.isEmpty)
        #expect(modele.etatTikkun == nil)
        #expect(modele.sourceDuJour == nil)
        #expect(modele.entrees.count == 8)
        #expect(modele.autour.count == 2)
    }

    // MARK: Le Tikoun

    @Test func leTikounDitCeQuiResteAujourdhui() async throws {
        let tikkun = try await Self.contenus.tikkun()
        let date = try jour("2026-11-16")
        let midi = DateHeure(date, heure: 12)

        let (rien, _, _) = try fabriquer()
        await rien.actualiser()
        #expect(rien.etatTikkun == Libelle("tikkun_progress_none", .entier(10), .entier(tikkun.versets)))

        var trois = Reglages()
        for numero in [16, 32, 41] {
            Store.setTikkunDone(reglages: &trois, numero: numero, done: true, maintenant: midi)
        }
        let (enCours, _, _) = try fabriquer(trois)
        await enCours.actualiser()
        #expect(enCours.etatTikkun == Libelle("tikkun_progress", .entier(3), .entier(10)))

        var tous = Reglages()
        for numero in Tikkun.ordre {
            Store.setTikkunDone(reglages: &tous, numero: numero, done: true, maintenant: midi)
        }
        let (fini, _, _) = try fabriquer(tous)
        await fini.actualiser()
        #expect(fini.etatTikkun == Libelle("tikkun_progress_all"))
    }

    @Test func leJourDuTikounBasculeAQuatreHeures() async throws {
        var reglages = Reglages()
        let veille = try jour("2026-11-16")
        let soir = DateHeure(veille, heure: 23)
        Store.setTikkunDone(reglages: &reglages, numero: 16, done: true, maintenant: soir)
        // Après minuit, avant 4 h : encore le même jour du Tikoun.
        let (nuit, _, _) = try fabriquer(reglages, iso: "2026-11-17", heure: 2)
        await nuit.actualiser()
        #expect(nuit.etatTikkun == Libelle("tikkun_progress", .entier(1), .entier(10)))
        // Passé 4 h : un jour neuf, rien de dit.
        let (matin, _, _) = try fabriquer(reglages, iso: "2026-11-17", heure: 5)
        await matin.actualiser()
        let etat = try #require(matin.etatTikkun)
        #expect(etat.cle == "tikkun_progress_none")
    }

    // MARK: Les Tehilim

    /// Le premier jour, à partir du 16/11/2026, dont le jour du mois hébraïque vérifie `condition`.
    private func premierJour(_ condition: (Int, Int) -> Bool) throws -> JourCivil {
        var date = try jour("2026-11-16")
        for _ in 0..<800 {
            let (j, longueur) = CycleTehilim.jourHebreu(date)
            if condition(j, longueur) { return date }
            date = date.plus(jours: 1)
        }
        Issue.record("aucun jour trouvé")
        return date
    }

    @Test func laPortionDuJourSuitLeMoisHebraique() throws {
        let (modele, _, _) = try fabriquer()
        let date = try jour("2026-11-16")
        let (j, longueur) = CycleTehilim.jourHebreu(date)
        let attendu = Libelle("tehilim_today", .libelle(TextesModele.portion(CycleTehilim.duMois(j, longueur), langue: "fr")))
        #expect(modele.etatTehilim == attendu)
    }

    @Test func leVingtCinqLesVersetsDuPsaumeCentDixNeuf() throws {
        let date = try premierJour { j, _ in j == 25 }
        let (modele, _, _) = try fabriquer(iso: date.iso)
        let attendu = Libelle("tehilim_today",
                              .libelle(Libelle("tehilim_range_verses", .texte("119"), .texte("1"), .texte("96"))))
        #expect(modele.etatTehilim == attendu)
        let traducteur = try Traducteur(catalogue: Self.catalogue.get(), langue: "fr")
        let texte = traducteur.texte(modele.etatTehilim)
        #expect(texte == "Aujourd\u{2019}hui\u{A0}: Tehilim 119, versets 1 à 96")
    }

    @Test func enHebreuLesNumerosSontEnLettres() throws {
        let date = try premierJour { j, _ in j == 1 }
        let persistance = PersistanceEnMemoire()
        let modele = TextesModele(magasin: Magasin(persistance: persistance), contenus: Self.contenus,
                                  horloge: HorlogeFixe(DateHeure(date, heure: 12), fuseau: .utc), langue: "he")
        let attendu = Libelle("tehilim_today", .libelle(Libelle("tehilim_range", .texte(Reference.lettres(1)),
                                                                  .texte(Reference.lettres(9)))))
        #expect(modele.etatTehilim == attendu)
    }

    @Test func unMoisDeVingtNeufJoursFinitLeLivreLeVingtNeuf() throws {
        let date = try premierJour { j, longueur in j == 29 && longueur == 29 }
        let (modele, _, _) = try fabriquer(iso: date.iso)
        let attendu = Libelle("tehilim_today", .libelle(Libelle("tehilim_range", .texte("140"), .texte("150"))))
        #expect(modele.etatTehilim == attendu)
    }

    // MARK: La musique

    @Test func laMusiqueDitLeMorceauChoisiEtLeVolume() throws {
        let premier = try #require(MusiquePlay.morceaux.first)
        let (modele, _, _) = try fabriquer()
        #expect(modele.musiqueActive)
        #expect(modele.etatMusique == Libelle("music_on_summary", .libelle(Libelle(premier.titleRes)),
                                              .entier(Reglages.defaultVolume)))
        // Un morceau renommé se dit par son nom.
        var reglages = Reglages()
        reglages.setMusicNames("{\"\(premier.id)\":\"Mon nigoun\"}")
        reglages.setMusicVolume(40)
        let (renomme, _, _) = try fabriquer(reglages)
        #expect(renomme.etatMusique == Libelle("music_on_summary", .texte("Mon nigoun"), .entier(40)))
    }

    @Test func laMusiqueAleatoireOuEteinte() throws {
        var reglages = Reglages()
        reglages.setMusicShuffle(true)
        reglages.setMusicVolume(55)
        let (aleatoire, _, _) = try fabriquer(reglages)
        #expect(aleatoire.etatMusique == Libelle("music_shuffle_summary", .entier(55)))
        // Éteinte l'emporte sur tout le reste.
        reglages.setMusicEnabled(false)
        let (eteinte, _, _) = try fabriquer(reglages)
        #expect(eteinte.etatMusique == Libelle("music_off_summary"))
        #expect(!eteinte.musiqueActive)
        let interrupteur = eteinte.autour.first?.interrupteur
        #expect(interrupteur == false)
    }

    @Test func lInterrupteurEcritLeReglageEtPrevientLaSeance() async throws {
        let signal = TextesSignalMusiqueFaux()
        let (modele, magasin, persistance) = try fabriquer(signal: signal)
        try await modele.basculerMusique(false)
        #expect(!magasin.reglages.musicEnabled)
        #expect(modele.etatMusique == Libelle("music_off_summary"))
        let ecrit = await persistance.enregistrement.reglages.musicEnabled
        #expect(!ecrit)
        let signaux = await signal.signaux
        #expect(signaux == 1)
        // La même position ne fait rien.
        try await modele.basculerMusique(false)
        let ecritures = await persistance.ecrituresReglages
        #expect(ecritures == 1)
        let encore = await signal.signaux
        #expect(encore == 1)
    }

    @Test func uneEcritureRefuseeSeRendEtLaSeanceEstPrevenue() async throws {
        let signal = TextesSignalMusiqueFaux()
        let (modele, magasin, persistance) = try fabriquer(signal: signal)
        await persistance.faireEchouer(true)
        var refuse = false
        do {
            try await modele.basculerMusique(false)
        } catch is PersistanceEnMemoire.Echec {
            refuse = true
        } catch {
            Issue.record("erreur inattendue : \(error)")
        }
        #expect(refuse)
        // Le changement reste en mémoire, comme le Magasin le veut.
        #expect(!magasin.reglages.musicEnabled)
        let signaux = await signal.signaux
        #expect(signaux == 1)
    }

    // MARK: Les rappels

    @Test func lesRappelsEteintsSansHeureOuComptes() throws {
        let (eteints, _, _) = try fabriquer()
        #expect(eteints.etatRappels == Libelle("reminders_off"))

        var reglages = Reglages()
        reglages.setReminderEnabled(true)
        let (unSeul, _, _) = try fabriquer(reglages)
        // Sans liste écrite, l'heure unique d'avant : une heure.
        #expect(unSeul.etatRappels == Libelle.pluriel("reminders_count", quantite: 1, .entier(1)))

        reglages.setReminderTimes([480, 1260])
        let (deux, _, _) = try fabriquer(reglages)
        #expect(deux.etatRappels == Libelle.pluriel("reminders_count", quantite: 2, .entier(2)))

        reglages.setReminderTimes([])
        let (aucune, _, _) = try fabriquer(reglages)
        #expect(aucune.etatRappels == Libelle("reminders_none"))
    }

    // MARK: La source du jour

    @Test func laSourceDuJourEstCelleDeSourceDuJour() async throws {
        let bibliotheque = try await Self.contenus.bibliotheque()
        let date = try jour("2026-11-16")
        let pensee = try #require(SourceDuJour.choix(bibliotheque, date))
        let (modele, _, _) = try fabriquer()
        await modele.actualiser()
        let carte = try #require(modele.sourceDuJour)
        #expect(carte.id == pensee.source.id)
        #expect(carte.entete == Libelle("source_du_jour"))
        #expect(carte.bouton == Libelle("source_du_jour_lire"))
        #expect(carte.extrait == PoliceHebraique.masque(SourceDuJour.extrait(pensee.texte), police: .serif))
        #expect(carte.reference == Reference.localise(pensee.source.ref, "fr"))
        #expect(carte.route == .entreeBibliotheque(id: pensee.source.id))
        let choisie = TextesSourceDuJour.choisir(bibliotheque, jour: date, langue: "fr", police: .serif)
        #expect(choisie == carte)
    }

    @Test func laMemeSourceToutLaJourneePuisUneAutre() async throws {
        let bibliotheque = try await Self.contenus.bibliotheque()
        let (matin, _, _) = try fabriquer(heure: 0)
        await matin.actualiser()
        let (soir, _, _) = try fabriquer(heure: 23)
        await soir.actualiser()
        #expect(matin.sourceDuJour == soir.sourceDuJour)
        let (lendemain, _, _) = try fabriquer(iso: "2026-11-17", heure: 0)
        await lendemain.actualiser()
        let suivant = try jour("2026-11-17")
        let attendue = TextesSourceDuJour.choisir(bibliotheque, jour: suivant, langue: "fr", police: .serif)
        #expect(lendemain.sourceDuJour == attendue)
    }

    // MARK: Les chaînes

    @Test func chaqueLibelleSeResoutDansLesTroisLangues() async throws {
        var reglages = Reglages()
        Store.setPositionLecture(reglages: &reglages, cle: "s:chaharit", position: 3, maintenant: 0)
        Store.basculerFavori(reglages: &reglages, cle: "s:minha")
        Store.basculerFavori(reglages: &reglages, cle: TextesModele.cleTehilim)
        Store.basculerMarque(reglages: &reglages, MarquesPages.Marque(cle: "s:chaharit", nusah: "edot", section: 1,
                                                                      bloc: 1, apercu: "x"))
        reglages.setReminderEnabled(true)
        let (modele, _, _) = try fabriquer(reglages, relecture: true)
        await modele.actualiser()
        var libelles: [Libelle] = [modele.titre, modele.recherche, modele.titreAutour]
        for entree in modele.entrees + modele.autour {
            libelles.append(entree.titre)
            if let etat = entree.etat { libelles.append(etat) }
        }
        for ligne in modele.reprise {
            if let entete = ligne.entete { libelles.append(entete) }
            if case .libelle(let libelle) = ligne.titre { libelles.append(libelle) }
        }
        let carte = try #require(modele.sourceDuJour)
        libelles.append(carte.entete)
        libelles.append(carte.bouton)
        // Les autres états des lignes.
        libelles += [
            Libelle("tikkun_progress", .entier(3), .entier(10)), Libelle("tikkun_progress_all"),
            Libelle("music_off_summary"), Libelle("music_none_summary"), Libelle("music_shuffle_summary", .entier(70)),
            Libelle("reminders_off"), Libelle("reminders_none"),
            Libelle.pluriel("reminders_count", quantite: 2, .entier(2)),
            Libelle("tehilim_today", .libelle(TextesModele.portion(Portion(119, 119, 1, 96), langue: "fr"))),
            Libelle("tehilim_today", .libelle(TextesModele.portion(Portion(25, 25), langue: "fr"))),
        ]
        #expect(libelles.count > 30)
        for langue in Traducteur.langues {
            let traducteur = try Traducteur(catalogue: Self.catalogue.get(), langue: langue)
            for libelle in libelles {
                let texte = traducteur.texte(libelle)
                #expect(texte != libelle.cle, "\(langue) : \(libelle)")
            }
        }
    }
}
