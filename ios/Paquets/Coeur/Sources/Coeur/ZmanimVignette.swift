import Foundation

/// Ce qui se calcule dans les trois vignettes des zmanim (ZmanimVignette.kt, demande du 28/10 : petite,
/// moyenne et grande, sur un même fond de nuit verte), sans les vues : la journée que montre la grande,
/// où commence la fenêtre de la prière du moment et sa part écoulée (la jauge), le jour hébreu affiché,
/// qui change à la sortie des étoiles du lieu comme le jour hébreu (02/11), et le prochain instant où
/// elles changent. Les vues (RemoteViews), la lecture des réglages, la fête ou la paracha en tête et la
/// programmation de l'alarme restent à l'app. Jugé par `Tests/Vecteurs/vignettes.json`
/// (tools/vecteurs_ios/VecteursVignettes.kt).
public enum ZmanimVignette {

    /// La journée telle que la grande vignette la montre, dans l'ordre.
    public static let journee = ["alot", "netz", "szks_gra", "szt_gra", "chatsot", "minha_gedola", "plag", "chkia", "tset"]

    /// Au plus tard, la vignette se redessine toutes les dix minutes : le temps qui reste et la jauge.
    private static let pasMaxMinutes = 10

    /// Où commence la fenêtre de la prière du moment, pour la jauge : l'aube, la fin de Cha'harit, la chki'a.
    public static func debut(priere: String, horaires: [String: DateHeureZonee]) -> DateHeureZonee? {
        switch priere {
        case "chaharit": horaires["alot"]
        case "minha": horaires["szt_gra"]
        default: horaires["chkia"]
        }
    }

    /// La date civile dont la vignette montre le jour hébreu : celle du lieu, ou le lendemain une fois la
    /// sortie des étoiles passée, le jour hébreu commençant le soir (02/11). Sans lieu, pas de tsét connu :
    /// la date change à minuit.
    public static func jourHebreuAffiche(maintenant: DateHeureZonee, tset: DateHeureZonee?) -> JourCivil {
        if let tset, !(maintenant < tset) { return maintenant.jour.plus(jours: 1) }
        return maintenant.jour
    }

    /// La part écoulée de la fenêtre, de 0 à 1000 ; 0 sans bornes. Comme sur Android, en secondes pleines
    /// (`Duration.seconds`, arrondies vers le bas) puis en virgule flottante : une fenêtre de moins d'une
    /// seconde divise par zéro, et `toInt()` borne l'infini et rend 0 pour NaN.
    public static func ecoule(debut: DateHeureZonee?, fin: DateHeureZonee?, maintenant: DateHeureZonee) -> Int {
        guard let debut, let fin, fin > debut else { return 0 }
        let total = Double(secondes(de: debut, jusqua: fin))
        let part = Kotlin.versInt(Double(secondes(de: debut, jusqua: maintenant)) / total * 1000)
        return min(max(part, 0), 1000)
    }

    /// Le prochain instant où la vignette change (02/11) : un zman d'aujourd'hui ou de demain (la fin de
    /// Cha'harit, la chki'a, le milieu de la nuit…), minuit du lieu (la date en tête), minuit du téléphone,
    /// et au plus tard dans dix minutes. Avant, seule la mise à jour d'Android toutes les demi-heures la
    /// redessinait : « Cha'harit jusqu'à 9:12 » restait affiché à 9:40. À instant égal, le premier dans cet
    /// ordre l'emporte, avec son fuseau (`minByOrNull`).
    public static func prochainChangement(horaires: [DateHeureZonee?], maintenant: DateHeureZonee,
                                          minuitTelephone: DateHeureZonee? = nil) -> DateHeureZonee {
        // `toLocalDate().plusDays(1).atStartOfDay(zone)` : un minuit qui manque devient la fin du trou.
        let minuitLieu = DateHeureZonee(DateHeure(maintenant.jour.plus(jours: 1)), fuseau: maintenant.fuseau)
        let dansDixMinutes = maintenant.plus(minutes: pasMaxMinutes)
        var candidats = horaires.compactMap { $0 }
        candidats.append(minuitLieu)
        if let minuitTelephone { candidats.append(minuitTelephone) }
        candidats.append(dansDixMinutes)
        var retenu: DateHeureZonee?
        for candidat in candidats where candidat > maintenant {
            if let deja = retenu, !(candidat.millis < deja.millis) { continue }
            retenu = candidat
        }
        return retenu ?? dansDixMinutes
    }

    /// `Duration.between(debut, fin).seconds` : des secondes pleines, arrondies vers le bas.
    private static func secondes(de debut: DateHeureZonee, jusqua fin: DateHeureZonee) -> Int {
        Kotlin.floorDiv(Int(fin.millis &- debut.millis), 1000)
    }
}
