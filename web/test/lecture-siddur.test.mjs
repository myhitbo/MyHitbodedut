// La lecture de la Torah dans le siddour (26/11, phase B) : à sa place dans chaque office, repliée, puis sa haftara ;
// et le texte « Lecture de la Torah ». Les mêmes cas qu'Android (LectureSiddurTest.kt).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { ID_TEXTE, NUSAH, TITRE, chargeTargoum, chnayimMikra, lectures, lecturesOffice, litDansLOffice, parachaSemaine, reference, versets } from '../src/js/lecture-torah.js';
import { conditionsPour, index, placeLecture, plan, segments, signature } from '../src/js/siddur-jour.js';
import { litChaines } from '../tools/chaines.mjs';
import { decoupeTexte } from '../tools/lecture-torah.mjs';

const ANDROID = new URL('../../android/app/src/main/', import.meta.url);
const raw = (f) => JSON.parse(readFileSync(new URL(`res/raw/${f}`, ANDROID), 'utf8'));
const annotations = raw('siddur_annotations.json');
const donnees = raw('lecture_torah.json');
const siddur = Object.fromEntries(NUSAH.map((n) => [n, raw(`siddur_${n}.json`)]));
const app = readFileSync(new URL('../src/js/app.js', import.meta.url), 'utf8');
const nu = (s) => s.replace(/<[^>]+>/g, ' ').replace(/[֑-ׇ]/g, '').replace(/\s+/g, ' ').trim();

/**
 * Ce qu'écrit ecranPriere (corpsDe), dans l'ordre : les blocs lus en clair, les replis (leur libellé), et la lecture
 * du jour à sa place ({ lecture: [...] }), comme SiddurJour.lignes.
 */
function deroule(nusah, office, iso, israel = false) {
  const texte = siddur[nusah].textes.find((t) => t.id === office);
  const idx = index(annotations[nusah][office]);
  const c = conditionsPour(nusah, israel, jour(iso, israel).conditions);
  const l = lecturesOffice(donnees, iso, office, { enIsrael: israel, nusah });
  const sortie = [];
  const bloc = (s, si, i) => {
    sortie.push({ si, i, texte: nu(s.blocs[i].t ?? s.blocs[i].c) });
    if (l.length && placeLecture(idx, si, i, c)) sortie.push({ lecture: l });
  };
  texte.sections.forEach((s, si) => {
    for (const p of plan(s, si, idx, c)) {
      if (p.etat === 'retire') continue;
      if (p.etat === 'replie') { sortie.push({ replie: p.libelle ?? p.annotation.libelle }); continue; }
      if (p.annotation?.sorte !== 'bloc') { p.lus.forEach((i) => bloc(s, si, i)); continue; }
      for (const g of segments(p.lus, si, idx, c)) {
        if (g.et) sortie.push({ replie: g.libelle });
        else g.blocs.forEach((i) => bloc(s, si, i));
      }
    }
  });
  return sortie;
}
const lecturesDe = (d) => d.filter((x) => x.lecture).map((x) => x.lecture);

test('un lundi, la lecture repliée après la bénédiction qui la suit, avant les Mi chébérakh', () => {
  for (const nusah of NUSAH) {
    const d = deroule(nusah, 'chaharit', '2026-11-23');
    const l = lecturesDe(d);
    assert.equal(l.length, 1, nusah);
    assert.equal(l[0][0].cle, 'semaine:VAYISHLACH');
    assert.deepEqual(l[0][0].montees.map((m) => m.libelle.fr), ['Cohen', 'Lévi', 'Israël']);
    assert.deepEqual(l[0][0].haftara, []);
    const k = d.findIndex((x) => x.lecture);
    assert.match(d[k - 1].texte, /^ברוך אתה (יהוה|ה׳|יי).*אשר נתן/, nusah);
    if (nusah !== 'edot') assert.ok(d.findIndex((x) => x.replie === 'ajout_mi_cheberakh_oleh') > k, nusah);
  }
});

test('un mardi sans lecture, rien à Cha\'harit', () => {
  for (const nusah of NUSAH) assert.deepEqual(lecturesDe(deroule(nusah, 'chaharit', '2026-11-24')), [], nusah);
});

test('Roch \'Hodech et \'Hanouka à Roch \'Hodech Tevet : quatre montées', () => {
  for (const nusah of NUSAH) {
    const rc = lecturesDe(deroule(nusah, 'chaharit', '2026-11-10'))[0][0];
    assert.equal(rc.cle, 'Rosh Chodesh');
    assert.equal(rc.montees.length, 4);
    const tevet = lecturesDe(deroule(nusah, 'chaharit', '2026-12-11'))[0][0];
    assert.equal(tevet.cle, 'Chanukah Day 7 (on Rosh Chodesh)');
    assert.deepEqual(tevet.montees.map((m) => m.debut), ['28:1', '28:6', '28:11', '7:48']);
  }
});

