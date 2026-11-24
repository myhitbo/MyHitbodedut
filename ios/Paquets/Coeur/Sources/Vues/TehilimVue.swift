import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le livre de Tehilim (TehilimActivity.kt, activity_tehilim.xml) : le bandeau, la ligne des marque-pages, les deux
/// portions du jour (le mois hébraïque, la semaine), puis la grille des 150 psaumes. Tout se lit dans `TehilimModele`.
///
/// La lecture est une sous-page de cet écran : la vue la pousse elle-même dans la pile de son onglet
/// (`navigationDestination(for: TehilimRoute.self)`), avec le modèle que rend `lecture` pour la cible demandée.
public struct TehilimVue: View {
    let modele: TehilimModele
    private let lecture: @MainActor (TehilimLectureCible) -> TehilimLectureModele

    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase
    /// Le marque-page choisi dans la feuille, ouvert une fois la feuille fermée.
    @State private var signetChoisi: TehilimRoute? = nil
    @State private var signetOuvert: TehilimRoute? = nil

    /// - Parameters:
    ///   - modele: le modèle du livre.
    ///   - lecture: le modèle de la lecture d'une cible (`TehilimLectureModele(magasin:contenus:langue:cible:)`).
    public init(modele: TehilimModele,
                lecture: @escaping @MainActor (TehilimLectureCible) -> TehilimLectureModele) {
        self.modele = modele
        self.lecture = lecture
    }

