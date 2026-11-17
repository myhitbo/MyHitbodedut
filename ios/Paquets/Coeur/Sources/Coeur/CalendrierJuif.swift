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

        /// Avinou malkénou à Min'ha : le même jour, si Ta'hanoun s'y dit ou à Roch Hachana et Kippour, jamais le
        /// vendredi (TSIDDUR-09).
        public static let avinouMalkenouMinha = "avinou_malkenou_minha"
        /// Le 9 Av ou Kippour (12/11) : « שעשה לי כל צרכי » ne se dit pas.
        public static let tichaBeavKippour = "ticha_beav_kippour"
        /// Le dimanche 16 Adar d'un Pourim triple, en Israël hors de Jérusalem (14/11) : l'Ashkenaz y omet Ta'hanoun.
        public static let pourimTripleHorsJerusalem = "pourim_triple_hors_jerusalem"
        /// Le même dimanche à Jérusalem, jour du festin (Yalkut Yosef 688:6, § 15).
        public static let pourimTripleFestin = "pourim_triple_festin"

        // Audit du 16/11 : Ta'hanoun et ce qui en dépend (CalendrierJuif.kt).
        public static let avinouMalkenouJeune = "avinou_malkenou_jeune"
        public static let kaddichCompletHallel = "kaddich_complet_hallel"
        public static let veillePessahCheni = "veille_pessah_cheni"
        public static let jourPessahCheni = "jour_pessah_cheni"
        public static let elErekhApayim = "el_erekh_apayim"
        public static let erevKippour = "erev_kippour"
        /// « Pas de Ta'hanoun aujourd'hui » (réglage ponctuel) : jamais calculée, ajoutée le jour choisi.
        public static let sansTahanounPonctuel = "sans_tahanoun_ponctuel"

        // Hallel et Moussaf (audit du 16/11).
        public static let rochHodechChol = "roch_hodech_chol"
        public static let holHamoed = "hol_hamoed"
        public static let hanoukaSansMoussaf = "hanouka_sans_moussaf"
        public static let hanoukaHorsRochHodech = "hanouka_hors_roch_hodech"
        public static let leilPessah = "leil_pessah"
        public static let hallelPartiel = "hallel_partiel"

        // Structure des offices (audit du 16/11).
        public static let mizmorLetoda = "mizmor_letoda"
        public static let yomTovSemaine = "yom_tov_semaine"
        public static let leilHaseder = "leil_haseder"
        public static let lendemainRochHodech = "lendemain_roch_hodech"
        public static let chome = "chome"

        // Posées par SiddurJour.conditionsPour selon le noussa'h (audit du 16/11).
        public static let vihiNoam = "vihi_noam"
        public static let veataKadoch = "veata_kadoch"
        public static let tefilin = "tefilin"
        public static let tefilinSansBerakha = "tefilin_sans_berakha"
        public static let viduiCoucher = "vidui_coucher"
        /// Le vendredi 14 Adar d'un Pourim triple, à Jérusalem : la Méguila s'y lit.
        public static let pourimTripleVendredi = "pourim_triple_vendredi"
        /// La nuit : posée par la lecture d'après l'heure (`nuit`), jamais par le calendrier.
        public static let nuit = "nuit"

        // La Havdala, le lendemain d'un jour d'ajouts, Bein hamétsarim, Tikoun Ra'hel (audit du 16/11).
        public static let havdalaNer = "havdala_ner"
        public static let havdalaBessamim = "havdala_bessamim"
        public static let lendemainTichaBeavDimanche = "lendemain_ticha_beav_dimanche"
        public static let lendemainAjouts = "lendemain_ajouts"
        public static let beinHametsarim = "bein_hametsarim"
        public static let tikounRahel = "tikoun_rahel"
        /// Toujours vrai : une indication fixe du siddour, sans condition du jour.
        public static let toujours = "toujours"

        public static let derivees = [avinouMalkenou, avinouMalkenouMinha, kriatHatorah] + joursSemaine + [
            tsomGuedaliaTevet, lendemainKippour, tichaBeavKippour, estherPourim, chivaAssarTamouz, basculePluie, erevKippourVendredi,
            lamnatseah, ledavid, techouvaHochaana, yomTov, moed, chabbatRochHodech, yomTovChabbat, rochHachanaChabbat,
            motsaeChabbatYT, beitAvel, oubli, minyan, chevaBerakhot, zimun, facultatif, embolismique, embolismiqueAvantNissan,
            pourimTripleHorsJerusalem, pourimTripleFestin, avinouMalkenouJeune, kaddichCompletHallel,
            veillePessahCheni, erevKippour, sansTahanounPonctuel, jourPessahCheni, elErekhApayim,
            rochHodechChol, holHamoed, hanoukaSansMoussaf, hanoukaHorsRochHodech, leilPessah, hallelPartiel,
            mizmorLetoda, yomTovSemaine, leilHaseder, lendemainRochHodech, chome, vihiNoam, veataKadoch, tefilin,
            tefilinSansBerakha, viduiCoucher, nuit, pourimTripleVendredi, havdalaNer, havdalaBessamim,
            lendemainTichaBeavDimanche, lendemainAjouts, beinHametsarim, tikounRahel, toujours,
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
        /// Le Chabbat spécial (Chekalim, Zakhor, Para, ha'Hodech…), en hébreu ; nil les autres jours (audit du 16/11).
        public var parachaSpeciale: String? = nil
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
        // Tikoun 'hatsot avant minuit : la nuit du lendemain ; à midi (Bein hamétsarim), le jour même (audit du 16/11).
        case "tikoun_hatsot": heure >= 18 ? date.plus(jours: 1) : date
        case "minha": date
        default: apresSortie ? date.plus(jours: 1) : date
        }
    }

    /// La nuit, pour la lecture (audit du 16/11 : שהחיינו de la Méguila chez les Edot, « אשר הניא » en Sfard et en
    /// Ashkenaz) : après la sortie des étoiles ou avant l'aube du lieu ; sans lieu (`apresSortie`, `avantAube`
    /// nil), de 19 h à 6 h. `heure` : l'heure de la journée (0 à 23).
    public static func nuit(heure: Int, apresSortie: Bool?, avantAube: Bool?) -> Bool {
        (apresSortie ?? (heure >= 19)) || (avantAube ?? (heure < 6))
    }

    /// Les repères du jour qui ne changent pas le texte de la prière (audit du 16/11), en clés de chaîne :
    /// Seli'hot, chofar d'Eloul (Ashkenaz, Sfard), pas de chofar le 29 Eloul, בה״ב et son « מי שבירך »
    /// (Ashkenaz, Sfard), Yom Kippour katan, érouv tavchilin (CalendrierJuif.reperes).
    public static func reperes(_ date: JourCivil, enIsrael: Bool, nusah: String) -> [String] {
        verrou.withLock { _ in
            let c = calendrier(date, enIsrael: enIsrael, modernes: false)
            let mois = moisKosherJava(c.getJewishMonth(), embolismique: c.isJewishLeapYear())
            let j = c.getJewishDayOfMonth()
            let chabbat = date.jourDeSemaine == 7
            let edot = nusah == "edot"
            var r: [String] = []
            if selihot(date, enIsrael: enIsrael, edot: edot) { r.append("repere_selihot") }
            if !edot && mois == Mois.eloul && j <= 28 && !chabbat { r.append("repere_chofar") }
            if mois == Mois.eloul && j == 29 { r.append("repere_pas_de_chofar") }
            if !edot && c.isBeHaB() { r.append("repere_behab") }
            if !edot && chabbat && calendrier(date.plus(jours: 2), enIsrael: enIsrael, modernes: false).isBeHaB()
                && calendrier(date.plus(jours: 5), enIsrael: enIsrael, modernes: false).isBeHaB() {
                r.append("repere_behab_mi_cheberakh")
            }
            if c.isYomKippurKatan() { r.append("repere_yom_kippour_katan") }
            if erouvTavchilin(date, enIsrael: enIsrael) { r.append("repere_erouv_tavchilin") }
            return r
        }
    }

    private static func selihot(_ date: JourCivil, enIsrael: Bool, edot: Bool) -> Bool {
        let c = calendrier(date, enIsrael: enIsrael, modernes: false)
        if date.jourDeSemaine == 7 || c.isRoshHashana() { return false }
        let mois = moisKosherJava(c.getJewishMonth(), embolismique: c.isJewishLeapYear())
        let j = c.getJewishDayOfMonth()
        if mois == Mois.tichri { return j <= 9 }
        if mois != Mois.eloul { return false }
        if edot { return j >= 2 }
        // Le dimanche avant Roch Hachana ; s'il reste moins de quatre jours, celui d'avant.
        let rh = date.plus(jours: 30 - j)
        // dayOfWeek.value % 7 de Java : 0 le dimanche, 6 le samedi.
        var debut = rh.plus(jours: -(rh.jourDeSemaine - 1))
        if rh.jourJulien - debut.jourJulien < 4 { debut = debut.plus(jours: -7) }
        return !(date < debut)
    }

    /// La période où l'on évite d'écouter des chants avec instruments (audit du 16/11) : « omer » (sauf Lag
    /// baOmer), « bein_hametsarim » du 17 Tamouz au 9 Av, le jeûne repoussé compris ; nil sinon.
    public static func periodeSansMusique(_ date: JourCivil) -> String? {
        verrou.withLock { _ in
            let c = calendrier(date, enIsrael: false, modernes: false)
            let mois = moisKosherJava(c.getJewishMonth(), embolismique: c.isJewishLeapYear())
            let j = c.getJewishDayOfMonth()
            if c.getDayOfOmer() > 0 && c.getDayOfOmer() != 33 { return "omer" }
            if (mois == Mois.tamouz && j >= 17) || (mois == Mois.av && j <= 9) || c.getYomTovIndex() == JewishCalendar.TISHA_BEAV {
                return "bein_hametsarim"
            }
            return nil
        }
    }

    /// La veille d'un Yom tov dont les jours chômés mènent jusqu'à Chabbat (un vendredi de fête).
    private static func erouvTavchilin(_ date: JourCivil, enIsrael: Bool) -> Bool {
        if calendrier(date, enIsrael: enIsrael, modernes: false).isAssurBemelacha() { return false }
        var d = date.plus(jours: 1)
        while calendrier(d, enIsrael: enIsrael, modernes: false).isYomTovAssurBemelacha() {
            if d.jourDeSemaine == 6 { return true }
            d = d.plus(jours: 1)
        }
        return false
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
        // Pourim triple (15 Adar un Chabbat) : à Jérusalem, le dimanche 16 est le jour du festin, sans Ta'hanoun
        // ni למנצח (Kitsour Yalkout Yossef 688:6, § 14), ce que TefilaRules ignore ; ailleurs en Israël,
        // Ta'hanoun, sauf en Ashkenaz (C.pourimTripleHorsJerusalem).
        let dimanchePourimTriple = dimanche && quantieme == 16 && mois == (embolismique ? Mois.adarII : Mois.adar)
        let festinJerusalem = mukafChoma && dimanchePourimTriple
        if festinJerusalem { c.insert(C.pourimTripleFestin) }
        if enIsrael && !mukafChoma && dimanchePourimTriple { c.insert(C.pourimTripleHorsJerusalem) }
        let tahanoun = tefila.isTachanunRecitedShacharis(jewishCalendar: regles) && index != JewishCalendar.EREV_ROSH_HASHANA
            && !festinJerusalem
        if tahanoun { c.insert(C.tahanounChaharit) }
        if tefila.isTachanunRecitedMincha(jewishCalendar: regles) && !festinJerusalem { c.insert(C.tahanounMinha) }
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
        if regles.isTishaBav() || regles.isYomKippur() { c.insert(C.tichaBeavKippour) }
        if index == JewishCalendar.FAST_OF_ESTHER || c.contains(C.pourim) { c.insert(C.estherPourim) }
        if index == JewishCalendar.SEVENTEEN_OF_TAMMUZ { c.insert(C.chivaAssarTamouz) }
        if (mois == Mois.tichri && quantieme == 22) || (mois == Mois.nissan && quantieme == 15) { c.insert(C.basculePluie) }
        if mois == Mois.tichri && quantieme == 9 && semaine == 6 { c.insert(C.erevKippourVendredi) }
        // Relevé du 19/10 : למנצח, « לדוד ה׳ אורי », les dix jours et Hochaana Rabba, fêtes et Chabbat.
        let adar1415 = (mois == Mois.adar || mois == Mois.adarII) && (14...15).contains(quantieme)
        if !(roshChodesh || regles.isChanukah() || adar1415 || festinJerusalem || regles.isTishaBav() || regles.isAssurBemelacha()
             || regles.isCholHamoed() || index == JewishCalendar.EREV_PESACH || index == JewishCalendar.EREV_YOM_KIPPUR) { c.insert(C.lamnatseah) }
        if mois == Mois.eloul || (mois == Mois.tichri && quantieme <= 21) { c.insert(C.ledavid) }
        if regles.isAseresYemeiTeshuva() || (mois == Mois.tichri && quantieme == 21) { c.insert(C.techouvaHochaana) }
        let yomTov = regles.isYomTovAssurBemelacha()
        if yomTov { c.insert(C.yomTov) }
        if [C.pessah, C.soukkot, C.chavouot, C.cheminiAtseret].contains(where: { c.contains($0) }) { c.insert(C.moed) }
        if samedi && roshChodesh { c.insert(C.chabbatRochHodech) }
        // Hallel et Moussaf (audit du 16/11).
        if !samedi && roshChodesh { c.insert(C.rochHodechChol) }
        if regles.isCholHamoed() { c.insert(C.holHamoed) }
        if regles.isChanukah() && !roshChodesh && !samedi { c.insert(C.hanoukaSansMoussaf) }
        if regles.isChanukah() && !roshChodesh { c.insert(C.hanoukaHorsRochHodech) }
        if index == JewishCalendar.PESACH && mois == Mois.nissan && quantieme <= 16 { c.insert(C.leilPessah) }
        if c.contains(C.hallel) && !c.contains(C.hallelComplet) { c.insert(C.hallelPartiel) }
        // « וּלְכַפָּרַת פָּשַׁע » au Moussaf de Roch 'Hodech d'une année embolismique : jusqu'à Roch 'Hodech Adar II
        // inclus, plus à partir de Nissan (Sfard, Ashkenaz ; pour les Edot, Kitsour Yalkut Yosef 423:14, audit du
        // 16/11, leur siddour le dit toute l'année) ; le 30 inaugure le mois suivant.
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
        // Audit du 16/11 (C.avinouMalkenouJeune…).
        if c.contains(C.jeune) && !c.contains(C.asseretYemeiTechouva) { c.insert(C.avinouMalkenouJeune) }
        if !regles.isChanukah() || roshChodesh || samedi { c.insert(C.kaddichCompletHallel) }
        if mois == Mois.iyar && quantieme == 13 { c.insert(C.veillePessahCheni) }
        if mois == Mois.iyar && quantieme == 14 { c.insert(C.jourPessahCheni) }
        if c.contains(C.lamnatseah) && lundiOuJeudi { c.insert(C.elErekhApayim) }
        if index == JewishCalendar.EREV_YOM_KIPPUR { c.insert(C.erevKippour) }
        let hier = calendrier(date.plus(jours: -1), enIsrael: enIsrael, modernes: false)
        // Un samedi soir qui est Yom tov n'est pas un soir ouvrable (O.H. 491:2 ; audit du 16/11).
        if (dimanche || hier.isYomTovAssurBemelacha()) && !regles.isAssurBemelacha() { c.insert(C.motsaeChabbatYT) }
        if regles.isAssurBemelacha() { c.insert(C.chome) }
        if !(samedi || yomTov || regles.isPesach() || index == JewishCalendar.EREV_PESACH
             || index == JewishCalendar.EREV_YOM_KIPPUR) { c.insert(C.mizmorLetoda) }
        if dimanche && (0...5).contains(where: { k in
            let j = calendrier(date.plus(jours: k), enIsrael: enIsrael, modernes: false)
            return j.isYomTovAssurBemelacha() || j.isCholHamoed()
        }) { c.insert(C.yomTovSemaine) }
        if mois == Mois.nissan && (quantieme == 15 || (quantieme == 16 && !enIsrael)) { c.insert(C.leilHaseder) }
        if hier.isRoshChodesh() && !roshChodesh { c.insert(C.lendemainRochHodech) }
        if mukafChoma && semaine == 6 && quantieme == 14 && mois == (embolismique ? Mois.adarII : Mois.adar) {
            c.insert(C.pourimTripleVendredi)
        }
        // La Havdala et le lendemain d'un jour d'ajouts (audit du 16/11).
        let veille = calendrier(date.plus(jours: -1), enIsrael: enIsrael, modernes: false, mukafChoma: mukafChoma)
        let kippour = c.contains(C.kippour) || c.contains(C.lendemainKippour)
        if samedi || dimanche || kippour { c.insert(C.havdalaNer) }
        if samedi || (dimanche && !c.contains(C.tichaBeav)) || kippour { c.insert(C.havdalaBessamim) }
        if semaine == 2 && veille.isTishaBav() { c.insert(C.lendemainTichaBeavDimanche) }
        if !samedi && (dimanche || veille.isRoshChodesh() || veille.isYomTovAssurBemelacha() || veille.isCholHamoed()
                       || veille.isChanukah() || veille.isPurim()) { c.insert(C.lendemainAjouts) }
        if (mois == Mois.tamouz && quantieme >= 17) || (mois == Mois.av && quantieme <= 10) { c.insert(C.beinHametsarim) }
        // Tikoun Ra'hel (audit du 16/11).
        if !(roshChodesh || (mois == Mois.tichri && quantieme <= (enIsrael ? 22 : 23)) || regles.isChanukah() || adar1415
             || mois == Mois.nissan || regles.getDayOfOmer() > 0 || (enIsrael && regles.getJewishYear() % 7 == 0)) {
            c.insert(C.tikounRahel)
        }
        c.insert(C.toujours)

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
            conditions: c,
            parachaSpeciale: parachaSpeciale(regles, samedi: samedi, mois: mois, embolismique: embolismique,
                                             quantieme: quantieme, mukafChoma: mukafChoma, format: format))
    }

    /// Le Chabbat spécial (audit du 16/11) : Chekalim, Zakhor, Para, ha'Hodech… ; à Jérusalem, le Chabbat 15 Adar
    /// d'un Pourim triple, le maftir « ויבא עמלק » (O.H. 688:6), que getSpecialShabbos ne connaît pas.
    private static func parachaSpeciale(_ regles: JewishCalendar, samedi: Bool, mois: Int, embolismique: Bool,
                                        quantieme: Int, mukafChoma: Bool, format: HebrewDateFormatter) -> String? {
        if !samedi { return nil }
        if regles.getSpecialShabbos() != .NONE {
            let nom = format.formatSpecialParsha(jewishCalendar: regles)
            return nom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : nom
        }
        let adar = embolismique ? Mois.adarII : Mois.adar
        return mukafChoma && mois == adar && quantieme == 15 ? "מפטיר ויבא עמלק" : nil
    }
}
