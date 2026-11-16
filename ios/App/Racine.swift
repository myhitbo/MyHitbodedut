import Coeur
import Ecrans
import SwiftUI
import Vues

/// Les cinq onglets de l'app, dans l'ordre de la barre d'Android (Onglet, nav_main.xml), chacun avec sa pile de
/// navigation (PORTAGE.md § 1.2). La racine pose aussi l'apparence tirée des réglages : la palette, le mode clair
/// ou sombre, l'adresse qui choisit le personnage ; un réglage changé se voit aussitôt.
struct Racine: View {
    let magasin: Magasin
    let palettes: Palettes?
    let zmanim: ZmanimModele
    @Binding var onglet: Onglet
    @Environment(\.colorScheme) private var schema

    init(magasin: Magasin, palettes: Palettes?, zmanim: ZmanimModele, onglet: Binding<Onglet>) {
        self.magasin = magasin
        self.palettes = palettes
        self.zmanim = zmanim
        _onglet = onglet
    }

    var body: some View {
        let apparence = ApparenceChoisie(magasin.reglages)
        let palette = PaletteApp.choisie(palettes, apparence)
        TabView(selection: $onglet) {
            Tab(LocalizedStringKey(Onglet.aujourdhui.cle), systemImage: Onglet.aujourdhui.symbole,
                value: Onglet.aujourdhui) {
                NavigationStack { EnAttente(onglet: .aujourdhui) }
            }
            Tab(LocalizedStringKey(Onglet.textes.cle), systemImage: Onglet.textes.symbole,
                value: Onglet.textes) {
                NavigationStack { EnAttente(onglet: .textes) }
            }
            Tab(LocalizedStringKey(Onglet.zmanim.cle), systemImage: Onglet.zmanim.symbole,
                value: Onglet.zmanim) {
                NavigationStack { ZmanimVue(modele: zmanim) }
            }
            Tab(LocalizedStringKey(Onglet.journal.cle), systemImage: Onglet.journal.symbole,
                value: Onglet.journal) {
                NavigationStack { EnAttente(onglet: .journal) }
            }
            Tab(LocalizedStringKey(Onglet.reglages.cle), systemImage: Onglet.reglages.symbole,
                value: Onglet.reglages) {
                NavigationStack { EnAttente(onglet: .reglages) }
            }
        }
        .tint(palette.couleur(.brand, schema: schema))
        .environment(\.paletteApp, palette)
        .environment(\.apparence, apparence)
        .preferredColorScheme(apparence.schema)
    }
}

/// Un onglet dont l'écran n'est pas encore porté : son titre, son icône et « Bientôt », sans rien faire semblant.
/// La chaîne est propre à iOS (Ressources/Chaines/ios.xcstrings, à relire par le propriétaire).
struct EnAttente: View {
    let onglet: Onglet

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(LocalizedStringKey(onglet.cle))
            } icon: {
                Image(systemName: onglet.symbole)
            }
        } description: {
            Text("ios_bientot", tableName: "ios")
        }
        .foregroundStyle(Teinte(.ink))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Teinte(.paper))
        .navigationTitle(Text(LocalizedStringKey(onglet.cle)))
    }
}
