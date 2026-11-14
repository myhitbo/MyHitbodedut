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

// Les légendes des visuels (audit du 12/11, TPLAYDOCS-04 à 08, TEN-01, THE-03) : play/visuels/legendes.json,
// que lit l'outil de composition. Huit visuels par langue, dans le même ordre, courts, sans le Nom en toutes lettres.
test('les légendes des visuels : huit par langue, dans l’ordre, dans les limites', () => {
  const { langues } = JSON.parse(readFileSync(new URL('../../play/visuels/legendes.json', import.meta.url), 'utf8'));
  const cles = ['accueil', 'seance', 'barriere', 'siddour', 'zmanim', 'textes', 'boussole', 'journal'];
  assert.deepEqual(Object.keys(langues), ['en', 'he']);
  assert.equal(langues.en.dossier, 'en-US');
  assert.equal(langues.he.dossier, 'iw-IL');
  for (const [langue, { visuels }] of Object.entries(langues)) {
    assert.deepEqual(visuels.map((v) => v.cle), cles, langue);
    for (const v of visuels) {
      assert.deepEqual(Object.keys(v), ['cle', 'titre', 'phrase'], `${langue} ${v.cle}`);
      assert.ok(v.titre && [...v.titre].length <= 30, `${langue} ${v.cle} titre`);
      assert.ok(v.phrase && [...v.phrase].length <= 90, `${langue} ${v.cle} phrase`);
      // Ni classement, ni suivi en direct : la version Play ne l'a pas.
      assert.ok(!/יהוה|\bbest\b|#1|№|\blive\b|OpenSky/i.test(v.titre + ' ' + v.phrase), `${langue} ${v.cle}`);
    }
    // L'hébreu est en hébreu, l'anglais en lettres latines.
    assert.equal(visuels.every((v) => /[\u05D0-\u05EA]/.test(v.titre)), langue === 'he', langue);
  }
});
