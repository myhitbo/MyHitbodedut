import Foundation
import Synchronization
import Testing
import Coeur
@testable import Ecrans

/// Une horloge qu'on avance : l'écran resté ouvert jusqu'au lendemain, la position vieille de six heures.
final class ZmanimHorlogeMobile: Horloge, Sendable {
    private let temps: Mutex<Int64>
    let fuseau: Fuseau

    init(_ dateHeure: DateHeure, fuseau: Fuseau) {
        temps = Mutex(fuseau.millis(dateHeure))
        self.fuseau = fuseau
    }

    var maintenant: Int64 {
        temps.withLock { $0 }
    }

    func avancer(heures: Int) {
        temps.withLock { $0 += Int64(heures) * 3_600_000 }
    }
}

/// Ce que partagent les tests de l'onglet Zmanim, du calendrier, du lieu et du partage : les contenus exportés du
/// dépôt, le catalogue de chaînes, les villes.
enum ZmanimEssais {
    static let contenus = ContenusApp(dossier: Fichiers.contenu)
    static let hilloulot = ZmanimHilloulotTable(dossier: Fichiers.contenu)
    /// Les identifiants GeoNames de Jérusalem et de Paris dans `villes.json`.
    static let jerusalem: Int64 = 281_184
    static let paris: Int64 = 2_988_507

    static func traducteur(_ langue: String = "fr") throws -> Traducteur {
        try Traducteur(catalogue: Fichiers.catalogue(), langue: langue)
    }

    static func ville(_ id: Int64) async throws -> Ville {
        let villes = try await contenus.villes()
        let trouvee = villes.first { $0.id == id }
        return try #require(trouvee)
    }

    /// Une ville choisie dans la liste (Israël d'après son pays), et un noussa'h.
    static func reglages(_ ville: Ville, nusah: Nusah = .edot) -> Reglages {
        var reglages = Reglages()
        reglages.setLieuZmanim(ville.lieu, ville: ville, maintenant: 0)
        reglages.setSiddurNusah(nusah)
        return reglages
    }

    static func cles(_ libelles: [Libelle]) -> [String] {
        libelles.map { $0.cle }
    }
}

/// L'onglet Zmanim (ZmanimActivity.kt et VueJour.kt) sur les contenus exportés : les jours des captures de
/// `captures-calendrier/zmanim-*.png` (mêmes ajouts, mêmes horaires à la minute), le bandeau, les boutons, les
/// cartes sous les horaires, l'allumage et Ta'hanoun, le jour qui suit l'horloge.
@Suite("Écran Zmanim")
@MainActor
struct ZmanimEcranTests {

    /// Un modèle sur les contenus du dépôt, l'horloge arrêtée à `heure` du jour `iso` dans `fuseau`, apparu.
    private func fabriquer(_ reglages: Reglages, _ iso: String, heure: Int = 9, fuseau: String,
                        langue: String = "fr") async throws -> (ZmanimModele, Magasin) {
        let jour = try #require(JourCivil(iso: iso))
        let telephone = try #require(Fuseau(fuseau))
        let traducteur = try ZmanimEssais.traducteur(langue)
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let modele = ZmanimModele(magasin: magasin, horloge: HorlogeFixe(DateHeure(jour, heure: heure), fuseau: telephone),
                                  contenus: ZmanimEssais.contenus, hilloulot: ZmanimEssais.hilloulot,
                                  traducteur: traducteur)
        await modele.apparaitre()
        return (modele, magasin)
    }

    private func heures(_ modele: ZmanimModele) -> [String: String] {
        var heures: [String: String] = [:]
        for ligne in modele.lignes { heures[ligne.cle] = ligne.heureTexte }
        return heures
    }

    // MARK: Les captures

