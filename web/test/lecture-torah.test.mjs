// La lecture de la Torah du jour (26/11) : lecture-torah.js contre la référence, @hebcal/leyning
// 10.1.0 (dépendance de test seulement, BSD-2-Clause, jamais servie), chaque jour de six années
// hébraïques (5786 à 5791), en Israël et en diaspora, à Cha'harit et à Min'ha ; les écarts sont
// nommés et comptés ici, chacun avec sa source dans tools/lecture_torah_construction.py ou
// lecture-torah.js. Puis les vecteurs que LectureTorahTest.kt relit (même réponse côté Android),
// les cas choisis, et le texte.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';
import { HDate } from '@hebcal/core';
import { getLeyningForParsha, getLeyningOnDate } from '@hebcal/leyning';
import { ajouteJours } from '../src/js/calendrier.js';
import { calendrier } from '../src/js/calendrier-juif.js';
import { chargeDonnees, chargeLivre, lectures, parachaApres, versets } from '../src/js/lecture-torah.js';
import { DEBUT, FIN, RAW, VECTEURS, decoupeTexte, resume, vecteurs } from '../tools/lecture-torah.mjs';

const D = JSON.parse(readFileSync(join(RAW, 'lecture_torah.json'), 'utf8'));
const TEXTE = JSON.parse(readFileSync(join(RAW, 'lecture_torah_texte.json'), 'utf8'));
const LIVRES = decoupeTexte(TEXTE);

const jours = function* (debut = DEBUT, fin = FIN) {
  for (let iso = debut; iso <= fin; iso = ajouteJours(iso, 1)) yield iso;
};
const hd = (iso) => new HDate(new Date(`${iso}T12:00:00`));
const segs = (h) => (h ? (Array.isArray(h) ? h : [h]) : []).map((x) => `${x.k} ${x.b}-${x.e}`).join('; ');
const passages = (l) => `${l.montees.map((m) => `${m.livre} ${m.debut}-${m.fin}`).join(', ')} | ${l.haftara.map((h) => `${h.livre} ${h.debut}-${h.fin}`).join('; ')}`;

/** La lecture de Cha'harit selon hebcal, sous la même forme ; null sans lecture de la Torah. */
function hebcal(iso, il, sefarade) {
  const r = getLeyningOnDate(hd(iso), il);
  const al = r && (r.fullkriyah ?? r.weekday);
  if (!al || !al['1']) return null; // Veille de Pourim, de Ticha bèAv : la Méguila seule
  const h = sefarade ? (r.seph ?? r.haft) : r.haft;
  return { nom: r.name.en, texte: `${Object.values(al).map((a) => `${a.k} ${a.b}-${a.e}`).join(', ')} | ${segs(h)}` };
}
const nous = (iso, il, nusah, office = 'chaharit', mukafChoma = false) => lectures(D, iso, office, { enIsrael: il, nusah, mukafChoma });

/** Pessa'h a commencé un jeudi (le Chabbat 17 Nissan est 'hol hamoèd). */
const pessahJeudi = (iso) => {
  const jc = calendrier(iso, true, false, false);
  return jc.getJewishMonth() === 1 && calendrier(ajouteJours(iso, 15 - jc.getJewishDayOfMonth()), true, false, false).getDayOfWeek() === 5;
};

/**
 * Les écarts voulus avec hebcal, par catégorie ; tout autre écart fait échouer le test.
 *  - souccot_israel : en Israël les quatre montées de 'Hol hamoèd lisent le sacrifice du jour, et le maftir
 *    du Chabbat aussi (Rema O.H. 663:1 ; Kitsour Yalkout Yossef 662:1 et 4) ;
 *  - pessah_jeudi_israel : Pessa'h un jeudi, en Israël, קדש et בכספא le dimanche et le lundi (Kitsour
 *    Yalkout Yossef 488:12 ; hebcal relit פסל, lu le Chabbat) ;
 *  - chouchan_pourim_hors_jerusalem : le 15 Adar n'est Pourim qu'à Jérusalem (Choul'han Aroukh O.H. 688) ;
 *  - yom_haatsmaout : pas de lecture propre, coutume qui varie (comme CalendrierJuif, hors règles de prière).
 */
