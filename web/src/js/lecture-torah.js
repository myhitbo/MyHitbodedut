// La lecture de la Torah des offices de semaine (LectureTorah.kt, 26/11) : à Cha'harit le lundi et le jeudi, à
// Roch 'Hodech, à 'Hol hamoèd, à 'Hanouka, à Pourim et aux jeûnes publics (9 Av compris), à Min'ha des jeûnes
// publics ; jamais Chabbat ni Yom tov, dont le siddour n'a pas l'office. Ses montées selon Israël ou la diaspora,
// Jérusalem et le noussa'h. Le même calcul qu'Android, sur kosher-zmanim (le portage de KosherJava) :
// web/test/lecture-torah.test.mjs le compare jour par jour à @hebcal/leyning, la référence, et aux vecteurs que
// tient aussi LectureTorahTest.kt (web/test/vecteurs_lecture_torah.json).
//
// Les données : data/lecture_torah.json (les lectures, tools/lecture_torah_construction.py) et le texte, un
// fichier par livre (data/lecture_torah/<livre>.json, découpé par build.mjs), lus à la demande : rien n'est
// chargé au démarrage du site.

import { JewishCalendar } from '../vendor/kosher-zmanim-0.9.0.min.js';
import { ajouteJours } from './calendrier.js';
import { calendrier, jour as jourJuif } from './calendrier-juif.js';
import { PARSHIOT } from './halakha.js';

const NISSAN = 1, TISHREI = 7;
const LUNDI = 2, JEUDI = 5;

/** Les offices où l'on lit : Cha'harit et Min'ha (les clés des textes du siddour). */
export const OFFICES = ['chaharit', 'minha'];
export const NUSAH = ['edot', 'sefard', 'ashkenaz'];

const cal = (iso, il, muk) => calendrier(iso, il, false, muk);

/** Le jour de Sim'hat Torah : 22 Tichri en Israël, 23 en diaspora. */
const simhatTorah = (il) => (il ? 22 : 23);

/**
 * La paracha lue le Chabbat [iso] (un Chabbat) ou, à défaut (fête), celle qui vient dans le cycle :
 * findParshaHaShavua d'hebcal. Entre Kippour et Sim'hat Torah, Vézot haBérakha.
 */
export function parachaDeLaSemaine(iso, il) {
  for (let s = iso; ; s = ajouteJours(s, 7)) {
    const jc = cal(s, il, false);
    const p = jc.getParsha();
    if (p) return PARSHIOT[p];
    if (s === iso && jc.getJewishMonth() === TISHREI && jc.getJewishDayOfMonth() > 2 &&
        jc.getJewishDayOfMonth() <= simhatTorah(il)) return 'VZOS_HABERACHA';
  }
}

/** Le prochain Chabbat, [iso] compris. */
function chabbatSuivant(iso) {
  const j = new Date(`${iso}T12:00:00Z`).getUTCDay(); // 0 dimanche … 6 samedi
  return ajouteJours(iso, (6 - j + 7) % 7);
}

/**
 * La clé de la lecture d'un jour de semaine qui n'est pas un lundi ou un jeudi ordinaire (holiday-readings.json
 * d'hebcal) : Roch 'Hodech, 'Hol hamoèd, 'Hanouka, Pourim, jeûnes ; null sinon. [jc] n'est ni Chabbat ni Yom tov.
 */
export function cleFete(jc, iso, il, muk) {
  const m = jc.getJewishMonth(), d = jc.getJewishDayOfMonth();
  const yt = jc.getYomTovIndex();
  if (m === TISHREI) {
    if (d >= (il ? 16 : 17) && d <= 20) {
      const n = d - (il ? 15 : 16);
      return il ? `Sukkot Chol ha-Moed Day ${n} (Israel)` : `Sukkot Chol ha-Moed Day ${n}`;
    }
    if (d === 21) return il ? 'Sukkot Final Day (Hoshana Raba) (Israel)' : 'Sukkot Final Day (Hoshana Raba)';
  }
  if (yt === JewishCalendar.FAST_OF_GEDALYAH) return 'Tzom Gedaliah';
  if (jc.isChanukah()) {
    const j = jc.getDayOfChanukah();
    const rc = jc.isRoshChodesh();
    if (rc && j === 7) return 'Chanukah Day 7 (on Rosh Chodesh)';
    if (rc) return 'Chanukah Day 6';
    return `Chanukah Day ${j}`;
  }
  if (yt === JewishCalendar.TENTH_OF_TEVES) return "Asara B'Tevet";
  if (yt === JewishCalendar.FAST_OF_ESTHER) return "Ta'anit Esther";
  if (yt === JewishCalendar.SEVENTEEN_OF_TAMMUZ) return 'Tzom Tammuz';
  if (yt === JewishCalendar.TISHA_BEAV) return "Tish'a B'Av";
  // Pourim : le 14, ou le 15 dans une ville murée (Jérusalem), où il est « Chouchan Pourim ».
  if (jc.isPurim()) return muk ? 'Shushan Purim' : 'Purim';
  if (m === NISSAN) {
    if (d === 16) return "Pesach II (CH''M)"; // en Israël ; en diaspora, Yom tov
    if (d >= 17 && d <= 20) {
      // Pessa'h un jeudi : « ראה אתה » (פסל) le Chabbat 17, puis קדש, בכספא, במדברא du dimanche au mardi
      // (Choul'han Aroukh O.H. 490:5 ; Kitsour Yalkout Yossef 488:12, pour Israël aussi : hebcal y relit
      // פסל le lundi et omet קדש, écart voulu).
      const jeudi = cal(ajouteJours(iso, 15 - d), il, false).getDayOfWeek() === JEUDI;
      const n = jeudi ? { 18: 1, 19: 2, 20: 4 }[d] : d - 16;
      return `Pesach Chol ha-Moed Day ${n}`;
    }
  }
  if (jc.isRoshChodesh()) return 'Rosh Chodesh';
  return null;
}

