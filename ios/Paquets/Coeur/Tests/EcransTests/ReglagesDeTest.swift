import Coeur

/// Pour préparer un test : un réglage posé « depuis toujours ». Sur Android, Store date chaque changement de
/// « Chabbat et Yom Tov » et d'« Israël ou diaspora » (HistoriqueReglage, FDONNEES-05) ; daté de l'origine de
/// l'historique, le réglage vaut pour tous les jours, comme avant l'audit. Les tests qui rejouent la JVM passent
/// le jour qu'il est.
extension Reglages {
    mutating func setShabbatMode(_ value: Bool) {
        setShabbatMode(value, aujourdhui: HistoriqueReglage.origine)
    }

    mutating func setInIsrael(_ value: Bool) {
        setInIsrael(value, aujourdhui: HistoriqueReglage.origine, fuseauTelephone: "UTC")
    }

    /// Le lieu, son jour pris dans son fuseau ; le téléphone dans le même fuseau.
    mutating func setLieuZmanim(_ lieu: Zmanim.Lieu, ville: Ville?, maintenant: Int64) {
        let fuseau = Fuseau(lieu.fuseau) ?? .utc
        setLieuZmanim(lieu, ville: ville, maintenant: maintenant, aujourdhui: fuseau.jour(millis: maintenant),
                      fuseauTelephone: fuseau.identifiant)
    }
}
