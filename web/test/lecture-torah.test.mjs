// La lecture de la Torah des offices de semaine (26/11) : lecture-torah.js contre la référence, @hebcal/leyning
// 10.1.0 (dépendance de test seulement, BSD-2-Clause, jamais servie), chaque jour de six années hébraïques (5786 à
// 5791), en Israël et en diaspora, à Cha'harit et à Min'ha ; jamais Chabbat ni Yom tov. Les écarts sont nommés et
// comptés ici, chacun avec sa source dans tools/lecture_torah_construction.py ou lecture-torah.js. Puis les vecteurs
// que LectureTorahTest.kt relit (même réponse côté Android), les cas choisis, et le texte.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { HDate } from '@hebcal/core';
import { getLeyningOnDate } from '@hebcal/leyning';
import { ajouteJours } from '../src/js/calendrier.js';
import { calendrier, jour } from '../src/js/calendrier-juif.js';
import { chargeDonnees, chargeLivre, lectures, litDansLOffice, versets } from '../src/js/lecture-torah.js';
import { DEBUT, FIN, RAW, VECTEURS, decoupeTexte, resume, vecteurs } from '../tools/lecture-torah.mjs';

const D = JSON.parse(readFileSync(join(RAW, 'lecture_torah.json'), 'utf8'));
const TEXTE = JSON.parse(readFileSync(join(RAW, 'lecture_torah_texte.json'), 'utf8'));
const LIVRES = decoupeTexte(TEXTE);

const jours = function* (debut = DEBUT, fin = FIN) {
  for (let iso = debut; iso <= fin; iso = ajouteJours(iso, 1)) yield iso;
};
const hd = (iso) => new HDate(new Date(`${iso}T12:00:00`));
const passages = (l) => l.montees.map((m) => `${m.livre} ${m.debut}-${m.fin}`).join(', ');
/** Chabbat ou Yom tov : pas d'office de semaine, pas de lecture. */
const chome = (iso, il) => calendrier(iso, il, false, false).isAssurBemelacha();

/** La lecture de Cha'harit selon hebcal, sous la même forme ; null sans lecture de la Torah. */
function hebcal(iso, il) {
  const r = getLeyningOnDate(hd(iso), il);
  const al = r && (r.fullkriyah ?? r.weekday);
  if (!al || !al['1']) return null; // Veille de Pourim, de Ticha bèAv : la Méguila seule
  return { nom: r.name.en, texte: Object.values(al).map((a) => `${a.k} ${a.b}-${a.e}`).join(', ') };
}
const nous = (iso, il, nusah, office = 'chaharit', mukafChoma = false) => lectures(D, iso, office, { enIsrael: il, nusah, mukafChoma });

/** Pessa'h a commencé un jeudi (le Chabbat 17 Nissan est 'hol hamoèd). */
const pessahJeudi = (iso) => {
  const jc = calendrier(iso, true, false, false);
  return jc.getJewishMonth() === 1 && calendrier(ajouteJours(iso, 15 - jc.getJewishDayOfMonth()), true, false, false).getDayOfWeek() === 5;
};

/**
 * Les écarts voulus avec hebcal, par catégorie ; tout autre écart fait échouer le test.
 *  - souccot_israel : en Israël les quatre montées de 'Hol hamoèd lisent le sacrifice du jour (Rema O.H. 663:1 ;
 *    Kitsour Yalkout Yossef 662:1) ;
 *  - pessah_jeudi_israel : Pessa'h un jeudi, en Israël, קדש et בכספא le dimanche et le lundi (Kitsour
 *    Yalkout Yossef 488:12 ; hebcal relit פסל, lu le Chabbat) ;
 *  - chouchan_pourim_hors_jerusalem : le 15 Adar n'est Pourim qu'à Jérusalem (Choul'han Aroukh O.H. 688) ;
 *  - yom_haatsmaout : pas de lecture propre, coutume qui varie (comme CalendrierJuif, hors règles de prière).
 */
