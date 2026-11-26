import Foundation
import Testing
@testable import Coeur

/// MusicFilesTest d'Android, porté sur ce qu'iOS livre : `musique.json` et `ios/Ressources/Musique`,
/// que l'export tire de MusiquePlay.kt et de `res/raw` (jamais de `src/musique_hors_play`). Ce qui se
/// vérifie sans appareil : chaque morceau déclaré a son fichier et son titre, aucun n'est livré deux
/// fois sous deux noms, le poids reste sous les yeux.
///
/// iOS livre la liste de la version Play (PUBLICATION_PLAY_STORE.md § 3.2) : le test de la
/// construction Play d'Android (Gradle) devient « aucun morceau hors Play dans l'app ».
@Suite("Musique")
struct MusiqueTests {

    private let ressources = Depot.racine.appendingPathComponent("ios/Ressources")

    private func morceaux() throws -> [Morceau] { try Morceau.lire(Depot.contenu("musique.json")) }

    /// Les morceaux d'un dossier : AAC (.m4a) ; un .mp3 n'y est relevé que pour être refusé.
    private func audio(_ dossier: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(atPath: dossier.path)
            .filter { $0.hasSuffix(".m4a") || $0.hasSuffix(".mp3") }
            .sorted()
            .map { dossier.appendingPathComponent($0) }
    }

    private func embarques() throws -> [URL] { try audio(ressources.appendingPathComponent("Musique")) }

    private func nom(_ url: URL) -> String { url.deletingPathExtension().lastPathComponent }

    /// La taille et les huit premiers octets, sans lire le reste.
    private func entete(_ url: URL) throws -> (taille: UInt64, tete: [UInt8]) {
        let fichier = try FileHandle(forReadingFrom: url)
        defer { _ = try? fichier.close() }
        let tete = try fichier.read(upToCount: 8) ?? Data()
        let taille = try fichier.seekToEnd()
        return (taille, [UInt8](tete))
    }

    private func estMP4(_ tete: [UInt8]) -> Bool {
        tete.count == 8 && tete[4..<8].elementsEqual("ftyp".utf8)
    }

    /// Les fichiers aux mêmes octets, par groupes : la taille d'abord, le contenu ensuite.
    private func doublons(_ fichiers: [URL]) throws -> [[String]] {
        var parTaille: [UInt64: [URL]] = [:]
        for f in fichiers {
            let taille = try entete(f).taille
            parTaille[taille, default: []].append(f)
        }
        var groupes: [[String]] = []
        for memeTaille in parTaille.values where memeTaille.count > 1 {
            var restants = memeTaille
            while let premier = restants.first {
                let octets = try Data(contentsOf: premier)
                var pareils = [premier], autres: [URL] = []
                for f in restants.dropFirst() {
                    if try Data(contentsOf: f) == octets { pareils.append(f) } else { autres.append(f) }
                }
                if pareils.count > 1 { groupes.append(pareils.map(\.lastPathComponent)) }
                restants = autres
            }
        }
        return groupes
    }

    @Test func chaqueMorceauDeclareASonFichierEtSonTitre() throws {
        let liste = try morceaux()
        #expect(!liste.isEmpty, "aucun morceau déclaré : la lecture est cassée")
        let catalogue = try Catalogue.lire()
        let titres = Catalogue.langues.map { ($0, catalogue.simples($0)) }
        for m in liste {
            #expect(m.fichier == "Musique/\(m.id).m4a", "\(m.id) : l'identifiant et le fichier doivent porter le même nom")
            let url = ressources.appendingPathComponent(m.fichier)
            let existe = FileManager.default.fileExists(atPath: url.path)
            #expect(existe, "fichier absent : \(m.fichier)")
            if existe {
                let taille = try entete(url).taille
                #expect(taille > 1_000, "\(m.fichier) est vide")
                #expect(taille == UInt64(m.octets), "\(m.fichier) : \(taille) octets, musique.json en annonce \(m.octets)")
            }
            for (langue, chaines) in titres {
                #expect(chaines[m.titre].map { !$0.blanc } == true, "titre « \(m.titre) » absent en \(langue)")
            }
        }
    }

    @Test func aucunMorceauNEstLivreDeuxFoisSousDeuxNoms() throws {
        let fichiers = try embarques()
        #expect(!fichiers.isEmpty, "aucun morceau trouvé")
        for groupe in try doublons(fichiers) {
            Issue.record("mêmes octets sous plusieurs noms : \(groupe.joined(separator: ", "))")
        }
    }

    @Test func tousLesMorceauxLivresSontDeclaresEtReciproquement() throws {
        let surDisque = try embarques().map(nom).sorted()
        let declares = try morceaux().map(\.id).sorted()
        #expect(surDisque == declares, "un morceau livré que personne ne joue, ou un morceau déclaré sans fichier")
    }

    /// Le poids de l'audio est le poids de l'app : il ne se compresse plus. Le seuil d'Android
    /// (150 Mo, relevé quatre fois) n'est pas une réserve à remplir.
    @Test func lePoidsEmbarqueResteSousLesYeux() throws {
        var octets: UInt64 = 0
        for f in try embarques() {
            let taille = try entete(f).taille
            octets += taille
        }
        let mo = Double(octets) / 1_048_576
        #expect(mo < 150, "audio embarqué : \(mo) Mo ; n'embarquer qu'une sélection, pas relever le seuil")
    }

