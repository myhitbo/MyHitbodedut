import Coeur
import Ecrans
import SwiftUI
import Vues

/// Un écran qu'ouvre la pile du Jour : les zmanim (la date hébraïque de l'en-tête) et les réglages (la roue).
enum EcranDuJour: Hashable {
    case zmanim
    case reglages
}

/// Un écran qu'ouvre la pile du Chemin : le journal, « Mon parcours », les trophées.
enum EcranDuChemin: Hashable {
    case journal
    case parcours
    case paliers
}

/// Les trois onglets de l'app, dans l'ordre de la barre d'Android (Onglet, nav_main.xml ; refonte du 13/11), chacun
/// avec sa pile de navigation (PORTAGE.md § 1.2). Zmanim et Réglages ne sont plus des onglets : l'en-tête du Jour les
/// ouvre dans sa pile. La racine pose aussi l'apparence tirée des réglages : la palette, le mode clair ou sombre,
/// l'adresse qui choisit le personnage ; un réglage changé se voit aussitôt.
struct Racine: View {
    let magasin: Magasin
    let palettes: Palettes?
    let zmanim: ZmanimModele
    let accueil: AccueilModele
    let chemin: CheminModele
    @Binding var onglet: Onglet
    @Binding var pileDuJour: [EcranDuJour]
    @State private var pileDuChemin: [EcranDuChemin] = []
    @Environment(\.colorScheme) private var schema

    init(magasin: Magasin, palettes: Palettes?, zmanim: ZmanimModele, accueil: AccueilModele, chemin: CheminModele,
         onglet: Binding<Onglet>, pileDuJour: Binding<[EcranDuJour]>) {
        self.magasin = magasin
        self.palettes = palettes
        self.zmanim = zmanim
        self.accueil = accueil
        self.chemin = chemin
        _onglet = onglet
        _pileDuJour = pileDuJour
    }

    var body: some View {
        let apparence = ApparenceChoisie(magasin.reglages)
        let palette = PaletteApp.choisie(palettes, apparence)
        TabView(selection: $onglet) {
            Tab(LocalizedStringKey(Onglet.aujourdhui.cle), systemImage: Onglet.aujourdhui.symbole,
                value: Onglet.aujourdhui) {
                NavigationStack(path: $pileDuJour) {
                    LeJourEnAttente(accueil: accueil)
                        .navigationDestination(for: EcranDuJour.self) { ecran in
                            switch ecran {
                            case .zmanim:
                                ZmanimVue(modele: zmanim)
                            case .reglages:
                                EnAttente(cle: "settings_title", symbole: "gearshape")
                            }
                        }
                }
            }
            Tab(LocalizedStringKey(Onglet.textes.cle), systemImage: Onglet.textes.symbole,
                value: Onglet.textes) {
                NavigationStack { EnAttente(onglet: .textes) }
            }
            Tab(LocalizedStringKey(Onglet.chemin.cle), systemImage: Onglet.chemin.symbole,
                value: Onglet.chemin) {
                NavigationStack(path: $pileDuChemin) {
                    CheminVue(modele: chemin)
                        .navigationDestination(for: EcranDuChemin.self) { ecran in
                            switch ecran {
                            case .journal:
                                EnAttente(cle: "nav_journal", symbole: "pencil.line")
                            case .parcours:
                                EnAttente(cle: "parcours_title", symbole: "chart.bar")
                            case .paliers:
                                EnAttente(cle: "trophees_paliers", symbole: "trophy")
                            }
                        }
                }
            }
        }
        // Les routes des modèles deviennent des écrans de la pile ; celles dont l'écran n'est pas encore porté sont
        // retirées sans rien ouvrir.
        .onChange(of: accueil.routes) { _, routes in
            guard let route = routes.first else { return }
            switch route {
            case .zmanim: pileDuJour.append(.zmanim)
            case .reglages: pileDuJour.append(.reglages)
            default: break
            }
            accueil.routeOuverte()
        }
        .onChange(of: chemin.routes) { _, routes in
            guard let route = routes.first else { return }
            switch route {
            case .journal: pileDuChemin.append(.journal)
            case .parcours: pileDuChemin.append(.parcours)
            case .paliers: pileDuChemin.append(.paliers)
            }
            chemin.routeOuverte()
        }
        .tint(palette.couleur(.brand, schema: schema))
        .environment(\.paletteApp, palette)
        .environment(\.apparence, apparence)
        .preferredColorScheme(apparence.schema)
    }
}

/// Le Jour tant que son écran n'est pas porté : l'en-tête de la refonte (la date hébraïque vers les zmanim, la roue
/// vers les réglages), puis « Bientôt ».
struct LeJourEnAttente: View {
    let accueil: AccueilModele

    var body: some View {
        VStack(spacing: 0) {
            EnteteJour(modele: accueil)
                .padding(.horizontal, 16)
            EnAttente(onglet: .aujourdhui)
        }
        .background(Teinte(.paper))
    }
}

/// Un écran qui n'est pas encore porté : son titre, son icône et « Bientôt », sans rien faire semblant.
/// La chaîne est propre à iOS (Ressources/Chaines/ios.xcstrings, à relire par le propriétaire).
struct EnAttente: View {
    let cle: String
    let symbole: String

    init(cle: String, symbole: String) {
        self.cle = cle
        self.symbole = symbole
    }

    init(onglet: Onglet) {
        self.init(cle: onglet.cle, symbole: onglet.symbole)
    }

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(LocalizedStringKey(cle))
            } icon: {
                Image(systemName: symbole)
            }
        } description: {
            Text("ios_bientot", tableName: "ios")
        }
        .foregroundStyle(Teinte(.ink))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Teinte(.paper))
        .navigationTitle(Text(LocalizedStringKey(cle)))
    }
}
