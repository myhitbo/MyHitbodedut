import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { anneeDuLivre, choix, part, pour, recherche, sections } from '../src/js/halakha.js';

const livre = JSON.parse(readFileSync(new URL('../../android/app/src/main/res/raw/ben_ish_hai.json', import.meta.url)));

test('chaque jour de trois années a sa halakha ; la semaine couvre la section (Halakha.kt)', () => {
  for (let t = Date.UTC(2025, 8, 1); t < Date.UTC(2028, 8, 1); t += 86400000) {
    const iso = new Date(t).toISOString().slice(0, 10);
    for (const il of [false, true]) assert.ok(pour(livre, iso, il).length, `${iso} ${il}`);
  }
  const semaine = [18, 19, 20, 21, 22, 23, 24].flatMap((d) => pour(livre, `2026-10-${d}`, false));
  assert.deepEqual(semaine.map((x) => x.numero), Array.from({ length: 21 }, (_, i) => i + 1));
  assert.ok(semaine.every((x) => x.annee === 1 && x.section === 'לך לך'));
});

test('jointes, séparées, Hanouka, part du jour', () => {
  const t = sections(livre.annees['1'], 'TAZRIA')[0];
  const m = sections(livre.annees['1'], 'METZORA')[0];
  assert.equal(m.depart, t.h.length);
  assert.equal(sections(livre.annees['2'], 'TAZRIA_METZORA').length, 2);
  assert.equal(choix(livre, 'VAYESHEV', 0, 5787, 1)[0].section, 'הלכות חנוכה');
  assert.equal(anneeDuLivre(5787), 1);
  assert.deepEqual(part([1, 2, 3], 3, 7), [1]);
  assert.ok(recherche(livre, 'ציצית').length > 10);
});

test('Vayéchev année 2 sans la note vide ; Hochaana Rabba : Vézot haBéra\'kha', () => {
  for (let j = 19; j <= 24; j++) {
    const h = pour(livre, `2027-12-${j}`, false);
    assert.ok(h.length && h.every((x) => !x.texte.startsWith('בפרשה זו לא כתבתי')), `2027-12-${j}`);
  }
  assert.equal(pour(livre, '2026-10-02', false)[0].section, 'וזאת הברכה');
  // Du 15 au 23 Tichri : ses 18 halakhot, chacune une fois, dans l'ordre.
  const soukkot = [26, 27, 28, 29, 30].map((j) => `2026-09-${j}`).concat([1, 2, 3, 4].map((j) => `2026-10-0${j}`))
    .flatMap((iso) => pour(livre, iso, false));
  assert.deepEqual(soukkot.map((x) => x.numero), Array.from({ length: 18 }, (_, i) => i + 1));
  assert.ok(soukkot.every((x) => x.section === 'וזאת הברכה' && x.annee === 1));
});
