package myhitbodedut;

import java.util.Vector;
import javax.microedition.lcdui.Graphics;

/**
 * Un texte à lire : le personnage du moment, une phrase mise en avant
 * (le bilan d'une hitbodedout), le texte et sa référence. Haut et bas
 * font défiler ; la touche centrale fait l'action principale de l'écran.
 * La touche 0 lance ou arrête le défilement automatique ; en marche,
 * * (ou gauche) le ralentit, # (ou droite) l'accélère ; haut ou bas le
 * suspend, et il s'arrête seul au bout du texte.
 *
 * Le texte est l'hébreu, aligné à droite, puis sa traduction dans la
 * langue de l'interface (aucune en hébreu : RegleLangue).
 */
final class Lecture extends Ecran {
    interface Action {
        void centre(Lecture l);
    }

    final String titre;
    final String personnage;
    final String accroche;
    final String hebreu;
    final String texte;
    final String reference;
    Action action;
    private int decalage;
    private int hauteurTotale;

    Lecture(String titre, String personnage, String accroche, String hebreu, String texte, String reference) {
        this.titre = titre;
        this.personnage = personnage;
        this.accroche = accroche;
        this.hebreu = hebreu;
        this.texte = texte;
        this.reference = reference;
    }

    // --- Défilement automatique (Defilement) ----------------------------------------
    // Le minuteur avance decalage depuis son propre fil ; paint et les touches le lisent
    // depuis celui de l'écran : tout ce qui suit se touche sous le verrou de l'écran.
    private final Defilement defilement = new Defilement();
    private java.util.Timer minuteur;
    private boolean auto;
    private long dernierTic;

    /** Le décalage le plus grand : le bas du texte touche le bas de l'écran. */
    private int maximum() {
        return Math.max(0, hauteurTotale - getHeight() + 8);
    }

    private synchronized void demarreAuto() {
        if (auto) return;
        mise(getWidth(), getHeight());
        int max = maximum();
        if (max <= 0) return; // le texte tient dans l'écran : rien à faire défiler
        if (decalage >= max) decalage = 0; // déjà au bout : on repart du début
        auto = true;
        defilement.remetAZero();
        dernierTic = System.currentTimeMillis();
        minuteur = new java.util.Timer();
        minuteur.schedule(new java.util.TimerTask() {
            public void run() {
                tic();
            }
        }, Defilement.TIC, Defilement.TIC);
    }

    private synchronized void arreteAuto() {
        auto = false;
        if (minuteur != null) minuteur.cancel();
        minuteur = null;
    }

    /** Un pas du minuteur, depuis son fil : quelques pixels, et l'arrêt au bout du texte. */
    private void tic() {
        synchronized (this) {
            if (!auto) return;
            long maintenant = System.currentTimeMillis();
            int px = defilement.avance(Defilement.vitesse(), maintenant - dernierTic);
            dernierTic = maintenant;
            int max = maximum();
            decalage = Math.min(max, decalage + px);
            if (decalage >= max) arreteAuto();
            else if (px == 0) return;
        }
        repaint();
    }

    /** Écran caché (autre écran, appel, menu du téléphone) : le défilement s'arrête et le cran est gardé. */
    protected void hideNotify() {
        arreteAuto();
        Defilement.enregistre();
    }

    protected void touche(int code) {
        if (code == KEY_NUM0) {
            boolean marche;
            synchronized (this) {
                marche = auto;
            }
            if (marche) {
                arreteAuto();
                Defilement.enregistre();
            } else {
                demarreAuto();
            }
            repaint();
            return;
        }
        int a = jeu(code);
        boolean marche;
        synchronized (this) {
            marche = auto;
        }
        if (marche && (code == KEY_STAR || code == KEY_POUND || a == LEFT || a == RIGHT)) {
            Defilement.change(code == KEY_POUND || (code != KEY_STAR && a == RIGHT) ? 1 : -1);
            repaint();
            return;
        }
        int pas = MOYENNE.getHeight() * 3;
        if (a == UP || a == DOWN) {
            // La main reprend : le défilement automatique s'arrête, la flèche fait son pas.
            arreteAuto();
            synchronized (this) {
                int max = maximum();
                if (a == DOWN) decalage = Math.min(max, decalage + pas);
                else decalage = Math.max(0, decalage - pas);
            }
        } else if (a == FIRE && action != null) {
            arreteAuto();
            action.centre(this);
        }
        repaint();
    }

    // --- Mise en page, gardée tant que l'écran garde sa taille (le minuteur redessine 20 fois par seconde) ---
    private int miseLargeur = -1, miseHauteur = -1;
    private Vector lignesAccroche;
    private Vector lignesHebreu;
    private Vector lignesTexte;
    private int hCarte;
    private boolean aide;

    private synchronized void mise(int w, int h) {
        if (w == miseLargeur && h == miseHauteur) return;
        miseLargeur = w;
        miseHauteur = h;
        int large = w - 2 * MARGE;
        lignesAccroche = accroche == null ? null : coupe(accroche, large, GRANDE);
        lignesHebreu = hebreu == null ? null : coupe(hebreu, large - 16, MOYENNE);
        lignesTexte = texte == null ? null : coupe(texte, large - 16, MOYENNE);
        boolean carte = lignesHebreu != null || lignesTexte != null;
        int hTextes = (lignesHebreu == null ? 0 : lignesHebreu.size()) * MOYENNE.getHeight()
            + (lignesTexte == null ? 0 : lignesTexte.size()) * MOYENNE.getHeight()
            + (lignesHebreu != null && lignesTexte != null ? 9 : 0);
        hCarte = !carte ? 0 : hTextes + 16 + (reference != null ? PETITE.getHeight() + 8 : 0);
        int y = GRASSE.getHeight() + 10 + 8; // sous le bandeau
        if (personnage != null) y += 84 + 6;
        if (lignesAccroche != null) y += lignesAccroche.size() * GRANDE.getHeight() + 6;
        if (carte) y += hCarte + 8;
        // L'aide (« 0 : défilement auto... ») seulement quand le texte dépasse l'écran.
        aide = carte && y > h;
        if (aide) y += PETITE.getHeight() + 6;
        hauteurTotale = y; // en coordonnées du contenu, sans le défilement
        if (decalage > maximum()) decalage = maximum();
    }

