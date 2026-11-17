package myhitbodedut;

import java.util.Calendar;
import java.util.Date;
import javax.microedition.io.PushRegistry;
import javax.microedition.lcdui.Alert;
import javax.microedition.lcdui.AlertType;
import javax.microedition.lcdui.ChoiceGroup;
import javax.microedition.lcdui.Command;
import javax.microedition.lcdui.CommandListener;
import javax.microedition.lcdui.DateField;
import javax.microedition.lcdui.Display;
import javax.microedition.lcdui.Displayable;
import javax.microedition.lcdui.Form;
import javax.microedition.lcdui.Graphics;
import javax.microedition.lcdui.TextBox;
import javax.microedition.lcdui.TextField;
import javax.microedition.media.Manager;
import javax.microedition.midlet.MIDlet;

/**
 * MyHitbodedut pour téléphone à touches (Java ME, MIDP 2.0) : la
 * hitbodedout minutée, les textes de ’hizouk, le journal et un rappel
 * quotidien, dans les couleurs et avec le personnage de l'application.
 * En français, en anglais ou en hébreu (Mots). Aucune connexion.
 */
public final class MyHitbodedut extends MIDlet implements CommandListener, Minuteur.Fin, Menu.Choix {
    static final int[] DUREES = {5, 10, 15, 30, 60, 90};

    private Display display;
    private Textes textes;
    private Journal journal;

    // Les touches écran, refaites quand la langue change (le libellé d'une Command est fixe).
    private Command quitter, retour, choisir, commencer, ok, accueilCmd, autre, pause, reprendre, bloque, arreter,
        enregistrer, lecturePause;

    private void creeCommandes() {
        quitter = new Command(Mots.m(Mots.QUITTER), Command.EXIT, 1);
        retour = new Command(Mots.m(Mots.RETOUR), Command.BACK, 1);
        choisir = new Command(Mots.m(Mots.CHOISIR), Command.OK, 1);
        commencer = new Command(Mots.m(Mots.COMMENCER), Command.OK, 1);
        ok = new Command(Mots.m(Mots.OK), Command.OK, 1);
        accueilCmd = new Command(Mots.m(Mots.ACCUEIL), Command.OK, 1);
        autre = new Command(Mots.m(Mots.AUTRE), Command.SCREEN, 2);
        pause = new Command(Mots.m(Mots.PAUSE), Command.SCREEN, 1);
        reprendre = new Command(Mots.m(Mots.REPRENDRE), Command.SCREEN, 1);
        bloque = new Command(textes.mot("chizuk_stuck"), Command.SCREEN, 2);
        arreter = new Command(Mots.m(Mots.ARRETER), Command.STOP, 3);
        enregistrer = new Command(Mots.m(Mots.ENREGISTRER), Command.OK, 1);
        lecturePause = new Command(Mots.m(Mots.LECTURE_PAUSE), Command.OK, 1);
    }

    private Menu accueil;
    private Menu langues;
    private Menu durees;
    private Menu moments;
    private Menu liste;
    private TextBox auChoix;
    private Lecture avant;
    private Lecture lecture;
    private Lecture fin;
    private JournalEcran journalEcran;
    private Form reglage;
    private DateField heure;
    private ChoiceGroup actif;
    private Form appel;
    private ChoiceGroup adresse;
    private Minuteur minuteur;
    private Musique musique;
    private int dureeChoisie;
    private int momentOuvert = -1;
    private int texteOuvert = -1;
    private Displayable apresLecture;

    protected void startApp() {
        if (display != null) return; // retour d'une pause : l'écran reste où il était
        display = Display.getDisplay(this);
        Mots.lit();
        journal = Journal.lit();
        Ecran.feminin(journal.adresse == Journal.TSADEKET);
        try {
            textes = Textes.charge(Mots.langue);
        } catch (Exception e) {
            display.setCurrent(new Alert("MyHitbodedut", Mots.m(Mots.ILLISIBLES, e.getMessage()), null, AlertType.ERROR));
            return;
        }
        creeCommandes();
        construitAccueil();
        reprogrammeRappel();
        if (appeleParRappel()) {
            Alert a = new Alert(textes.mot("reminder_title"), textes.mot("reminder_title") + ".", null, AlertType.INFO);
            a.setTimeout(Alert.FOREVER);
            display.setCurrent(a, accueil);
        } else {
            display.setCurrent(accueil);
        }
    }

