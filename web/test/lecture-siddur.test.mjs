// La lecture de la Torah dans le siddour (26/11) : à sa place dans chaque office de semaine, repliée, ses montées
// dépliées. Les mêmes cas qu'Android (LectureSiddurTest.kt).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { NUSAH, lecturesOffice, litDansLOffice, reference } from '../src/js/lecture-torah.js';
import { conditionsPour, index, placeLecture, plan, segments, signature } from '../src/js/siddur-jour.js';
import { litChaines } from '../tools/chaines.mjs';

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
    assert.equal(l[0].length, 1, nusah);
    assert.equal(l[0][0].cle, 'semaine:VAYISHLACH');
    assert.deepEqual(l[0][0].montees.map((m) => m.libelle.fr), ['Cohen', 'Lévi', 'Israël']);
    assert.deepEqual(Object.keys(l[0][0]), ['cle', 'titre', 'montees']);
    const k = d.findIndex((x) => x.lecture);
    assert.match(d[k - 1].texte, /^ברוך אתה (יהוה|ה׳|יי).*אשר נתן/, nusah);
    if (nusah !== 'edot') assert.ok(d.findIndex((x) => x.replie === 'ajout_mi_cheberakh_oleh') > k, nusah);
  }
  // « Berèchit 32:4–6 » : les noms hébreux des livres, écrits à la manière de chaque langue.
  const [m] = lecturesDe(deroule('edot', 'chaharit', '2026-11-23'))[0][0].montees;
  assert.equal(reference(donnees, m.livre, m.debut, m.fin), 'Berèchit 32:4–6');
  assert.equal(reference(donnees, m.livre, m.debut, m.fin, (t) => t.en), 'Bereshit 32:4–6');
  assert.equal(reference(donnees, m.livre, m.debut, m.fin, (t) => t.he), 'בראשית 32:4–6');
  assert.deepEqual(Object.values(donnees.livres).map((t) => [t.fr, t.en]),
    [['Berèchit', 'Bereshit'], ['Chemot', 'Shemot'], ['Vayikra', 'Vayikra'], ['Bamidbar', 'Bamidbar'], ['Devarim', 'Devarim']]);
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

test('9 Av, le matin et à Min\'ha, une seule lecture ; plus de repère qui la décrivait', () => {
  for (const nusah of NUSAH) {
    const matin = lecturesDe(deroule(nusah, 'chaharit', '2026-07-23'));
    assert.deepEqual(matin.map((l) => l.map((x) => x.cle)), [["Tish'a B'Av"]], nusah);
    assert.deepEqual(matin[0][0].montees.map((m) => m.debut), ['4:25', '4:30', '4:36']);
    const minha = lecturesDe(deroule(nusah, 'minha', '2026-07-23'));
    assert.deepEqual(minha.map((l) => l.map((x) => x.cle)), [["Tish'a B'Av (Mincha)"]], nusah);
    // Le troisième : maftir, dans les trois rites ce jour-là.
    assert.equal(minha[0][0].montees[2].libelle.fr, 'Maftir', nusah);
    const indices = annotations[nusah].minha.filter((a) => a.sorte === 'indice').map((a) => a.texte);
    assert.ok(!indices.some((t) => t.includes('ויחל') || t.includes('שובה ישראל')), nusah);
  }
});

test('un jeûne public à Min\'ha : le troisième selon le rite', () => {
  for (const nusah of NUSAH) {
    const l = lecturesDe(deroule(nusah, 'minha', '2026-12-20'));
    assert.deepEqual(l.map((x) => x.map((y) => y.cle)), [["Asara B'Tevet (Mincha)"]], nusah);
    assert.equal(l[0][0].montees[2].libelle.fr, nusah === 'edot' ? 'Israël' : 'Maftir', nusah);
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
  assert.match(app, /lectureApres = \(si, i\) => \(lecturesDuJour\.length && placeLecture\(idx, si, i, c\) \? boitesLecture\(lecturesDuJour\) : \[\]\)/);
});

test('la question Israël ou diaspora tient compte de la lecture', () => {
  // Dimanche 27/09/2026 (16 Tichri) : 'Hol hamoed en Israël, sa lecture ; second jour de Souccot en diaspora, Yom tov,
  // rien dans l'office de semaine.
  const iso = '2026-09-27';
  const l = (il) => lecturesOffice(donnees, iso, 'chaharit', { enIsrael: il, nusah: 'edot' });
  assert.equal(l(true)[0].cle, 'Sukkot Chol ha-Moed Day 1 (Israel)');
  assert.deepEqual(l(false), []);
  assert.match(app, /\|\| JSON\.stringify\(lecturesPour\(true\)\) !== JSON\.stringify\(lecturesPour\(false\)\)/);
  assert.ok(typeof signature === 'function');
});

test('le site : le module chargé à la demande, les offices de semaine seuls', () => {
  // Jamais d'import statique de lecture-torah.js : il ne se lit que les jours de lecture (D6).
  assert.ok(!/^import .*lecture-torah\.js/m.test(app));
  assert.match(app, /import\('\.\/lecture-torah\.js'\)/);
  // Une boîte par lecture, ses montées seules.
  assert.match(app, /function boitesLecture\(lectures\) \{\n {2}return lectures\.map\(\(l\) => boiteLecture\(/);
  // build.mjs ne découpe que le texte des lectures, un fichier par livre de la Torah.
  const build = readFileSync(new URL('../build.mjs', import.meta.url), 'utf8');
  assert.deepEqual([...new Set(build.match(/lecture_torah[a-z_]*\.json/g))].sort(), ['lecture_torah.json', 'lecture_torah_texte.json']);
});

test('les chaînes de la lecture dans les cinq langues, et la licence d\'hebcal', () => {
  for (const dossier of ['values', 'values-en', 'values-iw', 'values-es', 'values-ar-rTN']) {
    const xml = readFileSync(new URL(`res/${dossier}/strings.xml`, ANDROID), 'utf8');
    const { chaines, pluriels } = litChaines(xml);
    for (const cle of ['lecture_titre', 'lecture_chargement']) assert.ok(chaines[cle], `${dossier} ${cle}`);
    assert.ok(pluriels.lecture_montees?.other, dossier);
    assert.ok(chaines.licences_texte.includes('@hebcal/leyning') && chaines.licences_texte.includes('BSD'), dossier);
    assert.ok(chaines.licences_texte.includes('Tanach with Ta’amei Hamikra'), dossier);
  }
});
