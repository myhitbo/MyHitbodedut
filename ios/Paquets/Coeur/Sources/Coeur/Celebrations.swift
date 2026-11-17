// La fête d'un palier ou d'un trophée (Confettis.kt, l'objet Celebrations ; demande du 11/10) : ce qui est
// neuf depuis la dernière fois, paliers et trophées. L'écran et la notification tiennent chacun leur
// liste de ce qu'ils ont déjà fêté ; le tout premier passage ne fête rien (une installation qui a déjà de
// l'historique ne reçoit pas une pluie de vieux trophées).
//
// Sur Android, Celebrations lit la pratique dans Store et y écrit ce qu'il faut retenir ; ici la règle
// reçoit le bilan des paliers et la pratique des trophées, et rend l'état à retenir. La phrase de la fête
// est un `Libelle`, aux clés et aux arguments de TropheesVue et PaliersVue (PaliersActivity.kt) et de
// Store.formatDuration. Restent à l'app : les confettis, la fiche du trophée, les étincelles de l'accueil
// (Celebrations.ecran), l'image et l'envoi de la notification (Confettis.notifier).
//
// Jugé par `Tests/Vecteurs/celebrations.json` (tools/vecteurs_ios/VecteursCelebrations.kt).

/// Ce qui est neuf depuis la dernière fois, et ce qu'il faut en retenir.
public enum Celebrations {

    /// Le résultat de `neuf` : `icone` et `message` vides quand rien n'est neuf ; `marques` et `trophees`,
    /// l'état à retenir comme déjà fêté.
    public struct Neuf: Hashable, Sendable {
        /// L'icône au trait de la famille (`Trophees.Famille.icone`) pour un trophée, « 🎉 » pour un palier,
        /// "" quand rien n'est neuf.
        public let icone: String
        /// La phrase de la fête ; nil quand rien n'est neuf (le message vide d'Android).
        public let message: Libelle?
        /// Les marques des paliers atteints (`Paliers.marques`).
        public let marques: Set<String>
        /// Les clés des trophées fêtés, à retenir : celles déjà vues et celles des niveaux gagnés, l'union
        /// (`Trophees.vusAvec`, FDONNEES-10) : un niveau perdu puis regagné n'est pas refêté.
        public let trophees: Set<String>
        /// Les trophées gagnés à cet instant (le grade des étincelles) ; l'union retenue garde aussi ceux perdus.
        public let compte: Int

        public init(icone: String, message: Libelle?, marques: Set<String>, trophees: Set<String>, compte: Int) {
            self.icone = icone
            self.message = message
            self.marques = marques
            self.trophees = trophees
            self.compte = compte
        }
    }

    /// La notification d'après séance (Confettis.notifier) : son titre, son texte, et l'icône de son image.
    public struct Annonce: Hashable, Sendable {
        public let titre: Libelle
        public let texte: Libelle
        public let icone: String

        public init(titre: Libelle, texte: Libelle, icone: String) {
            self.titre = titre
            self.texte = texte
            self.icone = icone
        }
    }

    /// Un trophée neuf d'abord, sinon le plus haut palier neuf (à égalité de rang, le premier dans l'ordre
    /// de `Paliers.etats`, comme `maxByOrNull`). `paliersVus` nil : les paliers n'ont jamais été regardés,
    /// aucun n'est fêté ; `tropheesVus` nil ou d'avant les niveaux : aucun trophée n'est fêté
    /// (`Trophees.nouveaux`).
    public static func neuf(_ bilan: Paliers.Bilan, _ pratique: Trophees.Pratique, paliersVus: Set<String>?,
                            tropheesVus: Set<String>?) -> Neuf {
        let etats = Paliers.etats(bilan)
        let gagnes = Trophees.gagnes(pratique)
        let trophee = Trophees.nouveaux(gagnes, vus: tropheesVus).first
        var palier: Paliers.Etat?
        if let vus = paliersVus {
            for e in Paliers.nouveaux(etats, bilan, vus: vus) {
                if let meilleur = palier, meilleur.rang >= e.rang { continue }
                palier = e
            }
        }
        let icone: String
        let message: Libelle?
        if let trophee {
            icone = trophee.famille.icone
            // Sans métal (13/11, FDONNEES-06) : celui de la famille n'est plus celui que l'écran montre.
            message = Libelle("trophee_niveau_gagne", .libelle(nomTrophee(trophee.famille)), .entier(trophee.rang))
        } else if let palier {
            icone = "\u{1F389}"
            message = Libelle("palier_nouveau", .libelle(libellePalier(palier.piste, bilan)),
                              .libelle(valeurPalier(palier.piste, palier.atteint)))
        } else {
            icone = ""
            message = nil
        }
        // L'union, jamais le remplacement : un trophée qui disparaît puis revient (note effacée, interrupteur
        // rallumé) n'est pas fêté une seconde fois (FDONNEES-10).
        return Neuf(icone: icone, message: message, marques: Paliers.marques(etats, bilan),
                    trophees: Trophees.vusAvec(tropheesVus, gagnes), compte: gagnes.count)
    }

