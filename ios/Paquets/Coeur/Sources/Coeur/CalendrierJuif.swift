import Foundation
import KosherSwift
import Synchronization

/// Le jour hébraïque et ce qu'il change aux prières (CalendrierJuif.kt), hors ligne, par KosherSwift
/// 1.10.11 : JewishCalendar pour la date et les fêtes, TefilaRules pour les ajouts, HebrewDateFormatter
/// pour les libellés. Aucune règle de la bibliothèque n'est récrite ici ; ce fichier ne fait que les
/// réunir, comme sur Android. Le juge : les 3 896 jours de `web/test/vecteurs_kosherjava.json`,
/// produits par le code Android lui-même.
///
/// Les mois sont rendus dans la numérotation de KosherJava (NISSAN = 1 … ELUL = 6, TICHREI = 7 …
/// ADAR = 12, ADAR_II = 13), celle d'Android, du site et des vecteurs. KosherSwift, lui, lit le mois
/// dans le calendrier hébreu de Foundation (TICHREI = 1, l'Adar d'une année simple = 7).
public enum CalendrierJuif {

    /// Les mois, numérotés comme JewishDate de KosherJava.
    public enum Mois {
        public static let nissan = 1, iyar = 2, sivan = 3, tamouz = 4, av = 5, eloul = 6
        public static let tichri = 7, hechvan = 8, kislev = 9, tevet = 10, chevat = 11, adar = 12, adarII = 13
    }

    /// Les clés de condition, communes à Android, au web et aux annotations du siddour.
    public enum C {
        public static let yaaleVeyavo = "yaale_veyavo"
        public static let rochHodech = "roch_hodech"
        public static let pessah = "pessah"
        public static let soukkot = "soukkot"
        public static let chavouot = "chavouot"
        public static let rochHachana = "roch_hachana"
        public static let cheminiAtseret = "chemini_atseret"
        public static let kippour = "kippour"
        public static let alHanissim = "al_hanissim"
        public static let hanouka = "hanouka"
        public static let pourim = "pourim"
        public static let machivHarouah = "machiv_harouah"
        public static let moridHatal = "morid_hatal"
        public static let talOumatar = "tal_oumatar"
        public static let berakha = "berakha"
        public static let hallel = "hallel"
        public static let hallelComplet = "hallel_complet"
        public static let tahanounChaharit = "tahanoun_chaharit"
        public static let tahanounMinha = "tahanoun_minha"
        public static let lundiJeudi = "lundi_jeudi"
        public static let asseretYemeiTechouva = "asseret_yemei_techouva"
        public static let jeune = "jeune"
        public static let tichaBeav = "ticha_beav"
        public static let chabbat = "chabbat"
        public static let motsaeChabbat = "motsae_chabbat"
        public static let omer = "omer"
        /// Du 22 Tichri à la fin du mois : Ta'hanoun selon la coutume (SiddurJour.conditionsPour).
        public static let finTichri = "fin_tichri"

        /// Les conditions des vecteurs, dans leur ordre.
        public static let toutes = [
            yaaleVeyavo, rochHodech, pessah, soukkot, chavouot, rochHachana, cheminiAtseret, kippour, alHanissim, hanouka,
            pourim, machivHarouah, moridHatal, talOumatar, berakha, hallel, hallelComplet,
            tahanounChaharit, tahanounMinha, lundiJeudi, asseretYemeiTechouva,
            jeune, tichaBeav, chabbat, motsaeChabbat, omer, finTichri,
        ]

