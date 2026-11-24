import Foundation
import Testing
import Coeur
@testable import Ecrans

// Le choix des applications de la barrière (AppPickerActivity.kt, qui n'a pas de test d'Android) : ce qui se
// décide par des nombres et des états. L'autorisation de Temps d'écran et ce que la carte en dit, le compte de la
// sélection et ses lignes, les 50 applications, l'aide-mémoire d'Android, ce qui s'écrit dans le stock et ce qui ne
// s'écrit pas, les clés des deux catalogues. Le sélecteur d'Apple et `Label(jeton)` restent à l'app (FamilyControls).

@Suite("Modèle du choix des applications")
@MainActor
struct ApplicationsModeleTests {

    private static let octets = Data([0x01, 0x02])
    private static let autres = Data([0x03])
    private static let vides = Data([0x00])

    private struct Banc {
        let modele: ApplicationsModele
        let autorisation: AppsFausseAutorisation
        let stock: AppsFausseSelection
    }

    private func fabriquer(etat: AppsAutorisationEtat = .accordee, issue: AppsDemandeIssue = .accordee,
                           etatApres: AppsAutorisationEtat? = nil, donnees: Data? = nil,
                           comptes: [Data: ApplicationsCompte] = [:], android: Set<String> = [],
                           refuse: Bool = false) -> Banc {
        var reglages = Reglages()
        reglages.setBlockedApps(android)
        var tous = comptes
        tous[ApplicationsModeleTests.vides] = .vide
        let autorisation = AppsFausseAutorisation(etat: etat, issue: issue, etatApres: etatApres)
        let stock = AppsFausseSelection(donnees: donnees, comptes: tous, refuse: refuse)
        let modele = ApplicationsModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                                        autorisation: autorisation, stock: stock)
        return Banc(modele: modele, autorisation: autorisation, stock: stock)
    }

    // MARK: L'autorisation

    @Test func avantLaLectureRienNEstMontre() {
        let m = fabriquer().modele
        #expect(m.acces == .lecture)
        #expect(m.texteAcces == nil)
        #expect(m.boutonDemande == nil)
        #expect(m.peutChoisir == false)
        #expect(m.resume.isEmpty)
        #expect(m.peutToutRetirer == false)
        #expect(m.titre == Libelle("apps_title"))
        #expect(m.titreAutorisation == Libelle("reglages_autorisation_temps_ecran"))
        #expect(m.boutonChoisir == Libelle("action_pick_apps"))
        #expect(m.boutonToutRetirer == Libelle("apps_clear"))
    }

    @Test func jamaisDemandeeOnProposeDAccorder() async {
        let m = fabriquer(etat: .nonDemandee).modele
        await m.ouvrir()
        #expect(m.acces == .aDemander)
        #expect(m.texteAcces == Libelle("applications_autorisation_a_demander"))
        #expect(m.accesAvertit == false)
        #expect(m.boutonDemande == Libelle("action_grant"))
        #expect(m.boutonReglages == nil)
        // Sans autorisation, le sélecteur ne s'ouvre pas.
        #expect(m.peutChoisir == false)
        m.choisir()
        #expect(m.selecteurOuvert == false)
    }

    @Test func accorderOuvreLeChoix() async {
        let banc = fabriquer(etat: .nonDemandee, issue: .accordee)
        let m = banc.modele
        await m.ouvrir()
        await m.demanderAutorisation()
        let demandes = await banc.autorisation.demandes
        #expect(demandes == 1)
        #expect(m.acces == .accordee)
        #expect(m.texteAcces == Libelle("applications_autorisation_accordee"))
        #expect(m.boutonDemande == nil)
        #expect(m.demandeEnCours == false)
        #expect(m.peutChoisir)
        m.choisir()
        #expect(m.selecteurOuvert)
    }

    /// Une autorisation accordée dont l'état tarde à suivre : la demande fait foi.
    @Test func lIssueAccordeeFaitFoiSiLEtatTarde() async {
        let m = fabriquer(etat: .nonDemandee, issue: .accordee, etatApres: .nonDemandee).modele
        await m.ouvrir()
        await m.demanderAutorisation()
        #expect(m.acces == .accordee)
        // Le retour au premier plan qui suit la feuille du système relit l'état, encore en retard : rien ne change.
        await m.rafraichir()
        #expect(m.acces == .accordee)
        #expect(m.peutChoisir)
    }

    /// Sans l'entitlement Family Controls, iOS refuse : l'écran le dit, et propose de réessayer.
    @Test func unEchecEstDitTelQuel() async {
        let banc = fabriquer(etat: .nonDemandee, issue: .echec)
        let m = banc.modele
        await m.ouvrir()
        await m.demanderAutorisation()
        #expect(m.acces == .echec)
        #expect(m.texteAcces == Libelle("applications_autorisation_echec"))
        #expect(m.accesAvertit)
        #expect(m.boutonDemande == Libelle("applications_reessayer"))
        #expect(m.boutonReglages == nil)
        #expect(m.peutChoisir == false)
        await m.demanderAutorisation()
        let demandes = await banc.autorisation.demandes
        #expect(demandes == 2)
    }

    @Test func uneRestrictionNeProposeRien() async {
        let m = fabriquer(etat: .nonDemandee, issue: .restreinte).modele
        await m.ouvrir()
        await m.demanderAutorisation()
        #expect(m.acces == .restreinte)
        #expect(m.texteAcces == Libelle("applications_autorisation_restreinte"))
        #expect(m.accesAvertit)
        #expect(m.boutonDemande == nil)
        #expect(m.boutonReglages == nil)
    }

    @Test func unRefusProposeLesReglages() async {
        let m = fabriquer(etat: .refusee).modele
        await m.ouvrir()
        #expect(m.acces == .refusee)
        #expect(m.texteAcces == Libelle("applications_autorisation_refusee"))
        #expect(m.accesAvertit)
        #expect(m.boutonReglages == Libelle("applications_ouvrir_reglages"))
        #expect(m.boutonDemande == Libelle("action_grant"))
        #expect(m.peutChoisir == false)
    }

    /// La feuille fermée sans répondre : selon l'état qu'iOS en garde, encore à demander, ou refusé.
    @Test func uneFeuilleFermeeSuitLEtat() async {
        let sansReponse = fabriquer(etat: .nonDemandee, issue: .annulee).modele
        await sansReponse.ouvrir()
        await sansReponse.demanderAutorisation()
        #expect(sansReponse.acces == .aDemander)
        let refus = fabriquer(etat: .nonDemandee, issue: .annulee, etatApres: .refusee).modele
        await refus.ouvrir()
        await refus.demanderAutorisation()
        #expect(refus.acces == .refusee)
    }

    /// Le retour des Réglages d'iOS : l'état relu remplace le refus comme l'échec.
    @Test func leRetourDesReglagesRelitLAutorisation() async {
        let banc = fabriquer(etat: .nonDemandee, issue: .echec)
        let m = banc.modele
        await m.ouvrir()
        await m.demanderAutorisation()
        #expect(m.acces == .echec)
        await banc.autorisation.regler(.accordee)
        await m.rafraichir()
        #expect(m.acces == .accordee)
    }

    // MARK: Le compte

    @Test func sansSelectionLAvertissementDAndroid() async {
        let m = fabriquer().modele
        await m.ouvrir()
        #expect(m.selectionLue)
        #expect(m.resume == [Libelle("apps_none_warning")])
        #expect(m.resumeAvertit)
        #expect(m.nombreDeJetons == 0)
        #expect(m.montrerJetons == false)
        #expect(m.peutToutRetirer == false)
        #expect(m.donnees == nil)
    }

    @Test func leResumeCompteApplicationsCategoriesEtSites() async {
        let compte = ApplicationsCompte(applications: 3, categories: 2, sites: 1)
        let m = fabriquer(donnees: Self.octets, comptes: [Self.octets: compte]).modele
        await m.ouvrir()
        let attendu = [Libelle.pluriel("apps_selected", quantite: 3, .entier(3)),
                       Libelle("applications_categories", .entier(2)),
                       Libelle("applications_sites", .entier(1))]
        #expect(m.resume == attendu)
        #expect(m.resumeAvertit == false)
        #expect(m.nombreDeJetons == 6)
        #expect(m.donnees == Self.octets)
        #expect(m.montrerJetons)
        #expect(m.peutToutRetirer)
    }

    /// Une catégorie seule : pas de « 0 application ».
    @Test func uneCategorieSeuleSansLigneDApplications() async {
        let compte = ApplicationsCompte(categories: 1)
        let m = fabriquer(donnees: Self.octets, comptes: [Self.octets: compte]).modele
        await m.ouvrir()
        #expect(m.resume == [Libelle("applications_categories", .entier(1))])
    }

    /// Les jetons ne se dessinent qu'avec l'autorisation.
    @Test func lesJetonsAttendentLAutorisation() async {
        let compte = ApplicationsCompte(applications: 2)
        let m = fabriquer(etat: .refusee, donnees: Self.octets, comptes: [Self.octets: compte]).modele
        await m.ouvrir()
        #expect(m.montrerJetons == false)
        #expect(m.peutToutRetirer)
    }

    @Test func unCompteNegatifVautZero() {
        let compte = ApplicationsCompte(applications: -2, categories: 1, sites: -1)
        #expect(compte.total == 1)
        #expect(ApplicationsCompte.vide.total == 0)
    }

    // MARK: Les 50 applications

    @Test func laLimiteDesCinquanteApplications() async {
        func modele(_ n: Int, categories: Int = 0) async -> ApplicationsModele {
            let compte = ApplicationsCompte(applications: n, categories: categories)
            let m = fabriquer(donnees: Self.octets, comptes: [Self.octets: compte]).modele
            await m.ouvrir()
            return m
        }
        let sous = await modele(49)
        #expect(sous.limite == nil)
        #expect(sous.texteLimite == nil)
        let juste = await modele(50)
        #expect(juste.limite == .atteinte)
        #expect(juste.texteLimite == Libelle("applications_limite", .entier(50)))
        let trop = await modele(51)
        #expect(trop.limite == .depassee)
        #expect(trop.texteLimite == Libelle("applications_trop", .entier(51), .entier(50)))
        // Une catégorie vaut un jeton, et n'a pas de limite : seules les applications comptent.
        let categories = await modele(49, categories: 30)
        #expect(categories.limite == nil)
        #expect(ApplicationsModele.limiteApplications == 50)
    }

    // MARK: Retenir

    @Test func retenirEcritEtCompte() async {
        let compte = ApplicationsCompte(applications: 4)
        let banc = fabriquer(comptes: [Self.octets: compte])
        let m = banc.modele
        await m.ouvrir()
        await m.retenir(Self.octets)
        let ecritures = await banc.stock.ecritures
        #expect(ecritures == [Self.octets])
        #expect(m.donnees == Self.octets)
        #expect(m.compte == compte)
        #expect(m.resume == [Libelle.pluriel("apps_selected", quantite: 4, .entier(4))])
        // La même sélection rendue une seconde fois : rien n'est réécrit.
        await m.retenir(Self.octets)
        let encore = await banc.stock.ecritures
        #expect(encore.count == 1)
        #expect(m.message == nil)
    }

    /// Le sélecteur rendu vide efface ce qui était gardé ; vide sur vide, rien n'est écrit.
    @Test func uneSelectionVideEfface() async {
        let compte = ApplicationsCompte(applications: 2)
        let banc = fabriquer(donnees: Self.octets, comptes: [Self.octets: compte])
        let m = banc.modele
        await m.ouvrir()
        await m.retenir(Self.vides)
        let ecritures = await banc.stock.ecritures
        #expect(ecritures == [nil])
        #expect(m.donnees == nil)
        #expect(m.compte == .vide)
        await m.retenir(Self.vides)
        let encore = await banc.stock.ecritures
        #expect(encore.count == 1)
    }

    /// Des octets que l'app n'a pu encoder, ou qui ne sont pas une sélection : rien n'est écrit, et on le dit.
    @Test func desOctetsIllisiblesNeSEcriventPas() async {
        let banc = fabriquer()
        let m = banc.modele
        await m.ouvrir()
        await m.retenir(nil)
        #expect(m.message == Libelle("applications_echec_ecriture"))
        m.message = nil
        await m.retenir(Self.autres)
        #expect(m.message == Libelle("applications_echec_ecriture"))
        let ecritures = await banc.stock.ecritures
        #expect(ecritures.isEmpty)
    }

    @Test func uneEcritureRefuseeGardeLAncienneSelection() async {
        let ancien = ApplicationsCompte(applications: 1)
        let neuf = ApplicationsCompte(applications: 5)
        let banc = fabriquer(donnees: Self.octets, comptes: [Self.octets: ancien, Self.autres: neuf], refuse: true)
        let m = banc.modele
        await m.ouvrir()
        await m.retenir(Self.autres)
        #expect(m.message == Libelle("applications_echec_ecriture"))
        #expect(m.donnees == Self.octets)
        #expect(m.compte == ancien)
    }

    @Test func toutRetirerEfface() async {
        let compte = ApplicationsCompte(applications: 2, sites: 3)
        let banc = fabriquer(donnees: Self.octets, comptes: [Self.octets: compte])
        let m = banc.modele
        await m.ouvrir()
        await m.toutRetirer()
        let ecritures = await banc.stock.ecritures
        #expect(ecritures == [nil])
        #expect(m.donnees == nil)
        #expect(m.resume == [Libelle("apps_none_warning")])
        #expect(m.peutToutRetirer == false)
        // Plus rien à retirer : rien n'est écrit.
        await m.toutRetirer()
        let encore = await banc.stock.ecritures
        #expect(encore.count == 1)
    }

    /// Des octets gardés qui ne sont plus une sélection : la refaire, ou tout retirer.
    @Test func uneSelectionIllisibleEstARefaire() async {
        let banc = fabriquer(donnees: Self.autres)
        let m = banc.modele
        await m.ouvrir()
        #expect(m.selectionIllisible)
        #expect(m.texteIllisible == Libelle("gate_reselect_detail"))
        #expect(m.donnees == nil)
        #expect(m.peutToutRetirer)
        await m.toutRetirer()
        #expect(m.selectionIllisible == false)
        #expect(m.texteIllisible == nil)
        let ecritures = await banc.stock.ecritures
        #expect(ecritures == [nil])
    }

    /// Une sélection vide retenue sur une sélection illisible l'efface quand même.
    @Test func uneSelectionVideRemplaceLIllisible() async {
        let banc = fabriquer(donnees: Self.autres)
        let m = banc.modele
        await m.ouvrir()
        await m.retenir(Self.vides)
        #expect(m.selectionIllisible == false)
        let ecritures = await banc.stock.ecritures
        #expect(ecritures == [nil])
    }

    @Test func desReglagesIntrouvables() {
        let m = fabriquer().modele
        m.reglagesImpossibles()
        #expect(m.message == Libelle("settings_screen_missing"))
    }

    // MARK: L'aide-mémoire d'Android

    @Test func sansListeDAndroidPasDAideMemoire() {
        let m = fabriquer().modele
        #expect(m.aideMemoire == nil)
        #expect(m.applicationsAndroid.isEmpty)
    }

    @Test func laListeDAndroidTrieeEnAideMemoire() {
        let m = fabriquer(android: ["com.whatsapp", "com.instagram.android"]).modele
        #expect(m.applicationsAndroid == ["com.instagram.android", "com.whatsapp"])
        #expect(m.aideMemoire == Libelle("applications_android_aide", .texte("com.instagram.android, com.whatsapp")))
    }

    // MARK: Les catalogues

    /// Chaque clé montrée est dans le catalogue d'Android ou dans ios.xcstrings ; les chaînes d'iOS ont leurs trois
    /// langues et les mêmes marqueurs dans chacune ; et elles se mettent en forme.
    @Test func lesClesSontDansLesCatalogues() async throws {
        let android = try CatalogueBrut.lire()
        let ios = try JSONDecoder().decode(CatalogueBrut.self,
                                           from: Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings"))
        var libelles: [Libelle] = []
        let etats: [(AppsAutorisationEtat, AppsDemandeIssue)] = [
            (.nonDemandee, .accordee), (.nonDemandee, .echec), (.nonDemandee, .restreinte),
            (.refusee, .annulee), (.accordee, .accordee),
        ]
        for (etat, issue) in etats {
            let m = fabriquer(etat: etat, issue: issue).modele
            await m.ouvrir()
            libelles += [m.texteAcces, m.boutonDemande, m.boutonReglages].compactMap { $0 }
            await m.demanderAutorisation()
            libelles += [m.texteAcces, m.boutonDemande, m.boutonReglages].compactMap { $0 }
        }
        for n in [50, 51] {
            let compte = ApplicationsCompte(applications: n, categories: 1, sites: 1)
            let m = fabriquer(donnees: Self.octets, comptes: [Self.octets: compte],
                              android: ["com.whatsapp"]).modele
            await m.ouvrir()
            libelles += m.resume
            libelles += [m.texteLimite, m.aideMemoire].compactMap { $0 }
        }
        let illisible = fabriquer(donnees: Self.autres).modele
        await illisible.ouvrir()
        libelles += illisible.resume
        libelles += [illisible.texteIllisible].compactMap { $0 }
        let m = fabriquer().modele
        libelles += [m.titre, m.indication, m.titreAutorisation, m.titreSelection, m.boutonChoisir,
                     m.boutonToutRetirer, Libelle("applications_autorisation_attente"),
                     Libelle("applications_echec_ecriture"), Libelle("settings_screen_missing")]

        let cles = Set(libelles.map { $0.cle })
        let absentes = cles.filter { android.strings[$0] == nil && ios.strings[$0] == nil }.sorted()
        #expect(absentes.isEmpty, "\(absentes)")

        let marqueurs = ["%1$lld", "%2$lld", "%1$@"]
        for cle in cles.sorted() where ios.strings[cle] != nil {
            let fr = ios.valeur(cle, langue: "fr")
            #expect(fr != nil, "\(cle) sans français")
            for langue in ["en", "he"] {
                let valeur = ios.valeur(cle, langue: langue)
                #expect(valeur != nil, "\(cle) sans \(langue)")
                for marqueur in marqueurs {
                    let ici = valeur?.contains(marqueur) ?? false
                    let enFrancais = fr?.contains(marqueur) ?? false
                    #expect(ici == enFrancais, "\(cle) en \(langue) : \(marqueur)")
                }
            }
        }

        func texte(_ libelle: Libelle, _ langue: String) -> String? {
            libelle.texte(langue: langue,
                          chaine: { cle in ios.valeur(cle, langue: langue) ?? android.valeur(cle, langue: langue) },
                          pluriel: { cle, forme in android.forme(cle, forme, langue: langue) })
        }
        let trop = texte(Libelle("applications_trop", .entier(51), .entier(50)), "fr") ?? ""
        let tropDebut = trop.hasPrefix("51 applications choisies")
        #expect(tropDebut, "\(trop)")
        let tropLimite = trop.contains("que 50 à la fois")
        #expect(tropLimite, "\(trop)")
        let aide = texte(Libelle("applications_android_aide", .texte("com.instagram.android, com.whatsapp")), "en")
        let aideDebut = aide?.hasPrefix("On Android, you held back: com.instagram.android, com.whatsapp.") ?? false
        #expect(aideDebut, "\(aide ?? "")")
        let sites = texte(Libelle("applications_sites", .entier(3)), "he")
        #expect(sites == "אתרים: 3")
    }
}
