import Barriere
import Coeur
import Ecrans
import Foundation
import Observation

/// La barrière « Je suis avec Hachem » côté app (PORTAGE.md § 2.1, § 3.2) : ce que GateService et Store faisaient
/// sur Android, partagé ici avec les trois extensions de Temps d'écran par le groupe d'apps (`barriere/`).
///
/// - À chaque changement du journal ou des réglages (suivis par l'observation du `Magasin`, regroupés en une
///   écriture), et au retour au premier plan (`actualiser`), l'app écrit l'instantané `etat.json`
///   (`EtatBarriere.etat` de Coeur : fenêtre, report, deux ans de jours chômés, journée validée, séance en cours,
///   textes du bouclier déjà traduits), le décor du bouclier (`bouclier.json` : couleurs de la palette, essai en
///   cours) et les deux poses du hassid du jour ; puis elle pose les jetons de la sélection sur les magasins
///   nommés, les active ou les désactive selon la règle des extensions (`PilotageBarriere.consigne`), et
///   (re)planifie les rendez-vous de la surveillance (`DeviceActivityCenter`, SystemeBarriereMagasins).
/// - Au retour au premier plan, elle relève la boîte des extensions : les « Je l'ai déjà faite » vont au journal
///   (`Store.addSession(…, 0)`), les « Plus tard » aux réglages (`Store.snooze`), un « Commencer » récent attend
///   que l'app ouvre la séance (`demandeDeCommencer`) ; tout part dans l'historique (les cinquante derniers
///   événements, `historique.jsonl`), puis la boîte est vidée.
/// - L'essai réel de l'écran d'aperçu (`BouclierEssai`) : le magasin `essai`, deux minutes.
///
/// Un seul écrivain par fichier (§ 3.2) : l'app écrit etat.json, bouclier.json, les poses et l'historique ; les
/// extensions n'ajoutent qu'à la boîte.
///
/// Rien ne fait semblant : sans le groupe d'apps accordé à la signature, aucun fichier ne s'écrit ; sans
/// l'entitlement Family Controls accordé par Apple, les magasins ne retiennent rien et la surveillance ne s'inscrit
/// pas, ce que la carte d'état des réglages dit (`constat`). La construction SANS_BARRIERE n'écrit rien.
@MainActor
final class SystemeBarriere: BouclierEssai {

    /// Un « Commencer » plus ancien ne démarre plus de séance à l'ouverture de l'app.
    static let fraicheurCommencer: Int64 = 10 * 60_000
    /// Le temps de laisser passer une rafale de changements (une séance qui commence en écrit plusieurs).
    private static let delaiDepot: Duration = .milliseconds(400)

    private let magasin: Magasin
    private let traducteur: Traducteur
    private let horloge: any Horloge
    private let palettes: Palettes?
    /// Les illustrations du paquet de l'app (`Images/<nom>.webp`).
    private let images: URL

    /// Un « Commencer » du bouclier, relevé dans la boîte, que l'app n'a pas encore suivi.
    private var commencerDemande = false
    /// L'essai réel en cours, déposé dans bouclier.json.
    private var essai: DecorBouclier.Essai?
    /// Le dernier instantané écrit, sans son heure d'écriture : un instantané identique ne se réécrit pas.
    private var dernierEtat: Etat?
    private var dernierDecor: DecorBouclier?
    /// La pose déposée pour chaque visage (elle change chaque jour, et avec l'adresse).
    private var posesDeposees: [PoseBouclier: String] = [:]
    /// Les jetons posés sur `barriere` et `seance` depuis le lancement, et ceux-là.
    private var jetonsAJour = false
    private var jetonsPoses: Data?
    /// `barriere` et `seance` ont été vidés (mode éteint, sélection vide).
    private var magasinsVides = false
    private var suivi = false
    private var depotPrevu: Task<Void, Never>?
    private var finEssaiPrevue: Task<Void, Never>?

    /// `paquet` : le paquet de l'app, où sont les illustrations (`Images/`).
    init(magasin: Magasin, traducteur: Traducteur, horloge: any Horloge, palettes: Palettes?, paquet: URL) {
        self.magasin = magasin
        self.traducteur = traducteur
        self.horloge = horloge
        self.palettes = palettes
        images = paquet.appending(path: "Images", directoryHint: .isDirectory)
    }

    // MARK: Le suivi

    /// Suit le journal et les réglages, et dépose une première fois. Une seule fois pour la vie de l'app.
    func demarrer() {
        guard !suivi else { return }
        suivi = true
        suivre()
        prevoirDepot()
    }

    /// Le retour au premier plan : la boîte relevée, puis tout redéposé (le jour a pu changer, la sélection aussi).
    func actualiser() async {
        guard let conteneur else { return }
        await relever(conteneur)
        await deposer()
    }

