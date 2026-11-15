import Foundation
import Observation
import Coeur

/// La boussole de Jérusalem (BoussoleActivity.kt, design C « le hassid se tourne », 28/10), depuis le lieu des
/// zmanim : le bandeau et son lieu, la boussole (scène en valeurs, BoussoleScene), les deux directions et la
/// distance, le choix de la méthode et de l'affichage, la note sur les deux calculs ; sans lieu, l'état vide.
///
/// Le cap vient du `BoussoleCapteur`, depuis le nord magnétique ; le modèle y ajoute la déclinaison du lieu
/// (Magnetisme, WMM2025, à la place du GeomagneticField d'Android) pour le nord vrai, comme les deux
/// directions, puis le lisse (Boussole.lisser). Rien ne passe par le réseau.
///
/// Le lieu, la méthode (`boussole_carte`) et l'affichage (`boussole_rose`) sont les réglages du `Magasin`,
/// lus à chaque fois : un lieu choisi ailleurs se voit ici. « Actualiser ma position » demande la position
/// approximative (ChoixLieu.maPosition) ; à chaque reprise de l'écran, la position du téléphone se reprend
/// sans bruit si elle est déjà permise (ChoixLieu.rafraichir).
///
/// La vue appelle `suivreCapteur()` dans sa `.task` (le capteur s'arrête quand la tâche est annulée) et
/// `reprendre()` à l'apparition et au retour au premier plan (onResume).
@MainActor
@Observable
public final class BoussoleModele {
    private let magasin: Magasin
    private let contenus: ContenusApp
    private let horloge: any Horloge
    private let traducteur: Traducteur
    private let tableaux: BoussoleTableaux
    private let capteur: any BoussoleCapteur
    private let localisation: any Localisation
    private let autorisationLieu: any BoussoleAutorisationLieu
    private let rafraichissement: (any BoussoleRafraichissement)?

    /// L'article qui expose les deux calculs (BoussoleActivity.SOURCE, vérifié le 28/10).
    public static let adresseSource =
        "https://www.chabad.org/library/article_cdo/aid/3502321/jewish/Why-Do-We-Face-East-When-Praying-Or-Do-We.htm"

    // MARK: L'état

    /// Le téléphone a-t-il de quoi trouver le nord ? Vrai jusqu'à ce que `suivreCapteur()` le demande au
    /// capteur (la plupart des téléphones en ont un).
    public private(set) var avecCapteur = true
    /// Le cap lissé, depuis le nord vrai (le `lisse` de BoussoleActivity) ; nil tant qu'aucune mesure n'est
    /// venue. Il survit à la reprise de l'écran, comme sur Android.
    public private(set) var capLisse: Double? = nil
    /// La dernière précision annoncée est au plus basse (onAccuracyChanged) ; remis à faux à chaque
    /// abonnement au capteur (afficher() recrée l'avertissement caché).
    public private(set) var precisionFaible = false
    /// Le nombre d'arrivées face à Jérusalem : la vue joue le retour haptique à chaque hausse
    /// (`.sensoryFeedback(_, trigger:)`), comme BoussoleView.performHapticFeedback(CONFIRM).
    public private(set) var alignements = 0
    /// Ce que lit VoiceOver sur la boussole (BoussoleView.contentDescription) : pas à chaque mesure, qui le
    /// ferait relire sans fin, mais à chaque nouvel affichage (le cap n'y est pas encore : « 54° depuis le
    /// nord ») puis à chaque arrivée face à Jérusalem et à chaque départ.
    public private(set) var consigneAccessible = Libelle("zmanim_choisir_lieu")
    /// Le dialogue ouvert ; nil sans dialogue.
    public var dialogue: BoussoleDialogue? = nil
    /// Les villes du dialogue du choix du lieu, sous « Ma position », dans l'ordre de villes.json.
    public private(set) var villesProposees: [BoussoleVilleProposee] = []
    /// Le message passager (les Toast de ChoixLieu) ; la vue l'efface (`effacerMessage()`) au bout de sa durée.
    public private(set) var message: BoussoleMessage? = nil
    /// Une demande de position est en cours.
    public private(set) var rechercheEnCours = false