        // Les conditions déduites, hors des vecteurs KosherJava (CalendrierJuif.C.DERIVEES).
        public static let avinouMalkenou = "avinou_malkenou"
        public static let kriatHatorah = "kriat_hatorah"
        /// Le psaume du jour : « jour_1 » le dimanche … « jour_6 » le vendredi.
        public static let joursSemaine = (1...6).map { "jour_\($0)" }
        public static let tsomGuedaliaTevet = "tsom_guedalia_tevet"
        public static let lendemainKippour = "lendemain_kippour"
        public static let estherPourim = "esther_pourim"
        public static let chivaAssarTamouz = "chiva_assar_tamouz"
        /// 22 Tichri et 15 Nissan : les deux formules valent ce jour-là (O.H. 114:1).
        public static let basculePluie = "bascule_pluie"
        /// La veille de Kippour un vendredi : Avinou malkénou à Cha'harit (Rema O.H. 604:2).
        public static let erevKippourVendredi = "erev_kippour_vendredi"
        public static let lamnatseah = "lamnatseah"
        public static let ledavid = "ledavid"
        public static let techouvaHochaana = "techouva_hochaana"
        public static let yomTov = "yom_tov"
        public static let moed = "moed"
        public static let chabbatRochHodech = "chabbat_roch_hodech"
        public static let yomTovChabbat = "yom_tov_chabbat"
        public static let rochHachanaChabbat = "roch_hachana_chabbat"
        public static let motsaeChabbatYT = "motsae_chabbat_yt"
        /// La maison endeuillée et la bénédiction de qui a oublié : jamais du jour, repliées.
        public static let beitAvel = "beit_avel"
        public static let oubli = "oubli"
        public static let chevaBerakhot = "cheva_berakhot"
        public static let zimun = "zimun"
        public static let facultatif = "facultatif"
        /// Roch 'Hodech d'une année embolismique ; avant Nissan (« וּלְכַפָּרַת פָּשַׁע »).
        public static let embolismique = "embolismique"
        public static let embolismiqueAvantNissan = "embolismique_avant_nissan"
        /// Ce qui ne se dit qu'avec un minyan : jamais du jour, replié.
        public static let minyan = "minyan"

        public static let derivees = [avinouMalkenou, kriatHatorah] + joursSemaine + [
            tsomGuedaliaTevet, lendemainKippour, estherPourim, chivaAssarTamouz, basculePluie, erevKippourVendredi,
            lamnatseah, ledavid, techouvaHochaana, yomTov, moed, chabbatRochHodech, yomTovChabbat, rochHachanaChabbat,
            motsaeChabbatYT, beitAvel, oubli, minyan, chevaBerakhot, zimun, facultatif, embolismique, embolismiqueAvantNissan,
        ]
    }

    /// Les fêtes par l'index de `getYomTovIndex()` ; la clé donne le libellé « fete_<clé> ».
    public static let fetes: [Int: String] = [
        JewishCalendar.EREV_PESACH: "erev_pessah",
        JewishCalendar.PESACH: "pessah",
        JewishCalendar.CHOL_HAMOED_PESACH: "hol_hamoed_pessah",
        JewishCalendar.PESACH_SHENI: "pessah_cheni",
        JewishCalendar.EREV_SHAVUOS: "erev_chavouot",
        JewishCalendar.SHAVUOS: "chavouot",
        JewishCalendar.SEVENTEEN_OF_TAMMUZ: "tamouz_17",
        JewishCalendar.TISHA_BEAV: "ticha_beav",
        JewishCalendar.TU_BEAV: "tou_beav",
        JewishCalendar.EREV_ROSH_HASHANA: "erev_roch_hachana",
        JewishCalendar.ROSH_HASHANA: "roch_hachana",
        JewishCalendar.FAST_OF_GEDALYAH: "jeune_guedalia",
        JewishCalendar.EREV_YOM_KIPPUR: "erev_yom_kippour",
        JewishCalendar.YOM_KIPPUR: "yom_kippour",
        JewishCalendar.EREV_SUCCOS: "erev_soukkot",
        JewishCalendar.SUCCOS: "soukkot",
        JewishCalendar.CHOL_HAMOED_SUCCOS: "hol_hamoed_soukkot",
        JewishCalendar.HOSHANA_RABBA: "hochaana_rabba",
        JewishCalendar.SHEMINI_ATZERES: "chemini_atseret",
        JewishCalendar.SIMCHAS_TORAH: "simhat_torah",
        JewishCalendar.CHANUKAH: "hanouka",
        JewishCalendar.TENTH_OF_TEVES: "tevet_10",
        JewishCalendar.TU_BESHVAT: "tou_bichvat",
        JewishCalendar.FAST_OF_ESTHER: "jeune_esther",
        JewishCalendar.PURIM: "pourim",
        JewishCalendar.SHUSHAN_PURIM: "chouchan_pourim",
        JewishCalendar.PURIM_KATAN: "pourim_katan",
        JewishCalendar.ROSH_CHODESH: "roch_hodech",
        JewishCalendar.YOM_HASHOAH: "yom_hachoah",
        JewishCalendar.YOM_HAZIKARON: "yom_hazikaron",
        JewishCalendar.YOM_HAATZMAUT: "yom_haatsmaout",
        JewishCalendar.YOM_YERUSHALAYIM: "yom_yerouchalayim",
        JewishCalendar.LAG_BAOMER: "lag_baomer",
        JewishCalendar.SHUSHAN_PURIM_KATAN: "chouchan_pourim_katan",
        JewishCalendar.ISRU_CHAG: "isrou_hag",
    ]

