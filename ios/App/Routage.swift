import Coeur
import Ecrans
import Foundation

/// Ce qu'ouvre chaque route des écrans : les fermetures `ouvrir` que l'app passe aux vues. Une route devient un
/// écran poussé sur la pile de l'onglet qu'on voit (`Ecran`), une feuille ou un plein écran posé par la racine,
/// ou un autre onglet. Aucune route ne reste sans destination : un écran d'Android pas encore porté s'ouvre sur
/// « Bientôt » (`Ecran.bientot`).
extension PartageApp {

    /// L'accueil (MainActivity).
    func ouvrirAccueil(_ route: AccueilRoute) {
        switch route {
        case .seance(let demarrer):
            navigation.pousser(.seance(commencer: demarrer))
        case .paliers:
            navigation.pousser(.paliers)
        case .parcours:
            navigation.pousser(.parcours)
        case .musique:
            navigation.pousser(.musique)
        case .note(let jour):
            navigation.feuille = .note(jour)
        case .celebration(let minutes, let dateNote):
            let jour = dateNote.flatMap { JourCivil(iso: $0) }
            navigation.couverture = .celebration(CelebrationDemande(minutes: minutes, dateNote: jour))
        case .presentation:
            montrerPresentation()
        case .siddour(let id):
            navigation.pousser(.lecture(.siddour(id)))
        case .entreeBibliotheque(let id):
            navigation.pousser(.entreeBibliotheque(id))
        }
    }

    /// L'onglet Textes (le panneau des textes de MainActivity).
    func ouvrirTextes(_ route: TextesRoute) {
        switch route {
        case .recherche:
            navigation.pousser(.recherche)
        case .tikkun:
            navigation.pousser(.tikkun)
        case .siddour:
            navigation.pousser(.siddour)
        case .tehilim:
            navigation.pousser(.tehilim)
        case .tefilot:
            navigation.pousser(.tefilot)
        case .bibliotheque(let livresSeuls):
            navigation.pousser(.bibliotheque(livresSeuls: livresSeuls))
        case .chizuk:
            navigation.pousser(.chizuk)
        case .conseils:
            navigation.pousser(.conseils)
        case .relecture:
            // ProofreadActivity (debug) n'a ni modèle ni vue.
            navigation.pousser(.bientot(cle: "proofread_title"))
        case .musique:
            navigation.pousser(.musique)
        case .rappels:
            // RemindersActivity : sur iOS, les rappels se règlent dans l'onglet Réglages.
            navigation.onglet = .reglages
        case .lecture(let id, let livre):
            navigation.pousser(.lecture(LectureCible(id: id, livre: livre)))
        case .marquesPages(let recueil):
            navigation.feuille = .marquesPages(recueil: recueil)
        case .entreeBibliotheque(let id):
            navigation.pousser(.entreeBibliotheque(id))
        }
    }

    /// Le siddour, le lecteur et la feuille des marque-pages.
    func ouvrirLecture(_ route: LectureRoute) {
        switch route {
        case .lecture(let cible):
            navigation.pousser(.lecture(cible))
        case .tehilim:
            navigation.pousser(.tehilim)
        case .tikkun:
            navigation.pousser(.tikkun)
        case .tehilimMarque(let psaume, let verset):
            navigation.pousser(.tehilimMarque(psaume: psaume, verset: verset))
        case .marquesPages(let recueil):
            navigation.feuille = .marquesPages(recueil: recueil)
        }
    }

    /// Un résultat de la recherche globale.
    func ouvrirRecherche(_ route: RechercheRoute) {
        switch route {
        case .siddour(let id):
            navigation.pousser(.lecture(.siddour(id)))
        case .livre(let id):
            navigation.pousser(.lecture(.livre(id)))
        case .halakha(let recherche):
            navigation.pousser(.halakha(date: nil, recherche: recherche))
        case .hilloulot(let recherche):
            navigation.pousser(.hilloulot(date: nil, recherche: recherche))
        }
    }

    /// La bibliothèque : seuls `.livre` et `.marque` arrivent ici, `BibliothequeVue` poussant elle-même ses
    /// sous-pages ; une sous-page reçue quand même est confiée à sa destination, plus bas dans la pile.
    func ouvrirBibliotheque(_ route: BibliothequeRoute) {
        switch route {
        case .livre(let id):
            navigation.pousser(.lecture(.livre(id)))
        case .marque(let livre, let section, let bloc):
            let place = LecturePlace(section: section, bloc: bloc)
            navigation.pousser(.lecture(LectureCible(id: livre, livre: true, marque: place)))
        case .sousSection, .entree:
            navigation.pousserValeur(route, dans: navigation.onglet)
        }
    }

    /// Les Tfilot : une entrée de la bibliothèque.
    func ouvrirTefilot(_ route: TefilotRoute) {
        switch route {
        case .entree(let id):
            navigation.pousser(.entreeBibliotheque(id))
        }
    }

    /// Le 'hizouk : « Commencer une hitbodedout » (sans EXTRA_START_NOW, ChizukActivity).
    func ouvrirChizuk(_ route: ChizukRoute) {
        switch route {
        case .seance:
            navigation.pousser(.seance(commencer: false))
        }
    }

