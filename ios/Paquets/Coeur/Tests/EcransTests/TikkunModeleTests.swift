import Foundation
import Testing
import Coeur
@testable import Ecrans

/// Le Tikoun HaKlali d'un trait (TikkunFlowActivity.kt) : la page dans l'ordre (l'ouverture, les dix psaumes, la
/// clôture, la kavana et la prière de Rabbi Natan avec leurs notes), l'arrêt marqué dans le verset, les langues de
/// lecture ; « J'ai dit le Tikoun en entier » et le journal du Tikoun (Store.kt : le jour qui bascule à 4 h, les
/// psaumes dits, les jours dits) ; et le critère de la feuille de route (tâche 22) : le bouton fait gagner le
/// premier trophée du Tikoun. Sur le Tikoun exporté du dépôt.
///
/// Restent au test d'interface : le bouton qui ferme l'écran, le défilement, les couleurs et les tailles à l'écran,
/// et la célébration du trophée, qui vient de l'accueil (Celebrations), pas de cet écran.
@Suite("Modèle du Tikoun HaKlali")
@MainActor
struct TikkunModeleTests {

    private static let contenus = ContenusApp(dossier: Fichiers.contenu)

    private static func horloge(_ iso: String, heure: Int = 10, minute: Int = 0) throws -> HorlogeFixe {
        let jour = try #require(JourCivil(iso: iso))
        return HorlogeFixe(DateHeure(jour, heure: heure, minute: minute), fuseau: .utc)
    }

    private static func modele(langue: String = "fr", reglages: Reglages = Reglages(), magasin: Magasin? = nil,
                               horloge: HorlogeFixe? = nil) async throws -> TikkunModele {
        let ici = try horloge ?? Self.horloge("2026-11-16")
        let modele = TikkunModele(magasin: magasin ?? Magasin.enMemoire(Enregistrement(reglages: reglages)),
                                  contenus: contenus, horloge: ici, langue: langue)
        await modele.charger()
        return modele
    }

    private static func element(_ elements: [TikkunElement], _ id: String) throws -> TikkunElement {
        try #require(elements.first { $0.id == id })
    }

    // MARK: La page

    @Test func laPageSuitLOrdreDuTikoun() async throws {
        let modele = try await Self.modele()
        #expect(modele.etat == .pret)
        #expect(modele.titre == Libelle("tikkun_title"))
        #expect(modele.libelleFin == Libelle("tikkun_flow_done"))
        let elements = modele.elements
        let ids = elements.map { $0.id }
        #expect(Set(ids).count == ids.count)

        // Les titres, dans l'ordre : l'ouverture, les dix psaumes, la clôture, la kavana, la prière.
        var titres: [String] = []
        var premiers: [String] = []
        for element in elements {
            if case .titre(_, let premier) = element.sorte {
                titres.append(element.id)
                if premier { premiers.append(element.id) }
            }
        }
        let psaumes = Tikkun.ordre.map { "psaume" + String($0) + ":titre" }
        #expect(titres == ["ouverture:titre"] + psaumes + ["cloture:titre", "kavana:titre", "priere_rabbi_nathan:titre"])
        #expect(premiers == ["ouverture:titre"])

        let tikkun = try await Self.contenus.tikkun()
        let ouverture = try #require(tikkun.bloc(Tikkun.ouverture))
        let tete = try #require(elements.first)
        #expect(tete.sorte == .titre(.hebreu(PoliceHebraique.masque(ouverture.titre.he, police: .serif)), premier: true))
        let seize = try Self.element(elements, "psaume16:titre")
        #expect(seize.sorte == .titre(.libelle(Libelle("tikkun_psalm_he", .texte(Reference.lettres(16)))), premier: false))
    }