test('9 Av, le matin et à Min\'ha, selon le rite ; plus de repère qui la décrivait', () => {
  for (const nusah of NUSAH) {
    const matin = lecturesDe(deroule(nusah, 'chaharit', '2026-07-23'))[0][0];
    assert.equal(matin.haftara[0].livre, 'Jeremiah', nusah);
    const minha = deroule(nusah, 'minha', '2026-07-23');
    const l = lecturesDe(minha)[0][0];
    assert.deepEqual(l.haftara.map((p) => p.livre), nusah === 'edot' ? ['Hosea', 'Micah'] : ['Isaiah'], nusah);
    const indices = annotations[nusah].minha.filter((a) => a.sorte === 'indice').map((a) => a.texte);
    assert.ok(!indices.some((t) => t.includes('ויחל') || t.includes('שובה ישראל')), nusah);
  }
  // « שובה ישראל », puis Mikha 7:18-20 (Edot), sous leur nom traduit.
  const edot = lecturesDe(deroule('edot', 'minha', '2026-07-23'))[0][0];
  assert.deepEqual(edot.haftara.map((p) => reference(donnees, p.livre, p.debut, p.fin)), ['Osée 14:2–10', 'Michée 7:18–20']);
  assert.equal(reference(donnees, 'Hosea', '14:2', '14:10', (t) => t.he), 'הושע 14:2–10');
});

test('un jeûne public à Min\'ha : Edot sans haftara, Ashkenaz et Sfard avec « דרשו »', () => {
  for (const nusah of NUSAH) {
    const l = lecturesDe(deroule(nusah, 'minha', '2026-12-20'))[0][0];
    assert.equal(l.cle, "Asara B'Tevet (Mincha)");
    assert.equal(l.haftara.length > 0, nusah !== 'edot', nusah);
    assert.equal(l.montees[2].libelle.fr, nusah === 'edot' ? 'Israël' : 'Maftir', nusah);
    // Un jour sans jeûne, rien à Min'ha.
    assert.deepEqual(lecturesDe(deroule(nusah, 'minha', '2026-12-21')), [], nusah);
  }
});

