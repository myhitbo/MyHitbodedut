// La lecture de la Torah du jour (LectureTorah.kt, 26/11) : quelle lecture, à quel office, avec ses
// montées et sa haftara, selon Israël ou la diaspora, Jérusalem et le noussa'h. Le même calcul
// qu'Android, sur kosher-zmanim (le portage de KosherJava) : web/test/lecture-torah.test.mjs le
// compare jour par jour à @hebcal/leyning, la référence, et aux vecteurs que tient aussi
// LectureTorahTest.kt (web/test/vecteurs_lecture_torah.json).
//
// Les données : data/lecture_torah.json (les lectures, tools/lecture_torah_construction.py) et
// le texte, un fichier par livre (data/lecture_torah/<livre>.json, découpé par build.mjs), lus à la
// demande : rien n'est chargé au démarrage du site.

import { JewishCalendar } from '../vendor/kosher-zmanim-0.9.0.min.js';
import { ajouteJours } from './calendrier.js';
import { calendrier, jour as jourJuif } from './calendrier-juif.js';
import { PARSHIOT } from './halakha.js';

const NISSAN = 1, SIVAN = 3, AV = 5, TISHREI = 7;
const LUNDI = 2, JEUDI = 5, CHABBAT = 7;

/** Les offices où l'on lit : Cha'harit et Min'ha (les clés des textes du siddour). */
export const OFFICES = ['chaharit', 'minha'];
export const NUSAH = ['edot', 'sefard', 'ashkenaz'];

/** Le texte « Lecture de la Torah » du siddour (26/11, D1) : sa clé et son titre (LectureTorah.ID_TEXTE, TITRE). */
export const ID_TEXTE = 'lecture_torah';
export const TITRE = { he: 'קְרִיאַת הַתּוֹרָה', fr: 'Lecture de la Torah', en: 'Torah reading' };

const cal = (iso, il, muk) => calendrier(iso, il, false, muk);

/** L'énumération Parsha de kosher-zmanim, Chabbatot spéciaux compris (SHKALIM = 62 … NACHAMU = 70). */
const SPECIAUX = [...PARSHIOT, 'SHKALIM', 'ZACHOR', 'PARA', 'HACHODESH', 'SHUVA', 'SHIRA', 'HAGADOL', 'CHAZON', 'NACHAMU'];

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

/**
 * Chabbat à Min'ha : le début de la paracha qui suit (Choul'han Aroukh O.H. 135:2 et 292:1, « ואפי' חל
 * יו"ט להיות בשבת קוראין בפרשה הבאה » ; Kitsour Yalkout Yossef 292:5). De Kippour à Sim'hat Torah,
 * Vézot haBérakha, la seule qui reste avant Berèchit.
 */
export function parachaApres(iso, il) {
  const jc = cal(iso, il, false);
  const d = jc.getJewishDayOfMonth();
  if (jc.getJewishMonth() === TISHREI && d >= 10 && d <= simhatTorah(il)) return 'VZOS_HABERACHA';
  return parachaDeLaSemaine(ajouteJours(iso, 7), il);
}

/** Le prochain Chabbat, [iso] compris. */
function chabbatSuivant(iso) {
  const j = new Date(`${iso}T12:00:00Z`).getUTCDay(); // 0 dimanche … 6 samedi
  return ajouteJours(iso, (6 - j + 7) % 7);
}

/**
 * La clé de la lecture d'une fête (holiday-readings.json d'hebcal, getLeyningKeyForEvent), en
 * semaine ou un Chabbat sans paracha ; null s'il n'y en a pas.
 */
