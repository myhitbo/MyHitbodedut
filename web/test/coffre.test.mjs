// La sauvegarde chiffrée par mot de passe (coffre.js, Coffre.kt ; audit de sécurité du 12/11/2026).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { chiffrer, dechiffrer, estChiffre, ITERATIONS } from '../src/js/coffre.js';
import { creeStore, memoire } from '../src/js/store.js';
import { tropDemande, DEBIT_MAX, DEBIT_FENETRE, traiter } from '../../tools/relais_vol/worker.js';

const CLAIR = '{"format":"myhitbodedut","days":{"2026-11-12":{"note":"שלום, une note intime"}}}';

test('le bon mot de passe rend le texte, un autre ne rend rien', async () => {
  const chiffre = await chiffrer(CLAIR, 'mot de passe é', 100_000);
  assert.ok(estChiffre(chiffre));
  assert.ok(!chiffre.includes('intime'));
  assert.equal(await dechiffrer(chiffre, 'mot de passe é'), CLAIR);
  assert.equal(await dechiffrer(chiffre, 'mot de passe e'), null);
  assert.notEqual(chiffre, await chiffrer(CLAIR, 'mot de passe é', 100_000));
  assert.ok(ITERATIONS >= 600_000);
});

test('un fichier modifié ou fabriqué est refusé', async () => {
  const r = JSON.parse(await chiffrer(CLAIR, 'a', 100_000));
  const abime = { ...r, data: (r.data[0] === 'A' ? 'B' : 'A') + r.data.slice(1) };
  assert.equal(await dechiffrer(JSON.stringify(abime), 'a'), null);
  assert.equal(await dechiffrer(JSON.stringify({ ...r, iterations: 1 }), 'a'), null);
  assert.equal(await dechiffrer(JSON.stringify({ ...r, iterations: 2e9 }), 'a'), null);
  assert.equal(await dechiffrer(CLAIR, 'a'), null);
  assert.ok(!estChiffre(CLAIR));
  assert.ok(!estChiffre('pas du json'));
});

test('le vecteur commun avec Android (CoffreTest) se déchiffre', async () => {
  const v = JSON.parse(readFileSync(new URL('./vecteur_coffre.json', import.meta.url), 'utf8'));
  assert.equal(await dechiffrer(JSON.stringify(v.chiffre), v.mot_de_passe), v.clair);
});

test('une sauvegarde chiffrée, puis déchiffrée, s’importe comme une autre', async () => {
  const a = creeStore(memoire());
  a.setNote(a.today(), 'une note');
  const b = creeStore(memoire());
  assert.equal(b.importJson(await dechiffrer(await chiffrer(a.exportJson(), 'x', 100_000), 'x')), 1);
  assert.equal(b.importJson(await chiffrer(a.exportJson(), 'x', 100_000)), null);
});

test('l’import borne ce qu’un fichier fabriqué apporte', () => {
  const s = creeStore(memoire());
  const jour = s.today();
  const n = s.importJson(JSON.stringify({
    format: 'myhitbodedut',
    days: { [jour]: { minutes: 5, themes: [...Array.from({ length: 500 }, (_, i) => `t${i}`), 'x'.repeat(10_000)] } },
    settings: { music_track: 'm'.repeat(100_000) },
    blocked_apps: [...Array.from({ length: 5000 }, (_, i) => `app.${i}`), 'y'.repeat(100_000)],
  }));
  assert.equal(n, 1);
  const sortie = JSON.parse(s.exportJson());
  assert.ok(sortie.days[jour].themes.length <= 20);
  assert.ok(sortie.blocked_apps.length <= 500);
  assert.ok(JSON.stringify(sortie).length < 50_000);
});

test('le relais refuse une adresse qui demande trop, puis la laisse repasser', async () => {
  const debits = new Map();
  for (let i = 0; i < DEBIT_MAX; i++) assert.equal(tropDemande('1.2.3.4', 1000, debits), false);
  assert.equal(tropDemande('1.2.3.4', 1000, debits), true);
  assert.equal(tropDemande('5.6.7.8', 1000, debits), false);
  assert.equal(tropDemande('1.2.3.4', 1000 + DEBIT_FENETRE, debits), false);
  // Refusée avant toute demande à OpenSky : ses crédits ne partent pas.
  const pleins = new Map([['9.9.9.9', { fin: Date.now() + 60_000, n: DEBIT_MAX }]]);
  let appels = 0;
  const r = await traiter(new Request('https://relais.test/position?indicatif=ELY1&lat=50&lon=-20', { headers: { 'cf-connecting-ip': '9.9.9.9' } }),
    {}, async () => { appels++; return new Response('{}'); }, new Map(), Date.now(), pleins);
  assert.equal(r.status, 429);
  assert.equal((await r.json()).erreur, 'relais 429');
  assert.equal(appels, 0);
});
