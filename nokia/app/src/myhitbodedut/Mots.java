package myhitbodedut;

import javax.microedition.rms.RecordStore;

/**
 * Les mots de l'interface, en français, en anglais et en hébreu, et la
 * langue choisie. Les traductions reprennent celles de l'application
 * Android (values-en, values-iw) quand la phrase y existe.
 *
 * La langue suit d'abord le téléphone (microedition.locale) : hébreu,
 * anglais ou français ; toute autre langue donne l'anglais, comme sur
 * Android. Un choix fait dans l'application est gardé dans son propre
 * RecordStore (« langue »), à part du journal.
 *
 * Un tableau par mot, dans l'ordre FR, EN, HE : pas de Hashtable, et un
 * .jar qui reste petit.
 */
final class Mots {
    private Mots() {
    }

    static final int FR = 0, EN = 1, HE = 2;
    static final String[] CODES = {"fr", "en", "he"};
    /** Le nom de chaque langue, dans sa propre langue (langues_* de strings.xml). */
    static final String[] NOMS = {"Français", "English", "עברית"};

    /** Ce que montre chaque langue pour les textes de 'hizouk (RegleLangue), dans sa propre langue. */
    static final String[] CONTENU = {"Textes : hébreu et français", "Texts: Hebrew and English", "טקסטים: עברית בלבד"};

    /** La langue de l'interface : FR jusqu'au choix (les tests des règles l'attendent). */
    static int langue = FR;

    // Les clés : l'indice d'une ligne de T.
    static final int QUITTER = 0, RETOUR = 1, CHOISIR = 2, COMMENCER = 3, OK = 4, ACCUEIL = 5, AUTRE = 6,
        PAUSE = 7, REPRENDRE = 8, ARRETER = 9, ENREGISTRER = 10, LECTURE_PAUSE = 11, ILLISIBLES = 12,
        HITBODEDOUT = 13, MUSIQUE = 14, HIZOUK = 15, JOURNAL = 16, RAPPEL = 17, APPEL = 18, LANGUE = 19,
        DETAIL_DUREES = 20, EN_LECTURE = 21, ESSAI = 22, DETAIL_TEXTES = 23, DETAIL_JOURNAL = 24,
        CHAQUE_JOUR = 25, PAS_DE_RAPPEL = 26, DU_JOUR = 27, FAITE = 28, A_FAIRE = 29, SERIE_N = 30,
        AU_CHOIX = 31, DUREE = 32, MINUTES = 33, TITRE_PREPARE = 34, BILAN = 35, MOINS_D_UNE_MINUTE = 36,
        TEXTES = 37, TEXTE = 38, ME_RAPPELER = 39, HEURE = 40, RAPPEL_AIDE = 41, RAPPEL_ACTIF = 42,
        RAPPEL_COUPE = 43, RAPPEL_REFUSE = 44, COMMENT_APPELER = 45, APPEL_AIDE = 46, EN_PAUSE = 47,
        PARLE = 48, CENTRALE_REPRENDRE = 49, CENTRALE_PAUSE = 50, NIGGOUN = 51, AUCUN_FORMAT = 52,
        INCONNUS = 53, LECTURE_IMPOSSIBLE = 54, MUET = 55, NI_MP3_NI_AMR = 56, CENTRALE_ECOUTER = 57,
        JOUE = 58, EN_PAUSE_REPRENDRE = 59, FORMATS = 60, AUJOURDHUI = 61, A_FAIRE_MIN = 62, SERIE = 63,
        EN_TOUT = 64;