    public struct Jour: Sendable, Equatable {
        public let date: JourCivil
        public let enIsrael: Bool
        /// « כ״ט תשרי תשפ״ז ».
        public let dateHebraique: String
        /// Le quantième en lettres, « כ״ט », pour la grille du calendrier.
        public let jourEnLettres: String
        public let jourHebreu: Int
        /// Le mois hébreu, numéroté comme KosherJava (`Mois`).
        public let moisHebreu: Int
        public let anneeHebraique: Int
        /// « תשרי תשפ״ז » : le titre d'un mois du calendrier.
        public let moisEtAnnee: String
        /// Clés « fete_<clé> » du jour, sans doublon.
        public let fetes: [String]
        /// Le jour de l'omer compté le soir qui ouvre ce jour hébreu, 0 hors omer.
        public let omer: Int
        /// La paracha lue ce Chabbat, en hébreu ; nil en semaine ou un Chabbat de fête.
        public let paracha: String?
        /// Chabbat ou Yom Tov : jour où le travail est interdit (isAssurBemelacha).
        public let chome: Bool
        public let conditions: Set<String>
    }

    /// Jérusalem, ville murée depuis Josué : Pourim y est le 15 Adar (Chouchan Pourim).
    public static let jerusalemGeonames: Int64 = 281_184

    /// Une position dans Jérusalem : à 10 km au plus de la Vieille Ville (31,7767 N ; 35,2345 E),
    /// hors d'Abou Dis et Ma'alé Adoumim (est de 35,258 E), de Bethléem et Beit Jala (sud de
    /// 31,72 N) et de Mevasseret (ouest de 35,165 E au nord de 31,785 N). Le rayon est un choix de
    /// l'application, pas une limite halakhique.
    public static func aJerusalem(latitude: Double, longitude: Double) -> Bool {
        if longitude > 35.258 || latitude < 31.72 || (longitude < 35.165 && latitude > 31.785) { return false }
        let r = 6371.0, radian = Double.pi / 180
        let dLat = (latitude - 31.7767) * radian, dLon = (longitude - 35.2345) * radian
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(31.7767 * radian) * cos(latitude * radian) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(a.squareRoot()) <= 10.0
    }

    /// `mukafChoma` : une ville murée depuis Josué, où Pourim et Al hanissim sont le 15 Adar.
    public static func jour(_ date: JourCivil, enIsrael: Bool, mukafChoma: Bool = false) -> Jour {
        verrou.withLock { _ in calculer(date, enIsrael: enIsrael, mukafChoma: mukafChoma) }
    }

    /// Le jour hébreu dont relève une prière dite à `heure` le jour civil `date`. Arvit et le Chema
    /// du coucher, dès midi, relèvent du lendemain ; les autres textes (bénédictions du repas,
    /// Havdala…) passent au lendemain après la sortie des étoiles du lieu (`apresSortie`) ; Min'ha
    /// garde le jour civil.
    public static func jourDeLaPriere(_ texte: String, date: JourCivil, heure: Int, apresSortie: Bool = false) -> JourCivil {
        switch texte {
        case "arvit", "chema_coucher": heure >= 12 ? date.plus(jours: 1) : date
        case "minha": date
        default: apresSortie ? date.plus(jours: 1) : date
        }
    }

    // MARK: KosherSwift

    private static let verrou = Mutex(())

    /// Les noms de Pourim dans une ville murée (libellés « fete_<clé> »).
    private static let muree = ["pourim": "pourim_ailleurs", "chouchan_pourim": "pourim_jerusalem"]

