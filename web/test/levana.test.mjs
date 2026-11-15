import { test } from 'node:test';
import assert from 'node:assert/strict';
import { levana, phaseLune, usageLevana } from '../src/js/calendrier-juif.js';

// 'Hechvan 5787 : du 18 au 25 octobre 2026 au soir, comme CalJ (LevanaTest.kt).
test('Birkat haLevana, Hechvan 5787', () => {
  const l = levana('2026-10-14', 'Asia/Jerusalem');
  assert.equal(l.premier, '2026-10-18');
  assert.equal(l.dernier, '2026-10-25');
  assert.deepEqual(l.etat, { dans: 4 });
  assert.ok(l.debut < l.point === false && l.debut < l.fin);
  assert.equal(levana('2026-10-18', 'Asia/Jerusalem').etat, 'ce_soir');
  assert.equal(levana('2026-10-25', 'Asia/Jerusalem').etat, 'dernier');
  assert.ok(levana('2026-10-26', 'Asia/Jerusalem').premier > '2026-11-01');
});

// Audit du 12/11, FCALENDRIER-03 : quand la fenêtre se ferme l'après-midi, le dernier soir est la veille (LevanaTest.kt).
test('Birkat haLevana, Kislev 5787 : la mi-mois tombe l’après-midi du 24/11 à Paris, dernier soir le 23', () => {
  const paris = 'Europe/Paris';
  for (const usage of ['trois_mi_mois', 'sept_mi_mois']) {
    const l = levana('2026-11-20', paris, { usage });
    assert.equal(l.dernier, '2026-11-23');
    assert.equal(levana('2026-11-23', paris, { usage }).etat, 'dernier');
    assert.equal(levana('2026-11-22', paris, { usage }).etat, 'ce_soir');
    assert.ok(l.finMs < Date.parse('2026-11-24T20:00:00+01:00'));
    assert.equal(typeof levana('2026-11-24', paris, { usage }).etat, 'object', 'le 24, la fenêtre suivante');
  }
  assert.equal(levana('2026-11-20', paris, { usage: 'sept_quinze' }).dernier, '2026-11-24');
  assert.equal(levana('2026-11-20', 'America/New_York', { usage: 'sept_quinze' }).dernier, '2026-11-23');
});

// Revue du 14/10 sur le texte (Choulhan Aroukh O.H. 426 ; Michna Beroura 426), mêmes valeurs que LevanaTest.kt.
test('Birkat haLevana : usages, motsaé Chabbat, Kippour, Tich\'a beAv', () => {
  const z = 'Asia/Jerusalem';
  const trois = levana('2026-10-14', z, { usage: 'trois_mi_mois' });
  assert.equal(trois.premier, '2026-10-14');
  assert.equal(trois.dernier, '2026-10-25');
  assert.equal(trois.motsae, '2026-10-17');
  const quinze = levana('2026-10-14', z, { usage: 'sept_quinze' });
  assert.equal(quinze.premier, '2026-10-18');
  assert.ok(quinze.finMs > trois.finMs);
  assert.equal(levana('2026-10-14', z, { usage: 'sept_mi_mois' }).motsae, null);
  const tichri = levana('2026-09-15', z, { usage: 'trois_mi_mois' });
  assert.equal(tichri.premier, '2026-09-21');
  assert.equal(tichri.restriction, 'kippour');
  const av = levana('2026-07-20', z, { usage: 'trois_mi_mois' });
  assert.equal(av.premier, '2026-07-23');
  assert.equal(av.restriction, 'tisha_beav');
  assert.equal(usageLevana('edot'), 'sept_quinze');
  assert.equal(usageLevana('sefard'), 'sept_mi_mois');
  assert.equal(usageLevana('ashkenaz'), 'trois_mi_mois');
  assert.equal(usageLevana('edot', 'trois_mi_mois'), 'trois_mi_mois');
});

test('la lune : nouvelle, premier quartier, pleine', () => {
  assert.ok(phaseLune(Date.parse('2026-10-10T12:00:00Z')).eclairage < 0.01);
  const q = phaseLune(Date.parse('2026-10-18T12:00:00Z'));
  assert.ok(q.eclairage > 0.4 && q.eclairage < 0.6 && q.croissante);
  assert.ok(phaseLune(Date.parse('2026-10-26T12:00:00Z')).eclairage > 0.99);
});