    protected void paint(Graphics g) {
        int w = getWidth();
        int h = getHeight();
        mise(w, h);
        int decalage;
        boolean auto;
        synchronized (this) {
            decalage = this.decalage;
            auto = this.auto;
        }
        g.setColor(PAPER);
        g.fillRect(0, 0, w, h);
        // En marche, le cran du défilement dans le bandeau (à droite, ou à gauche en hébreu).
        int hb = bandeau(g, w, titre, auto ? Mots.m(Mots.DEFIL_CRAN, String.valueOf(Defilement.vitesse()), String.valueOf(Defilement.MAX)) : null);
        g.setClip(0, hb, w, h - hb);
        g.translate(0, -decalage);

        int y = hb + 8;
        if (personnage != null) y += plaque(g, personnage, w / 2, y, 84) + 6;
        int large = w - 2 * MARGE;
        if (lignesAccroche != null) {
            g.setColor(BRAND);
            g.setFont(GRANDE);
            for (int i = 0; i < lignesAccroche.size(); i++) {
                g.drawString((String) lignesAccroche.elementAt(i), MARGE + large / 2, y, Graphics.TOP | Graphics.HCENTER);
                y += GRANDE.getHeight();
            }
            y += 6;
        }
        if (aide) {
            g.setColor(MUTED);
            g.setFont(PETITE);
            g.drawString(tronque(Mots.m(Mots.DEFIL_AIDE), large, PETITE), MARGE + large / 2, y, Graphics.TOP | Graphics.HCENTER);
            y += PETITE.getHeight() + 6;
        }
        if (lignesHebreu != null || lignesTexte != null) {
            // Le texte sur une carte blanche, la référence en dessous. La barre verte
            // est au début de la ligne : à gauche, ou à droite en hébreu.
            boolean r = rtl();
            int lt = large - 16;
            g.setColor(CARD);
            g.fillRoundRect(MARGE, y, large, hCarte, 12, 12);
            g.setColor(BRAND);
            g.fillRect(r ? MARGE + large - 3 : MARGE, y + 8, 3, hCarte - 16);
            int ty = y + 8;
            int tx = r ? MARGE + 6 : MARGE + 10;
            g.setColor(INK);
            // L'hébreu se lit de droite à gauche, quelle que soit la langue de l'interface.
            if (lignesHebreu != null) ty = visibles(g, lignesHebreu, tx, ty, lt, true, decalage + hb, decalage + h);
            if (lignesHebreu != null && lignesTexte != null) {
                g.setColor(LINE);
                g.drawLine(tx, ty + 4, tx + lt, ty + 4);
                g.setColor(INK);
                ty += 9;
            }
            if (lignesTexte != null) ty = visibles(g, lignesTexte, tx, ty, lt, false, decalage + hb, decalage + h);
            if (reference != null) {
                g.setColor(BRAND);
                g.setFont(PETITE);
                // À la fin de la ligne : à droite, ou à gauche en hébreu.
                if (r) g.drawString(tronque(reference, large - 20, PETITE), MARGE + 8, ty + 6, Graphics.TOP | Graphics.LEFT);
                else g.drawString(tronque(reference, large - 20, PETITE), MARGE + large - 8, ty + 6, Graphics.TOP | Graphics.RIGHT);
            }
        }
        g.translate(0, decalage);
        g.setClip(0, 0, w, h);

        // L'ascenseur : où l'on en est dans un texte long.
        if (hauteurTotale > h) {
            int zone = h - hb - 8;
            int taille = Math.max(12, zone * (h - hb) / (hauteurTotale - hb));
            int pos = hb + 4 + (zone - taille) * decalage / Math.max(1, hauteurTotale - h + 8);
            int ax = rtl() ? 1 : w - 4;
            g.setColor(LINE);
            g.fillRect(ax, hb + 4, 3, zone);
            g.setColor(BRAND);
            g.fillRect(ax, pos, 3, taille);
        }
    }

    /**
     * Comme Ecran.lignes (à gauche, ou à droite pour l'hébreu), mais n'écrit
     * que les lignes entre haut et bas : le défilement redessine souvent.
     * Renvoie le y suivant.
     */
    private static int visibles(Graphics g, Vector lignes, int x, int y, int largeur, boolean droite, int haut, int bas) {
        g.setFont(MOYENNE);
        int lh = MOYENNE.getHeight();
        for (int i = 0; i < lignes.size(); i++) {
            if (y + lh > haut && y < bas) {
                String l = (String) lignes.elementAt(i);
                if (droite) g.drawString(l, x + largeur, y, Graphics.TOP | Graphics.RIGHT);
                else g.drawString(l, x, y, Graphics.TOP | Graphics.LEFT);
            }
            y += lh;
        }
        return y;
    }
}