    /// Le journal : le bouton de l'écran vide (JournalActivity).
    func ouvrirJournal(_ route: JournalRoute) {
        switch route {
        case .seance:
            navigation.pousser(.seance(commencer: false))
        }
    }

    /// La séance : seul « Prier » arrive ici ; le bravo et la note sont présentés par `SeanceVue` elle-même.
    func ouvrirSeance(_ route: SeanceRoute) {
        switch route {
        case .tefilot:
            navigation.pousser(.tefilot)
        case .celebration, .note:
            break
        }
    }

    /// L'onglet Zmanim et le calendrier.
    func ouvrirZmanim(_ route: ZmanimRoute) {
        switch route {
        case .halakha(let jour):
            navigation.pousser(.halakha(date: jour, recherche: nil))
        case .hilloulot(let jour):
            navigation.pousser(.hilloulot(date: jour, recherche: nil))
        case .calendrier:
            navigation.pousser(.calendrier)
        case .vol:
            navigation.pousser(.vol)
        case .boussole:
            navigation.pousser(.boussole)
        case .siddour(let id):
            navigation.pousser(.lecture(.siddour(id)))
        case .ajouterTemps(let jour):
            // Nil pour un jour à venir : rien ne s'ouvre (AjoutTemps.possible).
            navigation.ajout = AjoutTempsModele(magasin: magasin, horloge: horloge, systeme: services.ajoutTemps,
                                                date: jour)
        }
    }

    /// Les réglages. Les Réglages d'iOS et le navigateur sont ouverts par `ReglagesVue` elle-même.
    func ouvrirReglages(_ route: ReglagesRoute) {
        switch route {
        case .reglagesApp, .reglagesNotifications, .navigateur:
            break
        case .presentation:
            montrerPresentation()
        case .apercuBarriere:
            // L'aperçu du bouclier (GateService.preview) : tâche 27.
            navigation.pousser(.bientot(cle: "action_preview_gate"))
        case .choixApplications:
            // FamilyActivityPicker (AppPickerActivity), après l'autorisation de Temps d'écran.
            navigation.pousser(.applications)
        case .dedicace:
            // La boîte de Dedicace.kt : une feuille, l'e-mail composé et ouvert dans la messagerie.
            navigation.feuille = .dedicace
        case .aideConcentration:
            // L'aide qui remplace « Ne pas déranger » (§ 2.2.6) : créer un mode de concentration dans les Réglages.
            navigation.pousser(.concentration)
        case .recommencer:
            recommencer()
        }
    }

    /// « Tout effacer » : l'app repart de zéro, présentation comprise (MainActivity, tâche vidée).
    func recommencer() {
        navigation.toutFermer()
        navigation.onglet = Onglet.initial(magasin.reglages)
        if PresentationModele.aMontrer(magasin.reglages) {
            montrerPresentation()
        }
        replanifier()
    }

    // MARK: Les notifications touchées

    /// Ce que fait une notification touchée (ReminderReceiver, Confettis, LevanaAlerte, VolAlerte, la fin de
    /// séance de SessionService).
    func recevoir(_ touchee: NotificationTouchee) async {
        switch touchee.geste {
        case .plusTard:
            await services.reporterRappel()
        case .commencer:
            // « Commencer » sous le rappel : l'écran de séance, la séance lancée ; le rappel retiré et replanifié
            // (EXTRA_DEPUIS_RAPPEL).
            navigation.feuille = nil
            navigation.onglet = .aujourdhui
            navigation.vider(.aujourdhui)
            navigation.pousser(.seance(commencer: true), dans: .aujourdhui)
            await services.accueil.retirerRappelDuJour()
            await services.rappels.replanifier()
        case .ouvrir:
            ouvrirNotification(touchee)
        }
    }

    private func ouvrirNotification(_ touchee: NotificationTouchee) {
        navigation.onglet = .aujourdhui
        if let id = touchee.texteSiddur ?? texteSiddurDuVol(touchee.identifiant) {
            // Birkat haLevana, Tefilat haDerekh…
            navigation.pousser(.lecture(.siddour(id)), dans: .aujourdhui)
        } else if touchee.identifiant == SeanceEnCours.identifiantFete {
            // « Mazal tov ! » (Confettis.kt) : les paliers.
            navigation.pousser(.paliers, dans: .aujourdhui)
        } else if touchee.identifiant.hasPrefix("fin-seance-") {
            // La fin de séance (EXTRA_ASK_NOTE) : la note du jour, sauf si le bravo attend.
            accueil.demanderNote(horloge.aujourdhui)
        }
    }

    /// Le texte du siddour d'un rappel du vol posé par l'écran du vol (`VolModele`, par `programmer`), qui ne
    /// porte pas le `userInfo` du plan : l'identifiant « vol-<rang>-<type>-<instant> » ne dit pas la prière, le
    /// rappel est relu dans les réglages (VolAlerteReceiver ; VolNotifications.texteSiddur).
    private func texteSiddurDuVol(_ identifiant: String) -> String? {
        guard identifiant.hasPrefix(VolNotifications.prefixe) else { return nil }
        let rappel = VolStockage.rappels(magasin.reglages).first { r in
            identifiant.hasSuffix("-" + r.type.rawValue + "-" + String(r.instant))
        }
        return rappel.map { VolNotifications.texteSiddur($0) }
    }
}
