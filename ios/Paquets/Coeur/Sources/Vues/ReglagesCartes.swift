import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les cartes de l'écran Réglages, dans l'ordre d'activity_settings.xml : langue, apparence, écran Zmanim, état du
// mode, « Je suis avec Hachem », rythme, autorisations, dédicace, réinitialisation (la carte des données, qui tient
// les sélecteurs de fichiers, est dans ReglagesVue.swift). Chaque carte lit le modèle et lui passe les gestes ; les
// routes rendues vont à l'aiguillage.

// MARK: 1. Langue

/// La langue (les Réglages d'iOS, § 2.2.7), l'adresse, et « Revoir la présentation ».
struct ReglagesCarteLangue: View {
    let modele: ReglagesModele
    let aiguillage: ReglagesAiguillage
    let largeurValeur: CGFloat?
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            let langue = t("settings_language")
            ReglagesLigne(langue, margeHaute: false) {
                ReglagesBoutonValeur(reglagesTexte(modele.nomLangue, traducteur), intitule: langue,
                                     largeurMax: largeurValeur) {
                    aiguillage.suivre(modele.routeLangue)
                }
            }
            let adresse = t("settings_adresse")
            ReglagesLigne(adresse) {
                ReglagesBoutonValeur(Text(modele.adresse, traducteur: traducteur), intitule: adresse,
                                     largeurMax: largeurValeur) {
                    modele.dialogue = .choix(.adresse)
                }
            }
            Button {
                aiguillage.suivre(modele.routePresentation)
            } label: {
                t("settings_onboarding")
            }
            .buttonStyle(ReglagesBoutonTexte())
            .padding(.top, 4)
        }
    }

    private func t(_ cle: String) -> Text {
        reglagesTexte(cle, traducteur)
    }
}

// MARK: 2. Apparence

/// Le mode, le fond, l'accent, l'icône (iOS), la police, le grand texte et l'écran d'ouverture.
struct ReglagesCarteApparence: View {
    let modele: ReglagesModele
    let aiguillage: ReglagesAiguillage
    let largeurValeur: CGFloat?
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ReglagesTitreCarte("section_appearance", indication: "section_appearance_hint")
            ligneChoix("settings_mode", modele.mode, .mode)
            ligneChoix("settings_fond", modele.fond, .fond)
            ligneChoix("settings_accent", modele.accent, .accent)
            ligneIcone
            ligneChoix("settings_police", modele.police, .police)
            ReglagesLigneInterrupteur(t("settings_grand_texte"), actif: aiguillage.liaison(.grandTexte))
            ligneChoix("settings_ouverture", modele.ouverture, .ouverture)
        }
    }

    /// L'icône de l'app aux couleurs choisies : iOS ne la change que sur un geste, et prévient lui-même (§ 2.3).
    private var ligneIcone: some View {
        let intitule = t("reglages_icone")
        return ReglagesLigne(intitule) {
            if modele.iconeAJour {
                t("reglages_icone_a_jour")
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.trailing)
                    .reglagesLargeurMax(largeurValeur)
            } else {
                Button {
                    Task.immediate { @MainActor [modele] in
                        await modele.mettreIconeAuxCouleurs()
                    }
                } label: {
                    t("reglages_icone_appliquer")
                        .lineLimit(2)
                }
                .buttonStyle(.secondaire)
                .accessibilityLabel(intitule)
                .accessibilityValue(t("reglages_icone_appliquer"))
                .reglagesLargeurMax(largeurValeur)
            }
        }
    }

    /// RemindersActivity : la ligne mène à l'écran des rappels ; dessous, leur état.
    private var ligneRappels: some View {
        let intitule = t("reminders_title")
        return ReglagesLigne(intitule, indication: Text(modele.etatRappels, traducteur: traducteur)) {
            ReglagesBoutonValeur(t("reminders_open"), intitule: intitule, largeurMax: largeurValeur) {
                aiguillage.suivre(modele.routeRappels)
            }
        }
    }

    private func ligneChoix(_ cle: String, _ valeur: Libelle, _ liste: ReglagesListe) -> some View {
        let intitule = t(cle)
        return ReglagesLigne(intitule) {
            ReglagesBoutonValeur(Text(valeur, traducteur: traducteur), intitule: intitule,
                                 largeurMax: largeurValeur) {
                modele.dialogue = .choix(liste)
            }
        }
    }

    private func t(_ cle: String) -> Text {
        reglagesTexte(cle, traducteur)
    }
}

