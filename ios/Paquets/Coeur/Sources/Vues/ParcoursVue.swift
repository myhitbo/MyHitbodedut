import Foundation
import SwiftUI
import Coeur
import Ecrans

/// « Mon parcours » (ParcoursActivity.kt, activity_parcours.xml) : le bandeau vert et le hassid qui loue, puis
/// quatre tuiles, la moyenne, le mois en barres sur une carte verte, les sujets les plus fréquents, et l'humeur
/// moyenne quand elle a été notée. Rien ne s'y touche. Les blocs entrent en cascade, les nombres montent et les
/// barres se remplissent à l'ouverture (Effets.kt), sauf quand on réduit les animations.
public struct ParcoursVue: View {
    private let modele: ParcoursModele
    @Environment(\.traducteur) private var traducteur
    /// La cascade d'entrée est jouée (une fois, à la première apparition).
    @State private var entreeJouee = false

    /// - Parameter modele: `ParcoursModele(magasin:horloge:)`.
    public init(modele: ParcoursModele) {
        self.modele = modele
    }

    public var body: some View {
        VStack(spacing: 0) {
            ParcoursBandeauVue(titre: Text(modele.titre, traducteur: traducteur),
                               sousTitre: Text(modele.sousTitre, traducteur: traducteur),
                               image: modele.imageBandeau)
            ScrollView {
                contenu
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .background(Teinte(.paper))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !entreeJouee {
                entreeJouee = true
            }
        }
    }

    // MARK: Le contenu

    /// Les blocs, dans l'ordre d'Android ; chacun garde son rang dans la cascade (Effets.enfants).
    private var contenu: some View {
        let tuiles = modele.tuiles
        let moyenne = modele.moyenne
        let humeur = modele.humeur
        // Les blocs présents sont numérotés à la suite : la moyenne absente ne compte pas.
        let apresMoyenne = moyenne == nil ? 2 : 3
        return VStack(alignment: .leading, spacing: 0) {
            rangee(tuiles, de: 0)
                .padding(.top, 10)
                .parcoursCascade(rang: 0, jouee: entreeJouee)
            rangee(tuiles, de: 2)
                .padding(.top, 10)
                .parcoursCascade(rang: 1, jouee: entreeJouee)
            if let moyenne {
                Text(moyenne, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .parcoursCascade(rang: 2, jouee: entreeJouee)
            }
            ParcoursTitreSection(texte: traducteur.texte(modele.titreMois), langue: traducteur.langue)
                .parcoursCascade(rang: apresMoyenne, jouee: entreeJouee)
            carteMois
                .padding(.top, 8)
                .parcoursCascade(rang: apresMoyenne + 1, jouee: entreeJouee)
            ParcoursTitreSection(texte: traducteur.texte(modele.titreSujets), langue: traducteur.langue)
                .parcoursCascade(rang: apresMoyenne + 2, jouee: entreeJouee)
            carteSujets
                .padding(.top, 8)
                .parcoursCascade(rang: apresMoyenne + 3, jouee: entreeJouee)
            if let humeur {
                ParcoursTitreSection(texte: traducteur.texte(modele.titreHumeur), langue: traducteur.langue)
                    .parcoursCascade(rang: apresMoyenne + 4, jouee: entreeJouee)
                ParcoursHumeurVue(humeur: humeur)
                    .padding(.top, 8)
                    .parcoursCascade(rang: apresMoyenne + 5, jouee: entreeJouee)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Une rangée de deux tuiles, de même largeur et de même hauteur, à 10 l'une de l'autre.
    @ViewBuilder
    private func rangee(_ tuiles: [ParcoursTuile], de debut: Int) -> some View {
        if tuiles.count >= debut + 2 {
            HStack(alignment: .top, spacing: 10) {
                ParcoursTuileVue(tuile: tuiles[debut])
                ParcoursTuileVue(tuile: tuiles[debut + 1])
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Le mois sur la carte verte : la phrase en menthe, puis les barres (décoratives : la phrase les dit).
    private var carteMois: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(modele.texteMois, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.mint))
                .padding(.bottom, 10)
            JournalGraphiqueVue(graphique: modele.graphique)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            JournalCarteVerteFond()
        }
    }

    /// Les sujets les plus fréquents, ou la phrase qui dit qu'il n'y en a pas encore.
    private var carteSujets: some View {
        let sujets = modele.sujets
        return VStack(alignment: .leading, spacing: 0) {
            if sujets.isEmpty {
                Text(modele.sujetsVide, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.vertical, 8)
            } else {
                ForEach(sujets) { sujet in
                    ParcoursSujetVue(sujet: sujet)
                }
            }
        }
        .parcoursCarte()
    }
}

// MARK: Le bandeau

/// Le bandeau (activity_parcours.xml) : le titre et le sous-titre à gauche (au début de la ligne), le hassid qui
/// loue à droite sur sa plaque menthe de 64 × 78. Marges de 24 sur les côtés, 22 en haut, 18 en bas.
struct ParcoursBandeauVue: View {
    let titre: Text
    let sousTitre: Text
    let image: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                titre
                    .font(Font.title2.bold())
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isHeader)
                sousTitre
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.mint))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Illustration(decorative: image)
                .padding(4)
                .frame(width: 64, height: 78)
                .background(Teinte(.mint), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .background {
            JournalBandeauFond()
        }
    }
}

// MARK: Une tuile

/// Une tuile : la pastille de la couleur de son anneau, le chiffre en grand et son unité, puis ce qu'il compte.
/// VoiceOver la lit d'un trait, avec la valeur atteinte (et non celle qui monte).
struct ParcoursTuileVue: View {
    let tuile: ParcoursTuile
    @Environment(\.traducteur) private var traducteur
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(couleurPastille)
                .frame(width: 22, height: 5)
                .padding(.bottom, 10)
            HStack(alignment: .bottom, spacing: 0) {
                valeur
                    .font(Font.title.bold())
                    .foregroundStyle(Teinte(.ink))
                    .lineLimit(1)
                if let unite = tuile.unite {
                    Text(verbatim: " " + traducteur.texte(unite))
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.muted))
                        .padding(.bottom, 5)
                }
            }
            Text(tuile.libelle, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Teinte(.line), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: lecture))
    }

    @ViewBuilder
    private var valeur: some View {
        switch tuile.valeur {
        case .nombre(let n):
            ParcoursCompteVue(fin: n)
        case .duree(let libelle):
            Text(libelle, traducteur: traducteur)
        }
    }

    /// La couleur de la pastille : le jeton `brand`, ou la couleur fixe de l'anneau (ring_streak, ring_week).
    private var couleurPastille: Color {
        if let jeton = tuile.teinte.jeton {
            return palette.couleur(jeton, schema: schema)
        }
        if let couleur = tuile.teinte.couleur(nuit: schema == .dark) {
            return Color(couleur)
        }
        return Color.clear
    }

    /// « 12 jours, Série actuelle ».
    private var lecture: String {
        var morceaux: [String] = []
        switch tuile.valeur {
        case .nombre(let n):
            morceaux.append(String(n))
        case .duree(let libelle):
            morceaux.append(traducteur.texte(libelle))
        }
        if let unite = tuile.unite {
            morceaux.append(traducteur.texte(unite))
        }
        return morceaux.joined(separator: " ") + ", " + traducteur.texte(tuile.libelle)
    }
}

