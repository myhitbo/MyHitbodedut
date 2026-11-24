import Foundation
import Testing
import Coeur
@testable import Ecrans

/// La dédicace (Dedicace.kt) : les choix et leur ordre, les formules hébraïques recopiées de Kotlin, le nom
/// obligatoire, le corps de Dedicace.corps et le lien de Dedicace.lien, à l'octet, dans les trois langues, sur le
/// catalogue exporté du dépôt. Les attendus ont été calculés comme Android les calcule (`getString`,
/// `URLEncoder.encode(…, "UTF-8").replace("+", "%20")`).
///
/// Non porté : l'ouverture de la messagerie elle-même (Intent.ACTION_SENDTO, les extras) est l'affaire de la vue
/// (openURL) ; le modèle n'en reçoit que le résultat.
@Suite("Modèle de la dédicace")
@MainActor
struct DedicaceModeleTests {

    private static let catalogue: Result<Data, any Error> = Result { try Fichiers.catalogue() }

    private func modele(_ langue: String) throws -> DedicaceModele {
        let traducteur = try Traducteur(catalogue: Self.catalogue.get(), langue: langue)
        return DedicaceModele(traducteur: traducteur)
    }

    // MARK: La boîte

    @Test func laBoiteEtSesChaines() throws {
        let m = try modele("fr")
        #expect(m.titre == Libelle("section_dedicace"))
        #expect(m.aide == Libelle("section_dedicace_hint"))
        #expect(m.legendeObjet == Libelle("dedicace_quoi"))
        #expect(m.legendeIntention == Libelle("dedicace_pour"))
        #expect(m.indicationNom == Libelle("dedicace_nom"))
        #expect(m.indicationMot == Libelle("dedicace_mot"))
        #expect(m.libelleEcrire == Libelle("dedicace_ecrire"))
        #expect(m.libelleRetour == Libelle("action_back"))
        #expect(m.messageSansMessagerie == Libelle("dedicace_sans_messagerie"))
    }

    /// Toutes les clés de l'écran existent dans les trois langues du catalogue.
    @Test func toutesLesClesSontAuCatalogue() throws {
        let brut = try CatalogueBrut.lire()
        let m = try modele("fr")
        var cles = [m.titre, m.aide, m.legendeObjet, m.legendeIntention, m.indicationNom, m.indicationMot,
                    m.libelleEcrire, m.libelleRetour, m.messageSansMessagerie].map { $0.cle }
        cles += m.objets.map { $0.libelle.cle } + m.intentions.map { $0.libelle.cle }
        cles += ["dedicace_nom_manque", "dedicace_sujet", "dedicace_corps_intro", "dedicace_corps_demande",
                 "dedicace_corps_fin"]
        for cle in cles {
            for langue in Traducteur.langues {
                let valeur = brut.valeur(cle, langue: langue)
                #expect(valeur != nil, "\(cle) en \(langue)")
            }
        }
    }

