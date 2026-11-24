import Foundation
import SwiftUI
import Coeur
import Ecrans

// Les résultats du vol calculé (afficherResultats de VolActivity.kt) : la prière du moment, la frise des zmanim de
// la route, Chabbat, fêtes et Omer, les rappels, la position et sa fiabilité ; puis « Méthode et sources ». Tout se
// lit dans VolModele (`resultats`, `sources`) ; les actions sont les siennes.

/// La zone des résultats, sous le formulaire : rien, « Calcul en cours… », ou les cartes, dans l'ordre du modèle.
struct VolZoneResultats: View {
    let modele: VolModele

    init(modele: VolModele) {
        self.modele = modele
    }

    var body: some View {
        switch modele.resultats {
        case .aucun:
            EmptyView()
        case .enCours:
            VolCarteAttente()
        case .cartes(let cartes):
            VolCartePriereVue(carte: cartes.priere)
            VolCarteFriseVue(frise: cartes.frise)
            if let jalons = cartes.jalons {
                VolCarteJalonsVue(carte: jalons)
            }
            VolCarteRappelsVue(modele: modele, carte: cartes.rappels)
            VolCarteFiabiliteVue(modele: modele, carte: cartes.fiabilite)
        }
    }
}

/// « Calcul en cours… » (15, pâle) : à l'ouverture, tant que les aéroports se lisent, et pendant un calcul.
struct VolCarteAttente: View {
    @Environment(\.traducteur) private var traducteur

    init() {}

    var body: some View {
        Carte {
            Text(Libelle("vol_calcul_en_cours"), traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.muted))
        }
        .volPlace()
    }
}

// MARK: La prière du moment

/// La carte de la prière (cartePriere) : le ciel de l'heure en dégradé, tout le texte en blanc.
struct VolCartePriereVue: View {
    let carte: VolCartePriere
    @Environment(\.traducteur) private var traducteur

    init(carte: VolCartePriere) {
        self.carte = carte
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: capitales(Libelle("vol_priere_titre")))
                .font(.caption)
                .tracking(12 * 0.08)
                .foregroundStyle(Color.white.opacity(200.0 / 255))
                .accessibilityAddTraits(.isHeader)
            if let nom = carte.nom {
                Text(nom, traducteur: traducteur)
                    .font(Font.largeTitle.bold())
                    .foregroundStyle(Color.white)
                    .padding(.top, 4)
                suite
            } else if let message = carte.message {
                Text(message, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(240.0 / 255))
                    .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            VolFondPriere(ciel: carte.ciel)
        }
        .accessibilityElement(children: .combine)
        .volPlace()
    }

    /// Sous le nom : la prière sans limite, ou le compte à rebours, la limite et l'écart d'un retard.
    @ViewBuilder private var suite: some View {
        if let message = carte.message {
            Text(message, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(225.0 / 255))
                .padding(.top, 4)
        } else {
            if let compte = carte.compte {
                Text(compte, traducteur: traducteur)
                    .font(Font.title2.bold().monospacedDigit())
                    .foregroundStyle(Color.white)
                    .padding(.top, 8)
            }
            if let jusqua = carte.jusqua {
                Text(jusqua, traducteur: traducteur)
                    .font(Font.subheadline.monospacedDigit())
                    .foregroundStyle(Color.white.opacity(215.0 / 255))
                    .padding(.top, 4)
            }
            if let ecart = carte.ecart {
                Text(ecart, traducteur: traducteur)
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(170.0 / 255))
                    .padding(.top, 4)
            }
        }
    }

    /// textAllCaps d'Android, dans la langue de l'app.
    private func capitales(_ libelle: Libelle) -> String {
        traducteur.texte(libelle).uppercased(with: Locale(identifier: traducteur.langue))
    }
}

// MARK: La frise

/// La carte de la frise (frise de VolActivity) : du décollage à l'atterrissage, un point par zman, et
/// « maintenant » à sa place.
struct VolCarteFriseVue: View {
    let frise: VolFrise
    @Environment(\.traducteur) private var traducteur

    init(frise: VolFrise) {
        self.frise = frise
    }