function ecartAshkenaz(iso, il, h, l) {
  if (il && l?.cle.includes('(Israel)')) return 'souccot_israel';
  if (il && pessahJeudi(iso) && /Pesach (IV|V) \(CH''M\)/.test(h?.nom ?? '')) return 'pessah_jeudi_israel';
  if (il && h?.nom === 'Shushan Purim') return 'chouchan_pourim_hors_jerusalem';
  if (h?.nom === "Yom HaAtzma'ut") return 'yom_haatsmaout';
  return null;
}

/** Les écarts propres aux Edot (chacun sourcé dans l'outil de construction). */
function ecartEdot(iso, il, h, l) {
  const c = l?.cle ?? '';
  if (/^Chanukah Day [1-578]$/.test(c)) return 'hanouka_edot';
  if (!il && (/^Sukkot Chol ha-Moed Day \d$/.test(c) || c === 'Sukkot Final Day (Hoshana Raba)')) return 'souccot_diaspora_edot';
  return null;
}

test('Chabbat et Yom tov : aucune lecture, à aucun office, dans aucun rite', () => {
  let n = 0;
  for (const iso of jours()) {
    for (const il of [false, true]) {
      if (!chome(iso, il)) continue;
      n++;
      for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
        for (const office of ['chaharit', 'minha']) assert.deepEqual(nous(iso, il, nusah, office), [], `${iso} ${il} ${nusah} ${office}`);
      }
    }
  }
  // De septembre 2025 à décembre 2031, en Israël et en diaspora.
  assert.equal(n, 770);
});

test('Cha\'harit, Ashkenaz : la lecture d\'hebcal chaque jour de semaine de 5786 à 5791, sauf les écarts nommés', () => {
  const ecarts = {};
  let n = 0;
  for (const iso of jours()) {
    for (const il of [false, true]) {
      if (chome(iso, il)) continue;
      const h = hebcal(iso, il);
      const [l] = nous(iso, il, 'ashkenaz');
      n++;
      if ((h?.texte ?? null) === (l ? passages(l) : null)) continue;
      const cat = ecartAshkenaz(iso, il, h, l);
      assert.ok(cat, `${iso} ${il ? 'Israël' : 'diaspora'} :\n  hebcal ${h?.nom} ${h?.texte}\n  ici    ${l?.cle} ${l && passages(l)}`);
      ecarts[cat] = (ecarts[cat] ?? 0) + 1;
    }
  }
  assert.equal(n, 3856);
  // Chaque catégorie sert, et seulement autant qu'attendu. De septembre 2025 à décembre 2031 : sept Souccot (six jours
  // de 'Hol hamoèd en Israël, moins quatre Chabbatot), trois Pessa'h un jeudi (2026, 2027, 2030), six Pourim.
  assert.deepEqual(ecarts, { souccot_israel: 38, pessah_jeudi_israel: 6, chouchan_pourim_hors_jerusalem: 6, yom_haatsmaout: 12 });
});

test('Cha\'harit, Edot : les coutumes du Choul\'han Aroukh là où elles diffèrent', () => {
  const ecarts = {};
  for (const iso of jours()) {
    for (const il of [false, true]) {
      if (chome(iso, il)) continue;
      const h = hebcal(iso, il);
      const [l] = nous(iso, il, 'edot');
      if ((h?.texte ?? null) === (l ? passages(l) : null)) continue;
      const cat = ecartEdot(iso, il, h, l) ?? ecartAshkenaz(iso, il, h, l);
      assert.ok(cat, `${iso} ${il ? 'Israël' : 'diaspora'} :\n  hebcal ${h?.nom} ${h?.texte}\n  ici    ${l?.cle} ${l && passages(l)}`);
      ecarts[cat] = (ecarts[cat] ?? 0) + 1;
    }
  }
  for (const cat of ['hanouka_edot', 'souccot_diaspora_edot', 'souccot_israel', 'pessah_jeudi_israel', 'chouchan_pourim_hors_jerusalem',
    'yom_haatsmaout']) assert.ok(ecarts[cat] > 0, cat);
});

test('Sfard : les lectures d\'Ashkenaz, chaque jour et à chaque office', () => {
  for (const iso of jours()) {
    for (const il of [false, true]) {
      for (const office of ['chaharit', 'minha']) {
        assert.deepEqual(nous(iso, il, 'sefard', office), nous(iso, il, 'ashkenaz', office), `${iso} ${il} ${office}`);
      }
    }
  }
});

