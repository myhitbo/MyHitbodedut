import Foundation
import SwiftUI
import Coeur
import Ecrans

/// Le calendrier (CalendrierActivity.kt, activity_calendrier.xml), ouvert depuis Zmanim : un mois, du dimanche au
/// samedi, chaque case avec le quantième hébreu et le quantième civil ; Chabbat et fêtes teintés, les fêtes marquées
/// d'un point. Le mois hébreu est la vue principale, le mois civil au choix ; le jour touché montre sa carte, Levana,
/// la hilloula et la halakha, « Ajouter du temps fait hors du téléphone » pour un jour passé, ses horaires et le pied.
/// La vue ne calcule rien : elle lit `CalendrierModele` (testé sous Linux) et passe les écrans demandés à `ouvrir`.
public struct CalendrierVue: View {
    private let modele: CalendrierModele
    private let ouvrir: @MainActor (ZmanimRoute) -> Void
    @Environment(\.traducteur) private var traducteur
    @Environment(\.scenePhase) private var phase
    @Environment(\.layoutDirection) private var sens

    public init(modele: CalendrierModele, ouvrir: @escaping @MainActor (ZmanimRoute) -> Void = { _ in }) {
        self.modele = modele
        self.ouvrir = ouvrir
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                grille
                ZmanimCarteJourVue(carte: modele.carte, estAujourdhui: true, precedent: nil, suivant: nil,
                                   aujourdhui: nil, partage: modele.partage)
                if let levana = modele.levana {
                    ZmanimLevanaVue(levana: levana) { ouvrir(levana.route) }
                }
                if let hilloula = modele.hilloula {
                    hilloulaVue(hilloula)
                }
                if let halakha = modele.halakha {
                    halakhaVue(halakha)
                }
                if let ajouter = modele.ajouterTemps {
                    Button {
                        ouvrir(modele.routeAjouterTemps)
                    } label: {
                        Text(ajouter, traducteur: traducteur)
                            .font(Font.subheadline.bold())
                            .foregroundStyle(Teinte(.brand))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                horaires
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
        .modifier(ZmanimChoixLieu(choix: modele.choixLieu))
    }

    // MARK: La grille

    private var grille: some View {
        Carte {
            choixVue
            enTete
            // Sept colonnes : leurs chiffres grandissent avec le texte jusqu'à la première taille d'accessibilité,
            // au-delà desquelles ils ne tiendraient plus dans leur case ; chaque case se montre alors en grand sous
            // un appui long (le visualiseur de grand contenu, comme le calendrier d'iOS).
            Group {
                initiales
                ForEach(modele.semaines) { semaine in
                    HStack(spacing: 0) {
                        ForEach(Array(semaine.cases.enumerated()), id: \.offset) { _, uneCase in
                            if let uneCase {
                                CalendrierCaseVue(uneCase: uneCase, police: modele.police, langue: traducteur.langue) {
                                    modele.choisir(uneCase.date)
                                }
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 52)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            Button {
                modele.allerAujourdhui()
            } label: {
                Text(modele.aujourdhuiLibelle, traducteur: traducteur)
                    .font(Font.subheadline.bold())
                    .foregroundStyle(Teinte(.brand))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    /// « Hébraïque » | « Grégorien » : deux pilules sur la pilule commune.
    private var choixVue: some View {
        // L'un sous l'autre aux tailles d'accessibilité : côte à côte, chaque mot se coupait en deux.
        RangeeAdaptable(colonne: .center, espacement: 0) {
            ForEach(modele.vues) { vue in
                Button {
                    Task { try? await modele.basculer(civil: vue.civil) }
                } label: {
                    Text(vue.libelle, traducteur: traducteur)
                        .font(vue.actif ? Font.subheadline.bold() : Font.subheadline)
                        .foregroundStyle(vue.actif ? Teinte(.onBrand) : Teinte(.brand))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background {
                            if vue.actif { Capsule().fill(Teinte(.brand)) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(vue.actif ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Teinte(.brand).opacity(Double(0x17) / 255)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(modele.vueDescription, traducteur: traducteur))
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    /// « ‹ », le mois principal et l'autre calendrier, « › ».
    private var enTete: some View {
        let tete = modele.enTete
        return HStack(spacing: 0) {
            fleche(precedente: true, description: tete.precedent) { modele.moisPrecedent() }
            VStack(spacing: 2) {
                titre(tete.titre, taille: modele.civil ? 17 : 20, gras: true)
                    .foregroundStyle(Teinte(.ink))
                titre(tete.sousTitre, taille: 15, gras: false)
                    .foregroundStyle(Teinte(.brand))
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            fleche(precedente: false, description: tete.suivant) { modele.moisSuivant() }
        }
    }

    private func titre(_ titre: CalendrierTitre, taille: CGFloat, gras: Bool) -> some View {
        Group {
            switch titre {
            case .hebreu(let texte):
                Text(verbatim: texte)
                    .policeHebraique(modele.police, taille: taille, relativeA: VersionPolice.style(taille))
                    .environment(\.layoutDirection, .rightToLeft)
            case .moisCivil(let jour):
                Text(verbatim: CalendrierVue.initiale(AccueilDate.texte(jour, langue: traducteur.langue, motif: "LLLL yyyy"),
                                                      langue: traducteur.langue))
                    .tailleSp(taille, relativeA: VersionPolice.style(taille))
            case .plageCivile(let debut, let fin, let anneeAuDebut):
                let premier = AccueilDate.texte(debut, langue: traducteur.langue, motif: anneeAuDebut ? "LLLL yyyy" : "LLLL")
                let dernier = AccueilDate.texte(fin, langue: traducteur.langue, motif: "LLLL yyyy")
                Text(verbatim: CalendrierVue.initiale(premier + " – " + dernier, langue: traducteur.langue))
                    .tailleSp(taille, relativeA: VersionPolice.style(taille))
            }
        }
        .bold(gras)
    }

    /// Les flèches ne se reflètent pas d'elles-mêmes : en hébreu, « précédent » est à droite et pointe vers la droite.
    private func fleche(precedente: Bool, description: Libelle, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: precedente ? "chevron.backward" : "chevron.forward")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Teinte(.brand))
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(description, traducteur: traducteur))
    }

    /// Les initiales des jours, du dimanche au samedi, dans la langue de l'app (`TextStyle.NARROW`).
    private var initiales: some View {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.locale = Locale(identifier: Traducteur.identifiantLocale(traducteur.langue))
        let symboles = calendrier.veryShortStandaloneWeekdaySymbols
        return HStack(spacing: 0) {
            ForEach(modele.joursDeSemaine, id: \.self) { jour in
                Text(verbatim: jour - 1 < symboles.count ? symboles[jour - 1] : "")
                    .font(.caption)
                    .foregroundStyle(Teinte(.muted))
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Le jour choisi

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

    /// Les horaires du jour choisi, ou l'invitation à choisir un lieu (VueJour.horaires).
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

    /// La majuscule à l'initiale seulement : « Septembre – octobre 2026 ».
    static func initiale(_ texte: String, langue: String) -> String {
        guard let premier = texte.first else { return texte }
        return String(premier).uppercased(with: Locale(identifier: Traducteur.identifiantLocale(langue))) + texte.dropFirst()
    }
}

/// Une case de la grille : 52 pt de haut, toute la largeur d'une colonne ; le quantième principal en haut, le point
/// d'une fête, l'autre quantième ; Chabbat et Yom Tov sur fond de la marque à 10 %, le jour choisi cerclé.
private struct CalendrierCaseVue: View {
    let uneCase: CalendrierCase
    let police: PoliceHebraique.Police
    let langue: String
    let choisir: @MainActor () -> Void
    @Environment(\.traducteur) private var traducteur

    init(uneCase: CalendrierCase, police: PoliceHebraique.Police, langue: String,
         choisir: @escaping @MainActor () -> Void) {
        self.uneCase = uneCase
        self.police = police
        self.langue = langue
        self.choisir = choisir
    }

    var body: some View {
        Button(action: choisir) {
            VStack(spacing: 1) {
                quantieme(uneCase.haut, principal: true)
                    .foregroundStyle(uneCase.aujourdhui ? Teinte(.brand) : Teinte(.ink))
                if uneCase.fete {
                    Circle()
                        .fill(Teinte(.brand))
                        .frame(width: 5, height: 5)
                }
                quantieme(uneCase.bas, principal: false)
                    .foregroundStyle(Teinte(.muted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Teinte(.brand).opacity(uneCase.chome ? Double(0x1A) / 255 : 0))
                    .overlay {
                        if uneCase.choisie {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Teinte(.brand), lineWidth: 2)
                        }
                    }
                    .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: description))
        .accessibilityAddTraits(uneCase.choisie ? .isSelected : [])
        .accessibilityShowsLargeContentViewer {
            Text(verbatim: description)
        }
    }

    @ViewBuilder
    private func quantieme(_ q: CalendrierQuantieme, principal: Bool) -> some View {
        switch q {
        case .hebreu(let lettres):
            Text(verbatim: lettres)
                .policeHebraique(police, taille: principal ? 17 : 11, gras: principal && uneCase.aujourdhui,
                                 relativeA: principal ? .body : .caption2)
        case .civil(let jour):
            Text(verbatim: String(jour))
                .tailleSp(principal ? 15 : 11, poids: principal && uneCase.aujourdhui ? .bold : .regular,
                          relativeA: principal ? .subheadline : .caption2)
        case .premierDuMois(let jour):
            Text(verbatim: "1 " + AccueilDate.texte(jour, langue: langue, motif: "LLL"))
                .tailleSp(principal ? 15 : 11, poids: principal && uneCase.aujourdhui ? .bold : .regular,
                          relativeA: principal ? .subheadline : .caption2)
        }
    }

    /// La date civile, la date hébraïque, puis les fêtes, joints par « · ».
    private var description: String {
        let civile = AccueilDate.texte(uneCase.date, langue: langue)
        return ([civile, uneCase.dateHebraique] + uneCase.fetes.map { traducteur.texte($0) }).joined(separator: " · ")
    }
}
