package myhitbodedut;

import java.util.Calendar;
import java.util.Date;

/**
 * Les règles de l'application Java qui ne touchent pas l'écran : durées,
 * horloge, journal, prochain rappel. Tourne sur un JDK ordinaire.
 *
 *   java -cp classes:api myhitbodedut.TestsRegles
 */
public final class TestsRegles {
    private static int echecs;

    static void egal(Object attendu, Object obtenu, String quoi) {
        if (attendu == null ? obtenu != null : !attendu.equals(obtenu)) {
            echecs++;
            System.out.println("ÉCHEC " + quoi + " : attendu " + attendu + ", obtenu " + obtenu);
        } else {
            System.out.println("ok " + quoi);
        }
    }

    public static void main(String[] args) throws Exception {
        egal("5 min", Regles.duree(5), "5 min");
        egal("1 h", Regles.duree(60), "1 h");
        egal("1 h 30", Regles.duree(90), "1 h 30");
        egal("2 h 05", Regles.duree(125), "2 h 05");
        egal("20 h 05", Regles.heure(20 * 60 + 5), "heure du rappel");

        egal("5:00", Regles.horloge(300000), "horloge 5 min");
        egal("0:01", Regles.horloge(1), "une milliseconde se lit 0:01");
        egal("1:30:00", Regles.horloge(90 * 60000L), "horloge 1 h 30");
        egal("1:00:05", Regles.horloge(3605000L), "horloge 1 h 00 min 05");

        // Le journal survit à l'écriture et à la relecture.
        Journal j = new Journal();
        j.rappel = 20 * 60;
        j.ajoute(Journal.aujourdhui(), 15);
        j.ajoute(Journal.aujourdhui(), 5);
        j.ajoute(Journal.ilYa(1), 10);
        j.ajoute(Journal.ilYa(3), 10);
        j.ajoute(Journal.ilYa(4), 0);
        Journal r = Journal.depuisOctets(j.versOctets());
        egal(new Integer(20), new Integer(r.minutesDu(Journal.aujourdhui())), "minutes du jour cumulées");
        egal(new Integer(20 * 60), new Integer(r.rappel), "heure du rappel relue");
        egal(new Integer(3), new Integer(r.joursFaits()), "une journée à 0 min ne compte pas");
        egal(new Integer(40), new Integer(r.totalMinutes()), "total");
        // Un Chabbat vide ne casse pas la série : si avant-hier est un samedi, la série va jusqu'au jour 3.
        egal(new Integer(Journal.chabbat(Journal.ilYa(2)) ? 3 : 2), new Integer(r.serie()), "série : aujourd'hui et hier");

        // Comment vous appeler : relu, et un journal de la version 1 (sans ce choix) reste « pas choisi ».
        egal(new Integer(Journal.PAS_CHOISI), new Integer(r.adresse), "adresse : pas choisi par défaut");
        j.adresse = Journal.TSADEKET;
        egal(new Integer(Journal.TSADEKET), new Integer(Journal.depuisOctets(j.versOctets()).adresse), "adresse Tsadeket relue");
        java.io.ByteArrayOutputStream o1 = new java.io.ByteArrayOutputStream();
        java.io.DataOutputStream d1 = new java.io.DataOutputStream(o1);
        d1.writeShort(1);
        d1.writeInt(7 * 60);
        d1.writeInt(1);
        d1.writeInt(Journal.aujourdhui());
        d1.writeInt(12);
        d1.close();
        Journal v1 = Journal.depuisOctets(o1.toByteArray());
        egal(new Integer(Journal.PAS_CHOISI), new Integer(v1.adresse), "journal version 1 : pas choisi");
        egal(new Integer(12), new Integer(v1.minutesDu(Journal.aujourdhui())), "journal version 1 : minutes relues");

        // Le défilement automatique : 10 crans, 3 par défaut, gardé dans le journal (version 3).
        egal(new Integer(Defilement.DEFAUT), new Integer(v1.vitesseDefilement), "journal version 1 : défilement au cran 3");
        egal(new Integer(3), new Integer(new Journal().vitesseDefilement), "défilement : cran 3 par défaut");
        j.vitesseDefilement = 7;
        egal(new Integer(7), new Integer(Journal.depuisOctets(j.versOctets()).vitesseDefilement), "défilement : cran 7 relu");
        egal(new Integer(Journal.TSADEKET), new Integer(Journal.depuisOctets(j.versOctets()).adresse), "version 3 : adresse toujours relue");
        String table = "";
        for (int n = 0; n <= 11; n++) table += Defilement.pixelsParSeconde(n) + " ";
        egal("6 6 8 12 16 23 32 45 63 88 124 124 ", table, "défilement : 6 × 1,4^(n-1) px/s, borné à 1..10");
        for (int n = 1; n <= 10; n++) {
            double attendu = 6 * Math.pow(1.4, n - 1);
            if (Math.abs(Defilement.pixelsParSeconde(n) - attendu) > 0.6) egal("" + Math.round(attendu), "" + Defilement.pixelsParSeconde(n), "cran " + n);
        }
        Defilement d = new Defilement();
        int px = 0;
        for (int i = 0; i < 20; i++) px += d.avance(1, 50); // une seconde au cran 1, par pas de 50 ms
        egal(new Integer(6), new Integer(px), "défilement lent : les fractions de pixel s'additionnent");
        egal(new Integer(124), new Integer(d.avance(10, 1000)), "cran 10 : 124 px en une seconde");
        egal(new Integer(6), new Integer(d.avance(1, 60000)), "téléphone endormi : pas plus d'une seconde d'un coup");
        Defilement.relit(null);
        egal(new Integer(3), new Integer(Defilement.vitesse()), "sans journal : cran 3");
        for (int i = 0; i < 12; i++) Defilement.change(1);
        egal(new Integer(10), new Integer(Defilement.vitesse()), "pas plus vite que le cran 10");
        for (int i = 0; i < 12; i++) Defilement.change(-1);
        egal(new Integer(1), new Integer(Defilement.vitesse()), "pas plus lent que le cran 1");

        Journal hier = new Journal();
        hier.ajoute(Journal.ilYa(1), 10);
        hier.ajoute(Journal.ilYa(2), 10);
        egal(new Integer(2), new Integer(hier.serie()), "la série tient tant qu'aujourd'hui n'est pas fini");

        // Le prochain rappel : aujourd'hui s'il est encore à venir, sinon demain.
        Calendar c = Calendar.getInstance();
        c.set(2026, Calendar.SEPTEMBER, 29, 18, 0, 0);
        c.set(Calendar.MILLISECOND, 0);
        long maintenant = c.getTime().getTime();
        Calendar p = Calendar.getInstance();
        p.setTime(new Date(Regles.prochain(20 * 60, maintenant)));
        egal("29 20:00", p.get(Calendar.DAY_OF_MONTH) + " " + p.get(Calendar.HOUR_OF_DAY) + ":" + p.get(Calendar.MINUTE) + "0", "rappel plus tard le jour même");
        p.setTime(new Date(Regles.prochain(7 * 60, maintenant)));
        egal("30 7:00", p.get(Calendar.DAY_OF_MONTH) + " " + p.get(Calendar.HOUR_OF_DAY) + ":" + p.get(Calendar.MINUTE) + "0", "rappel passé : demain");
        p.setTime(new Date(Regles.prochain(7 * 60, maintenant - 3600000L * 10, true)));
        egal("30 7:00", p.get(Calendar.DAY_OF_MONTH) + " " + p.get(Calendar.HOUR_OF_DAY) + ":" + p.get(Calendar.MINUTE) + "0", "déjà faite aujourd'hui : demain");
        // Vendredi 16/10/2026 à 18 h, rappel à 20 h : ni vendredi soir ni Chabbat, dimanche 18.
        c.set(2026, Calendar.OCTOBER, 16, 18, 0, 0);
        p.setTime(new Date(Regles.prochain(20 * 60, c.getTime().getTime())));
        egal("18 20:00", p.get(Calendar.DAY_OF_MONTH) + " " + p.get(Calendar.HOUR_OF_DAY) + ":" + p.get(Calendar.MINUTE) + "0", "pas de rappel vendredi soir ni Chabbat");
        // Jeudi 15/10 à 8 h, rappel à 7 h : vendredi matin reste permis.
        c.set(2026, Calendar.OCTOBER, 15, 8, 0, 0);
        p.setTime(new Date(Regles.prochain(7 * 60, c.getTime().getTime())));
        egal("16 7:00", p.get(Calendar.DAY_OF_MONTH) + " " + p.get(Calendar.HOUR_OF_DAY) + ":" + p.get(Calendar.MINUTE) + "0", "vendredi matin permis");

        if (echecs > 0) {
            System.out.println(echecs + " échec(s)");
            System.exit(1);
        }
        System.out.println("Tous les tests passent.");
    }
}
