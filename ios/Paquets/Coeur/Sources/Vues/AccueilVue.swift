import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le Jour (refonte d'Android du 13/11, le panneau main_scroll d'activity_main.xml) : l'en-tête (la date hébraïque
/// vers les zmanim, la roue vers les réglages), la salutation et l'état du jour, les trois anneaux autour du hassid et
/// leur légende, le grade et le prochain trophée, la bande de la semaine, le mot de relance, « Écrire une note »,
/// « Préparer la séance », « Je l'ai faite sans le téléphone », puis les cartes du moment (les rappels de la tefila,
/// la prière de l'heure, Birkat haLevana, la source du jour). La barre de départ (« Commencer » et la flèche du volet
/// de la séance : durée, sujet, musique, barrière) est posée par la racine au bas des trois onglets.
///
/// La vue ne décide rien : elle lit `AccueilModele` (testé sous Linux) et appelle ses actions ; les écrans qu'il
/// demande (`routes`) sont ouverts par la pile de l'onglet (ios/App). Les animations suivent ce que le modèle dit
/// (remplissage, retour au hassid, fête d'un anneau) ; « Réduire les animations » les coupe.
public struct AccueilVue: View {
    private let modele: AccueilModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.accessibilityReduceMotion) private var reduire
    @Environment(\.scenePhase) private var phase
    @Environment(\.tropheeFormes) private var formes
    @Environment(\.dynamicTypeSize) private var tailleTexte
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema
    /// La place de l'écran : couché, ou debout sur l'iPad, le Jour se met en deux colonnes (GrandEcran.deuxColonnes).
    @State private var taille: CGSize = .zero
    /// La hauteur du premier écran, sous la barre d'état et au-dessus de la barre de départ : le ciel y descend
    /// jusqu'aux collines (CielPageVue).
    @State private var hauteurVue: CGFloat = 0

    /// La barre de départ et son volet sont posés par la racine sur les trois onglets (`BarreDepart`,
    /// `feuilleDepart`), comme la fiche des trophées neufs (`feteDesTrophees`).
    public init(modele: AccueilModele) {
        self.modele = modele
    }

    public var body: some View {
        // Le ciel du Jour suit le vrai soleil : revu chaque minute (MainActivity.veilleCiel).
        TimelineView(.everyMinute) { _ in
            defilement(modele.etatCiel)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: Bindable(modele).bilanLie) {
            if let bilan = modele.bilan {
                AccueilBilanVue(bilan: bilan) { modele.fermerBilan() }
                    .hauteursDeFeuille([.medium])
            }
        }
        .overlay(alignment: .bottom) {
            if let message = modele.message {
                AccueilMessage(texte: Text(message, traducteur: traducteur))
                    .padding(.bottom, 96)
                    .transition(.opacity)
            }
        }
        .task(id: modele.message) {
            guard modele.message != nil else { return }
            // Un Toast court d'Android : 2 s.
            if await AccueilAttente.ms(2_000) { modele.messageMontre() }
        }
        // Un palier neuf : sa phrase en bandeau, un Toast long d'Android (3,5 s) (Celebrations.ecran).
        .overlay(alignment: .bottom) {
            if modele.message == nil, let palier = modele.fete.palier {
                AccueilMessage(texte: Text(palier, traducteur: traducteur))
                    .padding(.bottom, 96)
                    .transition(.opacity)
            }
        }
        .task(id: modele.fete.palier) {
            guard modele.fete.palier != nil else { return }
            if await AccueilAttente.ms(3_500) { modele.fete.palierMontre() }
        }
        .onAppear {
            modele.reduireAnimations = reduire
            Task { await modele.apparaitre() }
        }
        .onChange(of: reduire) { _, oui in
            modele.reduireAnimations = oui
        }
        .onChange(of: phase) { _, nouvelle in
            // onResume d'Android : le retour au premier plan relit tout.
            if nouvelle == .active { Task { await modele.apparaitre() } }
        }
    }

    /// La page qui défile, sur le ciel du moment (CielPageVue) ; le papier uni avec « Contraste élevé ». Au-delà du
    /// contenu (le rebond du haut, le dessous de la barre de départ), le haut du ciel et son sol.
    private func defilement(_ etat: EtatCiel) -> some View {
        let sombre = schema == .dark
        let teintes = CielDuJourTeintes.teintes(etat, palette: palette, sombre: sombre)
        let fond: AnyShapeStyle
        if let t = teintes {
            fond = AnyShapeStyle(LinearGradient(stops: [
                Gradient.Stop(color: CielCouleur.couleur(t.haut), location: 0),
                Gradient.Stop(color: CielCouleur.couleur(t.haut), location: 0.5),
                Gradient.Stop(color: CielCouleur.couleur(t.collinePres), location: 0.5),
                Gradient.Stop(color: CielCouleur.couleur(t.collinePres), location: 1),
            ], startPoint: .top, endPoint: .bottom))
        } else {
            fond = AnyShapeStyle(Teinte(.paper))
        }
        return ScrollView {
            Group {
                if GrandEcran.deuxColonnes(largeur: Double(taille.width), hauteur: Double(taille.height),
                                           texteAccessible: tailleTexte.isAccessibilitySize) {
                    // Couché (layout-land/activity_main.xml), ou debout sur l'iPad : les anneaux à part, au début de
                    // la ligne (à droite en hébreu), l'en-tête, la semaine et la suite à côté d'eux. Chaque colonne
                    // est un conteneur d'accessibilité : VoiceOver lit l'une, puis l'autre, et non ligne à ligne.
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 0) {
                            anneaux
                        }
                        .frame(width: 300)
                        .accessibilityElement(children: .contain)
                        VStack(alignment: .leading, spacing: 0) {
                            tete
                            suite
                        }
                        .accessibilityElement(children: .contain)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        tete
                        anneaux
                        suite
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            // Le ciel couvre au moins le premier écran, même quand la page est courte (l'iPad).
            .frame(minHeight: hauteurVue, alignment: .top)
            .backgroundPreferenceValue(PlanDuCielCle.self) { plan in
                if let teintes {
                    // De gauche à droite quelle que soit la langue : le soleil se lève à gauche, comme sur Android.
                    // Les ancres des textes et des anneaux se lisent dans ce même repère.
                    GeometryReader { g in
                        CielPageVue(etat: etat, teintes: teintes, sombre: sombre,
                                    jauge: plan.jauge.map { AccueilVue.zone(g[$0]) },
                                    zones: plan.zones.map { AccueilVue.zone(g[$0]) },
                                    largeur: Double(g.size.width), hauteur: Double(g.size.height),
                                    hauteurVue: Double(hauteurVue))
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
        .onGeometryChange(for: CGSize.self, of: { $0.size }) { nouvelle in
            taille = nouvelle
        }
        // Le premier écran : ce qui se voit du contenu entre la barre d'état et la barre de départ, au-dessus de la
        // barre d'onglets (le bas des collines). C'est la taille du conteneur du défilement, déjà sans les marges qu'il
        // laisse à son contenu (la zone sûre, la barre de départ) : les retirer encore les comptait deux fois (relevé
        // des captures du 25/11 : conteneur de 655 points, marges de 62 et 157, sur un écran de 874 ; les collines
        // passaient au milieu des anneaux).
        .onScrollGeometryChange(for: CGFloat.self, of: { geometrie in
            geometrie.containerSize.height
        }, action: { _, nouvelle in
            hauteurVue = max(nouvelle, 0)
        })
        .background(fond)
    }

    /// Un rectangle de la page, pour le plan du ciel.
    static func zone(_ r: CGRect) -> PlanCiel.Zone {
        PlanCiel.Zone(gauche: Double(r.minX), haut: Double(r.minY), droite: Double(r.maxX), bas: Double(r.maxY))
    }

    /// L'en-tête (la date hébraïque, la roue) et l'état du jour.
    @ViewBuilder private var tete: some View {
        EnteteJour(modele: modele)
        AccueilEtatVue(modele: modele)
    }

    /// Les anneaux autour du hassid, leur légende et la ligne du prochain trophée.
    @ViewBuilder private var anneaux: some View {
        AccueilAnneauxVue(modele: modele)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
        Text(modele.legende, traducteur: traducteur)
            .font(.callout)
            .foregroundStyle(AccueilTeintes.style(modele.couleurLegende))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .zoneDuCiel()
            .padding(.top, 4)
        ligneTrophee
    }

    /// La bande de la semaine, le mot de relance, les boutons du jour et les cartes du moment.
    @ViewBuilder private var suite: some View {
        AccueilSemaineVue(modele: modele)
            .zoneDuCiel()
            .padding(.top, 16)
        if let relance = modele.relance {
            ChizukCarteVue(carte: relance)
                .zoneDuCiel()
                .padding(.top, 12)
        }
        boutonsDuJour
        ForEach(modele.cartes) { carte in
            AccueilCarteVue(carte: carte, police: modele.police) { route in
                modele.ouvrir(route)
            }
            .zoneDuCiel()
            .padding(.top, 14)
        }
    }

    /// Le grade et le prochain trophée (paliers_line) : touché, il ouvre les paliers.
    private var ligneTrophee: some View {
        let ligne = modele.ligneTrophee
        return Button {
            modele.ouvrirPaliers()
        } label: {
            HStack(spacing: 8) {
                // La médaille du grade, frappée de l'étoile (TropheeDessin MEDAILLE, 26 pt) ; un palier neuf y fait
                // jaillir les étincelles du grade.
                TropheeObjet(formes?.medaille(ligne.grade))
                    .frame(width: 26, height: 26)
                    .overlay { TropheeFetePalier(fete: modele.fete) }
                Text(ligne.texte, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
                    .multilineTextAlignment(.center)
                Image(systemName: "chevron.forward")
                    .font(.caption.bold())
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: ligne.accessibilite.map { traducteur.texte($0) }.joined(separator: ". ")))
        .zoneDuCiel()
        .padding(.top, 4)
    }

    /// « Écrire une note » (un jour fait), « Préparer la séance », « Je l'ai faite sans le téléphone » : des boutons
    /// texte, toute la largeur.
    private var boutonsDuJour: some View {
        VStack(spacing: 4) {
            if let note = modele.libelleNote {
                boutonTexte(note) { modele.ecrireNote() }
            }
            boutonTexte(modele.libellePreparer) { modele.preparer() }
            if let horsTelephone = modele.libelleHorsTelephone {
                boutonTexte(horsTelephone) { modele.declarerHorsTelephone() }
            }
        }
        .padding(.top, 8)
    }

    private func boutonTexte(_ libelle: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Text(libelle, traducteur: traducteur)
                .font(Font.subheadline.weight(.medium))
                .foregroundStyle(Teinte(.brand))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .zoneDuCiel()
    }
}

// MARK: - Les liaisons des feuilles

extension AccueilModele {
    /// Le volet ou une boîte : la feuille baissée d'un geste ferme l'un et l'autre.
    var feuilleLiee: Bool {
        get { feuilleOuverte }
        set { if !newValue { fermerFeuille() } }
    }

    /// Le bilan de la semaine : le baisser d'un geste vaut « Continuer ».
    var bilanLie: Bool {
        get { bilan != nil }
        set { if !newValue { fermerBilan() } }
    }
}

extension TextesModele {
    /// L'interrupteur de la musique (music_switch_main), dans le volet.
    var musiqueLiee: Bool {
        get { musiqueActive }
        set {
            let oui = newValue
            Task { try? await self.basculerMusique(oui) }
        }
    }
}

// MARK: - Les couleurs et les dates

/// Les couleurs de l'accueil : les jetons de la palette, et les couleurs fixes de res/values/colors.xml que la palette
/// n'a pas (les anneaux de la semaine et de la série, le jour exempté), de jour et de nuit (values-night).
enum AccueilTeintes {
    static func style(_ couleur: AccueilCouleur) -> AnyShapeStyle {
        switch couleur {
        case .brand: AnyShapeStyle(Teinte(.brand))
        case .ink: AnyShapeStyle(Teinte(.ink))
        case .muted: AnyShapeStyle(Teinte(.muted))
        case .white: AnyShapeStyle(Color.white)
        case .ringWeek: AnyShapeStyle(AccueilFixe(jour: 0x2E7DB3, nuit: 0x6FB7E8))
        case .ringStreak: AnyShapeStyle(AccueilFixe(jour: 0xB8780F, nuit: 0xE8B45C))
        // Les encres de texte des anneaux (ring_week_text, ring_streak_text), pour la légende posée sur le ciel.
        case .ringWeekText: AnyShapeStyle(AccueilFixe(jour: 0x256A9A, nuit: 0x6FB7E8))
        case .ringStreakText: AnyShapeStyle(AccueilFixe(jour: 0x8A5A00, nuit: 0xE8B45C))
        }
    }

    /// La couleur concrète d'un anneau, pour le dessin.
    static func anneau(_ quel: Anneaux.Quel, palette: PaletteApp, schema: ColorScheme) -> Color {
        switch quel {
        case .jour: palette.couleur(.brand, schema: schema)
        case .semaine: AccueilFixe.couleur(schema == .dark ? 0x6FB7E8 : 0x2E7DB3)
        case .serie: AccueilFixe.couleur(schema == .dark ? 0xE8B45C : 0xB8780F)
        }
    }
}

/// Une couleur fixe de colors.xml, de jour et de nuit.
struct AccueilFixe: ShapeStyle {
    let jour: Int
    let nuit: Int

    func resolve(in environment: EnvironmentValues) -> Color {
        AccueilFixe.couleur(environment.colorScheme == .dark ? nuit : jour)
    }

    static func couleur(_ hex: Int) -> Color {
        Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

/// Les dates écrites dans la langue de l'app, au calendrier grégorien (DateTimeFormatter.ofPattern d'Android).
enum AccueilDate {
    static func texte(_ jour: JourCivil, langue: String, motif: String? = nil, style: DateFormatter.Style = .full) -> String {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .gmt
        // Midi : aucun changement d'heure ne fait glisser le jour.
        let composantes = DateComponents(year: jour.annee, month: jour.mois, day: jour.jour, hour: 12)
        guard let date = calendrier.date(from: composantes) else { return jour.iso }
        let format = DateFormatter()
        format.calendar = calendrier
        format.timeZone = .gmt
        format.locale = Locale(identifier: Traducteur.identifiantLocale(langue))
        if let motif {
            format.dateFormat = motif
        } else {
            format.dateStyle = style
            format.timeStyle = .none
        }
        return format.string(from: date)
    }

    /// Le jour en toutes lettres, majuscule initiale (« EEEE » puis `replaceFirstChar { titlecase }`).
    static func jourSemaine(_ jour: JourCivil, langue: String) -> String {
        let brut = texte(jour, langue: langue, motif: "EEEE")
        guard let premier = brut.first else { return brut }
        return String(premier).uppercased() + brut.dropFirst()
    }
}

/// Une attente dans la suite d'une animation ; faux si la vue est partie entre-temps (la tâche est annulée).
enum AccueilAttente {
    static func ms(_ millisecondes: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(max(millisecondes, 0)))
            return true
        } catch {
            return false
        }
    }
}

/// Un texte de l'accueil : une chaîne du catalogue, ou un texte tel quel.
struct AccueilTexteVue {
    static func texte(_ t: AccueilTexte, _ traducteur: Traducteur) -> Text {
        switch t {
        case .libelle(let libelle): Text(libelle, traducteur: traducteur)
        case .brut(let brut): Text(verbatim: brut)
        }
    }

    static func chaine(_ t: AccueilTexte, _ traducteur: Traducteur) -> String {
        switch t {
        case .libelle(let libelle): traducteur.texte(libelle)
        case .brut(let brut): brut
        }
    }
}

// MARK: - L'état du jour

/// La salutation (26 pt gras), l'état du jour (le titre sans prénom), la série et le total, le détail d'un jour fait.
private struct AccueilEtatVue: View {
    let modele: AccueilModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let salutation = modele.salutation {
                Text(salutation, traducteur: traducteur)
                    .tailleSp(26, poids: .bold, relativeA: .title)
                    .foregroundStyle(Teinte(.ink))
                    // Toute la largeur, comme le texte d'Android (match_parent), pour le plan du ciel.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .zoneDuCiel()
            }
            if modele.etatEstTitre {
                Text(modele.titreEtat, traducteur: traducteur)
                    .tailleSp(20, poids: .bold, relativeA: .title3)
                    .foregroundStyle(Teinte(.ink))
                    // Toute la largeur, comme le texte d'Android (match_parent), pour le plan du ciel.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .zoneDuCiel()
            } else {
                Text(modele.titreEtat, traducteur: traducteur)
                    .policeHebraique(.arrondie, taille: 15, relativeA: .subheadline)
                    .foregroundStyle(Teinte(.muted))
                    // Toute la largeur, comme le texte d'Android (match_parent), pour le plan du ciel.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .zoneDuCiel()
            }
            // La série et le total côte à côte ; l'un sous l'autre aux tailles d'accessibilité, sans le point.
            RangeeAdaptable(alignement: .firstTextBaseline, espacement: 8) {
                Text(modele.ligneSerie, traducteur: traducteur)
                    .monospacedDigit()
                if let total = modele.ligneTotal {
                    if !tailleTexte.isAccessibilitySize {
                        Text(modele.separateur, traducteur: traducteur)
                            .accessibilityHidden(true)
                    }
                    Text(total, traducteur: traducteur)
                        .monospacedDigit()
                        .lignesAuPlus(2)
                }
            }
            .policeHebraique(.arrondie, taille: 15, relativeA: .subheadline)
            .foregroundStyle(Teinte(.muted))
            .frame(maxWidth: .infinity, alignment: .leading)
            .zoneDuCiel()
            if let detail = modele.detailDuJour {
                Text(detail, traducteur: traducteur)
                    .policeHebraique(.arrondie, taille: 16, relativeA: .callout)
                    .foregroundStyle(Teinte(.brand))
                    // Toute la largeur, comme le texte d'Android (match_parent), pour le plan du ciel.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .zoneDuCiel()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

// MARK: - Les anneaux

/// Les trois anneaux (AnneauxView, AnneauxDessin) et la plaque au creux : le hassid, ou une face et son chiffre.
/// Un anneau touché passe devant ; la plaque touchée tourne vers la face suivante.
private struct AccueilAnneauxVue: View {
    let modele: AccueilModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.layoutDirection) private var sens
    /// L'avance du remplissage, de 0 à 1.
    @State private var avance: Double = 1
    /// Le petit saut du hassid.
    @State private var decalage: CGFloat = 0
    /// Le battement des anneaux quand l'un se ferme.
    @State private var battement: CGFloat = 1

    /// gauge_size des téléphones de plus de 640 points de haut.
    private let cote: CGFloat = 260
    /// La plaque est rentrée de 32 points : trois anneaux de 8, deux écarts de 3, et un peu d'air.
    private let marge: CGFloat = 32

    var body: some View {
        ZStack {
            AccueilAnneauxDessin(traits: modele.traits(avance: avance), droite: sens == .leftToRight)
                .frame(width: cote, height: cote)
                .contentShape(Circle())
                .onTapGesture { point in
                    let x = sens == .leftToRight ? point.x : cote - point.x
                    if let quel = AccueilAnneaux.sousLePoint(cote: Double(cote), x: Double(x), y: Double(point.y)) {
                        modele.toucherAnneau(quel)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(Text(modele.descriptionAnneaux, traducteur: traducteur))
            plaque
                .frame(width: cote - 2 * marge, height: cote - 2 * marge)
                // La plaque claire : un fond, que l'astre ne touche pas (hero_plate, MainActivity.placerCiel).
                .zoneDuCiel()
        }
        // Le carré des anneaux : l'astre passe à côté d'eux, et derrière eux vers midi (CielPageVue).
        .jaugeDuCiel()
        .scaleEffect(battement)
        .sensoryFeedback(.impact(weight: .light), trigger: modele.touches)
        .task(id: modele.remplissage) {
            guard let numero = modele.remplissage else {
                avance = 1
                return
            }
            await remplir(numero)
        }
        .task(id: modele.retourHassidPrevu) {
            guard let numero = modele.retourHassidPrevu else { return }
            if await AccueilAttente.ms(AccueilModele.dureeRetourHassid) { modele.retourHassid(numero) }
        }
        .task(id: modele.feteAnneau) {
            guard let fete = modele.feteAnneau else { return }
            await battre()
            if await AccueilAttente.ms(AccueilModele.dureeFeteAnneau) { modele.finFeteAnneau(fete.numero) }
        }
        .task(id: modele.saut) {
            guard let saut = modele.saut else { return }
            await sauter(saut.fois)
        }
    }

    /// La plaque ronde (bg_gauge_plate, `stageSoft`, claire de jour comme de nuit).
    private var plaque: some View {
        Button {
            modele.toucherPlaque()
        } label: {
            ZStack {
                Circle().fill(Teinte(.stageSoft))
                if let face = modele.plaque {
                    VStack(spacing: 0) {
                        AccueilTexteVue.texte(face.texte, traducteur)
                            .tailleSp(34, poids: .bold, relativeA: .largeTitle)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                            .foregroundStyle(AccueilTeintes.style(face.couleur))
                        Text(face.legende, traducteur: traducteur)
                            .font(.caption)
                            .foregroundStyle(AccueilFixe(jour: 0x5E706A, nuit: 0x5E706A))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
                } else {
                    Illustration(decorative: modele.imageHassid)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                        .offset(y: decalage)
                        .transition(.opacity)
                }
            }
            .clipShape(Circle())
            .contentShape(Circle())
            .animation(modele.reduireAnimations ? nil : .easeInOut(duration: 0.34), value: modele.face)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: modele.accessibilitePlaque.map { AccueilTexteVue.chaine($0, traducteur) }
            .joined(separator: " ")))
    }

    /// 900 ms en ralentissant (DecelerateInterpolator 1,6), puis le modèle décide de la fête ou du saut.
    private func remplir(_ numero: Int) async {
        avance = 0
        let horloge = ContinuousClock()
        let debut = horloge.now
        let duree = Double(AccueilModele.dureeRemplissage)
        while true {
            let ecoule = Double((horloge.now - debut).components.attoseconds) / 1e15
                + Double((horloge.now - debut).components.seconds) * 1000
            let t = min(ecoule / duree, 1)
            avance = 1 - pow(1 - t, 3.2)
            if t >= 1 { break }
            guard await AccueilAttente.ms(16) else { return }
        }
        try? await modele.remplissageFini(numero)
    }

    /// Les anneaux battent deux fois (×1,07 en 180 ms, retour en 260 ms).
    private func battre() async {
        guard !modele.reduireAnimations else { return }
        for _ in 0..<2 {
            withAnimation(.easeOut(duration: 0.18)) { battement = 1.07 }
            guard await AccueilAttente.ms(180) else { return }
            withAnimation(.spring(duration: 0.26, bounce: 0.4)) { battement = 1 }
            guard await AccueilAttente.ms(260) else { return }
        }
    }

    /// Le saut du hassid : 10 points vers le haut en 220 ms, retour en rebond en 260 ms.
    private func sauter(_ fois: Int) async {
        guard !modele.reduireAnimations else { return }
        for _ in 0..<max(fois, 0) {
            withAnimation(.easeOut(duration: 0.22)) { decalage = -10 }
            guard await AccueilAttente.ms(220) else { return }
            withAnimation(.spring(duration: 0.26, bounce: 0.5)) { decalage = 0 }
            guard await AccueilAttente.ms(420) else { return }
        }
    }
}

/// Le dessin des anneaux (AnneauxDessin.kt) : pour chacun, la piste, un premier tour plein, puis le tour en cours
/// depuis le haut, dans le sens de lecture.
private struct AccueilAnneauxDessin: View {
    let traits: [AccueilTrait]
    /// Le sens de lecture : à droite en français, à gauche en hébreu.
    let droite: Bool
    @Environment(\.paletteApp) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        Canvas { contexte, taille in
            let cote = min(taille.width, taille.height)
            for trait in traits {
                dessiner(trait, dans: contexte, cote: cote)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func dessiner(_ trait: AccueilTrait, dans contexte: GraphicsContext, cote: CGFloat) {
        let retrait = CGFloat(trait.retrait)
        let cadre = CGRect(x: retrait, y: retrait, width: cote - 2 * retrait, height: cote - 2 * retrait)
        guard cadre.width > 0 else { return }
        let couleur = AccueilTeintes.anneau(trait.quel, palette: palette, schema: schema)
        let piste = palette.couleur(.dayTodo, schema: schema).mix(with: couleur, by: trait.teintePiste)
        let largeur = CGFloat(trait.epaisseur)
        var c = contexte
        c.opacity = trait.opacite
        let cercle = Path(ellipseIn: cadre)
        c.stroke(cercle, with: .color(piste), lineWidth: largeur)
        if trait.tourPlein {
            c.stroke(cercle, with: .color(couleur), lineWidth: largeur)
        }
        guard trait.reste > 0 else { return }
        let teinte = trait.assombri ? couleur.mix(with: .black, by: AccueilAnneaux.assombrissement) : couleur
        let balayage = 360 * trait.reste
        var arc = Path()
        // En y vers le bas, `clockwise: false` tourne à l'œil dans le sens des aiguilles d'une montre.
        arc.addArc(center: CGPoint(x: cadre.midX, y: cadre.midY), radius: cadre.width / 2,
                   startAngle: .degrees(-90), endAngle: .degrees(droite ? -90 + balayage : -90 - balayage),
                   clockwise: !droite)
        c.stroke(arc, with: .color(teinte), style: StrokeStyle(lineWidth: largeur, lineCap: .round))
    }
}

// MARK: - La bande de la semaine

/// Les sept cases, du dimanche au samedi (item_day.xml) : le jour en abrégé, la marque ; touchée, la boîte du jour.
private struct AccueilSemaineVue: View {
    let modele: AccueilModele
    @Environment(\.traducteur) private var traducteur
    @Environment(\.dynamicTypeSize) private var tailleTexte

    var body: some View {
        // Aux tailles d'accessibilité, les sept cases ne tiennent plus sur une ligne : elles se mettent en colonne,
        // le jour au début et la marque au bout de chaque case.
        RangeeAdaptable(colonne: .leading, espacement: 6) {
            ForEach(modele.semaine) { jour in
                if jour.ouvrable {
                    Button {
                        modele.ouvrirJour(jour.date)
                    } label: {
                        caseDuJour(jour)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: accessibilite(jour)))
                } else {
                    // Un jour à venir ne s'ouvre pas : une case, pas un bouton inactif, qu'iOS estompait (Android ne
                    // l'estompe pas, et le contraste de ses lettres ne suffisait plus).
                    caseDuJour(jour)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: accessibilite(jour)))
                }
            }
        }
    }

    private func caseDuJour(_ jour: AccueilJourSemaine) -> some View {
        let enLigne = tailleTexte.isAccessibilitySize
        let disposition = enLigne ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 4))
        return disposition {
            Text(verbatim: AccueilDate.texte(jour.date, langue: traducteur.langue, motif: enLigne ? "EEEE d" : "EEE"))
                .font(.caption)
                .foregroundStyle(AccueilTeintes.style(jour.couleurEtiquette))
                .lineLimit(enLigne ? nil : 1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: enLigne ? .infinity : nil, alignment: .leading)
            AccueilTexteVue.texte(jour.marque, traducteur)
                .tailleSp(jour.marqueReduite ? 12 : 16, poids: .bold, relativeA: jour.marqueReduite ? .caption : .callout)
                .monospacedDigit()
                .foregroundStyle(AccueilTeintes.style(jour.couleurMarque))
                .lineLimit(enLigne ? nil : 1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, enLigne ? 16 : 0)
        .padding(.vertical, enLigne ? 8 : 0)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(fond(jour.fond), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if jour.fond == .aujourdhui {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Teinte(.brand), lineWidth: 1.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func fond(_ fond: AccueilFondJour) -> AnyShapeStyle {
        switch fond {
        case .faite: AnyShapeStyle(Teinte(.dayDone))
        case .exempte: AnyShapeStyle(AccueilFixe(jour: 0xF3EEE2, nuit: 0x36322A))
        case .aujourdhui, .aFaire: AnyShapeStyle(Teinte(.dayTodo))
        }
    }

    private func accessibilite(_ jour: AccueilJourSemaine) -> String {
        let date = AccueilDate.texte(jour.date, langue: traducteur.langue, motif: "EEEE d")
        return ([date] + jour.accessibilite.map { traducteur.texte($0) }).joined(separator: " · ")
    }
}

// MARK: - Les cartes du moment

/// Une carte sous les boutons du jour : un rappel de la tefila, une prière, la source du jour.
private struct AccueilCarteVue: View {
    let carte: AccueilCarte
    let police: PoliceHebraique.Police
    let ouvrir: @MainActor (AccueilRoute) -> Void
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        switch carte {
        case .rappel(let rappel):
            rappelVue(rappel)
        case .priere(let priere):
            priereVue(priere)
        case .source(let source):
            sourceVue(source)
        }
    }

    /// Trois lignes centrées (RappelsTefilaVue.cartes).
    private func rappelVue(_ rappel: AccueilRappel) -> some View {
        let langue = traducteur.langue
        let corps = rappel.corps { AccueilDate.jourSemaine($0, langue: langue) }
        return Carte {
            VStack(spacing: 8) {
                Text(rappel.titre, traducteur: traducteur)
                    .tailleSp(19, poids: .bold, relativeA: .title3)
                    .foregroundStyle(Teinte(.ink))
                Text(corps, traducteur: traducteur)
                    .font(.callout)
                    .foregroundStyle(Teinte(.ink))
                    .lineSpacing(3)
                Text(rappel.source, traducteur: traducteur)
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    /// La prière de l'heure ou Birkat haLevana (AccueilMoment.carte) : le personnage, l'étiquette, le titre hébreu.
    private func priereVue(_ priere: AccueilPriere) -> some View {
        Button {
            ouvrir(priere.route)
        } label: {
            Carte {
                HStack(spacing: 14) {
                    Illustration(decorative: priere.image, hauteur: 56)
                        .frame(width: 48, height: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(priere.etiquette, traducteur: traducteur)
                            .font(Font.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .kerning(0.7)
                            .foregroundStyle(Teinte(.brand))
                        Text(verbatim: priere.hebreu)
                            .policeHebraique(police, taille: 21, gras: true)
                            .foregroundStyle(Teinte(.ink))
                            .environment(\.layoutDirection, .rightToLeft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let mot = priere.mot {
                            Text(mot, traducteur: traducteur)
                                .font(.footnote)
                                .foregroundStyle(Teinte(.muted))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward")
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// La source du jour (SourceDuJour.carte) : l'extrait de droite à gauche, la référence, « Lire la suite ».
    private func sourceVue(_ source: AccueilSource) -> some View {
        Carte {
            VStack(alignment: .leading, spacing: 10) {
                Text(source.titre, traducteur: traducteur)
                    .font(Font.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.7)
                    .foregroundStyle(Teinte(.brand))
                Text(verbatim: source.texte)
                    .policeHebraique(police, taille: 18)
                    .lineSpacing(4)
                    .foregroundStyle(Teinte(.ink))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(verbatim: source.reference)
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(Teinte(.muted))
                Button {
                    ouvrir(source.route)
                } label: {
                    Text(source.bouton, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
        }
    }
}

// MARK: - La barre de départ

/// La barre de départ (depart_barre), « visible dans les trois lieux » : « Commencer » sur toute la largeur, et la
/// flèche du volet à son bout. La racine la pose au bas de chaque onglet (`safeAreaInset`), et le volet une seule fois
/// par-dessus les onglets (`feuilleDepart`).
public struct BarreDepart: View {
    private let modele: AccueilModele
    /// Posée sous le Jour : elle prend la couleur du sol, au pied des collines du ciel (MainActivity.fondBarreDepart).
    private let surLeCiel: Bool
    @Environment(\.traducteur) private var traducteur
    /// La largeur de la barre : ses marges sont « edge » d'Android (16 sur un téléphone, jusqu'à 320 sur une
    /// tablette couchée, GrandEcran.bord).
    @State private var largeur: Double = 0

    public init(modele: AccueilModele, surLeCiel: Bool = false) {
        self.modele = modele
        self.surLeCiel = surLeCiel
    }

    public var body: some View {
        if surLeCiel {
            // Le sol du ciel suit le vrai soleil, comme le ciel du Jour : revu chaque minute.
            TimelineView(.everyMinute) { _ in
                barre(SolDuCiel(etat: modele.etatCiel))
            }
        } else {
            barre(SolDuCiel(etat: nil))
        }
    }

    private func barre(_ fond: SolDuCiel) -> some View {
        Button {
            modele.commencer()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .accessibilityHidden(true)
                Text(modele.libelleCommencer, traducteur: traducteur)
                    .lignesAuPlus(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.trailing, 48)
        }
        .buttonStyle(.principalGrand)
        .overlay(alignment: .trailing) {
            Button {
                modele.basculerVolet()
            } label: {
                Image(systemName: "chevron.up")
                    .font(Font.body.weight(.semibold))
                    .foregroundStyle(Teinte(.onBrand))
                    .rotationEffect(.degrees(modele.volet ? 180 : 0))
                    .frame(width: 60, height: 60)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(modele.libelleRegler, traducteur: traducteur))
        }
        .padding(.horizontal, GrandEcran.bord(largeur: largeur))
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(fond)
        // Pour l'audit d'accessibilité : ce qui défile dessous ne se voit pas (UITests, zoneVisible).
        .accessibilityIdentifier("barre-bas")
        .onGeometryChange(for: Double.self, of: { Double($0.size.width) }) { nouvelle in
            largeur = nouvelle
        }
    }
}

/// Le fond de la barre de départ : sous le Jour, la couleur du sol au pied des collines du ciel (`CielPageVue`), sans
/// couture ; ailleurs, ou avec « Contraste élevé », le papier.
struct SolDuCiel: ShapeStyle {
    let etat: EtatCiel?

    func resolve(in environment: EnvironmentValues) -> Color {
        if let etat, let t = CielDuJourTeintes.teintes(etat, palette: environment.paletteApp,
                                                        sombre: environment.colorScheme == .dark) {
            return CielCouleur.couleur(t.collinePres)
        }
        return environment.paletteApp.couleur(.paper, schema: environment.colorScheme)
    }
}

// MARK: - La feuille : le volet, ou une boîte

extension View {
    /// Le volet de la séance, ou la boîte qu'il a ouverte (ou qu'un geste du Jour a ouverte) à sa place : une feuille
    /// posée une seule fois, sur les onglets, pour qu'elle paraisse de n'importe lequel des trois lieux.
    public func feuilleDepart(accueil: AccueilModele, textes: TextesModele) -> some View {
        sheet(isPresented: Bindable(accueil).feuilleLiee) {
            AccueilFeuille(modele: accueil, textes: textes)
                .hauteursDeFeuille([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// Le volet de la séance, ou la boîte qu'il a ouverte (ou qu'un geste du Jour a ouverte) à sa place.
private struct AccueilFeuille: View {
    let modele: AccueilModele
    let textes: TextesModele

    var body: some View {
        Group {
            if let dialogue = modele.dialogue {
                AccueilBoite(modele: modele, dialogue: dialogue)
            } else {
                AccueilVolet(modele: modele, textes: textes)
            }
        }
        .background(Teinte(.paper))
    }
}

/// Le volet (depart_volet) : son titre, puis la durée, le sujet, la musique avec son interrupteur, la barrière.
private struct AccueilVolet: View {
    let modele: AccueilModele
    let textes: TextesModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(modele.titreVolet, traducteur: traducteur)
                    .tailleSp(20, poids: .bold, relativeA: .title3)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 20)
                    .padding(.bottom, 4)
                ForEach(modele.pastilles) { pastille in
                    ligne(pastille)
                    Divider().overlay(Teinte(.line))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private func ligne(_ pastille: AccueilPastille) -> some View {
        HStack(spacing: 10) {
            Button {
                Task { try? await modele.toucherPastille(pastille.genre) }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pastille.etiquette, traducteur: traducteur)
                            .font(.subheadline)
                            .foregroundStyle(Teinte(.ink))
                        if pastille.genre == .musique {
                            Text(textes.etatMusique, traducteur: traducteur)
                                .font(.footnote)
                                .foregroundStyle(Teinte(.muted))
                                .lignesAuPlus(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if pastille.genre != .musique {
                        AccueilTexteVue.texte(pastille.valeur, traducteur)
                            .font(Font.subheadline.bold())
                            .foregroundStyle(Teinte(.brand))
                            .lignesAuPlus(1)
                            .frame(maxWidth: 160, alignment: .trailing)
                    }
                    if pastille.genre != .barriere {
                        Image(systemName: "chevron.forward")
                            .font(Font.footnote.weight(.semibold))
                            .foregroundStyle(Teinte(.brand))
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if pastille.genre == .musique {
                Toggle(isOn: Bindable(textes).musiqueLiee) {
                    Text(pastille.etiquette, traducteur: traducteur)
                }
                .labelsHidden()
                .tint(Teinte(.brand))
            }
        }
    }
}

/// Les boîtes du Jour : une liste à choisir, la durée réglable, la boîte d'un jour de la bande.
private struct AccueilBoite: View {
    let modele: AccueilModele
    let dialogue: AccueilDialogue
    @Environment(\.traducteur) private var traducteur
    @State private var saisie = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let titre = titre {
                    titre
                        .tailleSp(20, poids: .bold, relativeA: .title3)
                        .foregroundStyle(Teinte(.ink))
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                }
                contenu
                Button {
                    modele.fermerDialogue()
                } label: {
                    Text(modele.libelleRetour, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
                .padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var titre: Text? {
        if case .jour(let boite) = dialogue {
            return Text(verbatim: AccueilDate.texte(boite.date, langue: traducteur.langue))
        }
        return modele.titreDialogue.map { Text($0, traducteur: traducteur) }
    }

    @ViewBuilder
    private var contenu: some View {
        switch dialogue {
        case .duree:
            ForEach(modele.optionsDuree) { option in
                choix(Text(option.libelle, traducteur: traducteur)) {
                    Task { try? await modele.choisirDuree(option.minutes) }
                }
            }
        case .dureeLibre:
            dureeLibre
        case .sujet:
            ForEach(modele.optionsSujet) { option in
                choix(Text(option.libelle, traducteur: traducteur)) {
                    Task { try? await modele.choisirSujet(option.theme) }
                }
            }
        case .jourHorsTelephone:
            let options = modele.optionsJourHorsTelephone
            ForEach(Array(options.enumerated()), id: \.offset) { rang, libelle in
                choix(Text(libelle, traducteur: traducteur)) {
                    modele.choisirJourHorsTelephone(hier: rang == 1)
                }
            }
        case .jour(let boite):
            jour(boite)
        }
    }

    private func choix(_ texte: Text, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            texte
                .font(.body)
                .foregroundStyle(Teinte(.ink))
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// La durée réglable (DureeSeance.saisir) : un champ numérique, prérempli ; refusée, la boîte le dit dessous.
    private var dureeLibre: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(text: $saisie, prompt: Text(modele.indicationDureeLibre, traducteur: traducteur), axis: .vertical) {
                Text(modele.indicationDureeLibre, traducteur: traducteur)
            }
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .onAppear { saisie = modele.texteDureeLibre }
            if let erreur = modele.erreurSaisie {
                Text(erreur, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(AccueilFixe(jour: 0xA8561F, nuit: 0xE8A062))
            } else {
                Text(modele.indicationDureeLibre, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
            }
            Button {
                let texte = saisie
                Task { try? await modele.validerDureeLibre(texte) }
            } label: {
                Text(modele.libelleValider, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 8)
        }
    }

    /// La boîte d'un jour (AjoutTemps.ouvrir) : ce qui est inscrit, ajouter du temps, montrer la durée.
    private func jour(_ boite: AccueilJourDialogue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(boite.message, traducteur: traducteur)
                .font(.body)
                .foregroundStyle(Teinte(.ink))
            Button {
                modele.ajouterTemps()
            } label: {
                Text(boite.ajouter, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            if let montrer = boite.montrer {
                Button {
                    modele.montrerDuree()
                } label: {
                    Text(montrer, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
        }
    }
}

// MARK: - Le bilan de la semaine

/// Le bilan de la semaine écoulée (MainActivity.bilanDeLaSemaine), une fois par semaine.
struct AccueilBilanVue: View {
    let bilan: AccueilBilan
    let fermer: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.tropheeFormes) private var formes

    var body: some View {
        // Défilante : aux grandes tailles du texte, le bilan dépasse la demi-hauteur de la feuille.
        ScrollView {
            contenu
        }
        .background(Teinte(.paper))
    }

    private var contenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(bilan.titre, traducteur: traducteur)
                .font(.title3.bold())
                .foregroundStyle(Teinte(.ink))
                .padding(.bottom, 6)
            Text(bilan.minutes, traducteur: traducteur)
                .font(Font.body.bold())
                .foregroundStyle(Teinte(.ink))
            if let plus = bilan.plus {
                Text(plus, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
            }
            if let record = bilan.record {
                Text(record, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
            }
            if let titreTrophees = bilan.titreTrophees {
                Text(titreTrophees, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 4)
                HStack(spacing: 6) {
                    ForEach(bilan.trophees) { trophee in
                        TropheeObjet(formes?.dessin(trophee.forme, metal: trophee.metal, icone: trophee.icone))
                            .frame(width: 40, height: 40)
                            .accessibilityLabel(Text(trophee.description, traducteur: traducteur))
                    }
                }
            }
            Button(action: fermer) {
                Text(bilan.bouton, traducteur: traducteur)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.principal)
            .padding(.top, 12)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Un mot bref (un Toast d'Android), en bas de l'écran.
struct AccueilMessage: View {
    let texte: Text

    var body: some View {
        texte
            .font(.subheadline)
            .foregroundStyle(Teinte(.paper))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Teinte(.ink).opacity(0.9), in: Capsule())
            .accessibilityAddTraits(.updatesFrequently)
    }
}
