import Accessibility
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Coeur
import Ecrans

/// Les zmanim en vol (VolActivity.kt, activity_vol.xml) : le bandeau, puis, dans la colonne qui défile, la saisie
/// rapide (une phrase ou le billet), le vol (son résumé, ou le formulaire : numéro, aéroports et heures du billet),
/// les résultats et « Méthode et sources ».
///
/// La vue ne décide rien : elle lit VolModele (cible Ecrans) et appelle ses actions. Elle le fait apparaître
/// (`apparaitre()`), puis le fait battre toutes les 30 secondes tant que l'app est au premier plan (onResume,
/// onPause d'Android) ; ses dialogues sont ceux du modèle (`dialogue`) : des alertes pour les messages et la
/// question des services en ligne, des feuilles pour les aéroports et les heures.
///
/// On l'ouvre de l'écran des zmanim (le bouton ✈) ; sa pile de navigation est celle de son onglet, et elle n'ouvre
/// aucun autre écran de l'app. Pas d'image ici hormis l'illustration du bandeau.
public struct VolVue: View {
    @Bindable private var modele: VolModele

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var scenePhase

    /// La place de l'écran, pour les mesures d'Android qui suivent la hauteur et la largeur (values-h640dp…).
    @State private var taille: CGSize = .zero
    /// Le sélecteur de fichier du billet (OpenDocument d'Android) est ouvert.
    @State private var billetOuvert = false
    @FocusState private var champActif: Champ?

    /// Les champs du clavier de cet écran.
    private enum Champ: Hashable {
        case phrase
        case numero
    }

    public init(modele: VolModele) {
        self.modele = modele
    }

    public var body: some View {
        ecran
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { nouvelle in
                taille = nouvelle
            }
            // Le titre nomme l'écran (le retour, VoiceOver) ; le bandeau le montre déjà : la barre ne le répète pas.
            .navigationTitle(Text(modele.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
            .task {
                await modele.apparaitre()
            }
            // Le compte à rebours ne bat qu'au premier plan : la tâche s'annule en quittant l'état actif (onPause) et
            // repart au retour (onResume), en battant aussitôt.
            .task(id: scenePhase == .active) { [actif = scenePhase == .active] in
                guard actif else { return }
                await battre()
            }
            .modifier(VolDialogues(modele: modele))
            .fileImporter(isPresented: $billetOuvert, allowedContentTypes: [.pdf, .image]) { resultat in
                guard case .success(let fichier) = resultat else { return }
                Task { await importer(fichier) }
            }
            // Les zones vivantes d'Android (accessibilityLiveRegion) : ce que la saisie rapide a compris, ce qu'a donné
            // la loupe.
            .onChange(of: modele.rapide) { _, lignes in
                guard let lignes else { return }
                annoncer(lignes)
            }
            .onChange(of: modele.aideRoute) { _, aide in
                guard let aide else { return }
                annoncer([aide])
            }
    }

    /// Le bandeau fixe, puis la colonne qui défile (la position est gardée quand les cartes se redessinent).
    private var ecran: some View {
        VStack(spacing: 0) {
            bandeau
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    contenu
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Teinte(.paper))
    }

    // MARK: Le cycle

    /// `battre()` tout de suite, puis toutes les 30 s, jusqu'à l'annulation de la tâche.
    private func battre() async {
        modele.battre()
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                // L'écran s'en va ou l'app passe en arrière-plan : la minuterie s'arrête.
                return
            }
            modele.battre()
        }
    }

    /// Le billet choisi, lu le temps que le modèle le lise (accès au fichier hors du bac à sable).
    private func importer(_ fichier: URL) async {
        let acces = fichier.startAccessingSecurityScopedResource()
        await modele.importerBillet(fichier)
        if acces {
            fichier.stopAccessingSecurityScopedResource()
        }
    }

    private func annoncer(_ lignes: [Libelle]) {
        let texte = lignes.map { traducteur.texte($0) }.joined(separator: "\n")
        AccessibilityNotification.Announcement(texte).post()
    }

    // MARK: Le bandeau (bg_hero)