    var body: some View {
        Carte {
            t("vol_en_vol_titre")
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .accessibilityAddTraits(.isHeader)
            if frise.vide {
                t("vol_aucun_zman")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 4)
            } else {
                if frise.noteRetard {
                    t("vol_frise_retard")
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 2)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(frise.points) { point in
                        VolLigneFriseVue(point: point)
                    }
                }
                .padding(.top, 12)
            }
        }
        .volPlace()
    }

    private func t(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }
}

/// Un point de la frise : à gauche (au début, en hébreu à droite) la colonne de 30 avec son rond et le trait vers le
/// point suivant ; puis le nom, les heures et le détail. Les icônes sont des ornements ; VoiceOver lit « nom,
/// heures, détail ».
struct VolLigneFriseVue: View {
    let point: VolPointFrise
    @Environment(\.traducteur) private var traducteur

    init(point: VolPointFrise) {
        self.point = point
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Color.clear
                .frame(width: 30, height: 30)
            corps
                .padding(.leading, 14)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            trait
        }
        .overlay(alignment: .topLeading) {
            repere
        }
        .accessibilityElement(children: .combine)
    }

    /// Le trait de 2 vers le point suivant, sous le rond ; caché au dernier point.
    @ViewBuilder private var trait: some View {
        if !point.dernier {
            Rectangle()
                .fill(Teinte(.line))
                .frame(width: 2)
                .padding(.top, 30)
                .frame(width: 30)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }

    /// Le rond : l'icône du ciel sur sa teinte pâlie ; pour « maintenant », un petit rond cerclé de l'accent.
    @ViewBuilder private var repere: some View {
        if point.ciel == .maintenant {
            Circle()
                .fill(Teinte(.card))
                .overlay {
                    Circle().strokeBorder(Teinte(.brand), lineWidth: 3)
                }
                .frame(width: 16, height: 16)
                .padding(.top, 7)
                .frame(width: 30)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(fondRond)
                .frame(width: 30, height: 30)
                .overlay {
                    if let icone = point.ciel.icone {
                        Image(systemName: VolIcones.frise(icone))
                            .font(.footnote)
                            .foregroundStyle(teinte)
                    }
                }
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var corps: some View {
        if point.ciel == .maintenant {
            Text(verbatim: traducteur.texte(point.nom).uppercased(with: Locale(identifier: traducteur.langue)))
                .font(Font.subheadline.bold())
                .tracking(14 * 0.06)
                .foregroundStyle(Teinte(.brand))
                .padding(.top, 4)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text(point.nom, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                if let ligneHeures = heures {
                    ligneHeures
                        .font(Font.callout.monospacedDigit())
                        .padding(.top, 2)
                }
                if let detail = point.detail {
                    Text(detail, traducteur: traducteur)
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 1)
                }
            }
            .multilineTextAlignment(.leading)
        }
    }

    /// L'heure du départ en gras, « · », l'heure de l'arrivée plus légère.
    private var heures: Text? {
        let depart = point.heureDepart.map { Text(verbatim: $0).bold().foregroundStyle(Teinte(.ink)) }
        let arrivee = point.heureArrivee.map { Text(verbatim: " · " + $0).foregroundStyle(Teinte(.muted)) }
        if let depart, let arrivee {
            return Text("\(depart)\(arrivee)")
        }
        return depart ?? arrivee
    }

    /// La teinte du ciel (écrite en dur par Android), ou l'accent.
    private var teinte: AnyShapeStyle {
        if let valeur = point.ciel.teinte {
            return AnyShapeStyle(Color(VolCouleurs.argb(valeur)))
        }
        return AnyShapeStyle(Teinte(.brand))
    }

    /// `card` mêlé à 14 % de la teinte.
    private var fondRond: VolMelange {
        if let valeur = point.ciel.teinte {
            return VolMelange(.card, .fixe(VolCouleurs.argb(valeur)), part: 0.14)
        }
        return VolMelange(.card, .jeton(.brand), part: 0.14)
    }
}

// MARK: Chabbat, fêtes et Omer

/// La carte des jalons (carteJalons) : une ligne par entrée ou sortie, l'allumage, la position, puis la note.
struct VolCarteJalonsVue: View {
    let carte: VolCarteJalons
    @Environment(\.traducteur) private var traducteur

    init(carte: VolCarteJalons) {
        self.carte = carte
    }

    var body: some View {
        Carte {
            Text(Libelle("vol_jalons_titre"), traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .accessibilityAddTraits(.isHeader)
            ForEach(carte.lignes) { ligne in
                VStack(alignment: .leading, spacing: 0) {
                    Text(ligne.texte, traducteur: traducteur)
                        .font(Font.subheadline.bold())
                        .foregroundStyle(Teinte(.ink))
                    if let allumage = ligne.allumage {
                        Text(allumage, traducteur: traducteur)
                            .font(.footnote)
                            .foregroundStyle(Teinte(.ink))
                            .padding(.top, 2)
                    }
                    Text(ligne.position, traducteur: traducteur)
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 1)
                }
                .multilineTextAlignment(.leading)
                .padding(.top, 10)
                .accessibilityElement(children: .combine)
            }
            Text(carte.note, traducteur: traducteur)
                .font(.caption)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 10)
        }
        .volPlace()
    }
}

