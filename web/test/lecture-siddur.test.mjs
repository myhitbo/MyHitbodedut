// La lecture de la Torah dans le siddour (26/11, phase B) : à sa place dans chaque office, repliée, puis sa haftara ;
// et le texte « Lecture de la Torah ». Les mêmes cas qu'Android (LectureSiddurTest.kt).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { ID_TEXTE, NUSAH, TITRE, lectures, programme, reference } from '../src/js/lecture-torah.js';
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
  const l = lectures(donnees, iso, office, { enIsrael: israel, nusah });
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

test('le texte « Lecture de la Torah » : Chabbat matin et Min\'ha, Chemini Atsérèt, un jour sans lecture', () => {
  const chabbat = programme(donnees, '2026-11-28', { nusah: 'edot' });
  assert.equal(chabbat.aujourdhui, true);
  assert.deepEqual(chabbat.offices.map(([o]) => o), ['chaharit', 'minha']);
  assert.equal(chabbat.offices[0][1][0].cle, 'parasha:VAYISHLACH');
  assert.equal(chabbat.offices[0][1][0].haftara[0].livre, 'Obadiah');
  assert.equal(chabbat.offices[0][1][0].montees.length, 8);
  assert.equal(chabbat.offices[1][1][0].cle, 'semaine:VAYESHEV');
  // Chemini Atsérèt un Chabbat (03/10/2026) : Sim'hat Torah en Israël, Chemini Atsérèt en diaspora.
  const il = programme(donnees, '2026-10-03', { enIsrael: true, nusah: 'ashkenaz' });
  const dia = programme(donnees, '2026-10-03', { enIsrael: false, nusah: 'ashkenaz' });
  assert.equal(il.offices[0][1][0].cle, 'Simchat Torah (on Shabbat)');
  assert.equal(dia.offices[0][1][0].cle, 'Shmini Atzeret (on Shabbat)');
  assert.notEqual(JSON.stringify(il), JSON.stringify(dia)); // d'où la question Israël ou diaspora
  // Un mardi sans lecture (24/11/2026) : la paracha du Chabbat qui vient, avec sa date ; un lundi a la sienne.
  const mardi = programme(donnees, '2026-11-24', { nusah: 'edot' });
  assert.equal(mardi.aujourdhui, false);
  assert.equal(mardi.date, '2026-11-28');
  assert.equal(mardi.offices[0][1][0].cle, 'parasha:VAYISHLACH');
  assert.equal(programme(donnees, '2026-11-23', { nusah: 'edot' }).aujourdhui, true);
  // Un dimanche avant Roch 'Hodech Kislev (mardi 10/11/2026) : celui-ci d'abord.
  assert.equal(programme(donnees, '2026-11-08', { nusah: 'edot' }).offices[0][1][0].cle, 'Rosh Chodesh');
});

test('la question Israël ou diaspora tient compte de la lecture', () => {
  // Dimanche 04/10/2026 (23 Tichri) : Sim'hat Torah en diaspora, rien en Israël ; les ajouts seuls ne le disent pas.
  const iso = '2026-10-04';
  const l = (il) => lectures(donnees, iso, 'chaharit', { enIsrael: il, nusah: 'edot' });
  assert.deepEqual(l(true), []);
  assert.equal(l(false)[0].cle, 'Simchat Torah');
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
    for (const cle of ['lecture_titre', 'lecture_haftara', 'lecture_prochaine', 'lecture_jour', 'lecture_chargement']) assert.ok(chaines[cle], `${dossier} ${cle}`);
    assert.ok(pluriels.lecture_montees?.other, dossier);
    assert.ok(chaines.licences_texte.includes('@hebcal/leyning') && chaines.licences_texte.includes('BSD'), dossier);
  }
});