function ecartAshkenaz(iso, il, h, l) {
  if (il && (l?.cle.includes('(Israel)') || l?.cle === 'Sukkot Shabbat Chol ha-Moed')) return 'souccot_israel';
  if (il && pessahJeudi(iso) && /Pesach (IV|V) \(CH''M\)/.test(h?.nom ?? '')) return 'pessah_jeudi_israel';
  if (il && h?.nom === 'Shushan Purim') return 'chouchan_pourim_hors_jerusalem';
  if (h?.nom === "Yom HaAtzma'ut") return 'yom_haatsmaout';
  return null;
}

/** Les écarts propres aux Edot (chacun sourcé dans l'outil de construction). */
function ecartEdot(iso, il, h, l) {
  const c = l?.cle ?? '';
  if (/^Chanukah Day [1-578]$/.test(c) || c.includes('Chanukah Day 1 (on Shabbat)')) return 'hanouka_edot';
  if (!il && (/^Sukkot Chol ha-Moed Day \d$/.test(c) || c === 'Sukkot Final Day (Hoshana Raba)')) return 'souccot_diaspora_edot';
  if (!il && c === 'Shmini Atzeret') return 'chemini_atseret_edot';
  if (c.startsWith('Simchat Torah')) return 'simhat_torah_edot';
  if (/Shabbat Rosh Chodesh$|Shabbat Shekalim$|HaChodesh \(on Rosh Chodesh\)|Re'eh on Shabbat|Ki Teitzei with 3rd/.test(c)) return 'haftara_ajouts_edot';
  return null;
}

test('Cha\'harit, Ashkenaz : la lecture d\'hebcal chaque jour de 5786 à 5791, sauf les écarts nommés', () => {
  const ecarts = {};
  let n = 0;
  for (const iso of jours()) {
    for (const il of [false, true]) {
      const h = hebcal(iso, il, false);
      const [l] = nous(iso, il, 'ashkenaz');
      n++;
      if ((h?.texte ?? null) === (l ? passages(l) : null)) continue;
      const cat = ecartAshkenaz(iso, il, h, l);
      assert.ok(cat, `${iso} ${il ? 'Israël' : 'diaspora'} :\n  hebcal ${h?.nom} ${h?.texte}\n  ici    ${l?.cle} ${l && passages(l)}`);
      ecarts[cat] = (ecarts[cat] ?? 0) + 1;
    }
  }
  assert.equal(n, 4626);
  // Chaque catégorie sert, et seulement autant qu'attendu (six 'Hol hamoèd, trois Pessa'h un jeudi…).
  // De septembre 2025 à décembre 2031 : sept Souccot, trois Pessa'h un jeudi (2026, 2027, 2030), six Pourim.
  assert.deepEqual(ecarts, { souccot_israel: 42, pessah_jeudi_israel: 6, chouchan_pourim_hors_jerusalem: 6, yom_haatsmaout: 12 });
});

test('Cha\'harit, Edot : les haftarot séfarades d\'hebcal, et les coutumes du Choul\'han Aroukh là où elles diffèrent', () => {
  const ecarts = {};
  for (const iso of jours()) {
    for (const il of [false, true]) {
      const h = hebcal(iso, il, true);
      const [l] = nous(iso, il, 'edot');
      if ((h?.texte ?? null) === (l ? passages(l) : null)) continue;
      const cat = ecartEdot(iso, il, h, l) ?? ecartAshkenaz(iso, il, h, l);
      assert.ok(cat, `${iso} ${il ? 'Israël' : 'diaspora'} :\n  hebcal ${h?.nom} ${h?.texte}\n  ici    ${l?.cle} ${l && passages(l)}`);
      ecarts[cat] = (ecarts[cat] ?? 0) + 1;
    }
  }
  for (const cat of ['hanouka_edot', 'souccot_diaspora_edot', 'chemini_atseret_edot', 'simhat_torah_edot', 'haftara_ajouts_edot',
    'souccot_israel', 'pessah_jeudi_israel', 'chouchan_pourim_hors_jerusalem', 'yom_haatsmaout']) assert.ok(ecarts[cat] > 0, cat);
});

test('Sfard : les lectures et les haftarot d\'Ashkenaz, chaque jour et à chaque office', () => {
  for (const iso of jours()) {
    for (const il of [false, true]) {
      for (const office of ['chaharit', 'minha']) {
        assert.deepEqual(nous(iso, il, 'sefard', office), nous(iso, il, 'ashkenaz', office), `${iso} ${il} ${office}`);
      }
    }
  }
});

test('Min\'ha des jeûnes et de Kippour : hebcal pour Ashkenaz ; Edot sans haftara, sauf le 9 Av (« שובה ישראל », « מי אל כמוך »)', () => {
  let jeunes = 0;
  for (const iso of jours()) {
    for (const il of [false, true]) {
      const m = getLeyningOnDate(hd(iso), il, true).find((r) => r.name.en.endsWith('(Mincha)'));
      const [a] = nous(iso, il, 'ashkenaz', 'minha');
      const [e] = nous(iso, il, 'edot', 'minha');
      if (!m) {
        // Sans Min'ha particulière : rien en semaine, le début de la paracha qui vient le Chabbat.
        if (a) assert.ok(a.cle.startsWith('semaine:'), `${iso} ${a.cle}`);
        continue;
      }
      jeunes++;
      assert.equal(passages(a), `${Object.values(m.fullkriyah).map((x) => `${x.k} ${x.b}-${x.e}`).join(', ')} | ${segs(m.haft)}`, iso);
      if (m.name.en.startsWith('Yom Kippur')) assert.equal(passages(e), passages(a), iso);
      else if (m.name.en.startsWith("Tish'a B'Av")) {
        assert.equal(passages(e), 'Exodus 32:11-32:14, Exodus 34:1-34:3, Exodus 34:4-34:10 | Hosea 14:2-14:10; Micah 7:18-7:20', iso);
        assert.equal(e.montees[2].libelle.fr, 'Maftir');
      } else {
        assert.equal(passages(e), 'Exodus 32:11-32:14, Exodus 34:1-34:3, Exodus 34:4-34:10 | ', iso);
        assert.equal(e.montees[2].libelle.fr, 'Israël');
      }
    }
  }
  // De septembre 2025 à décembre 2031 : six ans de cinq jeûnes et Kippour, plus Guedalia, Kippour et le 10 Tévet
  // de 5792 ; en Israël et en diaspora.
  assert.equal(jeunes, 78);
});

test('Chabbat à Min\'ha : le début de la paracha qui vient (hebcal), Vézot haBérakha de Kippour à Sim\'hat Torah', () => {
  let n = 0;
  for (const iso of jours()) {
    if (new Date(`${iso}T12:00:00Z`).getUTCDay() !== 6) continue;
    for (const il of [false, true]) {
      const [l] = nous(iso, il, 'ashkenaz', 'minha');
      if (getLeyningOnDate(hd(iso), il, true).some((r) => r.name.en === 'Yom Kippur (Mincha)')) continue;
      const jc = calendrier(iso, il, false, false);
      // La paracha de la première lecture de paracha d'hebcal qui suit, en semaine (findParshaHaShavua) ou le
      // Chabbat ; de Kippour à
      // Sim'hat Torah, Vézot haBérakha (hebcal lit déjà Berèchit les jours de semaine d'après la fête).
      let attendu;
      if (jc.getJewishMonth() === 7 && jc.getJewishDayOfMonth() >= 10 && jc.getJewishDayOfMonth() <= (il ? 22 : 23)) attendu = ['Vezot Haberakhah'];
      for (let s = ajouteJours(iso, 1); !attendu; s = ajouteJours(s, 1)) {
        const r = getLeyningOnDate(hd(s), il);
        if (r?.type === 'weekday' || r?.type === 'shabbat') attendu = r.parsha;
      }
      const w = getLeyningForParsha(attendu).weekday;
      assert.equal(passages(l), `${Object.values(w).map((x) => `${x.k} ${x.b}-${x.e}`).join(', ')} | `, `${iso} ${il}`);
      assert.deepEqual(l.montees.map((m) => m.libelle.fr), ['Cohen', 'Lévi', 'Israël']);
      n++;
    }
  }
  assert.ok(n > 600, `${n}`);
});

test('les vecteurs partagés avec LectureTorahTest.kt sont la réponse actuelle (sinon : node web/tools/lecture-torah.mjs)', () => {
  const attendu = JSON.parse(readFileSync(VECTEURS, 'utf8'));
  const v = vecteurs(D, attendu.debut, attendu.fin);
  assert.equal(Object.keys(v.jours).length, Object.keys(attendu.jours).length);
  for (const [k, x] of Object.entries(attendu.jours)) assert.deepEqual(v.jours[k], x, k);
});

// --- Cas choisis -----------------------------------------------------------------------------------

const une = (iso, opts = {}, office = 'chaharit') => {
  const l = lectures(D, iso, office, { enIsrael: false, nusah: 'ashkenaz', ...opts });
  assert.equal(l.length, 1, `${iso} : ${l.length} lectures`);
  return l[0];
};
const maftir = (l) => l.montees.find((m) => m.cle === 'M');
const haft = (l) => l.haftara.map((h) => `${h.livre} ${h.debut}-${h.fin}`).join('; ');

test('les Chabbatot spéciaux : maftir et haftara, dans les trois rites', () => {
  const m = (l) => `${maftir(l).livre} ${maftir(l).debut}-${maftir(l).fin}`;
  const edot = (iso) => haft(une(iso, { nusah: 'edot' }));
  // 5786 : Chekalim, Zakhor, Para, haHodech, haGadol.
  let l = une('2026-02-14');
  assert.equal(l.cle, 'parasha:MISHPATIM+Shabbat Shekalim');
  assert.equal(m(l), 'Exodus 30:11-30:16');
  assert.equal(haft(l), 'II Kings 12:1-12:17');
  assert.equal(edot('2026-02-14'), 'II Kings 11:17-12:17');
  assert.equal(l.raisons[0].fr, 'Chabbat Chekalim');
  // Chekalim la veille d'un Roch 'Hodech dimanche (5788) : Edot, premier et dernier versets de « מחר חדש ».
  assert.equal(edot('2028-02-26'), 'II Kings 11:17-12:17; I Samuel 20:18-20:18; I Samuel 20:42-20:42');
  assert.equal(haft(une('2028-02-26')), 'II Kings 12:1-12:17');
  l = une('2026-02-28');
  assert.equal(l.cle, 'parasha:TETZAVEH+Shabbat Zachor');
  assert.equal(m(l), 'Deuteronomy 25:17-25:19');
  assert.equal(edot('2026-02-28'), 'I Samuel 15:1-15:34');
  assert.equal(une('2026-03-07').cle, 'parasha:KI_SISA+Shabbat Parah');
  assert.equal(m(une('2026-03-07')), 'Numbers 19:1-19:22');
  assert.equal(edot('2026-03-07'), 'Ezekiel 36:16-36:36');
  assert.equal(une('2026-03-14').cle, 'parasha:VAYAKHEL_PEKUDEI+Shabbat HaChodesh');
  assert.equal(edot('2026-03-14'), 'Ezekiel 45:18-46:15');
  assert.equal(haft(une('2026-03-28')), 'Malachi 3:4-3:24');
  assert.equal(edot('2026-03-28'), 'Malachi 3:4-3:24');
  // haHodech à Roch 'Hodech Nissan (5789) : trois Sifrei Torah ; Edot, versets de « השמים כסאי ».
  l = une('2029-03-17');
  assert.equal(l.cle, 'parasha:VAYIKRA+Shabbat HaChodesh (on Rosh Chodesh)');
  assert.deepEqual(l.montees.slice(-2).map((x) => `${x.cle}:${x.livre} ${x.debut}-${x.fin}`), ['7:Numbers 28:9-28:15', 'M:Exodus 12:1-12:20']);
  assert.equal(edot('2029-03-17'), 'Ezekiel 45:18-46:15; Isaiah 66:1-66:1; Isaiah 66:23-66:23');
  // Chabbat Chouva, avec Vayélekh (5786) et avec Haazinou (5787).
  assert.equal(haft(une('2025-09-27')), 'Hosea 14:2-14:10; Micah 7:18-7:20');
  l = une('2026-09-19');
  assert.equal(l.cle, "parasha:HAAZINU+Shabbat Shuva (with Ha'azinu)");
  assert.equal(haft(l), 'Hosea 14:2-14:10; Joel 2:15-2:27');
  assert.equal(edot('2026-09-19'), 'Hosea 14:2-14:10; Micah 7:18-7:20');
  // Chabbat Roch 'Hodech sur deux jours (Korah, 30 Sivan 5788) et Ma'har 'Hodech (Bamidbar 5786).
  l = une('2028-06-24');
  assert.equal(l.cle, 'parasha:KORACH+Shabbat Rosh Chodesh');
  assert.equal(m(l), 'Numbers 28:9-28:15');
  assert.equal(haft(l), 'Isaiah 66:1-66:24');
  assert.equal(edot('2028-06-24'), 'Isaiah 66:1-66:24; I Samuel 20:18-20:18; I Samuel 20:42-20:42');
  assert.equal(haft(une('2026-05-16')), 'I Samuel 20:18-20:42');
  // Ré'é à Roch 'Hodech Elloul et Ki tétsé (5789) : Ashkenaz « השמים כסאי » puis les deux haftarot ;
  // Edot « עניה סוערה » et les versets, puis la haftara de Ki tétsé seule.
  assert.equal(haft(une('2029-08-11')), 'Isaiah 66:1-66:24');
  assert.equal(edot('2029-08-11'), 'Isaiah 54:11-55:5; Isaiah 66:1-66:1; Isaiah 66:23-66:23');
  assert.equal(haft(une('2029-08-25')), 'Isaiah 54:1-54:10; Isaiah 54:11-55:5');
  assert.equal(edot('2029-08-25'), 'Isaiah 54:1-54:10');
  // Pin'has après le 17 Tamouz (5786).
  assert.equal(haft(une('2026-07-04')), 'Jeremiah 1:1-2:3');
});

test('Chabbat Roch \'Hodech Tévèt : trois Sifrei Torah, la septième à Roch \'Hodech, le maftir du sixième jour', () => {
  const l = une('2025-12-20');
  assert.equal(l.cle, 'parasha:MIKETZ+Shabbat Rosh Chodesh Chanukah');
  assert.deepEqual(l.montees.slice(-2).map((m) => `${m.cle}:${m.livre} ${m.debut}-${m.fin}`), ['7:Numbers 28:9-28:15', 'M:Numbers 7:42-7:47']);
  assert.equal(haft(l), 'Zechariah 2:14-4:7');
  assert.equal(haft(une('2025-12-20', { nusah: 'edot' })), 'Zechariah 2:14-4:7');
  // Ce Chabbat est toujours le sixième jour de 'Hanouka (de 2000 à 2400) : le maftir fixe d'hebcal suffit.
  for (let iso = '2000-01-01'; iso < '2400-01-01'; iso = ajouteJours(iso, 1)) {
    const jc = calendrier(iso, false, false, false);
    if (jc.getDayOfWeek() === 7 && jc.isChanukah() && jc.isRoshChodesh()) assert.equal(jc.getDayOfChanukah(), 6, iso);
  }
});

test('\'Hanouka, jours 1 à 8 (5787), Roch \'Hodech Tévèt compris, Ashkenaz et Edot', () => {
  const att = {
    '2026-12-05': ['parasha:VAYESHEV+Chanukah Day 1 (on Shabbat)', 'M:Numbers 7:1-7:17', 'M:Numbers 6:22-7:17'],
    '2026-12-06': ['Chanukah Day 2', '3:Numbers 7:24-7:29', '3:Numbers 7:18-7:23'],
    '2026-12-10': ['Chanukah Day 6', '4:Numbers 7:42-7:47', '4:Numbers 7:42-7:47'],
    '2026-12-11': ['Chanukah Day 7 (on Rosh Chodesh)', '4:Numbers 7:48-7:53', '4:Numbers 7:48-7:53'],
    '2026-12-12': ['parasha:MIKETZ+Chanukah Day 8 (on Shabbat)', 'M:Numbers 7:54-8:4', 'M:Numbers 7:54-8:4'],
  };
  for (const [iso, [cle, a, e]] of Object.entries(att)) {
    const la = une(iso), le = une(iso, { nusah: 'edot' });
    assert.equal(la.cle, cle, iso);
    const fin = (l) => { const m = l.montees.at(-1); return `${m.cle}:${m.livre} ${m.debut}-${m.fin}`; };
    assert.equal(fin(la), a, iso);
    assert.equal(fin(le), e, iso);
  }
  assert.equal(haft(une('2026-12-12')), 'I Kings 7:40-7:50');
  // Le premier jour en semaine (5786) : Edot depuis la bénédiction des cohanim.
  assert.deepEqual(une('2025-12-15', { nusah: 'edot' }).montees.map((m) => `${m.debut}-${m.fin}`), ['6:22-7:3', '7:4-7:11', '7:12-7:17']);
  assert.deepEqual(une('2025-12-15').montees.map((m) => `${m.debut}-${m.fin}`), ['7:1-7:11', '7:12-7:14', '7:15-7:17']);
});

test('9 Av, matin et Min\'ha (5786, jeudi 23/07/2026)', () => {
  const m = une('2026-07-23');
  assert.equal(m.cle, "Tish'a B'Av");
  assert.equal(passages(m), 'Deuteronomy 4:25-4:29, Deuteronomy 4:30-4:35, Deuteronomy 4:36-4:40 | Jeremiah 8:13-9:23');
  assert.equal(passages(une('2026-07-23', { nusah: 'edot' })), passages(m));
  assert.equal(haft(une('2026-07-23', {}, 'minha')), 'Isaiah 55:6-56:8');
  assert.equal(haft(une('2026-07-23', { nusah: 'edot' }, 'minha')), 'Hosea 14:2-14:10; Micah 7:18-7:20');
  assert.equal(une('2026-07-23', {}, 'minha').titre.fr, 'Ticha bèAv');
  // Le 10 Tévet (5787, dimanche 20/12/2026) : lecture le matin et à Min'ha ; Edot sans haftara à Min'ha.
  assert.equal(une('2026-12-20').titre.fr, 'Jeûne du 10 Tévet');
  assert.equal(haft(une('2026-12-20', {}, 'minha')), 'Isaiah 55:6-56:8');
  assert.equal(haft(une('2026-12-20', { nusah: 'edot' }, 'minha')), '');
});

test('Pourim : le 14 hors de Jérusalem, le 15 à Jérusalem ; le Pourim triple, le vendredi et le Chabbat', () => {
  // 5787 : Pourim mardi 23/03/2027, Chouchan Pourim mercredi.
  assert.equal(une('2027-03-23').cle, 'Purim');
  assert.equal(une('2027-03-23', { enIsrael: true }).cle, 'Purim');
  assert.deepEqual(lectures(D, '2027-03-23', 'chaharit', { enIsrael: true, mukafChoma: true }), []);
  assert.equal(une('2027-03-24', { enIsrael: true, mukafChoma: true }).cle, 'Shushan Purim');
  assert.deepEqual(lectures(D, '2027-03-24', 'chaharit', { enIsrael: true }), []);
  // Pourim triple : le 15 Adar un Chabbat (cherché), à Jérusalem maftir « ויבא עמלק » et haftara de Zakhor.
  let iso = '2025-09-01';
  for (; ; iso = ajouteJours(iso, 1)) {
    const jc = calendrier(iso, true, false, true);
    if (jc.getDayOfWeek() === 7 && jc.isPurim()) break;
  }
  const j = une(iso, { enIsrael: true, mukafChoma: true });
  assert.match(j.cle, /\+Shushan Purim \(on Shabbat\)$/);
  assert.equal(`${maftir(j).livre} ${maftir(j).debut}-${maftir(j).fin}`, 'Exodus 17:8-17:16');
  assert.equal(haft(j), 'I Samuel 15:2-15:34');
  assert.equal(haft(une(iso, { enIsrael: true, mukafChoma: true, nusah: 'edot' })), 'I Samuel 15:1-15:34');
  assert.doesNotMatch(une(iso, { enIsrael: true }).cle, /Purim/);
  // Le vendredi 14, Pourim partout ailleurs ; à Jérusalem, pas de lecture (Méguila seule).
  assert.equal(une(ajouteJours(iso, -1), { enIsrael: true }).cle, 'Purim');
  assert.deepEqual(lectures(D, ajouteJours(iso, -1), 'chaharit', { enIsrael: true, mukafChoma: true }), []);
});

test('Chemini Atsérèt et Sim\'hat Torah, Israël et diaspora (5787)', () => {
  // Diaspora : Chemini Atsérèt samedi 03/10/2026, Sim'hat Torah dimanche ; Israël : Sim'hat Torah le Chabbat.
  const dia = une('2026-10-03');
  assert.equal(dia.cle, 'Shmini Atzeret (on Shabbat)');
  assert.equal(dia.montees[0].debut, '14:22');
  const il = une('2026-10-03', { enIsrael: true });
  assert.equal(il.cle, 'Simchat Torah (on Shabbat)');
  assert.deepEqual(il.montees.slice(-3).map((m) => m.cle), ['hatan_torah', 'hatan_bereshit', 'M']);
  assert.equal(haft(il), 'Joshua 1:1-1:18');
  assert.equal(haft(une('2026-10-03', { enIsrael: true, nusah: 'edot' })), 'Joshua 1:1-1:9');
  assert.equal(une('2026-10-03', { enIsrael: true, nusah: 'edot' }).montees.filter((m) => /^\d$/.test(m.cle)).length, 7);
  assert.equal(une('2026-10-04').cle, 'Simchat Torah');
  assert.deepEqual(lectures(D, '2026-10-04', 'chaharit', { enIsrael: true, nusah: 'edot' }), []); // un dimanche ordinaire en Israël
  assert.equal(une('2026-10-05', { enIsrael: true }).cle, 'semaine:BERESHIS');
  // Chemini Atsérèt en semaine (5786, mardi 14/10/2025), Edot : « כל הבכור » (Choul'han Aroukh O.H. 668:2).
  assert.equal(une('2025-10-14', { nusah: 'edot' }).montees[0].debut, '15:19');
  assert.equal(une('2025-10-14').montees[0].debut, '14:22');
});

test('semaines où Israël et la diaspora lisent des parachiot différentes', () => {
  // Chavouot II un samedi en diaspora (23/05/2026) : Israël lit Nasso, la diaspora le Chabbat suivant.
  assert.equal(une('2026-05-23').cle, 'Shavuot II (on Shabbat)');
  assert.match(une('2026-05-23', { enIsrael: true }).cle, /^parasha:NASSO/);
  assert.equal(une('2026-05-25').cle, 'semaine:NASSO');
  assert.equal(une('2026-05-25', { enIsrael: true }).cle, 'semaine:BEHAALOSCHA');
  assert.equal(une('2026-05-23', {}, 'minha').cle, 'semaine:NASSO');
  assert.equal(une('2026-05-23', { enIsrael: true }, 'minha').cle, 'semaine:BEHAALOSCHA');
  assert.match(une('2026-06-20').cle, /^parasha:KORACH/);
  assert.match(une('2026-06-20', { enIsrael: true }).cle, /^parasha:CHUKAS/);
  // Pessa'h VIII un samedi en diaspora (07/04/2029).
  assert.equal(une('2029-04-07').cle, 'Pesach VIII (on Shabbat)');
  assert.match(une('2029-04-07', { enIsrael: true }).cle, /^parasha:SHMINI/);
  // Pessa'h un jeudi en Israël : קדש dimanche, בכספא lundi, במדברא mardi.
  assert.deepEqual(['2026-04-05', '2026-04-06', '2026-04-07'].map((d) => une(d, { enIsrael: true }).montees[0].debut), ['13:1', '22:24', '9:1']);
});

test('les jours de lecture, ni plus ni moins', () => {
  // Un mardi ordinaire : rien ; Roch 'Hodech un mardi : quatre montées ; Chabbat à Min'ha : trois.
  assert.deepEqual(lectures(D, '2026-11-24', 'chaharit', { nusah: 'edot' }), []);
  assert.equal(une('2026-11-10').cle, 'Rosh Chodesh');
  assert.equal(une('2026-11-10').montees.length, 4);
  assert.equal(une('2026-11-26').cle, 'semaine:VAYISHLACH'); // aujourd'hui, jeudi 26/11/2026
  assert.equal(une('2026-11-26').titre.fr, 'Vayichla’h');
  assert.equal(parachaApres('2026-10-10', false), 'NOACH');
  assert.deepEqual(lectures(D, '2026-11-26', 'minha', { nusah: 'edot' }), []);
});

// --- Le texte ----------------------------------------------------------------------------------------

test('chaque passage lu de 5786 à 5791 a son texte, vocalisé, avec ses teamim', () => {
  const vus = new Set();
  for (const iso of jours()) {
    for (const il of [false, true]) {
      for (const nusah of ['edot', 'ashkenaz']) {
        for (const office of ['chaharit', 'minha']) {
          for (const l of nous(iso, il, nusah, office)) {
            for (const p of [...l.montees, ...l.haftara]) {
              const k = `${p.livre} ${p.debut}-${p.fin}`;
              if (vus.has(k)) continue;
              vus.add(k);
              const v = versets(p.livre, p.debut, p.fin, LIVRES[p.livre.replace(/ /g, '_')]);
              assert.ok(v.length > 0, k);
              for (const x of v) {
                assert.ok(x.t && /[֑-֯]/.test(x.t) && /[ְ-ּ]/.test(x.t), `${k} ${x.c}:${x.v}`);
                assert.ok(!/[[\]()<>{}]/.test(x.t), `${k} ${x.c}:${x.v}`);
              }
            }
          }
        }
      }
    }
  }
  assert.ok(vus.size > 500, `${vus.size}`);
  // Le qere : Berèchit 8:17 « הַיְצֵ֣א » (ketiv הוצא) ; Bamidbar 25:19 suit la numérotation d'hebcal.
  assert.ok(versets('Genesis', '8:17', '8:17', LIVRES.Genesis)[0].t.includes('הַיְצֵ֣א'));
  assert.equal(versets('Numbers', '25:19', '25:19', LIVRES.Numbers)[0].t, 'וַיְהִ֖י אַחֲרֵ֣י הַמַּגֵּפָ֑ה');
  assert.equal(versets('Genesis', '2:3', '2:3', LIVRES.Genesis)[0].fin, 'פ');
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
  assert.ok(resume(l).startsWith('semaine:VAYISHLACH|'));
});
