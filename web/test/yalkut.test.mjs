import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { du, fenetre, longueur, periode, pour, recherche, source, texteCarte, titreCarte, PAR_JOUR } from '../src/js/yalkut.js';

const livre = JSON.parse(readFileSync(new URL('../../android/app/src/main/res/raw/yalkut_yosef.json', import.meta.url)));
const PERIODES = ['ordinaire', 'chabbat', 'roch_hodech', 'pessah', 'omer', 'chavouot', 'bein_hametsarim', 'eloul', 'kippour', 'soukkot', 'hanouka', 'tou_bichvat', 'pourim'];

test('une sélection de halakhot courtes, jamais le livre entier (YalkutYosef.kt)', () => {
  assert.deepEqual(Object.keys(livre.periodes).sort(), [...PERIODES].sort());
  const pages = new Set(Object.values(livre.periodes).flat().map((x) => x.p));
  assert.ok(pages.size * 5 < 1048, `${pages.size} pages`);
  for (const p of PERIODES) {
    assert.ok(livre.periodes[p].length >= 4, p);
    for (const x of livre.periodes[p]) {
      assert.ok(x.t.length > 0 && x.t.length <= 420, `${p} ${x.s} ${x.l}`);
      assert.ok(x.s.length > 0, `${p} p.${x.p} sans siman`);
    }
  }
});

test('chaque jour de trois années a ses deux halakhot, et elles changent', () => {
  let avant = null;
  for (let t = Date.UTC(2025, 8, 1); t < Date.UTC(2028, 8, 1); t += 86400000) {
    const iso = new Date(t).toISOString().slice(0, 10);
    for (const il of [false, true]) assert.equal(pour(livre, iso, il).length, PAR_JOUR, `${iso} ${il}`);
    const ici = pour(livre, iso, false).map(source).join('|');
    assert.notEqual(ici, avant, iso);
    avant = ici;
  }
});

test('les fenêtres de fête', () => {
  assert.equal(fenetre(12, 14, false), 'pourim');
  assert.equal(fenetre(13, 14, true), 'pourim');
  assert.equal(fenetre(12, 14, true), null); // Adar I d'une année embolismique
  assert.equal(fenetre(12, 20, false), 'pessah');
  assert.equal(fenetre(1, 15, false), 'pessah');
  assert.equal(fenetre(1, 23, false), 'omer');
  assert.equal(fenetre(2, 29, false), 'omer');
  assert.equal(fenetre(3, 6, false), 'chavouot');
  assert.equal(fenetre(4, 17, false), 'bein_hametsarim');
  assert.equal(fenetre(5, 9, false), 'bein_hametsarim');
  assert.equal(fenetre(6, 1, false), 'eloul');
  assert.equal(fenetre(7, 1, false), 'eloul');
  assert.equal(fenetre(7, 10, false), 'kippour');
  assert.equal(fenetre(7, 15, false), 'soukkot');
  assert.equal(fenetre(9, 25, false), 'hanouka');
  assert.equal(fenetre(10, 2, false), 'hanouka');
  assert.equal(fenetre(11, 15, false), 'tou_bichvat');
  assert.equal(fenetre(8, 10, false), null);
  // Le premier jour d'une fenêtre a le rang 0 ; Roch 'Hodech passe avant tout.
  assert.deepEqual(periode('2027-03-25', false), ['pessah', 0]); // 16 Adar II 5787 (embolismique)
  assert.equal(periode('2027-03-24', false)[0], 'pourim'); // 15 Adar II
  assert.equal(periode('2026-10-12', false)[0], 'roch_hodech'); // 1er 'Hechvan 5787
  assert.equal(periode('2026-10-23', false)[0], 'chabbat'); // vendredi 12 'Hechvan
  assert.equal(periode('2026-10-21', false)[0], 'ordinaire');
  // Audit du 16/11 : le jeûne repoussé au dimanche 10 Av n'est pas un jour ordinaire (Kitsour YY 554:13).
  assert.equal(periode('2029-07-22', false)[0], 'bein_hametsarim');
  assert.equal(periode('2015-07-26', true)[0], 'bein_hametsarim');
  assert.equal(periode('2026-07-24', false)[0], 'chabbat'); // vendredi 10 Av 5786 : le jeûne était la veille
  assert.deepEqual(du([1, 2, 3], 2), [2, 3]);
  assert.ok(recherche(livre, 'ציצית').length > 0);
});

test('une seule carte pour les halakhot du jour', () => {
  const a = { s: 'סימן א', l: 'ב', t: 'x' }, b = { s: 'סימן א', l: 'ג', t: 'y' }, c = { s: 'סימן ב', l: 'א', t: 'z' };
  assert.equal(titreCarte([a, b]), 'ילקוט יוסף · סימן א');
  assert.equal(texteCarte([a, b]), 'ב. x\n\nג. y');
  assert.equal(titreCarte([b, c]), 'ילקוט יוסף');
  assert.equal(texteCarte([b, c]), 'סימן א\nג. y\n\nסימן ב\nא. z');
});

test('une fenêtre est répartie sur toute sa liste, les lois de la fête à la fin (THILLOULOT-02)', () => {
  const siman = (iso) => pour(livre, iso, false).map((x) => x.s);
  // Soukkot 5787 : 15 Tichri (26/09/2026), la soukka ; Hochaana Rabba (02/10), le loulav.
  assert.equal(longueur('2026-10-02', false), 13);
  assert.ok(siman('2026-09-26').every((s) => s.includes('תרכט')));
  assert.ok(siman('2026-10-02').every((s) => s.includes('תרנא')));
  // 6 Sivan 5787 (11/06/2027) : Chavouot, plus la sefirat haomer.
  assert.ok(siman('2027-06-11').every((s) => s.includes('תצד')));
  // 22 Nissan 5787 (29/04/2027) : les quatre coupes, plus la bedikat 'hamets.
  assert.ok(siman('2027-04-29').every((s) => s.includes('תעב')));
  assert.ok(siman('2027-03-25').every((s) => s.includes('תלג')));
});
