import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Les zmanim en vol (VolActivity.kt, activity_vol.xml, tâche 26) : le bandeau, la saisie (une phrase, ou les tuiles :
/// aéroports et heures du billet à l'heure de chaque aéroport), puis la prière du moment et son compte à rebours, la
/// frise des zmanim de la route, Chabbat, fêtes et Omer, les rappels, la position et ses réserves, les sources. Le
/// calcul est celui de Coeur, hors ligne ; rien ne sort du téléphone sans relais. La vue lit `VolModele` (testé sous
/// Linux) et appelle ses actions ; elle bat toutes les 30 secondes (`battre`).
public struct VolVue: View {
    private let modele: VolModele
    @Environment(\.traducteur) private var traducteur

    public init(modele: VolModele) {
        self.modele = modele
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                bandeau
                if let resume = modele.resume {
                    resumeVue(resume)
                } else {
                    formulaire
                }
                resultats
                volet(.sources, titre: Libelle("vol_sources")) {
                    ForEach(Array(modele.sources.enumerated()), id: \.offset) { _, source in
                        Text(source, traducteur: traducteur)
                            .font(.caption)
                            .foregroundStyle(Teinte(.muted))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await modele.apparaitre()
            while !Task.isCancelled {
                guard await AccueilAttente.ms(30_000) else { break }
                modele.battre()
            }
        }
        .sheet(item: Bindable(modele).dialogueLie) { dialogue in
            VolBoite(modele: modele, dialogue: dialogue.dialogue)
                .hauteursDeFeuille([.medium, .large])
        }
    }

    private var bandeau: some View {
        HStack(spacing: 14) {
            Illustration(decorative: modele.image, hauteur: 64)
                .frame(width: 72, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(modele.titre, traducteur: traducteur)
                    .font(Font.title3.bold())
                    .foregroundStyle(Teinte(.onBrand))
                Text(modele.bandeau, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.onBrand))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Teinte(.brand), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Le vol replié : « LY81 · TLV → BKK », le départ et l'arrivée à l'heure de chaque aéroport, « Modifier ».
    private func resumeVue(_ resume: VolResume) -> some View {
        Carte {
            Text(resume.titre, traducteur: traducteur)
                .titreCarte()
            HStack(spacing: 8) {
                Text(verbatim: resume.depart)
                Text(verbatim: modele.fleche)
                    .foregroundStyle(Teinte(.brand))
                Text(verbatim: resume.arrivee)
            }
            .font(.subheadline)
            .foregroundStyle(Teinte(.ink))
            .padding(.top, 4)
            HStack(spacing: 8) {
                Button {
                    modele.modifierVol()
                } label: {
                    Text(Libelle("vol_modifier"), traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                Button(role: .destructive) {
                    Task { await modele.effacer() }
                } label: {
                    Text(Libelle("vol_effacer"), traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
            .padding(.top, 10)
        }
    }

    /// La saisie : la phrase (« El Al Lyon TLV demain 11h ») et « Remplir le vol », le numéro, les tuiles, « Calculer ».
    private var formulaire: some View {
        Carte {
            Text(Libelle("vol_rapide_titre"), traducteur: traducteur)
                .titreCarte()
            TextField(text: Bindable(modele).phrase, axis: .vertical) {
                Text(Libelle("vol_rapide_exemple"), traducteur: traducteur)
            }
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .padding(.top, 6)
            Button {
                Task { await modele.remplir() }
            } label: {
                Text(Libelle("vol_rapide_remplir"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            .padding(.top, 6)
            // Le billet : l'appareil photo, une photo ou un fichier (VolBilletVue.swift).
            if modele.billetDisponible {
                VolBilletBouton(modele: modele)
                    .padding(.top, 2)
            }
            if let rapide = modele.rapide {
                ForEach(Array(rapide.enumerated()), id: \.offset) { _, ligne in
                    Text(ligne, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            TextField(text: Bindable(modele).numeroSaisi, axis: .vertical) {
                Text(Libelle("vol_numero"), traducteur: traducteur)
            }
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .padding(.top, 12)
            if let aide = modele.aideRoute {
                Text(aide, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            ForEach(modele.tuiles) { tuile in
                Button {
                    modele.toucher(tuile.genre)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tuile.etiquette, traducteur: traducteur)
                                .font(.caption)
                                .foregroundStyle(Teinte(.muted))
                            if let valeur = tuile.valeur {
                                Text(verbatim: valeur)
                                    .font(.subheadline)
                                    .foregroundStyle(Teinte(.ink))
                            } else {
                                Text(tuile.invite, traducteur: traducteur)
                                    .font(.subheadline)
                                    .foregroundStyle(Teinte(.muted))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Teinte(.brand))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if modele.noteArriveeEstimee {
                Text(Libelle("vol_rapide_estimee_court"), traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.brand))
            }
            Button {
                Task { await modele.calculer() }
            } label: {
                Text(Libelle("vol_calculer"), traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 10)
            if modele.peutEffacer {
                Button {
                    Task { await modele.effacer() }
                } label: {
                    Text(Libelle("vol_effacer"), traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var resultats: some View {
        switch modele.resultats {
        case .aucun:
            EmptyView()
        case .enCours:
            Carte {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(Libelle("vol_calcul_en_cours"), traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.ink))
                }
            }
        case .cartes(let cartes):
            VolPriereVue(carte: cartes.priere)
            VolFriseVue(frise: cartes.frise)
            if let jalons = cartes.jalons {
                VolJalonsVue(jalons: jalons)
            }
            rappels(cartes.rappels)
            fiabilite(cartes.fiabilite)
        }
    }

    private func rappels(_ carte: VolCarteRappels) -> some View {
        Carte {
            Toggle(isOn: Bindable(modele).rappelsLies) {
                Text(Libelle("vol_rappels_activer"), traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
            }
            .tint(Teinte(.brand))
            if carte.sansPermission {
                Text(Libelle("vol_rappels_sans_permission"), traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(ReglagesTeinte.nommee("warning"))
            }
            if carte.aucun {
                Text(Libelle("vol_rappels_aucun"), traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            ForEach(carte.lignes) { ligne in
                HStack {
                    Text(ligne.titre, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.ink))
                    Spacer(minLength: 8)
                    Text(verbatim: ligne.heure)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Teinte(.muted))
                }
                .padding(.top, 4)
            }
            if let note = carte.note {
                Text(note, traducteur: traducteur)
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 6)
            }
        }
    }

    private func fiabilite(_ carte: VolCarteFiabilite) -> some View {
        Carte {
            if carte.pastille {
                Text(Libelle("vol_fiabilite_court"), traducteur: traducteur)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
            }
            if let releve = carte.releve {
                Text(releve, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.ink))
            }
            if let gps = carte.gps {
                Button {
                    Task { await modele.releverGps() }
                } label: {
                    Text(gps, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .disabled(carte.gpsEnCours)
                .padding(.top, 6)
            }
            if carte.oublier {
                Button {
                    Task { await modele.oublierReleve() }
                } label: {
                    Text(Libelle("vol_gps_oublier"), traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.brand))
                        .frame(minHeight: 44)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
            ForEach(Array((carte.reserves + carte.lignesDate).enumerated()), id: \.offset) { _, ligne in
                Text(ligne, traducteur: traducteur)
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 4)
            }
        }
    }

    /// Un volet replié (« Titre ⌄ ») : ouvert, il le reste quand l'écran se redessine.
    private func volet<Contenu: View>(_ quel: VolVolet, titre: Libelle,
                                      @ViewBuilder contenu: () -> Contenu) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                modele.basculerVolet(quel)
            } label: {
                HStack {
                    Text(titre, traducteur: traducteur)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Teinte(.muted))
                    Image(systemName: modele.estOuvert(quel) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                }
                // 44 de haut, toute la largeur : la zone de toucher que demande l'audit d'accessibilité.
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
            if modele.estOuvert(quel) {
                contenu()
            }
        }
    }
}

// MARK: - Les liaisons

/// Un dialogue du vol, identifié pour `sheet(item:)`.
struct VolDialogueIdentifie: Identifiable, Hashable {
    let dialogue: VolDialogue
    var id: Int { dialogue.hashValue }
}

extension VolModele {
    var dialogueLie: VolDialogueIdentifie? {
        get { dialogue.map { VolDialogueIdentifie(dialogue: $0) } }
        set { if newValue == nil { fermerDialogue() } }
    }

    /// L'interrupteur « Me rappeler pendant le vol ».
    var rappelsLies: Bool {
        get {
            if case .cartes(let cartes) = resultats { return cartes.rappels.actifs }
            return false
        }
        set {
            let actifs = newValue
            Task { await self.basculerRappels(actifs) }
        }
    }

    /// La recherche d'un aéroport, frappe après frappe.
    var rechercheSaisie: String {
        get { recherche }
        set { chercherAeroport(newValue) }
    }
}

// MARK: - Les cartes

/// La prière du moment (VolPriere) : son nom, le temps qui reste, jusqu'à quand, l'écart ; ou pourquoi aucune.
private struct VolPriereVue: View {
    let carte: VolCartePriere
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            if let nom = carte.nom {
                Text(nom, traducteur: traducteur)
                    .font(Font.title3.bold())
                    .foregroundStyle(Teinte(.brand))
            }
            if let message = carte.message {
                Text(message, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
            }
            if let compte = carte.compte {
                Text(compte, traducteur: traducteur)
                    .font(Font.body.weight(.semibold))
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 4)
            }
            if let jusqua = carte.jusqua {
                Text(jusqua, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            if let ecart = carte.ecart {
                Text(ecart, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
        }
    }
}

/// La frise des zmanim de la route : chaque point, son ciel, son nom, l'heure au départ et à l'arrivée.
private struct VolFriseVue: View {
    let frise: VolFrise
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            if frise.vide {
                Text(Libelle("vol_aucun_zman"), traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
            }
            if frise.noteRetard {
                Text(Libelle("vol_frise_retard"), traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            ForEach(frise.points) { point in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(point.ciel == .maintenant ? Teinte(.brand) : Teinte(.line))
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.nom, traducteur: traducteur)
                            .font(point.ciel == .maintenant ? Font.subheadline.bold() : Font.subheadline)
                            .foregroundStyle(Teinte(.ink))
                        if let detail = point.detail {
                            Text(detail, traducteur: traducteur)
                                .font(.caption)
                                .foregroundStyle(Teinte(.muted))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        if let depart = point.heureDepart {
                            Text(verbatim: depart)
                        }
                        if let arrivee = point.heureArrivee {
                            Text(verbatim: arrivee)
                                .foregroundStyle(Teinte(.muted))
                        }
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Teinte(.ink))
                }
                .padding(.top, 6)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Chabbat, fêtes et Omer en vol (VolCalendrier) : chaque jalon, l'allumage, la position, le repli polaire.
private struct VolJalonsVue: View {
    let jalons: VolCarteJalons
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        Carte {
            ForEach([jalons.ligneDateDiscutee, jalons.omerLigneDate].compactMap { $0 }, id: \.self) { note in
                Text(note, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.brand))
            }
            ForEach(jalons.lignes) { ligne in
                VStack(alignment: .leading, spacing: 2) {
                    Text(ligne.texte, traducteur: traducteur)
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundStyle(Teinte(.ink))
                    if let allumage = ligne.allumage {
                        Text(allumage, traducteur: traducteur)
                            .font(.footnote)
                            .foregroundStyle(Teinte(.brand))
                    }
                    Text(ligne.position, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                    if let repli = ligne.repli {
                        Text(repli, traducteur: traducteur)
                            .font(.footnote)
                            .foregroundStyle(Teinte(.muted))
                    }
                }
                .padding(.top, 6)
            }
            Text(jalons.note, traducteur: traducteur)
                .font(.caption)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 6)
        }
    }
}

// MARK: - Les dialogues

/// La boîte ouverte : un message, la recherche d'un aéroport, ou le choix d'une date et d'une heure locales.
private struct VolBoite: View {
    let modele: VolModele
    let dialogue: VolDialogue
    @Environment(\.traducteur) private var traducteur
    @State private var date = Date(timeIntervalSince1970: 0)

    var body: some View {
        switch dialogue {
        case .message(let message):
            VStack(spacing: 16) {
                Text(message, traducteur: traducteur)
                    .font(.body)
                    .foregroundStyle(Teinte(.ink))
                ok { modele.fermerDialogue() }
            }
            .padding(24)
        case .enLigne:
            VStack(spacing: 16) {
                Text(Libelle("vol_en_ligne_titre"), traducteur: traducteur)
                    .font(.title3.bold())
                Text(Libelle("vol_en_ligne_aide"), traducteur: traducteur)
                    .font(.body)
                ok { Task { await modele.confirmerEnLigne() } }
            }
            .foregroundStyle(Teinte(.ink))
            .padding(24)
        case .aeroport:
            NavigationStack {
                List {
                    ForEach(modele.lignesAeroports) { ligne in
                        Button {
                            modele.choisirAeroport(ligne.aeroport)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: ligne.iata + " · " + ligne.titre)
                                    .foregroundStyle(Teinte(.ink))
                                Text(verbatim: ligne.detail)
                                    .font(.caption)
                                    .foregroundStyle(Teinte(.muted))
                            }
                        }
                    }
                }
                .searchable(text: Bindable(modele).rechercheSaisie, placement: .navigationBarDrawer(displayMode: .always))
                .onSubmit(of: .search) { modele.validerRecherche() }
                .navigationTitle(Text(Libelle("vol_choisir_aeroport"), traducteur: traducteur))
                .navigationBarTitleDisplayMode(.inline)
            }
        case .heure(_, let initiale):
            VStack(spacing: 16) {
                DatePicker(selection: $date) {
                    Text(Libelle("vol_choisir_heure"), traducteur: traducteur)
                }
                .datePickerStyle(.graphical)
                .environment(\.timeZone, .gmt)
                .onAppear { date = VolBoite.date(initiale) }
                ok {
                    guard let choisie = VolBoite.civile(date) else { return }
                    Task { await modele.choisirHeure(choisie) }
                }
            }
            .padding(24)
        }
    }

    private func ok(_ action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Text(Libelle("action_ok"), traducteur: traducteur)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.principal)
    }

    /// L'heure locale de l'aéroport, posée sur un calendrier sans fuseau : le sélecteur montre ce qui est écrit.
    private static func date(_ civile: DateHeure) -> Date {
        let jours = civile.jour.jourJulien - 2_440_588
        return Date(timeIntervalSince1970: Double(jours) * 86_400 + Double(civile.millisDuJour) / 1000)
    }

    private static func civile(_ date: Date) -> DateHeure? {
        let secondes = Int64(date.timeIntervalSince1970.rounded(.down))
        let jours = Int(secondes >= 0 ? secondes / 86_400 : (secondes - 86_399) / 86_400)
        let reste = Int(secondes - Int64(jours) * 86_400)
        guard let epoque = JourCivil(annee: 1970, mois: 1, jour: 1) else { return nil }
        return DateHeure(epoque.plus(jours: jours), heure: reste / 3600, minute: (reste % 3600) / 60)
    }
}
