// Audit du 16/11, « Ta'hanoun et ce qui en dépend » : les mêmes cas que SiddurJourTest (Kotlin).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { ajouts } from '../src/js/jour-affiche.js';
import { avecSansTahanoun, conditionsPour, vrai } from '../src/js/siddur-jour.js';

const annotations = JSON.parse(readFileSync(new URL('../../android/app/src/main/res/raw/siddur_annotations.json', import.meta.url), 'utf8'));
const conditions = (nusah, iso, israel = false) => conditionsPour(nusah, israel, jour(iso, israel).conditions);

/** « replie » (groupe hors du jour), « hors » (variante estompée dans un groupe du jour) ou « du_jour ». */
function etat(nusah, texte, s, b, iso, israel = false) {
  const a = annotations[nusah][texte].find((e) => e.sorte === 'bloc' && e.s === s && e.b === b);
  assert.ok(a, `${nusah}/${texte} ${s}.${b}`);
  const c = conditions(nusah, iso, israel);
  if (!vrai(a.racine, c)) return 'replie';
  return vrai(a.si, c) ? 'du_jour' : 'hors';
}

test('אל ארך אפים suit למנצח : dit le lundi de Tou biChvat, pas à Roch \'Hodech (MB 131:35)', () => {
  for (const [nusah, s] of [['sefard', 12], ['ashkenaz', 5]]) {
    assert.equal(etat(nusah, 'chaharit', s, 1, '2026-02-02'), 'du_jour', nusah); // lundi 15 Chvat
    assert.equal(etat(nusah, 'chaharit', s, 1, '2025-11-17'), 'du_jour', nusah); // lundi ordinaire
    assert.equal(etat(nusah, 'chaharit', s, 1, '2026-08-13'), 'hors', nusah); // jeudi 30 Av, Roch 'Hodech
    // Un jeûne qui n'est ni lundi ni jeudi : pas d'אל ארך אפים (ShA haRav 429:12).
    assert.equal(etat(nusah, 'chaharit', s, 1, '2025-12-30'), 'hors', nusah); // mardi 10 Tévèt
  }
  // Edot : lié au Ta'hanoun (Yalkout Yossef), inchangé.
  assert.equal(etat('edot', 'chaharit', 11, 1, '2026-02-02'), 'hors');
});

test('Ashkenaz : Vidouï et ה׳ אלהי ישראל seulement le lundi et le jeudi (MB 134:1)', () => {
  for (const b of [2, 7, 73, 83]) {
    assert.equal(etat('ashkenaz', 'chaharit', 4, b, '2025-11-17'), 'du_jour', `${b} lundi`);
    assert.equal(etat('ashkenaz', 'chaharit', 4, b, '2025-11-18'), 'replie', `${b} mardi`);
  }
  // Le Ps 6 et שומר ישראל : tous les jours de Ta'hanoun.
  for (const b of [72, 84, 88]) assert.equal(etat('ashkenaz', 'chaharit', 4, b, '2025-11-18'), 'du_jour', `${b} mardi`);
});

test('Tsom Guedalia : Avinou malkénou sans les lignes des jeûnes (Matté Efraïm 602:13)', () => {
  const lignes = (nusah, texte, iso) => annotations[nusah][texte].filter((e) => e.si === 'avinou_malkenou_jeune')
    .map((e) => etat(nusah, texte, e.s, e.b, iso));
  for (const nusah of ['sefard', 'ashkenaz']) {
    for (const texte of ['chaharit', 'minha']) {
      const guedalia = lignes(nusah, texte, '2025-09-25');
      assert.ok(guedalia.length > 0 && guedalia.every((x) => x === 'hors'), `${nusah} ${texte}`);
      assert.ok(lignes(nusah, texte, '2025-12-30').every((x) => x === 'du_jour'), `${nusah} ${texte} 10 Tévèt`);
    }
  }
  assert.equal(etat('ashkenaz', 'chaharit', 4, 13, '2025-09-25'), 'du_jour'); // חדש עלינו
});

test('Edot : pas de Vidouï à Min\'ha la veille de Pessa\'h chéni (Kitsour Yalkout Yossef 131:38)', () => {
  assert.ok(!conditions('edot', '2026-04-30').has('tahanoun_minha'));
  assert.ok(conditions('sefard', '2026-04-30').has('tahanoun_minha'));
  assert.ok(conditions('edot', '2026-04-29').has('tahanoun_minha'));
});

test('Edot, Avinou malkénou le Chabbat : les lignes de faute estompées (Kitsour Yalkout Yossef 602:24)', () => {
  for (const [texte, s, faute, autre] of [['chaharit', 9, 73, 74], ['minha', 1, 72, 73]]) {
    assert.equal(etat('edot', texte, s, faute, '2025-09-27'), 'hors', texte); // Chabbat Chouva
    assert.equal(etat('edot', texte, s, autre, '2025-09-27'), 'du_jour', texte);
    assert.equal(etat('edot', texte, s, faute, '2025-09-29'), 'du_jour', texte);
  }
});

test('Kaddich complet après le Hallel à Roch \'Hodech Tévèt et le Chabbat de \'Hanouka (Kitsour Yalkout Yossef 423:1)', () => {
  for (const nusah of ['edot', 'sefard']) {
    const a = annotations[nusah].hallel.filter((e) => e.si === 'kaddich_complet_hallel');
    assert.ok(a.length >= 3, nusah);
    const dit = (iso) => a.every((e) => vrai(e.racine, conditions(nusah, iso)));
    assert.ok(dit('2025-12-21') && dit('2025-12-20'), nusah); // Roch 'Hodech Tévèt ; Chabbat 'Hanouka
    assert.ok(!dit('2025-12-16'), nusah); // 'Hanouka, mardi
    assert.ok(dit('2026-10-11'), nusah); // Roch 'Hodech 'Hechvan
  }
});

test('« Pas de Ta\'hanoun aujourd\'hui » : le réglage ponctuel retire le Ta\'hanoun, pas למנצח', () => {
  const c0 = jour('2025-11-17', false).conditions;
  for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
    const c = conditionsPour(nusah, false, avecSansTahanoun(c0, true));
    for (const k of ['tahanoun_chaharit', 'tahanoun_minha', 'lundi_jeudi']) assert.ok(!c.has(k), `${nusah} ${k}`);
    assert.ok(c.has('lamnatseah'), nusah);
    assert.ok(conditionsPour(nusah, false, avecSansTahanoun(c0, false)).has('tahanoun_chaharit'), nusah);
    assert.ok(ajouts(avecSansTahanoun(c0, true), nusah).includes('ajout_sans_tahanoun_ponctuel'), nusah);
  }
});

test('Pessa\'h chéni (Ashkenaz) : l\'absence de Ta\'hanoun dite comme un usage', () => {
  assert.ok(ajouts(jour('2026-05-01', false).conditions, 'ashkenaz').includes('ajout_sans_tahanoun_pessah_cheni'));
  assert.ok(ajouts(jour('2026-05-01', false).conditions, 'sefard').includes('ajout_sans_tahanoun'));
});

test('Veille de Kippour : Vidouï et על חטא à Min\'ha signalés (Choul\'han Aroukh O.H. 607:1)', () => {
  assert.ok(ajouts(jour('2025-10-01', false).conditions, 'ashkenaz').includes('ajout_vidoui_erev_kippour'));
  assert.ok(!ajouts(jour('2025-10-02', false).conditions, 'ashkenaz').includes('ajout_vidoui_erev_kippour'));
});