    /// La position était-elle face à Jérusalem à la mesure précédente (BoussoleView.etaitFace) ?
    @ObservationIgnored private var etaitAlignee = false
    /// Les villes lues, pour le choix du lieu et pour nommer la position.
    @ObservationIgnored private var villes: [Ville]?
    /// La déclinaison du dernier lieu, calculée une fois (le modèle WMM2025 a quatre-vingt-dix termes).
    @ObservationIgnored private var memoDeclinaison: (latitude: Double, longitude: Double, valeur: Double)?

    public init(magasin: Magasin, contenus: ContenusApp, horloge: any Horloge, traducteur: Traducteur,
                tableaux: BoussoleTableaux, capteur: any BoussoleCapteur, localisation: any Localisation,
                autorisationLieu: any BoussoleAutorisationLieu, rafraichissement: (any BoussoleRafraichissement)? = nil) {
        self.magasin = magasin
        self.contenus = contenus
        self.horloge = horloge
        self.traducteur = traducteur
        self.tableaux = tableaux
        self.capteur = capteur
        self.localisation = localisation
        self.autorisationLieu = autorisationLieu
        self.rafraichissement = rafraichissement
        reinitialiserScene()
    }

    // MARK: Le lieu et les réglages

    /// Le lieu des zmanim ; nil tant que rien n'est choisi : l'état vide propose alors le choix.
    public var lieu: Zmanim.Lieu? {
        magasin.reglages.lieuZmanim
    }

    /// La direction de la carte de Mercator (cap constant) plutôt que celle du grand cercle (par défaut).
    public var selonCarte: Bool {
        magasin.reglages.boussoleCarte
    }

    /// La rose des vents plutôt que le hassid (par défaut).
    public var rose: Bool {
        magasin.reglages.boussoleRose
    }

    /// La langue de l'app : « fr », « en » ou « he » (ChizukCard.language).
    public var langue: String {
        traducteur.langue
    }

    /// Ce que montre l'écran.
    public var etat: BoussoleEtat {
        if lieu == nil { return .sansLieu }
        if !avecCapteur { return .sansCapteur }
        return capLisse == nil ? .attenteDuCap : .orientee
    }

    /// L'image du hassid de dos (le bandeau, l'état vide, la scène), au féminin pour qui a choisi צדקת
    /// (Personnage.pour).
    public var imageHassid: String {
        Personnage.pour(magasin.reglages.adresse.flatMap { Adresse(rawValue: $0) }, "char_standing_back")
    }

    /// La pastille du bandeau, sous le titre : le nom du lieu, « Choisir le lieu » s'il est vide ; nil sans
    /// lieu (l'état vide propose déjà le choix : pas de seconde pastille, 29/10). Son toucher ouvre le choix.
    public var pastille: BoussolePastille? {
        guard let lieu else { return nil }
        return lieu.nom.isEmpty ? .libelle(Libelle("zmanim_choisir_lieu")) : .nom(lieu.nom)
    }

    // MARK: Les directions

    /// La déclinaison magnétique du lieu, en degrés vers l'est (Magnetisme.declinaison, au niveau de la mer,
    /// à l'instant de l'horloge) ; nil sans lieu.
    public var declinaison: Double? {
        guard let lieu else { return nil }
        if let memo = memoDeclinaison, memo.latitude == lieu.latitude, memo.longitude == lieu.longitude {
            return memo.valeur
        }
        let valeur = Magnetisme.declinaison(lieu.latitude, lieu.longitude, millis: horloge.maintenant)
        memoDeclinaison = (latitude: lieu.latitude, longitude: lieu.longitude, valeur: valeur)
        return valeur
    }