    /// Le jour civil à midi UTC, lu en UTC : aucun fuseau ne peut le déplacer (comme Holidays).
    private static func calendrier(_ date: JourCivil, enIsrael: Bool, modernes: Bool, mukafChoma: Bool = false) -> JewishCalendar {
        let utc = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let midi = Date(timeIntervalSince1970: Double(date.jourJulien - 2_440_588) * 86_400 + 43_200)
        let c = JewishCalendar(workingDate: midi, timezone: utc, inIsrael: enIsrael, useModernHolidays: modernes)
        c.isMukafChoma = mukafChoma
        return c
    }

    /// Le mois de KosherSwift (Foundation) dans la numérotation de KosherJava.
    static func moisKosherJava(_ moisFoundation: Int, embolismique: Bool) -> Int {
        switch moisFoundation {
        case 8...13: moisFoundation - 7                    // Nissan … Eloul
        case 1...5: moisFoundation + 6                     // Tichri … Chevat
        case 6: Mois.adar                                  // Adar I, année embolismique
        default: embolismique ? Mois.adarII : Mois.adar   // 7 : Adar II, ou l'Adar d'une année simple
        }
    }

    // swiftlint:disable:next function_body_length
    private static func calculer(_ date: JourCivil, enIsrael: Bool, mukafChoma: Bool) -> Jour {
        // Deux calendriers : les fêtes modernes s'affichent, mais n'entrent pas dans les règles de
        // prière, où leur coutume varie.
        let regles = calendrier(date, enIsrael: enIsrael, modernes: false, mukafChoma: mukafChoma)
        let affiche = calendrier(date, enIsrael: enIsrael, modernes: true, mukafChoma: mukafChoma)
        let tefila = TefilaRules()
        let semaine = date.jourDeSemaine  // 1 = dimanche … 7 = samedi
        let samedi = semaine == 7, dimanche = semaine == 1, lundiOuJeudi = semaine == 2 || semaine == 5

        let embolismique = regles.isJewishLeapYear()
        let mois = moisKosherJava(regles.getJewishMonth(), embolismique: embolismique)
        let quantieme = regles.getJewishDayOfMonth()
        let index = regles.getYomTovIndex()
        let roshChodesh = regles.isRoshChodesh()

        var c = Set<String>()
        if tefila.isYaalehVeyavoRecited(jewishCalendar: regles) { c.insert(C.yaaleVeyavo) }
        if roshChodesh { c.insert(C.rochHodech) }
        if regles.isPesach() { c.insert(C.pessah) }
        if regles.isSuccos() { c.insert(C.soukkot) }
        // Les variantes de Ya'alé véyavo du Birkat hamazone, une par fête.
        if regles.isShavuos() { c.insert(C.chavouot) }
        if regles.isRoshHashana() { c.insert(C.rochHachana) }
        if regles.isShminiAtzeres() || regles.isSimchasTorah() { c.insert(C.cheminiAtseret) }
        if regles.isYomKippur() { c.insert(C.kippour) }
        if tefila.isAlHanissimRecited(jewishCalendar: regles) { c.insert(C.alHanissim) }
        if regles.isChanukah() { c.insert(C.hanouka) }
        if regles.isPurim() { c.insert(C.pourim) }
        if tefila.isMashivHaruachRecited(jewishCalendar: regles) { c.insert(C.machivHarouah) }
        if tefila.isMoridHatalRecited(jewishCalendar: regles) { c.insert(C.moridHatal) }
        if tefila.isVeseinTalUmatarRecited(jewishCalendar: regles) { c.insert(C.talOumatar) }
        if tefila.isVeseinBerachaRecited(jewishCalendar: regles) { c.insert(C.berakha) }
        if tefila.isHallelRecited(jewishCalendar: regles) { c.insert(C.hallel) }
        if tefila.isHallelShalemRecited(jewishCalendar: regles) { c.insert(C.hallelComplet) }
        // La veille de Roch Hachana, pas de Ta'hanoun à la prière (O.H. 581:3), que TefilaRules fait dire.
        let tahanoun = tefila.isTachanunRecitedShacharis(jewishCalendar: regles) && index != JewishCalendar.EREV_ROSH_HASHANA
        if tahanoun { c.insert(C.tahanounChaharit) }
        if tefila.isTachanunRecitedMincha(jewishCalendar: regles) { c.insert(C.tahanounMinha) }
        // « לשני וחמישי » : les jours sans Ta'hanoun, la section ne se dit pas non plus.
        if tahanoun && lundiOuJeudi { c.insert(C.lundiJeudi) }
        if regles.isAseresYemeiTeshuva() { c.insert(C.asseretYemeiTechouva) }
        if regles.isTaanis() && !regles.isYomKippur() { c.insert(C.jeune) }
        if regles.isTishaBav() { c.insert(C.tichaBeav) }
        if samedi { c.insert(C.chabbat) }
        if dimanche { c.insert(C.motsaeChabbat) }
        if regles.getDayOfOmer() > 0 { c.insert(C.omer) }
        if mois == Mois.tichri && quantieme >= 22 { c.insert(C.finTichri) }
        // La lecture de la Torah à Cha'harit : lundi et jeudi, Chabbat et fêtes, Roch 'Hodech, 'Hol
        // hamoed, 'Hanouka, Pourim, jeûnes publics (9 Av compris).
        let lecture = [C.chabbat, C.rochHodech, C.pessah, C.soukkot, C.chavouot, C.rochHachana, C.kippour,
                       C.cheminiAtseret, C.hanouka, C.pourim, C.jeune, C.tichaBeav]
        if lundiOuJeudi || lecture.contains(where: { c.contains($0) }) { c.insert(C.kriatHatorah) }
        // Le psaume du jour et les jours qui en ajoutent un.
        if !samedi { c.insert("jour_\(semaine)") }
        if index == JewishCalendar.FAST_OF_GEDALYAH || index == JewishCalendar.TENTH_OF_TEVES { c.insert(C.tsomGuedaliaTevet) }
        if mois == Mois.tichri && quantieme == 11 { c.insert(C.lendemainKippour) }
        if index == JewishCalendar.FAST_OF_ESTHER || c.contains(C.pourim) { c.insert(C.estherPourim) }
        if index == JewishCalendar.SEVENTEEN_OF_TAMMUZ { c.insert(C.chivaAssarTamouz) }
        if (mois == Mois.tichri && quantieme == 22) || (mois == Mois.nissan && quantieme == 15) { c.insert(C.basculePluie) }
        if mois == Mois.tichri && quantieme == 9 && semaine == 6 { c.insert(C.erevKippourVendredi) }
        // Relevé du 19/10 : למנצח, « לדוד ה׳ אורי », les dix jours et Hochaana Rabba, fêtes et Chabbat.
        let adar1415 = (mois == Mois.adar || mois == Mois.adarII) && (14...15).contains(quantieme)
        if !(roshChodesh || regles.isChanukah() || adar1415 || regles.isTishaBav() || regles.isAssurBemelacha()
             || index == JewishCalendar.EREV_PESACH || index == JewishCalendar.EREV_YOM_KIPPUR) { c.insert(C.lamnatseah) }
        if mois == Mois.eloul || (mois == Mois.tichri && quantieme <= 21) { c.insert(C.ledavid) }
        if regles.isAseresYemeiTeshuva() || (mois == Mois.tichri && quantieme == 21) { c.insert(C.techouvaHochaana) }
        let yomTov = regles.isYomTovAssurBemelacha()
        if yomTov { c.insert(C.yomTov) }
        if [C.pessah, C.soukkot, C.chavouot, C.cheminiAtseret].contains(where: { c.contains($0) }) { c.insert(C.moed) }
        if samedi && roshChodesh { c.insert(C.chabbatRochHodech) }
        // « וּלְכַפָּרַת פָּשַׁע » au Moussaf de Roch 'Hodech d'une année embolismique : toute l'année
        // (Edot) ou jusqu'à Roch 'Hodech Adar II inclus (Sfard et Ashkenaz) ; le 30 inaugure le mois suivant.
        if roshChodesh && embolismique {
            let inaugure: Int
            if quantieme == 30 {
                switch mois {
                case Mois.adar: inaugure = Mois.adarII
                case Mois.adarII: inaugure = Mois.nissan
                default: inaugure = mois + 1
                }
            } else {
                inaugure = mois
            }
            c.insert(C.embolismique)
            if inaugure >= Mois.tichri { c.insert(C.embolismiqueAvantNissan) }
        }
        if samedi && yomTov { c.insert(C.yomTovChabbat) }
        if samedi && regles.isRoshHashana() { c.insert(C.rochHachanaChabbat) }
        let hierYomTov = calendrier(date.plus(jours: -1), enIsrael: enIsrael, modernes: false).isYomTovAssurBemelacha()
        if dimanche || (hierYomTov && !regles.isAssurBemelacha()) { c.insert(C.motsaeChabbatYT) }

        // Dans une ville murée, le 15 Adar est Pourim ; le 14 ne l'est qu'ailleurs.
        var fetesDuJour: [String] = []
        if let fete = fetes[affiche.getYomTovIndex()] {
            fetesDuJour.append(mukafChoma ? muree[fete] ?? fete : fete)
        }
        if affiche.isRoshChodesh() && !fetesDuJour.contains("roch_hodech") { fetesDuJour.append("roch_hodech") }

        let format = HebrewDateFormatter()
        format.hebrewFormat = true
        var paracha: String?
        if samedi && regles.getParshah() != .NONE {
            let nom = format.formatParsha(jewishCalendar: regles)
            paracha = nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nom
        }
        return Jour(
            date: date,
            enIsrael: enIsrael,
            dateHebraique: format.format(jewishCalendar: regles),
            jourEnLettres: format.formatHebrewNumber(number: quantieme),
            jourHebreu: quantieme,
            moisHebreu: mois,
            anneeHebraique: regles.getJewishYear(),
            moisEtAnnee: format.formatMonth(jewishCalendar: regles) + " " + format.formatHebrewNumber(number: regles.getJewishYear()),
            fetes: fetesDuJour,
            omer: max(regles.getDayOfOmer(), 0),
            paracha: paracha,
            chome: regles.isAssurBemelacha(),
            conditions: c)
    }
}

