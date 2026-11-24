import Darwin
import Ecrans
import Foundation
import QuartzCore
import UIKit

/// Les mesures de la tâche 29 (ROADMAP.md : « premier écran en moins de 400 ms, défilement du plus long livre sans
/// image perdue »), prises par l'app elle-même pour le test d'interface `MesuresTests` (UITests/) et la CI
/// (`ios-interface.yml`). Lancée avec « -mesures », l'app écrit ce qu'elle mesure sur sa sortie d'erreur (lignes
/// « MESURE … ») et, si l'environnement de lancement donne MESURES_FICHIER, à la fin de ce fichier, une ligne par
/// mesure, champs séparés par des tabulations. Sans « -mesures », rien : l'app ne passe ici que par trois crochets
/// (`MyHitbodedutApp`, au début de `Captures.ouvrir`), qui rendent la main aussitôt.
///
/// Chaque étape du lancement donne les millisecondes écoulées depuis le démarrage du processus (l'instant où le
/// système l'a créé, avant même le chargement des bibliothèques : `kinfo_proc`), puis le temps de calcul que le
/// processus a pris jusque-là (`getrusage`) : un écart entre les deux est du temps passé à attendre (le disque, la
/// machine), pas à calculer.
/// - **main** : l'entrée dans `MyHitbodedutApp.init` (avant : dyld, les initialisations statiques) ;
/// - **init** : sa fin (polices, palette, formes, catalogues de chaînes lus) ;
/// - **modeles** : le magasin lu et les modèles faits (`ModelesApp.charger`), la racine peut paraître ;
/// - **premier-ecran** : la première image dessinée de l'accueil (la racine posée, à la première image d'après son
///   apparition, `CADisplayLink`) ;
/// - **accueil-pret** : la première image d'après le premier passage de l'accueil fini (`AccueilModele.apparaitre` :
///   contenus lus, anneaux posés).
///
/// Un texte ouvert dans le lecteur donne **lecteur-pret** (ses lignes faites : leur nombre, la lecture du texte et
/// la construction des lignes, en millisecondes) puis **lecteur-affiche** (la première image d'après). Avec
/// « -mesuresDefilement » en plus, l'app fait ensuite défiler ce texte et compte ses images (`DefilementMesure`).
enum Mesures {

    /// « -mesures » : l'app mesure.
    static let actives = ProcessInfo.processInfo.arguments.contains("-mesures")
    /// « -mesuresDefilement » : l'app fait défiler le premier texte ouvert et compte ses images.
    static let defilement = ProcessInfo.processInfo.arguments.contains("-mesuresDefilement")
    /// Le fichier où le test lit les mesures (l'app et le test tournent dans le simulateur, qui écrit dans les
    /// fichiers du Mac).
    static let fichier: String? = ProcessInfo.processInfo.environment["MESURES_FICHIER"]
    /// Le démarrage du processus ; nil s'il est illisible.
    static let debut: Date? = debutDuProcessus()

    /// Une étape du lancement : son nom, les millisecondes depuis le démarrage du processus, le temps de calcul.
    static func etape(_ nom: String) {
        guard actives else { return }
        guard let debut else {
            ecrire(["erreur", "début du processus illisible (sysctl)"])
            return
        }
        ecrire([nom, millisecondes(depuis: debut), String(tempsDeCalcul())])
    }