    protected void pauseApp() {
    }

    protected void destroyApp(boolean inconditionnel) {
        // callSerially ne passerait plus : les minutes faites s'inscrivent ici, tout de suite.
        Minuteur m = minuteur;
        minuteur = null;
        if (m != null) {
            journal.ajoute(jourDebut, m.coupe());
            journal.ecrit();
        }
        if (musique != null) musique.arrete();
    }

    private void ecoute(Displayable d, Command[] commandes) {
        for (int i = 0; i < commandes.length; i++) d.addCommand(commandes[i]);
        d.setCommandListener(this);
    }

    // --- Accueil -------------------------------------------------------------------
    private void construitAccueil() {
        accueil = new Menu("MyHitbodedut", new String[] {Mots.m(Mots.HITBODEDOUT), Mots.m(Mots.MUSIQUE), Mots.m(Mots.HIZOUK),
            Mots.m(Mots.JOURNAL), Mots.m(Mots.RAPPEL), Mots.m(Mots.APPEL), Mots.m(Mots.LANGUE)}, this);
        accueil.haut = new Menu.Haut() {
            public int dessine(Graphics g, int y, int w) {
                return enteteAccueil(g, y, w);
            }
        };
        metAJourAccueil();
        ecoute(accueil, new Command[] {choisir, quitter});
    }

    private void metAJourAccueil() {
        int n = 0;
        for (int i = 0; i < textes.textes.length; i++) n += textes.textes[i].length;
        accueil.details = new String[] {
            Mots.m(Mots.DETAIL_DUREES, Regles.duree(DUREES[0]), Regles.duree(DUREES[DUREES.length - 1])),
            Mots.m(musique != null && musique.joue() ? Mots.EN_LECTURE : Mots.ESSAI, Mots.m(Mots.NIGGOUN)),
            Mots.m(Mots.DETAIL_TEXTES, String.valueOf(n)),
            Mots.m(Mots.DETAIL_JOURNAL),
            journal.rappel >= 0 ? Mots.m(Mots.CHAQUE_JOUR, Regles.heure(journal.rappel)) : Mots.m(Mots.PAS_DE_RAPPEL),
            Mots.adresse(journal.adresse),
            Mots.NOMS[Mots.langue],
        };
    }

    private void montreAccueil() {
        metAJourAccueil();
        display.setCurrent(accueil);
        accueil.repaint();
    }

