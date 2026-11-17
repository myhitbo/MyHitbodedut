import Foundation

// L'historique d'un réglage qui pèse sur le passé (HistoriqueReglage.kt d'Android, 13/11, audit FDONNEES-05).
//
// « Israël ou diaspora » et « Chabbat et Yom Tov » décident des jours exemptés, donc de la série. Jugés avec la
// valeur du moment, ils changeaient le passé après coup : atterrir en Israël faisait des deuxièmes jours de fête
// déjà passés des jours manqués, la série tombait, puis revenait au retour. Chaque changement est donc daté, et
// un jour se juge avec la valeur en vigueur ce jour-là.
//
// Forme gardée : « 2000-01-01=0,2026-11-05=1 » — la date d'effet puis 1 (oui) ou 0 (non), par dates
// croissantes ; la première entrée vaut pour tout ce qui la précède. Vide : le réglage n'a jamais changé, sa
// valeur du moment vaut pour tous les jours. L'export ne la porte pas : un fichier importé date son réglage du
// jour.
//
// Jugé par `Tests/Vecteurs/store.json` (« historique »).

/// L'historique daté d'un réglage booléen.
public enum HistoriqueReglage {

    public struct Entree: Hashable, Sendable {
        public let depuis: JourCivil
        public let valeur: Bool

        public init(depuis: JourCivil, valeur: Bool) {
            self.depuis = depuis
            self.valeur = valeur
        }
    }

    /// La date d'effet de la valeur d'avant le premier changement : avant tout journal.
    public static let origine = JourCivil(annee: 2000, mois: 1, jour: 1)!

    /// Au-delà, les plus anciens changements se fondent dans l'origine.
    public static let max = 200

    /// Les entrées lisibles, par dates croissantes, une par date (la dernière l'emporte) ; le reste est ignoré.
    public static func decoder(_ brut: String?) -> [Entree] {
        guard let brut, !brut.estBlanc else { return [] }
        var parDate: [JourCivil: Bool] = [:]
        for morceau in brut.split(separator: ",", omittingEmptySubsequences: false).map(String.init) {
            let avant = morceau.avantUnites("=").trimmingCharacters(in: .whitespaces)
            guard let date = JourCivil(iso: avant) else { continue }
            // substringAfter('=', "") : rien sans « = ».
            guard let egal = morceau.firstIndex(of: "=") else { continue }
            switch morceau[morceau.index(after: egal)...].trimmingCharacters(in: .whitespaces) {
            case "1": parDate[date] = true
            case "0": parDate[date] = false
            default: break
            }
        }
        return parDate.keys.sorted().map { Entree(depuis: $0, valeur: parDate[$0]!) }
    }

    public static func encoder(_ histoire: [Entree]) -> String {
        histoire.map { "\($0.depuis.iso)=\($0.valeur ? 1 : 0)" }.joined(separator: ",")
    }

    /// La valeur en vigueur le `jour`. Depuis le dernier changement, c'est `actuelle` (le réglage lui-même fait
    /// foi) ; avant, celle de l'entrée en vigueur ce jour-là.
    public static func valeurLe(_ histoire: [Entree], _ jour: JourCivil, actuelle: Bool) -> Bool {
        guard let derniere = histoire.last, jour < derniere.depuis else { return actuelle }
        return (histoire.last { !($0.depuis > jour) } ?? histoire[0]).valeur
    }

    /// L'historique après un changement fait `aujourdhui`, de `ancienne` à `nouvelle` : le passé garde
    /// `ancienne`, le jour même et la suite prennent `nouvelle`. Changer puis revenir le même jour ne laisse rien.
    public static func apresChangement(_ histoire: [Entree], aujourdhui: JourCivil, ancienne: Bool, nouvelle: Bool) -> [Entree] {
        if ancienne == nouvelle { return histoire }
        let base = histoire.isEmpty ? [Entree(depuis: origine, valeur: ancienne)] : histoire
        // Jamais d'entrée à venir : une horloge reculée ne garde pas un changement du futur.
        var avant = base.filter { $0.depuis < aujourdhui }
        if avant.isEmpty { avant = [Entree(depuis: origine, valeur: ancienne)] }
        let suite = avant.last!.valeur == nouvelle ? avant : avant + [Entree(depuis: aujourdhui, valeur: nouvelle)]
        if suite.count <= max { return suite }
        let gardees = Array(suite.suffix(max))
        return [Entree(depuis: origine, valeur: gardees[0].valeur)] + gardees.dropFirst()
    }
}
