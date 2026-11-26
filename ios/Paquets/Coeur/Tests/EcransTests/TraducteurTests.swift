import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le Traducteur résout un `Libelle` comme Android résout ses ressources : la langue de l'app, le repli sur le
/// français, la forme du pluriel et sa forme « other », la clé elle-même quand rien ne se résout. Sur le
/// catalogue exporté du dépôt, puis sur un catalogue écrit ici pour les cas que le vrai n'a pas (il traduit
/// tout dans les trois langues). La mise en forme elle-même est jugée par LibelleTests (Coeur).
@Suite("Traducteur")
struct TraducteurTests {

    private static let catalogue: Result<Data, any Error> = Result { try Fichiers.catalogue() }

    private func traducteur(_ langue: String) throws -> Traducteur {
        try Traducteur(catalogue: Self.catalogue.get(), langue: langue)
    }

    // MARK: Le catalogue exporté

    @Test func desClesSimplesDansLesTroisLangues() throws {
        // « Le Jour » depuis la refonte de l'accueil d'Android (« Aujourd'hui » avant).
        let francais = try traducteur("fr").texte(cle: "nav_today")
        #expect(francais == "Le Jour")
        let anglais = try traducteur("en").texte(cle: "nav_today")
        #expect(anglais == "Today")
        let hebreu = try traducteur("he").texte(cle: "nav_today")
        #expect(hebreu == "היום")
        let diaspora = try traducteur("he").texte(Libelle("region_diaspora"))
        #expect(diaspora == "חו״ל")
    }

    @Test func lesArgumentsSeGlissentDansLeGabarit() throws {
        let allumage = Libelle("reglage_allumage_valeur", .entier(18))
        let francais = try traducteur("fr").texte(allumage)
        #expect(francais == "18 min avant la chki\u{2019}a")
        let anglais = try traducteur("en").texte(allumage)
        #expect(anglais == "18 min before sunset")
        let hebreu = try traducteur("he").texte(allumage)
        #expect(hebreu == "18 דקות לפני השקיעה")
        // Un libellé dans un autre se résout dans la même langue.
        let lieu = Libelle("zmanim_lieu_detail", .texte("Paris"), .libelle(Libelle("region_diaspora")))
        let enFrancais = try traducteur("fr").texte(lieu)
        #expect(enFrancais == "Paris \u{B7} Diaspora")
        let enHebreu = try traducteur("he").texte(lieu)
        #expect(enHebreu == "Paris \u{B7} חו״ל")
    }

    @Test func lesPlurielsDansLesTroisLangues() throws {
        func bloquees(_ n: Int, _ langue: String) throws -> String {
            try traducteur(langue).texte(Libelle.pluriel("apps_selected", quantite: n, .entier(n)))
        }
        // Français : 0 et 1 prennent « one ».
        let francais = try [0, 1, 2].map { try bloquees($0, "fr") }
        // « choisie » depuis l'audit du 13/11 d'Android (« bloquée » avant).
        #expect(francais == ["0 application choisie", "1 application choisie", "2 applications choisies"])
        // Anglais : 0 prend « other ».
        let anglais = try [0, 1, 5].map { try bloquees($0, "en") }
        #expect(anglais == ["0 apps selected", "1 app selected", "5 apps selected"])
        // Hébreu : « one », « two », « other » ; les deux premières formes n'écrivent pas le nombre.
        let hebreu = try [1, 2, 5].map { try bloquees($0, "he") }
        #expect(hebreu == ["אפליקציה אחת נבחרה", "שתי אפליקציות נבחרו", "5 אפליקציות נבחרו"])
        // Deux arguments, la quantité choisit la forme.
        let resume = try traducteur("fr").texte(Libelle.pluriel("journal_summary", quantite: 3, .entier(3), .texte("1 h")))
        #expect(resume == "3 jours de hitbodedout, 1 h au total")
    }

