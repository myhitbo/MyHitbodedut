// La fiche Play (audit du 12/11, TPLAYDOCS-03) : play/fiche/<langue>, au format de fastlane supply.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const lire = (langue, nom) => readFileSync(new URL(`../../play/fiche/${langue}/${nom}`, import.meta.url), 'utf8').replace(/\n$/, '');

test('la fiche Play tient dans les limites de Google, en anglais et en hébreu', () => {
  for (const langue of ['en-US', 'iw-IL']) {
    assert.ok([...lire(langue, 'title.txt')].length <= 30, `${langue} titre`);
    assert.ok([...lire(langue, 'short_description.txt')].length <= 80, `${langue} courte`);
    const longue = lire(langue, 'full_description.txt');
    assert.ok([...longue].length <= 4000, `${langue} complète`);
    // Les graphies latines pour la recherche, et la mention de la traduction automatique.
    assert.ok(/hitbodedut/.test(longue) && /hisbodedus/.test(longue), langue);
    assert.ok(/machine|במכונה/.test(longue), langue);
    // Ni le Nom écrit en toutes lettres, ni de classement (« n° 1 », « best »).
    assert.ok(!/יהוה|best|#1|№/i.test(longue), langue);
  }
  assert.ok(lire('en-US', 'short_description.txt').includes('התבודדות'));
});

test('l’image de présentation fait 1024 × 500, sans alpha', () => {
  for (const langue of ['en-US', 'iw-IL']) {
    const png = readFileSync(new URL(`../../play/fiche/${langue}/images/featureGraphic.png`, import.meta.url));
    assert.equal(png.readUInt32BE(16), 1024);
    assert.equal(png.readUInt32BE(20), 500);
    // Type de couleur 2 : RGB, sans canal alpha.
    assert.equal(png[25], 2, langue);
  }
});