export function cleFete(jc, iso, il, muk) {
  const m = jc.getJewishMonth(), d = jc.getJewishDayOfMonth();
  const ch = jc.getDayOfWeek() === CHABBAT;
  const sur = (cle) => (ch ? `${cle} (on Shabbat)` : cle);
  const yt = jc.getYomTovIndex();
  if (m === TISHREI) {
    if (d === 1) return sur('Rosh Hashana I');
    if (d === 2) return 'Rosh Hashana II';
    if (d === 15) return sur('Sukkot I');
    if (d === 16 && !il) return 'Sukkot II';
    if (d >= (il ? 16 : 17) && d <= 20) {
      if (ch) return 'Sukkot Shabbat Chol ha-Moed';
      const n = d - (il ? 15 : 16);
      return il ? `Sukkot Chol ha-Moed Day ${n} (Israel)` : `Sukkot Chol ha-Moed Day ${n}`;
    }
    if (d === 21) return il ? 'Sukkot Final Day (Hoshana Raba) (Israel)' : 'Sukkot Final Day (Hoshana Raba)';
    if (d === 22) return il ? sur('Simchat Torah') : sur('Shmini Atzeret');
    if (d === 23 && !il) return 'Simchat Torah';
  }
  if (yt === JewishCalendar.FAST_OF_GEDALYAH) return 'Tzom Gedaliah';
  if (yt === JewishCalendar.YOM_KIPPUR) return sur('Yom Kippur');
  if (jc.isChanukah()) {
    const j = jc.getDayOfChanukah();
    const rc = jc.isRoshChodesh();
    if (ch && rc) return 'Shabbat Rosh Chodesh Chanukah'; // toujours le sixième jour
    if (rc && j === 7) return 'Chanukah Day 7 (on Rosh Chodesh)';
    if (rc) return 'Chanukah Day 6';
    return ch ? `Chanukah Day ${j} (on Shabbat)` : `Chanukah Day ${j}`;
  }
  if (yt === JewishCalendar.TENTH_OF_TEVES) return "Asara B'Tevet";
  if (yt === JewishCalendar.FAST_OF_ESTHER) return "Ta'anit Esther";
  if (yt === JewishCalendar.SEVENTEEN_OF_TAMMUZ) return 'Tzom Tammuz';
  if (yt === JewishCalendar.TISHA_BEAV) return "Tish'a B'Av";
  // Pourim : le 14, ou le 15 dans une ville murée (Jérusalem), où il est « Chouchan Pourim ».
  if (jc.isPurim() && !ch) return muk ? 'Shushan Purim' : 'Purim';
  if (m === NISSAN) {
    if (d === 15) return sur('Pesach I');
    if (d === 16) return il ? "Pesach II (CH''M)" : 'Pesach II';
    if (d >= 17 && d <= 20) {
      if (ch) return 'Pesach Shabbat Chol ha-Moed';
      // Pessa'h un jeudi : « ראה אתה » (פסל) le Chabbat 17, puis קדש, בכספא, במדברא du dimanche au mardi
      // (Choul'han Aroukh O.H. 490:5 ; Kitsour Yalkout Yossef 488:12, pour Israël aussi : hebcal y relit
      // פסל le lundi et omet קדש, écart voulu).
      const jeudi = cal(ajouteJours(iso, 15 - d), il, false).getDayOfWeek() === JEUDI;
      const n = jeudi ? { 18: 1, 19: 2, 20: 4 }[d] : d - 16;
      return `Pesach Chol ha-Moed Day ${n}`;
    }
    if (d === 21) return sur('Pesach VII');
    if (d === 22 && !il) return sur('Pesach VIII');
  }
  if (m === SIVAN) {
    if (d === 6) return il ? 'Shavuot' : 'Shavuot I';
    if (d === 7 && !il) return sur('Shavuot II');
  }
  if (jc.isRoshChodesh() && !ch) return 'Rosh Chodesh';
  return null;
}

/** Les lectures qui changent le maftir ou la haftara d'un Chabbat à paracha (specialReadings2 d'hebcal). */
export function speciales(jc, p, muk) {
  const m = jc.getJewishMonth(), d = jc.getJewishDayOfMonth();
  const rc = jc.isRoshChodesh();
  const cles = [];
  const sp = SPECIAUX[jc.getSpecialShabbos()];
  if (sp === 'SHUVA') cles.push(`Shabbat Shuva (with ${p === 'VAYEILECH' ? 'Vayeilech' : "Ha'azinu"})`);
  if (jc.isChanukah()) {
    const j = jc.getDayOfChanukah();
    cles.push(rc ? 'Shabbat Rosh Chodesh Chanukah' : `Chanukah Day ${j} (on Shabbat)`);
  }
  if (sp === 'SHKALIM') cles.push(rc ? 'Shabbat Shekalim (on Rosh Chodesh)' : 'Shabbat Shekalim');
  if (sp === 'ZACHOR') cles.push('Shabbat Zachor');
  if (sp === 'PARA') cles.push('Shabbat Parah');
  if (sp === 'HACHODESH') cles.push(rc ? 'Shabbat HaChodesh (on Rosh Chodesh)' : 'Shabbat HaChodesh');
  if (sp === 'HAGADOL') cles.push('Shabbat HaGadol');
  // Jérusalem, Pourim triple : le Chabbat 15 Adar (Choul'han Aroukh O.H. 688:6).
  if (muk && jc.isPurim()) cles.push('Shushan Purim (on Shabbat)');
  return { cles, m, d };
}

function copie(x) { return JSON.parse(JSON.stringify(x)); }

/** Les montées et la haftara d'une entrée de lecture_torah.json pour un noussa'h (alias résolu). */
function entree(donnees, cle, nusah) {
  const e = donnees.lectures[cle];
  if (!e) throw new Error(`lecture inconnue : ${cle}`);
  const base = e.alias ? donnees.lectures[e.alias] : e;
  const champ = (nom) => e[`${nom}_${nusah}`] ?? e[nom] ?? base[`${nom}_${nusah}`] ?? base[nom];
  return { titre: e.titre ?? base.titre, alyot: champ('alyot'), haftara: champ('haftara') };
}