// MARK: Les rappels

/// La carte des rappels (carteRappels) : l'interrupteur, puis chaque rappel à venir et la note.
struct VolCarteRappelsVue: View {
    let modele: VolModele
    let carte: VolCarteRappels
    @Environment(\.traducteur) private var traducteur

    init(modele: VolModele, carte: VolCarteRappels) {
        self.modele = modele
        self.carte = carte
    }

    var body: some View {
        Carte {
            t("vol_rappels_titre")
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .accessibilityAddTraits(.isHeader)
            Toggle(isOn: interrupteur) {
                t("vol_rappels_activer")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
            }
            .tint(Teinte(.brand))
            if carte.sansPermission {
                t("vol_rappels_sans_permission")
                    .font(.footnote)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 4)
            }
            if carte.aucun {
                t("vol_rappels_aucun")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 4)
            }
            ForEach(carte.lignes) { ligne in
                VStack(alignment: .leading, spacing: 0) {
                    Text(ligne.titre, traducteur: traducteur)
                        .font(Font.subheadline.bold())
                        .foregroundStyle(Teinte(.ink))
                    Text(verbatim: ligne.heure)
                        .font(Font.footnote.monospacedDigit())
                        .foregroundStyle(Teinte(.ink))
                        .padding(.top, 2)
                }
                .multilineTextAlignment(.leading)
                .padding(.top, 10)
                .accessibilityElement(children: .combine)
            }
            if let note = carte.note {
                Text(note, traducteur: traducteur)
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 10)
            }
        }
        .volPlace()
    }

    /// L'interrupteur lit la carte et écrit par le modèle (les réglages, l'autorisation, les notifications). Le
    /// réglage change dans le geste même (`Task.immediate`, comme MusiqueVue) : l'interrupteur ne revient pas un
    /// instant en arrière.
    private var interrupteur: Binding<Bool> {
        let modele = self.modele
        let actifs = carte.actifs
        return Binding.passerelle({ @MainActor in actifs },
                       { @MainActor nouveau in
                           Task.immediate { @MainActor in
                               await modele.basculerRappels(nouveau)
                           }
                       })
    }

    private func t(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }
}

// MARK: La position et sa fiabilité

/// La carte de la fiabilité (carteFiabilite) : la pastille de l'estimation ou le relevé, « Comment c'est
/// calculé ? », « Préciser la position » (le GPS, le retour à la route prévue, le suivi en direct), puis les
/// réserves et les passages de la ligne de changement de date.
struct VolCarteFiabiliteVue: View {
    @Bindable var modele: VolModele
    let carte: VolCarteFiabilite
    @Environment(\.traducteur) private var traducteur

    init(modele: VolModele, carte: VolCarteFiabilite) {
        self.modele = modele
        self.carte = carte
    }