    /** Le personnage du jour, l'état de la hitbodedout, la série et la semaine ; en hébreu, en miroir. */
    private int enteteAccueil(Graphics g, int y, int w) {
        int auj = journal.minutesDu(Journal.aujourdhui());
        int d = 76;
        boolean r = Ecran.rtl();
        Ecran.plaque(g, auj > 0 ? Ecran.duJour(Ecran.JOIE, 3) : Ecran.duJour(Ecran.ACCUEIL, 0), Ecran.mx(Ecran.MARGE, d, w) + d / 2, y, d);
        int x = r ? w - Ecran.MARGE - d - 10 : Ecran.MARGE + d + 10;
        int a = Graphics.TOP | Ecran.debut();
        g.setFont(Ecran.PETITE);
        g.setColor(Ecran.MUTED);
        g.drawString(Mots.m(Mots.DU_JOUR), x, y + 2, a);
        g.setFont(Ecran.GRANDE);
        g.setColor(auj > 0 ? Ecran.BRAND : Ecran.WARNING);
        g.drawString(auj > 0 ? Mots.m(Mots.FAITE, Regles.duree(auj)) : Mots.m(Mots.A_FAIRE), x, y + 2 + Ecran.PETITE.getHeight(), a);
        int s = journal.serie();
        g.setFont(Ecran.PETITE);
        g.setColor(Ecran.INK);
        int ys = y + 4 + Ecran.PETITE.getHeight() + Ecran.GRANDE.getHeight();
        g.drawString(Mots.m(Mots.SERIE_N, Mots.jours(s)), x, ys, a);

        // La semaine : un carré par jour, plein quand la hitbodedout est faite ; en hébreu, de droite à gauche.
        int place = r ? x - Ecran.MARGE : w - x - Ecran.MARGE;
        int c = Math.min(16, (place - 6 * 3) / 7);
        int yc = ys + Ecran.PETITE.getHeight() + 4;
        Calendar cal = Calendar.getInstance();
        for (int k = 0; k < 7; k++) {
            cal.setTime(new Date(System.currentTimeMillis() - (6 - k) * 86400000L));
            boolean fait = journal.minutesDu(Journal.jour(cal.getTime())) > 0;
            int cx = r ? x - c - k * (c + 3) : x + k * (c + 3);
            g.setColor(fait ? Ecran.BRAND : Ecran.DAY_TODO);
            g.fillRoundRect(cx, yc, c, c, 5, 5);
            if (k == 6) {
                g.setColor(Ecran.BRAND);
                g.drawRoundRect(cx - 1, yc - 1, c + 1, c + 1, 6, 6);
            }
            g.setColor(fait ? 0xFFFFFF : Ecran.MUTED);
            g.drawString(Mots.initiale(cal.get(Calendar.DAY_OF_WEEK) - 1), cx + c / 2, yc + (c - Ecran.PETITE.getHeight()) / 2 + 1, Graphics.TOP | Graphics.HCENTER);
        }
        return Math.max(d, yc + c - y);
    }

    // --- Hitbodedout ---------------------------------------------------------------------
    private void choisitDuree() {
        if (durees == null) {
            String[] items = new String[DUREES.length + 1];
            for (int i = 0; i < DUREES.length; i++) items[i] = Regles.duree(DUREES[i]);
            items[DUREES.length] = Mots.m(Mots.AU_CHOIX);
            durees = new Menu(Mots.m(Mots.DUREE), items, this);
            durees.personnage = "praying";
            ecoute(durees, new Command[] {choisir, retour});
        }
        display.setCurrent(durees);
    }

    private void demandeAuChoix() {
        auChoix = new TextBox(Mots.m(Mots.MINUTES), "20", 3, TextField.NUMERIC);
        ecoute(auChoix, new Command[] {ok, retour});
        display.setCurrent(auChoix);
    }

    /** Avant de commencer : un texte « Pour commencer », puis le décompte. */
    private void prepare(int minutes) {
        dureeChoisie = minutes;
        int m = textes.moment("ouverture");
        int t = m < 0 ? -1 : textes.tire(m);
        avant = new Lecture(Mots.m(Mots.TITRE_PREPARE, Regles.duree(minutes)), "open_arms", null,
            t < 0 ? null : textes.hebreu[m][t], t < 0 ? null : textes.textes[m][t], t < 0 ? null : textes.refs[m][t]);
        avant.action = new Lecture.Action() {
            public void centre(Lecture l) {
                lance();
            }
        };
        ecoute(avant, new Command[] {commencer, retour});
        display.setCurrent(avant);
    }

    /** Le jour où la hitbodedout a commencé : c'est lui qui la reçoit, même finie après minuit (comme Android). */
    private int jourDebut;

    private void lance() {
        jourDebut = Journal.aujourdhui();
        minuteur = new Minuteur(dureeChoisie, this);
        ecoute(minuteur, new Command[] {pause, bloque, arreter});
        display.setCurrent(minuteur);
        minuteur.demarre();
    }

    /** La touche écran dit ce qu'elle fera : « Pause » ou « Reprendre ». */
    private void basculePause() {
        Minuteur m = minuteur;
        if (m == null) return;
        m.basculePause();
        suitPause();
    }

    public void pauseBasculee() {
        suitPause();
    }

