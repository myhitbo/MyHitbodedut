import Coeur
import Ecrans
import SwiftUI
import Vues

/// Garde le modèle d'un écran poussé ou présenté le temps que l'écran vit : il est construit à la première
/// apparition (une fois par écran, pas à chaque recalcul de la vue parente) et rendu à la vue de l'écran.
struct Garde<Modele: AnyObject, Contenu: View>: View {
    private let fabrique: @MainActor () -> Modele
    private let contenu: @MainActor (Modele) -> Contenu
    @State private var modele: Modele?

    init(_ fabrique: @escaping @MainActor () -> Modele,
         @ViewBuilder contenu: @escaping @MainActor (Modele) -> Contenu) {
        self.fabrique = fabrique
        self.contenu = contenu
    }

    var body: some View {
        if let modele {
            contenu(modele)
        } else {
            Rectangle()
                .fill(Teinte(.paper))
                .ignoresSafeArea()
                .onAppear { modele = fabrique() }
        }
    }
}

/// L'écran d'une valeur `Ecran` de la pile, posé par `navigationDestination(for: Ecran.self)`.
struct Destination: View {
    let ecran: Ecran
    let app: PartageApp

    var body: some View {
        app.vue(ecran)
    }
}

/// Un écran d'Android pas encore porté : son titre et « Bientôt », sans rien faire semblant. La chaîne est propre
/// à iOS (Ressources/Chaines/ios.xcstrings, à relire par le propriétaire).
struct Bientot: View {
    let cle: String
    @Environment(\.traducteur) private var traducteur

    var body: some View {
        ContentUnavailableView {
            Text(Libelle(cle), traducteur: traducteur)
        } description: {
            Text("ios_bientot", tableName: "ios")
        }
        .foregroundStyle(Teinte(.ink))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Teinte(.paper))
        .navigationTitle(Text(Libelle(cle), traducteur: traducteur))
    }
}

/// Les écrans de l'app : chaque `Ecran` mené à sa vue, son modèle construit avec les objets partagés et les
/// paramètres de la route. Les vues prennent leurs routes par les fermetures de Routage.swift.
extension PartageApp {

    func vue(_ ecran: Ecran) -> AnyView {
        switch ecran {
        case .seance(let commencer):
            return vueSeance(commencer: commencer)
        case .paliers, .parcours, .musique, .conseils:
            return vueAujourdhui(ecran)
        case .recherche, .siddour, .lecture, .tehilim, .tehilimMarque, .tikkun, .tefilot:
            return vueLecture(ecran)
        case .bibliotheque, .entreeBibliotheque, .chizuk:
            return vueBibliotheque(ecran)
        case .halakha, .hilloulot, .calendrier, .vol, .boussole:
            return vueZmanim(ecran)
        case .bientot(let cle):
            return AnyView(Bientot(cle: cle))
        }
    }

    // MARK: La séance

    private func vueSeance(commencer: Bool) -> AnyView {
        let seance = self.seance
        let contenus = self.contenus
        let langue = self.langue
        let mini = self.mini
        return AnyView(Garde {
            SeanceModele(seance: seance, contenus: contenus, langue: langue, debug: PartageApp.debug)
        } contenu: { modele in
            SeanceVue(modele: modele, demande: commencer ? .commencer : .aucune, mini: mini,
                      celebration: { demande in self.celebration(demande) },
                      note: { jour in self.note(jour) },
                      ouvrir: { route in self.ouvrirSeance(route) })
        })
    }

    /// Le modèle du bravo, pour la séance et l'accueil.
    func celebration(_ demande: CelebrationDemande) -> CelebrationModele {
        CelebrationModele(demande: demande, magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                          debug: PartageApp.debug)
    }

    /// Le modèle de la note d'un jour.
    func note(_ jour: JourCivil) -> NoteModele {
        NoteModele(date: jour, magasin: magasin)
    }

    // MARK: L'onglet Aujourd'hui

    private func vueAujourdhui(_ ecran: Ecran) -> AnyView {
        let magasin = self.magasin
        let horloge = self.horloge
        switch ecran {
        case .paliers:
            let formes = self.formes
            return AnyView(Garde {
                PaliersModele(magasin: magasin, horloge: horloge)
            } contenu: { modele in
                PaliersVue(modele: modele, formes: formes)
            })
        case .parcours:
            return AnyView(Garde {
                ParcoursModele(magasin: magasin, horloge: horloge)
            } contenu: { modele in
                ParcoursVue(modele: modele)
            })
        case .musique:
            // Un modèle neuf par ouverture, avec ses propres sorties d'aperçu.
            let services = self.services
            let musique = self.musique
            return AnyView(Garde {
                MusiqueModele(magasin: magasin, lecteur: musique, apercu: services.sortieAudioApercu(),
                              ambianceApercu: services.sortieAmbianceApercu(), stockage: services.stockage)
            } contenu: { modele in
                MusiqueVue(modele: modele)
            })
        default:
            return AnyView(Garde {
                ConseilsModele(magasin: magasin)
            } contenu: { modele in
                ConseilsVue(modele: modele)
            })
        }
    }

    // MARK: Le siddour, la lecture, les Tehilim

