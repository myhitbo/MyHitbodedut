import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'accueil, l'onglet Aujourd'hui (MainActivity.kt, le panneau main_scroll d'activity_main.xml) : de haut en bas,
/// l'en-tête, la jauge des trois anneaux et sa plaque, la légende, la ligne du trophée, « Commencer » et ses
/// pastilles, la bande de la semaine, le mot de relance, la note et « Je l'ai faite sans le téléphone », les cartes
/// du moment, « Trophées » et « Mon parcours ». Tout se lit dans `AccueilModele` ; la vue joue les mouvements
/// qu'il demande et lui rend chaque geste.
///
/// Chaque apparition (retour sur l'onglet, retour d'un écran ouvert, retour au premier plan) pose « Réduire les
/// animations » dans le modèle puis appelle `apparaitre()`, l'onResume d'Android. Les écrans que l'accueil ouvre
/// (séance, paliers, parcours, musique, note, bravo, présentation, siddour, bibliothèque) passent par `ouvrir`, que
/// l'app branche sur sa navigation ; la fiche d'un trophée neuf et le bilan de la semaine s'ouvrent ici.
public struct AccueilVue: View {
    let modele: AccueilModele
    private let formes: TropheeFormes
    private let ouvrir: @MainActor (AccueilRoute) -> Void
    private let preparer: @MainActor () async -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    @Environment(\.dynamicTypeSize) private var tailleTexte
    @Environment(\.scenePhase) private var phase

    /// Le champ de la durée réglable, prérempli à l'ouverture de sa boîte.
    @State private var texteLibre = ""
    /// Les fiches des trophées neufs s'ouvrent `retardFiches` après la première apparition.
    @State private var fichesPermises = false
    /// L'app est passée au second plan : son retour est un nouveau passage.
    @State private var auSecondPlan = false
    /// La cascade des cartes du moment est lancée.
    @State private var cascadeJouee = false

    /// - Parameters:
    ///   - modele: `AccueilModele(magasin:contenus:horloge:langue:barriere:debug:systeme:)`, gardé par l'app tant
    ///     que l'onglet vit.
    ///   - formes: les formes des trophées (`TropheeFormes.lire`), lues une fois par l'app.
    ///   - ouvrir: les écrans que l'accueil ouvre (`AccueilRoute`).
    ///   - preparer: ce que l'app fait avant chaque passage (onResume d'Android, avant `apparaitre()`) : la séance
    ///     restée inscrite close ou relancée, la position reprise après un voyage. Rien par défaut.
    public init(modele: AccueilModele, formes: TropheeFormes,
                ouvrir: @escaping @MainActor (AccueilRoute) -> Void,
                preparer: @escaping @MainActor () async -> Void = {}) {
        self.modele = modele
        self.formes = formes
        self.ouvrir = ouvrir
        self.preparer = preparer
    }

    public var body: some View {
        avecDialogues
            .tropheeFiche(fichesPermises ? modele.fete.ficheCourante : nil, formes: formes) {
                TropheeTransaction.sansAnimation {
                    modele.fete.fermerFiche()
                }
            }
            .task {
                await passer()
            }
            .onChange(of: phase) { _, nouvelle in
                if nouvelle == .background {
                    auSecondPlan = true
                } else if nouvelle == .active && auSecondPlan {
                    auSecondPlan = false
                    Task {
                        await passer()
                    }
                }
            }
            .onChange(of: reduire) { _, valeur in
                modele.reduireAnimations = valeur
            }
            .onChange(of: modele.routes.first, initial: true) { _, route in
                guard let route else { return }
                ouvrir(route)
                modele.routeOuverte()
            }
            .task(id: modele.cascade) {
                await lancerCascade()
            }
    }

    // MARK: La page

    private var page: some View {
        GeometryReader { geometrie in
            let mesures = AccueilMesures(largeur: geometrie.size.width,
                                         hauteur: geometrie.size.height + geometrie.safeAreaInsets.bottom,
                                         texteAgrandi: tailleTexte >= .xLarge)
            ScrollView {
                contenu(mesures)
                    .padding(.horizontal, mesures.marge)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Teinte(.paper))
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            messages
        }
    }