    private void suitPause() {
        if (minuteur == null) return;
        minuteur.removeCommand(minuteur.enPause() ? pause : reprendre);
        minuteur.addCommand(minuteur.enPause() ? reprendre : pause);
    }

    /** Appelé par le minuteur, depuis son propre fil. */
    public void finie(final int minutes) {
        final boolean complete = minuteur != null && minuteur.restant() == 0;
        display.callSerially(new Runnable() {
            public void run() {
                termine(minutes, complete);
            }
        });
    }

    private void termine(int minutes, boolean complete) {
        minuteur = null;
        journal.ajoute(jourDebut, minutes);
        journal.ecrit();
        reprogrammeRappel();
        if (complete) sonne();
        int m = textes.moment("cloture");
        int t = m < 0 ? -1 : textes.tire(m);
        String bilan = minutes > 0 ? Mots.m(Mots.BILAN, Mots.bravo(journal.adresse), Regles.duree(minutes)) : Mots.m(Mots.MOINS_D_UNE_MINUTE);
        fin = new Lecture(textes.mot("session_done_title"), minutes > 0 ? Ecran.duJour(Ecran.JOIE, 3) : "walking", bilan,
            t < 0 ? null : textes.hebreu[m][t], t < 0 ? null : textes.textes[m][t], t < 0 ? null : textes.refs[m][t]);
        fin.action = new Lecture.Action() {
            public void centre(Lecture l) {
                montreAccueil();
            }
        };
        ecoute(fin, new Command[] {accueilCmd});
        display.setCurrent(fin);
    }

    private void sonne() {
        try {
            display.vibrate(1500);
        } catch (Throwable t) {
            // pas de vibreur
        }
        try {
            Manager.playTone(76, 700, 80);
        } catch (Throwable t) {
            AlertType.ALARM.playSound(display);
        }
    }

    // --- ’Hizouk ---------------------------------------------------------------------------
    private void montreMoments() {
        if (moments == null) {
            int n = textes.titres.length;
            moments = new Menu(Mots.m(Mots.HIZOUK), textes.titres, this);
            moments.details = new String[n];
            moments.personnages = new String[n];
            for (int i = 0; i < n; i++) {
                int k = textes.textes[i].length;
                moments.details[i] = Mots.textes(k);
                moments.personnages[i] = Ecran.duMoment(textes.cles[i]);
            }
            ecoute(moments, new Command[] {choisir, retour});
        }
        display.setCurrent(moments);
    }

    private void montreListe(int moment) {
        momentOuvert = moment;
        int n = textes.refs[moment].length;
        liste = new Menu(textes.titres[moment], textes.refs[moment], this);
        liste.personnage = Ecran.duMoment(textes.cles[moment]);
        liste.details = new String[n];
        for (int i = 0; i < n; i++) liste.details[i] = textes.apercu(moment, i);
        ecoute(liste, new Command[] {choisir, retour});
        display.setCurrent(liste);
    }

    private void lit(int moment, int texte, Displayable ensuite) {
        momentOuvert = moment;
        texteOuvert = texte;
        apresLecture = ensuite;
        lecture = new Lecture(textes.titres[moment], Ecran.duMoment(textes.cles[moment]), null,
            textes.hebreu[moment][texte], textes.textes[moment][texte], textes.refs[moment][texte]);
        if (textes.textes[moment].length > 1) {
            lecture.action = new Lecture.Action() {
                public void centre(Lecture l) {
                    texteSuivant();
                }
            };
            ecoute(lecture, new Command[] {retour, autre});
        } else {
            ecoute(lecture, new Command[] {retour});
        }
        display.setCurrent(lecture);
    }

    private void texteSuivant() {
        lit(momentOuvert, (texteOuvert + 1) % textes.textes[momentOuvert].length, apresLecture);
    }

    // --- Musique -------------------------------------------------------------------------
    private void montreMusique() {
        if (musique == null) {
            musique = new Musique();
            ecoute(musique, new Command[] {lecturePause, retour});
        }
        display.setCurrent(musique);
    }