    /// La direction que suit le hassid, depuis le nord vrai : le grand cercle, ou la carte si on l'a choisie.
    public var principale: Double? {
        guard let lieu else { return nil }
        return DirectionJerusalem.directions(lieu.latitude, lieu.longitude, selonCarte: selonCarte).principale
    }

    /// L'autre direction, affichée pour information (le pointillé bleu).
    public var autre: Double? {
        guard let lieu else { return nil }
        return DirectionJerusalem.directions(lieu.latitude, lieu.longitude, selonCarte: selonCarte).autre
    }

    /// Où pointe le haut du téléphone, depuis le nord vrai ; nil sans lieu, sans capteur ou avant la première
    /// mesure.
    public var cap: Double? {
        guard lieu != nil, avecCapteur else { return nil }
        return capLisse
    }

    /// De combien tourner vers la direction principale, de -180 (à gauche) à +180 (à droite).
    public var ecart: Double? {
        guard let principale, let cap else { return nil }
        return DirectionJerusalem.ecart(principale, cap)
    }

    /// Face à Jérusalem, à ±4°.
    public var alignee: Bool {
        guard let ecart else { return false }
        return DirectionJerusalem.face(ecart)
    }

    /// Le texte du haut de la boussole (BoussoleView.consigne), à chaque mesure.
    public var consigne: Libelle {
        consignePour(cap: cap)
    }

    /// La scène à dessiner ; nil sans lieu (l'écran montre alors l'état vide, sans boussole).
    public var scene: BoussoleScene? {
        guard let principale, let autre else { return nil }
        guard let cap else {
            return .roseFixe(BoussoleRoseFixe(principale: principale, degres: DirectionJerusalem.degres(principale)))
        }
        let ecart = DirectionJerusalem.ecart(principale, cap)
        let face = DirectionJerusalem.face(ecart)
        if rose {
            return .roseVivante(BoussoleRoseVivante(cap: cap, principale: principale, autre: autre, face: face,
                                                    tolerance: Double(DirectionJerusalem.tolerance),
                                                    consigne: consignePour(cap: cap)))
        }
        let xJerusalem = BoussoleScene.xHorizon(ecart)
        return .hassid(BoussoleHassid(ecart: ecart, face: face, xJerusalem: xJerusalem,
                                      xEtiquette: BoussoleScene.xEtiquette(xJerusalem),
                                      xAutre: BoussoleScene.xHorizon(DirectionJerusalem.ecart(autre, cap)),
                                      yHassid: face ? -68 : -62, consigne: consignePour(cap: cap)))
    }

    /// N, E, S, O dans la langue, pour la rose vivante (boussole_cardinaux).
    public var cardinaux: [String] {
        tableaux.cardinaux
    }

    /// Le « N » de la rose fixe.
    public var nord: Libelle {
        Libelle("boussole_nord")
    }

    // MARK: Les textes sous la boussole

    /// L'avertissement « Boussole peu précise : dessinez un 8 » (en couleur d'alerte), sous la boussole.
    public var montrerCalibrage: Bool {
        lieu != nil && precisionFaible
    }

    /// L'aide sous la boussole : à plat ou droit, loin du métal ; ou ce téléphone n'a pas de boussole.
    public var aide: Libelle {
        Libelle(avecCapteur ? "boussole_a_plat" : "boussole_sans_capteur")
    }

    /// La première ligne de la carte des directions, celle que suit le hassid (en vert et en gras) :
    /// « Direction réelle (grand cercle) : 54° NE ».
    public var directionSuivie: Libelle? {
        lignes?.suivie
    }

    /// La seconde ligne, l'autre direction : « Direction sur la carte (cap constant) : 96° E ».
    public var directionAutre: Libelle? {
        lignes?.autre
    }

    /// La distance par le grand cercle, en kilomètres entiers (Math.round).
    public var distanceKm: Int? {
        guard let lieu else { return nil }
        return Int(Kotlin.arrondiLong(DirectionJerusalem.distanceKm(lieu.latitude, lieu.longitude)))
    }

