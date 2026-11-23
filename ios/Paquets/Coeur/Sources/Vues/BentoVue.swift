import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'accueil Bento (BentoActivity.kt, maquette « E · Bento — tuiles qui s'ouvrent ») : un tableau de bord en tuiles,
/// sans barre d'onglets. En tête, la date et la salutation, et la pastille du hassid (les réglages) ; puis la
/// hitbodedout et l'anneau de la semaine, la série en barres et le prochain zman, le 'hizouk, l'ambiance et son
/// égaliseur, la dernière note, le Siddour et Tehilim. Chaque tuile ouvre son écran ; la recherche reste en bas,
/// sous le pouce. Police : Heebo. Les tuiles entrent en cascade à la première ouverture (sauf « Réduire les
/// animations »). La vue lit `AccueilVersionModele.bento`.
struct BentoVue: View {
    let modele: AccueilVersionModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    /// Les rangées entrées : à la première ouverture, elles paraissent l'une après l'autre ; toutes ensuite.
    @State private var entrees = -1
    @State private var cascadeFaite = false

    var body: some View {
        let e = modele.bento
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    rang(0) { entete(e) }
                    rang(1) { tuileHitbodedout(e.hitbodedout) }
                    rang(2) {
                        rangee(tuileSerie(e.serie), tuileZmanim(e.zmanim))
                    }
                    rang(3) { tuileHizouk(e.pensee) }
                    rang(4) {
                        rangee(tuileAmbiance(e.ambiance), tuileJournal(e.journal))
                    }
                    rang(5) {
                        rangee(petiteTuile(Libelle("bento_siddour")) { modele.ouvrirSiddour() },
                               petiteTuile(Libelle("bento_tehilim")) { modele.ouvrirTehilim() })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            recherche
        }
        .background(Bento.fond.ignoresSafeArea())
        .onAppear {
            // Les tuiles entrent en cascade à la première ouverture seulement (maquette : +80 ms chacune).
            guard !cascadeFaite else { return }
            cascadeFaite = true
            guard !reduire else {
                entrees = Int.max
                return
            }
            Task { @MainActor in
                for i in 0..<6 {
                    withAnimation(.easeOut(duration: 0.5)) { entrees = i }
                    guard await AccueilAttente.ms(AccueilVersionModele.ecartCascade) else { break }
                }
                entrees = Int.max
            }
        }
    }

    /// Une rangée de la cascade : transparente et 10 pt plus bas tant qu'elle n'est pas entrée.
    private func rang<Contenu: View>(_ i: Int, @ViewBuilder _ contenu: () -> Contenu) -> some View {
        contenu()
            .opacity(i <= entrees ? 1 : 0)
            .offset(y: i <= entrees ? 0 : 10)
    }

    // MARK: En-tête et recherche