test('Min\'ha des jeûnes : « ויחל » d\'hebcal ; le troisième maftir chez Ashkenaz, et le 9 Av chez les Edot', () => {
  let jeunes = 0;
  for (const iso of jours()) {
    for (const il of [false, true]) {
      const m = getLeyningOnDate(hd(iso), il, true).find((r) => r.name.en.endsWith('(Mincha)'));
      const [a] = nous(iso, il, 'ashkenaz', 'minha');
      const [e] = nous(iso, il, 'edot', 'minha');
      // Kippour est Yom tov : pas d'office de semaine.
      if (!m || m.name.en.startsWith('Yom Kippur')) {
        assert.equal(a, undefined, iso);
        continue;
      }
      jeunes++;
      assert.equal(passages(a), Object.values(m.fullkriyah).map((x) => `${x.k} ${x.b}-${x.e}`).join(', '), iso);
      assert.equal(passages(e), passages(a), iso);
      assert.equal(a.montees[2].libelle.fr, 'Maftir', iso);
      assert.equal(e.montees[2].libelle.fr, m.name.en.startsWith("Tish'a B'Av") ? 'Maftir' : 'Israël', iso);
    }
  }
  // De septembre 2025 à décembre 2031 : six ans de cinq jeûnes, plus Guedalia et le 10 Tévet de 5792 ; en Israël et
  // en diaspora.
  assert.equal(jeunes, 64);
});

test('le calendrier et le calcul s\'accordent : une lecture les jours où l\'office en a une, et ces jours seulement', () => {
  for (const iso of jours()) {
    for (const [il, muk] of [[false, false], [true, false], [true, true]]) {
      const j = jour(iso, il, muk);
      for (const office of ['chaharit', 'minha']) {
        const l = lectures(D, iso, office, { enIsrael: il, mukafChoma: muk });
        // Yom ha-Atsmaout n'a pas de lecture propre (un jour sans Ta'hanoun que CalendrierJuif ne compte pas).
        assert.equal(l.length > 0, litDansLOffice(j, office), `${iso} ${il} ${muk} ${office}`);
      }
    }
  }
});

test('les vecteurs partagés avec LectureTorahTest.kt sont la réponse actuelle (sinon : node web/tools/lecture-torah.mjs)', () => {
  const attendu = JSON.parse(readFileSync(VECTEURS, 'utf8'));
  const v = vecteurs(D, attendu.debut, attendu.fin);
  assert.equal(Object.keys(v.jours).length, Object.keys(attendu.jours).length);
  for (const [k, x] of Object.entries(attendu.jours)) assert.deepEqual(v.jours[k], x, k);
});

