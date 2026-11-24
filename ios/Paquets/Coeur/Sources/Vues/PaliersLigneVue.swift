import Foundation
import SwiftUI
import Coeur
import Ecrans

// La ligne des trophées de l'écran des paliers (PaliersActivity : banniere, etape, carteIci) et ses animations
// (AnimationsTrophees.kt) : la pousse des dernières étapes (B), le retournement et les étincelles des nouveaux
// (A + E), le compte de « Vous êtes ici » et la pulsation de sa barre presque pleine (D). Elles ne jouent que si le
// modèle le dit (`retardPousse`, `retardRetournement`, `animer`) et jamais avec « Réduire les animations » : tout
// est alors d'emblée à sa place.

/// L'ancre du défilement vers « Vous êtes ici » (`PaliersModele.idIci`) : le haut de la carte. Un type à part, car
/// la ligne elle-même porte déjà l'identité `"ici"` dans le ForEach (`PaliersLigne.id`), marge comprise ; deux
/// vues de même identité laisseraient `scrollTo` choisir l'une ou l'autre.
enum PaliersAncre: Hashable {
    case ici
}

/// Une ligne de la colonne, telle que le modèle la donne.
struct PaliersLigneVue: View {
    let ligne: PaliersLigne
    let formes: TropheeFormes
    /// `PaliersModele.animer` : le compte et la pulsation de « Vous êtes ici ».
    let animer: Bool
    /// Change avec le filtre : la barre de « Vous êtes ici » remonte de zéro, comme Android qui redessine tout.
    let cleBarres: String
    let ouvrirFiche: @MainActor (Trophees.Niveau) -> Void

    @Environment(\.traducteur) private var traducteur

    init(ligne: PaliersLigne, formes: TropheeFormes, animer: Bool, cleBarres: String,
         ouvrirFiche: @escaping @MainActor (Trophees.Niveau) -> Void) {
        self.ligne = ligne
        self.formes = formes
        self.animer = animer
        self.cleBarres = cleBarres
        self.ouvrirFiche = ouvrirFiche
    }

    var body: some View {
        switch ligne {
        case .banniere(let banniere):
            PaliersBanniereVue(banniere: banniere, formes: formes)
        case .etape(let etape):
            PaliersEtapeVue(etape: etape, formes: formes, ouvrirFiche: ouvrirFiche)
        case .ici(let ici):
            VStack(spacing: 0) {
                // L'ancre du défilement : le haut de la carte, sous sa marge.
                Color.clear
                    .frame(height: 0)
                    .id(PaliersAncre.ici)
                PaliersIciVue(ici: ici, formes: formes, animer: animer, cleBarres: cleBarres,
                              ouvrirFiche: ouvrirFiche)
            }
            .padding(.vertical, 8)
        case .tousGagnes(let libelle):
            Text(libelle, traducteur: traducteur)
                .tropheeTexte(18, gras: true)
                .foregroundStyle(Teinte(.ink))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
        case .autres(let libelle):
            Text(libelle, traducteur: traducteur)
                .tropheeTexte(13)
                .foregroundStyle(Teinte(.muted))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}

// MARK: La bannière d'un grade

/// Un changement de grade sur la ligne : la médaille, « Grade Argent atteint », « au 10ᵉ trophée ». Atteint, sur
/// le dégradé du métal (de gauche à droite, jamais retourné) à l'encre sombre ; à venir, sur le filet, en gris.
struct PaliersBanniereVue: View {
    let banniere: PaliersBanniere
    let formes: TropheeFormes

    @Environment(\.traducteur) private var traducteur

    init(banniere: PaliersBanniere, formes: TropheeFormes) {
        self.banniere = banniere
        self.formes = formes
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            TropheeObjet(formes.medaille(banniere.medaille))
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(banniere.titre, traducteur: traducteur)
                    .tropheeTexte(15, gras: true)
                Text(banniere.sous, traducteur: traducteur)
                    .tropheeTexte(13)
                    .opacity(0.85)
            }
            .foregroundStyle(encre)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            fond
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    /// L'encre d'une bannière atteinte (#1A1306, lisible sur le métal), sinon le gris de la palette.
    private var encre: AnyShapeStyle {
        if let couleur = banniere.encre {
            return AnyShapeStyle(couleur.couleurSwiftUI)
        }
        return AnyShapeStyle(Teinte(.muted))
    }

    @ViewBuilder private var fond: some View {
        if let teintes = banniere.degrade {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [teintes.clair.couleurSwiftUI, teintes.fonce.couleurSwiftUI],
                                     startPoint: UnitPoint(x: 0, y: 0.5), endPoint: UnitPoint(x: 1, y: 0.5)))
                .environment(\.layoutDirection, .leftToRight)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Teinte(.line))
        }
    }
}

