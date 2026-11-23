import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'écran Zmanim (ZmanimActivity.kt, VueJour.kt), ouvert par la date hébraïque en tête du Jour : le lieu, la carte du
/// jour (date hébraïque, fêtes, ajouts de la tefila), les boutons (halakha, hilloulot, calendrier), la question de la
/// région et les notes du jour, les horaires, Birkat haLevana, la hilloula et la halakha du jour, l'allumage et
/// Ta'hanoun, le pied ; le jour se change par ses flèches. La vue ne calcule rien : elle lit `ZmanimModele` (testé sous
/// Linux) et passe les écrans demandés à `ouvrir`.
public struct ZmanimVue: View {
    private let modele: ZmanimModele
    private let ouvrir: @MainActor (ZmanimRoute) -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase
    @State private var reglageOuvert: ZmanimChoix? = nil

    public init(modele: ZmanimModele, ouvrir: @escaping @MainActor (ZmanimRoute) -> Void = { _ in }) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                lieu
                ZmanimCarteJourVue(carte: modele.carte, estAujourdhui: modele.estAujourdhui,
                                   precedent: { modele.jourPrecedent() }, suivant: { modele.jourSuivant() },
                                   aujourdhui: { modele.revenirAujourdhui() }, partage: modele.partage)
                boutons(modele.boutons)
                if let question = modele.questionRegion {
                    questionRegion(question)
                }
                ForEach(notes, id: \.self) { note in
                    Text(note, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.brand))
                }
                horaires
                if let levana = modele.levana {
                    ZmanimLevanaVue(levana: levana) { ouvrir(levana.route) }
                }
                if let hilloula = modele.hilloula {
                    hilloulaVue(hilloula)
                }
                if let halakha = modele.halakha {
                    halakhaVue(halakha)
                }
                reglage(modele.allumageCarte, choix: .allumage)
                if let tahanoun = modele.tahanounCarte {
                    reglage(tahanoun, choix: .tahanoun)
                }
                sansTahanoun
                boutons(modele.boutonsBas)
                ForEach(Array(modele.pied.enumerated()), id: \.offset) { _, ligne in
                    Text(ligne, traducteur: traducteur)
                        .font(.caption2)
                        .foregroundStyle(Teinte(.muted))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Teinte(.paper))
        .navigationTitle(Text(modele.titre, traducteur: traducteur))
        .navigationBarTitleDisplayMode(.inline)
        .task { await modele.apparaitre() }
        .onDisappear { modele.disparaitre() }
        .onChange(of: phase) { _, nouvelle in
            if nouvelle == .active { Task { await modele.apparaitre() } }
        }
        .sheet(item: $reglageOuvert) { choix in
            ZmanimChoixVue(reglage: choix == .allumage ? modele.allumageCarte : (modele.tahanounCarte ?? modele.allumageCarte)) { id in
                reglageOuvert = nil
                Task {
                    if choix == .allumage {
                        try? await modele.choisirAllumage(id)
                    } else {
                        try? await modele.choisirTahanounTichri(sans: id == 1)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .modifier(ZmanimChoixLieu(choix: modele.choixLieu))
    }

    private var notes: [Libelle] {
        [modele.noteYomTovCheni, modele.ligneDateDiscutee, modele.depuisTset].compactMap { $0 }
    }

    /// Le lieu (« Jérusalem · Israël »), touchable pour le changer ; sans lieu, l'invitation à en choisir un.
    private var lieu: some View {
        Button {
            modele.montrerChoixLieu()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "location")
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
                if let texte = modele.lieuTexte {
                    Text(texte, traducteur: traducteur)
                        .font(.subheadline)
                        .foregroundStyle(Teinte(.ink))
                } else {
                    Text(modele.choisirLieuLibelle, traducteur: traducteur)
                        .font(Font.subheadline.weight(.semibold))
                        .foregroundStyle(Teinte(.brand))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(modele.choixLieu == nil)
    }

    /// Les boutons sous la carte : même largeur, contour.
    private func boutons(_ liste: [ZmanimBouton]) -> some View {
        // Côte à côte ; l'un sous l'autre aux tailles d'accessibilité, où leur nom ne tenait plus.
        RangeeAdaptable(espacement: 8) {
            ForEach(liste) { bouton in
                Button {
                    ouvrir(bouton.route)
                } label: {
                    HStack(spacing: 4) {
                        if let icone = bouton.icone {
                            Text(verbatim: icone)
                        }
                        Text(bouton.libelle, traducteur: traducteur)
                            .uneLigne(retrecie: 0.65)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
        }
    }

    private func questionRegion(_ question: ZmanimQuestionRegion) -> some View {
        Carte {
            Text(question.question, traducteur: traducteur)
                .font(.subheadline)
                .foregroundStyle(Teinte(.ink))
            HStack(spacing: 8) {
                Button {
                    Task { try? await modele.repondreRegion(accepter: true) }
                } label: {
                    Text(question.accepter, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
                Button {
                    Task { try? await modele.repondreRegion(accepter: false) }
                } label: {
                    Text(question.garder, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondaire)
            }
            .padding(.top, 10)
        }
    }

    /// Les horaires (VueJour.horaires), ou l'invitation à choisir un lieu.
    @ViewBuilder
    private var horaires: some View {
        if modele.sansLieu {
            Carte {
                Text(modele.invitationLieu, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                Button {
                    modele.montrerChoixLieu()
                } label: {
                    Text(modele.choisirLieuLibelle, traducteur: traducteur)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.principal)
                .padding(.top, 10)
                .disabled(modele.choixLieu == nil)
            }
        } else {
            Carte {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(modele.lignes) { ligne in
                        LigneHoraire(libelle: Text(ligne.nom, traducteur: traducteur), heure: ligne.heureTexte,
                                     methode: ligne.methode.map { Text($0, traducteur: traducteur) },
                                     misEnAvant: ligne.misEnAvant)
                    }
                }
            }
        }
    }

    private func hilloulaVue(_ hilloula: ZmanimHilloula) -> some View {
        Carte {
            Text(hilloula.titre, traducteur: traducteur)
                .font(Font.caption.bold())
                .foregroundStyle(Teinte(.muted))
            ForEach(hilloula.noms, id: \.self) { nom in
                Text(verbatim: nom)
                    .policeHebraique(modele.police, taille: 14)
                    .foregroundStyle(Teinte(.ink))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .padding(.top, 2)
            }
            if let autres = hilloula.autres {
                lien(autres) { ouvrir(hilloula.route) }
            }
            lien(hilloula.tout) { ouvrir(hilloula.route) }
        }
    }

    private func halakhaVue(_ halakha: ZmanimHalakha) -> some View {
        Carte {
            Text(verbatim: traducteur.texte(halakha.titre) + " · " + traducteur.texte(halakha.livre))
                .font(Font.caption.bold())
                .foregroundStyle(Teinte(.muted))
            Text(verbatim: halakha.debut)
                .policeHebraique(modele.police, taille: 16)
                .foregroundStyle(Teinte(.ink))
                .lignesAuPlus(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .rightToLeft)
                .padding(.top, 4)
            lien(halakha.tout) { ouvrir(halakha.route) }
        }
    }

    private func lien(_ libelle: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(libelle, traducteur: traducteur)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(Font.subheadline.weight(.medium))
            .foregroundStyle(Teinte(.brand))
            .frame(minHeight: 44)
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    /// Une carte de réglage touchable : le titre, la valeur, la proposition ; touchée, la liste à choix.
    private func reglage(_ reglage: ZmanimReglage, choix: ZmanimChoix) -> some View {
        Button {
            reglageOuvert = choix
        } label: {
            Carte {
                Text(reglage.titre, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.ink))
                Text(reglage.valeur, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                if let proposition = reglage.proposition {
                    Text(proposition, traducteur: traducteur)
                        .font(.footnote)
                        .foregroundStyle(Teinte(.brand))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// « Pas de Ta'hanoun aujourd'hui » : une carte qui bascule d'un toucher.
    private var sansTahanoun: some View {
        let carte = modele.sansTahanounCarte
        return Button {
            Task { try? await modele.basculerSansTahanounAujourdhui() }
        } label: {
            Carte {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(carte.titre, traducteur: traducteur)
                            .font(.subheadline)
                            .foregroundStyle(Teinte(.ink))
                        Text(carte.valeur, traducteur: traducteur)
                            .font(.footnote)
                            .foregroundStyle(Teinte(.muted))
                    }
                    Spacer(minLength: 8)
                    Image(systemName: carte.actif ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(Teinte(.brand))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(carte.actif ? .isSelected : [])
    }
}

/// Le réglage ouvert en liste.
enum ZmanimChoix: String, Identifiable {
    case allumage, tahanoun
    var id: String { rawValue }
}

/// La carte du jour (VueJour.carte) : les flèches du jour, la date hébraïque, la date civile, les fêtes, les ajouts.
/// Le calendrier la montre sans flèches : sa grille choisit le jour.
struct ZmanimCarteJourVue: View {
    let carte: ZmanimCarteJour
    let estAujourdhui: Bool
    let precedent: (@MainActor () -> Void)?
    let suivant: (@MainActor () -> Void)?
    let aujourdhui: (@MainActor () -> Void)?
    /// L'image du jour à partager (« Partager ce jour ↗ ») ; nil sans lien.
    let partage: PartageContenu?
    @Environment(\.traducteur) private var traducteur

    init(carte: ZmanimCarteJour, estAujourdhui: Bool, precedent: (@MainActor () -> Void)?,
         suivant: (@MainActor () -> Void)?, aujourdhui: (@MainActor () -> Void)?, partage: PartageContenu? = nil) {
        self.carte = carte
        self.estAujourdhui = estAujourdhui
        self.precedent = precedent
        self.suivant = suivant
        self.aujourdhui = aujourdhui
        self.partage = partage
    }

    var body: some View {
        Carte {
            HStack(spacing: 8) {
                if let precedent {
                    Button(action: precedent) {
                        Image(systemName: "chevron.backward")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("jour_precedent"))
                }
                VStack(spacing: 2) {
                    Text(verbatim: carte.dateHebraique)
                        .policeHebraique(.serif, taille: 22, gras: true, relativeA: .title2)
                        .foregroundStyle(Teinte(.ink))
                        .environment(\.layoutDirection, .rightToLeft)
                    Text(verbatim: HalakhaDateCivile.texte(carte.date, langue: Traducteur.identifiantLocale(traducteur.langue)))
                        .font(.footnote)
                        .foregroundStyle(Teinte(.muted))
                }
                .frame(maxWidth: .infinity)
                if let suivant {
                    Button(action: suivant) {
                        Image(systemName: "chevron.forward")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("jour_suivant"))
                }
            }
            .foregroundStyle(Teinte(.brand))
            if !estAujourdhui, let aujourdhui {
                Button(action: aujourdhui) {
                    Text(Libelle("calendrier_aujourdhui"), traducteur: traducteur)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Teinte(.brand))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
            ForEach(Array(carte.marques.enumerated()), id: \.offset) { _, marque in
                Text(marque, traducteur: traducteur)
                    .font(Font.subheadline.weight(.semibold))
                    .foregroundStyle(Teinte(.brand))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            Text(carte.ajoutsTitre, traducteur: traducteur)
                .font(Font.caption.bold())
                .foregroundStyle(Teinte(.muted))
                .padding(.top, 10)
            ForEach(Array(carte.ajouts.enumerated()), id: \.offset) { _, ajout in
                Text(ajout, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.top, 2)
            }
            if let aucun = carte.aucunAjout {
                Text(aucun, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.muted))
                    .padding(.top, 2)
            }
            if let partage {
                PartageJourLien(contenu: partage, libelle: carte.partage)
                    .padding(.top, 6)
            }
        }
    }
}

/// Birkat haLevana (VueJour.levana) : l'état, la lune de ce soir, la fenêtre, le motsaé conseillé, la restriction,
/// les remarques, la jauge du mois, la source, « Lire Birkat haLevana ».
struct ZmanimLevanaVue: View {
    let levana: ZmanimLevana
    let lire: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    init(levana: ZmanimLevana, lire: @escaping @MainActor () -> Void) {
        self.levana = levana
        self.lire = lire
    }

    var body: some View {
        Carte {
            Text(levana.titre, traducteur: traducteur)
                .font(Font.caption.bold())
                .foregroundStyle(Teinte(.muted))
            Text(levana.etat, traducteur: traducteur)
                .font(Font.body.bold())
                .foregroundStyle(levana.etatMisEnAvant ? Teinte(.brand) : Teinte(.ink))
                .padding(.top, 2)
            Text(levana.luneTexte, traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.muted))
            Text(ZmanimLevana.fenetre(debut: borne(levana.debut, dateSeule: levana.debutDateSeule),
                                      fin: borne(levana.fin, dateSeule: false)), traducteur: traducteur)
                .font(.footnote)
                .foregroundStyle(Teinte(.ink))
                .padding(.top, 4)
            if let motsae = levana.motsae {
                Text(ZmanimLevana.motsae(AccueilDate.texte(motsae, langue: traducteur.langue, motif: "EEE d MMM")),
                     traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.brand))
            }
            if let restriction = levana.restriction {
                Text(restriction, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.ink))
            }
            ForEach(Array(levana.remarques.enumerated()), id: \.offset) { _, remarque in
                Text(remarque, traducteur: traducteur)
                    .font(.footnote)
                    .foregroundStyle(Teinte(.brand))
            }
            ZmanimJaugeVue(jauge: levana.jauge)
                .frame(height: 14)
                .padding(.vertical, 6)
            Text(levana.source, traducteur: traducteur)
                .font(.caption2)
                .foregroundStyle(Teinte(.muted))
            Button(action: lire) {
                HStack(spacing: 4) {
                    Text(levana.lire, traducteur: traducteur)
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .font(Font.subheadline.weight(.medium))
                .foregroundStyle(Teinte(.brand))
                .frame(minHeight: 44)
            }
            .contentShape(Rectangle())
            .buttonStyle(.plain)
        }
    }

    /// « EEE d MMM, HH:mm » dans la langue de l'app ; la date seule quand l'heure n'est pas connue.
    private func borne(_ moment: DateHeure, dateSeule: Bool) -> String {
        let jour = AccueilDate.texte(moment.jour, langue: traducteur.langue, motif: "EEE d MMM")
        guard !dateSeule else { return jour }
        let h = moment.heure, m = moment.minute
        return jour + ", " + (h < 10 ? "0" : "") + String(h) + ":" + (m < 10 ? "0" : "") + String(m)
    }
}

/// La jauge du mois lunaire : le fil, la fenêtre en or, le soir du jour en point ; de droite à gauche en hébreu.
struct ZmanimJaugeVue: View {
    let jauge: ZmanimJauge

    var body: some View {
        GeometryReader { geo in
            let largeur = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Teinte(.line))
                    .frame(height: 3)
                Capsule()
                    .fill(AccueilFixe(jour: 0xB8780F, nuit: 0xE8B45C))
                    .frame(width: max(largeur * CGFloat(jauge.fin - jauge.debut), 3), height: 6)
                    .offset(x: largeur * CGFloat(jauge.debut))
                Circle()
                    .fill(Teinte(.brand))
                    .overlay { Circle().strokeBorder(Teinte(.card), lineWidth: 2) }
                    .frame(width: 12, height: 12)
                    .offset(x: largeur * CGFloat(jauge.point) - 6)
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// La liste à choix unique d'un réglage (allumage, Ta'hanoun), titrée comme sa carte ; elle se ferme au choix.
private struct ZmanimChoixVue: View {
    let reglage: ZmanimReglage
    let choisir: @MainActor (Int) -> Void
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(reglage.titre, traducteur: traducteur)
                    .tailleSp(20, poids: .bold, relativeA: .title3)
                    .foregroundStyle(Teinte(.ink))
                    .padding(.bottom, 8)
                ForEach(reglage.options) { option in
                    Button {
                        choisir(option.id)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: option.choisie ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(Teinte(.brand))
                                .accessibilityHidden(true)
                            Text(option.libelle, traducteur: traducteur)
                                .foregroundStyle(Teinte(.ink))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(option.choisie ? .isSelected : [])
                }
            }
            .padding(24)
        }
        .background(Teinte(.paper))
    }
}

/// Le choix du lieu (ChoixLieu.kt) : une feuille avec « Ma position » et les villes de la liste, puis le message bref
/// d'Android (un Toast : « Recherche de la position… », « Position indisponible : choisissez une ville. »). Partagé
/// par Zmanim et le calendrier.
struct ZmanimChoixLieu: ViewModifier {
    let choix: LieuModele?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let choix {
            content
                .sheet(isPresented: Bindable(choix).dialogueOuvert) {
                    ZmanimListeLieux(choix: choix)
                        .presentationDetents([.large])
                }
                .overlay(alignment: .bottom) {
                    ZmanimMessageLieu(choix: choix)
                }
        } else {
            content
        }
    }
}

/// Le message bref du choix du lieu, en bas de l'écran, effacé au bout de sa durée (Toast court ou long).
private struct ZmanimMessageLieu: View {
    let choix: LieuModele
    @Environment(\.traducteur) private var traducteur

    init(choix: LieuModele) {
        self.choix = choix
    }

    var body: some View {
        Group {
            if let message = choix.message {
                Text(message.libelle, traducteur: traducteur)
                    .font(.subheadline)
                    .foregroundStyle(Teinte(.onBrand))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Teinte(.brandDark)))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.default, value: choix.message)
        .task(id: choix.message) {
            guard let message = choix.message else { return }
            // Toast.LENGTH_SHORT, LENGTH_LONG ; la recherche reste affichée tant qu'elle dure.
            try? await Task.sleep(for: .seconds(message.long ? 3.5 : 2))
            guard !Task.isCancelled, choix.message == message else { return }
            if !choix.enCours || message != .attente { choix.messageVu() }
        }
    }
}

private struct ZmanimListeLieux: View {
    let choix: LieuModele
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        NavigationStack {
            List(choix.options) { option in
                Button {
                    Task { try? await choix.choisir(option) }
                } label: {
                    nom(option.nom)
                        .foregroundStyle(Teinte(.ink))
                }
            }
            .navigationTitle(Text(choix.titre, traducteur: traducteur))
            .navigationBarTitleDisplayMode(.inline)
            .task { await choix.charger() }
        }
    }

    private func nom(_ nom: LieuNom) -> Text {
        switch nom {
        case .libelle(let libelle): Text(libelle, traducteur: traducteur)
        case .texte(let texte): Text(verbatim: texte)
        }
    }
}