    // --- Journal ------------------------------------------------------------------------
    private void montreJournal() {
        journalEcran = new JournalEcran(journal, textes.mot("journal_empty"));
        ecoute(journalEcran, new Command[] {retour});
        display.setCurrent(journalEcran);
    }

    // --- Rappel -------------------------------------------------------------------------
    private void montreRappel() {
        reglage = new Form(Mots.m(Mots.RAPPEL));
        actif = new ChoiceGroup(null, ChoiceGroup.MULTIPLE);
        actif.append(Mots.m(Mots.ME_RAPPELER), null);
        actif.setSelectedIndex(0, journal.rappel >= 0);
        reglage.append(actif);
        heure = new DateField(Mots.m(Mots.HEURE), DateField.TIME);
        int m = journal.rappel >= 0 ? journal.rappel : 20 * 60;
        // MIDP : un champ TIME attend le 1er janvier 1970 ; une autre date le laisse « non initialisé »
        // sur un vrai téléphone, et l'enregistrement désactivait le rappel.
        Calendar c = Calendar.getInstance();
        c.setTime(new Date(0));
        c.set(Calendar.YEAR, 1970);
        c.set(Calendar.MONTH, Calendar.JANUARY);
        c.set(Calendar.DAY_OF_MONTH, 1);
        c.set(Calendar.HOUR_OF_DAY, m / 60);
        c.set(Calendar.MINUTE, m % 60);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        heure.setDate(c.getTime());
        reglage.append(heure);
        reglage.append(Mots.m(Mots.RAPPEL_AIDE));
        ecoute(reglage, new Command[] {enregistrer, retour});
        display.setCurrent(reglage);
    }