/// Un nombre qui monte de 0 à sa valeur en 0,7 s après 0,12 s (Effets.compte), sur la courbe de l'app ; rien ne
/// bouge à zéro, ni quand on réduit les animations.
struct ParcoursCompteVue: View {
    let fin: Int
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    /// La valeur montrée pendant que le compte monte ; nil, la valeur atteinte.
    @State private var compte: Int? = nil
    @State private var joue = false

    var body: some View {
        Text(verbatim: String(compte ?? fin))
            .monospacedDigit()
            .task {
                await monter()
            }
    }

    private func monter() async {
        guard !joue else { return }
        joue = true
        guard !reduireAnimations, fin > 0 else { return }
        compte = 0
        let courbe = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.8),
                                      endControlPoint: UnitPoint(x: 0.2, y: 1))
        do {
            try await Task.sleep(for: .milliseconds(120))
            let debut = Date()
            while true {
                let t = min(Date().timeIntervalSince(debut) / 0.7, 1)
                // IntEvaluator d'Android : la valeur est tronquée.
                compte = Int(Double(fin) * courbe.value(at: t))
                if t >= 1 { break }
                try await Task.sleep(for: .milliseconds(16))
            }
        } catch {
            // L'écran est parti : la valeur atteinte s'affiche.
        }
        compte = nil
    }
}