    @Test func uneCleIntrouvableSeRendTelleQuelle() throws {
        let fr = try traducteur("fr")
        let absente = fr.texte(cle: "cle_qui_n_existe_pas")
        #expect(absente == "cle_qui_n_existe_pas")
        // Un argument manque au gabarit (%2$@) : rien de faux ne s'affiche, la clé non plus n'est pas vide.
        let incomplet = fr.texte(Libelle("zmanim_lieu_detail", .texte("Paris")))
        #expect(incomplet == "zmanim_lieu_detail")
        // Un pluriel demandé comme une chaîne simple, et l'inverse.
        let pluriel = fr.texte(cle: "apps_selected")
        #expect(pluriel == "apps_selected")
        let simple = fr.texte(Libelle.pluriel("nav_today", quantite: 2))
        #expect(simple == "nav_today")
    }

    @Test func chaqueChaineSimpleDuCatalogueSeResoutDansSaLangue() throws {
        let brut = try CatalogueBrut.lire()
        #expect(brut.sourceLanguage == Traducteur.repli)
        var comparees = 0
        for langue in Traducteur.langues {
            let resolveur = try traducteur(langue)
            for cle in brut.strings.keys.sorted() {
                guard let attendue = brut.valeur(cle, langue: langue) else { continue }
                // Sans argument, le gabarit tel qu'il est écrit (`getString(id)`).
                let obtenue = resolveur.texte(cle: cle)
                #expect(obtenue == attendue, "\(cle) en \(langue)")
                comparees += 1
            }
        }
        #expect(comparees > 3000, "trop peu de chaînes : \(comparees)")
    }

    // MARK: La langue de l'app

    @Test func laLangueDeLApp() throws {
        let codes: [String?] = ["fr", "en", "he", "iw", "he-IL", "fr-CA", "FR", "en_GB", "de", "", nil]
        let langues = codes.map { Traducteur.langueApp($0) }
        #expect(langues == ["fr", "en", "he", "he", "he", "fr", "fr", "en", "en", "en", "en"])
        // L'espagnol, partout ; l'arabe, seulement en Tunisie (LangueApp.livree d'Android, 17/11).
        let nouvelles: [String?] = ["es", "es-MX", "es_ES", "ar-TN", "ar_tn", "ar-Latn-TN", "ar", "ar-MA", "ar_EG"]
        #expect(nouvelles.map { Traducteur.langueApp($0) } == ["es", "es", "es", "ar", "ar", "ar", "en", "en", "en"])
        let espagnol = try traducteur("es-MX")
        #expect(espagnol.langue == "es")
        #expect(espagnol.texte(cle: "nav_today") == "El Día")
        let iw = try traducteur("iw")
        #expect(iw.langue == "he")
        let hebreu = iw.texte(cle: "nav_journal")
        #expect(hebreu == "יומן")
    }

    /// LanguesTest d'Android (« un téléphone dont aucune langue n'est livrée passe en anglais ») : la première des
    /// langues préférées que l'app livre ; l'arabe d'ailleurs que la Tunisie n'est pas livré.
    @Test func laLangueDuTelephone() {
        let cas: [([String], String)] = [
            (["de-DE", "ru-RU"], "en"), (["es-ES"], "es"), (["es-419"], "es"), (["ar-TN"], "ar"), (["ar-EG"], "en"),
            (["ar"], "en"), ([], "en"), (["de-DE", "fr-FR"], "fr"), (["iw-IL"], "he"), (["he"], "he"),
            (["en-GB"], "en"), (["ar-EG", "fr-FR"], "fr"), (["ar-Latn-TN", "fr"], "ar"),
        ]
        for (preferees, attendue) in cas {
            let langue = Traducteur.langueDuTelephone(preferees)
            #expect(langue == attendue, "\(preferees)")
        }
        let livrees = ["fr", "en-US", "he", "iw", "es-MX", "ar-TN", "ar_tn"].map(Traducteur.livree)
        #expect(livrees == [true, true, true, true, true, true, true])
        let refusees = ["ar", "ar-SA", "de", ""].map(Traducteur.livree)
        #expect(refusees == [false, false, false, false])
    }