    public var body: some View {
        VStack(spacing: 0) {
            TehilimBandeau(titre: Text(modele.titre, traducteur: traducteur),
                           sousTitre: modele.sousTitre.map { Text($0, traducteur: traducteur) },
                           image: modele.image)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ligneSignets
                    portions
                    entete
                    grille
                }
                .padding(.bottom, 24)
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TehilimRoute.self) { route in
            TehilimLecturePage(cible: route.cible, fabrique: lecture)
        }
        .navigationDestination(item: $signetOuvert) { route in
            TehilimLecturePage(cible: route.cible, fabrique: lecture)
        }
        .sheet(isPresented: feuilleOuverte, onDismiss: { ouvrirSignetChoisi() }) {
            TehilimFeuilleSignets(modele: modele) { route in
                signetChoisi = route
            }
        }
        .task { await modele.charger() }
        .onAppear { modele.actualiser() }
        .onChange(of: phase) { _, nouvelle in
            // onResume d'Android : le jour a pu changer pendant que l'app était en arrière-plan.
            if nouvelle == .active { modele.actualiser() }
        }
    }

    /// La feuille suit le modèle ; la fermer d'un geste passe par `fermerSignets()`.
    private var feuilleOuverte: Binding<Bool> {
        let modele = self.modele
        return Binding.passerelle({ @MainActor in modele.feuilleSignetsOuverte },
                       { @MainActor _ in modele.fermerSignets() })
    }

    private func ouvrirSignetChoisi() {
        signetOuvert = signetChoisi
        signetChoisi = nil
    }

    // MARK: La ligne des marque-pages

    @ViewBuilder
    private var ligneSignets: some View {
        if let ligne = modele.ligneSignets {
            Button {
                modele.ouvrirSignets()
            } label: {
                HStack(spacing: 8) {
                    // textDirection RTL, mais textAlignment VIEW_START et l'icône en fin de vue : seul le sens du
                    // texte est de droite à gauche ; l'alignement et l'icône suivent le sens de l'app.
                    Text(verbatim: traducteur.texte(ligne.titre) + " · " + String(ligne.nombre) + "  ›")
                        .policeHebraique(.serif, taille: 19)
                        .foregroundStyle(Teinte(.ink))
                        .multilineTextAlignment(.leading)
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    // ic_marque_priere : un ruban en contour.
                    Image(systemName: "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: traducteur.texte(ligne.titre) + ", " + String(ligne.nombre)))
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    // MARK: Les portions du jour

    private var portions: some View {
        Carte {
            NavigationLink(value: modele.routeMois) {
                LigneSection(titre: Text(Libelle("tehilim_month"), traducteur: traducteur),
                             etat: Text(modele.etatMois, traducteur: traducteur))
            }
            .buttonStyle(.plain)
            NavigationLink(value: modele.routeSemaine) {
                LigneSection(titre: Text(Libelle("tehilim_week"), traducteur: traducteur),
                             etat: Text(modele.etatSemaine, traducteur: traducteur))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: La grille

    private var entete: some View {
        Text(Libelle("tehilim_all"), traducteur: traducteur)
            .font(.caption)
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(Teinte(.muted))
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .accessibilityAddTraits(.isHeader)
    }

    private var grille: some View {
        VStack(spacing: 0) {
            ForEach(modele.grille) { rangee in
                HStack(spacing: 0) {
                    ForEach(rangee.cases) { c in
                        caseVue(c)
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 12)
    }

    private func caseVue(_ c: TehilimCase) -> some View {
        NavigationLink(value: c.route) {
            Text(verbatim: c.numero)
                .font(Font.callout.monospacedDigit())
                .foregroundStyle(Teinte(.ink))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Teinte(.dayTodo), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(4)
        .accessibilityLabel(Text(c.description, traducteur: traducteur))
    }
}

/// La lecture des Tehilim poussée dans la pile : elle garde son modèle d'une mise à jour de la page à l'autre (la
/// destination de navigation est recalculée, le modèle ne doit pas l'être). Le câblage de l'app s'en sert aussi pour
/// un marque-page des Tehilim vu ailleurs (`LectureRoute.tehilimMarque` → `TehilimLectureCible.marque`).
public struct TehilimLecturePage: View {
    private let cible: TehilimLectureCible
    private let fabrique: @MainActor (TehilimLectureCible) -> TehilimLectureModele
    @State private var modele: TehilimLectureModele? = nil

    public init(cible: TehilimLectureCible,
                fabrique: @escaping @MainActor (TehilimLectureCible) -> TehilimLectureModele) {
        self.cible = cible
        self.fabrique = fabrique
    }

    public var body: some View {
        Group {
            if let modele {
                TehilimLectureVue(modele: modele)
            } else {
                Rectangle().fill(Teinte(.paper))
            }
        }
        .onAppear {
            if modele == nil {
                modele = fabrique(cible)
            }
        }
    }
}

/// La feuille des marque-pages des Tehilim (RepriseFavoris.listeSignets) : les puces « Tout » et « Tehilim », puis
/// les marque-pages ; en toucher un ferme la feuille et ouvre son psaume, à son verset.
struct TehilimFeuilleSignets: View {
    let modele: TehilimModele
    let choisir: @MainActor (TehilimRoute) -> Void
    @Environment(\.traducteur) private var traducteur

    init(modele: TehilimModele, choisir: @escaping @MainActor (TehilimRoute) -> Void) {
        self.modele = modele
        self.choisir = choisir
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    puces
                    ForEach(modele.lignesSignets) { ligne in
                        ligneVue(ligne)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(Teinte(.card))
            .navigationTitle(Text(modele.titreFeuilleSignets, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Le bouton OK du dialogue d'Android.
                    Button(role: .confirm) {
                        modele.fermerSignets()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var puces: some View {
        HStack(spacing: 8) {
            ForEach(modele.filtresSignets) { filtre in
                puce(filtre)
            }
        }
        .padding(.bottom, 4)
    }

    /// Une puce à sélection unique : la cochée porte une coche et le fond menthe.
    private func puce(_ filtre: TehilimFiltreSignets) -> some View {
        let choisie = filtre.id == modele.filtreSignets
        return Button {
            modele.choisirFiltreSignets(filtre.id)
        } label: {
            HStack(spacing: 4) {
                if choisie {
                    Image(systemName: "checkmark")
                        .font(Font.caption.weight(.semibold))
                }
                Text(filtre.libelle, traducteur: traducteur)
                    .font(.footnote)
            }
            .foregroundStyle(Teinte(choisie ? .onPlate : .ink))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(Teinte(choisie ? .mint : .card), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(choisie ? .isSelected : [])
    }

    private func ligneVue(_ ligne: TehilimSignetLigne) -> some View {
        Button {
            choisir(modele.choisirSignet(ligne))
        } label: {
            // Comme la ligne des marque-pages : le sens du texte est de droite à gauche, l'alignement (VIEW_START) et
            // l'icône (en fin de vue) suivent le sens de l'app.
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    // PoliceHebraique.appliquer d'Android : la police de lecture, comme l'aperçu dessous.
                    Text(ligne.titre, traducteur: traducteur)
                        .policeHebraique(.serif, taille: 13, relativeA: .footnote)
                        .foregroundStyle(Teinte(.muted))
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "bookmark")
                        .font(.system(size: 14))
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
                Text(verbatim: ligne.apercu)
                    .policeHebraique(.serif, taille: 17)
                    .foregroundStyle(Teinte(.ink))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