// MARK: Un sujet

/// Un sujet fréquent : son nom et le nombre de fois, puis sa barre (piste `line`, part remplie `brand`), qui part
/// du début de la ligne et se remplit à l'ouverture en 0,7 s après 0,3 s (Effets.remplir).
struct ParcoursSujetVue: View {
    let sujet: ParcoursSujet
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations
    @State private var rempli = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(sujet.nom, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(sujet.fois, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            barre
                .padding(.top, 6)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .onAppear {
            if !rempli {
                rempli = true
            }
        }
    }

    private var barre: some View {
        let part = (rempli || reduireAnimations) ? sujet.partDessinee : 0
        return GeometryReader { geometrie in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Teinte(.line))
                    .frame(maxWidth: .infinity)
                Capsule()
                    .fill(Teinte(.brand))
                    .frame(width: geometrie.size.width * CGFloat(part))
            }
        }
        .frame(height: 8)
        .animation(reduireAnimations ? nil
                   : Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7).delay(0.3),
                   value: rempli)
        .accessibilityHidden(true)
    }
}

// MARK: L'humeur

/// L'humeur moyenne : « 😐  →  😄 » en grand, puis sa légende en deux morceaux joints par « · ».
struct ParcoursHumeurVue: View {
    let humeur: ParcoursHumeur
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: humeur.texte)
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            Text(verbatim: humeur.legende.map { traducteur.texte($0) }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Teinte(.muted))
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .parcoursCarte()
        .accessibilityElement(children: .combine)
    }
}

// MARK: Les titres et les cartes

/// Un titre de section : en capitales, crénage de 0,08 em, 12 en gris, 22 au-dessus, 4 sur les côtés.
struct ParcoursTitreSection: View {
    let texte: String
    let langue: String

    var body: some View {
        Text(verbatim: texte.uppercased(with: Locale(identifier: langue)))
            .font(.caption)
            .tracking(0.96)
            .foregroundStyle(Teinte(.muted))
            .padding(.horizontal, 4)
            .padding(.top, 22)
            .accessibilityAddTraits(.isHeader)
    }
}

/// La carte des sujets et de l'humeur (bg_card.xml) : fond `card`, filet `line`, coins de 20, 16 × 8 de marge.
private struct ParcoursCarte: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Teinte(.card), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Teinte(.line), lineWidth: 1)
            }
    }
}

/// L'entrée en cascade (Effets.enfants) : chaque bloc part 14 points plus bas, effacé, et arrive en 420 ms, après
/// 60 ms et 45 ms de plus par rang (au plus 8 rangs). Tout de suite en place quand on réduit les animations.
private struct ParcoursCascade: ViewModifier {
    let rang: Int
    let jouee: Bool
    @Environment(\.accessibilityReduceMotion) private var reduireAnimations

    private var visible: Bool {
        jouee || reduireAnimations
    }

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 14)
            .animation(reduireAnimations ? nil
                       : Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.42)
                           .delay(0.06 + 0.045 * Double(min(rang, 8))),
                       value: visible)
    }
}

extension View {
    fileprivate func parcoursCarte() -> some View {
        modifier(ParcoursCarte())
    }

    fileprivate func parcoursCascade(rang: Int, jouee: Bool) -> some View {
        modifier(ParcoursCascade(rang: rang, jouee: jouee))
    }
}