    /// « Distance : 9 169 km », le nombre groupé comme NumberFormat.getIntegerInstance dans la langue.
    public var distance: Libelle? {
        guard let distanceKm else { return nil }
        return Libelle("boussole_distance", .texte(BoussoleModele.entierGroupe(distanceKm, langue: langue)))
    }

    /// Ce que suivent l'étiquette et le pointillé bleu.
    public var legende: Libelle? {
        guard lieu != nil else { return nil }
        return Libelle(selonCarte ? "boussole_legende_carte" : "boussole_legende")
    }

    /// Le sous-titre de la carte « Direction suivie » : la méthode choisie.
    public var methodeChoisie: Libelle {
        Libelle(selonCarte ? "boussole_methode_carte" : "boussole_methode_reelle")
    }

    /// Le sous-titre de la carte « Affichage de la boussole » : l'affichage choisi.
    public var affichageChoisi: Libelle {
        Libelle(rose ? "boussole_affichage_rose" : "boussole_affichage_hassid")
    }

    /// « Source : Chabad.org, “Why Do We Face East…” » : le titre isolé (U+2066 … U+2069), comme Android, pour
    /// que l'anglais garde sa ponctuation dans l'hébreu ; toute la ligne mène à `lienSource`.
    public var source: Libelle {
        Libelle("boussole_source", .texte("\u{2066}" + traducteur.texte(cle: "boussole_source_titre") + "\u{2069}"))
    }

    /// L'article de la note.
    public var lienSource: URL? {
        URL(string: BoussoleModele.adresseSource)
    }

    // MARK: Les dialogues

    /// Les deux méthodes, la choisie cochée : le grand cercle (`valeur` faux), puis la carte (vrai).
    public var optionsMethode: [BoussoleOption] {
        [BoussoleOption(libelle: Libelle("boussole_methode_reelle"), valeur: false, choisie: !selonCarte),
         BoussoleOption(libelle: Libelle("boussole_methode_carte"), valeur: true, choisie: selonCarte)]
    }

    /// Les deux affichages, le choisi coché : le hassid (`valeur` faux), puis la rose des vents (vrai).
    public var optionsAffichage: [BoussoleOption] {
        [BoussoleOption(libelle: Libelle("boussole_affichage_hassid"), valeur: false, choisie: !rose),
         BoussoleOption(libelle: Libelle("boussole_affichage_rose"), valeur: true, choisie: rose)]
    }

    /// La première ligne du choix du lieu, au-dessus des villes.
    public var maPosition: Libelle {
        Libelle("zmanim_position")
    }

    public func ouvrirMethode() {
        dialogue = .methode
    }

    public func ouvrirAffichage() {
        dialogue = .affichage
    }

    /// Ouvre le choix du lieu (ChoixLieu.montrer) : « Ma position », puis les villes dans la langue de l'app.
    /// Si les villes ne se lisent pas, le dialogue n'a que « Ma position ».
    public func ouvrirChoixLieu() async {
        let liste = await villesLues()
        let langue = self.langue
        villesProposees = liste.map { BoussoleVilleProposee(id: $0.id, nom: $0.nom.pour(langue)) }
        dialogue = .choixLieu
    }

    public func fermerDialogue() {
        dialogue = nil
    }

    public func effacerMessage() {
        message = nil
    }

    // MARK: Les actions

    /// Grand cercle ou carte de Mercator (03/11) : la boussole et le widget suivent le choix.
    public func choisirMethode(selonCarte: Bool) async throws {
        dialogue = nil
        try await magasin.modifierReglages { $0.setBoussoleCarte(selonCarte) }
        reinitialiserScene()
        await rafraichissement?.rafraichir()
    }

    /// Le hassid ou la rose des vents.
    public func choisirAffichage(rose: Bool) async throws {
        dialogue = nil
        try await magasin.modifierReglages { $0.setBoussoleRose(rose) }
        reinitialiserScene()
    }