    private func vueLecture(_ ecran: Ecran) -> AnyView {
        let magasin = self.magasin
        let contenus = self.contenus
        let horloge = self.horloge
        let langue = self.langue
        switch ecran {
        case .recherche:
            let preparateur = self.preparateur
            return AnyView(Garde {
                RechercheModele(magasin: magasin, preparateur: preparateur)
            } contenu: { modele in
                RechercheVue(modele: modele, ouvrir: { route in self.ouvrirRecherche(route) })
            })
        case .siddour:
            return AnyView(SiddourEcran(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                                        ouvrir: { route in self.ouvrirLecture(route) }))
        case .lecture(let cible):
            return AnyView(LectureEcran(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue,
                                        cible: cible, ouvrir: { route in self.ouvrirLecture(route) }))
        case .tehilim:
            return AnyView(Garde {
                TehilimModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue)
            } contenu: { modele in
                TehilimVue(modele: modele, lecture: { cible in self.lectureTehilim(cible) })
            })
        case .tehilimMarque(let psaume, let verset):
            return AnyView(TehilimLecturePage(cible: .marque(psaume: psaume, verset: verset),
                                              fabrique: { cible in self.lectureTehilim(cible) }))
        case .tikkun:
            return AnyView(Garde {
                TikkunModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue)
            } contenu: { modele in
                TikkunVue(modele: modele)
            })
        default:
            return AnyView(Garde {
                TefilotModele(magasin: magasin, contenus: contenus, langue: langue)
            } contenu: { modele in
                TefilotVue(modele: modele, ouvrir: { route in self.ouvrirTefilot(route) })
            })
        }
    }

    /// Le modèle de la lecture d'une portion de Tehilim.
    private func lectureTehilim(_ cible: TehilimLectureCible) -> TehilimLectureModele {
        TehilimLectureModele(magasin: magasin, contenus: contenus, langue: langue, cible: cible)
    }

    // MARK: La bibliothèque et le 'hizouk

    private func vueBibliotheque(_ ecran: Ecran) -> AnyView {
        let magasin = self.magasin
        let contenus = self.contenus
        let langue = self.langue
        switch ecran {
        case .bibliotheque(let livresSeuls):
            return AnyView(Garde {
                BibliothequeModele(magasin: magasin, contenus: contenus, langue: langue, livresSeuls: livresSeuls)
            } contenu: { modele in
                BibliothequeVue(modele: modele,
                                sousSection: { id in
                                    BibliothequeSousSectionModele(magasin: magasin, contenus: contenus,
                                                                  langue: langue, id: id)
                                },
                                entree: { id in
                                    BibliothequeEntreeModele(magasin: magasin, contenus: contenus, langue: langue,
                                                             id: id)
                                },
                                ouvrir: { route in self.ouvrirBibliotheque(route) })
            })
        case .entreeBibliotheque(let id):
            return AnyView(BibliothequeEntreePage(id: id, fabrique: { id in
                BibliothequeEntreeModele(magasin: magasin, contenus: contenus, langue: langue, id: id)
            }))
        default:
            return AnyView(Garde {
                ChizukModele(magasin: magasin, contenus: contenus, langue: langue, debug: PartageApp.debug)
            } contenu: { modele in
                ChizukVue(modele: modele, ouvrir: { route in self.ouvrirChizuk(route) })
            })
        }
    }

    // MARK: L'onglet Zmanim

    private func vueZmanim(_ ecran: Ecran) -> AnyView {
        let magasin = self.magasin
        let contenus = self.contenus
        let horloge = self.horloge
        let langue = self.langue
        switch ecran {
        case .halakha(let date, let recherche):
            return AnyView(Garde {
                HalakhaModele(magasin: magasin, contenus: contenus, horloge: horloge, langue: langue, date: date,
                              recherche: recherche)
            } contenu: { modele in
                HalakhaVue(modele: modele)
            })
        case .hilloulot(let date, let recherche):
            let hilloulot = self.hilloulot
            return AnyView(Garde {
                HilloulotModele(magasin: magasin, contenus: hilloulot, horloge: horloge, langue: langue, date: date,
                                recherche: recherche)
            } contenu: { modele in
                HilloulotVue(modele: modele)
            })
        case .calendrier:
            return AnyView(Garde {
                self.calendrier()
            } contenu: { modele in
                CalendrierVue(modele: modele, ouvrir: { route in self.ouvrirZmanim(route) })
            })
        case .vol:
            return AnyView(Garde {
                self.modeleVol()
            } contenu: { modele in
                VolVue(modele: modele)
            })
        default:
            return AnyView(Garde {
                self.modeleBoussole()
            } contenu: { modele in
                BoussoleVue(modele: modele)
            })
        }
    }

    /// Le calendrier, sur aujourd'hui, avec le choix du lieu de l'onglet.
    func calendrier() -> CalendrierModele {
        CalendrierModele(magasin: magasin, horloge: horloge, contenus: contenus, hilloulot: tableHilloulot,
                         choixLieu: zmanim.choixLieu, langue: langue)
    }

    /// Les zmanim en vol. Sans adresse de relais (décision D10), ni loupe ni suivi en direct : `enLigne` nil.
    private func modeleVol() -> VolModele {
        VolModele(magasin: magasin, horloge: horloge, aeroports: VolModele.lireAeroports(lecteur: lecteur),
                  notificateur: services.notificateur, retrait: services.notificateur,
                  localisation: services.localisation, lecteurBillet: services.lecteurBillet, enLigne: nil,
                  traducteur: traducteur, formats: .langue(langue))
    }

    private func modeleBoussole() -> BoussoleModele {
        BoussoleModele(magasin: magasin, contenus: contenus, horloge: horloge, traducteur: traducteur,
                       tableaux: tableaux, capteur: services.boussole, localisation: services.localisation,
                       autorisationLieu: services.localisation, rafraichissement: services.widgets)
    }
}