test('pas de Yom tov ni de Chabbat dans les offices de semaine ; \'Hol hamoed et \'Hanouka gardent leur lecture', () => {
  for (const nusah of NUSAH) {
    for (const iso of ['2026-11-28', '2026-04-02', '2026-10-03']) assert.deepEqual(lecturesDe(deroule(nusah, 'chaharit', iso)), [], `${nusah} ${iso}`);
    assert.deepEqual(lecturesDe(deroule(nusah, 'minha', '2026-09-21')), [], nusah); // Kippour
    assert.equal(lecturesDe(deroule(nusah, 'chaharit', '2026-04-05'))[0][0].cle, 'Pesach Chol ha-Moed Day 1');
    assert.equal(lecturesDe(deroule(nusah, 'chaharit', '2026-12-07'))[0][0].cle, 'Chanukah Day 3');
  }
  const j = jour('2026-11-28', false);
  assert.ok(j.conditions.has('kriat_hatorah') && !litDansLOffice(j, 'chaharit'));
  // app.js garde la même règle sans charger le module.
  assert.match(app, /const litIci = \(j\) => !j\.chome && j\.conditions\.has\(x\.id === 'chaharit' \? 'kriat_hatorah' : 'jeune'\);/);
  assert.match(app, /lecture\.m\.lecturesOffice\(/);
});

const semaine = (iso, enIsrael = false, nusah = 'edot') => parachaSemaine(donnees, iso, { enIsrael, nusah });

test('le texte « Lecture de la Torah » : la paracha de la semaine, jamais une lecture de Yom tov', () => {
  const mardi = semaine('2026-11-24');
  assert.equal(mardi.date, '2026-11-28');
  assert.equal(mardi.lecture.cle, 'parasha:VAYISHLACH');
  assert.equal(mardi.lecture.montees.length, 8);
  assert.equal(mardi.lecture.haftara[0].livre, 'Obadiah');
  assert.deepEqual(semaine('2026-11-28'), mardi);
  // Avant Souccot 5787 et la semaine de Sim'hat Torah : Berèchit, le 10/10.
  for (const il of [true, false]) assert.equal(semaine('2026-09-22', il).date, '2026-10-10');
  assert.equal(semaine('2026-10-04').lecture.titre.fr, 'Berèchit');
  // Avant Pessa'h 5786 : Chabbat 'Hol hamoed sauté, Chemini le 11/04.
  assert.deepEqual([semaine('2026-03-31', false, 'ashkenaz').date, semaine('2026-03-31', false, 'ashkenaz').lecture.cle], ['2026-04-11', 'parasha:SHMINI']);
  // 5789 : le 8e jour de Pessa'h un Chabbat en diaspora.
  assert.equal(semaine('2029-04-03', true, 'ashkenaz').date, '2029-04-07');
  assert.equal(semaine('2029-04-03', false, 'ashkenaz').date, '2029-04-14');
  // Deux parachiot jointes : Matot-Masé.
  const jointes = semaine('2027-07-27', false, 'ashkenaz').lecture;
  assert.equal(jointes.cle, 'parasha:MATOS_MASEI');
  assert.equal(jointes.titre.fr, 'Matot-Masé');
  assert.deepEqual([jointes.montees[0].debut, jointes.montees[6].fin], ['30:2', '36:13']);
  // Chabbat Chekalim : son maftir et sa haftara.
  for (const nusah of NUSAH) {
    const l = semaine('2027-03-02', false, nusah).lecture;
    assert.ok(l.cle.startsWith('parasha:VAYAKHEL+Shabbat Shekalim'), nusah);
    assert.equal(l.montees.at(-1).debut, '30:11');
    assert.equal(l.haftara[0].livre, 'II Kings');
    assert.ok(l.raisons.length > 0);
  }
  // Dans tout un cycle : toujours une paracha, un Chabbat, pas avant le jour.
  for (let t = Date.UTC(2026, 8, 1); t < Date.UTC(2027, 9, 1); t += 864e5) {
    const iso = new Date(t).toISOString().slice(0, 10);
    for (const il of [true, false]) {
      const p = semaine(iso, il);
      assert.ok(p.lecture.cle.startsWith('parasha:') && new Date(`${p.date}T12:00:00Z`).getUTCDay() === 6 && p.date >= iso, iso);
    }
  }
  // L'écran : l'en-tête, la paracha avec le Targoum, le bouton « ×2 ».
  assert.match(app, /m\.parachaSemaine\(donnees, iso, options\(israel\)\)/);
  assert.match(app, /\.\.\.boitesLecture\(\[p\.lecture\], \{ targoum: true \}\)/);
  assert.match(app, /chnayimMikra: true, entete:/);
  assert.match(app, /lectureApres = \(si, i\) => \(lecturesDuJour\.length && placeLecture\(idx, si, i, c\) \? boitesLecture\(lecturesDuJour\) : \[\]\)/);
});

const parLivre = decoupeTexte(raw('lecture_torah_texte.json'));
const targoum = raw('lecture_torah_targoum.json');
const targoumParLivre = decoupeTexte(targoum);

test('Chnayim mikra : l\'hébreu deux fois puis le Targoum, ou une fois selon le réglage', () => {
  const h = versets('Genesis', '32:4', '32:6', parLivre.Genesis);
  const t = versets('Genesis', '32:4', '32:6', targoumParLivre.Genesis);
  const deux = chnayimMikra(h, t);
  assert.deepEqual(deux.map((l) => l.v), [4, 4, 4, 5, 5, 5, 6, 6, 6]);
  assert.deepEqual(deux.map((l) => l.targoum), [false, false, true, false, false, true, false, false, true]);
  assert.equal(deux[0].t, h[0].t);
  assert.deepEqual(deux[0], deux[1]);
  assert.ok(deux[2].t.startsWith('וּשְׁלַח יַעֲקֹב אִזְגַּדִּין'));
  assert.deepEqual(chnayimMikra(h, t, true).map((l) => l.targoum), [false, true, false, true, false, true]);
  assert.throws(() => chnayimMikra(h, t.slice(1)));
  // Le réglage : gardé (store.js, sauvegarde comprise), deux fois par défaut ; « ×1 » cache la seconde fois sur place.
  const store = readFileSync(new URL('../src/js/store.js', import.meta.url), 'utf8');
  assert.match(store, /lectureHebreuUneFois: \(\) => get\('lecture_hebreu_une_fois', false\) === true/);
  assert.match(store, /lecture_hebreu_une_fois: store\.lectureHebreuUneFois\(\)/);
  assert.match(app, /lecture-seule\$\{store\.lectureHebreuUneFois\(\) \? ' hebreu-une-fois' : ''\}/);
  const css = readFileSync(new URL('../src/app.css', import.meta.url), 'utf8');
  assert.match(css, /\.hebreu-une-fois \.lecture-bis \{ display: none; \}/);
});

test('le Targoum Onkelos : même versification que le texte, chargé à la demande, livre par livre', async () => {
  const heb = raw('lecture_torah_texte.json').livres;
  assert.deepEqual(Object.keys(targoum.livres), ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']);
  let n = 0;
  for (const [livre, chapitres] of Object.entries(targoum.livres)) {
    assert.deepEqual(Object.keys(chapitres), Object.keys(heb[livre]), livre);
    for (const [c, v] of Object.entries(chapitres)) { assert.equal(v.length, heb[livre][c].length, `${livre} ${c}`); n += v.length; }
  }
  assert.equal(n, 5847);
  assert.equal(targoum.livres.Numbers['25'][18], 'וַהֲוָה בָּתַר מוֹתָנָא׃');
  assert.equal(targoum._meta.licence, 'Public Domain');
  // À la demande : une requête par livre, gardée.
  const lus = [];
  const lire = async (u) => { lus.push(u); return targoumParLivre.Genesis; };
  await chargeTargoum('Genesis', lire);
  await chargeTargoum('Genesis', lire);
  assert.deepEqual(lus, ['data/lecture_torah/targoum/Genesis.json']);
  // build.mjs découpe le Targoum ; app.js ne le demande que pour le texte « Lecture de la Torah ».
  const build = readFileSync(new URL('../build.mjs', import.meta.url), 'utf8');
  assert.match(build, /lecture_torah_targoum\.json/);
  assert.match(app, /\.\.\.\(targoum \? \[m\.chargeTargoum\(l\)/);
});

test('la question Israël ou diaspora tient compte de la lecture', () => {
  // Dimanche 27/09/2026 (17 Tichri) : 'Hol hamoed en Israël, sa lecture ; second jour de Souccot en diaspora, Yom tov,
  // rien dans l'office de semaine.
  const iso = '2026-09-27';
  const l = (il) => lecturesOffice(donnees, iso, 'chaharit', { enIsrael: il, nusah: 'edot' });
  assert.equal(l(true)[0].cle, 'Sukkot Chol ha-Moed Day 1 (Israel)');
  assert.deepEqual(l(false), []);
  assert.match(app, /\|\| JSON\.stringify\(lecturesPour\(true\)\) !== JSON\.stringify\(lecturesPour\(false\)\)/);
  assert.ok(typeof signature === 'function');
});

test('le site : le module chargé à la demande, le texte en tête des textes de certains moments', () => {
  // Jamais d'import statique de lecture-torah.js : il ne se lit que les jours de lecture (D6).
  assert.ok(!/^import .*lecture-torah\.js/m.test(app));
  assert.match(app, /import\('\.\/lecture-torah\.js'\)/);
  assert.match(app, /g\.cle === 'moments' \? ligneHebreu\(LECTURE_TORAH\.titre\.he/);
  // La clé et le titre que garde app.js sont ceux du module (et d'Android, LectureTorah.TITRE).
  const m = app.match(/const LECTURE_TORAH = \{ id: '([^']+)', titre: \{ he: '([^']+)', fr: '([^']+)', en: '([^']+)' \} \};/);
  assert.deepEqual(m.slice(1), [ID_TEXTE, TITRE.he, TITRE.fr, TITRE.en]);
  for (const n of NUSAH) assert.ok(siddur[n].groupes.some((g) => g.cle === 'moments'), n);
  const kt = readFileSync(new URL('java/com/myhitbodedut/LectureTorah.kt', ANDROID), 'utf8');
  assert.ok(kt.includes(`LocalizedText("${TITRE.he}", "${TITRE.fr}", "${TITRE.en}")`));
});

test('les chaînes de la lecture dans les cinq langues, et la licence d\'hebcal', () => {
  for (const dossier of ['values', 'values-en', 'values-iw', 'values-es', 'values-ar-rTN']) {
    const xml = readFileSync(new URL(`res/${dossier}/strings.xml`, ANDROID), 'utf8');
    const { chaines, pluriels } = litChaines(xml);
    for (const cle of ['lecture_titre', 'lecture_haftara', 'lecture_paracha_semaine', 'lecture_paracha_chabbat', 'reglage_chnayim_mikra', 'lecture_hebreu_deux_fois',
      'lecture_hebreu_une_fois', 'lecture_chargement']) assert.ok(chaines[cle], `${dossier} ${cle}`);
    assert.ok(chaines.licences_texte.includes('toratemetfreeware.com'), dossier);
    assert.ok(pluriels.lecture_montees?.other, dossier);
    assert.ok(chaines.licences_texte.includes('@hebcal/leyning') && chaines.licences_texte.includes('BSD'), dossier);
  }
});
