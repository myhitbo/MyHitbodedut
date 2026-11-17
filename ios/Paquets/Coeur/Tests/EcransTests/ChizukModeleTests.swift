import Foundation
import Synchronization
import Testing
import Coeur
@testable import Ecrans

/// L'écran « J'ai besoin de 'hizouk » (ChizukActivity) : le tirage sans remise et son sac dans les réglages,
/// « Un autre » qui ne redonne jamais le texte qui vient de sortir, les textes gardés, la carte dans les langues
/// de lecture, le partage. Sur un petit fichier écrit ici (dont le mélange est fixé), et sur chizuk.json exporté.
///
/// Restent au test d'interface : le fondu de la carte et la remontée en haut (`changements`), la cascade
/// d'entrée et « Réduire les animations », la feuille de partage elle-même, la taille des blocs de texte.
@Suite("Modèle du 'hizouk")
@MainActor
struct ChizukModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    /// Trois textes publiables (a, b, c), dont un d'une édition sans vocalisation (b), et un texte non relu (x).
    private static let petit = """
    {"_meta": {"version": "t", "editions": {
        "pd": {"titre": "PD", "licence": "Public Domain", "nikkoud_ok": true},
        "nu": {"titre": "N", "licence": "non déclarée", "nikkoud_ok": false}}},
     "items": [
       {"id": "a", "moments": ["ouverture"], "edition": "pd", "ref": "Tehilim 1:1", "he": "\u{05D0}\u{05B7}",
        "fr": "A fr", "en": "A en", "statut_verif": "verifie_texte", "relu": true},
       {"id": "b", "moments": [], "edition": "nu", "ref": "Si'hot HaRan 2", "he": "\u{05D1}", "fr": "B fr", "en": "", "statut_verif": "verifie_texte", "relu": true},
       {"id": "c", "moments": ["blocage"], "edition": "pd", "ref": "Michlé 24:16", "he": "\u{05D2}",
        "fr": "", "en": "C en", "statut_verif": "verifie_texte", "relu": true},
       {"id": "x", "moments": [], "edition": "pd", "ref": "Tehilim 2:2", "he": "\u{05D3}",
        "fr": "X", "en": "X", "statut_verif": "a_verifier", "relu": false}
     ]}
    """

    /// Rien de publiable : un seul texte, non relu.
    private static let rienAPublier = """
    {"_meta": {"version": "t", "editions": {}},
     "items": [{"id": "x", "moments": [], "edition": "pd", "ref": "Tehilim 2:2", "he": "\u{05D3}",
                "fr": "X", "en": "X", "statut_verif": "a_verifier", "relu": false}]}
    """

    private static func contenusEcrits(_ json: String) -> ContenusApp {
        let donnees = Data(json.utf8)
        return ContenusApp(lecteur: { chemin in chemin == "chizuk.json" ? donnees : nil })
    }

    /// Le modèle sur le petit fichier, son magasin et la persistance qui reçoit ses écritures. Le mélange par
    /// défaut garde l'ordre du vivier : a, b, c, a, b, c…
    private static func fabriquer(_ reglages: Reglages = Reglages(), langue: String = "fr", debug: Bool = false,
                                  json: String? = nil,
                                  melange: @escaping @Sendable ([String]) -> [String] = { $0 })
        -> (modele: ChizukModele, magasin: Magasin, persistance: PersistanceEnMemoire) {
        let enregistrement = Enregistrement(reglages: reglages)
        let persistance = PersistanceEnMemoire(enregistrement)
        let magasin = Magasin(persistance: persistance, enregistrement: enregistrement)
        let modele = ChizukModele(magasin: magasin, contenus: contenusEcrits(json ?? petit), langue: langue,
                                  debug: debug, melange: melange)
        return (modele, magasin, persistance)
    }

    /// Un mélange qui garde l'ordre au premier remplissage, le renverse au second, et ainsi de suite : au
    /// second, le texte qui ouvrirait le cycle est celui qui vient de clore le précédent.
    private final class Alternance: Sendable {
        private let appels = Mutex(0)

        func melanger(_ ids: [String]) -> [String] {
            let rang: Int = appels.withLock { valeur in
                valeur += 1
                return valeur
            }
            return rang % 2 == 1 ? ids : Array(ids.reversed())
        }
    }

    // MARK: Le tirage et son sac

    @Test func lOuvertureTireUnTexteEtGardeLeSac() async throws {
        let (modele, magasin, persistance) = Self.fabriquer()
        #expect(modele.etat == .chargement)
        #expect(modele.carte == nil)
        await modele.charger()
        #expect(modele.etat == .pret)
        #expect(modele.courantId == "a")
        // Le sac et le dernier sorti, sous les clés et dans la forme d'Android.
        let sac = magasin.reglages.brut["chizuk_bag_demande"]
        #expect(sac == .chaine("b\nc"))
        let dernier = magasin.reglages.brut["chizuk_last_demande"]
        #expect(dernier == .chaine("a"))
        #expect(ChizukSac.sac(magasin.reglages, moment: .demande) == ["b", "c"])
        #expect(ChizukSac.dernier(magasin.reglages, moment: .demande) == "a")
        let ecrites = await persistance.ecrituresReglages
        #expect(ecrites == 1)
        let gardees = await persistance.enregistrement.reglages
        #expect(gardees == magasin.reglages)
        // Le texte non relu n'est pas du vivier d'une release.
        #expect(modele.changements == 0)
    }

    @Test func rouvrirLaVueNeTirePasUnAutreTexte() async {
        let (modele, _, persistance) = Self.fabriquer()
        await modele.charger()
        await modele.charger()
        #expect(modele.courantId == "a")
        let ecrites = await persistance.ecrituresReglages
        #expect(ecrites == 1)
    }

    @Test func lEcranRecreeReprendSonTexteSansTirer() async {
        let (modele, magasin, persistance) = Self.fabriquer()
        await modele.charger(restaurer: "c")
        #expect(modele.courantId == "c")
        let ecrites = await persistance.ecrituresReglages
        #expect(ecrites == 0)
        #expect(ChizukSac.sac(magasin.reglages, moment: .demande).isEmpty)
        // Un texte retiré des données depuis : un tirage.
        let (autre, _, _) = Self.fabriquer()
        await autre.charger(restaurer: "retire")
        #expect(autre.courantId == "a")
    }

    @Test func unAutreSuitLeSacSansRemise() async throws {
        let (modele, magasin, _) = Self.fabriquer()
        await modele.charger()
        var tires = [modele.courantId]
        for _ in 0..<5 {
            try await modele.unAutre()
            tires.append(modele.courantId)
        }
        #expect(tires == ["a", "b", "c", "a", "b", "c"])
        #expect(modele.changements == 5)
        #expect(ChizukSac.dernier(magasin.reglages, moment: .demande) == "c")
        #expect(ChizukSac.sac(magasin.reglages, moment: .demande).isEmpty)
    }

    @Test func unAutreNeRedonneJamaisLeTexteQuiVientDeSortir() async throws {
        let alternance = Alternance()
        let (modele, _, _) = Self.fabriquer(melange: { alternance.melanger($0) })
        await modele.charger()
        var tires = [modele.courantId]
        for _ in 0..<11 {
            try await modele.unAutre()
            tires.append(modele.courantId)
        }
        // Au second remplissage, le mélange renversé ouvrirait sur c, qui vient de sortir : c passe en fin de sac.
        #expect(tires == ["a", "b", "c", "b", "a", "c", "a", "b", "c", "b", "a", "c"])
        for rang in 1..<tires.count {
            #expect(tires[rang] != tires[rang - 1], "tirage \(rang)")
        }
    }

    @Test func surChizukJsonChaqueTexteUneFoisParCycleEtJamaisDeuxFoisDeSuite() async throws {
        let magasin = Magasin.enMemoire()
        let modele = ChizukModele(magasin: magasin, contenus: Self.contenus, langue: "fr", debug: false)
        await modele.charger()
        let chizuk = try await Self.contenus.chizuk()
        let vivier = ChizukRules.forMoment(chizuk, .demande, debug: false).map { $0.id }
        #expect(vivier.count == 171)
        var tires: [String] = [try #require(modele.courantId)]
        for _ in 0..<399 {
            try await modele.unAutre()
            tires.append(try #require(modele.courantId))
        }
        for rang in 1..<tires.count {
            #expect(tires[rang] != tires[rang - 1], "tirage \(rang)")
        }
        // Sans remise : le premier cycle passe par chacun des 171 textes, une fois.
        let premierCycle = Set(tires.prefix(171))
        #expect(premierCycle.count == 171)
        #expect(premierCycle == Set(vivier))
    }

    @Test func unTexteRetireDuSacNeRessortPas() async {
        var reglages = Reglages()
        ChizukSac.poser(&reglages, moment: .demande, sac: ["retire", "c", "b"], dernier: "a")
        let (modele, magasin, _) = Self.fabriquer(reglages)
        await modele.charger()
        #expect(modele.courantId == "c")
        #expect(ChizukSac.sac(magasin.reglages, moment: .demande) == ["b"])
    }

    @Test func uneEcritureRefuseeMontreQuandMemeLeTexte() async throws {
        let (modele, magasin, persistance) = Self.fabriquer()
        await modele.charger()
        await persistance.faireEchouer(true)
        var echec = false
        do {
            try await modele.unAutre()
        } catch {
            echec = true
        }
        #expect(echec)
        #expect(modele.courantId == "b")
        #expect(modele.carte?.id == "b")
        #expect(modele.changements == 1)
        // La prochaine écriture emporte tout ce qui est resté en mémoire.
        await persistance.faireEchouer(false)
        try await modele.unAutre()
        #expect(modele.courantId == "c")
        let gardees = await persistance.enregistrement.reglages
        #expect(gardees == magasin.reglages)
    }

    @Test func rienAPublierCacheLaCarte() async {
        let (modele, magasin, _) = Self.fabriquer(json: Self.rienAPublier)
        await modele.charger()
        #expect(modele.etat == .pret)
        #expect(modele.courantId == nil)
        #expect(modele.carte == nil)
        #expect(!modele.actionsActives)
        #expect(ChizukSac.dernier(magasin.reglages, moment: .demande) == nil)
        let partage = modele.textePartage { $0.cle }
        #expect(partage == nil)
        // « Garder » ne fait rien sans texte.
        do {
            try await modele.garder()
        } catch {
            Issue.record("garder a levé : \(error)")
        }
        #expect(ChizukSac.favoris(magasin.reglages).isEmpty)
    }

    @Test func enDebugUnTexteNonReluPasseAvecSonBadge() async throws {
        let (modele, _, _) = Self.fabriquer(debug: true, json: Self.rienAPublier)
        await modele.charger()
        let carte = try #require(modele.carte)
        #expect(carte.id == "x")
        #expect(carte.aRelire)
        // Un texte publiable n'a pas de badge, même en debug.
        let (publiable, _, _) = Self.fabriquer(debug: true)
        await publiable.charger()
        #expect(publiable.carte?.aRelire == false)
    }

    @Test func unContenuIlisibleSeDitEnErreur() async {
        let modele = ChizukModele(magasin: Magasin.enMemoire(), contenus: ContenusApp(lecteur: { _ in nil }),
                                  langue: "fr", debug: false)
        await modele.charger()
        #expect(modele.etat == .erreur)
        #expect(modele.carte == nil)
        // Une nouvelle tentative relit.
        await modele.charger()
        #expect(modele.etat == .erreur)
    }

    // MARK: La carte

    @Test func laCarteEnFrancaisLHebreuPuisLaTraduction() async throws {
        let (modele, _, _) = Self.fabriquer()
        await modele.charger()
        #expect(modele.modeLangues == .heFr)
        let carte = try #require(modele.carte)
        #expect(carte.texte == "\u{05D0}\u{05B7}")
        #expect(carte.langueTexte == "he")
        #expect(carte.texteDroiteAGauche)
        #expect(carte.second == "A fr")
        #expect(carte.reference == "Tehilim 1:1")
        #expect(carte.moment == Libelle("chizuk_demande_title"))
        #expect(carte.image == "char_open_arms")
        #expect(!carte.aRelire)
        #expect(modele.titre == Libelle("chizuk_demande_title"))
        #expect(modele.sousTitre == Libelle("chizuk_demande_hint"))
        #expect(modele.image == "char_open_arms")
    }

    @Test func uneEditionSansLicenceDeVocalisationMontreLHebreuNu() async throws {
        let (modele, _, _) = Self.fabriquer(langue: "en")
        await modele.charger(restaurer: "b")
        let carte = try #require(modele.carte)
        #expect(carte.texte == "\u{05D1}")
        // Pas d'anglais pour ce texte : l'hébreu seul.
        #expect(carte.second == nil)
        #expect(carte.reference == Reference.localise("Si'hot HaRan 2", "en"))
        #expect(carte.reference == "Sichot HaRan 2")
    }

    @Test func enHebreuRienQueLHebreu() async throws {
        let (modele, _, _) = Self.fabriquer(langue: "he")
        await modele.charger()
        let carte = try #require(modele.carte)
        #expect(modele.modeLangues == .he)
        #expect(carte.texte == "\u{05D0}\u{05B7}")
        #expect(carte.second == nil)
        #expect(carte.reference == Reference.localise("Tehilim 1:1", "he"))
    }

    @Test func lesLanguesDeLectureChoisiesChangentLaCarte() async throws {
        var francais = Reglages()
        francais.setLectureLangues("fr")
        let (seul, _, _) = Self.fabriquer(francais)
        await seul.charger()
        let carte = try #require(seul.carte)
        #expect(carte.texte == "A fr")
        #expect(carte.langueTexte == "fr")
        #expect(!carte.texteDroiteAGauche)
        #expect(carte.second == nil)
        // c n'a pas de français : l'hébreu reste, de droite à gauche.
        seul.montrer("c")
        let sansFrancais = try #require(seul.carte)
        #expect(sansFrancais.texte == "\u{05D2}")
        #expect(sansFrancais.texteDroiteAGauche)

        var deux = Reglages()
        deux.setLectureLangues("fr+en")
        let (traductions, _, _) = Self.fabriquer(deux)
        await traductions.charger()
        let deuxTextes = try #require(traductions.carte)
        #expect(deuxTextes.texte == "A fr")
        #expect(deuxTextes.second == "A en")
    }

    @Test func lePersonnageAuFeminin() async throws {
        var reglages = Reglages()
        reglages.setAdresse("f")
        let (modele, _, _) = Self.fabriquer(reglages)
        await modele.charger()
        let carte = try #require(modele.carte)
        #expect(carte.image == Personnage.feminin("char_open_arms"))
        #expect(modele.image == Personnage.feminin("char_open_arms"))
        #expect(modele.image != "char_open_arms")
    }

    @Test func leNomDeChaqueMoment() {
        let cles = Moment.allCases.map { ChizukCarte.libelle($0) }
        #expect(cles == ["moment_ouverture", "moment_blocage", "moment_porte", "moment_relance", "moment_cloture",
                         "moment_lieu", "chizuk_demande_title"])
    }

    @Test func surChizukJsonLaCarteSuitLesRegles() async throws {
        let modele = ChizukModele(magasin: Magasin.enMemoire(), contenus: Self.contenus, langue: "fr", debug: false)
        await modele.charger()
        let chizuk = try await Self.contenus.chizuk()
        let carte = try #require(modele.carte)
        let item = try #require(chizuk.item(carte.id))
        #expect(carte.texte == ChizukRules.hebrew(chizuk, item))
        #expect(carte.second == item.fr)
        #expect(carte.reference == Reference.localise(item.ref, "fr"))
        #expect(!carte.aRelire)
    }

    // MARK: Garder

    @Test func garderPuisRetirer() async throws {
        let (modele, magasin, _) = Self.fabriquer()
        await modele.charger()
        #expect(modele.actionsActives)
        #expect(!modele.garde)
        #expect(modele.libelleGarder == Libelle("chizuk_garder"))
        #expect(modele.gardes.isEmpty)

        try await modele.garder()
        #expect(modele.garde)
        #expect(modele.libelleGarder == Libelle("chizuk_garde"))
        let premiers = modele.gardes.map { $0.id }
        #expect(premiers == ["a"])

        // Un autre texte n'est pas gardé ; le garder le met en tête.
        try await modele.unAutre()
        #expect(!modele.garde)
        try await modele.garder()
        let deux = modele.gardes.map { $0.id }
        #expect(deux == ["b", "a"])
        let favoris = magasin.reglages.brut["chizuk_favoris"]
        #expect(favoris == .chaine("b|a"))

        // Le garder encore le retire.
        try await modele.garder()
        let reste = modele.gardes.map { $0.id }
        #expect(reste == ["a"])
        #expect(modele.libelleGarder == Libelle("chizuk_garder"))
    }

    @Test func toucherUnTexteGardeLeRemetSurLaCarte() async throws {
        let (modele, magasin, _) = Self.fabriquer()
        await modele.charger()
        try await modele.garder()
        try await modele.unAutre()
        #expect(modele.courantId == "b")
        let sac = ChizukSac.sac(magasin.reglages, moment: .demande)
        let changements = modele.changements
        modele.montrer("a")
        #expect(modele.courantId == "a")
        #expect(modele.garde)
        #expect(modele.changements == changements + 1)
        // Rien n'est tiré : le sac n'a pas bougé.
        #expect(ChizukSac.sac(magasin.reglages, moment: .demande) == sac)
        // Un texte qui n'existe plus ne s'affiche pas.
        modele.montrer("retire")
        #expect(modele.courantId == "a")
    }

    @Test func lesTextesGardesDansLaLangueDeLApp() async throws {
        var reglages = Reglages()
        ChizukSac.basculerFavori(&reglages, id: "a")
        ChizukSac.basculerFavori(&reglages, id: "retire")
        ChizukSac.basculerFavori(&reglages, id: "c")
        let (modele, _, _) = Self.fabriquer(reglages)
        await modele.charger()
        let gardes = modele.gardes
        // Le texte retiré des données est passé sous silence ; le plus récent en tête.
        let ids = gardes.map { $0.id }
        #expect(ids == ["c", "a"])
        // c n'a pas de français : son hébreu.
        #expect(gardes[0].texte == "\u{05D2}")
        #expect(gardes[0].reference == Reference.localise("Michlé 24:16", "fr"))
        #expect(gardes[1].texte == "A fr")
        #expect(gardes[1].ligne == "A fr\nTehilim 1:1")

        let (hebreu, _, _) = Self.fabriquer(reglages, langue: "he")
        await hebreu.charger()
        let textes = hebreu.gardes.map { $0.texte }
        #expect(textes == ["\u{05D2}", "\u{05D0}\u{05B7}"])
    }

    // MARK: Partager

    @Test func leTextePartage() async throws {
        let (modele, _, _) = Self.fabriquer()
        await modele.charger()
        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: "fr")
        let lien = traducteur.texte(modele.lienPartage)
        #expect(lien == "Essayez, vous aussi, gratuitement\u{a0}: https://hil123.github.io/myhitbodedut-web/")
        let partage = modele.textePartage { traducteur.texte($0) }
        #expect(partage == "\u{05D0}\u{05B7}\n\nA fr\n\n— Tehilim 1:1\n\n" + lien)
        #expect(modele.libellePartager == Libelle("chizuk_partager"))
    }

    @Test func enHebreuLePartageNaPasDeTraduction() async throws {
        let (modele, _, _) = Self.fabriquer(langue: "he")
        await modele.charger()
        let traducteur = try Traducteur(catalogue: Fichiers.catalogue(), langue: "he")
        let lien = traducteur.texte(modele.lienPartage)
        let partage = modele.textePartage { traducteur.texte($0) }
        let attendu = ChizukPartage.texte("\u{05D0}\u{05B7}", "", Reference.localise("Tehilim 1:1", "he"), lien)
        #expect(partage == attendu)
        #expect(partage == "\u{05D0}\u{05B7}\n\n— " + Reference.localise("Tehilim 1:1", "he") + "\n\n" + lien)
    }

    @Test func commencerOuvreLaSeance() {
        let (modele, _, _) = Self.fabriquer()
        #expect(modele.routeCommencer == .seance)
        #expect(modele.libelleCommencer == Libelle("chizuk_commencer"))
        #expect(modele.libelleAutre == Libelle("chizuk_autre"))
        #expect(modele.titreGardes == Libelle("chizuk_favoris"))
    }

    // MARK: Les chaînes

    @Test func chaqueCleDeLEcranEstDansLeCatalogue() throws {
        let catalogue = try CatalogueBrut.lire()
        let cles = [
            "chizuk_demande_title", "chizuk_demande_hint", "chizuk_autre", "chizuk_garder", "chizuk_garde",
            "chizuk_partager", "chizuk_commencer", "chizuk_favoris", "chizuk_badge_to_proofread", "partage_lien",
        ] + Moment.allCases.map { ChizukCarte.libelle($0) }
        for cle in cles {
            for langue in Traducteur.langues {
                let valeur = catalogue.valeur(cle, langue: langue)
                #expect(valeur != nil, "\(cle) \(langue)")
            }
        }
    }
}