    /// Une ville de la liste (ChoixLieu.montrer) : son nom dans la langue de l'app, et Israël ou diaspora
    /// selon son pays (Reglages.setLieuZmanim). Une ville inconnue ne change rien.
    public func choisirVille(id: Int64) async throws {
        dialogue = nil
        let liste = await villesLues()
        guard let ville = liste.first(where: { $0.id == id }) else { return }
        let lieu = Zmanim.Lieu(nom: ville.nom.pour(langue), latitude: ville.latitude, longitude: ville.longitude,
                               altitude: ville.altitude, fuseau: ville.fuseau)
        let maintenant = horloge.maintenant
        try await magasin.modifierReglages { $0.setLieuZmanim(lieu, ville: ville, maintenant: maintenant) }
        reinitialiserScene()
        await rafraichissement?.rafraichir()
    }

    /// « Utiliser ma position » (l'état vide, le choix du lieu) et « Actualiser ma position » (sous la
    /// boussole) : la position approximative, l'autorisation demandée au besoin (ChoixLieu.maPosition).
    /// Pendant la recherche, « Recherche de la position… » ; sans position, « Position indisponible : choisissez
    /// une ville. ». Une demande en cours n'en lance pas d'autre.
    public func utiliserMaPosition() async throws {
        dialogue = nil
        guard !rechercheEnCours else { return }
        rechercheEnCours = true
        defer { rechercheEnCours = false }
        message = BoussoleMessage(libelle: Libelle("zmanim_position_attente"), long: false)
        switch await localisation.positionApprochee() {
        case .position(let position):
            message = nil
            try await enregistrer(position)
        case .refusee, .indisponible:
            message = BoussoleMessage(libelle: Libelle("zmanim_position_refusee"), long: true)
        }
    }

    /// La reprise de l'écran (onResume, ChoixLieu.rafraichir) : si le lieu est la position du téléphone (pas
    /// une ville) et que la localisation est déjà permise, la reprendre sans rien dire, pour que la direction
    /// suive l'endroit où l'on est (28/10). Rien n'est demandé, aucun message ; sans position, rien ne change.
    public func reprendre() async throws {
        guard lieu != nil, magasin.reglages.lieuVille == -1, !rechercheEnCours else { return }
        guard await autorisationLieu.localisationPermise() else { return }
        rechercheEnCours = true
        defer { rechercheEnCours = false }
        if case .position(let position) = await localisation.positionApprochee() {
            try await enregistrer(position)
        }
    }

    /// Écoute le capteur tant que la tâche qui l'appelle n'est pas annulée (la `.task` de la vue : onResume
    /// et onPause d'Android). Sans capteur, rend la main tout de suite : la rose fixe reste, orientée au nord.
    /// Chaque abonnement est un nouvel affichage : l'avertissement de précision repart caché, et l'arrivée face
    /// à Jérusalem se signale de nouveau si l'on y est déjà ; le cap lissé, lui, continue.
    public func suivreCapteur() async {
        let present = await capteur.disponible()
        avecCapteur = present
        guard present else { return }
        precisionFaible = false
        reinitialiserScene()
        let flux = await capteur.mesures()
        for await mesure in flux {
            if Task.isCancelled { break }
            recevoir(mesure)
        }
    }

    /// Une mesure du capteur (onSensorChanged, onAccuracyChanged) : le cap magnétique, plus la déclinaison du
    /// lieu, lissé ; ou la précision. Une matrice incomplète ou un cap qui n'est pas un nombre sont ignorés.
    public func recevoir(_ mesure: BoussoleMesure) {
        switch mesure {
        case .orientation(let matrice):
            guard matrice.count == 9 else { return }
            appliquer(capMagnetique: Boussole.capDevant(matrice))
        case .cap(let magnetique):
            appliquer(capMagnetique: magnetique)
        case .precision(let precision):
            precisionFaible = precision.aCalibrer
        }
    }

    // MARK: Le reste