    /// Les choix dans l'ordre des boutons radio, le premier de chacun coché.
    @Test func lesChoixDansLOrdreDAndroid() throws {
        let m = try modele("fr")
        #expect(m.objets == [.hitbodedut, .etude])
        #expect(m.intentions == [.leilouy, .refoua, .hatslaha, .zivoug, .autre])
        #expect(m.objet == .hitbodedut)
        #expect(m.intention == .leilouy)
        #expect(m.nom == "")
        #expect(m.mot == "")
        let objets = m.objets.map { $0.libelle }
        #expect(objets == [Libelle("dedicace_hitbodedut"), Libelle("dedicace_etude")])
        let intentions = m.intentions.map { $0.libelle }
        #expect(intentions == [Libelle("dedicace_leilouy"), Libelle("dedicace_refoua"), Libelle("dedicace_hatslaha"),
                               Libelle("dedicace_zivoug"), Libelle("dedicace_autre")])
    }

    /// Les formules et l'adresse sont celles de Dedicace.kt, lu là où il est.
    @Test func lesFormulesEtLAdresseDeDedicaceKt() throws {
        let kotlin = String(decoding: try Fichiers.donnees("android/app/src/main/java/com/myhitbodedut/Dedicace.kt"),
                            as: UTF8.self)
        #expect(kotlin.contains("const val ADRESSE = \"" + DedicaceCourriel.adresse + "\""))
        for intention in DedicaceIntention.allCases {
            let formule = intention.formule.map { "\"" + $0 + "\"" } ?? "null"
            let ligne = "(R.string." + intention.libelle.cle + ", " + formule + ")"
            #expect(kotlin.contains(ligne), "\(ligne)")
        }
        #expect(DedicaceCourriel.adresse == "myhitbodedut26@gmail.com")
        let formules = DedicaceIntention.allCases.map { $0.formule }
        let attendues: [String?] = ["לעילוי נשמת", "לרפואה שלמה", "להצלחה", "לזיווג הגון", nil]
        #expect(formules == attendues)
        let octets = Array((DedicaceIntention.leilouy.formule ?? "").utf8)
        let attendus: [UInt8] = [0xD7, 0x9C, 0xD7, 0xA2, 0xD7, 0x99, 0xD7, 0x9C, 0xD7, 0x95, 0xD7, 0x99, 0x20,
                                 0xD7, 0xA0, 0xD7, 0xA9, 0xD7, 0x9E, 0xD7, 0xAA]
        #expect(octets == attendus)
    }

    // MARK: Le nom obligatoire

    @Test func sansNomRienNeSOuvreEtLeChampLeDit() throws {
        let m = try modele("fr")
        #expect(m.erreurNom == nil)
        let vide = m.ecrire()
        #expect(vide == nil)
        #expect(m.erreurNom == Libelle("dedicace_nom_manque"))
        #expect(m.termine == false)
        #expect(m.sansMessagerie == false)
        // Des blancs seuls ne font pas un nom (isBlank).
        m.nom = " \t\n "
        let blanc = m.ecrire()
        #expect(blanc == nil)
        #expect(m.erreurNom == Libelle("dedicace_nom_manque"))
        // Un nom saisi efface l'erreur.
        m.nom = "Moché"
        #expect(m.erreurNom == nil)
        let url = try #require(m.ecrire())
        #expect(url.absoluteString == m.lien)
        #expect(url.scheme == "mailto")
        #expect(m.termine == false)
    }

    /// Avant d'avoir touché « Écrire », un nom vide ne montre aucune erreur.
    @Test func pasDErreurAvantLePremierEssai() throws {
        let m = try modele("en")
        m.nom = "x"
        m.nom = ""
        #expect(m.erreurNom == nil)
    }

    // MARK: L'e-mail, à l'octet

    @Test func lEMailEnFrancais() throws {
        let m = try modele("fr")
        m.nom = "  Moché ben Sarah "
        #expect(m.sujet == "Dédicace – Ma hitbodedout")
        let corpsAttendu = [
            "Bonjour,\n\nJe souhaite dédier ma hitbodedout :\nלעילוי נשמת Moché ben Sarah\n\n",
            "Envoyé depuis l’application MyHitbodedut."
        ].joined()
        #expect(m.corps == corpsAttendu)
        let lienAttendu = [
            "mailto:myhitbodedut26@gmail.com?subject=D%C3%A9dicace%20%E2%80%93%20Ma%20hitbodedout",
            "&body=Bonjour%2C%0A%0AJe%20souhaite%20d%C3%A9dier%20ma%20hitbodedout%20%3A%0A",
            "%D7%9C%D7%A2%D7%99%D7%9C%D7%95%D7%99%20%D7%A0%D7%A9%D7%9E%D7%AA%20Moch%C3%A9%20ben%20Sarah",
            "%0A%0AEnvoy%C3%A9%20depuis%20l%E2%80%99application%20MyHitbodedut."
        ].joined()
        #expect(m.lien == lienAttendu)
        let url = try #require(m.ecrire())
        #expect(url.absoluteString == m.lien)
    }

    @Test func lEMailEnAnglaisSansFormuleAvecUnMot() throws {
        let m = try modele("en")
        m.objet = .etude
        m.intention = .autre
        m.nom = "Rivka bat Léa"
        m.mot = "  Merci + bravo !\n"
        #expect(m.sujet == "Dedication – My study")
        let corpsAttendu = [
            "Hello,\n\nI would like to dedicate my study:\nRivka bat Léa\n\nMerci + bravo !\n\n",
            "Sent from the MyHitbodedut app."
        ].joined()
        #expect(m.corps == corpsAttendu)
        let lienAttendu = [
            "mailto:myhitbodedut26@gmail.com?subject=Dedication%20%E2%80%93%20My%20study",
            "&body=Hello%2C%0A%0AI%20would%20like%20to%20dedicate%20my%20study%3A%0ARivka%20bat%20L%C3%A9a",
            "%0A%0AMerci%20%2B%20bravo%20%21%0A%0ASent%20from%20the%20MyHitbodedut%20app."
        ].joined()
        #expect(m.lien == lienAttendu)
    }

    @Test func lEMailEnHebreu() throws {
        let m = try modele("he")
        m.intention = .zivoug
        m.nom = "משה בן שרה"
        m.mot = "תודה"
        #expect(m.sujet == "הקדשה – את ההתבודדות שלי")
        let corpsAttendu = [
            "שלום,\n\nברצוני להקדיש את ההתבודדות שלי:\nלזיווג הגון משה בן שרה\n\nתודה\n\n",
            "נשלח מהאפליקציה MyHitbodedut."
        ].joined()
        #expect(m.corps == corpsAttendu)
        let lienAttendu = [
            "mailto:myhitbodedut26@gmail.com?subject=",
            "%D7%94%D7%A7%D7%93%D7%A9%D7%94%20%E2%80%93%20%D7%90%D7%AA%20",
            "%D7%94%D7%94%D7%AA%D7%91%D7%95%D7%93%D7%93%D7%95%D7%AA%20%D7%A9%D7%9C%D7%99",
            "&body=%D7%A9%D7%9C%D7%95%D7%9D%2C%0A%0A%D7%91%D7%A8%D7%A6%D7%95%D7%A0%D7%99%20",
            "%D7%9C%D7%94%D7%A7%D7%93%D7%99%D7%A9%20%D7%90%D7%AA%20",
            "%D7%94%D7%94%D7%AA%D7%91%D7%95%D7%93%D7%93%D7%95%D7%AA%20%D7%A9%D7%9C%D7%99%3A%0A",
            "%D7%9C%D7%96%D7%99%D7%95%D7%95%D7%92%20%D7%94%D7%92%D7%95%D7%9F%20",
            "%D7%9E%D7%A9%D7%94%20%D7%91%D7%9F%20%D7%A9%D7%A8%D7%94%0A%0A%D7%AA%D7%95%D7%93%D7%94%0A%0A",
            "%D7%A0%D7%A9%D7%9C%D7%97%20%D7%9E%D7%94%D7%90%D7%A4%D7%9C%D7%99%D7%A7%D7%A6%D7%99%D7%94",
            "%20MyHitbodedut."
        ].joined()
        #expect(m.lien == lienAttendu)
    }

    /// Chaque intention écrit sa formule devant le nom ; « Autre » le nom seul.
    @Test func laLigneDeLaDedicaceSuitLIntention() throws {
        let m = try modele("fr")
        m.nom = "Sarah"
        for intention in DedicaceIntention.allCases {
            m.intention = intention
            let lignes = m.corps.components(separatedBy: "\n")
            let attendue = intention.formule.map { $0 + " Sarah" } ?? "Sarah"
            #expect(lignes.count == 6)
            #expect(lignes[3] == attendue)
        }
    }

    // MARK: Dedicace.corps et Dedicace.lien

    @Test func leCorpsCommeDedicaceCorps() {
        let sans = DedicaceCourriel.corps(intro: "A", demande: "B", formule: nil, nom: " N ", mot: " \n ", fin: "F")
        #expect(sans == "A\n\nB\nN\n\nF")
        let avec = DedicaceCourriel.corps(intro: "A", demande: "B", formule: "ל", nom: "N", mot: "\tM M\n", fin: "F")
        #expect(avec == "A\n\nB\nל N\n\nM M\n\nF")
        // Un nom vide (le modèle ne l'envoie pas, la fonction l'écrit comme Kotlin) : la formule suivie d'une espace.
        let vide = DedicaceCourriel.corps(intro: "A", demande: "B", formule: "ל", nom: "", mot: "", fin: "F")
        #expect(vide == "A\n\nB\nל \n\nF")
    }

    /// URLEncoder de Java : seuls les lettres et chiffres ASCII et « . - * _ » restent ; « + » devient %2B,
    /// l'espace %20, « ~ » %7E.
    @Test func lEncodageCommeURLEncoder() {
        #expect(DedicaceCourriel.encoder("") == "")
        #expect(DedicaceCourriel.encoder("aZ09.-*_") == "aZ09.-*_")
        #expect(DedicaceCourriel.encoder("a b+c") == "a%20b%2Bc")
        #expect(DedicaceCourriel.encoder("~!'()&=?/:@#%") == "%7E%21%27%28%29%26%3D%3F%2F%3A%40%23%25")
        #expect(DedicaceCourriel.encoder("\r\n\t") == "%0D%0A%09")
        #expect(DedicaceCourriel.encoder("é") == "%C3%A9")
        // « é » décomposé reste décomposé : l'encodage suit les octets, pas l'équivalence canonique.
        #expect(DedicaceCourriel.encoder("e\u{301}") == "e%CC%81")
        #expect(DedicaceCourriel.encoder("שָׁ") == "%D7%A9%D6%B8%D7%81")
        #expect(DedicaceCourriel.encoder("😀") == "%F0%9F%98%80")
        #expect(DedicaceCourriel.lien(sujet: "S s", corps: "C\nc") ==
                "mailto:myhitbodedut26@gmail.com?subject=S%20s&body=C%0Ac")
    }

    @Test func laPremiereLettreEnMinuscule() {
        #expect(DedicaceCourriel.premiereEnMinuscule("Ma hitbodedout") == "ma hitbodedout")
        #expect(DedicaceCourriel.premiereEnMinuscule("My Study") == "my Study")
        #expect(DedicaceCourriel.premiereEnMinuscule("את הלימוד שלי") == "את הלימוד שלי")
        #expect(DedicaceCourriel.premiereEnMinuscule("") == "")
    }

    // MARK: L'ouverture

    @Test func uneMessagerieOuverteFermeLaBoite() throws {
        let m = try modele("fr")
        m.nom = "Sarah"
        _ = try #require(m.ecrire())
        m.ouverture(reussie: true)
        #expect(m.termine)
        #expect(m.sansMessagerie == false)
    }

    @Test func sansMessagerieLeMessagePuisLaFermeture() throws {
        let m = try modele("fr")
        m.nom = "Sarah"
        _ = try #require(m.ecrire())
        m.ouverture(reussie: false)
        #expect(m.sansMessagerie)
        #expect(m.termine == false)
        m.messageLu()
        #expect(m.sansMessagerie == false)
        #expect(m.termine)
    }
}