/** Une lecture prête à afficher : montées libellées. */
function lecture(donnees, cle, titre, alyot) {
  const trois = alyot.length === 3;
  return {
    cle,
    titre,
    montees: alyot.map(([c, livre, debut, fin]) => ({
      cle: c,
      libelle: donnees.montees[trois && c === '3' ? '3_israel' : c],
      livre, debut, fin,
    })),
  };
}

/** Les montées d'une entrée de lecture_torah.json pour un noussa'h (alias résolu). */
function fete(donnees, cle, nusah) {
  const e = donnees.lectures[cle];
  if (!e) throw new Error(`lecture inconnue : ${cle}`);
  const base = e.alias ? donnees.lectures[e.alias] : e;
  const alyot = e[`alyot_${nusah}`] ?? e.alyot ?? base[`alyot_${nusah}`] ?? base.alyot;
  return lecture(donnees, cle, e.titre ?? base.titre, alyot);
}

function semaine(donnees, p) {
  const e = donnees.parachiot[p];
  return lecture(donnees, `semaine:${p}`, e.titre, e.semaine);
}

/**
 * Les lectures d'un office de semaine : [] s'il n'y en a pas, et toujours un Chabbat ou un Yom tov. [iso] : la date
 * civile du jour de l'office ; [office] : 'chaharit' ou 'minha' ; [nusah] : 'edot', 'sefard' ou 'ashkenaz' ;
 * [mukafChoma] : Jérusalem (Pourim le 15).
 */
export function lectures(donnees, iso, office, { enIsrael = false, mukafChoma = false, nusah = 'edot' } = {}) {
  const il = enIsrael, muk = mukafChoma && enIsrael;
  const jc = cal(iso, il, muk);
  if (jc.isAssurBemelacha()) return [];
  if (office === 'minha') return jc.isTaanis() ? [fete(donnees, `${cleFete(jc, iso, il, muk)} (Mincha)`, nusah)] : [];
  if (office !== 'chaharit') return [];
  const cle = cleFete(jc, iso, il, muk);
  if (cle) return [fete(donnees, cle, nusah)];
  const jour = jc.getDayOfWeek();
  if (jour === LUNDI || jour === JEUDI) return [semaine(donnees, parachaDeLaSemaine(chabbatSuivant(iso), il))];
  return [];
}

/** Le jour [j] (calendrier-juif.js, jour) a-t-il une lecture à l'office de semaine [office] ? Jamais Chabbat ni Yom tov. */
export function litDansLOffice(j, office) {
  if (j.chome) return false;
  if (office === 'chaharit') return j.conditions.has('kriat_hatorah');
  if (office === 'minha') return j.conditions.has('jeune');
  return false;
}

/**
 * La lecture d'un office de semaine du siddour, à sa place (LectureTorah.lecturesOffice) : à Cha'harit les jours où
 * l'on lit, à Min'ha les jours de jeûne ; jamais un Chabbat ni un Yom tov (le siddour n'en a pas l'office).
 */
export function lecturesOffice(donnees, iso, office, options = {}) {
  const j = jourJuif(iso, !!options.enIsrael, !!options.mukafChoma);
  return litDansLOffice(j, office) ? lectures(donnees, iso, office, options) : [];
}

/** « Berèchit 32:4–13 » (LectureTorah.reference) : [nom] traduit le nom du livre ({ he, fr, en } → texte). */
export function reference(donnees, livre, debut, fin, nom = (t) => t.fr) {
  const l = donnees.livres?.[livre];
  const [c1, v1] = debut.split(':');
  const [c2, v2] = fin.split(':');
  const plage = debut === fin ? debut : c1 === c2 ? `${c1}:${v1}–${v2}` : `${debut}–${fin}`;
  return `${l ? nom(l) : livre} ${plage}`;
}

// --- Le texte ----------------------------------------------------------------------------------

/** Les versets d'un passage : [{ c, v, t, fin }] (fin : 'פ' ou 'ס' en fin de paragraphe). */
export function versets(livre, debut, fin, texteLivre) {
  const [c1, v1] = debut.split(':').map(Number);
  const [c2, v2] = fin.split(':').map(Number);
  const sortie = [];
  for (let c = c1; c <= c2; c++) {
    const chapitre = texteLivre.chapitres[String(c)];
    if (!chapitre) throw new Error(`${livre} ${c} : chapitre absent`);
    for (let v = c === c1 ? v1 : 1; v <= (c === c2 ? v2 : chapitre.length); v++) {
      sortie.push({ c, v, t: chapitre[v - 1], fin: texteLivre.paragraphes?.[`${c}:${v}`] ?? null });
    }
  }
  return sortie;
}

/** Le nom de fichier d'un livre : son nom anglais, les espaces en « _ ». */
export const fichierLivre = (livre) => livre.replace(/ /g, '_');

let promesseDonnees = null;
const livres = new Map();

/** data/lecture_torah.json, une fois. */
export function chargeDonnees(lire = (u) => fetch(u).then((r) => r.json())) {
  promesseDonnees ??= lire('data/lecture_torah.json');
  return promesseDonnees;
}

/** Le texte d'un livre, à la demande (data/lecture_torah/<livre>.json). */
export function chargeLivre(livre, lire = (u) => fetch(u).then((r) => r.json())) {
  if (!livres.has(livre)) livres.set(livre, lire(`data/lecture_torah/${fichierLivre(livre)}.json`));
  return livres.get(livre);
}