    /// AAC 96 kb/s depuis le 29/10 (tools/audio.py) : un MP3 ramènerait le poids d'avant.
    @Test func chaqueMorceauEmbarqueEstEnAAC() throws {
        let fichiers = try embarques()
        #expect(!fichiers.contains { $0.pathExtension == "mp3" }, "un mp3 parmi les morceaux : le réencoder (tools/audio.py)")
        for f in fichiers {
            let tete = try entete(f).tete
            #expect(estMP4(tete), "\(f.lastPathComponent) n'est pas un MP4 (« ftyp » absent)")
        }
    }

    /// `musique/`, les morceaux gardés hors des apps : rien n'y double ni n'y contredit ce qui est
    /// livré. tools/ajoute_musique.py contrôle à l'écriture ; ceci contrôle ce qui est dans le dépôt.
    @Test func leDossierMusiqueNeDoubleNiNeContreditCeQuiEstEmbarque() throws {
        let hors = try audio(Depot.racine.appendingPathComponent("musique"))
        #expect(!hors.isEmpty, "dossier musique/ vide ou introuvable")
        let embarques = try embarques()
        let noms = Set(embarques.map(nom))
        let liste = try morceaux()
        let declares = Set(liste.map(\.id))
        for f in hors {
            let o = try entete(f).tete
            let mp3 = o.starts(with: "ID3".utf8) || (o.count >= 2 && o[0] == 0xFF && o[1] & 0xE0 == 0xE0)
            #expect(mp3 || estMP4(o), "\(f.lastPathComponent) n'est ni un MP3 (ID3, trame MPEG) ni un MP4")
            #expect(!noms.contains(nom(f)), "\(f.lastPathComponent) est à la fois dans musique/ et livré")
            #expect(!declares.contains(nom(f)), "\(f.lastPathComponent) est dans musique/ mais déclaré dans musique.json")
        }
        // Le même enregistrement deux fois : entre musique/ et l'app, ou dans musique/.
        for groupe in try doublons(hors + embarques) {
            Issue.record("mêmes octets sous plusieurs noms : \(groupe.joined(separator: ", "))")
        }
    }

    /// Ce que la version Play livre, et rien d'autre (29/10) : Yanuka, המלך בשדה, נעם שפייר et
    /// יניר קילינסקי (Ianir), § 3.2. Liste écrite en entier : chaque morceau ajouté passe par ici. Retirés
    /// le 16/11 sur Android, faute d'accord écrit complet : « Eshet 'Hayil », « Arba Bavot », « Zemer
    /// bichva'hin » (passés dans la version GitHub seulement). Entrés le 26/11 (PR 53), sur décision du propriétaire :
    /// neuf autres niggounim du Yanuka (accord déclaré oral) et dix morceaux de Shneor Lerer (accord écrit du 21/11).
    @Test func lAppNeLivreQueLesMorceauxAutorises() throws {
        let autorises = [
            "hamelech_basade",
            "ianir_al_harega", "ianir_baal_shem_tov", "ianir_berditchev", "ianir_bessarabie",
            "ianir_eden_el_salvador", "ianir_hakol_milfanekha", "ianir_haleluhu", "ianir_hello", "ianir_houppa",
            "ianir_kabbalat_chabbat", "ianir_kol_bayaar", "ianir_mirage", "ianir_yohanan_hasandlar",
            "shpayer_afilou", "shpayer_beyond", "shpayer_esh_kamanche",
            "shpayer_hithadshout", "shpayer_kenout", "shpayer_ki_hine_kahomer", "shpayer_pnima", "shpayer_tunnels_end",
            "yanuka_nigoun_3",
            "yanuka_a_part_of_me", "yanuka_anticipation", "yanuka_harping_his_praise", "yanuka_listening_to_the_heart",
            "yanuka_shlomo_yehuda", "yanuka_shlomo_yehuda_2", "yanuka_the_king_will_return", "yanuka_the_truth_will_rise",
            "yanuka_yearning",
            "nigunim_for_neshama_shneor_lerer", "chabad_shabbos_shneor_lerer", "chabad_yamim_noraim_shneor_lerer",
            "relaxing_chabad_melodies_shneor_lerer", "tzomo_lecho_s_lerer", "vehi_sheamda_s_lerer",
            "vehi_sheamda_piano_shneor_lerer", "lerer_anim_zemirot", "lerer_ani_maamin", "lerer_nigun_abaal_shem_tov_for_babies",
        ].sorted()
        let declares = try morceaux().map(\.id).sorted(), livres = try embarques().map(nom).sorted()
        #expect(declares == autorises, "n'y mettre qu'un morceau dont la diffusion publique est établie")
        #expect(livres == autorises)
        // Ceux que seule la version GitHub d'Android livre n'entrent jamais dans l'app.
        let horsPlay = try audio(Depot.racine.appendingPathComponent("android/app/src/musique_hors_play/res/raw")).map(nom)
        #expect(!horsPlay.isEmpty, "src/musique_hors_play introuvable : la lecture est cassée")
        let fuites = horsPlay.filter { autorises.contains($0) }
        #expect(fuites.isEmpty, "\(fuites)")
    }
}