    /// zmanim-rh-edot.png : Jérusalem, lundi 12 octobre 2026, Roch 'Hodech 'Hechvan.
    @Test func rochHodechAJerusalemEnEdot() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .edot), "2026-10-12", fuseau: "Asia/Jerusalem")
        let fr = try ZmanimEssais.traducteur()
        let lieu = modele.lieuTexte.map { fr.texte($0) }
        #expect(lieu == "Jérusalem · Israël")
        let carte = modele.carte
        let marques = ZmanimEssais.cles(carte.marques)
        #expect(marques.contains("fete_roch_hodech"))
        let ajouts = ZmanimEssais.cles(carte.ajouts)
        #expect(ajouts == ["ajout_machiv_harouah", "ajout_barkhenou", "ajout_yaale_veyavo",
                           "ajout_hallel_partiel_sans_berakha", "ajout_sans_tahanoun"])
        #expect(carte.aucunAjout == nil)
        #expect(carte.illustration == nil)
        let attendues = ["alot": "05:28", "misheyakir": "05:49", "netz": "06:40", "szks_mga": "08:56", "szks_gra": "09:32",
                         "szt_mga": "10:06", "szt_gra": "10:30", "minha_gedola": "12:54", "minha_ketana": "15:46",
                         "plag": "16:58", "chkia": "18:10", "tset": "18:46", "tset_rt": "19:22"]
        let obtenues = heures(modele)
        for (cle, heure) in attendues {
            #expect(obtenues[cle] == heure, "\(cle)")
        }
        // Un lundi ordinaire : ni allumage ni sortie, les quinze zmanim du profil dans son ordre.
        let ordre = modele.lignes.map { $0.cle }
        let profil = Zmanim.profil.map { $0.cle }
        #expect(ordre == profil)
    }

    /// zmanim-rh-sefard.png : le même jour en Sfard, le Hallel avec sa bénédiction.
    @Test func rochHodechAJerusalemEnSfard() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .sefard), "2026-10-12", fuseau: "Asia/Jerusalem")
        let ajouts = ZmanimEssais.cles(modele.carte.ajouts)
        #expect(ajouts == ["ajout_machiv_harouah", "ajout_berakha", "ajout_yaale_veyavo",
                           "ajout_hallel_partiel_avec_berakha", "ajout_sans_tahanoun"])
        let obtenues = heures(modele)
        #expect(obtenues["alot"] == "05:28")
        #expect(obtenues["szt_gra"] == "10:30")
    }

    /// zmanim-jeune-ashkenaz.png et zmanim-jeune-edot.png : Paris, dimanche 20 décembre 2026, jeûne du 10 Tévet.
    @Test func dixTevetAParis() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.paris)
        let (ashkenaze, _) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .ashkenaz), "2026-12-20", fuseau: "Europe/Paris")
        let fr = try ZmanimEssais.traducteur()
        let lieu = ashkenaze.lieuTexte.map { fr.texte($0) }
        #expect(lieu == "Paris · Diaspora")
        let ajoutsA = ZmanimEssais.cles(ashkenaze.carte.ajouts)
        #expect(ajoutsA == ["ajout_machiv_harouah", "ajout_tal_oumatar", "ajout_anenou_officiant",
                            "ajout_anenou_particulier_minha", "ajout_tahanoun"])
        let attendues = ["alot": "06:56", "misheyakir": "07:26", "netz": "08:40", "szks_mga": "10:08", "szks_gra": "10:44",
                         "szt_mga": "11:01", "szt_gra": "11:25", "minha_gedola": "13:08", "minha_ketana": "15:12",
                         "plag": "16:04", "chkia": "16:55", "tset": "17:50", "tset_rt": "18:07"]
        let obtenues = heures(ashkenaze)
        for (cle, heure) in attendues {
            #expect(obtenues[cle] == heure, "\(cle)")
        }
        let (edot, _) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .edot), "2026-12-20", fuseau: "Europe/Paris")
        let ajoutsE = ZmanimEssais.cles(edot.carte.ajouts)
        #expect(ajoutsE == ["ajout_machiv_harouah", "ajout_barekh_alenou", "ajout_anenou_officiant",
                            "ajout_anenou_particulier_matin_minha", "ajout_tahanoun"])
        let marques = edot.carte.marques
        #expect(!marques.isEmpty)
    }

    /// zmanim-ticha-beav-edot.png : Jérusalem, jeudi 12 août 2027, Tich'a bèAv.
    @Test func tichaBeavAJerusalemEnEdot() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .edot), "2027-08-12", fuseau: "Asia/Jerusalem")
        let carte = modele.carte
        let marques = ZmanimEssais.cles(carte.marques)
        #expect(marques.contains("fete_ticha_beav"))
        let ajouts = ZmanimEssais.cles(carte.ajouts)
        #expect(ajouts == ["ajout_morid_hatal", "ajout_barkhenou", "ajout_anenou_officiant",
                           "ajout_anenou_particulier_trois", "ajout_ticha_beav", "ajout_sans_tahanoun"])
        let attendues = ["alot": "04:43", "misheyakir": "05:07", "netz": "06:01", "szks_mga": "08:46", "szks_gra": "09:22",
                         "szt_mga": "10:05", "szt_gra": "10:29", "minha_gedola": "13:17", "minha_ketana": "16:38",
                         "plag": "18:02", "chkia": "19:26", "tset": "20:04", "tset_rt": "20:38"]
        let obtenues = heures(modele)
        for (cle, heure) in attendues {
            #expect(obtenues[cle] == heure, "\(cle)")
        }
    }

    // MARK: Les lignes des horaires

    /// La méthode sous chaque horaire, dans la langue de l'app : la virgule décimale en français.
    @Test func laMethodeSousChaqueHoraire() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville), "2026-10-12", fuseau: "Asia/Jerusalem")
        let fr = try ZmanimEssais.traducteur()
        var methodes: [String: String] = [:]
        var noms: [String: String] = [:]
        for ligne in modele.lignes {
            methodes[ligne.cle] = ligne.methode.map { fr.texte($0) }
            noms[ligne.cle] = fr.texte(ligne.nom)
        }
        #expect(noms["alot"] == "Alot hacha’har")
        #expect(methodes["alot"] == "soleil à 16,1° sous l’horizon")
        #expect(methodes["misheyakir"] == "soleil à 11,5° sous l’horizon")
        #expect(methodes["netz"] == "au niveau de la mer")
        #expect(methodes["szks_mga"] == "journée de 72 min avant le lever à 72 min après le coucher")
        #expect(methodes["szks_gra"] == "heures saisonnières du lever au coucher")
        let enAnglais = try ZmanimEssais.traducteur("en")
        let alot = modele.lignes.first { $0.cle == "alot" }
        let methode = try #require(alot?.methode)
        // Le paramètre est fixé à la construction : le modèle est en français.
        #expect(enAnglais.texte(methode) == "sun 16,1° below the horizon")
        #expect(ZmanimVueJour.parametre("16.1", langue: "en") == "16.1")
        #expect(ZmanimVueJour.parametre("16.1", langue: "he") == "16.1")
        #expect(ZmanimVueJour.parametre("72", langue: "fr") == "72")
        #expect(ZmanimVueJour.parametre("", langue: "fr") == "")
        let misEnAvant = modele.lignes.contains { $0.misEnAvant }
        #expect(!misEnAvant)
    }

    /// Un vendredi, l'allumage 18 minutes avant la chki'a, mis en avant ; le samedi, la sortie.
    @Test func lAllumageEtLaSortieSontMisEnAvant() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (vendredi, magasin) = try await fabriquer(ZmanimEssais.reglages(ville), "2026-10-16", fuseau: "Asia/Jerusalem")
        let ligneAllumage = vendredi.lignes.first { $0.cle == "allumage" }
        let ligneChkia = vendredi.lignes.first { $0.cle == "chkia" }
        let allumage = try #require(ligneAllumage)
        let chkia = try #require(ligneChkia)
        #expect(allumage.misEnAvant)
        #expect(!chkia.misEnAvant)
        let heureChkia = try #require(chkia.heure)
        let heureAllumage = try #require(allumage.heure)
        let ecart = heureChkia.minutesDuJour - heureAllumage.minutesDuJour
        #expect(ecart == 18)
        #expect(allumage.methode == Libelle("zman_methode_avant_chkia", .texte("18")))
        // L'allumage choisi se voit dans la méthode.
        try await vendredi.choisirAllumage(30)
        let trente = vendredi.lignes.first { $0.cle == "allumage" }
        #expect(trente?.methode == Libelle("zman_methode_avant_chkia", .texte("30")))
        #expect(magasin.reglages.allumage == 30)
        vendredi.jourSuivant()
        let samedi = vendredi.lignes.map { $0.cle }
        #expect(samedi.contains("sortie"))
        #expect(!samedi.contains("allumage"))
    }

    @Test func uneLigneSansHeureMontreUnTiret() {
        let ligne = ZmanimLigne(cle: "alot", nom: Libelle("zman_alot"), heure: nil, methode: Libelle("zmanim_absent"),
                                misEnAvant: false)
        #expect(ligne.heureTexte == "—")
        let jour = JourCivil(annee: 2026, mois: 10, jour: 12)
        if let jour {
            let tot = ZmanimLigne(cle: "alot", nom: Libelle("zman_alot"), heure: DateHeure(jour, heure: 5, minute: 7, seconde: 59),
                                  methode: nil, misEnAvant: false)
            #expect(tot.heureTexte == "05:07")
        }
    }

    // MARK: Sans lieu

    @Test func sansLieuLInvitationEtPasDePastille() async throws {
        let (modele, _) = try await fabriquer(Reglages(), "2026-10-12", fuseau: "Asia/Jerusalem")
        #expect(modele.sansLieu)
        #expect(modele.lieuTexte == nil)
        let lignes = modele.lignes
        #expect(lignes.isEmpty)
        #expect(modele.invitationLieu == Libelle("zmanim_sans_lieu"))
        #expect(modele.choisirLieuLibelle == Libelle("zmanim_choisir_lieu"))
        // La carte du jour paraît quand même, et Levana dans le fuseau du téléphone.
        let carte = modele.carte
        #expect(!carte.dateHebraique.isEmpty)
        let levana = modele.levana
        #expect(levana != nil)
        // Le choix du lieu s'ouvre.
        #expect(modele.choixLieu?.dialogueOuvert == false)
        modele.montrerChoixLieu()
        #expect(modele.choixLieu?.dialogueOuvert == true)
    }

    // MARK: Le bandeau et les boutons

    @Test func leBandeauEtLesBoutons() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.paris)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville), "2026-10-12", fuseau: "Europe/Paris")
        #expect(modele.titre == Libelle("zmanim_title"))
        #expect(modele.image == "char_torah")
        let jour = modele.jour
        let routes = modele.boutons.map { $0.route }
        let attendues: [ZmanimRoute] = [.halakha(jour), .hilloulot(jour), .calendrier]
        #expect(routes == attendues)
        let libelles = ZmanimEssais.cles(modele.boutons.map { $0.libelle })
        #expect(libelles == ["zmanim_bouton_halakha", "zmanim_bouton_hilloulot", "zmanim_calendrier"])
        let bas = modele.boutonsBas
        let routesBas = bas.map { $0.route }
        let attenduesBas: [ZmanimRoute] = [.vol, .boussole]
        #expect(routesBas == attenduesBas)
        let icones = bas.map { $0.icone }
        let iconesAttendues: [String?] = ["✈", "🧭"]
        #expect(icones == iconesAttendues)
        let pied = ZmanimEssais.cles(modele.pied)
        #expect(pied == ["zmanim_a_valider", "zmanim_source_villes"])
        #expect(modele.carte.partage == Libelle("partage_jour"))
    }

    /// Les clés de l'écran existent dans le catalogue, en français, en anglais et en hébreu.
    @Test func lesClesDeLEcranSontAuCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        let cles = ["zmanim_title", "zmanim_lieu_detail", "region_israel", "region_diaspora", "zmanim_choisir_lieu",
                    "zmanim_bouton_halakha", "zmanim_bouton_hilloulot", "zmanim_calendrier", "zmanim_bouton_vol",
                    "zmanim_bouton_boussole", "reglage_allumage", "reglage_allumage_proposition",
                    "reglage_allumage_jerusalem", "reglage_allumage_valeur", "reglage_tahanoun_tichri",
                    "reglage_tahanoun_tichri_sans", "reglage_tahanoun_tichri_dit", "levana_titre", "levana_ce_soir",
                    "levana_dernier_soir", "levana_lune", "levana_croissante", "levana_decroissante", "levana_fenetre",
                    "levana_motsae", "levana_kippour", "levana_tisha", "levana_source", "levana_lire", "zmanim_paracha",
                    "zmanim_omer_ce_soir", "zmanim_ajouts_titre", "zmanim_aucun_ajout", "partage_jour", "hilloula_titre",
                    "hilloulot_tout", "halakha_livre", "halakha_ben_ish_hai", "halakha_yomit_titre", "halakha_tout",
                    "zmanim_sans_lieu", "zmanim_absent", "zmanim_erreur", "zmanim_a_valider", "zmanim_source_villes",
                    "calendrier_title", "calendrier_vue", "calendrier_vue_hebreu", "calendrier_vue_civil",
                    "calendrier_precedent", "calendrier_suivant", "calendrier_aujourdhui", "jour_ajouter_temps",
                    "zmanim_position", "zmanim_position_pres", "zmanim_position_attente", "zmanim_position_ancienne",
                    "zmanim_position_refusee", "app_name"]
        for cle in cles {
            for langue in ["fr", "en", "he"] {
                let valeur = catalogue.valeur(cle, langue: langue)
                #expect(valeur != nil, "\(cle) en \(langue)")
            }
        }
        for cle in ["levana_dans", "hilloula_autres"] {
            for langue in ["fr", "en", "he"] {
                let autre = catalogue.forme(cle, "other", langue: langue)
                #expect(autre != nil, "\(cle) en \(langue)")
            }
        }
    }

    // MARK: Sous les horaires

    @Test func levanaSuitLesReglesDeCoeurEtSeMasque() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(ville), "2026-10-12", fuseau: "Asia/Jerusalem")
        let levana = try #require(modele.levana)
        let fuseau = try #require(Fuseau("Asia/Jerusalem"))
        let usage = Levana.Usage.duNusah(.edot)
        // Les nuits bornées par la tsét du lieu (audit du 16/11).
        let fenetre = Levana.fenetre(modele.jour, fuseau: fuseau, usage: usage,
                                     horaires: Levana.Horaires.du(ZmanimEssais.reglages(ville).lieuZmanim, fuseau: fuseau))
        #expect(levana.debut == fuseau.dateHeure(millis: fenetre.debut))
        #expect(levana.fin == fuseau.dateHeure(millis: fenetre.fin))
        #expect(levana.debut < levana.fin)
        let etat = Levana.etat(fenetre, modele.jour, fuseau: fuseau, enIsrael: true)
        switch etat {
        case .dans(let jours):
            #expect(levana.etat == Libelle.pluriel("levana_dans", quantite: jours, .entier(jours)))
            #expect(!levana.etatMisEnAvant)
        case .ceSoir:
            #expect(levana.etat == Libelle("levana_ce_soir"))
            #expect(levana.etatMisEnAvant)
        case .dernierSoir:
            #expect(levana.etat == Libelle("levana_dernier_soir"))
            #expect(levana.etatMisEnAvant)
        case .pasCeSoir(let chome):
            #expect(levana.etat == Libelle(chome == .chabbat ? "levana_pas_chabbat" : "levana_pas_yom_tov"))
            #expect(!levana.etatMisEnAvant)
        }
        #expect(levana.lune == Levana.phase(Levana.soir(modele.jour, fuseau: fuseau)))
        #expect(!levana.sud)
        #expect(levana.route == .siddour("birkat_halevana"))
        #expect(levana.source == Libelle("levana_source", .libelle(Libelle(usage.libelle))))
        #expect(levana.jauge.debut <= levana.jauge.fin)
        let fr = try ZmanimEssais.traducteur()
        let lune = fr.texte(levana.luneTexte)
        #expect(lune.hasPrefix("Lune ce soir"))
        #expect(lune.contains(" %"))
        #expect(fr.texte(ZmanimLevana.fenetre(debut: "lun. 19 oct., 20:00", fin: "mar. 27 oct., 06:00"))
                == "Du lun. 19 oct., 20:00 au mar. 27 oct., 06:00")
        // L'usage choisi l'emporte sur celui du noussa'h.
        let trois = Levana.Usage.troisMiMois
        var reglages = ZmanimEssais.reglages(ville)
        reglages.setLevanaUsage(trois.cle)
        #expect(ZmanimVueJour.usageLevana(reglages) == trois)
        reglages.setLevanaAffichee(false)
        let (masquee, _) = try await fabriquer(reglages, "2026-10-12", fuseau: "Asia/Jerusalem")
        #expect(masquee.levana == nil)
    }

    @Test func auSudLaLuneEnMiroir() async throws {
        var reglages = Reglages()
        let melbourne = Zmanim.Lieu(nom: "Melbourne", latitude: -37.814, longitude: 144.96332, fuseau: "Australia/Melbourne")
        reglages.setLieuZmanim(melbourne, ville: nil, maintenant: 0)
        let (modele, _) = try await fabriquer(reglages, "2026-10-12", fuseau: "Australia/Melbourne")
        let levana = try #require(modele.levana)
        #expect(levana.sud)
    }

    @Test func laHalakhaDuJourDansLeLivreChoisi() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        var reglages = ZmanimEssais.reglages(ville)
        let (modele, magasin) = try await fabriquer(reglages, "2026-10-12", fuseau: "Asia/Jerusalem")
        let yalkut = try await ZmanimEssais.contenus.yalkutYosef()
        let texte = YalkutYosef.pour(yalkut, date: modele.jour, israel: true).first?.texte
        // Dans la police de lecture (serif par défaut), ses signes absents masqués (PoliceHebraique.appliquer).
        let attendu = texte.map { PoliceHebraique.masque($0, police: .serif) }
        let halakha = try #require(modele.halakha)
        #expect(halakha.debut == attendu)
        #expect(halakha.livre == Libelle("halakha_livre"))
        #expect(halakha.titre == Libelle("halakha_yomit_titre"))
        #expect(halakha.route == .halakha(modele.jour))
        // Le Ben Ish 'Haï seul.
        try await magasin.modifierReglages { $0.setSourceHalakha(.benIshHai) }
        let bih = try await ZmanimEssais.contenus.benIshHai()
        let texteBih = Halakha.pour(bih, date: modele.jour, enIsrael: true).first?.texte
        let attenduBih = texteBih.map { PoliceHebraique.masque($0, police: .serif) }
        let autre = modele.halakha
        #expect(autre?.debut == attenduBih)
        if attenduBih != nil {
            #expect(autre?.livre == Libelle("halakha_ben_ish_hai"))
        }
        // Une autre police de lecture : ses propres signes absents.
        try await magasin.modifierReglages { $0.setLecturePolice("david") }
        let david = texteBih.map { PoliceHebraique.masque($0, police: .david) }
        let enDavid = modele.halakha?.debut
        #expect(enDavid == david)
        // Masquée dans les réglages : la carte ne paraît pas.
        reglages.setHalakhaAffichee(false)
        let (masquee, _) = try await fabriquer(reglages, "2026-10-12", fuseau: "Asia/Jerusalem")
        #expect(masquee.halakha == nil)
    }

    @Test func laHillouaCinqNomsPuisLesAutres() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        var reglages = ZmanimEssais.reglages(ville)
        let (modele, _) = try await fabriquer(reglages, "2026-10-12", fuseau: "Asia/Jerusalem")
        let table = try await ZmanimEssais.hilloulot.table()
        // Le premier jour de l'année qui a plus de cinq hilloulot.
        let debut = try #require(JourCivil(iso: "2026-09-12"))
        var trouve: (JourCivil, [Hilloulot.Hilloula])?
        for i in 0..<385 {
            let jour = debut.plus(jours: i)
            let liste = Hilloulot.pour(table, date: jour, enIsrael: true)
            if liste.count > 5 {
                trouve = (jour, liste)
                break
            }
        }
        let (jour, liste) = try #require(trouve)
        modele.jour = jour
        let hilloula = try #require(modele.hilloula)
        let cinq = liste.prefix(5).map { PoliceHebraique.masque($0.he, police: .serif) }
        #expect(hilloula.noms == cinq)
        #expect(hilloula.autres == Libelle.pluriel("hilloula_autres", quantite: liste.count - 5, .entier(liste.count - 5)))
        #expect(hilloula.route == .hilloulot(jour))
        #expect(hilloula.tout == Libelle("hilloulot_tout"))
        // Un jour sans hilloula : pas de carte.
        for i in 0..<385 {
            let vide = debut.plus(jours: i)
            if Hilloulot.pour(table, date: vide, enIsrael: true).isEmpty {
                modele.jour = vide
                #expect(modele.hilloula == nil)
                break
            }
        }
        reglages.setHilloulotAffichees(false)
        let (masquee, _) = try await fabriquer(reglages, jour.iso, fuseau: "Asia/Jerusalem")
        #expect(masquee.hilloula == nil)
    }

    // MARK: L'allumage et Ta'hanoun

    @Test func lAllumageProposeLaCoutumeDeJerusalem() async throws {
        let jerusalem = try await ZmanimEssais.ville(ZmanimEssais.jerusalem)
        let (modele, _) = try await fabriquer(ZmanimEssais.reglages(jerusalem), "2026-10-12", fuseau: "Asia/Jerusalem")
        let carte = modele.allumageCarte
        #expect(carte.titre == Libelle("reglage_allumage"))
        #expect(carte.valeur == Libelle("reglage_allumage_valeur", .entier(18)))
        #expect(carte.proposition == Libelle("reglage_allumage_proposition"))
        let ids = carte.options.map { $0.id }
        #expect(ids == Zmanim.allumages)
        let choisies = carte.options.filter { $0.choisie }.map { $0.id }
        #expect(choisies == [18])
        let quarante = carte.options.last?.libelle
        #expect(quarante == Libelle("reglage_allumage_jerusalem", .entier(40)))
        try await modele.choisirAllumage(40)
        let apres = modele.allumageCarte
        #expect(apres.valeur == Libelle("reglage_allumage_jerusalem", .entier(40)))
        #expect(apres.proposition == nil)
        let fr = try ZmanimEssais.traducteur()
        #expect(fr.texte(apres.valeur) == "40 min avant la chki’a · coutume de Jérusalem")
        // Ailleurs, ni coutume ni proposition.
        let paris = try await ZmanimEssais.ville(ZmanimEssais.paris)
        var reglages = ZmanimEssais.reglages(paris)
        reglages.setAllumage(40)
        let (ailleurs, _) = try await fabriquer(reglages, "2026-10-12", fuseau: "Europe/Paris")
        let carteParis = ailleurs.allumageCarte
        #expect(carteParis.valeur == Libelle("reglage_allumage_valeur", .entier(40)))
        #expect(carteParis.proposition == nil)
    }

    @Test func tahanounDeFinDeTichriEnSfardSeulement() async throws {
        let ville = try await ZmanimEssais.ville(ZmanimEssais.paris)
        let (edot, _) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .edot), "2026-10-12", fuseau: "Europe/Paris")
        #expect(edot.tahanounCarte == nil)
        let (ashkenaz, _) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .ashkenaz), "2026-10-12", fuseau: "Europe/Paris")
        #expect(ashkenaz.tahanounCarte == nil)
        let (sfard, magasin) = try await fabriquer(ZmanimEssais.reglages(ville, nusah: .sefard), "2026-10-12", fuseau: "Europe/Paris")
        let carte = try #require(sfard.tahanounCarte)
        #expect(carte.valeur == Libelle("reglage_tahanoun_tichri_dit"))
        let choisies = carte.options.filter { $0.choisie }.map { $0.id }
        #expect(choisies == [0])
        try await sfard.choisirTahanounTichri(sans: true)
        #expect(magasin.reglages.sansTahanounFinTichri)
        let apres = try #require(sfard.tahanounCarte)
        #expect(apres.valeur == Libelle("reglage_tahanoun_tichri_sans"))
        let choisiesApres = apres.options.filter { $0.choisie }.map { $0.id }
        #expect(choisiesApres == [1])
    }

    // MARK: Le jour

    /// Laissé ouvert jusqu'au lendemain : le jour d'alors passe à aujourd'hui ; un autre jour choisi reste.
    @Test func leJourSuitLHorlogeAuRetour() async throws {
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let fuseau = try #require(Fuseau("Asia/Jerusalem"))
        let horloge = ZmanimHorlogeMobile(DateHeure(jour, heure: 23), fuseau: fuseau)
        let modele = ZmanimModele(magasin: .enMemoire(), horloge: horloge)
        await modele.apparaitre()
        modele.disparaitre()
        horloge.avancer(heures: 2)
        await modele.apparaitre()
        #expect(modele.jour.iso == "2026-10-13")
        #expect(modele.estAujourdhui)
        // Un autre jour choisi exprès reste affiché : le 15, quand aujourd'hui est devenu le 14.
        modele.jourSuivant()
        modele.jourSuivant()
        modele.disparaitre()
        horloge.avancer(heures: 24)
        await modele.apparaitre()
        #expect(modele.jour.iso == "2026-10-15")
        #expect(!modele.estAujourdhui)
        // Sans contenus ni traducteur : ni halakha, ni hilloula, ni choix du lieu.
        #expect(modele.halakha == nil)
        #expect(modele.hilloula == nil)
        let sansChoix = modele.choixLieu == nil
        #expect(sansChoix)
        #expect(modele.langue == "fr")
    }

    /// L'app crée l'onglet à son lancement : ouvert pour la première fois le lendemain, il montre aujourd'hui
    /// (Android : `LocalDate.now()` à chaque onResume).
    @Test func lOngletOuvertLeLendemainDeSaCreationMontreAujourdhui() async throws {
        let jour = try #require(JourCivil(iso: "2026-10-12"))
        let fuseau = try #require(Fuseau("Asia/Jerusalem"))
        let horloge = ZmanimHorlogeMobile(DateHeure(jour, heure: 22), fuseau: fuseau)
        let modele = ZmanimModele(magasin: .enMemoire(), horloge: horloge)
        #expect(modele.jour.iso == "2026-10-12")
        horloge.avancer(heures: 3)
        await modele.apparaitre()
        #expect(modele.jour.iso == "2026-10-13")
        #expect(modele.estAujourdhui)
    }
}
