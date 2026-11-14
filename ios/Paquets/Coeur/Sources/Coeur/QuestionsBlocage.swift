// « Je ne sais pas quoi dire » (QuestionsBlocage.kt d'Android) : au lieu d'un seul texte, des
// questions, une à la fois. Elles suivent le « que dit-on ? » du guide du propriétaire
// (textes/guide_hitbodedut.md, quatorzième partie) : remercier, raconter, dire ce qu'on ressent,
// demander le matériel puis le spirituel, faire son 'heshbon nefesh, demander pardon, une petite
// décision, l'avenir, et finir en remerciant.

public enum QuestionsBlocage {

    /// Les clés des dix questions dans les chaînes, dans l'ordre où on les pose.
    public static let questions: [String] = [
        "question_merci",
        "question_raconter",
        "question_ressenti",
        "question_besoins",
        "question_force",
        "question_bilan",
        "question_pardon",
        "question_decision",
        "question_demain",
        "question_fin",
    ]

    /// La suivante ; après la dernière, on recommence. `(i + 1) % QUESTIONS.size` de Kotlin, qui
    /// déborde pour Int.MAX_VALUE (il y rend −8) ; ici le reste est pris avant d'ajouter un, et rien
    /// ne déborde : le résultat est toujours un rang de question.
    public static func suivante(_ i: Int) -> Int {
        i < 0 ? 0 : (i % questions.count + 1) % questions.count
    }
}