// MARK: Une étape

/// Une étape de la ligne : dans une colonne de 60 × 72, le trait du métal (ou gris) et l'objet par-dessus ; à
/// côté, ce qu'il demande et le petit texte. Toucher ouvre la fiche ; VoiceOver la lit d'un trait.
struct PaliersEtapeVue: View {
    let etape: PaliersEtape
    let formes: TropheeFormes
    let ouvrirFiche: @MainActor (Trophees.Niveau) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// B : le trait a grandi.
    @State private var traitParu = false
    /// B : l'objet a paru.
    @State private var objetParu = false

    init(etape: PaliersEtape, formes: TropheeFormes, ouvrirFiche: @escaping @MainActor (Trophees.Niveau) -> Void) {
        self.etape = etape
        self.formes = formes
        self.ouvrirFiche = ouvrirFiche
    }

    var body: some View {
        let langue = traducteur.langue
        Button {
            ouvrirFiche(etape.niveau)
        } label: {
            HStack(alignment: .center, spacing: 0) {
                colonne
                    .frame(width: 60, height: 72)
                VStack(alignment: .leading, spacing: 0) {
                    Text(etape.description, traducteur: traducteur)
                        .tropheeTexte(15, gras: etape.gagne)
                        .foregroundStyle(Teinte(etape.gagne ? .ink : .muted))
                    if let sous = etape.sous {
                        Text(sous.libelle(dateLongue: { TropheeDate.longue($0, langue: langue) }),
                             traducteur: traducteur)
                            .tropheeTexte(12)
                            .foregroundStyle(Teinte(.muted))
                            .padding(.top, 4)
                    }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(TropheeAccessibilite.texte(
            etape.accessibilite(dateLongue: { TropheeDate.longue($0, langue: langue) }), traducteur))
        .task(id: etape.retardPousse) {
            await pousser()
        }
    }

    /// Le trait, puis l'objet centré par-dessus, qui se retourne s'il est neuf.
    private var colonne: some View {
        ZStack {
            trait
                .frame(width: 6, height: 72)
                .scaleEffect(x: 1, y: cache && !traitParu ? 0 : 1, anchor: .top)
            TropheeRetournement(dessin: formes.dessin(etape.niveau, metal: etape.metal),
                                cote: CGFloat(etape.coteObjet),
                                retard: etape.retardRetournement,
                                etincelles: etape.trait)
                // Un trophée devenu neuf à l'ouverture reprend de zéro : retourné, puis il se retourne.
                .id(etape.retardRetournement)
                .opacity(cache && !objetParu ? 0 : etape.opaciteObjet)
                .scaleEffect(cache && !objetParu ? 0.7 : 1)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    /// Le trait : un dégradé du métal de haut en bas, ou le gris à 0x40.
    @ViewBuilder private var trait: some View {
        if let teintes = etape.trait {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [teintes.clair.couleurSwiftUI, teintes.fonce.couleurSwiftUI],
                                     startPoint: .top, endPoint: .bottom))
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Teinte(.muted).opacity(Double(0x40) / 255))
        }
    }

    /// L'étape attend sa pousse : cachée jusqu'à son tour.
    private var cache: Bool {
        etape.retardPousse != nil && !reduire
    }

    /// B (AnimationsTrophees.pousser) : après le délai, le trait grandit depuis le haut en 0,26 s ; 0,12 s plus
    /// tard, l'objet paraît et grandit de 0,7 à 1 en 0,3 s. Interrompue, l'étape se montre telle quelle.
    private func pousser() async {
        guard let retard = etape.retardPousse, !reduire else { return }
        traitParu = false
        objetParu = false
        guard await TropheeAttente.ms(retard) else {
            traitParu = true
            objetParu = true
            return
        }
        withAnimation(.easeInOut(duration: 0.26)) {
            traitParu = true
        }
        guard await TropheeAttente.ms(120) else {
            objetParu = true
            return
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            objetParu = true
        }
    }
}

// MARK: Vous êtes ici

/// La carte « Vous êtes ici · prochain objectif » : cerclée de l'accent, l'objet gris, ce qu'il demande, la barre
/// et « 31 / 40 · encore 9 ». Toucher ouvre la fiche.
struct PaliersIciVue: View {
    let ici: PaliersIci
    let formes: TropheeFormes
    let animer: Bool
    let cleBarres: String
    let ouvrirFiche: @MainActor (Trophees.Niveau) -> Void

    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// D : la valeur montrée pendant que le compte monte ; nil, la valeur atteinte.
    @State private var compte: Int?
    /// D : la barre presque pleine pulse.
    @State private var pulse = false

    init(ici: PaliersIci, formes: TropheeFormes, animer: Bool, cleBarres: String,
         ouvrirFiche: @escaping @MainActor (Trophees.Niveau) -> Void) {
        self.ici = ici
        self.formes = formes
        self.animer = animer
        self.cleBarres = cleBarres
        self.ouvrirFiche = ouvrirFiche
    }

    var body: some View {
        Button {
            ouvrirFiche(ici.niveau)
        } label: {
            carte
        }
        .buttonStyle(.plain)
        .task(id: animer) {
            await jouer()
        }
    }

    private var carte: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(PaliersIci.titre, traducteur: traducteur)
                .tropheeTexte(13, gras: true, interlettrage: 0.06)
                .foregroundStyle(Teinte(.brand))
            HStack(alignment: .center, spacing: 0) {
                TropheeObjet(formes.dessin(ici.niveau, metal: nil))
                    .frame(width: 64, height: 64)
                    .opacity(0.9)
                VStack(alignment: .leading, spacing: 0) {
                    Text(ici.description, traducteur: traducteur)
                        .tropheeTexte(19, gras: true)
                        .foregroundStyle(Teinte(.ink))
                    TropheeBarre(fraction: Double(ici.fraction), hauteur: 10, couleur: Teinte(.brand), monte: true)
                        .id(cleBarres + "|" + ici.niveau.cle)
                        .scaleEffect(x: 1, y: pulse ? 1.8 : 1)
                        .padding(.top, 8)
                    Text(ici.encore(compte ?? ici.valeur), traducteur: traducteur)
                        .tropheeTexte(14, gras: true)
                        .foregroundStyle(Teinte(.brand))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
            }
            .padding(.top, 8)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Teinte(.brand), lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// D (AnimationsTrophees.monter, pulser) : le compte monte de 0 à la valeur en 0,7 s (décélération 1,5),
    /// sauf à zéro ; à 0,9 s, la barre presque pleine passe à 1,8 de haut en 0,3 s puis revient en 0,45 s.
    private func jouer() async {
        compte = nil
        pulse = false
        guard animer, !reduire else { return }
        let debut = Date()
        let fin = ici.valeur
        if fin > 0 {
            compte = 0
            while true {
                let t = min(Date().timeIntervalSince(debut) / 0.7, 1)
                // DecelerateInterpolator(1,5) : 1 − (1 − t)^3 ; IntEvaluator d'Android tronque.
                let f = 1 - pow(1 - t, 3)
                compte = Int(Double(fin) * f)
                if t >= 1 { break }
                guard await TropheeAttente.ms(16) else { break }
            }
            compte = nil
        }
        guard ici.pulser else { return }
        let ecoule = Int(Date().timeIntervalSince(debut) * 1000)
        guard await TropheeAttente.ms(max(900 - ecoule, 0)) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            pulse = true
        }
        guard await TropheeAttente.ms(300) else {
            pulse = false
            return
        }
        withAnimation(.easeInOut(duration: 0.45)) {
            pulse = false
        }
    }
}
