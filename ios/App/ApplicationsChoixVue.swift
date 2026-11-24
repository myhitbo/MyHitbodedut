import Ecrans
import SwiftUI
import Vues
#if !SANS_BARRIERE
import FamilyControls
import ManagedSettings
#endif

/// L'écran du choix des applications de la barrière (AppPickerActivity d'Android) : `ApplicationsVue` (Vues), et
/// ce qui ne vit que dans FamilyControls, absent de Linux et de la construction sans barrière : le sélecteur
/// d'Apple, présenté quand `modele.selecteurOuvert` passe à vrai, et la liste des jetons, que le système dessine
/// (`Label(jeton)` : l'app n'en lit ni le nom ni l'icône).
///
/// La sélection tenue ici suit celle que le modèle garde (`modele.donnees`) ; ce que le sélecteur rend part au
/// modèle en octets (`retenir`), qui l'écrit dans le groupe d'apps (SystemeFamilyControls), puis la remet d'accord.
/// La construction SANS_BARRIERE n'ouvre jamais cet écran (les réglages n'en montrent pas l'entrée) ; elle le
/// compile sans FamilyControls.
struct ApplicationsChoixVue: View {
    @Bindable private var modele: ApplicationsModele

    #if !SANS_BARRIERE
    /// Ce que le sélecteur montre et modifie.
    @State private var selection = FamilyActivitySelection()
    /// Ce que le modèle garde, décodé : la liste des jetons, et de quoi reconnaître un vrai changement du
    /// sélecteur.
    @State private var retenue = FamilyActivitySelection()
    #endif

    init(modele: ApplicationsModele) {
        _modele = Bindable(wrappedValue: modele)
    }

    var body: some View {
        #if SANS_BARRIERE
        ApplicationsVue(modele: modele) {
            EmptyView()
        }
        #else
        ApplicationsVue(modele: modele) {
            ApplicationsJetons(selection: retenue)
        }
        .familyActivityPicker(isPresented: $modele.selecteurOuvert, selection: $selection)
        .onChange(of: modele.donnees, initial: true) { _, donnees in
            accorder(donnees)
        }
        .onChange(of: selection) { _, nouvelle in
            guard nouvelle != retenue else { return }
            retenue = nouvelle
            let donnees = SystemeFamilyControls.donnees(de: nouvelle)
            Task { @MainActor in
                await modele.retenir(donnees)
                // Une écriture refusée laisse le modèle sur l'ancienne sélection : le sélecteur y revient.
                accorder(modele.donnees)
            }
        }
        #endif
    }

    #if !SANS_BARRIERE
    /// Le sélecteur et la liste remis sur ce que le modèle garde.
    private func accorder(_ donnees: Data?) {
        let gardee = SystemeFamilyControls.selection(de: donnees)
        guard gardee != retenue || gardee != selection else { return }
        retenue = gardee
        selection = gardee
    }
    #endif
}

#if !SANS_BARRIERE
/// Les jetons retenus, catégories entières d'abord, puis les applications et les sites : leur nom et leur icône
/// dessinés par le système. L'ordre d'un ensemble de jetons n'a pas de sens (ils sont opaques), seul leur
/// regroupement en a un.
private struct ApplicationsJetons: View {
    let selection: FamilyActivitySelection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(selection.categoryTokens), id: \.self) { jeton in
                Label(jeton)
            }
            ForEach(Array(selection.applicationTokens), id: \.self) { jeton in
                Label(jeton)
            }
            ForEach(Array(selection.webDomainTokens), id: \.self) { jeton in
                Label(jeton)
            }
        }
    }
}
#endif