    /// Un « Commencer » du bouclier attend : l'app doit ouvrir l'écran de séance, la séance lancée. Rendu une fois.
    func demandeDeCommencer() -> Bool {
        let demande = commencerDemande
        commencerDemande = false
        return demande
    }

    /// Un changement du journal ou des réglages (une lecture dans `apply` suffit à l'observer) : un dépôt prévu,
    /// puis le suivi rétabli, l'observation ne prévenant qu'une fois.
    private func suivre() {
        withObservationTracking {
            _ = magasin.journal
            _ = magasin.reglages
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.suivre()
                self?.prevoirDepot()
            }
        }
    }

    private func prevoirDepot() {
        depotPrevu?.cancel()
        depotPrevu = Task { @MainActor [weak self] in
            try? await Task.sleep(for: SystemeBarriere.delaiDepot)
            guard !Task.isCancelled else { return }
            await self?.deposer()
        }
    }

    // MARK: Le dépôt

    /// Le conteneur du groupe d'apps ; nil sans groupe accordé, et toujours dans la construction sans barrière.
    private var conteneur: URL? {
        #if SANS_BARRIERE
        return nil
        #else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ConteneurBarriere.groupe)
        #endif
    }

    /// Écrit etat.json, bouclier.json et les poses, puis met les magasins et la surveillance d'accord.
    func deposer() async {
        guard let conteneur else { return }
        let millis = horloge.maintenant
        let fuseau = horloge.fuseau
        let zone = TimeZone(identifier: fuseau.identifiant) ?? TimeZone.current
        let familyControls = SystemeFamilyControls()
        let selection = await familyControls.lire()
        var jetons = 0
        if let selection, let compte = await familyControls.compter(selection) {
            jetons = compte.total
        }
        let traducteur = self.traducteur
        let etat = EtatBarriere.etat(journal: magasin.journal, reglages: magasin.reglages, millis: millis,
                                     fuseau: fuseau, nombreDeJetons: jetons, textes: { traducteur.texte($0) })
        if let fini = essai, fini.fin <= millis {
            essai = nil
        }
        var decor = decorDesCouleurs()
        decor.essai = essai
        do {
            try FileManager.default.createDirectory(at: ConteneurBarriere.repertoire(dans: conteneur),
                                                    withIntermediateDirectories: true)
        } catch {
            return
        }
        ecrireEtat(etat, conteneur)
        if decor != dernierDecor, let donnees = try? decor.donnees(), ecrire(donnees, DecorBouclier.nomFichier, conteneur) {
            dernierDecor = decor
        }
        deposerPoses(conteneur)
        appliquer(etat: etat, decor: decor, selection: selection, millis: millis, zone: zone, conteneur: conteneur)
    }

    private func ecrireEtat(_ etat: Etat, _ conteneur: URL) {
        var comparable = etat
        comparable.ecritA = 0
        guard comparable != dernierEtat, let donnees = try? etat.donnees() else { return }
        if ecrire(donnees, Etat.nomFichier, conteneur) {
            dernierEtat = comparable
        }
    }

    /// Les couleurs de jour de la palette choisie (le bouclier est dessiné par le système, qui ne dit pas à
    /// l'extension si l'écran est sombre) ; celles d'origine si palettes.json n'a pu être lu.
    private func decorDesCouleurs() -> DecorBouclier {
        var decor = DecorBouclier()
        guard let palettes else { return decor }
        let reglages = magasin.reglages
        let palette = palettes.palette(fond: reglages.fond, accent: reglages.accent, nuit: false)
        decor.fond = palette[.brandDark].hex
        decor.bouton = palette[.brand].hex
        decor.texteBouton = palette[.onBrand].hex
        decor.sousTitre = palette[.mint].hex
        return decor
    }

    /// Les poses du jour (Character.call, Character.during), au féminin pour qui a choisi צדקת, copiées du paquet.
    private func deposerPoses(_ conteneur: URL) {
        let jour = horloge.aujourdhui
        let adresse = Adresse.parse(magasin.reglages.adresse)
        for pose in PoseBouclier.allCases {
            let nom = Personnage.pour(adresse, pose == .appel ? Poses.call(jour) : Poses.during(jour))
            guard posesDeposees[pose] != nom else { continue }
            let source = images.appending(path: nom + ".webp", directoryHint: .notDirectory)
            guard let donnees = try? Data(contentsOf: source), ecrire(donnees, pose.fichier, conteneur) else { continue }
            posesDeposees[pose] = nom
        }
    }

    /// Les magasins d'accord avec la règle, puis la surveillance. L'état d'un magasin passe avant ses jetons : un
    /// magasin qu'on remplit ne retient pas un instant de trop. Chaque bascule faite par l'app (une séance qui
    /// commence, une correction après un rendez-vous manqué) va à l'historique.
    private func appliquer(etat: Etat, decor: DecorBouclier, selection: Data?, millis: Int64, zone: TimeZone,
                           conteneur: URL) {
        let evenements = lireBoite(conteneur)
        let consigne = PilotageBarriere.consigne(etat: etat, decor: decor, evenements: evenements, millis: millis,
                                                 fuseau: zone)
        let quand = EtatBarriere.horodatage(millis: millis, fuseau: horloge.fuseau)
        var bascules: [Evenement] = []
        func basculer(_ nom: String, _ actif: Bool) {
            if SystemeBarriereMagasins.basculer(nom, actif) {
                bascules.append(Evenement(quand: quand, genre: actif ? .armee : .levee, detail: "app:" + nom))
            }
        }
        let noms = [PilotageBarriere.magasinBarriere, PilotageBarriere.magasinSeance]
        if etat.enabled && etat.nombreDeJetons > 0 {
            basculer(PilotageBarriere.magasinBarriere, consigne.barriere)
            basculer(PilotageBarriere.magasinSeance, consigne.seance)
            if !jetonsAJour || jetonsPoses != selection {
                SystemeBarriereMagasins.poserJetons(selection, sur: noms)
                jetonsPoses = selection
                jetonsAJour = true
            }
            magasinsVides = false
        } else if !magasinsVides {
            SystemeBarriereMagasins.vider(noms)
            magasinsVides = true
            jetonsAJour = false
            jetonsPoses = nil
        }
        // L'essai : ses jetons sont posés par `commencerEssai` ; ici, il s'active à son début et se lève à sa fin.
        // Pas noté : un magasin jamais rempli est actif par défaut, sa première désactivation ne dit rien.
        _ = SystemeBarriereMagasins.basculer(PilotageBarriere.magasinEssai, consigne.essai)
        noter(bascules)
        SystemeBarriereMagasins.planifier(etat, essai: decor.essai, millis: millis, fuseau: zone)
    }

    // MARK: La boîte et l'historique

    /// Relève la boîte des extensions : elle est d'abord renommée (une ligne ajoutée pendant la relève va à une
    /// boîte neuve), lue, versée, puis effacée.
    private func relever(_ conteneur: URL) async {
        let fichiers = FileManager.default
        let boite = ConteneurBarriere.fichier(Boite.nomFichier, dans: conteneur)
        let releve = ConteneurBarriere.fichier(Boite.nomFichier + ".releve", dans: conteneur)
        guard fichiers.fileExists(atPath: boite.path(percentEncoded: false)) else { return }
        try? fichiers.removeItem(at: releve)
        do {
            try fichiers.moveItem(at: boite, to: releve)
        } catch {
            return
        }
        let evenements = Boite.lire((try? Data(contentsOf: releve)) ?? Data(), garder: Int.max)
        if !evenements.isEmpty {
            noter(evenements)
            await verser(evenements)
        }
        try? fichiers.removeItem(at: releve)
    }

    /// Ce que les extensions ont appris, porté au journal et aux réglages, dans l'ordre des événements.
    private func verser(_ evenements: [Evenement]) async {
        var journal = magasin.journal
        var reglages = magasin.reglages
        let fuseau = horloge.fuseau
        let maintenant = horloge.maintenant
        for evenement in evenements {
            let instant = evenement.quand.millis
            switch evenement.genreConnu {
            case .dejaFaite?:
                // Le « Je l'ai déjà faite » de l'écran de garde : `Store.addSession(context, 0)`.
                Store.addSession(journal: &journal, reglages: &reglages, minutes: 0, millis: instant, fuseau: fuseau)
            case .plusTard?:
                let minutes = Int(evenement.detail) ?? reglages.snoozeMinutes
                if instant + Int64(minutes) * 60_000 > reglages.snoozedUntil {
                    Store.snooze(reglages: &reglages, millis: instant)
                }
            case .commencer?:
                if instant + SystemeBarriere.fraicheurCommencer >= maintenant {
                    commencerDemande = true
                }
            case .essai?:
                if evenement.detail == PilotageBarriere.finEssai, let courant = essai, instant >= courant.debut {
                    essai = nil
                }
            default:
                break
            }
        }
        let journalFinal = journal
        let reglagesFinals = reglages
        do {
            try await magasin.modifierJournal { $0 = journalFinal }
        } catch {
            // Le changement reste en mémoire ; la prochaine écriture l'emportera (Magasin).
        }
        do {
            try await magasin.modifierReglages { $0 = reglagesFinals }
        } catch {
            // Idem.
        }
    }

    /// La boîte telle qu'elle est, sans la vider : ce que les extensions savent déjà.
    private func lireBoite(_ conteneur: URL) -> [Evenement] {
        let boite = ConteneurBarriere.fichier(Boite.nomFichier, dans: conteneur)
        return Boite.lire((try? Data(contentsOf: boite)) ?? Data())
    }

    /// Les cinquante derniers événements de la barrière (le journal de la barrière, § 2.1.8), du plus ancien au
    /// plus récent ; vide sans groupe d'apps.
    func historique() -> [Evenement] {
        guard let conteneur else { return [] }
        let fichier = ConteneurBarriere.fichier(ConteneurBarriere.historique, dans: conteneur)
        return Boite.lire((try? Data(contentsOf: fichier)) ?? Data())
    }

    /// Ajoute des événements à l'historique, qui garde les cinquante derniers.
    private func noter(_ evenements: [Evenement]) {
        guard !evenements.isEmpty, let conteneur else { return }
        var donnees = Data()
        for evenement in Array((historique() + evenements).suffix(Boite.maximum)) {
            donnees.append(Boite.ligne(evenement))
        }
        _ = ecrire(donnees, ConteneurBarriere.historique, conteneur)
    }

    // MARK: Le constat

    /// Ce que la carte d'état des réglages évalue (§ 2.1.8) : l'autorisation, puis, mode allumé, l'activité
    /// `fenetre` inscrite, le dernier réveil de la surveillance (l'historique, une fois la boîte relevée) et le
    /// magasin `barriere`, une fois l'app d'accord avec la règle. Pendant une séance, c'est le magasin `seance` qui
    /// retient : celui de la barrière n'est pas jugé.
    func constat() async -> Constat {
        let autorise = await SystemeFamilyControls().etat() == .accordee
        var constat = Constat(autorise: autorise)
        guard conteneur != nil else { return constat }
        await actualiser()
        guard magasin.reglages.isEnabled else { return constat }
        constat.surveillanceInscrite = SystemeBarriereMagasins.inscrite(.fenetre)
        constat.dernierReveil = Boite.dernierReveil(historique())
        if let etats = SystemeBarriereMagasins.etats(), !etats.seance {
            constat.magasinActif = etats.barriere
        }
        return constat
    }

    // MARK: Tout lever

    /// « Tout effacer » (`TempsEcran.leverBoucliers`) : les trois magasins vidés, plus aucune activité surveillée.
    func toutLever() async {
        essai = nil
        finEssaiPrevue?.cancel()
        SystemeBarriereMagasins.vider([PilotageBarriere.magasinBarriere, PilotageBarriere.magasinSeance,
                                       PilotageBarriere.magasinEssai])
        SystemeBarriereMagasins.toutArreter()
        jetonsAJour = false
        jetonsPoses = nil
        magasinsVides = true
        await deposer()
    }

    // MARK: L'essai réel

    /// Deux minutes de vrai bouclier « APERÇU, AUCUN EFFET » sur les applications choisies, à n'importe quelle
    /// heure, mode allumé ou non. Il faut l'autorisation de Temps d'écran et une sélection non vide ; l'activité
    /// `essai` le lève à sa fin si l'app dort, sinon l'app le lève elle-même.
    func commencerEssai() async -> Int64? {
        let familyControls = SystemeFamilyControls()
        guard conteneur != nil, await familyControls.etat() == .accordee, let selection = await familyControls.lire(),
              let compte = await familyControls.compter(selection), compte.total > 0 else {
            return nil
        }
        let debut = horloge.maintenant
        let fin = debut + PilotageBarriere.dureeEssai
        essai = DecorBouclier.Essai(debut: debut, fin: fin)
        // Les jetons sur un magasin inactif ; le dépôt écrit l'essai dans bouclier.json, puis active le magasin.
        _ = SystemeBarriereMagasins.basculer(PilotageBarriere.magasinEssai, false)
        SystemeBarriereMagasins.poserJetons(selection, sur: [PilotageBarriere.magasinEssai])
        noter([Evenement(quand: EtatBarriere.horodatage(millis: debut, fuseau: horloge.fuseau), genre: .essai,
                         detail: PilotageBarriere.debutEssai)])
        await deposer()
        finEssaiPrevue?.cancel()
        finEssaiPrevue = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(fin - debut + 1000))
            guard !Task.isCancelled else { return }
            await self?.deposer()
        }
        return fin
    }

    // MARK: Les fichiers

    /// Écriture atomique dans le dossier de la barrière, lisible dès le premier déverrouillage (l'extension de
    /// surveillance est réveillée le matin), hors de la sauvegarde iCloud (§ 3.2 : un état de cet iPhone). Vrai si
    /// le fichier est écrit.
    private func ecrire(_ donnees: Data, _ nom: String, _ conteneur: URL) -> Bool {
        var url = ConteneurBarriere.fichier(nom, dans: conteneur)
        do {
            try donnees.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            return false
        }
        var valeurs = URLResourceValues()
        valeurs.isExcludedFromBackup = true
        try? url.setResourceValues(valeurs)
        return true
    }
}
