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

test('le relais compte une adresse IPv6 pour son /64, et ne compte que les demandes à OpenSky (revue du 15/11)', async () => {
  const { cleAdresse, budgetEpuise, BUDGET_JOUR, ETATS } = await import('../../tools/relais_vol/worker.js');
  assert.equal(cleAdresse('2001:db8:1:2:aaaa::1'), '2001:db8:1:2::/64');
  assert.equal(cleAdresse('2001:0db8:0001:0002:ffff:ffff:ffff:ffff'), '2001:db8:1:2::/64');
  assert.equal(cleAdresse('2001:db8::5'), '2001:db8:0:0::/64');
  assert.equal(cleAdresse('203.0.113.7'), '203.0.113.7');
  assert.equal(cleAdresse(null), null);
  // Le budget du jour : au-delà, plus aucune demande ; le lendemain, il repart.
  const b = { jour: '', n: 0 };
  const midi = Date.parse('2026-11-15T12:00:00Z');
  for (let i = 0; i < BUDGET_JOUR.anonyme; i++) assert.equal(budgetEpuise(false, midi, b), false);
  assert.equal(budgetEpuise(false, midi, b), true);
  assert.equal(budgetEpuise(false, midi + 86_400_000, b), false);
  // Une même adresse, servie depuis le cache : aucune demande à OpenSky, donc aucun compte.
  let appels = 0;
  const chercher = async (url) => { if (String(url).startsWith(ETATS)) appels++; return new Response(JSON.stringify({ states: [] }), { status: 200 }); };
  const cache = new Map(); const debits = new Map(); const budget = { jour: '', n: 0 };
  const req = () => new Request('https://relais.test/position?indicatif=ELY1&lat=50&lon=-20', { headers: { 'cf-connecting-ip': '2001:db8:1:2::9' } });
  for (let i = 0; i < 30; i++) assert.equal((await traiter(req(), {}, chercher, cache, midi, debits, budget)).status, 200);
  assert.equal(appels, 1);
  assert.equal(budget.n, 1);
});

test('les clients distinguent le débit du relais du quota OpenSky, même en 5xx (revue du 15/11)', async () => {
  const Vol = await import('../src/js/vol.js');
  const maintenant = new Date('2026-11-10T18:31:00Z');
  const reponse = (status, corps) => async () => new Response(corps === undefined ? '' : JSON.stringify(corps), { status });
  const p = (f) => Vol.positionEnDirect('https://r.test', 'ELY1', { latitude: 0, longitude: 0 }, f, maintenant);
  assert.equal((await p(reponse(429, { erreur: 'relais 429' }))).raison, 'trop_de_demandes');
  assert.equal((await p(reponse(502, { erreur: 'opensky 429' }))).raison, 'quota');
  assert.equal((await p(reponse(502, { erreur: 'opensky injoignable' }))).raison, 'service');
  assert.equal((await p(reponse(503))).raison, 'serveur_503');
  assert.equal((await p(reponse(200, { trouve: false }))).statut, 'introuvable');
  const fr = readFileSync(new URL('../../android/app/src/main/res/values/strings.xml', import.meta.url), 'utf8');
  assert.ok(fr.includes('name="vol_erreur_trop_de_demandes"'));
});

test('l’import borne aussi les clés de la version 2 (revue du 15/11)', () => {
  const s = creeStore(memoire());
  const long = 'x'.repeat(20_000);
  s.importJson(JSON.stringify({
    format: 'myhitbodedut', version: 2, days: {},
    favoris: [...Array.from({ length: 1000 }, (_, i) => `s:${i}`), `s:${long}`, 's:a|l:b'],
    chizuk_favoris: [...Array.from({ length: 2000 }, (_, i) => `c${i}`), long, 'a|b'],
    marques_pages: [
      { cle: 'siddur', nusah: 'edot', section: 1, bloc: 2, apercu: long },
      { cle: long, nusah: 'edot', section: 1, bloc: 3, apercu: '' },
      { cle: 'siddur', nusah: long, section: 1, bloc: 4, apercu: '' },
    ],
    tikkun_journal: Array.from({ length: 6000 }, (_, i) => new Date(Date.UTC(2000, 0, 1) + i * 86_400_000).toISOString().slice(0, 10)),
  }));
  const sortie = JSON.parse(s.exportJson());
  assert.ok(sortie.favoris.length <= 200 && sortie.favoris.every((f) => f.length <= 100 && !f.includes('|')));
  assert.ok(sortie.chizuk_favoris.length <= 500 && sortie.chizuk_favoris.every((c) => c.length <= 40 && !c.includes('|')));
  assert.equal(sortie.marques_pages.length, 1);
  assert.ok(sortie.marques_pages[0].apercu.length <= 200);
  assert.ok(sortie.tikkun_journal.length <= 4000);
  assert.ok(JSON.stringify(sortie).length < 120_000);
});