// MARK: 3. Écran Zmanim

/// Ce que montre l'écran des zmanim : Levana et son rappel, son usage, les hilloulot, la halakha et sa source.
struct ReglagesCarteZmanim: View {
    let modele: ReglagesModele
    let aiguillage: ReglagesAiguillage
    let largeurValeur: CGFloat?
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ReglagesTitreCarte("section_zmanim_ecran", indication: "section_zmanim_ecran_hint")
            ReglagesLigneInterrupteur(t("reglage_levana"), actif: aiguillage.liaison(.levana))
            ReglagesLigneInterrupteur(t("levana_rappel_reglage"), actif: aiguillage.liaison(.levanaRappel))
            ligneChoix("levana_usage_titre", modele.usageLevana, .usageLevana)
            ReglagesLigneInterrupteur(t("hilloulot_afficher"), actif: aiguillage.liaison(.hilloulot))
            ReglagesLigneInterrupteur(t("halakha_afficher"), actif: aiguillage.liaison(.halakha))
            ligneChoix("halakha_source_titre", modele.sourceHalakha, .sourceHalakha)
        }
    }

    private func ligneChoix(_ cle: String, _ valeur: Libelle, _ liste: ReglagesListe) -> some View {
        let intitule = t(cle)
        return ReglagesLigne(intitule) {
            ReglagesBoutonValeur(Text(valeur, traducteur: traducteur), intitule: intitule,
                                 largeurMax: largeurValeur) {
                modele.dialogue = .choix(liste)
            }
        }
    }

    private func t(_ cle: String) -> Text {
        reglagesTexte(cle, traducteur)
    }
}

// MARK: 4. État du mode

/// L'état de « Je suis avec Hachem » (renderDiagnostic) : son titre en couleur, son détail, le bouton des
/// autorisations quand il en manque, et l'aperçu du bouclier.
struct ReglagesCarteEtatMode: View {
    let modele: ReglagesModele
    let carte: ReglagesCarteBarriere
    let aiguillage: ReglagesAiguillage
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ReglagesTitreCarte("section_gate_state")
            if carte.titreVisible {
                Text(carte.titre, traducteur: traducteur)
                    .font(Font.callout.bold())
                    .foregroundStyle(reglagesTeinte(carte.couleurTitre))
                    .padding(.top, 8)
            }
            Text(carte.detail, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 4)
            if carte.boutonAutorisations {
                Button {
                    modele.montrerAutorisations()
                } label: {
                    reglagesTexte("gate_permissions_action", traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
                .padding(.top, 12)
            }
            Button {
                aiguillage.suivre(modele.routeApercuBarriere)
            } label: {
                reglagesTexte("action_preview_gate", traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 12)
        }
    }
}

// MARK: 5. « Je suis avec Hachem »

/// Le mode lui-même : l'interrupteur, la fenêtre du matin, le report, les applications retenues.
struct ReglagesCarteMode: View {
    let modele: ReglagesModele
    let aiguillage: ReglagesAiguillage
    let largeurValeur: CGFloat?
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            interrupteur
            ReglagesSeparateur()
            fenetre
            let report = t("settings_snooze")
            ReglagesLigne(report) {
                ReglagesBoutonValeur(Text(modele.report, traducteur: traducteur), intitule: report,
                                     largeurMax: largeurValeur) {
                    modele.dialogue = .choix(.report)
                }
            }
            ReglagesSeparateur()
            Text(modele.applications, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(reglagesTeinte(modele.couleurApplications))
            Button {
                aiguillage.suivre(modele.routeChoixApplications)
            } label: {
                t("action_pick_apps")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 8)
        }
    }