    static final String[][] T = {
        {"Quitter", "Quit", "יציאה"},
        {"Retour", "Back", "חזרה"},
        {"Choisir", "Choose", "בחירה"},
        {"Commencer", "Start", "להתחיל"},
        {"OK", "OK", "אישור"},
        {"Accueil", "Home", "ראשי"},
        {"Autre texte", "Another text", "טקסט אחר"},
        {"Pause", "Pause", "השהיה"},
        {"Reprendre", "Resume", "המשך"},
        {"Arrêter", "Stop", "עצירה"},
        {"Enregistrer", "Save", "שמירה"},
        {"Lecture/Pause", "Play/Pause", "הפעלה/השהיה"},
        {"Textes illisibles : %1", "Texts unreadable: %1", "לא ניתן לקרוא את הטקסטים: %1"},
        {"Hitbodedout", "Hitbodedut", "התבודדות"},
        {"Musique", "Music", "מוזיקה"},
        {"'Hizouk", "Chizuk", "חיזוק"},
        {"Journal", "Journal", "יומן"},
        {"Rappel", "Reminder", "תזכורת"},
        {"Vous appeler", "Address me as", "איך לפנות אליי"},
        {"Langue", "Language", "שפה"},
        {"De %1 à %2, ou au choix", "From %1 to %2, or your own length", "%1 עד %2, או לבחירה"},
        {"%1 : en lecture", "%1: playing", "%1: מתנגן"},
        {"%1 (essai)", "%1 (sample)", "%1 (לדוגמה)"},
        {"%1 textes, moment par moment", "%1 texts, moment by moment", "%1 טקסטים, רגע אחר רגע"},
        {"Série et 7 derniers jours", "Streak and the last 7 days", "רצף ושבעת הימים האחרונים"},
        {"Chaque jour à %1", "Every day at %1", "כל יום ב-%1"},
        {"Pas de rappel", "No reminder", "אין תזכורת"},
        {"Hitbodedout du jour", "Today's hitbodedut", "ההתבודדות של היום"},
        {"Faite : %1", "Done: %1", "נעשתה: %1"},
        {"À faire", "To do", "לביצוע"},
        {"Série : %1", "Streak: %1", "רצף: %1"},
        {"Au choix", "Other length", "משך לבחירה"},
        {"Durée", "Length", "משך"},
        {"Minutes (1 à 180)", "Minutes (1 to 180)", "דקות (1 עד 180)"},
        {"Hitbodedout · %1", "Hitbodedut · %1", "התבודדות · %1"},
        {"%1 %2 de hitbodedout.", "%1 %2 of hitbodedut.", "%1 %2 של התבודדות."},
        {"Moins d'une minute : rien n'est noté.", "Less than a minute: nothing is recorded.", "פחות מדקה: דבר לא נרשם."},
        {"%1 textes", "%1 texts", "%1 טקסטים"},
        {"1 texte", "1 text", "טקסט אחד"},
        {"Me rappeler chaque jour", "Remind me every day", "להזכיר לי כל יום"},
        {"Heure", "Time", "שעה"},
        {"Le téléphone ouvre MyHitbodedut à l'heure choisie. S'il le refuse, règle plutôt son alarme.",
            "The phone opens MyHitbodedut at the chosen time. If it refuses, set its alarm instead.",
            "הטלפון יפתח את MyHitbodedut בשעה שנבחרה. אם הוא מסרב, כוונו במקום זאת את השעון המעורר שלו."},
        {"Rappel chaque jour à %1.", "Reminder every day at %1.", "תזכורת כל יום ב-%1."},
        {"Rappel désactivé.", "Reminder off.", "התזכורת כבויה."},
        {"Ce téléphone refuse les rappels d'application. Règle plutôt son alarme (Menu > Extras).",
            "This phone refuses app reminders. Set its alarm instead (Menu > Extras).",
            "הטלפון הזה לא מאפשר תזכורות של אפליקציות. כוונו במקום זאת את השעון המעורר שלו."},
        {"Comment vous appeler ?", "What should we call you?", "איך לפנות אליכם?"},
        {"À la fin de chaque hitbodedout, l'application vous félicite. Avec Tsadeket, le personnage est une femme.",
            "At the end of each hitbodedut, the app congratulates you. With Tzaddeket, the character is a woman.",
            "בסוף כל התבודדות האפליקציה מברכת אתכם. עם צדקת, הדמות היא אישה."},
        {"En pause", "Paused", "מושהה"},
        {"Parle à Hachem, dans ta langue, comme à quelqu'un.", "Talk to Hashem, in your own language, as you would to someone.",
            "דברו אל השם בשפה שלכם, כמו שמדברים אל מישהו."},
        {"Touche centrale : reprendre", "Centre key: resume", "מקש אמצעי: המשך"},
        {"Touche centrale : pause", "Centre key: pause", "מקש אמצעי: השהיה"},
        {"Niggoun 33", "Niggun 33", "ניגון 33"},
        {"aucun format audio déclaré", "no audio format declared", "לא הוצהר אף פורמט שמע"},
        {"inconnus", "unknown", "לא ידועים"},
        {"Lecture impossible : %1", "Cannot play: %1", "לא ניתן לנגן: %1"},
        {"%1 : accepté mais muet. ", "%1: accepted but silent. ", "%1: התקבל אך שותק. "},
        {"Ce téléphone ne joue ni le MP3 ni l'AMR depuis une application. ", "This phone plays neither MP3 nor AMR from an app. ",
            "הטלפון הזה לא מנגן MP3 או AMR מתוך אפליקציה. "},
        {"Touche centrale : écouter", "Centre key: listen", "מקש אמצעי: האזנה"},
        {"Lecture (%1). Touche centrale : pause", "Playing (%1). Centre key: pause", "מתנגן (%1). מקש אמצעי: השהיה"},
        {"En pause. Touche centrale : reprendre", "Paused. Centre key: resume", "מושהה. מקש אמצעי: המשך"},
        {"Formats du téléphone : %1", "Phone formats: %1", "פורמטים של הטלפון: %1"},
        {"Aujourd'hui", "Today", "היום"},
        {"à faire", "to do", "לביצוע"},
        {"Série", "Streak", "רצף"},
        {"En tout : %1, %2", "In all: %1, %2", "סך הכול: %1, %2"},
    };