    /// ChiffresTest d'Android (décision du 24/11) : en arabe, les dates et les nombres que l'app écrit sont en chiffres
    /// 0 à 9 ; la région reste ; les autres langues ne changent pas.
    @Test func enArabeDesChiffresDeZeroANeuf() {
        let arabesOrientaux = Set("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹")
        for langue in ["ar", "ar-TN", "ar_TN"] {
            let l = Traducteur.localeDesChiffres(langue)
            #expect(l.region?.identifier == "TN", "\(langue)")
            let format = DateFormatter()
            format.locale = l
            format.timeZone = TimeZone(secondsFromGMT: 0)
            format.dateFormat = "d MMMM yyyy"
            let ecrit = format.string(from: Date(timeIntervalSince1970: 1_795_000_000))
            #expect(!ecrit.contains(where: arabesOrientaux.contains), "\(langue) : \(ecrit)")
            #expect(ecrit.contains("2026"), "\(langue) : \(ecrit)")
            let nombre = NumberFormatter()
            nombre.locale = l
            #expect(nombre.string(from: 2985) == "2985" || nombre.string(from: 2985)?.contains(where: arabesOrientaux.contains) == false)
        }
        for langue in ["fr", "en", "he", "es"] {
            #expect(Traducteur.localeDesChiffres(langue).identifier == langue)
        }
    }

    /// L'arabe est l'arabe de Tunisie, de droite à gauche comme l'hébreu.
    @Test func laLocalisationEtLeSensDEcriture() {
        let identifiants = Traducteur.langues.map(Traducteur.identifiantLocale)
        #expect(identifiants == ["fr", "en", "he", "es", "ar-TN"])
        let rtl = Traducteur.langues.filter(Traducteur.deDroiteAGauche)
        #expect(rtl == ["he", "ar"])
    }

    /// LanguesTest d'Android (« les langues livrées sont déclarées au système ») : chaque langue de Langues.toutes
    /// est dans les localisations de l'app (projet-commun.yml) et dans le catalogue que compile Xcode, sous le même
    /// code (« iw » s'écrit « he » sur iOS).
    @Test func lesLanguesLivreesSontDeclareesAuSysteme() throws {
        let projet = String(decoding: try Fichiers.donnees("ios/projet-commun.yml"), as: UTF8.self)
        let attendues = Langues.toutes.map { $0.etiquette == "iw" ? "he" : $0.etiquette }
        #expect(projet.contains("CFBundleLocalizations: [fr, en, he, es, ar-TN]"))
        for code in attendues {
            #expect(projet.contains(code), "\(code)")
        }
        // Le catalogue compilé n'existe qu'après l'export (tools/export_contenu), comme les contenus.
        let compile = try JSONSerialization.jsonObject(with: Fichiers.donnees("ios/Ressources/Catalogue/Localizable.xcstrings"))
        let entree = ((compile as? [String: Any])?["strings"] as? [String: Any])?["nav_today"] as? [String: Any]
        let langues = (entree?["localizations"] as? [String: Any])?.keys.sorted() ?? []
        #expect(langues == attendues.sorted())
        let ios = try JSONSerialization.jsonObject(with: Fichiers.donnees("ios/Ressources/Catalogue/ios.xcstrings"))
        let ok = ((ios as? [String: Any])?["strings"] as? [String: Any])?["action_ok"] as? [String: Any]
        let languesIos = (ok?["localizations"] as? [String: Any])?.keys.sorted() ?? []
        #expect(languesIos == attendues.sorted())
    }

    // MARK: Un catalogue écrit ici

    private static let petit = Data("""
    {
      "sourceLanguage" : "fr",
      "strings" : {
        "seulement_fr" : { "localizations" : {
          "fr" : { "stringUnit" : { "state" : "translated", "value" : "Seulement en français" } } } },
        "bonjour" : { "localizations" : {
          "fr" : { "stringUnit" : { "state" : "translated", "value" : "Bonjour" } },
          "en" : { "stringUnit" : { "state" : "translated", "value" : "Hello" } },
          "iw" : { "stringUnit" : { "state" : "translated", "value" : "שלום" } } } },
        "jours" : { "localizations" : {
          "fr" : { "variations" : { "plural" : {
            "one" : { "stringUnit" : { "state" : "translated", "value" : "%lld jour" } },
            "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld jours" } } } } },
          "he" : { "variations" : { "plural" : {
            "one" : { "stringUnit" : { "state" : "translated", "value" : "יום אחד" } },
            "other" : { "stringUnit" : { "state" : "translated", "value" : "%lld ימים" } } } } } } },
        "sans_traduction" : { }
      },
      "version" : "1.0"
    }
    """.utf8)