    private func contenu(_ mesures: AccueilMesures) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            AccueilEnteteVue(modele: modele)
            AccueilJaugeVue(modele: modele, cote: mesures.cote, retraitPlaque: mesures.retraitPlaque)
                .frame(maxWidth: .infinity)
                .padding(.top, mesures.hautJauge)
            Text(modele.legende, traducteur: traducteur)
                .tropheeTexte(16)
                .foregroundStyle(AccueilTeinte(modele.couleurLegende))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            AccueilLigneTropheeVue(ligne: modele.ligneTrophee, fete: modele.fete, formes: formes) {
                modele.ouvrirPaliers()
            }
            .padding(.top, 4)
            depart
            AccueilSemaineVue(jours: modele.semaine, langue: modele.langue) { date in
                modele.ouvrirJour(date)
            }
            .padding(.top, 16)
            suite
        }
    }

    /// « Commencer » et ses pastilles.
    private var depart: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                modele.commencer()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text(modele.libelleCommencer, traducteur: traducteur)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principalGrand)
            .padding(.top, 16)
            AccueilPastillesVue(pastilles: modele.pastilles) { genre in
                lancer {
                    try await modele.toucherPastille(genre)
                }
            }
            .padding(.top, 12)
        }
    }

    /// Sous la bande : la relance, la note, la séance hors du téléphone, les cartes du moment, les deux boutons.
    private var suite: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let relance = modele.relance {
                AccueilRelanceVue(carte: relance)
                    .padding(.top, 12)
            }
            if let note = modele.libelleNote {
                AccueilBoutonTexte(libelle: note) {
                    modele.ecrireNote()
                }
                .padding(.top, 4)
            }
            if let horsTelephone = modele.libelleHorsTelephone {
                AccueilBoutonTexte(libelle: horsTelephone) {
                    modele.declarerHorsTelephone()
                }
                .padding(.top, 4)
            }
            cartes
            rangeeBas
                .padding(.top, 12)
                .padding(.bottom, 8)
        }
    }

    private var cartes: some View {
        ForEach(Array(modele.cartes.enumerated()), id: \.element.id) { rang, carte in
            AccueilCarteVue(carte: carte, police: modele.police, langue: modele.langue) { route in
                modele.ouvrir(route)
            }
            .padding(.top, 12)
            .modifier(AccueilCascade(rang: rang, visible: !modele.cascade || cascadeJouee))
        }
    }

    /// « Trophées » et « Mon parcours », côte à côte, de même largeur.
    private var rangeeBas: some View {
        HStack(spacing: 8) {
            Button {
                modele.ouvrirPaliers()
            } label: {
                Text(modele.libelleTrophees, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
            Button {
                modele.ouvrirParcours()
            } label: {
                Text(modele.libelleParcours, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondaire)
        }
    }

    /// Les mots brefs : la phrase d'un palier neuf (3,5 s), puis le message du modèle (2 s).
    private var messages: some View {
        VStack(spacing: 8) {
            if let palier = modele.fete.palier {
                AccueilMessageBref(message: palier, duree: 3500) {
                    modele.fete.palierMontre()
                }
            }
            if let message = modele.message {
                AccueilMessageBref(message: message, duree: 2000) {
                    modele.messageMontre()
                }
            }
        }
    }

    // MARK: Les boîtes

    /// Les boîtes sont posées sur des vues distinctes : une boîte peut en ouvrir une autre (la liste des durées
    /// ouvre la durée réglable, le jour ouvre la liste des durées).
    private var avecDialogues: some View {
        page
            .background {
                Color.clear
                    .confirmationDialog(titreDialogue, isPresented: ouverte(.liste), titleVisibility: .visible) {
                        actionsListe
                    }
            }
            .background {
                Color.clear
                    .alert(titreDialogue, isPresented: ouverte(.dureeLibre)) {
                        actionsDureeLibre
                    }
            }
            .background {
                Color.clear
                    .alert(titreJour, isPresented: ouverte(.jour)) {
                        actionsJour
                    } message: {
                        messageJour
                    }
            }
            .background {
                Color.clear
                    .sheet(isPresented: bilanOuvert) {
                        bilan
                    }
            }
            .onChange(of: modele.dialogue) { _, dialogue in
                if case .dureeLibre? = dialogue {
                    texteLibre = modele.texteDureeLibre
                }
            }
    }

    private var titreDialogue: Text {
        Text(verbatim: modele.titreDialogue.map { traducteur.texte($0) } ?? "")
    }

    /// La boîte de ce genre est ouverte. Fermée par SwiftUI (un toucher à côté), elle l'est aussi dans le modèle, si
    /// aucun bouton n'a déjà changé la boîte : le contrôle attend la fin du geste en cours.
    private func ouverte(_ genre: AccueilGenreBoite) -> Binding<Bool> {
        let modele = self.modele
        return Binding(get: { @MainActor in
            modele.dialogue.map { AccueilGenreBoite($0) == genre } ?? false
        }, set: { @MainActor montree in
            guard !montree, let boite = modele.dialogue, AccueilGenreBoite(boite) == genre else { return }
            Task { @MainActor in
                await Task.yield()
                if modele.dialogue == boite {
                    modele.fermerDialogue()
                }
            }
        })
    }

    /// Les listes : les durées, les sujets, le jour d'une séance faite sans le téléphone ; puis « Retour ».
    @ViewBuilder
    private var actionsListe: some View {
        switch modele.dialogue {
        case .duree?:
            ForEach(modele.optionsDuree) { option in
                Button {
                    lancer {
                        try await modele.choisirDuree(option.minutes)
                    }
                } label: {
                    Text(option.libelle, traducteur: traducteur)
                }
            }
        case .sujet?:
            ForEach(modele.optionsSujet) { option in
                Button {
                    lancer {
                        try await modele.choisirSujet(option.theme)
                    }
                } label: {
                    Text(option.libelle, traducteur: traducteur)
                }
            }
        case .jourHorsTelephone?:
            ForEach(Array(modele.optionsJourHorsTelephone.enumerated()), id: \.offset) { rang, option in
                Button {
                    // La seconde ligne est « Hier ».
                    modele.choisirJourHorsTelephone(hier: rang == 1)
                } label: {
                    Text(option, traducteur: traducteur)
                }
            }
        default:
            EmptyView()
        }
        Button(role: .cancel) {
            modele.fermerDialogue()
        } label: {
            Text(modele.libelleRetour, traducteur: traducteur)
        }
    }

    /// La durée réglable : un champ numérique, « OK », « Retour ».
    @ViewBuilder
    private var actionsDureeLibre: some View {
        let indication = traducteur.texte(modele.indicationDureeLibre)
        TextField(text: $texteLibre, prompt: Text(verbatim: indication)) {
            Text(verbatim: indication)
        }
        .keyboardType(.numberPad)
        Button {
            let texte = texteLibre
            lancer {
                try await modele.validerDureeLibre(texte)
            }
        } label: {
            Text(modele.libelleValider, traducteur: traducteur)
        }
        Button(role: .cancel) {
            modele.fermerDialogue()
        } label: {
            Text(modele.libelleRetour, traducteur: traducteur)
        }
    }

    /// La boîte d'un jour de la bande : la date en entier pour titre.
    private var titreJour: Text {
        guard case .jour(let boite)? = modele.dialogue else { return Text(verbatim: "") }
        return Text(verbatim: AccueilDates.complete(boite.date, langue: modele.langue))
    }

    @ViewBuilder
    private var messageJour: some View {
        if case .jour(let boite)? = modele.dialogue {
            Text(boite.message, traducteur: traducteur)
        }
    }

    @ViewBuilder
    private var actionsJour: some View {
        if case .jour(let boite)? = modele.dialogue {
            Button {
                modele.ajouterTemps()
            } label: {
                Text(boite.ajouter, traducteur: traducteur)
            }
            if let montrer = boite.montrer {
                Button {
                    modele.montrerDuree()
                } label: {
                    Text(montrer, traducteur: traducteur)
                }
            }
            Button(role: .cancel) {
                modele.fermerDialogue()
            } label: {
                Text(boite.retour, traducteur: traducteur)
            }
        }
    }

    // MARK: Le bilan

    /// Le bilan s'ouvre quand aucune fiche de trophée n'est à montrer (elles passent d'abord).
    private var bilanOuvert: Binding<Bool> {
        let modele = self.modele
        let permis = fichesPermises
        return Binding(get: { @MainActor in
            permis && modele.bilan != nil && modele.fete.ficheCourante == nil
        }, set: { @MainActor ouvert in
            if !ouvert {
                modele.fermerBilan()
            }
        })
    }

    @ViewBuilder
    private var bilan: some View {
        if let bilan = modele.bilan {
            AccueilBilanVue(bilan: bilan, formes: formes) {
                modele.fermerBilan()
            }
            .presentationDetents([.medium, .large])
            .presentationBackground(Teinte(.card))
        }
    }

    // MARK: Le passage

    /// onResume : « Réduire les animations » d'abord, puis le passage ; la première fois, les fiches des trophées
    /// neufs peuvent s'ouvrir `retardFiches` après.
    private func passer() async {
        await preparer()
        modele.reduireAnimations = reduire
        await modele.apparaitre()
        guard !fichesPermises else { return }
        guard await TropheeAttente.ms(TropheeFeteModele.retardFiches) else { return }
        TropheeTransaction.sansAnimation {
            fichesPermises = true
        }
    }

    /// La cascade des cartes, `departCascade` après la première apparition.
    private func lancerCascade() async {
        guard modele.cascade, !cascadeJouee else { return }
        guard await TropheeAttente.ms(AccueilModele.departCascade) else { return }
        cascadeJouee = true
    }

    /// Lance une action du modèle qui peut écrire : tout de suite, pour que la boîte qu'elle ferme le soit avant que
    /// SwiftUI ne signale sa fermeture. Une écriture refusée ne montre rien, comme sur Android.
    private func lancer(_ action: @escaping @MainActor () async throws -> Void) {
        Task.immediate { @MainActor in
            do {
                try await action()
            } catch {
                // Android écrit ses préférences sans échec possible : rien de plus à montrer.
            }
        }
    }
}

// MARK: Les mesures

/// Les marges et la taille de la jauge selon la place (dimens.xml et ses variantes w360dp, w600dp, w840dp,
/// w1200dp, h640dp, h720dp).
private struct AccueilMesures {
    /// La marge de chaque côté : 16, 24 dès 360 pt de large ; puis 16 et une gouttière de 32, 104 ou 304.
    let marge: CGFloat
    /// Le côté du carré de la jauge.
    let cote: CGFloat
    /// La plaque est rentrée d'autant du bord de la jauge.
    let retraitPlaque: CGFloat
    /// La marge au-dessus de la jauge.
    let hautJauge: CGFloat

    init(largeur: CGFloat, hauteur: CGFloat, texteAgrandi: Bool) {
        let marge: CGFloat
        if largeur >= 1200 {
            marge = 16 + 304
        } else if largeur >= 840 {
            marge = 16 + 104
        } else if largeur >= 600 {
            marge = 16 + 32
        } else if largeur >= 360 {
            marge = 24
        } else {
            marge = 16
        }
        self.marge = marge
        // Un texte agrandi sur un écran bas, en portrait : la jauge se fait petite pour laisser la place au reste.
        let compacte = texteAgrandi && hauteur < 640 && largeur < hauteur
        let voulu: CGFloat
        if compacte {
            voulu = 96
        } else if hauteur >= 720 {
            voulu = 292
        } else if hauteur >= 640 {
            voulu = 260
        } else {
            voulu = 176
        }
        cote = max(min(voulu, largeur - 2 * marge), 0)
        retraitPlaque = compacte ? 24 : 32
        hautJauge = compacte ? 2 : 16
    }
}

/// Les trois sortes de boîtes, chacune posée à part.
private enum AccueilGenreBoite: Equatable {
    case liste
    case dureeLibre
    case jour

    init(_ dialogue: AccueilDialogue) {
        switch dialogue {
        case .duree, .sujet, .jourHorsTelephone: self = .liste
        case .dureeLibre: self = .dureeLibre
        case .jour: self = .jour
        }
    }
}
