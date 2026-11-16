// Le ciel du Jour (CielDuJourTest.kt, 14/11) : les mêmes cas, et les mêmes couleurs qu'Android.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as Ciel from '../src/js/ciel.js';

const ICI = dirname(fileURLToPath(import.meta.url));
const ANDROID = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'java', 'com', 'myhitbodedut');

// Un jour de novembre à Jérusalem (UTC+2), en chiffres ronds.
const a = (h, m) => new Date(Date.UTC(2026, 10, 12, h - 2, m));
const z = { alot: a(5, 0), netz: a(6, 20), chkia: a(16, 40), tset: a(17, 5) };
const phase = (h, m) => Ciel.phase(a(h, m), z);

test('les zmanim bornent les quatre ciels', () => {
  assert.equal(phase(4, 59), 'nuit');
  assert.equal(phase(5, 0), 'aube');
  assert.equal(phase(7, 19), 'aube');
  assert.equal(phase(7, 20), 'jour');
  assert.equal(phase(15, 39), 'jour');
  assert.equal(phase(15, 40), 'coucher');
  assert.equal(phase(17, 4), 'coucher');
  assert.equal(phase(17, 5), 'nuit');
  assert.equal(phase(23, 59), 'nuit');
});

test('un jour trop court passe de l’aube au coucher', () => {
  const court = { alot: a(8, 0), netz: a(9, 0), chkia: a(10, 30), tset: a(11, 30) };
  assert.equal(Ciel.phase(a(9, 59), court), 'aube');
  assert.equal(Ciel.phase(a(10, 0), court), 'coucher');
  assert.equal(Ciel.phase(a(11, 30), court), 'nuit');
});

test('sans zman, l’heure du lieu décide', () => {
  assert.equal(Ciel.phase(a(12, 0), { ...z, alot: null }, { heures: 12, minutes: 0 }), 'jour');
  assert.equal(Ciel.phase(a(22, 0), { ...z, tset: null }, { heures: 22, minutes: 0 }), 'nuit');
  for (const [h, m, attendu] of [[4, 59, 'nuit'], [5, 0, 'aube'], [7, 59, 'aube'], [8, 0, 'jour'], [16, 59, 'jour'],
    [17, 0, 'coucher'], [19, 59, 'coucher'], [20, 0, 'nuit']]) {
    assert.equal(Ciel.parHeure(h, m), attendu, `${h}:${m}`);
  }
});

test('les couleurs du ciel sont celles d’Android', () => {
  const kt = readFileSync(join(ANDROID, 'CielDuJour.kt'), 'utf8');
  const champs = ['haut', 'milieu', 'horizon', 'colline', 'astre', 'lueur', 'voile'];
  for (const p of Ciel.PHASES) {
    const debut = kt.indexOf(`Phase.${p.toUpperCase()} to Palette(`);
    assert.ok(debut >= 0, `${p} absent de CielDuJour.kt`);
    // Le bloc de cette palette : jusqu'à la suivante, ou à la fin de la table.
    const bloc = kt.slice(debut).split(/\n\s*Phase\.|\n\s*\)/)[0];
    const android = [...bloc.matchAll(/0xFF([0-9A-F]{6})/g)].map((x) => `#${x[1]}`);
    assert.deepEqual(champs.map((c) => Ciel.PALETTES[p][c]), android, p);
  }
  const dessin = readFileSync(join(ANDROID, 'CielDessin.kt'), 'utf8');
  for (const [p, [x, y, r, l]] of Object.entries(Ciel.ASTRES)) {
    assert.ok(dessin.includes(`Phase.${p.toUpperCase()} to Astre(${x}f, ${y}f, ${r}f, ${l}f)`), `astre ${p}`);
  }
});
