import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const app = readFileSync(new URL('../src/js/app.js', import.meta.url), 'utf8');
const res = (d) => readFileSync(new URL(`../../android/app/src/main/res/${d}/strings.xml`, import.meta.url), 'utf8');

// FPRODUIT-04 : le bouton principal de l'accueil démarre d'un toucher, comme sur Android.
test('le bouton principal de l\'accueil demarre la seance sans second toucher', () => {
  // Depuis la refonte du 13/11, le bouton principal est celui de la barre de départ (barreDepart).
  const bloc = app.slice(app.indexOf('function barreDepart()'), app.indexOf('function voletDepart()'));
  assert.match(bloc, /isSessionRunning\(\) \? ouvrir\('seance'\) : commencer\(store\.targetMinutes\(\)\)/);
  assert.ok(app.includes("tr.t('start_prepare')"));
});

test('l\'ecran de preparation reste atteignable, en trois langues', () => {
  for (const d of ['values', 'values-en', 'values-iw']) {
    assert.match(res(d), /name="start_prepare"/, d);
  }
  assert.match(res('values'), /name="chizuk_commencer">Préparer une hitbodedout</);
});
