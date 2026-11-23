import Foundation
import Observation
import Coeur

// Le verrou du journal (VerrouJournal.kt d'Android, audit du 12/11, revue du 15/11). Le journal ne s'ouvre qu'avec le
// code du téléphone, Face ID ou Touch ID. Pour que ce verrou serve à quelque chose, tout ce qui montre ou emporte le
// texte du journal passe par ici : l'écran du journal (`JournalVerrouille`), la fenêtre de note déjà remplie
// (`JournalNoteModele.verrouillee`), l'export (`ReglagesModele.exportAutorise`), la désactivation du verrou lui-même
// (`basculer`), et les aperçus des accueils des versions (`AccueilVersionModele.verrou` : la dernière note, les
// derniers jours de Sérénité). Les widgets n'en montrent rien, comme sur Android. Sans code sur le téléphone, il n'y a
// rien à demander.
//
// L'appel au système (LocalAuthentication, `.deviceOwnerAuthentication`) est derrière `CodeDuTelephone`, que l'app
// branche (App/Services/CodeDuTelephone.swift) ; `FauxCodeDuTelephone` le remplace dans les tests et les aperçus.

/// Le code du téléphone (le KeyguardManager d'Android) : LocalAuthentication dans l'app.
@MainActor
public protocol CodeDuTelephone: AnyObject {
    /// Le téléphone a un code (`KeyguardManager.isDeviceSecure`) : `canEvaluatePolicy(.deviceOwnerAuthentication)`.
    var ecranProtege: Bool { get }
    /// La demande du code, de Face ID ou de Touch ID (`createConfirmDeviceCredentialIntent`) : vrai s'il est donné,
    /// faux si l'on renonce. `raison` : la phrase de la demande (« Ouvrir le journal »).
    func demander(raison: Libelle) async -> Bool
}

/// Un code de téléphone qui répond ce qu'on lui dit, et compte les demandes : pour les tests et les aperçus.
@MainActor
public final class FauxCodeDuTelephone: CodeDuTelephone {
    public var ecranProtege: Bool
    /// Ce que la prochaine demande répondra.
    public var reponse: Bool
    public private(set) var demandes = 0
    public private(set) var raisons: [Libelle] = []

    public init(ecranProtege: Bool = true, reponse: Bool = true) {
        self.ecranProtege = ecranProtege
        self.reponse = reponse
    }

    public func demander(raison: Libelle) async -> Bool {
        demandes += 1
        raisons.append(raison)
        return reponse
    }
}

/// Le verrou du journal, partagé par toute l'app (`VerrouJournal`, objet d'Android).
@MainActor
@Observable
public final class VerrouJournal {

    /// Le titre de la demande (`journal_verrou_titre`).
    public static let raison = Libelle("journal_verrou_titre")

    private let magasin: Magasin
    private let code: any CodeDuTelephone
    /// Une demande est à l'écran : une seconde ne s'empile pas sur elle.
    public private(set) var demandeEnCours = false

    public init(magasin: Magasin, code: any CodeDuTelephone) {
        self.magasin = magasin
        self.code = code
    }

    /// Le verrou est demandé, et le téléphone a un code pour le tenir (`VerrouJournal.actif`).
    public var actif: Bool {
        magasin.reglages.journalVerrou && code.ecranProtege
    }

    /// Le téléphone a un code (`ecranProtege`).
    public var ecranProtege: Bool {
        code.ecranProtege
    }

    /// `VerrouJournal.exiger` : vrai tout de suite si le verrou n'est pas actif, sinon après le code ; faux si l'on
    /// renonce, ou si une demande est déjà à l'écran.
    public func exiger() async -> Bool {
        guard actif else { return true }
        guard !demandeEnCours else { return false }
        demandeEnCours = true
        let accorde = await code.demander(raison: VerrouJournal.raison)
        demandeEnCours = false
        return accorde
    }

    /// L'interrupteur des réglages (SettingsActivity.renderVerrou). Il montre ce qui protège vraiment (`actif`) :
    /// l'allumer sans code sur le téléphone ne fait rien et rend le message à dire (`journal_verrou_sans_code`) ; le
    /// couper demande d'abord le code, sinon quiconque tient le téléphone déverrouillé l'éteignait avant d'ouvrir le
    /// journal. Rend le message à dire, ou nil.
    @discardableResult
    public func basculer(_ voulu: Bool) async throws -> Libelle? {
        if voulu {
            guard code.ecranProtege else { return Libelle("journal_verrou_sans_code") }
            try await magasin.modifierReglages { $0.setJournalVerrou(true) }
            return nil
        }
        if actif {
            guard await exiger() else { return nil }
        }
        try await magasin.modifierReglages { $0.setJournalVerrou(false) }
        return nil
    }
}

/// L'écran du journal fermé à clé (JournalActivity.verrouiller, onStop, onStart) : rien ne s'y montre avant le code ;
/// il se referme quand l'app part en arrière-plan (onStop hors rotation : iOS ne recrée pas l'écran en tournant), et le
/// code est redemandé au retour. Renoncer ferme l'écran (`finish()`).
@MainActor
@Observable
public final class JournalVerrouille {

    private let verrou: VerrouJournal
    /// Le contenu du journal peut se montrer.
    public private(set) var ouvert: Bool
    /// On a renoncé au code : la vue ferme l'écran.
    public private(set) var refuse = false
    /// Le journal a été caché en passant à l'arrière-plan : le code est redemandé au retour.
    private var aRedemander = false
    private var demandeEnCours = false

    /// Ouvert d'emblée si le verrou n'est pas actif : un téléphone sans code n'a rien à demander.
    public init(verrou: VerrouJournal) {
        self.verrou = verrou
        ouvert = !verrou.actif
    }

    /// L'écran paraît (onCreate → verrouiller) : la demande, s'il est fermé.
    public func apparaitre() async {
        guard !ouvert else { return }
        await demander()
    }

    /// L'app part en arrière-plan (onStop) : le journal ouvert se referme si le verrou est actif.
    public func arrierePlan() {
        guard ouvert, verrou.actif else { return }
        ouvert = false
        aRedemander = true
    }

    /// L'app revient au premier plan (onStart) : le code est redemandé ; si le verrouillage d'écran a été retiré
    /// entre-temps, il n'y a rien à demander et le journal se rouvre.
    public func premierPlan() async {
        guard aRedemander else { return }
        aRedemander = false
        await demander()
    }

    private func demander() async {
        guard !demandeEnCours else { return }
        demandeEnCours = true
        let accorde = await verrou.exiger()
        demandeEnCours = false
        if accorde {
            ouvert = true
        } else {
            refuse = true
        }
    }
}