/** Le sixième et le septième réunis, quand une lecture spéciale prend le septième (mergeAliyotWithSpecial). */
function fusionne(alyot, special) {
  let a = copie(alyot);
  for (const m of special) {
    if (m[0] === '7') {
      const six = a.find((x) => x[0] === '6'), sept = a.find((x) => x[0] === '7');
      six[3] = sept[3];
      a = a.filter((x) => x[0] !== '7');
      a.splice(a.indexOf(six) + 1, 0, copie(m));
    } else if (m[0] === 'M') {
      a = a.filter((x) => x[0] !== 'M');
      a.push(copie(m));
    } else {
      throw new Error(`montée spéciale inattendue : ${m[0]}`);
    }
  }
  return a;
}

/** Une lecture prête à afficher : montées libellées, haftara. */
function lecture(donnees, cle, titre, alyot, haftara, raisons = []) {
  const trois = alyot.length === 3;
  return {
    cle,
    titre,
    raisons,
    montees: alyot.map(([c, livre, debut, fin]) => ({
      cle: c,
      libelle: donnees.montees[trois && c === '3' ? '3_israel' : c],
      livre, debut, fin,
    })),
    haftara: (haftara ?? []).map(([livre, debut, fin]) => ({ livre, debut, fin })),
  };
}

function fete(donnees, cle, nusah, extra = {}) {
  const e = entree(donnees, cle, nusah);
  let alyot = e.alyot;
  if (extra.maftir) alyot = [...alyot, ['M', ...extra.maftir]];
  return lecture(donnees, cle, e.titre, alyot, e.haftara);
}

function semaine(donnees, p) {
  const e = donnees.parachiot[p];
  return lecture(donnees, `semaine:${p}`, e.titre, e.semaine, []);
}

function chabbat(donnees, jc, iso, p, il, muk, nusah) {
  const e = donnees.parachiot[p];
  let alyot = e[`alyot_${nusah}`] ?? e.alyot;
  let haftara = e[`haftara_${nusah}`] ?? e.haftara;
  const { cles, m, d } = speciales(jc, p, muk);
  const appliquees = [...cles];
  let haftaraSpeciale = null;
  const applique = (cle) => {
    const s = entree(donnees, cle, nusah);
    if (s.haftara && haftaraSpeciale === null) haftaraSpeciale = cle;
    if (s.haftara && haftaraSpeciale === cle) haftara = s.haftara;
    if (s.alyot) alyot = fusionne(alyot, s.alyot);
  };
  cles.forEach(applique);
  if (haftaraSpeciale === null) {
    const demain = cal(ajouteJours(iso, 1), il, false).getJewishDayOfMonth();
    let cle = null;
    if (p === 'PINCHAS' && d > 17) cle = 'Pinchas occurring after 17 Tammuz';
    else if (d === 30 || d === 1) {
      cle = p === 'MASEI' || p === 'MATOS_MASEI' ? 'Masei on Shabbat Rosh Chodesh'
        : p === 'REEH' ? "Re'eh on Shabbat Rosh Chodesh" : 'Shabbat Rosh Chodesh';
    } else if (p === 'KI_SEITZEI' && d === 14) cle = 'Ki Teitzei with 3rd Haftarah of Consolation';
    else if (p === 'KEDOSHIM' && (d === 26 || d === 28 || d === 6)) cle = 'Kedoshim following Special Shabbat';
    else if (m !== AV && (demain === 30 || demain === 1)) cle = 'Shabbat Machar Chodesh';
    if (cle) {
      appliquees.push(cle);
      applique(cle);
    }
    // Edot : Roch 'Hodech Chabbat et dimanche, le premier et le dernier verset de « מחר חדש » après « השמים
    // כסאי » (Choul'han Aroukh O.H. 425:2).
    if (nusah === 'edot' && cle === 'Shabbat Rosh Chodesh' && d === 30) haftara = [...haftara, ...entree(donnees, 'Ajout Machar Chodesh', nusah).haftara];
  }
  // Edot : Chabbat Chekalim la veille d'un Roch 'Hodech dimanche, de même (Kitsour Yalkout Yossef, שקלים § 2).
  if (nusah === 'edot' && haftaraSpeciale === 'Shabbat Shekalim') {
    const demain = cal(ajouteJours(iso, 1), il, false).getJewishDayOfMonth();
    if (demain === 30 || demain === 1) haftara = [...haftara, ...entree(donnees, 'Ajout Machar Chodesh', nusah).haftara];
  }
  const raisons = appliquees.map((c) => donnees.lectures[c].titre).filter(Boolean);
  return lecture(donnees, `parasha:${p}${appliquees.length ? `+${appliquees.join('+')}` : ''}`, e.titre, alyot, haftara, raisons);
}

