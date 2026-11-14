// Les avis de l'accueil sur la garde des données (13/11, audit du 12/11, FWEBCODE-01) :
// installer sur l'iPhone, importer après l'installation, exporter de temps en temps ;
// et les échecs du stockage, qui ne restent plus muets.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { REPORT_JOURS, avisAccueil, joursEntre } from '../src/js/avis.js';
import { creeStore, memoire } from '../src/js/store.js';

const J = '2026-11-13';
const base = { ios: false, installee: false, aujourdhui: J };

test('jours entre deux dates', () => {
  assert.equal(joursEntre('2026-11-13', '2026-11-13'), 0);
  assert.equal(joursEntre('2026-10-14', '2026-11-13'), 30);
  assert.equal(joursEntre('2026-03-01', '2026-04-01'), 31); // le changement d'heure ne compte pas
  assert.ok(Number.isNaN(joursEntre(undefined, J)));
});

test('iPhone hors de l’écran d’accueil : installer, avant tout autre avis', () => {
  assert.equal(avisAccueil({ ...base, ios: true }), 'installer');
  assert.equal(avisAccueil({ ...base, ios: true, premierJour: '2025-01-01' }), 'installer');
  // Refermé, il revient au bout de trente jours : le risque, lui, ne passe pas.
  assert.equal(avisAccueil({ ...base, ios: true, reports: { installer: '2026-11-01' } }), null);
  assert.equal(avisAccueil({ ...base, ios: true, reports: { installer: '2026-10-14' } }), 'installer');
  // Un report daté de l'avenir ne vaut rien.
  assert.equal(avisAccueil({ ...base, ios: true, reports: { installer: '2027-01-01' } }), 'installer');
  // Ailleurs que sur iOS, ou une fois installée : jamais.
  assert.equal(avisAccueil({ ...base }), null);
  assert.equal(avisAccueil({ ...base, ios: true, installee: true, premierJour: J }), null);
});

test('installée sur iPhone, journal vide : importer ce que Safari gardait, une fois', () => {
  assert.equal(avisAccueil({ ...base, ios: true, installee: true }), 'importer');
  assert.equal(avisAccueil({ ...base, ios: true, installee: true, reports: { importer: '2020-01-01' } }), null);
  assert.equal(avisAccueil({ ...base, ios: true, installee: true, premierJour: J }), null);
  // Une application installée ailleurs partage le stockage du navigateur : rien à importer.
  assert.equal(avisAccueil({ ...base, installee: true }), null);
});

test('plus de trente jours sans sauvegarde : exporter', () => {
  assert.equal(REPORT_JOURS, 30);
  // Jamais sauvegardé : le compte part du premier jour du journal.
  assert.equal(avisAccueil({ ...base, premierJour: '2026-10-14' }), null);
  assert.equal(avisAccueil({ ...base, premierJour: '2026-10-13' }), 'exporter');
  assert.equal(avisAccueil({ ...base, premierJour: '2025-01-01', derniereSauvegarde: '2026-11-01' }), null);
  assert.equal(avisAccueil({ ...base, premierJour: '2025-01-01', derniereSauvegarde: '2026-10-01' }), 'exporter');
  assert.equal(avisAccueil({ ...base, premierJour: '2025-01-01', reports: { exporter: '2026-11-10' } }), null);
  assert.equal(avisAccueil({ ...base, premierJour: '2025-01-01', reports: { exporter: '2026-10-01' } }), 'exporter');
  // Un journal vide n'a rien à perdre.
  assert.equal(avisAccueil({ ...base }), null);
  // Installée sur iPhone, avec un journal : le même rappel.
  assert.equal(avisAccueil({ ...base, ios: true, installee: true, premierJour: '2025-01-01' }), 'exporter');
});

test('le store garde le jour de la dernière sauvegarde et les avis refermés', () => {
  const s = creeStore(memoire(), { maintenant: () => new Date(2026, 10, 13, 9) });
  assert.equal(s.derniereSauvegarde(), null);
  assert.deepEqual(s.avisReportes(), {});
  s.setDerniereSauvegarde(s.today());
  s.reporteAvis('installer');
  assert.equal(s.derniereSauvegarde(), '2026-11-13');
  assert.deepEqual(s.avisReportes(), { installer: '2026-11-13' });
  assert.equal(s.premierJour(), null);
  s.addSession(10, { date: '2026-11-02' });
  s.setNote('2026-10-30', 'une note');
  assert.equal(s.premierJour(), '2026-10-30');
  // Ni l'un ni l'autre ne part dans l'export : ils valent pour ce navigateur seulement.
  assert.ok(!/derniere_sauvegarde|avis_reportes/.test(s.exportJson()));
  // Réinitialiser les efface avec le reste.
  s.reinitialiser();
  assert.equal(s.derniereSauvegarde(), null);
  assert.deepEqual(s.avisReportes(), {});
});

test('une écriture refusée par le navigateur remonte au lieu d’être avalée', () => {
  const plein = { ...memoire(), setItem: () => { throw new DOMException('plein', 'QuotaExceededError'); } };
  const echecs = [];
  const s = creeStore(plein, { surEchec: (nom) => echecs.push(nom) });
  s.addSession(15);
  assert.deepEqual(echecs, ['myhitbodedut-journal']);
  s.setTargetMinutes(20);
  assert.deepEqual(echecs, ['myhitbodedut-journal', 'myhitbodedut']);
  // Sans écouteur, rien ne casse (les tests, l'import) ; une écriture réussie ne signale rien.
  creeStore(plein).addSession(15);
  const ok = [];
  creeStore(memoire(), { surEchec: (nom) => ok.push(nom) }).addSession(15);
  assert.deepEqual(ok, []);
});

test('l’application dit ce qu’elle sait du stockage (garde-fou sur app.js)', () => {
  const app = readFileSync(new URL('../src/js/app.js', import.meta.url), 'utf8');
  // Le repli en mémoire a son bandeau permanent, posé à chaque rendu.
  assert.match(app, /catch \{\s*sansStockage = true;\s*return memoire\(\);/);
  assert.match(app, /if \(sansStockage\) app\.append\(h\('p', \{ class: 'bandeau-stockage'[^\n]*tr\.t\('stockage_memoire_web'\)/);
  // L'échec d'écriture arrive à l'écran, et la réponse de persist() est lue.
  assert.match(app, /creeStore\(stockageDuNavigateur\(\), \{ surEchec: /);
  assert.match(app, /signale\(tr\.t\('stockage_echec_web'\)\)/);
  assert.match(app, /navigator\.storage\?\.persist\?\.\(\)\.then\(\(garde\) => \{ stockageDurable = garde === true;/);
  assert.match(app, /stockageDurable === false \? h\('p', \{ class: 'indice' \}, tr\.t\('stockage_fragile_web'\)\)/);
  // L'export et l'import datent la dernière sauvegarde.
  assert.equal(app.split('store.setDerniereSauvegarde(store.today())').length - 1, 3);
});