    private func appliquer(capMagnetique: Double) {
        guard capMagnetique.isFinite else { return }
        let vrai = DirectionJerusalem.norm(capMagnetique + (declinaison ?? 0))
        capLisse = Boussole.lisser(capLisse, vrai)
        verifierAlignement()
    }

    /// BoussoleView.cap : l'arrivée face à Jérusalem vibre ; l'arrivée et le départ mettent à jour ce que lit
    /// VoiceOver.
    private func verifierAlignement() {
        let face = alignee
        if face && !etaitAlignee {
            alignements += 1
        }
        if face != etaitAlignee {
            etaitAlignee = face
            consigneAccessible = consigne
        }
    }

    /// Un nouvel affichage (afficher() d'Android recrée la BoussoleView) : `directions()` y met la description
    /// d'un cap encore inconnu, puis `cap(lisse)` signale l'arrivée face à Jérusalem si l'on y est déjà.
    private func reinitialiserScene() {
        etaitAlignee = false
        consigneAccessible = consignePour(cap: nil)
        verifierAlignement()
    }

    private func consignePour(cap: Double?) -> Libelle {
        guard let principale else { return Libelle("zmanim_choisir_lieu") }
        guard let cap else {
            return Libelle("boussole_par_rapport_nord", .entier(DirectionJerusalem.degres(principale)))
        }
        let ecart = DirectionJerusalem.ecart(principale, cap)
        if DirectionJerusalem.face(ecart) { return Libelle("boussole_face") }
        if ecart > 0 { return Libelle("boussole_droite", .entier(Kotlin.arrondi(ecart))) }
        return Libelle("boussole_gauche", .entier(Kotlin.arrondi(-ecart)))
    }

    /// Les deux lignes des directions : celle que suit le hassid d'abord.
    private var lignes: (suivie: Libelle, autre: Libelle)? {
        guard let lieu else { return nil }
        let reelle = ligne("boussole_grand_cercle", DirectionJerusalem.grandCercle(lieu.latitude, lieu.longitude))
        let surCarte = ligne("boussole_cap_constant", DirectionJerusalem.carte(lieu.latitude, lieu.longitude))
        return selonCarte ? (suivie: surCarte, autre: reelle) : (suivie: reelle, autre: surCarte)
    }

    private func ligne(_ cle: String, _ direction: Double) -> Libelle {
        Libelle(cle, .entier(DirectionJerusalem.degres(direction)), .texte(tableaux.point(direction)))
    }

    /// ChoixLieu.enregistrerPosition : la ville la plus proche (à 60 km) ne fait que nommer la position et
    /// donner l'altitude ; le fuseau reste celui du téléphone, et Israël ou diaspora se lit sur le territoire,
    /// pas sur la ville (16/10). Le nom s'enregistre écrit dans la langue de l'app, comme sur Android.
    private func enregistrer(_ position: PositionApprochee) async throws {
        let liste = await villesLues()
        let proche = Villes.plusProche(liste, position.latitude, position.longitude)
        let nom: String
        if let proche {
            nom = traducteur.texte(Libelle("zmanim_position_pres", .texte(proche.nom.pour(langue))))
        } else {
            nom = traducteur.texte(cle: "zmanim_position")
        }
        let lieu = Zmanim.Lieu(nom: nom, latitude: position.latitude, longitude: position.longitude,
                               altitude: proche?.altitude ?? 0, fuseau: horloge.fuseau.identifiant)
        let enIsrael = TerritoireIsrael.contient(position.latitude, position.longitude)
        let maintenant = horloge.maintenant
        try await magasin.modifierReglages { reglages in
            reglages.setLieuZmanim(lieu, ville: nil, maintenant: maintenant)
            reglages.setInIsrael(enIsrael)
        }
        reinitialiserScene()
        await rafraichissement?.rafraichir()
    }

