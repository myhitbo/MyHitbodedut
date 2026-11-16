/// Le code-barres d'une carte d'embarquement (CarteEmbarquement.kt, 04/11) : le format BCBP de l'IATA
/// (résolution 792), le même pour toutes les compagnies, dans le PDF417, l'Aztec ou le QR de la carte, sur
/// papier, en PDF ou dans le téléphone. On n'en lit que le premier tronçon : départ, arrivée, compagnie,
/// numéro, jour de l'année. Le nom du passager et le numéro de réservation ne sont ni lus ni gardés.
/// Pas les heures : le code ne les porte pas ; elles viennent du texte du billet, ou de la saisie.
///
/// Les positions sont celles de Kotlin, en unités UTF-16. Jugé par `Tests/Vecteurs/vol_suite.json`
/// (tools/vecteurs_ios/VecteursVolSuite.kt), section « cartes ».
public enum CarteEmbarquement {

    public struct Troncon: Sendable, Hashable {
        public var depart: String
        public var arrivee: String
        public var compagnie: String
        public var numero: String
        public var date: JourCivil?

        public init(depart: String, arrivee: String, compagnie: String, numero: String, date: JourCivil?) {
            self.depart = depart
            self.arrivee = arrivee
            self.compagnie = compagnie
            self.numero = numero
            self.date = date
        }
    }

    private static let aeroport = ExpressionReguliere("[A-Z]{3}")
    private static let compagnie = ExpressionReguliere("[A-Z0-9]{2,3}")
    private static let vol = ExpressionReguliere("[0-9]{1,4}[A-Z]?")

    /// « M1DUPONT/JEAN        EABC123 LYSTLVLY 0382 316Y012A0001 100 » → LYS, TLV, LY, LY382, le 316e jour,
    /// l'année la plus proche d'aujourd'hui.
    public static func lire(_ code: String, _ aujourdhui: JourCivil) -> Troncon? {
        let unites = Array(code.utf16)
        if unites.count < 47 || unites[0] != 0x4D || chiffre(unites[1]) == nil { return nil }
        // Un champ qui coupe une paire de substitution garde chez Kotlin la moitié seule, qu'aucun motif n'accepte.
        guard let de = champ(unites, 30, 33), let vers = champ(unites, 33, 36), let cie = champ(unites, 36, 39),
              let brut = champ(unites, 39, 44) else { return nil }
        let numero = sansZerosDeTete(brut)
        let jour = champ(unites, 44, 47).flatMap { entierKotlin($0) }
        if !aeroport.couvre(de) || !aeroport.couvre(vers) { return nil }
        if !compagnie.couvre(cie) || !vol.couvre(numero) { return nil }
        var date: JourCivil?
        if let jour, jour >= 1 && jour <= 366 { date = quantieme(jour, aujourdhui) }
        return Troncon(depart: de, arrivee: vers, compagnie: cie, numero: cie + numero, date: date)
    }

    /// Le jour de l'année le plus proche d'aujourd'hui : l'an dernier, cette année ou l'an prochain
    /// (`minByOrNull` : le premier des plus proches).
    private static func quantieme(_ n: Int, _ aujourdhui: JourCivil) -> JourCivil? {
        var meilleur: JourCivil?
        var ecart = 0
        for an in [aujourdhui.annee - 1, aujourdhui.annee, aujourdhui.annee + 1] {
            guard let d = jourDeLAnnee(an, n) else { continue }
            let e = abs(d.jourJulien - aujourdhui.jourJulien)
            if meilleur == nil || e < ecart {
                meilleur = d
                ecart = e
            }
        }
        return meilleur
    }

    /// `LocalDate.ofYearDay` : nil pour le 366e jour d'une année commune.
    private static func jourDeLAnnee(_ an: Int, _ n: Int) -> JourCivil? {
        let longueur = JourCivil.estBissextile(an) ? 366 : 365
        guard n >= 1 && n <= longueur, let premier = JourCivil(annee: an, mois: 1, jour: 1) else { return nil }
        return premier.plus(jours: n - 1)
    }

    /// `substring(debut, fin).trim()` de Kotlin ; nil si le champ coupe une paire de substitution (`Unites.texte`
    /// en retirerait la moitié seule, que Kotlin garde : ni `matches` ni `toIntOrNull` ne l'acceptent).
    private static func champ(_ unites: [UInt16], _ debut: Int, _ fin: Int) -> String? {
        if UTF16.isTrailSurrogate(unites[debut]) || UTF16.isLeadSurrogate(unites[fin - 1]) { return nil }
        return Unites.texte(unites[debut..<fin]).rogne
    }

    /// `trimStart('0')`.
    private static func sansZerosDeTete(_ s: String) -> String {
        let unites = Array(s.utf16)
        var i = 0
        while i < unites.count && unites[i] == 0x30 { i += 1 }
        return Unites.texte(unites[i...])
    }

    /// `Character.digit(c, 10)` de Java : la valeur d'un chiffre décimal d'Unicode (catégorie Nd), nil sinon.
    /// `Char.isDigit()` de Kotlin en est le cas non nul. Une moitié de paire de substitution n'est pas un chiffre.
    private static func chiffre(_ u: UInt16) -> Int? {
        if u >= 0x30 && u <= 0x39 { return Int(u - 0x30) }
        guard let scalaire = Unicode.Scalar(u), scalaire.properties.numericType == .decimal,
              let valeur = scalaire.properties.numericValue else { return nil }
        return Int(valeur)
    }

    /// `toIntOrNull()` de Kotlin : un signe facultatif, puis des chiffres décimaux d'Unicode ; nil hors des 32 bits.
    private static func entierKotlin(_ texte: String) -> Int? {
        let unites = Array(texte.utf16)
        guard let premiere = unites.first else { return nil }
        var debut = 0
        var negatif = false
        if premiere < 0x30 {
            if unites.count == 1 { return nil }
            if premiere == 0x2D {
                negatif = true
            } else if premiere != 0x2B {
                return nil
            }
            debut = 1
        }
        var valeur: Int64 = 0
        for u in unites[debut...] {
            guard let c = chiffre(u) else { return nil }
            valeur = valeur * 10 + Int64(c)
            if valeur > 2_147_483_648 { return nil }
        }
        if negatif { return Int(-valeur) }
        return valeur > 2_147_483_647 ? nil : Int(valeur)
    }
}