    /// Le titre de la carte et son indication, avec l'interrupteur à leur bout : le Toggle s'appelle
    /// « section_gate » pour VoiceOver.
    private var interrupteur: some View {
        Toggle(isOn: aiguillage.liaison(.barriere)) {
            ReglagesTitreCarte("section_gate", indication: "section_gate_hint")
        }
        .tint(Teinte(.brand))
        .accessibilityLabel(t("section_gate"))
        .accessibilityHint(t("section_gate_hint"))
    }

    /// Le début et la fin de la fenêtre, deux boutons de valeur côte à côte.
    private var fenetre: some View {
        let intitule = t("settings_window")
        // Juste sous le séparateur : sans marge haute (layout_marginTop="0dp").
        return ReglagesLigne(intitule, margeHaute: false) {
            HStack(spacing: 8) {
                bouton(.debut, intitule: intitule)
                bouton(.fin, intitule: intitule)
            }
        }
    }

    private func bouton(_ borne: ReglagesBorne, intitule: Text) -> some View {
        ReglagesBoutonValeur(reglagesTexte(modele.texteHeure(borne), traducteur), intitule: intitule,
                             largeurMax: nil) {
            modele.dialogue = .heure(borne)
        }
    }

    private func t(_ cle: String) -> Text {
        reglagesTexte(cle, traducteur)
    }
}

// MARK: 6. Rythme

/// Le prénom, la durée, l'objectif, Chabbat, la région, le décompte, la concentration (iOS), la hitbodedout
/// guidée et la pause du jour.
struct ReglagesCarteRythme: View {
    let modele: ReglagesModele
    let aiguillage: ReglagesAiguillage
    let largeurValeur: CGFloat?
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ReglagesTitreCarte("section_rhythm")
            lignePrenom
            ligneChoix("settings_target", nil, modele.duree, .duree, margeHaute: true)
            ReglagesSeparateur()
            ligneChoix("settings_daily_goal", "settings_daily_goal_hint", modele.objectif, .objectif,
                       margeHaute: false)
            ReglagesSeparateur()
            ReglagesLigneInterrupteur(t("settings_shabbat"), indication: t("settings_shabbat_hint"),
                                      margeHaute: false, actif: aiguillage.liaison(.chabbat))
            ligneRegion
            ReglagesLigneInterrupteur(t("settings_hide_countdown"), indication: t("settings_hide_countdown_hint"),
                                      actif: aiguillage.liaison(.masquerDecompte))
            ligneConcentration
            ligneRappels
            ReglagesLigneInterrupteur(t("settings_hitbodedut"), indication: t("settings_hitbodedut_hint"),
                                      actif: aiguillage.liaison(.guidee))
            ReglagesLigneInterrupteur(t("settings_exempt_today"), indication: t("settings_exempt_today_hint"),
                                      actif: aiguillage.liaison(.pauseAujourdhui))
        }
    }

    private var lignePrenom: some View {
        let intitule = t("settings_name")
        return ReglagesLigne(intitule, indication: t("settings_name_hint")) {
            ReglagesBoutonValeur(reglagesTexte(modele.prenom, traducteur), intitule: intitule,
                                 largeurMax: largeurValeur) {
                modele.dialogue = .prenom
            }
        }
    }

    /// Israël ou diaspora : le toucher bascule, sans liste (region_button).
    private var ligneRegion: some View {
        let intitule = t("settings_region")
        return ReglagesLigne(intitule) {
            ReglagesBoutonValeur(Text(modele.region, traducteur: traducteur), intitule: intitule,
                                 largeurMax: largeurValeur) {
                Task.immediate { @MainActor [modele] in
                    do {
                        try await modele.basculerRegion()
                    } catch {
                        // La persistance a refusé d'écrire : rien de plus, comme Store sur Android.
                    }
                }
            }
        }
    }

    /// « Ne pas déranger » n'existe pas sur iOS : la ligne mène à l'aide du mode de concentration (§ 2.2.6).
    private var ligneConcentration: some View {
        let intitule = t("settings_ne_pas_deranger")
        return ReglagesLigne(intitule, indication: t("reglages_concentration_hint")) {
            ReglagesBoutonValeur(t("action_open"), intitule: intitule, largeurMax: largeurValeur) {
                aiguillage.suivre(modele.routeConcentration)
            }
        }
    }

    private func ligneChoix(_ cle: String, _ indication: String?, _ valeur: Libelle, _ liste: ReglagesListe,
                            margeHaute: Bool) -> some View {
        let intitule = t(cle)
        return ReglagesLigne(intitule, indication: indication.map { t($0) }, margeHaute: margeHaute) {
            ReglagesBoutonValeur(Text(valeur, traducteur: traducteur), intitule: intitule,
                                 largeurMax: largeurValeur) {
                modele.dialogue = .choix(liste)
            }
        }
    }

    private func t(_ cle: String) -> Text {
        reglagesTexte(cle, traducteur)
    }
}

