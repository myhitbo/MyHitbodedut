import Foundation
import Testing
import Coeur
import Barriere
@testable import Ecrans

// Les écrans de la barrière (tâches 27 et 28) : l'aperçu du bouclier et l'essai réel (GateService.preview,
// BlockerView), le choix des applications (AppPickerActivity), la dédicace (Dedicace.kt, DedicaceTest.kt) et le journal
// de la barrière (PORTAGE.md § 2.1.8). Ce que le système fait (FamilyActivityPicker, les magasins, les extensions) reste
// à l'iPhone ; ici, ce que chaque écran montre et ce que fait chaque geste.

/// Les deux catalogues de l'app, comme MyHitbodedutApp les lit.
private func traducteur(_ langue: String = "fr") throws -> Traducteur {
    try Traducteur(catalogues: [Fichiers.catalogue(), Fichiers.donnees("ios/Ressources/Chaines/ios.xcstrings")], langue: langue)
}

private let lundi = JourCivil(iso: "2026-11-16")!

/// Le lundi 16 novembre 2026, 9 h à Paris.
private func horloge(heure: Int = 9) throws -> HorlogeFixe {
    let paris = try #require(Fuseau("Europe/Paris"))
    return HorlogeFixe(DateHeure(lundi, heure: heure), fuseau: paris)
}

@Suite("Écrans de la barrière")
@MainActor
struct BarriereEcransTests {

    // MARK: L'aperçu du bouclier

