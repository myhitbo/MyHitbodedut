import Darwin
import Ecrans
import Foundation
import QuartzCore

/// Les mesures de la tâche 29 (ROADMAP.md : « premier écran en moins de 400 ms, défilement du plus long livre sans
/// image perdue »), prises par l'app elle-même pour le test d'interface `MesuresTests` (UITests/) et la CI
/// (`ios-interface.yml`). Lancée avec « -mesures », l'app écrit ce qu'elle mesure sur sa sortie d'erreur (lignes
/// « MESURE … ») et, si l'environnement de lancement donne MESURES_FICHIER, à la fin de ce fichier, une ligne par
/// mesure, champs séparés par des tabulations. Sans « -mesures », rien : l'app ne passe ici que par un crochet,
/// au début de `Captures.ouvrir`, qui rend la main aussitôt.
///
/// - **premier-ecran** : du démarrage du processus (l'instant où le système l'a créé, avant même le chargement des
///   bibliothèques : `kinfo_proc`) à la première image dessinée de l'accueil, le magasin lu (la racine posée, à la
///   première image d'après son apparition, `CADisplayLink`).
/// - **accueil-pret** : du même instant à la première image d'après le premier passage de l'accueil fini
///   (`AccueilModele.apparaitre` : contenus lus, anneaux posés).
/// - **images** (avec « -mesuresImages » en plus) : le compte des images depuis le lancement, que le test lit
///   autour de son défilement (`CompteurImages`).
enum Mesures {

    /// « -mesures » : l'app mesure.
    static let actives = ProcessInfo.processInfo.arguments.contains("-mesures")
    /// « -mesuresImages » : l'app compte aussi ses images, image par image.
    static let images = ProcessInfo.processInfo.arguments.contains("-mesuresImages")
    /// Le fichier où le test lit les mesures (l'app et le test tournent dans le simulateur, qui écrit dans les
    /// fichiers du Mac).
    static let fichier: String? = ProcessInfo.processInfo.environment["MESURES_FICHIER"]

    /// Mesure le premier écran et l'accueil prêt, puis compte les images si on le demande ; à appeler à l'apparition
    /// de la racine. Sans « -mesures », ne fait rien.
    @MainActor
    static func lancement(_ app: ModelesApp) {
        guard actives else { return }
        if images { CompteurImages.demarrer() }
        guard let debut = debutDuProcessus() else {
            ecrire(["erreur", "début du processus illisible (sysctl)"])
            return
        }
        Task { @MainActor in
            await ProchaineImage().attendre()
            ecrire(["premier-ecran", millisecondes(depuis: debut)])
            // Les anneaux posés : le premier passage de l'accueil (apparaitre) est allé au bout. Vingt secondes au
            // plus : l'accueil d'une autre version n'a pas d'anneaux.
            var attente = 0
            while app.accueil.anneauxMontres == nil && attente < 20_000 {
                try? await Task.sleep(for: .milliseconds(4))
                attente += 4
            }
            guard app.accueil.anneauxMontres != nil else {
                ecrire(["erreur", "accueil jamais prêt"])
                return
            }
            await ProchaineImage().attendre()
            ecrire(["accueil-pret", millisecondes(depuis: debut)])
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

/// Le compte des images (« -mesuresImages ») : à chaque image, l'écart avec la précédente ; un écart de plus d'une
/// image et demie est un accroc (une image au moins n'a pas été prête à temps : le fil principal tenu, la mise en
/// page d'une ligne du lecteur trop longue). Toutes les quarts de seconde, les comptes depuis le lancement s'écrivent
/// sur une ligne « images » (l'instant, en secondes depuis 1970 : le test, sur la même horloge, lit les comptes de
/// part et d'autre de son défilement) : images, accrocs, images perdues, millisecondes d'accroc (ce que chaque
/// accroc a duré au-delà d'une image). Ce compte ne voit que le fil principal de l'app, pas le serveur de rendu ;
/// `XCTHitchMetric` voit les deux, sur un iPhone.
@MainActor
final class CompteurImages: NSObject {
    private static var compteur: CompteurImages?
    private var lien: CADisplayLink?
    private var precedente: CFTimeInterval = 0
    private var ecrite: CFTimeInterval = 0
    private var nombre = 0
    private var accrocs = 0
    private var perdues = 0
    private var tempsAccroc: Double = 0

    static func demarrer() {
        guard compteur == nil else { return }
        let nouveau = CompteurImages()
        let lien = CADisplayLink(target: nouveau, selector: #selector(CompteurImages.image(_:)))
        lien.add(to: .main, forMode: .common)
        nouveau.lien = lien
        compteur = nouveau
    }

    @objc private func image(_ lien: CADisplayLink) {
        let instant = lien.timestamp
        defer { precedente = instant }
        guard precedente > 0 else {
            ecrite = instant
            return
        }
        // La durée d'une image à la cadence de l'écran (1/60 s au simulateur ; un iPhone ProMotion varie).
        let duree = max(lien.duration, 1.0 / 120)
        let ecart = instant - precedente
        nombre += 1
        if ecart > duree * 1.5 {
            accrocs += 1
            perdues += max(1, Int((ecart / duree).rounded()) - 1)
            tempsAccroc += (ecart - duree) * 1000
        }
        if instant - ecrite >= 0.25 {
            ecrite = instant
            Mesures.ecrire(["images", String(format: "%.3f", Date().timeIntervalSince1970), String(nombre),
                            String(accrocs), String(perdues), String(format: "%.1f", tempsAccroc)])
        }
    }
}