// MARK: 7. Autorisations

/// Les autorisations de cette édition (renderPermissions, item_permission.xml) : chacune dit pourquoi, son état,
/// et « Accorder » quand elle manque.
struct ReglagesCarteAutorisations: View {
    let modele: ReglagesModele
    let aiguillage: ReglagesAiguillage
    let largeurValeur: CGFloat?
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ReglagesTitreCarte("section_permissions", indication: "section_permissions_hint")
            ForEach(modele.autorisations) { ligne in
                ligneAutorisation(ligne)
            }
        }
    }

    private func ligneAutorisation(_ ligne: ReglagesLigneAutorisation) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(ligne.titre, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                Text(ligne.pourquoi, traducteur: traducteur)
                    .indicationCarte()
                Text(ligne.etat, traducteur: traducteur)
                    .font(Font.footnote.bold())
                    .foregroundStyle(reglagesTeinte(ligne.couleurEtat))
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            // VoiceOver : le titre, l'état, puis la raison.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: [ligne.titre, ligne.etat, ligne.pourquoi]
                .map { traducteur.texte($0) }
                .joined(separator: ", ")))
            Button {
                accorder(ligne.autorisation)
            } label: {
                reglagesTexte("action_grant", traducteur)
                    .lineLimit(2)
                    .frame(minWidth: 44)
            }
            .buttonStyle(.secondaire)
            .disabled(!ligne.boutonActif)
            .accessibilityHint(Text(ligne.titre, traducteur: traducteur))
            .reglagesLargeurMax(largeurValeur)
            .layoutPriority(1)
        }
        .padding(.top, 12)
    }

    private func accorder(_ autorisation: ReglagesAutorisation) {
        let aiguillage = self.aiguillage
        Task.immediate { @MainActor [modele] in
            let route = await modele.accorder(autorisation)
            aiguillage.suivre(route)
        }
    }
}

// MARK: 8. Dédicace

struct ReglagesCarteDedicace: View {
    let modele: ReglagesModele
    let aiguillage: ReglagesAiguillage
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ReglagesTitreCarte("section_dedicace", indication: "section_dedicace_hint")
            Button {
                aiguillage.suivre(modele.routeDedicace)
            } label: {
                reglagesTexte("dedicace_bouton", traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 12)
        }
    }
}

// MARK: 10. Réinitialiser

/// « Réinitialiser l'application », en dernier : le texte du bouton est à la couleur « danger » d'Android.
struct ReglagesCarteReinitialiser: View {
    let modele: ReglagesModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ReglagesTitreCarte("reset_title", indication: "reset_hint")
            Button {
                modele.demanderReinitialisation()
            } label: {
                reglagesTexte("reset_action", traducteur)
                    .foregroundStyle(ReglagesTeinteFixe.danger)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 12)
        }
    }
}