    private void enregistreRappel() {
        if (actif.isSelected(0) && heure.getDate() != null) {
            Calendar c = Calendar.getInstance();
            c.setTime(heure.getDate());
            journal.rappel = c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE);
        } else {
            journal.rappel = -1;
        }
        journal.ecrit();
        String resultat = reprogrammeRappel();
        metAJourAccueil();
        Alert a = new Alert(Mots.m(Mots.RAPPEL), resultat, null, AlertType.CONFIRMATION);
        a.setTimeout(3000);
        display.setCurrent(a, accueil);
    }

    /** Une alarme ne sonne qu'une fois : on la reprogramme à chaque ouverture. */
    private String reprogrammeRappel() {
        try {
            long quand = journal.rappel >= 0
                ? Regles.prochain(journal.rappel, System.currentTimeMillis(), journal.minutesDu(Journal.aujourdhui()) > 0) : 0;
            PushRegistry.registerAlarm(getClass().getName(), quand);
            return journal.rappel >= 0 ? Mots.m(Mots.RAPPEL_ACTIF, Regles.heure(journal.rappel)) : Mots.m(Mots.RAPPEL_COUPE);
        } catch (Throwable t) {
            return Mots.m(Mots.RAPPEL_REFUSE);
        }
    }

    private boolean appeleParRappel() {
        if (journal.rappel < 0 || journal.minutesDu(Journal.aujourdhui()) > 0) return false;
        Calendar c = Calendar.getInstance();
        int maintenant = c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE);
        int ecart = maintenant - journal.rappel;
        return ecart >= 0 && ecart <= 2;
    }


    // --- Comment vous appeler ---------------------------------------------------------------
    private void montreAppel() {
        appel = new Form(Mots.m(Mots.APPEL));
        adresse = new ChoiceGroup(Mots.m(Mots.COMMENT_APPELER), ChoiceGroup.EXCLUSIVE);
        adresse.append(Mots.adresse(Journal.TSADIK), null);
        adresse.append(Mots.adresse(Journal.TSADEKET), null);
        adresse.append(Mots.adresse(Journal.PAS_CHOISI), null);
        adresse.setSelectedIndex(journal.adresse == Journal.TSADIK ? 0 : journal.adresse == Journal.TSADEKET ? 1 : 2, true);
        appel.append(adresse);
        appel.append(Mots.m(Mots.APPEL_AIDE));
        ecoute(appel, new Command[] {enregistrer, retour});
        display.setCurrent(appel);
    }

    private void enregistreAppel() {
        int i = adresse.getSelectedIndex();
        journal.adresse = i == 0 ? Journal.TSADIK : i == 1 ? Journal.TSADEKET : Journal.PAS_CHOISI;
        journal.ecrit();
        Ecran.feminin(journal.adresse == Journal.TSADEKET);
        // Les écrans gardés en mémoire redessinent leur personnage à la prochaine ouverture.
        montreAccueil();
    }

    // --- Langue ------------------------------------------------------------------------------
    /** Les trois langues, chacune écrite dans sa langue, avec ce qu'elle montre des textes. */
    private void montreLangues() {
        langues = new Menu(Mots.m(Mots.LANGUE), Mots.NOMS, this);
        langues.details = Mots.CONTENU;
        langues.personnage = "open_arms";
        langues.selection = Mots.langue;
        ecoute(langues, new Command[] {choisir, retour});
        display.setCurrent(langues);
    }

    /**
     * Change la langue : gardée à part du journal, puis textes relus et écrans
     * refaits (les menus gardés en mémoire, les touches écran). Une
     * hitbodedout ne peut pas être en cours : on vient de l'accueil.
     */
    private void changeLangue(int l) {
        if (l != Mots.langue) {
            int avantChoix = Mots.langue;
            Mots.ecrit(l);
            try {
                textes = Textes.charge(l);
            } catch (Exception e) {
                Mots.ecrit(avantChoix);
                display.setCurrent(new Alert("MyHitbodedut", Mots.m(Mots.ILLISIBLES, e.getMessage()), null, AlertType.ERROR), accueil);
                return;
            }
            Command[] anciennes = {lecturePause, retour};
            creeCommandes();
            if (musique != null) {
                for (int i = 0; i < anciennes.length; i++) musique.removeCommand(anciennes[i]);
                ecoute(musique, new Command[] {lecturePause, retour});
            }
            durees = null;
            moments = null;
            liste = null;
            construitAccueil();
        }
        montreAccueil();
    }

    // --- Choix dans les menus et commandes ----------------------------------------------------
    public void choisi(Menu m, int i) {
        if (m == accueil) {
            if (i == 0) choisitDuree();
            else if (i == 1) montreMusique();
            else if (i == 2) montreMoments();
            else if (i == 3) montreJournal();
            else if (i == 4) montreRappel();
            else if (i == 5) montreAppel();
            else montreLangues();
        } else if (m == durees) {
            if (i < DUREES.length) prepare(DUREES[i]);
            else demandeAuChoix();
        } else if (m == moments) {
            montreListe(i);
        } else if (m == liste) {
            lit(momentOuvert, i, liste);
        } else if (m == langues) {
            changeLangue(i);
        }
    }

    public void commandAction(Command c, Displayable d) {
        if (c == quitter) {
            notifyDestroyed();
        } else if (c == choisir && d instanceof Menu) {
            choisi((Menu) d, ((Menu) d).selection);
        } else if (d == auChoix && c == ok) {
            int m = 0;
            try {
                m = Integer.parseInt(auChoix.getString());
            } catch (NumberFormatException e) {
                // reste à 0
            }
            if (m >= 1 && m <= 180) prepare(m);
        } else if (d == auChoix || d == avant) {
            if (c == commencer) lance();
            else display.setCurrent(durees);
        } else if (d == minuteur) {
            if (c == pause || c == reprendre) basculePause();
            else if (c == arreter) minuteur.arrete();
            else if (c == bloque) {
                int m = textes.moment("blocage");
                if (m >= 0) lit(m, textes.tire(m), minuteur);
            }
        } else if (d == lecture) {
            if (c == autre) texteSuivant();
            else display.setCurrent(apresLecture);
        } else if (d == liste) {
            display.setCurrent(moments);
        } else if (d == musique && c == lecturePause) {
            musique.bascule();
        } else if (d == reglage && c == enregistrer) {
            enregistreRappel();
        } else if (d == appel && c == enregistrer) {
            enregistreAppel();
        } else {
            montreAccueil();
        }
    }
}