// MARK: Le jour hébreu seul, et le molad

extension CalendrierJuif {

    /// Ce que `JewishCalendar(date)` de KosherJava dit d'un jour civil, sans les règles de prière :
    /// assez léger pour les boucles de Levana, du Yalkout Yossef et des hilloulot. Lu dans le calendrier
    /// hébreu de Foundation, celui que KosherSwift lit lui-même.
    public struct DateJuive: Sendable, Equatable {
        public let annee: Int
        /// Numérotation de KosherJava : NISSAN = 1 … ELUL = 6, TICHREI = 7 … ADAR = 12, ADAR_II = 13.
        public let mois: Int
        public let jour: Int
        public let embolismique: Bool

        /// `isRoshChodesh()` : le 30 d'un mois, ou le 1er d'un mois autre que Tichri.
        public var rochHodech: Bool { (jour == 1 && mois != Mois.tichri) || jour == 30 }
    }

    /// Le calendrier hébreu de Foundation, en UTC : le jour civil y est lu à midi.
    private static let hebreu: Calendar = {
        var c = Calendar(identifier: .hebrew)
        c.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        return c
    }()

    /// `JewishCalendar(date)` : l'année, le mois et le jour hébreux d'un jour civil.
    public static func dateJuive(_ date: JourCivil) -> DateJuive {
        let midi = Date(timeIntervalSince1970: Double(date.jourJulien - 2_440_588) * 86_400 + 43_200)
        let c = hebreu.dateComponents([.year, .month, .day], from: midi)
        let annee = c.year ?? 0
        let embolismique = estEmbolismique(annee)
        return DateJuive(annee: annee, mois: moisKosherJava(c.month ?? 0, embolismique: embolismique),
                         jour: c.day ?? 0, embolismique: embolismique)
    }

