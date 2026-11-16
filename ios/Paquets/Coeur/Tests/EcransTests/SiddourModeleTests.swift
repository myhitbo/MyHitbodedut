import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La liste du siddour (SiddurActivity) sur les siddourim exportés : la suggestion de l'heure (heures fixes sans
/// lieu, zmanim avec), le Hallel de 'Hanouka, Birkat haIlanot au nord et au sud, la Méguila, les livres, les
/// groupes et leurs lignes, les mentions des licences, le nusah, la ligne des marque-pages.
///
/// Restent au test d'interface : le bandeau et ses couleurs, les illustrations sur leur panneau, l'ondulation au
/// toucher, le dialogue du nusah, la navigation vers le lecteur, Tehilim et le Tikoun.
@Suite("Modèle du siddour")
@MainActor
struct SiddourModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private static let jerusalem = Zmanim.Lieu(nom: "Jérusalem", latitude: 31.76904, longitude: 35.21633,
                                               fuseau: "Asia/Jerusalem")
    private static let sydney = Zmanim.Lieu(nom: "Sydney", latitude: -33.86785, longitude: 151.20732,
                                            fuseau: "Australia/Sydney")

    private func fabriquer(_ reglages: Reglages = Reglages(), jour: JourCivil, heure: Int, minute: Int = 0,
                           fuseau nom: String = "Asia/Jerusalem", langue: String = "fr") throws -> (SiddourModele, Magasin) {
        let fuseau = try #require(Fuseau(nom))
        let magasin = Magasin.enMemoire(Enregistrement(reglages: reglages))
        let horloge = HorlogeFixe(DateHeure(jour, heure: heure, minute: minute), fuseau: fuseau)
        return (SiddourModele(magasin: magasin, contenus: Self.contenus, horloge: horloge, langue: langue), magasin)
    }

    private func diaspora(_ nusah: Nusah = .edot) -> Reglages {
        var r = Reglages()
        r.setSiddurNusah(nusah)
        r.setInIsrael(false)
        return r
    }

    private func jour(_ iso: String) throws -> JourCivil {
        try #require(JourCivil(iso: iso))
    }

    /// Le premier jour de semaine à partir de `iso` qui remplit `condition` (en diaspora).
    private func premierJour(depuis iso: String, _ condition: (CalendrierJuif.Jour) -> Bool) throws -> JourCivil {
        var d = try jour(iso)
        for _ in 0..<500 {
            let j = CalendrierJuif.jour(d, enIsrael: false)
            if d.jourDeSemaine < 6 && condition(j) { return d }
            d = d.plus(jours: 1)
        }
        Issue.record("aucun jour depuis \(iso)")
        return d
    }

    // MARK: La suggestion de l'heure

    @Test func sansLieuLaSuggestionSuitLHorloge() async throws {
        let siddur = try await Self.contenus.siddur(.edot)
        let cas: [(Int, Int, String)] = [(4, 59, "tikoun_hatsot"), (5, 0, "birkot_hachahar"), (8, 0, "chaharit"),
                                         (12, 30, "minha"), (20, 0, "arvit"), (22, 30, "chema_coucher")]
        for (heure, minute, attendu) in cas {
            let (m, _) = try fabriquer(diaspora(), jour: jour("2026-11-17"), heure: heure, minute: minute)
            await m.actualiser()
            #expect(m.moment == attendu)
            let ids = m.suggestions.map { $0.id }
            let existe = siddur.texte(attendu) != nil
            #expect(ids == (existe ? [attendu] : []), "\(heure):\(minute)")
            if let premiere = m.suggestions.first {
                #expect(premiere.image == SiddurMoment.illustration(attendu))
                #expect(premiere.route == .lecture(.siddour(attendu)))
                let titre = siddur.texte(attendu).map { PoliceHebraique.masque($0.titre.he, police: .serif) }
                #expect(premiere.hebreu == titre)
            }
        }
    }

    @Test func avecUnLieuLaSuggestionSuitSesZmanim() async throws {
        var r = diaspora()
        r.setLieuZmanim(Self.jerusalem, ville: nil, maintenant: 0)
        let date = try jour("2026-11-17")
        let zmanim = Zmanim.jour(lieu: Self.jerusalem, date: date)
        let coucher = zmanim.first { $0.cle == "chkia" }?.instant
        let chkia = try #require(coucher)
        let fuseau = try #require(Fuseau("Asia/Jerusalem"))
        // Entre la chki'a et la sortie des étoiles : aucun texte n'est suggéré.
        let creux = Int64((chkia.timeIntervalSince1970 * 1000).rounded(.down)) + 60_000
        let magasin = Magasin.enMemoire(Enregistrement(reglages: r))
        let m = SiddourModele(magasin: magasin, contenus: Self.contenus,
                              horloge: HorlogeFixe(maintenant: creux, fuseau: fuseau), langue: "fr")
        await m.actualiser()
        #expect(m.moment == nil)
        let vides = m.suggestions.isEmpty
        #expect(vides)
        // Le matin, Cha'harit.
        let (matin, _) = try fabriquer(r, jour: date, heure: 8)
        await matin.actualiser()
        #expect(matin.moment == "chaharit")
    }

    @Test func leHallelDeHanoukaSousChaharit() async throws {
        let date = try premierJour(depuis: "2026-11-17") { $0.fetes.contains("hanouka") }
        let (m, _) = try fabriquer(diaspora(), jour: date, heure: 8)
        await m.actualiser()
        let ids = m.suggestions.map { $0.id }
        #expect(ids == ["chaharit", "hallel"])
        let images = m.suggestions.map { $0.image }
        #expect(images == ["char_tefillin", "scene_hanukkah"])
        // L'après-midi, pas de Hallel.
        let (apresMidi, _) = try fabriquer(diaspora(), jour: date, heure: 15)
        await apresMidi.actualiser()
        let tard = apresMidi.suggestions.map { $0.id }
        #expect(tard == ["minha"])
    }

    @Test func birkatHailanotEnNissanAuNordEtEnElloulAuSud() async throws {
        let nissan = try premierJour(depuis: "2027-01-01") { $0.moisHebreu == CalendrierJuif.Mois.nissan }
        let (nord, _) = try fabriquer(diaspora(), jour: nissan, heure: 15)
        await nord.actualiser()
        let ids = nord.suggestions.map { $0.id }
        #expect(ids == ["minha", "birkat_hailanot"])
        #expect(nord.suggestions.last?.image == "scene_nature")

        var sud = diaspora()
        sud.setLieuZmanim(Self.sydney, ville: nil, maintenant: 0)
        let (enNissan, _) = try fabriquer(sud, jour: nissan, heure: 15, fuseau: "Australia/Sydney")
        await enNissan.actualiser()
        let auSud = enNissan.suggestions.map { $0.id }
        #expect(!auSud.contains("birkat_hailanot"))
        let eloul = try premierJour(depuis: "2027-06-01") { $0.moisHebreu == CalendrierJuif.Mois.eloul }
        let (enEloul, _) = try fabriquer(sud, jour: eloul, heure: 15, fuseau: "Australia/Sydney")
        await enEloul.actualiser()
        let fleurs = enEloul.suggestions.map { $0.id }
        #expect(fleurs.contains("birkat_hailanot"))
    }

    @Test func laMeguilaAPourim() async throws {
        let pourim = try premierJour(depuis: "2027-01-01") { $0.fetes.contains("pourim") }
        let (matin, _) = try fabriquer(diaspora(), jour: pourim, heure: 8)
        await matin.actualiser()
        let esther = matin.suggestions.last
        #expect(esther?.id == "meguilat_esther")
        #expect(esther?.route == .lecture(.livre("meguilat_esther")))
        #expect(esther?.image == "char_purim")
        // La veille au soir, sous Arvit.
        let (veille, _) = try fabriquer(diaspora(), jour: pourim.plus(jours: -1), heure: 20)
        await veille.actualiser()
        let ids = veille.suggestions.map { $0.id }
        #expect(ids == ["arvit", "meguilat_esther"])
        // Un jour ordinaire, pas de Méguila.
        let (autre, _) = try fabriquer(diaspora(), jour: pourim.plus(jours: 7), heure: 8)
        await autre.actualiser()
        let sans = autre.suggestions.map { $0.id }
        #expect(!sans.contains("meguilat_esther"))
    }

    // MARK: Les livres et les groupes

    @Test func tehilimEtLeTikounCoteACote() async throws {
        let (m, _) = try fabriquer(diaspora(), jour: jour("2026-11-17"), heure: 8)
        await m.actualiser()
        let routes = m.livres.map { $0.route }
        #expect(routes == [.tehilim, .tikkun])
        let images = m.livres.map { $0.image }
        #expect(images == ["char_tehilim", "char_torah"])
        let noms = m.livres.map { $0.hebreu.cle }
        #expect(noms == ["siddur_tehilim_he", "siddur_tikkun_he"])
        #expect(m.titreLivres.cle == "siddur_books")
        #expect(m.libelleSuggestion.cle == "siddur_maintenant")
    }

    @Test(arguments: Nusah.allCases)
    func lesGroupesEtLeursTextesDansLOrdreDuFichier(_ nusah: Nusah) async throws {
        let siddur = try await Self.contenus.siddur(nusah)
        let (m, _) = try fabriquer(diaspora(nusah), jour: jour("2026-11-17"), heure: 8)
        await m.actualiser()
        #expect(m.etat == .pret)
        let groupes = m.groupes
        let ids = groupes.map { $0.id }
        let cles = siddur.groupes.map { $0.cle }
        #expect(ids == cles)
        for g in groupes {
            let textes = g.textes.map { $0.id }
            let attendus = siddur.du(g.id).map { $0.id }
            #expect(textes == attendus, "\(g.id)")
        }
        // En français, la traduction sous l'hébreu ; un texte emprunté dit d'où il vient.
        let lignes = groupes.flatMap { $0.textes }
        for texte in siddur.textes where lignes.contains(where: { $0.id == texte.id }) {
            let ligne = lignes.first { $0.id == texte.id }
            var morceaux: [String] = []
            if !texte.titre.pour("fr").egalUnites(texte.titre.he) { morceaux.append(texte.titre.pour("fr")) }
            if let emprunt = texte.emprunt { morceaux.append(emprunt.pour("fr")) }
            let attendu = morceaux.isEmpty ? nil : morceaux.joined(separator: " · ")
            #expect(ligne?.detail == attendu, "\(texte.id)")
            #expect(ligne?.route == .lecture(.siddour(texte.id)))
        }
        // Les mentions des licences, au pied.
        let mentions = m.mentions
        if siddur.mentions.isEmpty {
            #expect(mentions == nil)
        } else {
            #expect(mentions == Libelle("siddur_sources", .texte(siddur.mentions.joined(separator: " ; "))))
        }
    }

    @Test func enHebreuPasDeTraductionSaufLEmprunt() async throws {
        let siddur = try await Self.contenus.siddur(.ashkenaz)
        let (m, _) = try fabriquer(diaspora(.ashkenaz), jour: jour("2026-11-17"), heure: 8, langue: "he")
        await m.actualiser()
        let lignes = m.groupes.flatMap { $0.textes }
        for texte in siddur.textes where lignes.contains(where: { $0.id == texte.id }) {
            let detail = lignes.first { $0.id == texte.id }?.detail
            #expect(detail == texte.emprunt?.he, "\(texte.id)")
        }
        let traductions = m.groupes.compactMap { $0.traduction }
        #expect(traductions.isEmpty)
        let enPolice = m.groupes.filter { $0.hebreuPolice }.count
        #expect(enPolice == m.groupes.count)
    }

    // MARK: Le nusah

    @Test func leNusahSeChoisitSurLeBandeau() async throws {
        let (m, magasin) = try fabriquer(diaspora(.edot), jour: jour("2026-11-17"), heure: 8)
        await m.actualiser()
        let edot = try await Self.contenus.siddur(.edot)
        #expect(m.nusah == edot.nusah.fr)
        #expect(m.descriptionNusah.cle == "siddur_choose")
        let choisi = m.optionsNusah.filter { $0.choisi }.map { $0.valeur }
        #expect(choisi == [.edot])
        m.choixNusahOuvert = true
        try await m.choisirNusah(.ashkenaz)
        #expect(!m.choixNusahOuvert)
        #expect(magasin.reglages.siddurNusah == .ashkenaz)
        let ashkenaz = try await Self.contenus.siddur(.ashkenaz)
        #expect(m.nusah == ashkenaz.nusah.fr)
        let montres = m.groupes.flatMap { $0.textes }.count
        let attendus = ashkenaz.groupes.flatMap { ashkenaz.du($0.cle) }.count
        #expect(montres == attendus)
    }

    // MARK: Les marque-pages

    @Test func laLigneDesMarquePagesNeCompteQueLeSiddour() async throws {
        let (sans, _) = try fabriquer(diaspora(), jour: jour("2026-11-17"), heure: 8)
        await sans.actualiser()
        #expect(sans.signets == nil)

        let marques = [
            MarquesPages.Marque(cle: "s:chaharit", nusah: "edot", section: 1, bloc: 2, apercu: "א"),
            MarquesPages.Marque(cle: "s:inexistant", nusah: "edot", section: 0, bloc: 0, apercu: "ב"),
            MarquesPages.Marque(cle: "l:likoutei_moharan", nusah: "", section: 3, bloc: 1, apercu: "ג"),
            MarquesPages.Marque(cle: "t:tehilim", nusah: "", section: 23, bloc: 1, apercu: "ד"),
            MarquesPages.Marque(cle: "s:minha", nusah: "edot", section: 0, bloc: 4, apercu: "ה"),
        ]
        var r = diaspora()
        var brut = r.brut
        brut["marques_pages"] = .chaine(MarquesPages.encoder(marques))
        r = Reglages(brut: brut)
        let (m, _) = try fabriquer(r, jour: jour("2026-11-17"), heure: 8)
        await m.actualiser()
        let signets = try #require(m.signets)
        #expect(signets.nombre == 2)
        #expect(signets.titre.cle == "marques_titre")
        #expect(signets.icone == "ic_marque_priere")
        #expect(signets.route == .marquesPages(recueil: "s"))
    }
}