    /// Le titre en blanc et la pastille du vol (ou l'invitation), l'illustration sur sa plaque menthe au bout.
    private var bandeau: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(modele.titre, traducteur: traducteur)
                    .font(ecranHaut ? Font.title2.bold() : Font.title3.bold())
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)
                Text(modele.bandeau, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(minHeight: 36)
                    .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Illustration(decorative: modele.image)
                .padding(4)
                .frame(width: ecranHaut ? 64 : 50, height: ecranHaut ? 78 : 60)
                .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, marge)
        .padding(.top, ecranHaut ? 22 : 12)
        .padding(.bottom, ecranHaut ? 18 : 10)
        .background {
            VolFondBandeau()
        }
    }

    /// values-h640dp : le bandeau s'agrandit sur un écran haut.
    private var ecranHaut: Bool {
        taille.height >= 640
    }

    /// @dimen/edge : 16, 24 dès 360 de large.
    private var marge: CGFloat {
        taille.width >= 360 ? 24 : 16
    }

    // MARK: Le contenu

    @ViewBuilder private var contenu: some View {
        if !modele.pret {
            VolCarteAttente()
        } else {
            if modele.formulaireOuvert {
                carteRapide
            }
            if let resume = modele.resume {
                carteResume(resume)
            } else {
                carteFormulaire
            }
            VolZoneResultats(modele: modele)
            VolSourcesVue(modele: modele)
        }
    }

    // MARK: La saisie rapide

    /// « Décrivez votre vol » : la phrase, « Remplir le vol », le billet, puis ce qui a été compris.
    private var carteRapide: some View {
        VStack(alignment: .leading, spacing: 0) {
            t("vol_rapide_titre")
                .font(Font.body.bold())
                .foregroundStyle(Teinte(.ink))
                .accessibilityAddTraits(.isHeader)
            t("vol_rapide_aide")
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 4)
            champPhrase
                .padding(.top, 12)
            Button {
                remplir()
            } label: {
                t("vol_rapide_remplir")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 12)
            if modele.billetDisponible {
                Button {
                    billetOuvert = true
                } label: {
                    Label {
                        t("vol_rapide_billet")
                    } icon: {
                        Image(systemName: VolIcones.billet)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .padding(.top, 8)
            }
            if let lignes = modele.rapide {
                Text(verbatim: lignes.map { traducteur.texte($0) }.joined(separator: "\n"))
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            VolFondRapide()
        }
        .volPlace()
    }

    /// La phrase, sur 2 à 6 lignes, majuscule en début de phrase.
    private var champPhrase: some View {
        TextField(text: $modele.phrase, prompt: t("vol_rapide_exemple"), axis: .vertical) {
            t("vol_rapide_titre")
        }
        .lineLimit(2...6)
        .font(.callout)
        .foregroundStyle(Teinte(.ink))
        .textInputAutocapitalization(.sentences)
        .focused($champActif, equals: .phrase)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .volCadreSaisie()
    }

    /// « Remplir le vol » : le clavier se ferme, puis la phrase est lue.
    private func remplir() {
        champActif = nil
        Task { await modele.remplir() }
    }

    // MARK: Le résumé

    /// Le vol calculé replié : « LY81 · TLV → BKK », « Modifier », les heures du billet.
    private func carteResume(_ resume: VolResume) -> some View {
        Carte {
            HStack(alignment: .center, spacing: 8) {
                Text(resume.titre, traducteur: traducteur)
                    .font(Font.body.bold())
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                VolLien(texte: t("vol_modifier")) {
                    modele.modifierVol()
                }
            }
            Text(verbatim: "\u{2068}\(resume.depart)\u{2069} \(modele.fleche) \u{2068}\(resume.arrivee)\u{2069}")
                .font(Font.subheadline.monospacedDigit())
                .foregroundStyle(Teinte(.muted))
                .multilineTextAlignment(.leading)
                .padding(.top, 2)
        }
        .volPlace()
    }

    // MARK: Le formulaire

    /// Le numéro (et sa loupe), les tuiles, « Calculer », « Effacer le vol ».
    private var carteFormulaire: some View {
        Carte {
            champNumero
            if let aide = modele.aideRoute {
                Text(aide, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)
            }
            ForEach(Array(modele.tuiles.enumerated()), id: \.element.id) { rang, tuile in
                tuileVue(tuile)
                    .padding(.top, rang == 0 ? 12 : 8)
                if tuile.genre == .atterrissage && modele.noteArriveeEstimee {
                    t("vol_rapide_estimee_court")
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.top, 4)
                }
            }
            Button {
                Task { await modele.calculer() }
            } label: {
                t("vol_calculer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 16)
            if modele.peutEffacer {
                VolLien(texte: t("vol_effacer"), couleur: .muted) {
                    Task { await modele.effacer() }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
        .volPlace()
    }

    /// Le numéro de vol : une ligne, en capitales, sans correction ; la touche « Rechercher » fait la loupe.
    private var champNumero: some View {
        TextField(text: $modele.numeroSaisi, prompt: t("vol_numero")) {
            t("vol_numero")
        }
        .font(.body)
        .foregroundStyle(Teinte(.ink))
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
        .submitLabel(modele.enLigneDisponible ? .search : .done)
        .onSubmit {
            Task { await modele.loupe() }
        }
        .focused($champActif, equals: .numero)
        .padding(.leading, 16)
        .padding(.trailing, modele.enLigneDisponible ? 56 : 16)
        .padding(.vertical, 14)
        .volCadreSaisie()
        .overlay(alignment: .trailing) {
            if modele.enLigneDisponible {
                loupe
            }
        }
    }

    /// La loupe au bout du champ : la route du numéro, en ligne. Pâlie pendant la recherche.
    private var loupe: some View {
        Button {
            Task { await modele.loupe() }
        } label: {
            Image(systemName: VolIcones.loupe)
                .font(.title3)
                .foregroundStyle(Teinte(.brand))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!modele.loupeActive)
        .opacity(modele.loupeActive ? 1 : 0.4)
        .padding(.trailing, 4)
        .accessibilityLabel(t("vol_route_bouton"))
    }

    /// Une tuile : l'étiquette en petit, la valeur en gras (ou l'invite, plus pâle), le chevron. VoiceOver la lit
    /// d'un trait, « étiquette, valeur ».
    private func tuileVue(_ tuile: VolTuile) -> some View {
        let etiquette = traducteur.texte(tuile.etiquette)
        let invite = traducteur.texte(tuile.invite)
        return Button {
            modele.toucher(tuile.genre)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: etiquette)
                        .font(.caption)
                        .foregroundStyle(Teinte(.muted))
                    if let valeur = tuile.valeur {
                        Text(verbatim: valeur)
                            .font(Font.callout.bold().monospacedDigit())
                            .foregroundStyle(Teinte(.ink))
                    } else {
                        Text(verbatim: invite)
                            .font(.callout)
                            .foregroundStyle(Teinte(.muted))
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(Font.footnote.weight(.semibold))
                    .foregroundStyle(Teinte(.muted))
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 60)
            .volCadreSaisie()
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: etiquette + ", " + (tuile.valeur ?? invite)))
    }

    /// Une chaîne simple du catalogue, dans la langue de l'app.
    private func t(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }
}

// MARK: Les dialogues

/// Les dialogues du modèle (`dialogue`) : une alerte « OK » pour un message, l'alerte des services en ligne, la
/// feuille d'un aéroport ou d'une heure. Les boutons disent tous au modèle quoi faire ; une feuille glissée vers le
/// bas, ou l'alerte d'un message fermée, le referme (`fermerDialogue()`).
struct VolDialogues: ViewModifier {
    let modele: VolModele
    @Environment(\.traducteur) private var traducteur

    init(modele: VolModele) {
        self.modele = modele
    }

    func body(content: Content) -> some View {
        content
            .alert(titreMessage, isPresented: messageOuvert) {
                // Aucune action : le système met « OK », qui ferme l'alerte et le dialogue.
            }
            .alert(t("vol_en_ligne_titre"), isPresented: enLigneOuvert) {
                Button {
                    Task { await modele.confirmerEnLigne() }
                } label: {
                    t("vol_en_ligne_oui")
                }
                Button(role: .cancel) {
                    modele.fermerDialogue()
                }
            } message: {
                t("vol_en_ligne_aide")
            }
            .sheet(item: feuille) { ouverte in
                switch ouverte {
                case .aeroport:
                    VolFeuilleAeroport(modele: modele)
                case .heure(_, let initiale):
                    VolFeuilleHeure(modele: modele, initiale: initiale)
                }
            }
    }

    /// Le message, en titre de l'alerte (setMessage d'Android, sans titre).
    private var titreMessage: Text {
        guard case .message(let libelle)? = modele.dialogue else { return Text(verbatim: "") }
        return Text(libelle, traducteur: traducteur)
    }

    /// L'alerte d'un message est ouverte ; fermée par son « OK », elle ferme le dialogue.
    private var messageOuvert: Binding<Bool> {
        let modele = self.modele
        return Binding(get: { @MainActor in
                           if case .message(_)? = modele.dialogue { return true }
                           return false
                       },
                       set: { @MainActor ouverte in
                           guard !ouverte, case .message(_)? = modele.dialogue else { return }
                           modele.fermerDialogue()
                       })
    }

    /// L'alerte des services en ligne est ouverte. Ses deux boutons disent au modèle quoi faire : la fermeture que
    /// signale SwiftUI ensuite n'ajoute rien (« Activer et chercher » trouverait sinon le dialogue déjà fermé).
    private var enLigneOuvert: Binding<Bool> {
        let modele = self.modele
        return Binding(get: { @MainActor in modele.dialogue == .enLigne },
                       set: { @MainActor _ in })
    }

    /// La feuille ouverte. Glissée vers le bas, elle ferme le dialogue s'il est encore le sien.
    private var feuille: Binding<VolFeuilleOuverte?> {
        let modele = self.modele
        return Binding(get: { @MainActor in VolFeuilleOuverte.de(modele.dialogue) },
                       set: { @MainActor nouvelle in
                           guard nouvelle == nil, VolFeuilleOuverte.de(modele.dialogue) != nil else { return }
                           modele.fermerDialogue()
                       })
    }

    private func t(_ cle: String) -> Text {
        Text(Libelle(cle), traducteur: traducteur)
    }
}