    /// Mesure le premier écran et l'accueil prêt, l'ouverture des textes du lecteur, puis le défilement si on le
    /// demande ; à appeler à l'apparition de la racine. Sans « -mesures », ne fait rien.
    @MainActor
    static func lancement(_ app: ModelesApp) {
        guard actives else { return }
        LectureModele.mesure = { cible, lignes, lecture, construction in
            let pret = Date()
            ecrire(["lecteur-pret", cible.id, String(lignes), String(lecture), String(construction)])
            Task { @MainActor in
                await ProchaineImage().attendre()
                ecrire(["lecteur-affiche", cible.id, millisecondes(depuis: pret)])
                guard defilement else { return }
                // Le temps que les dernières lignes se posent, puis le défilement.
                try? await Task.sleep(for: .seconds(3))
                DefilementMesure.lancer()
            }
        }
        Task { @MainActor in
            await ProchaineImage().attendre()
            etape("premier-ecran")
            // Les anneaux posés : le premier passage de l'accueil (apparaitre) est allé au bout. Vingt secondes au
            // plus : l'accueil d'une autre version n'a pas d'anneaux, un texte ouvert d'emblée non plus.
            let attente = Date()
            while app.accueil.anneauxMontres == nil && Date().timeIntervalSince(attente) < 20 {
                try? await Task.sleep(for: .milliseconds(4))
            }
            guard app.accueil.anneauxMontres != nil else { return }
            await ProchaineImage().attendre()
            etape("accueil-pret")
        }
    }

    /// L'instant où le système a créé le processus (`kp_proc.p_starttime`), avant dyld et `main`.
    static func debutDuProcessus() -> Date? {
        var info = kinfo_proc()
        var taille = MemoryLayout<kinfo_proc>.stride
        var nom: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let resultat = nom.withUnsafeMutableBufferPointer { nom in
            sysctl(nom.baseAddress, 4, &info, &taille, nil, 0)
        }
        guard resultat == 0 else { return nil }
        let debut = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: Double(debut.tv_sec) + Double(debut.tv_usec) / 1_000_000)
    }

    /// Le temps de calcul du processus depuis son démarrage (utilisateur et système), en millisecondes.
    static func tempsDeCalcul() -> Int {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return -1 }
        let secondes = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        return Int((secondes * 1000).rounded())
    }

    /// Les millisecondes écoulées depuis `debut`, à la milliseconde près (rien n'est arrondi au-delà).
    static func millisecondes(depuis debut: Date) -> String {
        String(Int((Date().timeIntervalSince(debut) * 1000).rounded()))
    }

    /// Une mesure : « MESURE » et ses champs sur la sortie d'erreur ; ses champs, séparés par des tabulations, à la
    /// fin de MESURES_FICHIER.
    static func ecrire(_ champs: [String]) {
        let ligne = champs.joined(separator: "\t") + "\n"
        FileHandle.standardError.write(Data(("MESURE\t" + ligne).utf8))
        guard let fichier else { return }
        if !FileManager.default.fileExists(atPath: fichier) {
            FileManager.default.createFile(atPath: fichier, contents: nil)
        }
        guard let sortie = FileHandle(forWritingAtPath: fichier) else { return }
        defer { try? sortie.close() }
        _ = try? sortie.seekToEnd()
        try? sortie.write(contentsOf: Data(ligne.utf8))
    }
}

/// La prochaine image affichée : `CADisplayLink` rappelle quand l'écran va prendre l'image suivante, celle qui
/// porte ce que la vue vient de poser.
@MainActor
private final class ProchaineImage: NSObject {
    private var suite: CheckedContinuation<Void, Never>?
    private var lien: CADisplayLink?

    func attendre() async {
        await withCheckedContinuation { suite in
            self.suite = suite
            let lien = CADisplayLink(target: self, selector: #selector(image(_:)))
            lien.add(to: .main, forMode: .common)
            self.lien = lien
        }
    }

    @objc private func image(_ lien: CADisplayLink) {
        lien.invalidate()
        self.lien = nil
        suite?.resume()
        suite = nil
    }
}

/// Le défilement mesuré du texte ouvert (« -mesuresDefilement ») : l'app fait défiler elle-même le texte du lecteur,
/// à 3 000 points par seconde, dix secondes vers la fin puis trois vers le début (une lecture qu'on survole, une
/// quarantaine d'écrans), et compte ses images pendant ce temps. Le test n'y touche pas : chaque geste d'un test
/// d'interface fait d'abord photographier tout l'arbre d'accessibilité de l'app, sur son fil principal (quinze
/// secondes sur le plus long livre, au simulateur de la CI), ce qui fausserait le compte.
///
/// À chaque image, l'écart avec la précédente ; un écart de plus d'une image et demie est un accroc (une image au
/// moins n'a pas été prête à temps : le fil principal tenu par la mise en page des lignes qui entrent). La distance
/// suit le temps écoulé, comme un doigt : un accroc ne ralentit pas le défilement, il le saccade. À la fin, une
/// ligne « defilement » : images, accrocs, images perdues, millisecondes d'accroc (ce que chaque accroc a duré
/// au-delà d'une image), le plus long accroc, la durée, les points parcourus. Ce compte ne voit que le fil principal
/// de l'app, pas le serveur de rendu ; `XCTHitchMetric` voit les deux, sur un iPhone (MesuresTests).
@MainActor
final class DefilementMesure: NSObject {
    private static var encours: DefilementMesure?
    static let vitesse: CGFloat = 3_000
    static let descente: CFTimeInterval = 10
    static let remontee: CFTimeInterval = 3