    /// Ce qui est neuf est su sans notification (ajout de temps, application ouverte ; 16/10) : rien n'est
    /// annoncé, l'app retient `marques` comme paliers notifiés et `trophees` comme trophées notifiés.
    public static func marquerNotifies(_ bilan: Paliers.Bilan, _ pratique: Trophees.Pratique,
                                       paliersNotifies: Set<String>?, tropheesNotifies: Set<String>?) -> Neuf {
        neuf(bilan, pratique, paliersVus: paliersNotifies, tropheesVus: tropheesNotifies)
    }

    /// Après une séance enregistrée : la notification, même l'application fermée, s'il y a du neuf (nil
    /// sinon), titrée « celebration_titre » ; puis, comme `marquerNotifies`, l'état à retenir comme notifié.
    public static func notification(_ bilan: Paliers.Bilan, _ pratique: Trophees.Pratique,
                                    paliersNotifies: Set<String>?,
                                    tropheesNotifies: Set<String>?) -> (annonce: Annonce?, neuf: Neuf) {
        let r = neuf(bilan, pratique, paliersVus: paliersNotifies, tropheesVus: tropheesNotifies)
        guard let message = r.message else { return (nil, r) }
        return (Annonce(titre: Libelle("celebration_titre"), texte: message, icone: r.icone), r)
    }

    // MARK: Les libellés (TropheesVue et PaliersVue, PaliersActivity.kt)

    /// TropheesVue.nom : le nom de la famille.
    static func nomTrophee(_ f: Trophees.Famille) -> Libelle {
        switch f {
        case .premierPas: return Libelle("trophee_premier_pas")
        case .seanceLongue: return Libelle("trophee_seance_longue")
        case .jours: return Libelle("trophee_jours")
        case .serie: return Libelle("trophee_serie")
        case .heures: return Libelle("trophee_heures")
        case .semaines: return Libelle("trophee_semaines")
        case .erevChabbat: return Libelle("trophee_erev_chabbat")
        case .retour: return Libelle("trophee_retour")
        case .plume: return Libelle("trophee_plume")
        case .tikkun: return Libelle("trophee_tikkun")
        case .tikkunSerie: return Libelle("trophee_tikkun_serie")
        }
    }

    /// TropheesVue.metal : le métal de la médaille.
    static func metalTrophee(_ m: Trophees.Metal) -> Libelle {
        switch m {
        case .bronze: return Libelle("metal_bronze")
        case .argent: return Libelle("metal_argent")
        case .or: return Libelle("metal_or")
        case .platine: return Libelle("metal_platine")
        }
    }

    /// PaliersVue.libelle : le nom de la piste ; celui du mois porte le mois hébreu d'aujourd'hui (hors
    /// d'Israël, comme sur Android), isolé (FSI … PDI) pour que le nom hébreu ne renverse pas la phrase.
    static func libellePalier(_ piste: Paliers.Piste, _ bilan: Paliers.Bilan) -> Libelle {
        switch piste {
        case .serie: return Libelle("palier_serie")
        case .jour: return Libelle("palier_jour")
        case .semaine: return Libelle("palier_semaine")
        case .mois:
            let mois = CalendrierJuif.jour(bilan.aujourdhui, enIsrael: false).moisEtAnnee
            return Libelle("palier_mois", .texte("\u{2068}" + mois + "\u{2069}"))
        case .cumul: return Libelle("palier_cumul")
        case .jours: return Libelle("palier_jours")
        }
    }

    /// PaliersVue.valeur : des jours pour la série et les jours de pratique, une durée pour le reste.
    static func valeurPalier(_ piste: Paliers.Piste, _ v: Int) -> Libelle {
        switch piste {
        case .serie, .jours: return Libelle.pluriel("palier_n_jours", quantite: v, .entier(v))
        case .jour, .semaine, .mois, .cumul: return duree(v)
        }
    }

    /// Store.formatDuration : « 45 min », « 2 h », « 1 h 05 ». La division et le reste tronquent vers zéro,
    /// en Swift comme en Kotlin.
    private static func duree(_ minutes: Int) -> Libelle {
        if minutes < 60 { return Libelle("duration_minutes", .entier(minutes)) }
        if minutes % 60 == 0 { return Libelle("duration_hours", .entier(minutes / 60)) }
        return Libelle("duration_hours_minutes", .entier(minutes / 60), .entier(minutes % 60))
    }
}
