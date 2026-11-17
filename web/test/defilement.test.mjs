// Le défilement automatique des textes (16/11) : la règle commune à Android, Nokia, iOS et au site.
import assert from 'node:assert/strict';
import test from 'node:test';
import { NIVEAU_DEFAUT, borneNiveau, pas, vitesse } from '../src/js/defilement.js';
import { creeStore, memoire } from '../src/js/store.js';

test('les dix vitesses : 6 × 1,4^(n−1) px/s', () => {
  const attendu = [6, 8.4, 11.76, 16.46, 23.05, 32.27, 45.18, 63.25, 88.55, 123.97];
  for (let n = 1; n <= 10; n++) assert.ok(Math.abs(vitesse(n) - attendu[n - 1]) < 0.01, `niveau ${n} : ${vitesse(n)}`);
  // Hors bornes : ramené à 1 ou 10.
  assert.equal(vitesse(0), vitesse(1));
  assert.equal(vitesse(42), vitesse(10));
  assert.equal(vitesse('x'), vitesse(NIVEAU_DEFAUT));
});

test('la vitesse suit la taille du texte : autant de lignes par minute', () => {
  assert.ok(Math.abs(vitesse(3, 1.5) - vitesse(3) * 1.5) < 1e-9);
  assert.ok(Math.abs(vitesse(5, 0.8) - vitesse(5) * 0.8) < 1e-9);
  assert.equal(vitesse(3, 0), vitesse(3));
});

test('le niveau est entier, entre 1 et 10', () => {
  assert.equal(NIVEAU_DEFAUT, 3);
  assert.equal(borneNiveau(0), 1);
  assert.equal(borneNiveau(11), 10);
  assert.equal(borneNiveau(4.4), 4);
  assert.equal(borneNiveau(undefined), 3);
});

test('les fractions de pixel s’accumulent, les longs écarts sont bornés', () => {
  // 6 px/s à 60 images/s : 0,1 px par image, un pixel toutes les dix images.
  let r = 0;
  let total = 0;
  for (let i = 0; i < 600; i++) { const p = pas(r, 1000 / 60, 6); r = p.reste; total += p.pixels; }
  assert.ok(total >= 59 && total <= 60, String(total));
  assert.ok(r >= 0 && r < 1);
  // Retour de veille : 10 s d'écart ne valent que 100 ms.
  assert.equal(pas(0, 10000, 100).pixels, 10);
  assert.equal(pas(0.5, -5, 100).pixels, 0);
});

test('le niveau est gardé dans le store, borné, 3 par défaut', () => {
  const store = creeStore(memoire());
  assert.equal(store.lectureDefilementVitesse(), 3);
  store.setLectureDefilementVitesse(7);
  assert.equal(store.lectureDefilementVitesse(), 7);
  store.setLectureDefilementVitesse(15);
  assert.equal(store.lectureDefilementVitesse(), 10);
  store.setLectureDefilementVitesse(-2);
  assert.equal(store.lectureDefilementVitesse(), 1);
});
