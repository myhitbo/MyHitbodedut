import Barriere
import Coeur
import Ecrans
import SwiftUI
import Vues
#if !SANS_BARRIERE
import FamilyControls
import ManagedSettings
#endif

// Les écrans de la barrière ouverts depuis les réglages (tâches 27 et 28) : l'aperçu du bouclier et l'essai réel, le
// choix des applications sur le sélecteur d'Apple, la dédicace, le journal de la barrière. La racine les pousse dans la
// pile de l'onglet (`Ecran.barriere`) ; leurs modèles sont construits ici, à l'ouverture, gardés par `Garde`.

/// Un écran de la barrière (ou de la dédicace, voisine dans les réglages).
enum EcranBarriere: Hashable {
    case apercu
    case choixApplications
    case dedicace
    case journal

    /// L'écran d'une route des réglages ; nil pour une route qui n'en est pas un.
    init?(_ route: ReglagesRoute) {
        switch route {
        case .apercuBarriere: self = .apercu
        case .choixApplications: self = .choixApplications
        case .dedicace: self = .dedicace
        case .journalBarriere: self = .journal
        default: return nil
        }
    }
}

/// La destination de la pile pour un écran de la barrière.
struct BarriereDestination: View {
    let app: ModelesApp
    let ecran: EcranBarriere

    var body: some View {
        switch ecran {
        case .apercu:
            Garde(app.apercuBouclier) { ApercuBouclierVue(modele: $0) }
        case .choixApplications:
            Garde(app.choixApplications) { ChoixApplicationsEcran(modele: $0, tempsEcran: app.tempsEcran) }
        case .dedicace:
            Garde(app.dedicace) { DedicaceVue(modele: $0) }
        case .journal:
            Garde(app.journalBarriere) { JournalBarriereVue(modele: $0) }
        }
    }
}

extension ModelesApp {
    func apercuBouclier() -> ApercuBouclierModele {
        ApercuBouclierModele(magasin: magasin, horloge: horloge, traducteur: traducteur, palette: tempsEcran.palette,
                             systeme: tempsEcran)
    }

    func choixApplications() -> ChoixApplicationsModele {
        ChoixApplicationsModele(magasin: magasin, systeme: tempsEcran)
    }

    func dedicace() -> DedicaceModele {
        DedicaceModele(traducteur: traducteur)
    }

    func journalBarriere() -> JournalBarriereModele {
        JournalBarriereModele(systeme: tempsEcran)
    }
}

/// Le choix des applications (AppPickerActivity) sur le sélecteur d'Apple : la vue de Vues, avec ce qui vient de
/// FamilyControls (le sélecteur, `Label(jeton)` que le système dessine : l'app ne connaît ni le nom ni l'icône). Une
/// sélection changée s'enregistre aussitôt, et les boucliers la suivent.
struct ChoixApplicationsEcran: View {
    let modele: ChoixApplicationsModele
    let tempsEcran: TempsEcranApp
    #if !SANS_BARRIERE
    @State private var selection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var enregistree: FamilyActivitySelection? = nil
    @State private var selecteurOuvert = false
    #endif

    var body: some View {
        #if !SANS_BARRIERE
        ChoixApplicationsVue(modele: modele, choisir: { selecteurOuvert = true },
                             retirer: { selection = FamilyActivitySelection(includeEntireCategory: true) }) {
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
        .familyActivityPicker(isPresented: $selecteurOuvert, selection: $selection)
        .onChange(of: selection) { _, nouvelle in
            guard let precedente = enregistree, nouvelle != precedente else { return }
            enregistree = nouvelle
            Task {
                let resume = await tempsEcran.enregistrer(nouvelle)
                modele.selectionEnregistree(resume)
            }
        }
        .task {
            let lue = tempsEcran.selectionActuelle()
            enregistree = lue
            selection = lue
            await modele.rafraichir()
        }
        #else
        ChoixApplicationsVue(modele: modele, choisir: {}, retirer: {}) { EmptyView() }
            .task { await modele.rafraichir() }
        #endif
    }
}
