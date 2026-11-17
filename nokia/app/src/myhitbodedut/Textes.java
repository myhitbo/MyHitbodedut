package myhitbodedut;

import java.io.DataInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Hashtable;
import java.util.Random;

/**
 * Les textes de ’hizouk, rangés par moment, dans la langue de l'interface.
 * Ils viennent de /textes.bin (français, anglais, hébreu), produit depuis
 * les ressources Android par nokia/textes.mjs.
 *
 * La règle des langues (RegleLangue sur Android) : on ne garde que
 * l'hébreu et la langue de l'interface. En hébreu, l'hébreu seul ; en
 * anglais ou en français, l'hébreu et sa traduction. Les autres langues
 * sont sautées à la lecture, sans être chargées.
 */
final class Textes {
    final Hashtable mots = new Hashtable();
    String[] cles;
    /** Dans la langue de l'interface. */
    String[] titres;
    /** Les références, dans la langue de l'interface. */
    String[][] refs;
    /** L'hébreu original de chaque texte. */
    String[][] hebreu;
    /** Sa traduction dans la langue de l'interface ; null en hébreu (rien d'autre que l'hébreu). */
    String[][] textes;
    private final Random hasard = new Random();
    private final Hashtable derniers = new Hashtable();

    /** Lit textes.bin pour la langue de l'interface (Mots.FR, EN ou HE). */
    static Textes charge(int langue) throws IOException {
        InputStream in = Textes.class.getResourceAsStream("/textes.bin");
        if (in == null) throw new IOException("textes.bin absent");
        DataInputStream d = new DataInputStream(in);
        try {
            Textes t = new Textes();
            if (d.readShort() != 2) throw new IOException("textes.bin : version inconnue");
            int nl = d.readShort();
            // Pour chaque langue du fichier : est-ce celle de l'interface, est-ce l'hébreu ?
            boolean[] interfaceL = new boolean[nl];
            boolean[] hebreuL = new boolean[nl];
            String code = Mots.CODES[langue];
            for (int l = 0; l < nl; l++) {
                String c = d.readUTF();
                interfaceL[l] = c.equals(code);
                hebreuL[l] = c.equals("he");
            }
            int n = d.readShort();
            for (int i = 0; i < n; i++) {
                String cle = d.readUTF();
                for (int l = 0; l < nl; l++) {
                    if (interfaceL[l]) t.mots.put(cle, d.readUTF());
                    else saute(d);
                }
            }
            int m = d.readShort();
            t.cles = new String[m];
            t.titres = new String[m];
            t.refs = new String[m][];
            t.hebreu = new String[m][];
            t.textes = new String[m][];
            boolean traduit = langue != Mots.HE;
            for (int i = 0; i < m; i++) {
                t.cles[i] = d.readUTF();
                for (int l = 0; l < nl; l++) {
                    if (interfaceL[l]) t.titres[i] = d.readUTF();
                    else saute(d);
                }
                int k = d.readShort();
                t.refs[i] = new String[k];
                t.hebreu[i] = new String[k];
                t.textes[i] = new String[k];
                for (int j = 0; j < k; j++) {
                    for (int l = 0; l < nl; l++) {
                        if (interfaceL[l]) t.refs[i][j] = d.readUTF();
                        else saute(d);
                        if (hebreuL[l]) t.hebreu[i][j] = d.readUTF();
                        else if (interfaceL[l] && traduit) t.textes[i][j] = vide(d.readUTF());
                        else saute(d);
                    }
                }
            }
            return t;
        } finally {
            d.close();
        }
    }

    /** Une chaîne d'une langue qu'on ne montre pas : passée sans être lue. */
    private static void saute(DataInputStream d) throws IOException {
        // skipBytes peut sauter moins que demandé (flux d'une ressource du .jar).
        for (int n = d.readUnsignedShort(); n > 0;) {
            int s = d.skipBytes(n);
            if (s <= 0) {
                d.readByte();
                s = 1;
            }
            n -= s;
        }
    }

    /** Une traduction absente ne s'affiche pas (pas de repli sur une autre langue). */
    private static String vide(String s) {
        return s.length() == 0 ? null : s;
    }

    /** Le début d'un texte pour une liste : la traduction, ou l'hébreu en hébreu. */
    String apercu(int moment, int texte) {
        String s = textes[moment][texte] != null ? textes[moment][texte] : hebreu[moment][texte];
        return s.length() <= 40 ? s : s.substring(0, 40);
    }

    String mot(String cle) {
        Object v = mots.get(cle);
        return v == null ? cle : (String) v;
    }

    /** L'indice d'un moment ("ouverture", "blocage"...), ou -1. */
    int moment(String cle) {
        for (int i = 0; i < cles.length; i++) if (cles[i].equals(cle)) return i;
        return -1;
    }

    /** Un texte du moment au hasard, jamais deux fois de suite le même. */
    int tire(int moment) {
        int n = textes[moment].length;
        if (n <= 1) return 0;
        Integer avant = (Integer) derniers.get(cles[moment]);
        int j;
        do {
            j = (hasard.nextInt() >>> 1) % n;
        } while (avant != null && avant.intValue() == j);
        derniers.put(cles[moment], new Integer(j));
        return j;
    }
}