    /// Cycle de Méton : 7 années embolismiques sur 19 (`isJewishLeapYear`).
    public static func estEmbolismique(_ annee: Int) -> Bool { Kotlin.floorMod(7 * annee + 1, 19) < 7 }

    /// `getYomTovIndex() == YOM_KIPPUR` : le 10 Tichri.
    public static func estKippour(_ date: JourCivil) -> Bool {
        let d = dateJuive(date)
        guard d.mois == Mois.tichri && d.jour == 10 else { return false }
        return verrou.withLock { _ in calendrier(date, enIsrael: false, modernes: false).getYomTovIndex() == JewishCalendar.YOM_KIPPUR }
    }

    /// `getYomTovIndex() == TISHA_BEAV` : le 9 Av, ou le 10 quand le 9 est un Chabbat.
    public static func estTichaBeav(_ date: JourCivil) -> Bool {
        let d = dateJuive(date)
        guard d.mois == Mois.av && (d.jour == 9 || d.jour == 10) else { return false }
        return verrou.withLock { _ in calendrier(date, enIsrael: false, modernes: false).getYomTovIndex() == JewishCalendar.TISHA_BEAV }
    }

    /// `isYomTovAssurBemelacha()` d'un `JewishCalendar(date)` : hors d'Israël, sans les fêtes modernes.
    public static func estYomTovChome(_ date: JourCivil) -> Bool {
        verrou.withLock { _ in calendrier(date, enIsrael: false, modernes: false).isYomTovAssurBemelacha() }
    }