    /// La réplique montre ce que l'extension montrera : les mêmes textes, dans la langue de l'app, la même règle
    /// (`PlanBouclier`), visage par visage, avec la durée, le report et la série du moment.
    @Test func laRepliqueDuBouclier() async throws {
        var reglages = Reglages()
        reglages.setEnabled(true)
        reglages.setTargetMinutes(20)
        reglages.setSnoozeMinutes(10)
        let m = try ApercuBouclierModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)),
                                         horloge: horloge(), traducteur: traducteur(), palette: nil,
                                         systeme: FausseBarriereSysteme(selection: SelectionResume(applications: 3)))
        await m.rafraichir()
        #expect(ApercuBouclierModele.faces == [.invite, .autreReponse, .seance, .apercu])
        #expect(m.face == .invite)
        let invite = m.contenu
        #expect(invite.titre == "Avez-vous fait votre hitbodedout\u{202F}?")
        #expect(invite.principal == "Commencer maintenant, 20 min")
        #expect(invite.secondaire == "Autre réponse")
        #expect(invite.sousMenu == ["Je l’ai faite sans le téléphone", "Plus tard (10 min)"])
        #expect(invite.sousTitre.hasSuffix("Première journée de la série."))
        #expect(invite.apparence.fond == "#173C32")
        #expect(m.image == Poses.call(lundi))
        m.face = .seance
        #expect(m.contenu.titre == "Hitbodedout en cours")
        #expect(m.contenu.principal == "Revenir à la hitbodedout")
        m.face = .apercu
        #expect(m.contenu.sousTitre.hasPrefix("APERÇU, AUCUN EFFET"))
        #expect(m.contenu.principal == "Fermer l’aperçu")
        #expect(m.libelle(.invite) == Libelle("bouclier_visage_invite"))
        #expect(m.libelle(.seance) == Libelle("blocker_session_title"))
        // En hébreu, les textes d'Android en hébreu.
        let he = try ApercuBouclierModele(magasin: Magasin.enMemoire(), horloge: horloge(), traducteur: traducteur("he"),
                                          palette: nil, systeme: FausseBarriereSysteme())
        #expect(he.contenu.titre == "התבודדתם היום?")
    }

    /// L'essai réel : seulement avec l'accès et au moins une application ; une fois lancé, la ligne dit jusqu'à quand,
    /// et le visage montré est celui de l'essai.
    @Test func lEssaiReel() async throws {
        let systeme = FausseBarriereSysteme(autorise: false, selection: SelectionResume())
        let h = try horloge()
        let m = try ApercuBouclierModele(magasin: Magasin.enMemoire(), horloge: h, traducteur: traducteur(), palette: nil,
                                         systeme: systeme)
        #expect(!m.essaiPossible)
        #expect(m.etatEssai == Libelle("bouclier_essai_explication"))
        await m.rafraichir()
        #expect(!m.essaiPossible)
        #expect(m.etatEssai == Libelle("bouclier_essai_sans_acces"))
        await systeme.regler(autorise: true, selection: SelectionResume())
        await m.rafraichir()
        #expect(m.etatEssai == Libelle("apps_none_warning"))
        await m.essayer()
        let rien = await systeme.essais
        #expect(rien == 0)
        await systeme.regler(autorise: true, selection: SelectionResume(categories: 1))
        await m.rafraichir()
        #expect(m.essaiPossible)
        await m.essayer()
        let essais = await systeme.essais
        #expect(essais == 1)
        // Le faux rend 120 000 : déjà passé à 9 h ; un vrai essai finit deux minutes plus tard.
        #expect(m.face == .apercu)
        #expect(m.message == Libelle("bouclier_essai_lance"))
        m.messageVu()
        #expect(m.message == nil)

        let enCours = FausseBarriereSysteme(autorise: true, selection: SelectionResume(applications: 1),
                                            dureeEssai: h.maintenant + 120_000)
        let e = try ApercuBouclierModele(magasin: Magasin.enMemoire(), horloge: h, traducteur: traducteur(), palette: nil,
                                         systeme: enCours)
        await e.rafraichir()
        await e.essayer()
        #expect(e.essaiEnCours)
        #expect(!e.essaiPossible)
        #expect(e.etatEssai == Libelle("bouclier_essai_en_cours", .texte("09:02")))
        // Un essai refusé par le système le dit.
        let refus = try ApercuBouclierModele(magasin: Magasin.enMemoire(), horloge: h, traducteur: traducteur(), palette: nil,
                                             systeme: FausseBarriereSysteme(selection: SelectionResume(sites: 2), dureeEssai: nil))
        await refus.rafraichir()
        await refus.essayer()
        #expect(refus.message == Libelle("bouclier_essai_echec"))
        #expect(refus.face == .invite)
    }

    // MARK: Le choix des applications

    @Test func leChoixDesApplications() async throws {
        var reglages = Reglages()
        reglages.setBlockedApps(["com.instagram.android", "com.whatsapp", "com.google.android.youtube", "org.telegram.messenger",
                                 "com.instagram.lite"])
        let systeme = FausseBarriereSysteme(autorise: true, selection: SelectionResume())
        let m = ChoixApplicationsModele(magasin: Magasin.enMemoire(Enregistrement(reglages: reglages)), systeme: systeme)
        #expect(m.titre == Libelle("apps_title"))
        #expect(m.choixPossible)
        await m.rafraichir()
        #expect(m.comptes == [Libelle("apps_none_warning")])
        #expect(m.couleurComptes == "warning")
        #expect(!m.retraitPossible)
        #expect(m.avertissementLimite == nil)
        #expect(m.aideMemoire == Libelle("apps_ios_android", .texte("instagram, telegram, whatsapp, youtube")))
        m.selectionEnregistree(SelectionResume(applications: 51, categories: 2, sites: 1))
        #expect(m.comptes == [Libelle.pluriel("apps_selected", quantite: 51, .entier(51)),
                              Libelle("apps_ios_categories", .entier(2)), Libelle("apps_ios_sites", .entier(1))])
        #expect(m.couleurComptes == "muted")
        #expect(m.avertissementLimite == Libelle("apps_ios_limite", .entier(50)))
        #expect(m.retraitPossible)
        m.selectionEnregistree(SelectionResume(applications: 50))
        #expect(m.avertissementLimite == nil)
        #expect(m.comptes.count == 1)
        // Sans l'accès, le sélecteur ne s'ouvre pas, et l'écran dit pourquoi.
        await systeme.regler(autorise: false, selection: SelectionResume(applications: 2))
        await m.rafraichir()
        #expect(!m.choixPossible)
        #expect(m.sansAcces == Libelle("bouclier_essai_sans_acces"))
        // Sans liste d'Android, pas d'aide-mémoire.
        let sans = ChoixApplicationsModele(magasin: Magasin.enMemoire(), systeme: systeme)
        #expect(sans.aideMemoire == nil)
    }

    @Test func lesNomsCourtsDesPaquetsDAndroid() {
        #expect(ChoixApplicationsModele.nomCourt("com.instagram.android") == "instagram")
        #expect(ChoixApplicationsModele.nomCourt("com.facebook.katana") == "facebook")
        #expect(ChoixApplicationsModele.nomCourt("com.google.android.youtube") == "youtube")
        #expect(ChoixApplicationsModele.nomCourt("org.telegram.messenger") == "telegram")
        #expect(ChoixApplicationsModele.nomCourt("com.twitter.android") == "twitter")
        #expect(ChoixApplicationsModele.nomCourt("com.android") == "android")
        #expect(ChoixApplicationsModele.nomCourt("Netflix") == "netflix")
    }

    // MARK: La dédicace (DedicaceTest.kt)

    @Test func leCorpsPorteLaFormuleHebraiqueEtLeNom() {
        let c = DedicaceModele.corps(intro: "Bonjour,", demande: "Je souhaite dédier ma hitbodedout :", formule: "לעילוי נשמת",
                                     nom: " Moché ben Sarah ", mot: "", fin: "Envoyé depuis l’application MyHitbodedut.")
        #expect(c == "Bonjour,\n\nJe souhaite dédier ma hitbodedout :\nלעילוי נשמת Moché ben Sarah\n\nEnvoyé depuis l’application MyHitbodedut.")
        let autre = DedicaceModele.corps(intro: "Hello,", demande: "I would like to dedicate my study:", formule: nil,
                                         nom: "Sarah bat Rivka", mot: "Merci", fin: "Sent.")
        #expect(autre.contains("\nSarah bat Rivka\n\nMerci\n"))
    }

    @Test func leLienVaALEquipeEncodeSansPlus() throws {
        let l = DedicaceModele.lien(sujet: "Dédicace – Mon étude", corps: "a b\nc & d")
        #expect(l.hasPrefix("mailto:myhitbodedut26@gmail.com?subject="))
        #expect(!l.contains("+"))
        let corps = try #require(l.components(separatedBy: "&body=").last?.removingPercentEncoding)
        #expect(corps == "a b\nc & d")
        #expect(DedicaceModele.encoder("a-b.c*d_e~f") == "a-b.c*d_e%7Ef")
        #expect(DedicaceModele.encoder("é") == "%C3%A9")
        #expect(DedicaceModele.minusculeInitiale("Ma hitbodedout") == "ma hitbodedout")
    }

    /// Les refus de la boîte d'Android : sans nom, puis « Autre intention » sans mot ; le message, dans la langue de
    /// l'app, avec la formule en hébreu.
    @Test func laDedicaceSEcrit() throws {
        let m = try DedicaceModele(traducteur: traducteur())
        #expect(m.indiceMot == Libelle("dedicace_mot"))
        #expect(m.ecrire() == nil)
        #expect(m.erreurNom == Libelle("dedicace_nom_manque"))
        m.nom = "Moché ben Sarah"
        #expect(m.erreurNom == nil)
        m.intention = .autre
        #expect(m.indiceMot == Libelle("dedicace_intention_manque"))
        #expect(m.ecrire() == nil)
        #expect(m.erreurMot == Libelle("dedicace_intention_manque"))
        m.intention = .refoua
        #expect(m.erreurMot == nil)
        m.objet = .etude
        let message = try #require(m.ecrire())
        #expect(message.sujet == "Dédicace – Mon étude")
        #expect(message.corps.contains("mon étude"))
        #expect(message.corps.contains("לרפואה שלמה Moché ben Sarah"))
        #expect(message.lien.hasPrefix("mailto:" + DedicaceModele.adresse + "?subject="))
        m.sansMessagerie(copie: true)
        #expect(m.avis == [Libelle("dedicace_sans_messagerie"), Libelle("dedicace_copie")])
        m.sansMessagerie(copie: false)
        #expect(m.avis == [Libelle("dedicace_sans_messagerie")])
        #expect(DedicaceIntention.allCases.map(\.formule) == ["לעילוי נשמת", "לרפואה שלמה", "להצלחה", "לזיווג הגון", nil])
    }

    // MARK: Le journal de la barrière

    @Test func leJournalDeLaBarriere() async throws {
        let quand = Horodatage(millis: 1, jour: "2026-11-16", minutes: 6 * 60 + 2)
        let evenements = [
            Evenement(quand: quand, genre: .reveil, detail: "fenetre"),
            Evenement(quand: quand, genre: .armee, detail: AgentBarriere.surveillance.rawValue),
            Evenement(quand: quand, genre: .plusTard, detail: "15"),
            Evenement(quand: quand, genre: .levee, detail: AgentBarriere.bouclier.rawValue),
            Evenement(quand: quand, genre: .dejaFaite),
            Evenement(quand: quand, genre: .essai, detail: Etat.essaiCommence),
            Evenement(quand: quand, genre: .essai, detail: Etat.essaiFini),
            Evenement(quand: quand, genre: .inscrite),
            Evenement(quand: quand, genre: "nouveau"),
        ]
        let m = JournalBarriereModele(systeme: FausseBarriereSysteme(journal: evenements))
        #expect(m.vide == nil)
        await m.rafraichir()
        #expect(m.lignes.count == 9)
        #expect(m.lignes.first?.texte == Libelle("journal_barriere_inconnu", .texte("nouveau")))
        #expect(m.lignes.last?.texte == Libelle("journal_barriere_reveil", .libelle(Libelle("journal_barriere_activite_fenetre"))))
        #expect(m.lignes.last?.quand == "16/11 06:02")
        let textes = m.lignes.map(\.texte)
        #expect(textes.contains(Libelle("journal_barriere_report", .entier(15))))
        #expect(textes.contains(Libelle("journal_barriere_bouton", .libelle(Libelle("blocker_already_done")))))
        #expect(textes.contains(Libelle("journal_barriere_levee", .libelle(Libelle("journal_barriere_par_bouclier")))))
        let t = try traducteur()
        let partage = m.partage(t)
        #expect(partage.hasPrefix("Journal de la barrière\n16/11 06:02  Événement"))
        #expect(partage.contains("Bouton «\u{00A0}Je l’ai faite sans le téléphone\u{00A0}»"))
        let vide = JournalBarriereModele(systeme: FausseBarriereSysteme())
        await vide.rafraichir()
        #expect(vide.vide == Libelle("journal_barriere_vide"))
    }

    // MARK: Les clés

    /// Chaque clé que ces écrans montrent existe dans l'un des deux catalogues, dans les cinq langues.
    @Test func lesClesSontDansLesCatalogues() throws {
        var libelles: [Libelle] = []
        let quand = Horodatage(millis: 1, jour: "2026-11-16", minutes: 0)
        for genre in Evenement.Genre.allCases {
            for detail in ["", "fin", "fenetre", "minuit", "report", "seance", "essai", "surveillance", "app", "bouclier",
                           "correction"] {
                libelles.append(JournalBarriereModele.libelle(Evenement(quand: quand, genre: genre, detail: detail)))
            }
        }
        libelles += [Libelle("journal_barriere_titre"), Libelle("journal_barriere_vide"), Libelle("bouclier_visage_invite"),
                     Libelle("bouclier_visage_essai"), Libelle("bouclier_apercu_titre"), Libelle("bouclier_apercu_explication"),
                     Libelle("bouclier_essai"), Libelle("bouclier_essai_explication"), Libelle("bouclier_essai_en_cours", .texte("9:02")),
                     Libelle("bouclier_essai_sans_acces"), Libelle("bouclier_essai_echec"), Libelle("bouclier_essai_lance"),
                     Libelle("apps_ios_explication"), Libelle("apps_ios_categories", .entier(1)), Libelle("apps_ios_sites", .entier(1)),
                     Libelle("apps_ios_limite", .entier(50)), Libelle("apps_ios_android", .texte("x")), Libelle("apps_title"),
                     Libelle("apps_clear"), Libelle("action_pick_apps"), Libelle("reglages_fenetre_courte"),
                     Libelle("temps_ecran_divulgation_titre"), Libelle("temps_ecran_divulgation_texte"),
                     Libelle("temps_ecran_divulgation_pas_maintenant"), Libelle("celebration_continue"), Libelle("chizuk_partager"),
                     Libelle("section_dedicace"), Libelle("section_dedicace_hint"), Libelle("dedicace_quoi"), Libelle("dedicace_pour"),
                     Libelle("dedicace_nom"), Libelle("dedicace_ecrire"), Libelle("action_back"), Libelle("settings_window_same")]
        libelles += DedicaceObjet.allCases.map(\.libelle) + DedicaceIntention.allCases.map(\.libelle)
        libelles += ReglagesActionBarriere.allCases.map(\.libelle)
        for langue in ["fr", "en", "he", "es", "ar"] {
            let t = try traducteur(langue)
            for libelle in libelles {
                let texte = t.texte(libelle)
                #expect(!texte.isEmpty && !texte.contains(libelle.cle), "\(langue) : \(libelle.cle)")
            }
        }
    }
}
