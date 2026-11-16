package myhitbodedut;

/**
 * Le défilement automatique d'un texte, à vitesse réglable (comme Android,
 * le site et l'iPhone) : 10 crans, 3 par défaut, 6 × 1,4^(n-1) pixels par
 * seconde. Pas de calcul flottant ici : la table est écrite d'avance.
 *
 * Ce qui ne touche pas l'écran (crans, pixels à avancer) reste ici pour
 * tourner aussi dans TestsRegles ; l'écran (Lecture) garde le minuteur.
 * Le cran est gardé dans le journal (Journal.vitesseDefilement), sous le
 * nom commun aux autres applications : lecture_defilement_vitesse.
 */
final class Defilement {
    static final int MIN = 1, MAX = 10, DEFAUT = 3;

    /** Pixels par seconde pour les crans 1 à 10 : 6 × 1,4^(n-1), arrondi. */
    static final int[] PIXELS_PAR_SECONDE = {6, 8, 12, 16, 23, 32, 45, 63, 88, 124};

    /** Le pas du minuteur, en millisecondes. */
    static final int TIC = 50;

    /** Le texte d'aide, là où l'écran le montre. */
    static final String AIDE = "0 : défilement auto, * et # : vitesse";

    private static final Object VERROU = new Object();

    /** Le cran choisi, commun à tous les textes ; relu du journal au démarrage. */
    private static int vitesse = DEFAUT;
    /** Le journal où l'écrire, s'il y en a un (posé par la MIDlet). */
    private static Journal journal;

    static int borne(int n) {
        return n < MIN ? MIN : n > MAX ? MAX : n;
    }

    static int pixelsParSeconde(int n) {
        return PIXELS_PAR_SECONDE[borne(n) - MIN];
    }

    static int vitesse() {
        synchronized (VERROU) {
            return vitesse;
        }
    }

    /** Relit le cran du journal (au démarrage). */
    static void relit(Journal j) {
        synchronized (VERROU) {
            journal = j;
            vitesse = j == null ? DEFAUT : borne(j.vitesseDefilement);
        }
    }

    /** Plus lent (-1) ou plus vite (+1) ; renvoie le nouveau cran. */
    static int change(int sens) {
        synchronized (VERROU) {
            vitesse = borne(vitesse + sens);
            return vitesse;
        }
    }

    /** Écrit le cran dans le journal s'il a changé (à l'arrêt, pas à chaque touche : l'écriture est lente). */
    static void enregistre() {
        Journal j;
        int v;
        synchronized (VERROU) {
            j = journal;
            v = vitesse;
        }
        if (j == null || j.vitesseDefilement == v) return;
        j.vitesseDefilement = v;
        j.ecrit();
    }

    /** Fraction de pixel en attente, en millièmes : les crans lents avancent aussi. */
    private int reste;

    void remetAZero() {
        reste = 0;
    }

    /** Les pixels entiers à avancer après ms millisecondes au cran n ; garde le reste pour la suite. */
    int avance(int n, long ms) {
        if (ms <= 0) return 0;
        if (ms > 1000) ms = 1000; // un téléphone endormi ne fait pas sauter le texte
        reste += (int) (pixelsParSeconde(n) * ms);
        int px = reste / 1000;
        reste -= px * 1000;
        return px;
    }
}
