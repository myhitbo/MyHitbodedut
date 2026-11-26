import Foundation
import Synchronization
import Testing
import Coeur
@testable import Ecrans

/// Une horloge qu'on avance : pour l'écran resté ouvert jusqu'au lendemain (onRestart).
final class LectureHorlogeReglable: Horloge, Sendable {
    private let temps: Mutex<Int64>
    let fuseau: Fuseau

    init(_ maintenant: Int64, fuseau: Fuseau) {
        temps = Mutex(maintenant)
        self.fuseau = fuseau
    }

    var maintenant: Int64 {
        temps.withLock { $0 }
    }

    func avancer(_ millis: Int64) {
        temps.withLock { $0 += millis }
    }
}

/// Le lecteur (SiddurLectureActivity, ReglagesLecture) sur les contenus exportés du dépôt : les lignes du jour de
/// Cha'harit dans les trois rites (un jour ordinaire, un Roch 'Hodech, un jeûne), la place de chaque paragraphe,
/// les signets, la taille qui garde le même bloc en tête (Likoutei Moharan, signet 300), la reprise, les
/// favoris, les marque-pages, les replis et le bouton de lecture.
///
/// Restent au test d'interface : les captures de Cha'harit, le défilement réel jusqu'au signet 300 et la ligne
/// qui reste en tête à l'écran après le changement de taille, l'animation des replis (et « Réduire les
/// animations »), l'appui long, le double toucher, la barre du bas, l'absence d'image à l'écran.
@Suite("Modèle du lecteur")
@MainActor
struct LectureModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private func fuseau() throws -> Fuseau {
        try #require(Fuseau("Asia/Jerusalem"))
    }

    /// Un lecteur sur `cible`, l'horloge arrêtée à `heure` du jour `iso` à Jérusalem.
    private func fabriquer(_ cible: LectureCible, reglages: Reglages = Reglages(), jour: JourCivil? = nil,
                           heure: Int = 8, langue: String = "fr") throws -> (LectureModele, Magasin) {
        let date: JourCivil
        if let jour {
            date = jour
        } else {
            date = try #require(JourCivil(iso: "2026-11-17"))
        }
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let horloge = HorlogeFixe(DateHeure(date, heure: heure), fuseau: try fuseau())
        return (LectureModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: langue, cible: cible),
                magasin)
    }

    private func reglages(_ nusah: Nusah, israel: Bool = true) -> Reglages {
        var r = Reglages()
        r.setSiddurNusah(nusah)
        r.setInIsrael(israel)
        return r
    }

    /// Le premier jour à partir de `iso` qui remplit `condition` (en Israël).
    private func premierJour(depuis iso: String, _ condition: (CalendrierJuif.Jour) -> Bool) throws -> JourCivil {
        var d = try #require(JourCivil(iso: iso))
        for _ in 0..<400 {
            if condition(CalendrierJuif.jour(d, enIsrael: true)) { return d }
            d = d.plus(jours: 1)
        }
        Issue.record("aucun jour depuis \(iso)")
        return d
    }

    private typealias C = CalendrierJuif.C

    private func jourOrdinaire() throws -> JourCivil {
        let exclues = [C.rochHodech, C.jeune, C.hanouka, C.chabbat, C.asseretYemeiTechouva, C.yaaleVeyavo, C.hallel,
                       C.finTichri, C.pourim]
        return try premierJour(depuis: "2026-11-17") { j in
            j.conditions.contains(C.tahanounChaharit) && !exclues.contains { j.conditions.contains($0) }
                && (j.date.jourDeSemaine == 3 || j.date.jourDeSemaine == 4)
        }
    }

    private func rochHodech() throws -> JourCivil {
        try premierJour(depuis: "2027-01-01") { j in
            j.conditions.contains(C.rochHodech) && !j.conditions.contains(C.chabbat) && !j.conditions.contains(C.hanouka)
        }
    }

    private func jeune() throws -> JourCivil {
        try premierJour(depuis: "2026-11-17") { j in
            j.conditions.contains(C.jeune) && !j.conditions.contains(C.tichaBeav) && !j.conditions.contains(C.chabbat)
        }
    }

    // MARK: Ce que les lignes contiennent

    private func etiquettes(_ m: LectureModele) -> [String] {
        m.lignes.compactMap { ligne -> String? in
            if case .etiquette(let l) = ligne.contenu { return l.cle }
            return nil
        }
    }

    private func replis(_ m: LectureModele) -> [LectureRepli] {
        m.lignes.compactMap { ligne -> LectureRepli? in
            if case .replie(let r) = ligne.contenu { return r }
            return nil
        }
    }

    private func renvois(_ m: LectureModele) -> [LectureRenvoi] {
        m.lignes.compactMap { ligne -> LectureRenvoi? in
            if case .renvoi(let r) = ligne.contenu { return r }
            return nil
        }
    }

    private func blocs(_ m: LectureModele) -> [(id: String, bloc: LectureBloc)] {
        m.lignes.compactMap { ligne -> (id: String, bloc: LectureBloc)? in
            if case .bloc(let b) = ligne.contenu { return (id: ligne.id, bloc: b) }
            return nil
        }
    }

    // MARK: Cha'harit dans les trois rites (critère de la feuille de route)

    @Test(arguments: Nusah.allCases)
    func chaharitUnJourOrdinaire(_ nusah: Nusah) async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(nusah), jour: jourOrdinaire())
        await m.charger()
        #expect(m.etat == .pret)
        // En tête, en français, la note du siddour sans traduction (COUV-02), puis celle du jour : la date hébraïque
        // qui décide des ajouts, et la région.
        guard case .note(let premiere)? = m.lignes.first?.contenu else {
            Issue.record("pas de note en tête")
            return
        }
        #expect(premiere.cle == "lecture_sans_traduction")
        guard m.lignes.count > 1, case .note(let note) = m.lignes[1].contenu else {
            Issue.record("pas de note du jour")
            return
        }
        #expect(note.cle == "siddur_jour_ajouts")
        #expect(note.arguments.count == 2)
        #expect(note.arguments.last == .libelle(Libelle("region_israel")))
        let lues = etiquettes(m)
        #expect(!lues.contains("ajout_yaale_veyavo"))
        // Règle du 26/11 : un ajout du calendrier hors de son jour est retiré, sans bandeau replié.
        let yaale = replis(m).contains { $0.nom.cle == "ajout_yaale_veyavo" }
        #expect(!yaale)
        // Ce qui ne se dit qu'avec un minyan, une occasion, n'est jamais « du jour » : « toucher pour lire ».
        let toucher = replis(m).contains { $0.etat.cle == "siddur_toucher_lire" }
        #expect(toucher)
        let aucunRenvoi = renvois(m).isEmpty
        #expect(aucunRenvoi)
        // Des sections titrées : la bande de signets.
        let signets = m.signets.count
        #expect(signets > 1)
    }

    @Test(arguments: Nusah.allCases)
    func chaharitUnRochHodech(_ nusah: Nusah) async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(nusah), jour: rochHodech())
        await m.charger()
        #expect(m.etat == .pret)
        let lues = etiquettes(m)
        #expect(lues.contains("ajout_yaale_veyavo"), "\(nusah.rawValue) : \(lues)")
        let yaaleReplie = replis(m).contains { $0.nom.cle == "ajout_yaale_veyavo" }
        #expect(!yaaleReplie)
        // Le Hallel du jour, ouvert d'un geste.
        let hallel = renvois(m).contains { $0.route == .lecture(.siddour("hallel")) }
        #expect(hallel, "\(nusah.rawValue)")
        // Un ajout du jour est mis en évidence.
        let duJour = blocs(m).contains { $0.bloc.duJour }
        #expect(duJour)
    }

    @Test(arguments: Nusah.allCases)
    func chaharitUnJourDeJeune(_ nusah: Nusah) async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(nusah), jour: jeune())
        await m.charger()
        #expect(m.etat == .pret)
        let lues = etiquettes(m)
        // 26/11, Q2 : le particulier en évidence (Edot, à Cha'harit) ; l'officiant replié sous « Avec minyan ».
        #expect(!lues.contains("ajout_anenou_officiant"), "\(nusah.rawValue) : \(lues)")
        if nusah == .edot {
            #expect(lues.contains("ajout_anenou_particulier"), "\(nusah.rawValue) : \(lues)")
        }
        if nusah != .edot {
            // Avinou malkénou, les jeûnes publics (Ashkenaz, Sfard).
            #expect(lues.contains("ajout_avinou_malkenou"), "\(nusah.rawValue) : \(lues)")
        }
    }

    // MARK: La place de chaque paragraphe

    /// Sur tous les textes des trois siddourim, trois jours, tout replié puis tout déplié : chaque bloc montré a
    /// la place du bloc du texte qu'il montre (le même, ou le même avec la seule formule du jour), les places
    /// croissent, et tout déplié, aucun bloc n'est montré deux fois (depuis le 26/11, un ajout du calendrier hors de
    /// son jour est retiré : tout déplié ne montre plus tout le texte).
    @Test func chaqueBlocMontreASaPlace() async throws {
        let jours = try [jourOrdinaire(), rochHodech(), jeune()]
        var echecs: [String] = []
        for nusah in Nusah.allCases {
            let siddur = try await Self.contenus.siddur(nusah)
            let toutes = try await Self.contenus.annotations(nusah)
            for texte in siddur.textes {
                let annotations = toutes[texte.id] ?? []
                for date in jours {
                    let conditions = CalendrierJuif.jour(date, enIsrael: true).conditions
                    let fermes = SiddurJour.lignes(texte, annotations, conditions, nusah: nusah, enIsrael: true)
                    // Tout déplié, replis imbriqués compris (la double annotation, audit du 16/11) : on ouvre
                    // jusqu'à ce qu'aucun repli neuf n'apparaisse.
                    var cles = Set<String>()
                    var ouverts = fermes
                    while true {
                        var neuves = cles
                        for ligne in ouverts {
                            if case .replie(let cle, _, _, _, _) = ligne { neuves.insert(cle) }
                        }
                        if neuves == cles { break }
                        cles = neuves
                        ouverts = SiddurJour.lignes(texte, annotations, conditions, ouverts: cles, nusah: nusah, enIsrael: true)
                    }
                    for (tout, lignes) in [(false, fermes), (true, ouverts)] {
                        let nom = "\(nusah.rawValue)/\(texte.id)/\(date.iso)/\(tout ? "ouvert" : "fermé")"
                        if let faute = verifier(texte, lignes, LectureLignes.places(texte, annotations, lignes), tout: tout) {
                            echecs.append(nom + " : " + faute)
                        }
                    }
                }
            }
        }
        #expect(echecs.isEmpty, "\(echecs.prefix(10))")
    }

    private func verifier(_ texte: SiddurTexte, _ lignes: [SiddurJour.Ligne], _ places: [LecturePlace?],
                          tout: Bool) -> String? {
        guard places.count == lignes.count else { return "nombre" }
        var precedente: LecturePlace?
        var vues = Set<LecturePlace>()
        for (k, ligne) in lignes.enumerated() {
            guard case .bloc(let bloc, _, _) = ligne else {
                if places[k] != nil { return "place hors d'un bloc à \(k)" }
                continue
            }
            guard let p = places[k] else { return "bloc sans place à \(k)" }
            guard p.section < texte.sections.count, p.bloc < texte.sections[p.section].blocs.count else {
                return "place hors du texte \(p) à \(k)"
            }
            let original = texte.sections[p.section].blocs[p.bloc]
            // La seule formule du jour (26/11, Q8) : une variante retirée ou remplacée (« מגדול »), quel que soit le style.
            let duJour = original.consigne == bloc.consigne && original.fr == bloc.fr && original.en == bloc.en
                && !bloc.texte.estBlanc
            if original != bloc && !duJour { return "bloc différent à \(p)" }
            if let q = precedente, (q.section, q.bloc) >= (p.section, p.bloc) { return "ordre à \(p)" }
            precedente = p
            if vues.contains(p) { return "montré deux fois : \(p)" }
            vues.insert(p)
        }
        // Tout déplié, au moins ce que montre le texte replié.
        if tout && vues.isEmpty && !texte.sections.isEmpty { return "déplié : aucun bloc" }
        return nil
    }

    // MARK: Le jour de la prière, les notes de traduction (audit du 16/11)

    /// Sans lieu, la nuit va de 19 h à 6 h : la condition « nuit » s'ajoute au jour de la prière (la Méguila).
    @Test func laNuitSAjouteAuJourDeLaPriere() throws {
        let (soir, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot), jour: jourOrdinaire(), heure: 22)
        let nuit = soir.jourDeLaPriere.conditions.contains(CalendrierJuif.C.nuit)
        #expect(nuit)
        let (matin, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot), jour: jourOrdinaire(), heure: 10)
        let jour = matin.jourDeLaPriere.conditions.contains(CalendrierJuif.C.nuit)
        #expect(!jour)
    }

    /// Un livre traduit en partie, ou automatiquement : on le dit quand une autre langue que l'hébreu est demandée.
    @Test func lesNotesDeTraduction() {
        let partielle = LectureModele.notesDeTraduction(livre: true, traduit: true, chapitresTraduits: 3, chapitres: 10,
                                                        auto: true, langues: .heFr).map(\.libelle)
        #expect(partielle == [Libelle("lecture_traduction_partielle", .entier(3), .entier(10)),
                              Libelle("lecture_traduction_auto")])
        let hebreu = LectureModele.notesDeTraduction(livre: true, traduit: true, chapitresTraduits: 3, chapitres: 10,
                                                     auto: true, langues: .he)
        #expect(hebreu.isEmpty)
        let siddour = LectureModele.notesDeTraduction(livre: false, traduit: true, chapitresTraduits: 3, chapitres: 10,
                                                      auto: true, langues: .heFr)
        #expect(siddour.isEmpty)
        let complet = LectureModele.notesDeTraduction(livre: true, traduit: true, chapitresTraduits: 10, chapitres: 10,
                                                      auto: false, langues: .heEn)
        #expect(complet.isEmpty)
    }

    /// « Pas de Ta'hanoun aujourd'hui » (ZmanimActivity) : la condition ponctuelle vaut pour la tefila du jour.
    @Test func pasDeTahanounAujourdhui() throws {
        var r = reglages(.edot)
        let date = try jourOrdinaire()
        r.setSansTahanounLe(date, sans: true)
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: r, jour: date, heure: 8)
        let conditions = SiddurJour.avecSansTahanoun(m.jourDeLaPriere.conditions, r.sansTahanounLe(date))
        #expect(conditions.contains(CalendrierJuif.C.sansTahanounPonctuel))
    }

    // MARK: Les deux catégories du 26/11 : la région, le bouton « תחנון », le jour voisin, la lecture de la Torah

    /// Israël ou diaspora non confirmé (Q7) : une carte après les notes quand le texte en dépend ; la réponse confirme le
    /// statut, à la main, et la carte s'en va.
    @Test func laQuestionIsraelOuDiasporaQuandLeTexteEnDepend() async throws {
        // Le mardi 17/11/2026 : « ותן טל ומטר » se dit en Israël, pas encore en diaspora.
        let (m, magasin) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot), jour: JourCivil(iso: "2026-11-17"))
        await m.charger()
        let question = m.lignes.first { if case .questionRegion = $0.contenu { true } else { false } }
        #expect(question?.contenu == .questionRegion(Libelle("siddur_region_question")))
        #expect(question?.id == "question:region")
        m.poserQuestionRegion()
        #expect(m.questionRegionOuverte)
        try await m.repondreRegion(israel: false)
        #expect(!m.questionRegionOuverte)
        #expect(magasin.reglages.inIsraelManuel)
        #expect(!magasin.reglages.inIsrael(fuseauTelephone: "Asia/Jerusalem"))
        #expect(magasin.reglages.regionConfirmee)
        let encore = m.lignes.contains { if case .questionRegion = $0.contenu { true } else { false } }
        #expect(!encore)
        // Un jour où rien ne diffère (le 19/01/2027) : pas de question, même sans statut confirmé.
        let (calme, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot), jour: JourCivil(iso: "2027-01-19"))
        await calme.charger()
        let aucune = calme.lignes.contains { if case .questionRegion = $0.contenu { true } else { false } }
        #expect(!aucune)
    }

    /// « Pas de Ta'hanoun aujourd'hui » dans la barre (Q1) : à Cha'harit et à Min'ha seulement ; il retire le Ta'hanoun,
    /// garde למנצח, et se dit à la lecture d'écran.
    @Test func leBoutonTahanounDeLaBarre() async throws {
        let date = try #require(JourCivil(iso: "2026-11-16"))  // un lundi
        let (m, magasin) = try fabriquer(.siddour("chaharit"), reglages: reglages(.sefard), jour: date)
        await m.charger()
        #expect(m.avecTahanoun)
        #expect(!m.sansTahanoun)
        #expect(m.etatTahanoun == Libelle("lecture_tahanoun_non"))
        let avant = m.lignes.count
        try await m.basculerTahanoun()
        #expect(m.sansTahanoun)
        #expect(m.etatTahanoun == Libelle("lecture_tahanoun_oui"))
        #expect(magasin.reglages.sansTahanounLe(date))
        #expect(m.lignes.count < avant)
        try await m.basculerTahanoun()
        #expect(!magasin.reglages.sansTahanounLe(date))
        let (arvit, _) = try fabriquer(.siddour("arvit"), reglages: reglages(.sefard), jour: date)
        #expect(!arvit.avecTahanoun)
        let (livre, _) = try fabriquer(.livre("likoutei_moharan"))
        #expect(!livre.avecTahanoun)
    }

    /// Le soir (Q6) : au Birkat haMazon d'un vendredi, sans lieu dès 16 h, les ajouts du Chabbat qui vient restent
    /// repliés, « pas aujourd'hui » ; le matin, ils sont retirés.
    @Test func leJourVoisinAuBirkatHamazon() async throws {
        let vendredi = try #require(JourCivil(iso: "2026-11-20"))
        let (soir, _) = try fabriquer(.siddour("birkat_hamazon"), reglages: reglages(.ashkenaz, israel: false), jour: vendredi,
                                      heure: 17)
        await soir.charger()
        let chabbat = replis(soir).filter { $0.nom.cle == "ajout_chabbat" }
        #expect(!chabbat.isEmpty)
        let pasAujourdhui = chabbat.allSatisfy { $0.etat.cle == "siddur_pas_aujourdhui" }
        #expect(pasAujourdhui)
        let (matin, _) = try fabriquer(.siddour("birkat_hamazon"), reglages: reglages(.ashkenaz, israel: false), jour: vendredi,
                                       heure: 10)
        await matin.charger()
        let aucun = replis(matin).contains { $0.nom.cle == "ajout_chabbat" }
        #expect(!aucun)
    }

    /// La lecture de la Torah (26/11) : un jeudi, repliée à sa place dans Cha'harit ; dépliée, ses trois montées, dont le
    /// texte se lit à part (« Chargement… » d'abord), puis le pied « Replier ».
    @Test func laLectureDeLaTorahUnJeudi() async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.ashkenaz, israel: false),
                                   jour: JourCivil(iso: "2026-11-26"))
        await m.charger()
        let bandeaux = m.lignes.compactMap { l -> LectureTorahBandeau? in
            if case .lecture(let b) = l.contenu { return b }
            return nil
        }
        #expect(bandeaux.count == 1)
        let bandeau = try #require(bandeaux.first)
        #expect(bandeau.cle == "lecture:chaharit:0")
        #expect(bandeau.titre == Libelle("lecture_titre", .texte("Vayichla\u{2019}h"),
                                         .libelle(Libelle.pluriel("lecture_montees", quantite: 3, .entier(3)))))
        #expect(bandeau.etat == Libelle("siddur_toucher_lire"))
        #expect(!bandeau.ouvert)
        m.basculer(bandeau.cle)
        await m.attendreTexteLecture()
        #expect(m.texteLectureLu)
        let passages = m.lignes.compactMap { l -> LectureTorahPassage? in
            if case .passage(let p) = l.contenu { return p }
            return nil
        }
        #expect(passages.count == 3)
        #expect(passages.first?.entete == "Cohen \u{00B7} Berèchit 32:4\u{2013}6")
        let versets = passages.first?.versets ?? []
        #expect(versets.map { $0.numero } == [4, 5, 6])
        let dansPanneau = passages.allSatisfy { $0.dansPanneau }
        #expect(dansPanneau)
        let pied = m.lignes.contains { $0.contenu == .pied(cle: bandeau.cle) }
        #expect(pied)
        let ouvert = m.lignes.contains { if case .lecture(let b) = $0.contenu { b.ouvert } else { false } }
        #expect(ouvert)
        // Le pied replie la lecture.
        m.replierDepuisLePied(bandeau.cle)
        let replie = m.lignes.contains { if case .passage = $0.contenu { true } else { false } }
        #expect(!replie)
        // Un mardi, pas de lecture.
        let (mardi, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.ashkenaz, israel: false),
                                       jour: JourCivil(iso: "2026-11-24"))
        await mardi.charger()
        let aucune = mardi.lignes.contains { if case .lecture = $0.contenu { true } else { false } }
        #expect(!aucune)
    }

    // MARK: Likoutei Moharan : le signet 300, la taille, la reprise (critère de la feuille de route)

    @Test func likouteiMoharanAuSignet300LaTailleGardeLeMemeBloc() async throws {
        let (m, magasin) = try fabriquer(.livre("likoutei_moharan"))
        await m.charger()
        #expect(m.etat == .pret)
        let signets = m.signets
        #expect(signets.count == 411)
        try #require(signets.count > 300)
        #expect(signets[300].texte == "תנינא תורה טו")

        // 411 chapitres : un bouton « Chapitres (411) » et une liste filtrable, non une bande (FLECTURE-03).
        #expect(m.enChapitres)
        #expect(m.boutonChapitres?.nombre == 411)
        #expect(m.boutonChapitres?.titre == Libelle("siddur_chapitres"))
        #expect(!m.feuilleChapitres)
        m.ouvrirListeChapitres()
        #expect(m.feuilleChapitres)
        #expect(m.chapitresFiltres.count == 411)
        m.filtreChapitres = "תנינא תורה טו"
        let trouves = m.chapitresFiltres.map(\.id)
        #expect(trouves.contains(300))
        m.ouvrirChapitre(300)
        // Le chapitre touché ferme la liste, et la prochaine s'ouvre entière.
        #expect(!m.feuilleChapitres)
        #expect(m.filtreChapitres.isEmpty)
        let demande = try #require(m.defilement)
        #expect(demande.ligne == signets[300].ligne)
        #expect(!demande.anime)
        #expect(m.signetActif == nil)

        // La vue montre le titre et les paragraphes qui le suivent.
        let rangTrouve = m.lignes.firstIndex { $0.id == signets[300].ligne }
        let rang = try #require(rangTrouve)
        m.visibles(m.lignes[rang..<(rang + 6)].map { $0.id }, enBas: false)
        let tete = try #require(m.ligneDeTete?.id)
        #expect(tete == signets[300].ligne)

        try await m.changerTaille(plus: true)
        #expect(m.pourcent == 110)
        let apres = try #require(m.defilement)
        #expect(apres.ligne == tete)
        #expect(apres.jeton > demande.jeton)
        #expect(m.ligneDeTete?.id == tete)

        // La police, les langues et la nuit gardent aussi le même bloc en tête.
        try await m.choisirPolice(.david)
        #expect(m.ligneDeTete?.id == tete)
        try await m.choisirLangues(.he)
        #expect(m.ligneDeTete?.id == tete)
        try await m.basculerNuit()
        #expect(m.ligneDeTete?.id == tete)
        #expect(m.sombre)

        // La reprise : la ligne de tête est gardée, et un livre reprend toujours, même le lendemain.
        try await m.quitter()
        let gardee = LecturePreferences.positionLecture(magasin.reglages, cle: "l:likoutei_moharan",
                                                        maintenant: Int64.max / 2)
        // Le rang a pu bouger d'une ligne : en hébreu seul, la note de la traduction partielle n'est plus là.
        let rangFinal = m.lignes.firstIndex { $0.id == tete }
        #expect(gardee == rangFinal)
        #expect(LecturePreferences.derniereLecture(magasin.reglages) == "l:likoutei_moharan")
        let lendemain = HorlogeFixe(DateHeure(try #require(JourCivil(iso: "2026-11-18")), heure: 9), fuseau: try fuseau())
        let rouvert = LectureModele(magasin: magasin, contenus: Self.contenus, horloge: lendemain, langue: "fr",
                                    cible: .livre("likoutei_moharan"))
        await rouvert.charger()
        #expect(rouvert.defilement?.ligne == tete)
        #expect(rouvert.ligneDeTete?.id == tete)
    }

    /// Le plus long livre (le Kitsour Yalkout Yossef, `Captures.plusLongLivre`) : 1 048 chapitres derrière un seul
    /// bouton, et non 1 048 signets posés d'un coup ; la liste rouverte après un filtre repart entière, et un mot
    /// trouve son chapitre (Chapitres.filtrer), le dernier compris.
    @Test func lePlusLongLivreNOuvreQuUnBoutonDeChapitres() async throws {
        let (m, _) = try fabriquer(.livre("yalkut_yosef_kitsour"))
        await m.charger()
        #expect(m.etat == .pret)
        #expect(m.enChapitres)
        #expect(m.boutonChapitres?.nombre == 1_048)
        #expect(m.signetActif == nil)
        m.ouvrirListeChapitres()
        m.filtreChapitres = "zzz introuvable"
        #expect(m.chapitresFiltres.isEmpty)
        m.feuilleChapitres = false
        m.ouvrirListeChapitres()
        #expect(m.filtreChapitres.isEmpty)
        #expect(m.chapitresFiltres.count == 1_048)
        m.filtreChapitres = "הלכות חליצה ויבום"
        let dernier = try #require(m.chapitresFiltres.last)
        #expect(dernier.id == 1_047)
        #expect(dernier.texte.contains("חליצה"))
        m.ouvrirChapitre(dernier.id)
        #expect(m.defilement?.ligne == dernier.ligne)
        #expect(!m.feuilleChapitres)
    }

    /// Un texte de quarante sections au plus garde sa bande de signets : ni bouton ni liste.
    @Test func unTexteCourtGardeSaBandeDeSignets() async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"))
        await m.charger()
        #expect(!m.signets.isEmpty)
        #expect(m.signets.count <= LectureModele.seuilChapitres)
        #expect(!m.enChapitres)
        #expect(m.boutonChapitres == nil)
        m.ouvrirListeChapitres()
        #expect(!m.feuilleChapitres)
    }

    @Test func unLivreNAPasDeNusahNiDAjouts() async throws {
        let (m, _) = try fabriquer(.livre("meguilat_esther"))
        await m.charger()
        #expect(m.etat == .pret)
        #expect(!m.avecNusah)
        let options = m.optionsNusah
        #expect(options.isEmpty)
        #expect(m.horaire == nil)
        #expect(m.iconeMarques == "ic_marque_etude")
        let notes = m.lignes.filter { if case .note = $0.contenu { return true } else { return false } }
        #expect(notes.isEmpty)
        // Les étiquettes : le nom traduit, puis « Livres ».
        let etiquettes = m.etiquettes
        #expect(etiquettes.last == "Livres")
    }

    @Test func unLivreSansTraductionLeDitQuandOnEnDemandeUne() async throws {
        let livre = """
        {"groupes": [], "textes": [{"id": "essai", "groupe": "g", "titre": {"he": "ספר", "fr": "Livre", "en": "Book"},
         "sections": [{"titre": "א", "blocs": [{"t": "שלום עולם"}]}, {"titre": "ב", "blocs": [{"t": "ברוך"}]}]}]}
        """
        let donnees = Data(livre.utf8)
        let contenus = ContenusApp(lecteur: { chemin in chemin == "livre_essai.json" ? donnees : nil })
        let horloge = HorlogeFixe(maintenant: 0, fuseau: try fuseau())
        let francais = LectureModele(magasin: .enMemoire(), contenus: contenus, horloge: horloge, langue: "fr",
                                     cible: .livre("essai"))
        await francais.charger()
        #expect(francais.etat == .pret)
        #expect(francais.lignes.first?.contenu == .note(Libelle("lecture_sans_traduction")))
        // Sans nom de recueil (pas d'index des livres), aucune étiquette vide.
        #expect(francais.etiquettes == ["Livre"])
        let hebreu = LectureModele(magasin: .enMemoire(), contenus: contenus, horloge: horloge, langue: "he",
                                   cible: .livre("essai"))
        await hebreu.charger()
        let premiere = hebreu.lignes.first?.id
        #expect(premiere == "titre:0")
        #expect(hebreu.signets.count == 2)
    }

    @Test func unTexteAbsentFermeLEcran() async throws {
        let (siddour, _) = try fabriquer(.siddour("inexistant"))
        await siddour.charger()
        #expect(siddour.etat == .introuvable)
        let (livre, _) = try fabriquer(.livre("inexistant"))
        await livre.charger()
        #expect(livre.etat == .introuvable)
    }

    // MARK: Le bandeau

    @Test func leBandeauDeChaharit() async throws {
        var r = reglages(.edot)
        r.setLieuZmanim(Zmanim.Lieu(nom: "Jérusalem", latitude: 31.76904, longitude: 35.21633, fuseau: "Asia/Jerusalem"),
                        ville: nil, maintenant: 0)
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: r)
        await m.charger()
        let siddur = try await Self.contenus.siddur(.edot)
        let texte = try #require(siddur.texte("chaharit"))
        #expect(m.titre == PoliceHebraique.masque(texte.titre.he, police: .serif))
        #expect(m.etiquettes == [texte.titre.fr, siddur.nusah.fr])
        #expect(m.etiquettesDescription == texte.titre.fr + ", " + siddur.nusah.fr)
        let horaire = try #require(m.horaire)
        #expect(horaire.cle == "banniere_chaharit")
        #expect(horaire.arguments.count == 1)
        #expect(m.iconeMarques == "ic_marque_priere")
        #expect(m.symboleFavori == "\u{2606}")
    }

    @Test func lHoraireDeMinhaASesDeuxBornesEtRienSansLieu() async throws {
        var r = reglages(.edot)
        r.setLieuZmanim(Zmanim.Lieu(nom: "Jérusalem", latitude: 31.76904, longitude: 35.21633, fuseau: "Asia/Jerusalem"),
                        ville: nil, maintenant: 0)
        let (minha, _) = try fabriquer(.siddour("minha"), reglages: r, heure: 14)
        await minha.charger()
        let h = try #require(minha.horaire)
        #expect(h.cle == "banniere_minha")
        #expect(h.arguments.count == 2)
        let (sansLieu, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot))
        await sansLieu.charger()
        #expect(sansLieu.horaire == nil)
        let (autre, _) = try fabriquer(.siddour("birkot_hachahar"), reglages: r)
        await autre.charger()
        #expect(autre.horaire == nil)
    }

    // MARK: Favoris et marque-pages

    @Test func lEtoileAjouteEtRetireLeFavori() async throws {
        let (m, magasin) = try fabriquer(.siddour("minha"), reglages: reglages(.edot))
        await m.charger()
        #expect(!m.estFavori)
        #expect(m.descriptionFavori.cle == "favori_ajouter")
        try await m.basculerFavori()
        #expect(m.estFavori)
        #expect(m.symboleFavori == "\u{2605}")
        #expect(m.descriptionFavori.cle == "favori_retirer")
        #expect(LecturePreferences.favoris(magasin.reglages) == ["s:minha"])
        try await m.basculerFavori()
        #expect(!m.estFavori)
    }

    @Test func unAppuiLongPosePuisRetireLeMarquePage() async throws {
        let (m, magasin) = try fabriquer(.siddour("chaharit"), reglages: reglages(.sefard))
        await m.charger()
        let premierTrouve = blocs(m).first { !$0.bloc.consigne }
        let premier = try #require(premierTrouve)
        #expect(m.marquesDuTexte.isEmpty)
        try await m.basculerMarque(premier.bloc)
        #expect(m.message == Libelle("marque_posee"))
        let marques = m.marquesDuTexte
        #expect(marques.count == 1)
        #expect(marques.first?.cle == "s:chaharit")
        #expect(marques.first?.nusah == "sefard")
        #expect(marques.first?.section == premier.bloc.place.section)
        #expect(marques.first?.bloc == premier.bloc.place.bloc)
        #expect(marques.first?.apercu == premier.bloc.apercu)
        // La ligne marquée le montre.
        let marquee = blocs(m).first { $0.id == premier.id }?.bloc.marque
        #expect(marquee == true)
        // Les marque-pages d'un nusah ne sont pas ceux d'un autre.
        try await m.choisirNusah(.edot)
        #expect(m.marquesDuTexte.isEmpty)
        try await m.choisirNusah(.sefard)
        let retrouvee = m.marquesDuTexte.count
        #expect(retrouvee == 1)
        let repriseTrouvee = blocs(m).first { $0.id == premier.id }
        let reprise = try #require(repriseTrouvee)
        try await m.basculerMarque(reprise.bloc)
        #expect(m.message == Libelle("marque_retiree"))
        #expect(LecturePreferences.marques(magasin.reglages).isEmpty)
        m.effacerMessage()
        #expect(m.message == nil)
    }

    @Test func ouvertDepuisUnMarquePageOnYVa() async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot), jour: jourOrdinaire())
        await m.charger()
        let cible = try #require(blocs(m).dropFirst(40).first)
        let place = cible.bloc.place
        let ouvert = LectureModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages(.edot))),
                                   contenus: Self.contenus,
                                   horloge: HorlogeFixe(DateHeure(try jourOrdinaire(), heure: 8), fuseau: try fuseau()),
                                   langue: "fr", cible: LectureCible(id: "chaharit", marque: place))
        await ouvert.charger()
        #expect(ouvert.defilement?.ligne == cible.id)
        #expect(ouvert.ligneDeTete?.id == cible.id)
        // Sans marque-page ni place gardée, rien ne bouge.
        #expect(m.defilement == nil)
        // Revenu d'un renvoi, la vue rappelle charger() (.task) : Android ne refait pas onCreate, on ne retourne
        // pas au marque-page.
        ouvert.allerAuSignet(1)
        let ailleurs = ouvert.defilement
        await ouvert.charger()
        #expect(ouvert.defilement == ailleurs)
    }

    /// Pas d'image à l'écran de lecture (on ne prie pas devant une image) : le modèle ne rend que des icônes.
    @Test func leLecteurNeRendQueDesIcones() async throws {
        for cible in [LectureCible.siddour("chaharit"), LectureCible.livre("nichmat")] {
            let (m, _) = try fabriquer(cible, reglages: reglages(.edot))
            await m.charger()
            #expect(m.etat == .pret)
            #expect(m.iconeMarques.hasPrefix("ic_"), "\(cible.id)")
        }
    }

    @Test func unMarquePageReplieMeneAuPremierParagrapheMontreDeSaSection() async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot), jour: jourOrdinaire())
        await m.charger()
        // Un groupe replié aujourd'hui : on le déplie pour connaître la place de son premier bloc.
        let groupe = replis(m).first { !$0.cle.hasPrefix("v") && !$0.cle.hasPrefix("\u{00A7}") }
        let repli = try #require(groupe)
        m.basculer(repli.cle)
        let rangTrouve = m.lignes.firstIndex { $0.id == "replie:" + repli.cle }
        let rangRepli = try #require(rangTrouve)
        guard case .bloc(let cache) = m.lignes[rangRepli + 1].contenu else {
            Issue.record("le repli ouvert n'est pas suivi de ses blocs")
            return
        }
        #expect(cache.dansPanneau)
        #expect(!cache.estompe)
        m.basculer(repli.cle)
        m.allerA(cache.place)
        let attendu = blocs(m).first { $0.bloc.place.section >= cache.place.section && $0.bloc.place != cache.place }
        #expect(m.defilement?.ligne == attendu?.id)
    }

    @Test func laFeuilleDesMarquesVaALaPlace() async throws {
        let (m, _) = try fabriquer(.livre("chir_hachirim"))
        await m.charger()
        let b = try #require(blocs(m).last)
        try await m.basculerMarque(b.bloc)
        m.feuilleMarques = true
        let marque = try #require(m.marquesDuTexte.first)
        #expect(marque.nusah == "")
        m.allerALaMarque(marque)
        #expect(!m.feuilleMarques)
        #expect(m.defilement?.ligne == b.id)
    }

    // MARK: Les replis

    @Test func unAjoutDeplieSeLitDansSonPanneauEtSePlieDepuisSonPied() async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot), jour: jourOrdinaire())
        await m.charger()
        let avant = m.lignes.count
        let ferme = replis(m).first { !$0.ouvert && !$0.cle.hasPrefix("v") }
        let repli = try #require(ferme)
        m.basculer(repli.cle)
        #expect(m.lignes.count > avant)
        let rangTrouve = m.lignes.firstIndex { $0.id == "replie:" + repli.cle }
        let rang = try #require(rangTrouve)
        guard case .replie(let ouvert) = m.lignes[rang].contenu else {
            Issue.record("le bandeau a disparu")
            return
        }
        #expect(ouvert.ouvert)
        #expect(ouvert.etat.cle == "siddur_replier")
        let piedTrouve = m.lignes.firstIndex { $0.id == "pied:" + repli.cle }
        let pied = try #require(piedTrouve)
        #expect(pied > rang + 1)
        for ligne in m.lignes[(rang + 1)..<pied] {
            guard case .bloc(let b) = ligne.contenu else {
                Issue.record("une ligne qui n'est pas un bloc dans le panneau")
                continue
            }
            #expect(b.dansPanneau)
        }
        // Replié depuis le pied, le bandeau étant passé au-dessus de l'écran : on y revient, en douceur.
        m.visibles([m.lignes[pied].id], enBas: false)
        m.replierDepuisLePied(repli.cle)
        #expect(m.lignes.count == avant)
        let retour = try #require(m.defilement)
        #expect(retour.ligne == "replie:" + repli.cle)
        #expect(retour.anime)
    }

    // MARK: La reprise d'une prière

    @Test func unePriereNeReprendQueDansLesTroisHeures() async throws {
        let date = try #require(JourCivil(iso: "2026-11-17"))
        let horloge = LectureHorlogeReglable(try fuseau().millis(DateHeure(date, heure: 7)), fuseau: try fuseau())
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages(.edot)))
        let m = LectureModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: "fr",
                              cible: .siddour("chaharit"))
        await m.charger()
        let loin = try #require(m.lignes.dropFirst(30).first)
        m.visibles([loin.id], enBas: false)
        try await m.quitter()

        horloge.avancer(60 * 60 * 1000)
        let uneHeure = LectureModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: "fr",
                                     cible: .siddour("chaharit"))
        await uneHeure.charger()
        #expect(uneHeure.defilement?.ligne == loin.id)

        horloge.avancer(3 * 60 * 60 * 1000)
        let quatreHeures = LectureModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: "fr",
                                         cible: .siddour("chaharit"))
        await quatreHeures.charger()
        #expect(quatreHeures.defilement == nil)

        // Resté ouvert derrière d'autres applications au-delà de trois heures : il repart du début.
        m.revenir()
        #expect(m.defilement?.ligne == m.lignes.first?.id)
    }

    @Test func revenirAvantTroisHeuresNeBougeRien() async throws {
        let horloge = LectureHorlogeReglable(1_800_000_000_000, fuseau: try fuseau())
        let m = LectureModele(magasin: .enMemoire(Enregistrement(reglages: reglages(.edot))), contenus: Self.contenus,
                              horloge: horloge, langue: "fr", cible: .siddour("arvit"))
        await m.charger()
        let loin = try #require(m.lignes.dropFirst(10).first)
        m.visibles([loin.id], enBas: false)
        try await m.quitter()
        horloge.avancer(10 * 60 * 1000)
        let avant = m.defilement
        m.revenir()
        #expect(m.defilement == avant)
    }

    // MARK: Le bouton de lecture

    @Test func laTailleVaDeQuatreVingtsADeuxCentsPourCent() async throws {
        let (m, magasin) = try fabriquer(.livre("nichmat"))
        await m.charger()
        #expect(m.pourcent == 100)
        #expect(m.libellePourcent == Libelle("lecture_pourcent", .entier(100)))
        var vus: [Int] = []
        for _ in 0..<12 {
            try await m.changerTaille(plus: true)
            vus.append(m.pourcent)
        }
        #expect(vus == [110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 200, 200])
        #expect(m.descriptionPourcent == Libelle("lecture_taille", .entier(200)))
        try await m.tailleNormale()
        #expect(m.pourcent == 100)
        try await m.changerTaille(plus: false)
        try await m.changerTaille(plus: false)
        try await m.changerTaille(plus: false)
        #expect(m.pourcent == 80)
        #expect(magasin.reglages.lectureEchelle == 0.8)
    }

    @Test func laLuneEtSonEtat() async throws {
        let (m, magasin) = try fabriquer(.livre("nichmat"))
        await m.charger()
        #expect(!m.sombre)
        #expect(m.etatNuit.cle == "lecture_nuit_non")
        try await m.basculerNuit()
        #expect(m.sombre)
        #expect(m.etatNuit.cle == "lecture_nuit_oui")
        #expect(magasin.reglages.lectureSombre)
    }

    @Test func lesChoixDeLaBarre() async throws {
        let (m, magasin) = try fabriquer(.siddour("minha"), reglages: reglages(.ashkenaz), langue: "en")
        await m.charger()
        let polices = m.optionsPolice.map { $0.valeur }
        #expect(polices == PoliceHebraique.Police.allCases)
        let policeChoisie = m.optionsPolice.filter { $0.choisi }.map { $0.valeur }
        #expect(policeChoisie == [.serif])
        let languesChoisies = m.optionsLangues.filter { $0.choisi }.map { $0.valeur }
        #expect(languesChoisies == [.heEn])
        let noms = m.optionsNusah.map { $0.nom.cle }
        #expect(noms == ["siddur_nusah_edot", "siddur_nusah_sefard", "siddur_nusah_ashkenaz"])
        let nusahChoisi = m.optionsNusah.filter { $0.choisi }.map { $0.valeur }
        #expect(nusahChoisi == [.ashkenaz])
        try await m.choisirLangues(.fr)
        #expect(magasin.reglages.lectureLangues == "fr")
        let francais = m.optionsLangues.filter { $0.choisi }.map { $0.valeur }
        #expect(francais == [.fr])
        try await m.choisirPolice(.rachi)
        #expect(magasin.reglages.lecturePolice == "rachi")
        // Un autre nusah : on repart du début.
        try await m.choisirNusah(.edot)
        #expect(magasin.reglages.siddurNusah == .edot)
        #expect(m.etat == .pret)
        #expect(m.defilement?.ligne == m.lignes.first?.id)
    }

    @Test func laPastilleLaBarreEtLeMasque() async throws {
        let (m, magasin) = try fabriquer(.livre("nichmat"))
        await m.charger()
        #expect(m.pastilleVisible)
        #expect(!m.barreVisible)
        // Descendre efface la pastille, même lentement ; remonter la rend.
        m.defilementVertical(10)
        m.defilementVertical(10)
        #expect(!m.pastilleEffacee)
        m.defilementVertical(10)
        #expect(m.pastilleEffacee)
        m.defilementVertical(-30)
        #expect(!m.pastilleEffacee)
        m.defilementVertical(30)
        #expect(m.pastilleEffacee)
        m.toucherTexte()
        #expect(!m.pastilleEffacee)

        m.deplierBarre(true)
        #expect(m.barreVisible)
        #expect(!m.pastilleVisible)
        // La barre dépliée ne s'efface pas en défilant.
        m.defilementVertical(100)
        #expect(m.barreVisible)

        try await m.masquer()
        #expect(m.masquee)
        #expect(magasin.reglages.lectureMasquee)
        #expect(!m.barreVisible)
        #expect(!m.pastilleVisible)
        #expect(m.annonceMasque)
        m.toucherTexte()
        #expect(!m.pastilleVisible)

        try await m.retrouver()
        #expect(!m.masquee)
        #expect(m.barreVisible)
        #expect(!m.annonceMasque)
        m.deplierBarre(false)
        #expect(m.pastilleVisible)
    }

    @Test func leBoutonMasqueLeResteALaReouverture() async throws {
        var r = Reglages()
        r.setLectureMasquee(true)
        let (m, _) = try fabriquer(.livre("nichmat"), reglages: r)
        await m.charger()
        #expect(!m.pastilleVisible)
        #expect(!m.barreVisible)
    }

    // MARK: Les signets

    @Test func leSignetSuitLaLectureSaufLeSignetTouche() async throws {
        let (m, _) = try fabriquer(.siddour("chaharit"), reglages: reglages(.edot))
        await m.charger()
        let signets = m.signets
        try #require(signets.count > 3)
        #expect(m.signetActif == 0)
        let rangTrouve = m.lignes.firstIndex { $0.id == signets[2].ligne }
        let rang2 = try #require(rangTrouve)
        m.visibles([m.lignes[rang2 + 1].id, m.lignes[rang2 + 2].id], enBas: false)
        #expect(m.signetActif == 2)
        m.allerAuSignet(1)
        #expect(m.signetActif == 1)
        // Le doigt reprend la page : la section lue l'emporte de nouveau.
        m.visibles([m.lignes[rang2 + 1].id], enBas: false)
        #expect(m.signetActif == 1)
        m.debutGlisse()
        #expect(m.signetActif == 2)
        // Tout en bas, la dernière section commencée à l'écran.
        let dernierTrouve = m.lignes.firstIndex { $0.id == signets[signets.count - 1].ligne }
        let dernier = try #require(dernierTrouve)
        m.visibles([m.lignes[dernier - 1].id, m.lignes[dernier].id], enBas: true)
        #expect(m.signetActif == signets.count - 1)
    }

    @Test func unTexteDUneSectionNaPasDeBande() async throws {
        let (m, _) = try fabriquer(.livre("nichmat"))
        await m.charger()
        let signets = m.signets
        #expect(signets.isEmpty)
        #expect(m.signetActif == nil)
    }

    // MARK: Les préférences d'Android

    @Test func lesFavorisSontUneListeSepareeParDesBarres() {
        var r = Reglages(brut: ObjetJSON([("favoris", .chaine("s:a||l:b| "))]))
        #expect(LecturePreferences.favoris(r) == ["s:a", "l:b"])
        LecturePreferences.basculerFavori(&r, "s:c")
        #expect(LecturePreferences.favoris(r) == ["s:c", "s:a", "l:b"])
        LecturePreferences.basculerFavori(&r, "s:a")
        #expect(r.brut["favoris"] == .chaine("s:c|l:b"))
    }

    @Test func laRepriseSuitLesReglesDeStore() {
        var r = Reglages()
        LecturePreferences.setPositionLecture(&r, cle: "s:arvit", position: 12, maintenant: 1_000)
        #expect(LecturePreferences.positionLecture(r, cle: "s:arvit", maintenant: 1_000 + 60_000) == 12)
        #expect(LecturePreferences.positionLecture(r, cle: "s:arvit", maintenant: 1_000 + LecturePreferences.priereRepriseMs) == nil)
        #expect(LecturePreferences.positionLecture(r, cle: "s:arvit", maintenant: 999) == nil)
        LecturePreferences.setPositionLecture(&r, cle: "l:x", position: 3, maintenant: 1_000)
        #expect(LecturePreferences.positionLecture(r, cle: "l:x", maintenant: Int64.max) == 3)
        LecturePreferences.setPositionLecture(&r, cle: "l:x", position: 0, maintenant: 1_000)
        #expect(LecturePreferences.positionLecture(r, cle: "l:x", maintenant: 2_000) == nil)
        #expect(LecturePreferences.derniereLecture(r) == "l:x")
        #expect(r.brut["position:s:arvit"] == .entier(12))
        #expect(r.brut["position_t:s:arvit"] == .entier(1_000))
    }

    @Test func uneRouteDeMarquePage() {
        let tehilim = MarquesPages.Marque(cle: "t:tehilim", nusah: "", section: 23, bloc: 4, apercu: "")
        #expect(LectureRoute.marque(tehilim) == .tehilimMarque(psaume: 23, verset: 4))
        let livre = MarquesPages.Marque(cle: "l:likoutei_etsot", nusah: "", section: 2, bloc: 5, apercu: "")
        #expect(LectureRoute.marque(livre) == .lecture(LectureCible(id: "likoutei_etsot", livre: true,
                                                                    marque: LecturePlace(section: 2, bloc: 5))))
        let priere = MarquesPages.Marque(cle: "s:minha", nusah: "edot", section: 0, bloc: 1, apercu: "")
        #expect(LectureRoute.marque(priere) == .lecture(LectureCible(id: "minha", marque: LecturePlace(section: 0, bloc: 1))))
        #expect(LectureCible.livre("a").cle == "l:a")
        #expect(LectureCible.siddour("a").cle == "s:a")
    }

    // MARK: Les chaînes

    /// Chaque clé que le siddour et le lecteur rendent existe dans le catalogue, en français, en anglais et en
    /// hébreu.
    @Test func lesClesSontAuCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        var cles = [
            "siddur_jour_ajouts", "region_israel", "region_diaspora", "lecture_sans_traduction", "siddur_aujourdhui",
            "siddur_replier", "siddur_toucher_lire", "siddur_pas_aujourdhui", "siddur_seul", "banniere_chaharit",
            "banniere_minha", "banniere_arvit", "favori_retirer", "favori_ajouter", "marque_posee", "marque_retiree",
            "marques_titre", "marques_aucun", "siddur_signets", "lecture_reglages", "lecture_nuit", "lecture_police",
            "lecture_langues", "lecture_masquer", "lecture_replier", "lecture_plus", "lecture_moins",
            "lecture_pourcent", "lecture_taille", "lecture_nuit_oui", "lecture_nuit_non", "lecture_masque_info",
            "lecture_annuler_masque", "siddur_choose", "siddur_title", "siddur_maintenant", "siddur_books",
            "siddur_tehilim_he", "tehilim_title", "siddur_tikkun_he", "tikkun_title", "siddur_sources",
            "recherche_tout", "livres_title",
        ]
        cles += Nusah.allCases.map { "siddur_nusah_" + $0.rawValue }
        cles += PoliceHebraique.Police.allCases.map { $0.libelle }
        cles += LanguesTexte.Mode.allCases.map { $0.libelle }
        var manquantes: [String] = []
        for cle in cles {
            for langue in ["fr", "en", "he"] where catalogue.valeur(cle, langue: langue) == nil {
                manquantes.append(cle + "/" + langue)
            }
        }
        #expect(manquantes.isEmpty, "\(manquantes)")
    }
}
