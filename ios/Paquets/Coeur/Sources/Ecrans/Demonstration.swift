import Foundation
import Coeur

/// Le journal et les réglages de démonstration des captures d'écran (`-captureDemo`, ios-captures.yml ; ECRANS.md,
/// « Les captures »), sur le modèle de ceux des captures d'Android (tools/promo_screenshots.sh) : douze jours faits de
/// suite jusqu'à hier, le Chabbat de repos ; trois jours manqués ; vingt-six jours plus anciens. Une durée de 20
/// minutes, trois rappels, la hitbodedout guidée, un nigoun du Yanouka ; la présentation vue ; une ville de la liste
/// selon la langue des captures. Aujourd'hui n'est pas encore fait : le Jour montre son bouton de départ.
///
/// L'app tient ce magasin en mémoire (Captures.swift) : rien n'est écrit dans ses fichiers.
public enum Demonstration {

    /// La ville de chaque langue (identifiants GeoNames de `villes.json`) : Paris, New York, Jérusalem, Buenos Aires ;
    /// Paris pour l'arabe de Tunisie, que la liste n'a pas. La CI donne au simulateur le fuseau de cette ville.
    public static func ville(langue: String) -> Int64 {
        switch langue {
        case "en": 5_128_581
        case "he": 281_184
        case "es": 3_435_910
        default: 2_988_507
        }
    }

    /// Les minutes des douze jours récents, du plus proche au plus lointain (promo_screenshots.sh).
    static let minutesRecentes = [20, 35, 15, 60, 20, 25, 20, 30, 20, 45, 20, 25]
    /// Celles des jours plus anciens, en boucle.
    static let minutesAnciennes = [20, 30, 45, 20, 60, 25]
    /// Les sujets des premiers jours récents (Theme).
    static let sujets: [Theme?] = [.gratitude, .famille, nil, .parnassa, .croissance]
    /// L'humeur avant et après la séance des premiers jours récents (JournalPlus, de 1 à 5).
    static let humeurs: [(Int, Int)] = [(2, 4), (3, 4), (3, 5), (2, 4)]

    /// Le journal et les réglages de la démonstration, aujourd'hui `aujourdhui` (à l'instant `maintenant`, dans le
    /// fuseau du téléphone `fuseau`), dans la langue de l'app. `villes` : la liste de `villes.json` ; sans la ville de
    /// la langue, le lieu reste à choisir.
    public static func enregistrement(aujourdhui: JourCivil, maintenant: Int64, fuseau: String, langue: String,
                                      villes: [Ville]) -> Enregistrement {
        var journal = Journal()
        let notes = Demonstration.notes(langue)
        var plus = ObjetJSON()
        // Douze jours faits jusqu'à hier, en sautant les samedis (le Chabbat est un jour de repos, la série tient).
        var jour = aujourdhui.plus(jours: -1)
        var recents = 0
        while recents < minutesRecentes.count {
            if jour.jourDeSemaine != 7 {
                let theme = recents < sujets.count ? sujets[recents]?.rawValue : nil
                journal.addSession(minutes: minutesRecentes[recents], note: recents < notes.count ? notes[recents] : nil,
                                   theme: theme, date: jour)
                if recents < humeurs.count {
                    let (avant, apres) = humeurs[recents]
                    JournalPlus.ecrire(&plus, date: jour.iso,
                                       plus: JournalPlus.Plus(avant: avant, apres: apres,
                                                              gratitude: recents == 0 ? gratitude(langue) : ""))
                }
                recents += 1
            }
            jour = jour.plus(jours: -1)
        }
        // Trois jours manqués, puis vingt-six jours plus anciens, samedis exceptés.
        jour = jour.plus(jours: -3)
        for i in 0..<26 {
            if jour.jourDeSemaine != 7 {
                journal.addSession(minutes: minutesAnciennes[i % minutesAnciennes.count], date: jour)
            }
            jour = jour.plus(jours: -1)
        }
        journal.setPlusBrut(plus)
        journal.setFirstName(prenom(langue))

        var reglages = Reglages()
        reglages.setOnboarded()
        // La version déjà choisie : l'accueil Classique, sans l'écran du choix par-dessus (MainActivity.onResume).
        reglages.setVersionApp(.classique)
        reglages.setAdresse("m")
        reglages.setTargetMinutes(20)
        reglages.setReminderEnabled(true)
        reglages.setReminderTimes([6 * 60 + 45, 13 * 60 + 30, 22 * 60 + 15])
        reglages.setGuidedHitbodedut(true)
        reglages.setMusicEnabled(true)
        reglages.setMusicTrackId("yanuka_nigoun_3")
        // Le bilan de la semaine passée déjà lu : le Jour se montre sans lui (AccueilModele.bilanDeLaSemaine).
        reglages.setBilanVu(BilanSemaine.debutSemaine(aujourdhui).plus(jours: -7).iso)
        let id = ville(langue: langue)
        if let ville = villes.first(where: { $0.id == id }) {
            // Comme LieuModele.choisirVille : le nom dans la langue de l'app, Israël d'après le pays.
            let lieu = Zmanim.Lieu(nom: ville.nom.pour(langue), latitude: ville.latitude, longitude: ville.longitude,
                                   altitude: ville.altitude, fuseau: ville.fuseau)
            reglages.setLieuZmanim(lieu, ville: ville, maintenant: maintenant, aujourdhui: aujourdhui,
                                   fuseauTelephone: fuseau)
        }
        return Enregistrement(journal: journal, reglages: reglages)
    }