    /// `getDayOfChanukah()` : de 1 à 8, ou -1 hors de 'Hanouka.
    public static func jourHanouka(_ date: JourCivil) -> Int {
        let d = dateJuive(date)
        guard d.mois == Mois.kislev || d.mois == Mois.tevet else { return -1 }
        return verrou.withLock { _ in calendrier(date, enIsrael: false, modernes: false).getDayOfChanukah() }
    }

    /// La paracha que suit la halakha du jour (Halakha.pour) : celle du Chabbat même, sinon celle du
    /// Chabbat qui vient (`getParshah`, puis `getUpcomingParshah`), par le nom de KosherJava (« LECH_LECHA »).
    public static func parachaAVenir(_ date: JourCivil, enIsrael: Bool) -> String {
        verrou.withLock { _ -> String in
            let c = calendrier(date, enIsrael: enIsrael, modernes: false)
            let p = c.getParshah()
            return String(describing: p == .NONE ? c.getUpcomingParshah() : p)
        }
    }

    // Les heures du molad comptent en halakim : 1 080 par heure, 25 920 par jour.
    private static let halakimParJour: Int64 = 25_920
    /// Le molad Tohou (BaHaRaD) : un jour, 5 heures et 204 halakim après le début du compte.
    private static let halakimMoladTohou: Int64 = 31_524
    /// Un mois lunaire moyen : 29 jours, 12 heures et 793 halakim.
    private static let halakimParMois: Int64 = 765_433
    /// Le jour de la création dans la numérotation de Reingold et Dershowitz (1er janvier 1 = 1), et le 1er janvier 1970.
    private static let epoqueJuive: Int64 = -1_373_429
    private static let jourFixe1970: Int64 = 719_163

    /// `getMoladAsDate()` du mois `mois` (numérotation de KosherJava) de l'année `annee`, en millisecondes
    /// Unix : l'heure moyenne de Jérusalem posée sur l'heure d'hiver d'Israël (UTC+2), moins le décalage de
    /// l'heure locale du mont du Temple (35,2354 E), 20 min 56,496 s. La milliseconde est tronquée comme
    /// en Java ; KosherSwift garde, lui, la fraction de milliseconde.
    public static func molad(annee: Int, mois: Int) -> Int64 {
        let embolismique = estEmbolismique(annee)
        let rang = (mois + (embolismique ? 6 : 5)) % (embolismique ? 13 : 12) + 1
        let a = Int64(annee - 1)
        let moisEcoules = 235 * (a / 19) + 12 * (a % 19) + (7 * (a % 19) + 1) / 19 + Int64(rang - 1)
        let halakim = halakimMoladTohou + halakimParMois * moisEcoules
        let jour = halakim / halakimParJour
        let parts = halakim - jour * halakimParJour
        let heures = parts / 1080
        let minutes = (parts - heures * 1080) / 18
        let reste = parts - heures * 1080 - minutes * 18
        // Le jour hébreu commence à 18 h : de sa sixième heure (minuit) on est au jour civil suivant.
        let civil = jour + epoqueJuive + (heures >= 6 ? 1 : 0)
        let heureCivile = (heures + 18) % 24
        let secondes = Double(reste) * 10 / 3
        let entieres = Int64(secondes)
        let millis = Int64(1000 * (secondes - Double(entieres)))
        let minuit: Int64 = (civil - jourFixe1970) * 86_400_000
        let heure: Int64 = heureCivile * 3_600_000 + minutes * 60_000 + entieres * 1000 + millis
        return minuit + heure - 7_200_000 - decalageHeureLocale
    }

    /// `GeoLocation.getLocalMeanTimeOffset()` du mont du Temple sur UTC+2, en millisecondes tronquées.
    private static let decalageHeureLocale = Int64(35.2354 * 4 * 60_000 - 7_200_000)
}