    @Test func enFrancaisChaqueVersetEstSuiviDeSaTraduction() async throws {
        let modele = try await Self.modele()
        let elements = modele.elements
        let tikkun = try await Self.contenus.tikkun()
        let verset = try #require(tikkun.byNumero(16)?.versets.first)
        let hebreu = try Self.element(elements, "psaume16:0")
        #expect(hebreu.sorte == .verset(PoliceHebraique.masque(verset.he, police: .serif)))
        let francais = try Self.element(elements, "psaume16:0:fr")
        let fr = try #require(verset.fr)
        #expect(francais.sorte == .traduction(fr, langue: "fr", seule: false, base: 19, margeHaut: 4))
        let anglais = elements.filter { $0.id.hasSuffix(":en") }.count
        #expect(anglais == 0)

        // Les paragraphes d'une partie : 18 pt de base pour leur traduction.
        let ouverture = try #require(tikkun.bloc(Tikkun.ouverture))
        let paragraphe = try Self.element(elements, "ouverture:0")
        #expect(paragraphe.sorte == .paragraphe(PoliceHebraique.masque(ouverture.paragraphes[0], police: .serif),
                                                centre: false))
        let traduit = try Self.element(elements, "ouverture:0:fr")
        #expect(traduit.sorte == .traduction(ouverture.paragraphesFr[0], langue: "fr", seule: false, base: 18,
                                             margeHaut: 4))
        // La note de l'ouverture n'est pas montrée : seules la kavana et la prière ont la leur.
        let notes = elements.filter { $0.id == "ouverture:note" }.count
        #expect(notes == 0)
    }

    @Test func lArretSeMarqueDansLeVersetAvantMitsar() async throws {
        let modele = try await Self.modele()
        let ids = modele.elements.map { $0.id }
        let tikkun = try await Self.contenus.tikkun()
        let verset = try #require(tikkun.byNumero(32)?.versets[6])
        let arret = try #require(verset.arret)
        let rang = try #require(ids.firstIndex(of: "psaume32:6"))
        let suite = Array(ids[rang..<(rang + 4)])
        #expect(suite == ["psaume32:6", "psaume32:6:arret", "psaume32:6:suite", "psaume32:6:fr"])
        let elements = modele.elements
        let coupe = try #require(verset.coupe())
        #expect(elements[rang].sorte == .verset(PoliceHebraique.masque(coupe.debut, police: .serif)))
        #expect(elements[rang + 1].sorte == .arret(PoliceHebraique.masque(arret.note, police: .serif)))
        #expect(elements[rang + 2].sorte == .verset(PoliceHebraique.masque(coupe.suite, police: .serif)))
        #expect(coupe.suite.commenceParUnites(arret.avant))
        let arrets = ids.filter { $0.hasSuffix(":arret") }
        #expect(arrets == ["psaume32:6:arret"])
    }

    @Test func laKavanaEtLaPriereOntLeurNoteDansLaLangueDeLApp() async throws {
        let modele = try await Self.modele()
        let elements = modele.elements
        let tikkun = try await Self.contenus.tikkun()
        let kavana = try #require(tikkun.bloc(Tikkun.kavana))
        let priere = try #require(tikkun.bloc(Tikkun.priere))
        // La kavana n'a pas de note : son titre traduit en tient lieu.
        let noteKavana = try Self.element(elements, "kavana:note")
        #expect(noteKavana.sorte == .note(kavana.titre.fr))
        let formule = try Self.element(elements, "kavana:formule")
        let texteFormule = try #require(kavana.formule)
        #expect(formule.sorte == .paragraphe(PoliceHebraique.masque(texteFormule, police: .serif), centre: true))
        let notePriere = try Self.element(elements, "priere_rabbi_nathan:note")
        let noteFr = try #require(priere.note).fr
        #expect(notePriere.sorte == .note(noteFr))
        // L'ordre : le titre, la note, la formule, puis les paragraphes.
        let ids = elements.map { $0.id }
        let rang = try #require(ids.firstIndex(of: "kavana:titre"))
        let suite = Array(ids[rang..<(rang + 4)])
        #expect(suite == ["kavana:titre", "kavana:note", "kavana:formule", "kavana:0"])
    }

    @Test func enHebreuNiTraductionNiNoteQuiRepeteLeTitre() async throws {
        let modele = try await Self.modele(langue: "he")
        let elements = modele.elements
        let traductions = elements.filter {
            if case .traduction = $0.sorte { return true }
            return false
        }.count
        #expect(traductions == 0)
        // La kavana : son titre hébreu ne se répète pas en note ; la prière garde sa note hébraïque.
        let noteKavana = elements.filter { $0.id == "kavana:note" }.count
        #expect(noteKavana == 0)
        let tikkun = try await Self.contenus.tikkun()
        let priere = try #require(tikkun.bloc(Tikkun.priere))
        let notePriere = try Self.element(elements, "priere_rabbi_nathan:note")
        let noteHe = try #require(priere.note).he
        #expect(notePriere.sorte == .note(noteHe))
    }

    @Test func sansLHebreuLaTraductionSeuleEnEncre() async throws {
        var reglages = Reglages()
        reglages.setLectureLangues("fr+en")
        let modele = try await Self.modele(reglages: reglages)
        let elements = modele.elements
        let ids = elements.map { $0.id }
        #expect(!ids.contains("psaume16:0"))
        #expect(!ids.contains("psaume32:6:arret"))
        let tikkun = try await Self.contenus.tikkun()
        let verset = try #require(tikkun.byNumero(16)?.versets.first)
        let francais = try Self.element(elements, "psaume16:0:fr")
        let fr = try #require(verset.fr)
        #expect(francais.sorte == .traduction(fr, langue: "fr", seule: true, base: 19, margeHaut: 12))
        let anglais = try Self.element(elements, "psaume16:0:en")
        let en = try #require(verset.en)
        #expect(anglais.sorte == .traduction(en, langue: "en", seule: true, base: 19, margeHaut: 4))
    }

    @Test func laPoliceMasqueSesSignesAbsents() async throws {
        var reglages = Reglages()
        reglages.setLecturePolice("miriam")
        let modele = try await Self.modele(reglages: reglages)
        let tikkun = try await Self.contenus.tikkun()
        let verset = try #require(tikkun.byNumero(16)?.versets.first)
        let hebreu = try Self.element(modele.elements, "psaume16:0")
        #expect(hebreu.sorte == .verset(PoliceHebraique.masque(verset.he, police: .miriam)))
    }

    // MARK: « J'ai dit le Tikoun en entier »

    /// Le critère de la tâche 22 : le bouton fait gagner le premier trophée du Tikoun.
    @Test func direLeTikounEnEntierFaitGagnerLePremierTropheeDuTikoun() async throws {
        let persistance = PersistanceEnMemoire()
        let magasin = Magasin(persistance: persistance)
        let modele = try await Self.modele(magasin: magasin)
        let premier = Trophees.Niveau(famille: .tikkun, rang: 1)
        let avant = Trophees.gagnes(Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0, tikkun: modele.joursDits))
        #expect(!avant.contains(premier))
        #expect(modele.finPossible)
        #expect(modele.psaumesDits.isEmpty)

        try await modele.direEnEntier()
        #expect(modele.termine)
        #expect(!modele.finPossible)
        #expect(modele.psaumesDits == Set(Tikkun.ordre))
        let jour = try #require(JourCivil(iso: "2026-11-16"))
        #expect(modele.joursDits == [jour])
        let apres = Trophees.gagnes(Trophees.Pratique(minutes: [:], notes: 0, meilleureSerie: 0, tikkun: modele.joursDits))
        #expect(apres.contains(premier))
        let tikkun = apres.filter { $0.famille == .tikkun }
        #expect(tikkun == [premier])

        // Écrit une seule fois, sous les clés d'Android.
        let ecritures = await persistance.ecrituresReglages
        #expect(ecritures == 1)
        let brut = await persistance.enregistrement.reglages.brut
        #expect(brut["tikkun_day"] == JSON.chaine("2026-11-16"))
        #expect(brut["tikkun_done"] == JSON.chaine("16,32,41,42,59,77,90,105,137,150"))
        #expect(brut["tikkun_journal"] == JSON.chaine("2026-11-16"))

        // Un second toucher ne réécrit rien.
        try await modele.direEnEntier()
        let encore = await persistance.ecrituresReglages
        #expect(encore == 1)
    }

    @Test func avantQuatreHeuresLeTikounCompteAuJourDAvant() async throws {
        let horloge = try Self.horloge("2026-11-17", heure: 2, minute: 30)
        let modele = try await Self.modele(horloge: horloge)
        try await modele.direEnEntier()
        let veille = try #require(JourCivil(iso: "2026-11-16"))
        #expect(modele.joursDits == [veille])
        let quatreHeures = try #require(JourCivil(iso: "2026-11-17"))
        let jour = TikkunJournal.jour(DateHeure(quatreHeures, heure: 4))
        #expect(jour == quatreHeures)
    }

    @Test func leJournalDuTikounGardeLesJoursEtOublieLesPsaumesDeLaVeille() throws {
        let lundi = try #require(JourCivil(iso: "2026-11-16"))
        var reglages = Reglages()
        for numero in Tikkun.ordre {
            TikkunJournal.marquer(&reglages, numero: numero, dit: true, maintenant: DateHeure(lundi, heure: 21))
        }
        #expect(TikkunJournal.journal(reglages) == [lundi])

        // Le lendemain : aucun psaume dit, le jour d'avant reste au journal.
        let mardi = lundi.plus(jours: 1)
        let faits = TikkunJournal.faits(reglages, maintenant: DateHeure(mardi, heure: 9))
        #expect(faits.isEmpty)
        TikkunJournal.marquer(&reglages, numero: 16, dit: true, maintenant: DateHeure(mardi, heure: 9))
        #expect(TikkunJournal.faits(reglages, maintenant: DateHeure(mardi, heure: 9)) == [16])
        #expect(TikkunJournal.journal(reglages) == [lundi])

        // Un psaume décoché le jour même retire ce jour du journal.
        TikkunJournal.marquer(&reglages, numero: 32, dit: false, maintenant: DateHeure(lundi, heure: 22))
        #expect(TikkunJournal.journal(reglages) == [])
    }

    @Test func leJournalSeLitCommeAndroidLeLit() throws {
        let lundi = try #require(JourCivil(iso: "2026-11-16"))
        var brut = ObjetJSON()
        brut["tikkun_day"] = .chaine("2026-11-16")
        brut["tikkun_done"] = .chaine(" 16, 32,x,,99999999999,-3")
        brut["tikkun_journal"] = .chaine("2026-11-02, n'importe quoi,2026-11-16,")
        let reglages = Reglages(brut: brut)
        let faits = TikkunJournal.faits(reglages, maintenant: DateHeure(lundi, heure: 12))
        #expect(faits == [16, 32, -3])
        let novembre = try #require(JourCivil(iso: "2026-11-02"))
        #expect(TikkunJournal.journal(reglages) == [novembre, lundi])
        // Un jour gardé qui n'est pas une chaîne : rien n'est dit ce jour.
        var autre = brut
        autre["tikkun_day"] = .entier(3)
        let rien = TikkunJournal.faits(Reglages(brut: autre), maintenant: DateHeure(lundi, heure: 12))
        #expect(rien.isEmpty)
    }

    // MARK: Le défilement et l'erreur

    @Test func uneTraductionRetireeRameneASonVerset() async throws {
        let magasin = Magasin.enMemoire()
        let modele = try await Self.modele(magasin: magasin)
        modele.teteVisible("psaume16:3:fr")
        try await modele.barre.choisirLangues(.he)
        let defilement = try #require(modele.defilement)
        #expect(defilement.cible == "psaume16:3")
        modele.teteVisible("psaume32:6:arret")
        try await modele.barre.changerTaille(plus: true)
        let ensuite = try #require(modele.defilement)
        #expect(ensuite.cible == "psaume32:6:arret")
    }

    @Test func unTikounIllisibleNeMontreRienEtNeCompteRien() async throws {
        let horloge = try Self.horloge("2026-11-16")
        let modele = TikkunModele(magasin: Magasin.enMemoire(), contenus: ContenusApp(lecteur: { _ in nil }),
                                  horloge: horloge, langue: "fr")
        #expect(!modele.finPossible)
        await modele.charger()
        #expect(modele.etat == .erreur)
        #expect(modele.elements.isEmpty)
        #expect(!modele.finPossible)
        try await modele.direEnEntier()
        #expect(!modele.termine)
        #expect(modele.joursDits.isEmpty)
    }
}