    @Test func ceQuiNEstPasTraduitRetombeSurLeFrancais() throws {
        let anglais = try Traducteur(catalogue: Self.petit, langue: "en")
        let seul = anglais.texte(cle: "seulement_fr")
        #expect(seul == "Seulement en français")
        let bonjour = anglais.texte(cle: "bonjour")
        #expect(bonjour == "Hello")
        // Un pluriel que l'anglais ne traduit pas : les formes du français, choisies par la règle de l'anglais.
        let un = anglais.texte(Libelle.pluriel("jours", quantite: 1, .entier(1)))
        #expect(un == "1 jour")
        let zero = anglais.texte(Libelle.pluriel("jours", quantite: 0, .entier(0)))
        #expect(zero == "0 jours")
        // Une entrée sans aucune traduction : sa clé.
        let rien = anglais.texte(cle: "sans_traduction")
        #expect(rien == "sans_traduction")
    }

    @Test func unPlurielTraduitGardeSesFormesEtSaFormeOther() throws {
        let hebreu = try Traducteur(catalogue: Self.petit, langue: "he")
        let un = hebreu.texte(Libelle.pluriel("jours", quantite: 1, .entier(1)))
        #expect(un == "יום אחד")
        // « two » manque à l'hébreu de ce catalogue : sa forme « other », pas celle du français.
        let deux = hebreu.texte(Libelle.pluriel("jours", quantite: 2, .entier(2)))
        #expect(deux == "2 ימים")
        // « iw » dans le catalogue se lit « he ».
        let bonjour = hebreu.texte(cle: "bonjour")
        #expect(bonjour == "שלום")
    }

    @Test func desOctetsQuiNeSontPasUnCatalogueSontRefuses() {
        var refuse = false
        do {
            _ = try Traducteur(catalogue: Data("[1, 2]".utf8), langue: "fr")
        } catch {
            refuse = true
        }
        #expect(refuse)
    }

    @Test func desGabaritsDonnesPourUnApercu() {
        let apercu = Traducteur(langue: "he", simples: ["fr": ["titre": "Titre"], "he": ["titre": "כותרת"]])
        let titre = apercu.texte(cle: "titre")
        #expect(titre == "כותרת")
        let francais = Traducteur(langue: "fr-FR", simples: ["fr": ["titre": "Titre"]])
        #expect(francais.langue == "fr")
        let repli = Traducteur(langue: "en", simples: ["fr": ["titre": "Titre"]]).texte(cle: "titre")
        #expect(repli == "Titre")
    }

    @Test func lesChainesPropresAIOSSeLisentAvecCellesDAndroid() throws {
        let android = try Fichiers.catalogue()
        let ios = try Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings")
        for langue in Traducteur.langues {
            let deux = try Traducteur(catalogues: [android, ios], langue: langue)
            let seul = try Traducteur(catalogue: android, langue: langue)
            // Une clé d'Android garde son gabarit ; une clé d'iOS se résout au lieu de rendre sa clé.
            #expect(deux.texte(cle: "nav_today") == seul.texte(cle: "nav_today"))
            for cle in ["action_ok", "contenu_illisible", "reglages_autorisation_temps_ecran",
                        "reglages_autorisation_temps_ecran_pourquoi", "reglages_minuterie_systeme"] {
                let texte = deux.texte(cle: cle)
                #expect(texte != cle, "\(cle) sans texte en \(langue)")
                #expect(seul.texte(cle: cle) == cle)
            }
        }
        // Le premier catalogue l'emporte sur une clé présente dans les deux.
        let premier = Data(#"{"sourceLanguage":"fr","strings":{"x":{"localizations":{"fr":{"stringUnit":{"value":"Un"}}}}}}"#.utf8)
        let second = Data(#"{"sourceLanguage":"fr","strings":{"x":{"localizations":{"fr":{"stringUnit":{"value":"Deux"}}}},"y":{"localizations":{"fr":{"stringUnit":{"value":"Y"}}}}}}"#.utf8)
        let fusion = try Traducteur(catalogues: [premier, second], langue: "fr")
        #expect(fusion.texte(cle: "x") == "Un")
        #expect(fusion.texte(cle: "y") == "Y")
    }
}