    private func entete(_ e: BentoEcran) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: VersionEcrit.ligne(e.ligneDate, traducteur))
                    .font(VersionPolice.heebo(14))
                    .foregroundStyle(Bento.doux)
                // Bonjour le matin, bonsoir le soir (Salutation) ; sans prénom, « Votre journée ».
                Text(e.titre, traducteur: traducteur)
                    .font(VersionPolice.heebo(28, .black))
                    .foregroundStyle(Bento.encre)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // La pastille du hassid ouvre les réglages, comme l'avatar d'un compte.
            Button {
                modele.ouvrirReglages()
            } label: {
                Illustration(decorative: "char_welcome")
                    .frame(width: 48, height: 48, alignment: .bottom)
                    .background(Bento.citron)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(VersionPression())
            .accessibilityLabel(Text(Libelle("version_reglages"), traducteur: traducteur))
        }
        .padding(.leading, 4)
        .padding(.bottom, 2)
    }

    private var recherche: some View {
        Button {
            modele.ouvrirRecherche()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Bento.doux)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text(Libelle("bento_recherche"), traducteur: traducteur)
                    .font(VersionPolice.heebo(15))
                    .foregroundStyle(Bento.doux)
                    .lignesAuPlus(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(Bento.blanc))
            .contentShape(Capsule())
        }
        .buttonStyle(VersionPression(echelle: 0.98))
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .accessibilityIdentifier("barre-bas")
    }

    // MARK: Les tuiles

    /// Une tuile : arrondie, qui s'enfonce un peu sous le doigt.
    private func tuile<Contenu: View>(_ fond: Color, _ hauteur: CGFloat, action: @escaping @MainActor () -> Void,
                                      @ViewBuilder contenu: () -> Contenu) -> some View {
        Button(action: action) {
            // La hauteur de la maquette, et plus si le texte agrandi ne tient plus (TuileExtensible).
            TuileExtensible(minimum: hauteur - 32) {
                contenu()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(fond)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(VersionPression())
    }

    /// Deux tuiles côte à côte ; l'une sous l'autre aux tailles d'accessibilité.
    private func rangee<A: View, B: View>(_ a: A, _ b: B) -> some View {
        RangeeAdaptable(alignement: .top, espacement: 10) {
            a.frame(maxWidth: .infinity)
            b.frame(maxWidth: .infinity)
        }
    }

    private func tuileHitbodedout(_ h: BentoHitbodedout) -> some View {
        tuile(Bento.vert, 208, action: { modele.commencerSeance() }) {
            Illustration(decorative: "char_debout")
                .frame(width: 130, height: 180, alignment: .bottomTrailing)
                .offset(x: 14, y: 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .roleDansTuile(.decor)
            BentoAnneau(faits: h.faits, dus: h.dus, fraction: h.fraction)
                .frame(width: 72, height: 72)
                .accessibilityLabel(Text(h.accessibiliteAnneau, traducteur: traducteur))
            VStack(alignment: .leading, spacing: 10) {
                Text(h.titre, traducteur: traducteur)
                    .font(VersionPolice.heebo(22, .bold))
                    .foregroundStyle(Bento.blanc)
                Text(h.bouton, traducteur: traducteur)
                    .font(VersionPolice.heebo(15, .bold))
                    .foregroundStyle(Bento.vert)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Bento.citron))
            }
            .frame(maxWidth: 210, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .roleDansTuile(.bas)
        }
        .accessibilityElement(children: .combine)
    }

    private func tuileSerie(_ s: BentoSerie) -> some View {
        tuile(Bento.blanc, 150, action: { modele.ouvrirParcours() }) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: String(s.nombre))
                    .font(VersionPolice.heebo(44, .black))
                    .foregroundStyle(Bento.encre)
                Text(s.jours, traducteur: traducteur)
                    .font(VersionPolice.heebo(13))
                    .foregroundStyle(Bento.doux)
            }
            BentoBarres(faits: s.barres)
                .frame(height: 36)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .accessibilityHidden(true)
                .roleDansTuile(.bas)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(s.accessibilite, traducteur: traducteur))
        .accessibilityAddTraits(.isButton)
    }

    private func tuileZmanim(_ z: BentoZmanim) -> some View {
        tuile(Bento.bleuFond, 150, action: { modele.ouvrirZmanim() }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(z.etiquette, traducteur: traducteur)
                    .font(VersionPolice.heebo(13))
                    .foregroundStyle(Bento.bleuDoux)
                    .lignesAuPlus(2)
                Text(z.valeur, traducteur: traducteur)
                    .font(VersionPolice.heebo(z.compte ? 26 : 20, .black))
                    .foregroundStyle(Bento.bleuEncre)
                    .uneLigne(retrecie: 0.7)
            }
            if let chkia = z.chkia {
                Text(verbatim: traducteur.texte(chkia.nom) + " " + chkia.heure)
                    .font(VersionPolice.heebo(13))
                    .foregroundStyle(Bento.bleuDoux)
                    .lignesAuPlus(1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .roleDansTuile(.bas)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: z.accessibilite.map { traducteur.texte($0) }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }

    private func tuileHizouk(_ pensee: VersionPensee?) -> some View {
        tuile(Bento.creme, 124, action: { modele.ouvrirChizuk() }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Libelle("pile_hizouk"), traducteur: traducteur)
                    .font(VersionPolice.heebo(12, .bold))
                    .textCase(.uppercase)
                    .tracking(1.9)
                    .foregroundStyle(Bento.cremeAccent)
                if let pensee {
                    VersionHebreu(texte: pensee.hebreu, taille: 19, couleur: Bento.cremeEncre, police: modele.police,
                                  lignes: 2)
                } else {
                    Text(Libelle("version_chargement"), traducteur: traducteur)
                        .font(VersionPolice.heebo(15))
                        .foregroundStyle(Bento.cremeEncre)
                        .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tuileAmbiance(_ a: BentoAmbiance) -> some View {
        tuile(Bento.nuit, 124, action: { modele.ouvrirMusique() }) {
            VStack(alignment: .leading, spacing: 2) {
                Text(a.etiquette, traducteur: traducteur)
                    .font(VersionPolice.heebo(13))
                    .foregroundStyle(Bento.nuitDoux)
                Text(verbatim: VersionEcrit.chaine(a.nom, traducteur))
                    .font(VersionPolice.heebo(17, .bold))
                    .foregroundStyle(Bento.nuitEncre)
                    .lignesAuPlus(2)
            }
            BentoEgaliseur(joue: a.joue)
                .frame(width: 46, height: 34)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .accessibilityHidden(true)
                .roleDansTuile(.bas)
        }
        .accessibilityElement(children: .combine)
    }

    private func tuileJournal(_ j: BentoJournal) -> some View {
        tuile(Bento.blanc, 124, action: { modele.ouvrirJournal() }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: quand(j))
                    .font(VersionPolice.heebo(13))
                    .foregroundStyle(Bento.doux)
                    .lignesAuPlus(1)
                Text(verbatim: VersionEcrit.chaine(j.texte, traducteur))
                    .font(VersionPolice.heebo(15))
                    .foregroundStyle(j.ecrite ? Bento.encre : Bento.doux)
                    .lignesAuPlus(3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// « Journal · hier, 20 min » : le jour en minuscules (`lowercase()`), ou « Journal ».
    private func quand(_ j: BentoJournal) -> String {
        guard let jour = j.quand, let duree = j.duree else { return traducteur.texte(Libelle("pile_journal")) }
        let locale = Locale(identifier: Traducteur.identifiantLocale(traducteur.langue))
        let minuscules = VersionEcrit.chaine(jour, traducteur).lowercased(with: locale)
        return traducteur.texte(Libelle("bento_journal_quand", .texte(minuscules), .libelle(duree)))
    }

    private func petiteTuile(_ titre: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        tuile(Bento.blanc, 64, action: action) {
            Text(titre, traducteur: traducteur)
                .font(VersionPolice.heebo(16, .bold))
                .foregroundStyle(Bento.encre)
                .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}

/// Les couleurs de la maquette Bento.
enum Bento {
    static let fond = VersionCouleur.argb(0xFFF2F2EF)
    static let blanc = VersionCouleur.argb(0xFFFFFFFF)
    static let encre = VersionCouleur.argb(0xFF121614)
    static let doux = VersionCouleur.argb(0xFF555B57)
    static let citron = VersionCouleur.argb(0xFFD9F56B)
    static let vert = VersionCouleur.argb(0xFF123B30)
    static let vertClair = VersionCouleur.argb(0xFF24574A)
    static let grisBarre = VersionCouleur.argb(0xFFDADDD8)
    static let bleuFond = VersionCouleur.argb(0xFFE6ECF8)
    static let bleuEncre = VersionCouleur.argb(0xFF16233F)
    static let bleuDoux = VersionCouleur.argb(0xFF3C4A69)
    static let creme = VersionCouleur.argb(0xFFFFF4DE)
    static let cremeEncre = VersionCouleur.argb(0xFF2B2118)
    static let cremeAccent = VersionCouleur.argb(0xFF8A4B14)
    static let nuit = VersionCouleur.argb(0xFF1B1C1F)
    static let nuitEncre = VersionCouleur.argb(0xFFF2F2EF)
    static let nuitDoux = VersionCouleur.argb(0xFFB9BCB6)
}

// MARK: - Les aperçus vivants

/// L'anneau de la semaine (BentoActivity.Anneau) : « 4/6 » au centre ; l'arc se trace en 1,2 s, 300 ms après
/// l'ouverture.
private struct BentoAnneau: View {
    let faits: Int
    let dus: Int
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var part: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Bento.vertClair, lineWidth: 7)
            Circle()
                .trim(from: 0, to: reduire ? fraction : part)
                .stroke(Bento.citron, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: "\(faits)/\(dus)")
                .font(VersionPolice.heebo(16, .bold))
                .foregroundStyle(Bento.blanc)
                .environment(\.layoutDirection, .leftToRight)
        }
        .padding(4)
        .task(id: fraction) {
            guard !reduire else { return }
            part = 0
            guard await AccueilAttente.ms(300) else { return }
            withAnimation(.easeInOut(duration: 1.2)) { part = fraction }
        }
    }
}

/// Les sept jours de la semaine en barres (BentoActivity.Barres) : un jour fait monte haut, un jour vide reste bas ;
/// elles poussent en 700 ms.
private struct BentoBarres: View {
    let faits: [Bool]
    @Environment(\.accessibilityReduceMotion) private var reduire
    @State private var pousse: Double = 0

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(faits.enumerated()), id: \.offset) { _, fait in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fait ? Bento.vert : Bento.grisBarre)
                        .frame(height: geo.size.height * (fait ? 1 : 0.3) * (reduire ? 1 : pousse))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            guard !reduire else { return }
            withAnimation(.easeOut(duration: 0.7)) { pousse = 1 }
        }
    }
}

/// L'égaliseur de l'ambiance (BentoActivity.Egaliseur) : cinq barres qui dansent tant qu'une musique ou une ambiance
/// est choisie, chacune à sa période ; immobiles et basses sinon, ou avec « Réduire les animations ».
private struct BentoEgaliseur: View {
    let joue: Bool
    @Environment(\.accessibilityReduceMotion) private var reduire

    private static let periodes: [Double] = [900, 1200, 800, 1100, 950]
    private static let decalages: [Double] = [0, 200, 100, 300, 150]

    var body: some View {
        let anime = joue && !reduire
        TimelineView(.animation(minimumInterval: nil, paused: !anime)) { contexte in
            Canvas { c, taille in
                let t = contexte.date.timeIntervalSinceReferenceDate * 1000
                for i in 0..<BentoEgaliseur.periodes.count {
                    let periode = BentoEgaliseur.periodes[i]
                    let phase = (t + BentoEgaliseur.decalages[i]).truncatingRemainder(dividingBy: periode) / periode
                    let h = anime ? taille.height * (0.3 + 0.7 * (0.5 - 0.5 * cos(phase * 2 * .pi)))
                        : taille.height * 0.3
                    let x = CGFloat(i) * (6 + 4)
                    c.fill(Path(roundedRect: CGRect(x: x, y: taille.height - h, width: 6, height: h), cornerRadius: 3),
                           with: .color(Bento.citron))
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