    /** Comment vous appeler, dans l'ordre de Journal.PAS_CHOISI, TSADIK, TSADEKET (adresse_*). */
    private static final String[][] ADRESSES = {
        {"Pas choisi", "Tsadik", "Tsadeket"},
        {"Not chosen", "Tzaddik", "Tzaddeket"},
        {"לא נבחר", "צדיק", "צדקת"},
    };
    /** celebration_neutral, celebration_tsadik, celebration_tsadeket. */
    private static final String[][] BRAVO = {
        {"Bravo !", "Bravo, Tsadik !", "Bravo, Tsadeket !"},
        {"Well done!", "Well done, Tzaddik!", "Well done, Tzaddeket!"},
        {"כל הכבוד!", "כל הכבוד, צדיק!", "כל הכבוד, צדקת!"},
    };
    /** L'initiale de chaque jour, de dimanche à samedi. */
    private static final String[][] INITIALES = {
        {"D", "L", "M", "M", "J", "V", "S"},
        {"S", "M", "T", "W", "T", "F", "S"},
        {"א", "ב", "ג", "ד", "ה", "ו", "ש"},
    };

    static String m(int cle) {
        return T[cle][langue];
    }

    /** Le mot, %1 remplacé. */
    static String m(int cle, String a) {
        return remplace(m(cle), "%1", a);
    }

    /** Le mot, %1 et %2 remplacés. */
    static String m(int cle, String a, String b) {
        return remplace(m(cle, a), "%2", b);
    }

    static String adresse(int a) {
        return ADRESSES[langue][a];
    }

    static String bravo(int a) {
        return BRAVO[langue][a];
    }

    /** Dimanche = 0. */
    static String initiale(int jourSemaine) {
        return INITIALES[langue][jourSemaine];
    }

    /** 1 jour, 3 jours ; 1 day ; יום אחד, יומיים, 3 ימים. */
    static String jours(int n) {
        if (langue == HE) return n == 1 ? "יום אחד" : n == 2 ? "יומיים" : n + " ימים";
        if (langue == EN) return n + (n == 1 ? " day" : " days");
        return n + (n > 1 ? " jours" : " jour");
    }

    /** Le nombre de textes d'un moment. */
    static String textes(int n) {
        return n == 1 ? m(TEXTE) : m(TEXTES, String.valueOf(n));
    }

    /** L'hébreu s'écrit de droite à gauche : les écrans dessinés se retournent. */
    static boolean rtl() {
        return langue == HE;
    }

    static String remplace(String s, String quoi, String par) {
        int i = s.indexOf(quoi);
        return i < 0 ? s : s.substring(0, i) + par + s.substring(i + quoi.length());
    }

    /** La langue d'une étiquette de téléphone (« he-IL », « iw », « en_US », « fr-FR »...) ; l'anglais sinon. */
    static int depuisLocale(String locale) {
        if (locale == null) return EN;
        String l = locale.toLowerCase();
        if (l.startsWith("he") || l.startsWith("iw")) return HE;
        if (l.startsWith("fr")) return FR;
        return EN;
    }

    // --- Le choix, à part du journal -------------------------------------------------
    private static final String NOM = "langue";

    /** La langue gardée, sinon celle du téléphone. */
    static void lit() {
        int choisie = -1;
        RecordStore rs = null;
        try {
            rs = RecordStore.openRecordStore(NOM, true);
            if (rs.getNumRecords() > 0) choisie = indice(new String(rs.getRecord(1)));
        } catch (Exception e) {
            // illisible : la langue du téléphone
        } finally {
            ferme(rs);
        }
        if (choisie < 0) {
            String locale = null;
            try {
                locale = System.getProperty("microedition.locale");
            } catch (Throwable t) {
                // pas de propriété
            }
            choisie = depuisLocale(locale);
        }
        langue = choisie;
    }

    static void ecrit(int l) {
        langue = l;
        RecordStore rs = null;
        try {
            byte[] b = CODES[l].getBytes();
            rs = RecordStore.openRecordStore(NOM, true);
            if (rs.getNumRecords() == 0) rs.addRecord(b, 0, b.length);
            else rs.setRecord(1, b, 0, b.length);
        } catch (Exception e) {
            // le téléphone refuse d'écrire : le choix vaut jusqu'à la fermeture
        } finally {
            ferme(rs);
        }
    }

    static int indice(String code) {
        for (int i = 0; i < CODES.length; i++) if (CODES[i].equals(code)) return i;
        return -1;
    }

    private static void ferme(RecordStore rs) {
        if (rs == null) return;
        try {
            rs.closeRecordStore();
        } catch (Exception e) {
            // déjà fermé
        }
    }
}