    /// Les villes de villes.json, lues une fois ; une liste vide si elles ne se lisent pas (la position garde
    /// alors le nom « Ma position »).
    private func villesLues() async -> [Ville] {
        if let villes { return villes }
        let lues = (try? await contenus.villes()) ?? []
        if !lues.isEmpty { villes = lues }
        return lues
    }

    /// `NumberFormat.getIntegerInstance(Locale.forLanguageTag(langue)).format(n)` d'Android pour les trois
    /// langues de l'app : des groupes de trois chiffres, séparés par l'espace fine insécable (U+202F) en
    /// français, par une virgule en anglais et en hébreu.
    static func entierGroupe(_ n: Int, langue: String) -> String {
        let separateur: Character = langue == "fr" ? "\u{202F}" : ","
        let chiffres = Array(String(n.magnitude))
        var sortie = n < 0 ? "-" : ""
        for (rang, chiffre) in chiffres.enumerated() {
            if rang > 0 && (chiffres.count - rang) % 3 == 0 {
                sortie.append(separateur)
            }
            sortie.append(chiffre)
        }
        return sortie
    }
}

/// Ce que montre l'écran de la boussole.
public enum BoussoleEtat: Sendable, Hashable {
    /// Aucun lieu : l'état vide (« Où êtes-vous ? »), sans boussole.
    case sansLieu
    /// Le téléphone n'a pas de boussole : la rose fixe, le nord en haut.
    case sansCapteur
    /// Le capteur est là, aucune mesure encore : la rose fixe.
    case attenteDuCap
    /// Le cap est connu : la scène vivante (le hassid ou la rose des vents).
    case orientee
}

/// La pastille du bandeau.
public enum BoussolePastille: Sendable, Hashable {
    /// Le nom du lieu tel qu'enregistré (« Paris », « Ma position · près de Paris »).
    case nom(String)
    /// Une chaîne du catalogue (« Choisir le lieu », quand le nom est vide).
    case libelle(Libelle)
}

/// Un dialogue de la boussole.
public enum BoussoleDialogue: String, Sendable, Hashable, Identifiable {
    /// Le choix du lieu (ChoixLieu.montrer) : « Ma position », puis les villes.
    case choixLieu
    /// « Direction suivie » : le grand cercle ou la carte de Mercator.
    case methode
    /// « Affichage de la boussole » : le hassid ou la rose des vents.
    case affichage

    public var id: String { rawValue }

    /// Le titre du dialogue.
    public var titre: Libelle {
        switch self {
        case .choixLieu: Libelle("zmanim_choisir_lieu")
        case .methode: Libelle("boussole_methode")
        case .affichage: Libelle("boussole_affichage")
        }
    }
}

/// Une ligne d'un dialogue à choix unique (setSingleChoiceItems).
public struct BoussoleOption: Sendable, Hashable, Identifiable {
    public let libelle: Libelle
    /// Ce que l'option choisit : la carte de Mercator (méthode), la rose des vents (affichage).
    public let valeur: Bool
    /// L'option cochée.
    public let choisie: Bool

    public var id: String { libelle.cle }

    public init(libelle: Libelle, valeur: Bool, choisie: Bool) {
        self.libelle = libelle
        self.valeur = valeur
        self.choisie = choisie
    }
}

/// Une ville du choix du lieu.
public struct BoussoleVilleProposee: Sendable, Hashable, Identifiable {
    /// L'identifiant GeoNames, que prend `choisirVille(id:)`.
    public let id: Int64
    /// Son nom dans la langue de l'app (l'hébreu à défaut).
    public let nom: String

    public init(id: Int64, nom: String) {
        self.id = id
        self.nom = nom
    }
}

/// Un message passager, le Toast d'Android.
public struct BoussoleMessage: Sendable, Hashable {
    public let libelle: Libelle
    /// Toast.LENGTH_LONG (3,5 s) plutôt que LENGTH_SHORT (2 s).
    public let long: Bool

    public init(libelle: Libelle, long: Bool) {
        self.libelle = libelle
        self.long = long
    }
}