test('les données : les seules lectures des jours de semaine, chacune lue un jour, rien d\'autre', () => {
  assert.deepEqual(Object.keys(D).sort(), ['_meta', 'lectures', 'livres', 'montees', 'parachiot']);
  assert.deepEqual(Object.keys(D.livres), ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']);
  assert.deepEqual(Object.keys(D.montees).sort(), ['1', '2', '3', '3_israel', '4', 'M']);
  for (const [k, p] of Object.entries(D.parachiot)) assert.deepEqual(Object.keys(p), ['hebcal', 'titre', 'semaine'], k);
  for (const [k, e] of Object.entries(D.lectures)) {
    assert.ok(Object.keys(e).every((c) => ['titre', 'alias', 'alyot', 'alyot_edot'].includes(c)), k);
  }
  // Chaque lecture sert un jour (2000-2060, hebcal compris), sauf les deux que reprennent les jeûnes (alias).
  const vues = new Set();
  for (let iso = '2000-01-01'; iso <= '2060-12-31'; iso = ajouteJours(iso, 1)) {
    for (const [il, muk] of [[false, false], [true, false], [true, true]]) {
      for (const office of ['chaharit', 'minha']) lectures(D, iso, office, { enIsrael: il, mukafChoma: muk }).forEach((l) => vues.add(l.cle));
    }
  }
  assert.deepEqual(Object.keys(D.lectures).filter((k) => !vues.has(k)), ['Fast Day (Morning)', 'Fast Day (Afternoon)']);
  assert.deepEqual(Object.keys(D.parachiot).filter((k) => !vues.has(`semaine:${k}`)), []);
});

// --- Cas choisis -----------------------------------------------------------------------------------

const une = (iso, opts = {}, office = 'chaharit') => {
  const l = lectures(D, iso, office, { enIsrael: false, nusah: 'ashkenaz', ...opts });
  assert.equal(l.length, 1, `${iso} : ${l.length} lectures`);
  return l[0];
};

test('\'Hanouka, jours 2 à 7 (5787), Roch \'Hodech Tévèt compris, Ashkenaz et Edot', () => {
  const att = {
    '2026-12-06': ['Chanukah Day 2', '3:Numbers 7:24-7:29', '3:Numbers 7:18-7:23'],
    '2026-12-10': ['Chanukah Day 6', '4:Numbers 7:42-7:47', '4:Numbers 7:42-7:47'],
    '2026-12-11': ['Chanukah Day 7 (on Rosh Chodesh)', '4:Numbers 7:48-7:53', '4:Numbers 7:48-7:53'],
  };
  for (const [iso, [cle, a, e]] of Object.entries(att)) {
    const la = une(iso), le = une(iso, { nusah: 'edot' });
    assert.equal(la.cle, cle, iso);
    const fin = (l) => { const m = l.montees.at(-1); return `${m.cle}:${m.livre} ${m.debut}-${m.fin}`; };
    assert.equal(fin(la), a, iso);
    assert.equal(fin(le), e, iso);
  }
  // Le premier jour (vendredi) et le huitième (Chabbat) de 5787 : le Chabbat, rien.
  assert.deepEqual(lectures(D, '2026-12-12', 'chaharit', { nusah: 'edot' }), []);
  assert.deepEqual(lectures(D, '2026-12-05', 'chaharit', { nusah: 'edot' }), []);
  // Le premier jour en semaine (5786) : Edot depuis la bénédiction des cohanim.
  assert.deepEqual(une('2025-12-15', { nusah: 'edot' }).montees.map((m) => `${m.debut}-${m.fin}`), ['6:22-7:3', '7:4-7:11', '7:12-7:17']);
  assert.deepEqual(une('2025-12-15').montees.map((m) => `${m.debut}-${m.fin}`), ['7:1-7:11', '7:12-7:14', '7:15-7:17']);
});

test('9 Av, matin et Min\'ha (5786, jeudi 23/07/2026), et le 10 Tévet (5787)', () => {
  const m = une('2026-07-23');
  assert.equal(m.cle, "Tish'a B'Av");
  assert.equal(passages(m), 'Deuteronomy 4:25-4:29, Deuteronomy 4:30-4:35, Deuteronomy 4:36-4:40');
  assert.equal(passages(une('2026-07-23', { nusah: 'edot' })), passages(m));
  assert.equal(une('2026-07-23', {}, 'minha').titre.fr, 'Ticha bèAv');
  assert.equal(passages(une('2026-07-23', {}, 'minha')), 'Exodus 32:11-32:14, Exodus 34:1-34:3, Exodus 34:4-34:10');
  // Le 10 Tévet (dimanche 20/12/2026) : le matin et à Min'ha.
  assert.equal(une('2026-12-20').titre.fr, 'Jeûne du 10 Tévet');
  assert.equal(une('2026-12-20', {}, 'minha').cle, "Asara B'Tevet (Mincha)");
});

test('Pourim : le 14 hors de Jérusalem, le 15 à Jérusalem ; le Pourim triple', () => {
  // 5787 : Pourim mardi 23/03/2027, Chouchan Pourim mercredi.
  assert.equal(une('2027-03-23').cle, 'Purim');
  assert.equal(une('2027-03-23', { enIsrael: true }).cle, 'Purim');
  assert.deepEqual(lectures(D, '2027-03-23', 'chaharit', { enIsrael: true, mukafChoma: true }), []);
  assert.equal(une('2027-03-24', { enIsrael: true, mukafChoma: true }).cle, 'Shushan Purim');
  assert.equal(une('2027-03-24', { enIsrael: true, mukafChoma: true }).titre.fr, 'Pourim à Jérusalem (Chouchan Pourim)');
  assert.deepEqual(lectures(D, '2027-03-24', 'chaharit', { enIsrael: true }), []);
  // Pourim triple : le 15 Adar un Chabbat (cherché) ; ce Chabbat, rien. Le vendredi 14, Pourim partout ailleurs ; à
  // Jérusalem, pas de lecture (Méguila seule).
  let iso = '2025-09-01';
  for (; ; iso = ajouteJours(iso, 1)) {
    const jc = calendrier(iso, true, false, true);
    if (jc.getDayOfWeek() === 7 && jc.isPurim()) break;
  }
  assert.deepEqual(lectures(D, iso, 'chaharit', { enIsrael: true, mukafChoma: true }), []);
  assert.equal(une(ajouteJours(iso, -1), { enIsrael: true }).cle, 'Purim');
  assert.deepEqual(lectures(D, ajouteJours(iso, -1), 'chaharit', { enIsrael: true, mukafChoma: true }), []);
});

test('\'Hol hamoèd : Souccot en Israël et en diaspora, Pessa\'h un jeudi en Israël', () => {
  // Souccot 5787 : lundi 28/09/2026 (17 Tichri). Israël : les quatre lisent le sacrifice du jour ; diaspora, Edot :
  // le cohen le premier jour du doute, le lévi et le troisième le second, le quatrième les deux.
  assert.deepEqual(new Set(une('2026-09-28', { enIsrael: true }).montees.map((m) => `${m.debut}-${m.fin}`)), new Set(['29:20-29:22']));
  assert.equal(une('2026-09-28').cle, 'Sukkot Chol ha-Moed Day 1');
  assert.deepEqual(une('2026-09-28', { nusah: 'edot' }).montees.map((m) => `${m.debut}-${m.fin}`), ['29:17-29:19', '29:20-29:22', '29:20-29:22', '29:17-29:22']);
  // Dimanche 27/09/2026 (16 Tichri) : 'Hol hamoèd en Israël, Yom tov en diaspora.
  assert.equal(une('2026-09-27', { enIsrael: true }).cle, 'Sukkot Chol ha-Moed Day 1 (Israel)');
  assert.deepEqual(lectures(D, '2026-09-27', 'chaharit', { nusah: 'edot' }), []);
  // Pessa'h un jeudi en Israël : קדש dimanche, בכספא lundi, במדברא mardi.
  assert.deepEqual(['2026-04-05', '2026-04-06', '2026-04-07'].map((d) => une(d, { enIsrael: true }).montees[0].debut), ['13:1', '22:24', '9:1']);
  // Le 16 Nissan en Israël (vendredi 03/04/2026) : 'Hol hamoèd ; en diaspora, Yom tov.
  assert.equal(une('2026-04-03', { enIsrael: true }).cle, "Pesach II (CH''M)");
  assert.deepEqual(lectures(D, '2026-04-03', 'chaharit', {}), []);
});

test('semaines où Israël et la diaspora lisent des parachiot différentes', () => {
  // Chavouot II un samedi en diaspora (23/05/2026) : Israël lit Nasso ce Chabbat, la diaspora le suivant.
  assert.equal(une('2026-05-25').cle, 'semaine:NASSO');
  assert.equal(une('2026-05-25', { enIsrael: true }).cle, 'semaine:BEHAALOSCHA');
  // Après Sim'hat Torah en Israël (5787) : un dimanche ordinaire, puis Berèchit le lundi.
  assert.deepEqual(lectures(D, '2026-10-04', 'chaharit', { enIsrael: true, nusah: 'edot' }), []);
  assert.equal(une('2026-10-05', { enIsrael: true }).cle, 'semaine:BERESHIS');
});

test('les jours de lecture, ni plus ni moins', () => {
  // Un mardi ordinaire : rien ; Roch 'Hodech un mardi : quatre montées ; un lundi ou un jeudi : trois.
  assert.deepEqual(lectures(D, '2026-11-24', 'chaharit', { nusah: 'edot' }), []);
  assert.equal(une('2026-11-10').cle, 'Rosh Chodesh');
  assert.equal(une('2026-11-10').montees.length, 4);
  assert.equal(une('2026-11-26').cle, 'semaine:VAYISHLACH'); // jeudi 26/11/2026
  assert.equal(une('2026-11-26').titre.fr, 'Vayichla’h');
  assert.deepEqual(une('2026-11-26').montees.map((m) => m.libelle.fr), ['Cohen', 'Lévi', 'Israël']);
  assert.deepEqual(lectures(D, '2026-11-26', 'minha', { nusah: 'edot' }), []);
  // Un Chabbat, ni le matin ni à Min'ha.
  assert.deepEqual(lectures(D, '2026-11-28', 'chaharit', { nusah: 'edot' }), []);
  assert.deepEqual(lectures(D, '2026-11-28', 'minha', { nusah: 'edot' }), []);
});

// --- Le texte ----------------------------------------------------------------------------------------

test('chaque passage des données a son texte, vocalisé, avec ses teamim ; rien d\'autre n\'est gardé', () => {
  const tous = [...Object.values(D.parachiot).map((p) => p.semaine),
    ...Object.values(D.lectures).flatMap((e) => [e.alyot, e.alyot_edot].filter(Boolean))].flat();
  const chapitres = new Set();
  for (const [, livre, debut, fin] of tous) {
    const k = `${livre} ${debut}-${fin}`;
    const v = versets(livre, debut, fin, LIVRES[livre]);
    assert.ok(v.length > 0, k);
    for (const x of v) {
      chapitres.add(`${livre} ${x.c}`);
      assert.ok(x.t && /[֑-֯]/.test(x.t) && /[ְ-ּ]/.test(x.t), `${k} ${x.c}:${x.v}`);
      assert.ok(!/[[\]()<>{}]/.test(x.t), `${k} ${x.c}:${x.v}`);
    }
  }
  assert.ok(tous.length > 300, `${tous.length}`);
  // Le texte ne garde que les chapitres lus, en entier.
  const gardes = Object.entries(TEXTE.livres).flatMap(([livre, c]) => Object.keys(c).map((n) => `${livre} ${n}`));
  assert.deepEqual(gardes.filter((c) => !chapitres.has(c)), []);
  assert.equal(gardes.length, chapitres.size);
  assert.deepEqual(Object.keys(TEXTE.livres), ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']);
  // Le qere : Berèchit 25:23 « גוֹיִם֙ » (ketiv גיים) ; Bamidbar 25:19 suit la numérotation d'hebcal ; les fins de paragraphe.
  assert.ok(versets('Genesis', '25:23', '25:23', LIVRES.Genesis)[0].t.includes('שְׁנֵ֤י גוֹיִם֙'));
  assert.equal(versets('Numbers', '25:19', '25:19', LIVRES.Numbers)[0].t, 'וַיְהִ֖י אַחֲרֵ֣י הַמַּגֵּפָ֑ה');
  assert.ok(Object.values(TEXTE.paragraphes.Genesis).every((x) => x === 'פ' || x === 'ס'));
});

test('le site lit les données à la demande, un livre à la fois', async () => {
  const lus = [];
  const lire = async (u) => { lus.push(u); return u.endsWith('lecture_torah.json') ? D : LIVRES[u.split('/').pop().replace('.json', '')]; };
  const d = await chargeDonnees(lire);
  const [l] = lectures(d, '2026-11-26', 'chaharit', { nusah: 'edot' });
  const livre = await chargeLivre(l.montees[0].livre, lire);
  await chargeLivre(l.montees[0].livre, lire);
  assert.deepEqual(lus, ['data/lecture_torah.json', 'data/lecture_torah/Genesis.json']);
  assert.equal(versets('Genesis', l.montees[0].debut, l.montees[0].fin, livre)[0].c, 32);
  // Aucun module du site n'importe la lecture au démarrage.
  const app = readFileSync(new URL('../src/js/app.js', import.meta.url), 'utf8');
  assert.ok(!/from '\.\/lecture-torah\.js'/.test(app) || /import\('\.\/lecture-torah\.js'\)/.test(app));
  assert.equal(resume(l), 'semaine:VAYISHLACH|1:Genesis 32:4-32:6,2:Genesis 32:7-32:9,3:Genesis 32:10-32:13');
});
