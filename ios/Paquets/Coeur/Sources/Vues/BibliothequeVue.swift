import Foundation
import SwiftUI
import Coeur
import Ecrans

/// La bibliothèque (LibraryActivity.kt, activity_library.xml) : le bandeau, la ligne des marque-pages (les livres
/// seulement), puis les titres de section et leurs cartes. Tout se lit dans `BibliothequeModele`.
///
/// Les sous-pages de la bibliothèque (une sous-section, une entrée) sont poussées par cette vue dans la pile de son
/// onglet (`navigationDestination(for: BibliothequeRoute.self)`), avec les modèles que rendent `sousSection` et
/// `entree`. Un livre et un marque-page s'ouvrent dans le lecteur du siddour, un autre écran : `ouvrir` les reçoit.
public struct BibliothequeVue: View {
    let modele: BibliothequeModele
    private let sousSection: @MainActor (String) -> BibliothequeSousSectionModele
    private let entree: @MainActor (String) -> BibliothequeEntreeModele
    private let ouvrir: @MainActor (BibliothequeRoute) -> Void

    @Environment(\.traducteur) private var traducteur
    /// Le marque-page choisi dans la feuille, ouvert une fois la feuille fermée.
    @State private var signetChoisi: BibliothequeRoute? = nil

    /// - Parameters:
    ///   - modele: la liste (`BibliothequeModele(magasin:contenus:langue:livresSeuls:)`).
    ///   - sousSection: le modèle d'une sous-section (`BibliothequeSousSectionModele(magasin:contenus:langue:id:)`).
    ///   - entree: le modèle d'une entrée (`BibliothequeEntreeModele(magasin:contenus:langue:id:)`).
    ///   - ouvrir: le lecteur du siddour, pour `.livre` et `.marque` (SiddurLectureActivity.ouvrirLivre, ouvrirMarque).
    public init(modele: BibliothequeModele,
                sousSection: @escaping @MainActor (String) -> BibliothequeSousSectionModele,
                entree: @escaping @MainActor (String) -> BibliothequeEntreeModele,
                ouvrir: @escaping @MainActor (BibliothequeRoute) -> Void) {
        self.modele = modele
        self.sousSection = sousSection
        self.entree = entree
        self.ouvrir = ouvrir
    }

