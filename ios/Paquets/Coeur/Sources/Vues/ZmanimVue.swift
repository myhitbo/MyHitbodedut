import Foundation
import SwiftUI
import Coeur
import Ecrans

/// L'onglet Zmanim : la date hébraïque du jour montré et ses horaires. La vue ne calcule rien :
/// elle lit ZmanimModele (cible Ecrans), qui se teste sous Linux. Sa pile de navigation est celle de son
/// onglet (ios/App) : la vue n'en ouvre pas une seconde.
public struct ZmanimVue: View {
    let modele: ZmanimModele

    public init(modele: ZmanimModele) {
        self.modele = modele
    }

    public var body: some View {
        List {
            Section {
                ForEach(modele.horaires, id: \.cle) { zman in
                    HStack {
                        Text(LocalizedStringKey("zman_" + zman.cle))
                        Spacer()
                        Text(verbatim: heure(zman))
                            .monospacedDigit()
                    }
                }
            } header: {
                Text(verbatim: modele.jourHebreu.dateHebraique)
            }
            Section {
                HStack {
                    Button("jour_precedent") { modele.jourPrecedent() }
                    Spacer()
                    Button("jour_suivant") { modele.jourSuivant() }
                }
            }
        }
        .navigationTitle(Text("nav_zmanim"))
    }

    /// « 05:42 » à l'heure du lieu ; « — » pour un zman absent ce jour-là.
    private func heure(_ zman: Zmanim.Zman) -> String {
        guard let instant = zman.instant, let lieu = modele.lieu, let fuseau = Fuseau(lieu.fuseau) else { return "—" }
        let civile = fuseau.dateHeure(millis: Int64((instant.timeIntervalSince1970 * 1000).rounded()))
        let h = civile.heure, m = civile.minute
        return (h < 10 ? "0" : "") + String(h) + ":" + (m < 10 ? "0" : "") + String(m)
    }
}