    /// La fête au Jour (`-capture fete`) : tout ce qui est gagné est déjà vu, paliers compris, sauf le dernier trophée
    /// gagné du chemin (Trophees.chemin) ; le passage sur l'accueil (TropheeFeteModele.passer) le fête, lui seul.
    public static func avecTropheeNeuf(_ demo: Enregistrement, aujourdhui: JourCivil, fuseau: String) -> Enregistrement {
        var demo = demo
        let pratique = Store.pratique(journal: demo.journal, reglages: demo.reglages, aujourdhui: aujourdhui,
                                      fuseauTelephone: fuseau)
        let bilan = Store.bilan(journal: demo.journal, reglages: demo.reglages, aujourdhui: aujourdhui,
                                fuseauTelephone: fuseau)
        let gagnes = Trophees.gagnes(pratique)
        guard let dernier = Trophees.chemin.last(where: { gagnes.contains($0) }) else { return demo }
        let tout = Celebrations.neuf(bilan, pratique, paliersVus: nil, tropheesVus: nil)
        demo.reglages.setPaliersVus(tout.marques)
        demo.reglages.setTropheesVus(Set(gagnes.map(\.cle)).subtracting([dernier.cle]))
        return demo
    }

    /// Le prénom de la démonstration.
    static func prenom(_ langue: String) -> String {
        switch langue {
        case "he": "דוד"
        case "ar": "داود"
        default: "David"
        }
    }

    /// Les notes des quatre derniers jours (la troisième vide), celles d'Android traduites.
    static func notes(_ langue: String) -> [String] {
        switch langue {
        case "fr":
            ["Je L'ai remercié pour ma famille. Demandé de la patience au travail.",
             "Difficile de commencer. Puis les mots sont venus.", "",
             "Marché dehors, parlé à voix haute. Je me suis senti proche."]
        case "he":
            ["הודיתי לו על המשפחה שלי. ביקשתי סבלנות בעבודה.", "היה קשה להתחיל. ואז המילים באו.", "",
             "הלכתי בחוץ, דיברתי בקול. הרגשתי קרוב."]
        case "es":
            ["Le agradecí por mi familia. Pedí paciencia en el trabajo.", "Me costó empezar. Luego llegaron las palabras.",
             "", "Caminé afuera, hablé en voz alta. Me sentí cerca."]
        case "ar":
            ["شكرتو على عايلتي. طلبت الصبر في الخدمة.", "كان صعيب باش نبدا. من بعد جاو الكلام.", "",
             "مشيت برّا وحكيت بالصوت العالي. حسّيت روحي قريب."]
        default:
            ["Thanked Him for my family. Asked for patience at work.", "Hard to start. Then the words came.", "",
             "Walked outside, spoke out loud. Felt close."]
        }
    }

    /// La gratitude d'hier.
    static func gratitude(_ langue: String) -> String {
        switch langue {
        case "fr": "Le sourire de ma fille ce matin."
        case "he": "החיוך של הבת שלי הבוקר."
        case "es": "La sonrisa de mi hija esta mañana."
        case "ar": "ضحكة بنتي الصباح."
        default: "My daughter's smile this morning."
        }
    }
}