    public var body: some View {
        // Le bandeau défile avec la liste : fixe au-dessus d'elle, il en prenait toute la place aux grandes tailles du
        // texte, et son titre se coupait.
        ScrollView {
            VStack(spacing: 0) {
                BibliothequeBandeau(titre: Text(modele.titre, traducteur: traducteur),
                                    sousTitre: Text(modele.sousTitre, traducteur: traducteur),
                                    image: modele.image, mesure: .liste)
                ligneSignets
                liste
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: BibliothequeRoute.self) { route in
            BibliothequeDestination(route: route, sousSection: sousSection, entree: entree)
        }
        .sheet(isPresented: feuilleOuverte, onDismiss: ouvrirSignetChoisi) {
            BibliothequeFeuilleSignets(modele: modele) { route in
                signetChoisi = route
            }
        }
        .task { await modele.charger() }
    }

    /// La feuille suit le modèle ; la fermer d'un geste passe par `fermerSignets()`.
    private var feuilleOuverte: Binding<Bool> {
        Bindable(modele).feuilleSignetsLiee
    }

    private func ouvrirSignetChoisi() {
        guard let route = signetChoisi else { return }
        signetChoisi = nil
        ouvrir(route)
    }

    // MARK: La ligne des marque-pages

    @ViewBuilder
    private var ligneSignets: some View {
        if let ligne = modele.ligneSignets {
            Button {
                modele.ouvrirSignets()
            } label: {
                HStack(spacing: 8) {
                    Text(verbatim: traducteur.texte(ligne.titre) + " · " + String(ligne.nombre) + "  ›")
                        .policeHebraique(modele.police, taille: 19)
                        .foregroundStyle(Teinte(.ink))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    Image(systemName: BibliothequeIcone.symbole(ligne.icone))
                        .font(.body)
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
                .environment(\.layoutDirection, .rightToLeft)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    // MARK: La liste

    private var liste: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(modele.lignes) { ligne in
                BibliothequeLigneVue(ligne: ligne, ouvrir: ouvrir)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 24)
    }
}

// MARK: - Les lignes

/// Une ligne de la liste : le titre d'une section (item_library_section), ou la carte d'une sous-section ou d'un
/// livre (item_library_subsection).
private struct BibliothequeLigneVue: View {
    let ligne: BibliothequeLigne
    let ouvrir: @MainActor (BibliothequeRoute) -> Void
    @Environment(\.traducteur) private var traducteur
    @ScaledMetric(relativeTo: .body) private var dynamique: CGFloat = 1

    init(ligne: BibliothequeLigne, ouvrir: @escaping @MainActor (BibliothequeRoute) -> Void) {
        self.ligne = ligne
        self.ouvrir = ouvrir
    }

    var body: some View {
        switch ligne.sorte {
        case .titre:
            titre
        case .carte:
            carte
        }
    }

    // MARK: Le titre d'une section

    private var titre: some View {
        VStack(alignment: .leading, spacing: 0) {
            hebreu(taille: 19)
            if let traduction = ligne.traduction {
                Text(verbatim: traduction)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Le titre hébreu : Noto Serif Hebrew en gras, de droite à gauche quelle que soit la langue, aligné au début.
    private func hebreu(taille: CGFloat) -> some View {
        Text(verbatim: ligne.hebreu)
            .font(Font.hebreu(.serif, taille: taille * dynamique).bold())
            .foregroundStyle(Teinte(.ink))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: La carte d'une sous-section ou d'un livre

    @ViewBuilder
    private var carte: some View {
        if let route = ligne.route {
            BibliothequeToucher(route: route, ouvrir: ouvrir) {
                contenuCarte
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        } else {
            contenuCarte
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
    }

    private var contenuCarte: some View {
        HStack(spacing: 12) {
            if let image = ligne.image {
                BibliothequeCadre(image: image, largeur: 66, hauteur: 80, fond: .stageSoft)
            }
            VStack(alignment: .leading, spacing: 0) {
                hebreu(taille: 18)
                if let traduction = ligne.traduction {
                    Text(verbatim: traduction)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.muted))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let compte = ligne.compte {
                    Text(compte, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.brand))
                        .padding(.top, 8)
                }
            }
        }
        .padding(16)
        .fondCarteBibliotheque()
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Ce qu'ouvre une carte : une sous-page de la bibliothèque se pousse dans la pile (`NavigationLink(value:)`) ; le
/// lecteur du siddour, un autre écran, passe par `ouvrir`. Les cartes de la bibliothèque n'ont pas d'effet de
/// toucher (Android ne les creuse pas).
struct BibliothequeToucher<Contenu: View>: View {
    let route: BibliothequeRoute
    let ouvrir: @MainActor (BibliothequeRoute) -> Void
    let contenu: Contenu

    init(route: BibliothequeRoute, ouvrir: @escaping @MainActor (BibliothequeRoute) -> Void,
         @ViewBuilder contenu: () -> Contenu) {
        self.route = route
        self.ouvrir = ouvrir
        self.contenu = contenu()
    }

    var body: some View {
        switch route {
        case .sousSection, .entree:
            NavigationLink(value: route) {
                contenu
            }
            .buttonStyle(.plain)
        case .livre, .marque:
            Button {
                ouvrir(route)
            } label: {
                contenu
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Les sous-pages

/// La destination d'une route poussée dans la pile : une sous-section ou une entrée. Le lecteur du siddour n'est
/// jamais poussé ici (`BibliothequeToucher` le confie à `ouvrir`).
private struct BibliothequeDestination: View {
    let route: BibliothequeRoute
    let sousSection: @MainActor (String) -> BibliothequeSousSectionModele
    let entree: @MainActor (String) -> BibliothequeEntreeModele

    init(route: BibliothequeRoute,
         sousSection: @escaping @MainActor (String) -> BibliothequeSousSectionModele,
         entree: @escaping @MainActor (String) -> BibliothequeEntreeModele) {
        self.route = route
        self.sousSection = sousSection
        self.entree = entree
    }

    var body: some View {
        switch route {
        case .sousSection(let id):
            BibliothequeSousSectionPage(id: id, fabrique: sousSection)
        case .entree(let id):
            BibliothequeEntreePage(id: id, fabrique: entree)
        case .livre, .marque:
            Rectangle().fill(Teinte(.paper))
        }
    }
}

/// Une sous-section poussée dans la pile : elle garde son modèle d'une mise à jour de la page à l'autre (la
/// destination de navigation est recalculée, le modèle ne doit pas l'être).
public struct BibliothequeSousSectionPage: View {
    private let id: String
    private let fabrique: @MainActor (String) -> BibliothequeSousSectionModele
    @State private var modele: BibliothequeSousSectionModele? = nil

    public init(id: String, fabrique: @escaping @MainActor (String) -> BibliothequeSousSectionModele) {
        self.id = id
        self.fabrique = fabrique
    }

    public var body: some View {
        Group {
            if let modele {
                BibliothequeSousSectionVue(modele: modele)
            } else {
                Rectangle().fill(Teinte(.paper))
            }
        }
        .onAppear {
            if modele == nil {
                modele = fabrique(id)
            }
        }
    }
}

/// Une entrée poussée dans la pile, de même.
public struct BibliothequeEntreePage: View {
    private let id: String
    private let fabrique: @MainActor (String) -> BibliothequeEntreeModele
    @State private var modele: BibliothequeEntreeModele? = nil

    public init(id: String, fabrique: @escaping @MainActor (String) -> BibliothequeEntreeModele) {
        self.id = id
        self.fabrique = fabrique
    }

    public var body: some View {
        Group {
            if let modele {
                BibliothequeEntreeVue(modele: modele)
            } else {
                Rectangle().fill(Teinte(.paper))
            }
        }
        .onAppear {
            if modele == nil {
                modele = fabrique(id)
            }
        }
    }
}

// MARK: - La sous-section

/// Les entrées d'une sous-section (LibrarySubSectionActivity.kt, activity_library.xml, item_library_entry.xml) :
/// le bandeau, puis une carte par entrée, les sources d'abord. Toucher une carte pousse l'entrée
/// (`NavigationLink(value: BibliothequeRoute.entree)`), que résout la destination posée par `BibliothequeVue`.
public struct BibliothequeSousSectionVue: View {
    let modele: BibliothequeSousSectionModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.dismiss) private var dismiss

    public init(modele: BibliothequeSousSectionModele) {
        self.modele = modele
    }

    public var body: some View {
        VStack(spacing: 0) {
            BibliothequeBandeau(titre: Text(verbatim: modele.titre),
                                sousTitre: modele.sousTitre.map { Text(verbatim: $0) },
                                image: modele.image, mesure: .liste)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(modele.entrees) { entree in
                        NavigationLink(value: entree.route) {
                            BibliothequeEntreeCarte(entree: entree)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(verbatim: modele.titre))
        .navigationBarTitleDisplayMode(.inline)
        .task { await modele.charger() }
        .onChange(of: modele.etat) { _, etat in
            // finish() d'Android : l'identifiant ne désigne rien.
            if etat == .introuvable { dismiss() }
        }
    }
}

/// La carte d'une entrée (item_library_entry.xml) : l'illustration, la pastille « Source » ou « Article », le titre
/// et la référence.
private struct BibliothequeEntreeCarte: View {
    let entree: BibliothequeEntreeLigne
    @Environment(\.traducteur) private var traducteur

    init(entree: BibliothequeEntreeLigne) {
        self.entree = entree
    }

    var body: some View {
        HStack(spacing: 12) {
            BibliothequeCadre(image: entree.image, largeur: 56, hauteur: 68, fond: .stageSoft)
            VStack(alignment: .leading, spacing: 0) {
                Text(entree.nature, traducteur: traducteur)
                    .font(.caption2)
                    .foregroundStyle(Teinte(.onPlate))
                    .padding(.horizontal, 8)
                    .background(Teinte(.mint), in: Capsule())
                    .padding(.bottom, 4)
                titre
                if let detail = entree.detail {
                    Text(verbatim: detail)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                        .multilineTextAlignment(.leading)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .fondCarteBibliotheque()
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// Le titre : de droite à gauche pour une source, dans le sens de la langue pour un article.
    @ViewBuilder
    private var titre: some View {
        let texte = Text(verbatim: entree.titre)
            .font(Font.callout.bold())
            .foregroundStyle(Teinte(.ink))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        if entree.titreDroiteAGauche {
            texte.environment(\.layoutDirection, .rightToLeft)
        } else {
            texte
        }
    }
}

// MARK: - La feuille des marque-pages

/// La feuille des marque-pages des livres (RepriseFavoris.listeSignets, recueil « l ») : les puces « Tout »,
/// « Livres » et un livre par puce, puis les marque-pages ; en toucher un ferme la feuille et ouvre le lecteur à sa
/// place.
private struct BibliothequeFeuilleSignets: View {
    let modele: BibliothequeModele
    let choisir: @MainActor (BibliothequeRoute) -> Void
    @Environment(\.traducteur) private var traducteur

    init(modele: BibliothequeModele, choisir: @escaping @MainActor (BibliothequeRoute) -> Void) {
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
        .hauteursDeFeuille([.medium, .large])
    }

    private var puces: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(modele.filtresSignets) { filtre in
                    puce(filtre)
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.bottom, 4)
    }

    /// Une puce à sélection unique : la cochée porte une coche et le fond menthe. La puce d'un livre montre son
    /// titre dans la police de lecture ; « Tout » et « Livres », la police du système.
    private func puce(_ filtre: BibliothequeFiltreSignets) -> some View {
        let choisie = filtre.id == modele.filtreSignets
        return Button {
            modele.choisirFiltreSignets(filtre.id)
        } label: {
            HStack(spacing: 4) {
                if choisie {
                    Image(systemName: "checkmark")
                        .font(Font.caption.weight(.semibold))
                }
                nomPuce(filtre)
            }
            .foregroundStyle(Teinte(choisie ? .onPlate : .ink))
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Teinte(choisie ? .mint : .card), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Teinte(.line), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(choisie ? .isSelected : [])
    }

    @ViewBuilder
    private func nomPuce(_ filtre: BibliothequeFiltreSignets) -> some View {
        if let libelle = filtre.libelle {
            Text(libelle, traducteur: traducteur)
                .font(.footnote)
        } else if let titre = filtre.titre {
            Text(verbatim: titre)
                .policeHebraique(modele.police, taille: 13, relativeA: .footnote)
        }
    }

    private func ligneVue(_ ligne: BibliothequeSignetLigne) -> some View {
        Button {
            choisir(modele.choisirSignet(ligne))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: ligne.titre)
                        .policeHebraique(modele.police, taille: 13, relativeA: .footnote)
                        .foregroundStyle(Teinte(.muted))
                    Image(systemName: BibliothequeIcone.symbole(ligne.icone))
                        .font(.footnote)
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
                Text(verbatim: ligne.apercu)
                    .policeHebraique(modele.police, taille: 17)
                    .foregroundStyle(Teinte(.ink))
                    .lignesAuPlus(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.vertical, 10)
            .environment(\.layoutDirection, .rightToLeft)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