    var body: some View {
        Carte {
            entete
            VolVoletVue(titre: t("vol_comment_calcule"), ouvert: modele.estOuvert(.commentCalcule),
                        basculer: { modele.basculerVolet(.commentCalcule) }) {
                t("vol_fiabilite")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.leading)
            }
            VolVoletVue(titre: t("vol_preciser_titre"), ouvert: modele.estOuvert(.preciser),
                        basculer: { modele.basculerVolet(.preciser) }) {
                preciser
            }
            ForEach(Array(carte.reserves.enumerated()), id: \.offset) { _, reserve in
                ligne(reserve)
            }
            ForEach(Array(carte.lignesDate.enumerated()), id: \.offset) { _, passage in
                ligne(passage)
            }
        }
        .volPlace()
    }

    /// « 📍 Estimation sur la route prévue » en pastille, ou le relevé qui a recalé la route.
    @ViewBuilder private var entete: some View {
        if carte.pastille {
            t("vol_fiabilite_court")
                .font(Font.subheadline.bold())
                .foregroundStyle(Teinte(.ink))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Teinte(.brand).opacity(0.1), in: Capsule())
        } else if let releve = carte.releve {
            Text(releve, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
        }
    }

    /// Le contenu de « Préciser la position ».
    private var preciser: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let gps = carte.gps {
                Button {
                    Task { await modele.releverGps() }
                } label: {
                    Text(gps, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .disabled(carte.gpsEnCours)
                .padding(.top, 4)
            }
            if carte.oublier {
                VolLien(texte: t("vol_gps_oublier")) {
                    Task { await modele.oublierReleve() }
                }
                .frame(maxWidth: .infinity)
            }
            if let direct = carte.direct {
                suivi(direct)
            }
        }
    }

    /// Le suivi en direct, avec un relais seulement : l'interrupteur des services en ligne, puis l'indicatif et le
    /// bouton de la position, ou ce qui partirait.
    private func suivi(_ direct: VolSuiviDirect) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: interrupteurDirect(direct.actif)) {
                t("vol_direct_activer")
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
            }
            .tint(Teinte(.brand))
            if direct.actif {
                TextField(text: $modele.indicatifSaisi, prompt: t("vol_indicatif")) {
                    t("vol_indicatif")
                }
                .font(.body)
                .foregroundStyle(Teinte(.ink))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .frame(minHeight: 44)
                Button {
                    Task { await modele.demanderDirect() }
                } label: {
                    Text(direct.bouton, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .disabled(direct.enCours)
                .padding(.top, 8)
                t("vol_source_opensky")
                    .font(.caption2)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 2)
            } else {
                t("vol_en_ligne_aide")
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 2)
            }
        }
        .multilineTextAlignment(.leading)
    }

    /// L'interrupteur des services en ligne : il lit la carte et écrit par le modèle, dans le geste même.
    private func interrupteurDirect(_ actif: Bool) -> Binding<Bool> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in actif },
                       { @MainActor nouveau in
                           Task.immediate { @MainActor in
                               await modele.basculerEnLigne(nouveau)
                           }
                       })
    }

    /// Une réserve ou un passage de la ligne de changement de date (14, encre, 8 au-dessus).
    private func ligne(_ libelle: Libelle) -> some View {
        Text(libelle, traducteur: traducteur)
            .font(.subheadline)
            .foregroundStyle(Teinte(.ink))
            .multilineTextAlignment(.leading)
            .padding(.top, 8)
    }

    private func t(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }
}

// MARK: Méthode et sources

/// « Méthode et sources », replié (sources de VolActivity) : la méthode, les aéroports, les routes.
struct VolSourcesVue: View {
    let modele: VolModele
    @Environment(\.traducteur) private var traducteur

    init(modele: VolModele) {
        self.modele = modele
    }

    var body: some View {
        VolVoletVue(titre: Text(Libelle("vol_sources"), traducteur: traducteur), ouvert: modele.estOuvert(.sources),
                    couleur: .muted, basculer: { modele.basculerVolet(.sources) }) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(modele.sources.enumerated()), id: \.offset) { rang, source in
                    Text(source, traducteur: traducteur)
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                        .multilineTextAlignment(.leading)
                        .padding(.top, VolSourcesVue.marge(rang))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Les marges d'Android entre les lignes : rien, 6, puis 4.
    private static func marge(_ rang: Int) -> CGFloat {
        switch rang {
        case 0: return 0
        case 1: return 6
        default: return 4
        }
    }
}