/**
 * Les lectures d'un office : [] s'il n'y en a pas. [iso] : la date civile du jour de l'office (Cha'harit
 * et Min'ha le même jour) ; [office] : 'chaharit' ou 'minha' ; [nusah] : 'edot', 'sefard' ou 'ashkenaz' ;
 * [mukafChoma] : Jérusalem (Pourim le 15).
 */
export function lectures(donnees, iso, office, { enIsrael = false, mukafChoma = false, nusah = 'edot' } = {}) {
  const il = enIsrael, muk = mukafChoma && enIsrael;
  const jc = cal(iso, il, muk);
  const jour = jc.getDayOfWeek();
  const yt = jc.getYomTovIndex();
  if (office === 'minha') {
    if (yt === JewishCalendar.YOM_KIPPUR) return [fete(donnees, 'Yom Kippur (Mincha)', nusah)];
    if (jc.isTaanis()) return [fete(donnees, `${cleFete(jc, iso, il, muk)} (Mincha)`, nusah)];
    if (jour === CHABBAT) return [semaine(donnees, parachaApres(iso, il))];
    return [];
  }
  if (office !== 'chaharit') return [];
  if (jour === CHABBAT) {
    const p = jc.getParsha();
    if (p) return [chabbat(donnees, jc, iso, PARSHIOT[p], il, muk, nusah)];
    const cle = cleFete(jc, iso, il, muk);
    if (cle === 'Sukkot Shabbat Chol ha-Moed') {
      const d = jc.getJewishDayOfMonth();
      const n = String(d - (il ? 15 : 16));
      const e = donnees.lectures[cle];
      return [fete(donnees, cle, nusah, { maftir: (il ? e.maftir_israel : e.maftir)[n] })];
    }
    return cle ? [fete(donnees, cle, nusah)] : [];
  }
  const cle = cleFete(jc, iso, il, muk);
  if (cle) return [fete(donnees, cle, nusah)];
  if (jour === LUNDI || jour === JEUDI) return [semaine(donnees, parachaDeLaSemaine(chabbatSuivant(iso), il))];
  return [];
}

/**
 * Ce que montre le texte « Lecture de la Torah » (LectureTorah.parachaSemaine ; demande du 26/11 : « Pas de Yom Tov,
 * on ne lit pas chnayim mikra pour Yom Tov ») : la paracha de la semaine, pour Chnayim mikra véé'had targoum, celle
 * du Chabbat qui vient ([iso] même si c'est Chabbat), avec ses montées, son maftir et sa haftara (ceux d'un Chabbat
 * spécial qui garde sa paracha restent). Un Chabbat de Yom tov ou de 'Hol hamoed n'a pas de paracha : la suivante.
 * { date, lecture }.
 */
export function parachaSemaine(donnees, iso, options = {}) {
  const il = !!options.enIsrael;
  const muk = !!options.mukafChoma && il;
  let j = chabbatSuivant(iso);
  while (!cal(j, il, muk).getParsha()) j = ajouteJours(j, 7);
  const [lecture] = lectures(donnees, j, 'chaharit', options);
  return { date: j, lecture };
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

/**
 * Chnayim mikra véé'had targoum (LectureTorah.chnayimMikra) : verset par verset, l'hébreu deux fois ([uneFois] :
 * une), puis le Targoum Onkelos. [hebreu], [targoum] : les versets d'un passage (versets()), alignés.
 * [{ c, v, t, targoum }].
 */
export function chnayimMikra(hebreu, targoum, uneFois = false) {
  if (hebreu.length !== targoum.length || hebreu.some((x, k) => x.c !== targoum[k].c || x.v !== targoum[k].v)) throw new Error('Targoum non aligné');
  return hebreu.flatMap((x, k) => [
    ...Array.from({ length: uneFois ? 1 : 2 }, () => ({ c: x.c, v: x.v, t: x.t, targoum: false })),
    { c: x.c, v: x.v, t: targoum[k].t, targoum: true },
  ]);
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

/** Le nom de fichier d'un livre (« I Samuel » → « I_Samuel »). */
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

const targoums = new Map();

/**
 * Le Targoum Onkelos d'un livre de la Torah, à la demande (data/lecture_torah/targoum/<livre>.json, découpé par
 * build.mjs dans lecture_torah_targoum.json) : seulement dans le texte « Lecture de la Torah ».
 */
export function chargeTargoum(livre, lire = (u) => fetch(u).then((r) => r.json())) {
  if (!targoums.has(livre)) targoums.set(livre, lire(`data/lecture_torah/targoum/${fichierLivre(livre)}.json`));
  return targoums.get(livre);
}