    private let vue: UIScrollView
    private var lien: CADisplayLink?
    private var debut: CFTimeInterval = 0
    private var precedente: CFTimeInterval = 0
    private var images = 0
    private var accrocs = 0
    private var perdues = 0
    private var tempsAccroc: Double = 0
    private var plusLong: Double = 0
    private var parcouru: CGFloat = 0

    private init(vue: UIScrollView) {
        self.vue = vue
    }

    /// Lance le défilement du plus grand défilement vertical de l'écran (le texte du lecteur), une fois.
    static func lancer() {
        guard encours == nil else { return }
        guard let vue = texteDuLecteur() else {
            Mesures.ecrire(["erreur", "aucun texte à faire défiler"])
            return
        }
        let mesure = DefilementMesure(vue: vue)
        let lien = CADisplayLink(target: mesure, selector: #selector(DefilementMesure.image(_:)))
        lien.add(to: .main, forMode: .common)
        mesure.lien = lien
        encours = mesure
    }

    /// Le défilement vertical au plus long contenu, dans les fenêtres de l'app.
    private static func texteDuLecteur() -> UIScrollView? {
        var trouves: [UIScrollView] = []
        func chercher(_ vue: UIView) {
            if let defilement = vue as? UIScrollView, defilement.contentSize.height > defilement.bounds.height * 2 {
                trouves.append(defilement)
            }
            vue.subviews.forEach(chercher)
        }
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach(chercher)
        }
        return trouves.max { $0.contentSize.height < $1.contentSize.height }
    }

    @objc private func image(_ lien: CADisplayLink) {
        let instant = lien.timestamp
        guard debut > 0 else {
            debut = instant
            precedente = instant
            return
        }
        // La durée d'une image à la cadence de l'écran (1/60 s au simulateur ; un iPhone ProMotion varie).
        let duree = max(lien.duration, 1.0 / 120)
        let ecart = instant - precedente
        precedente = instant
        images += 1
        if ecart > duree * 1.5 {
            accrocs += 1
            perdues += max(1, Int((ecart / duree).rounded()) - 1)
            tempsAccroc += (ecart - duree) * 1000
            plusLong = max(plusLong, ecart * 1000)
        }
        let ecoule = instant - debut
        guard ecoule < Self.descente + Self.remontee else {
            finir(ecoule)
            return
        }
        let sens: CGFloat = ecoule < Self.descente ? 1 : -1
        let haut = -vue.adjustedContentInset.top
        let bas = max(haut, vue.contentSize.height - vue.bounds.height + vue.adjustedContentInset.bottom)
        let avant = vue.contentOffset.y
        let apres = min(max(avant + sens * Self.vitesse * CGFloat(ecart), haut), bas)
        parcouru += abs(apres - avant)
        vue.contentOffset = CGPoint(x: vue.contentOffset.x, y: apres)
    }

    private func finir(_ duree: CFTimeInterval) {
        lien?.invalidate()
        lien = nil
        Mesures.ecrire(["defilement", String(images), String(accrocs), String(perdues),
                        String(format: "%.1f", tempsAccroc), String(format: "%.1f", plusLong),
                        String(format: "%.2f", duree), String(Int(parcouru))])
    }
}
