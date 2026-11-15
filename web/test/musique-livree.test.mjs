// La musique que le site sert (13/11, audit du 12/11, FPRODUIT-05) : celle de la version Play,
// et elle seule. Un site public est une diffusion : les morceaux dont la diffusion publique
// n'est pas établie (PUBLICATION_PLAY_STORE.md § 3.2) n'y entrent pas, et le service worker
// les retire des téléphones qui les avaient gardés.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import { TAILLE_MAX, litListe, morceauxLivres } from '../tools/musique.mjs';

const chemin = (c) => fileURLToPath(new URL(`../../${c}`, import.meta.url));
const lire = (c) => readFileSync(chemin(c), 'utf8');
const ANDROID = chemin('android/app/src/main');

test('le site livre les morceaux de MusiquePlay.kt, dans son ordre, et rien d’autre', () => {
  const play = litListe(lire('android/app/src/main/java/com/myhitbodedut/MusiquePlay.kt'));
  assert.ok(play.length >= 3);
  const livres = morceauxLivres(ANDROID);
  assert.deepEqual(livres.map((m) => m.id), play.map((m) => m.id));
  assert.equal(livres[0].id, 'hamelech_basade');
  const titres = lire('android/app/src/main/res/values/strings.xml');
  for (const m of livres) {
    assert.equal(m.fichier, `musique/${m.id}.m4a`);
    assert.ok(m.source.startsWith(`${ANDROID}/res/raw/`), m.source);
    assert.ok(m.octets > 0 && m.octets <= TAILLE_MAX, `${m.id} : ${m.octets} octets`);
    assert.ok(titres.includes(`<string name="${m.titre}"`), m.titre);
  }
});

test('aucun morceau retiré de Play n’est servi par le site', () => {
  const horsPlay = 'android/app/src/musique_hors_play/java/com/myhitbodedut/MusiqueHorsPlay.kt';
  const retires = existsSync(chemin(horsPlay)) ? litListe(lire(horsPlay)).map((m) => m.id) : [];
  const livres = new Set(morceauxLivres(ANDROID).map((m) => m.id));
  for (const id of retires) assert.ok(!livres.has(id), id);
  assert.ok(![...livres].some((id) => /^niggoun_\d+$/.test(id) || id.startsWith('ribo_')));
  // build.mjs ne connaît que cette liste : ni l'autre fichier Kotlin, ni son dossier.
  const build = lire('web/build.mjs');
  assert.match(build, /const morceaux = morceauxLivres\(ANDROID\)/);
  assert.ok(!/MusiqueHorsPlay|musique_hors_play/.test(build + lire('web/tools/musique.mjs')));
});

test('Cloudflare Pages : la construction refuse tout fichier de plus de 25 Mio', () => {
  assert.equal(TAILLE_MAX, 25 * 1024 * 1024);
  assert.match(lire('web/build.mjs'), /statSync\(f\)\.size > TAILLE_MAX\) throw new Error/);
});

/** Un faux stockage de caches, et sw.js tel que build.mjs l'écrit, avec la liste [livres]. */
function serviceWorker(livres, caches, coquille = []) {
  const ecouteurs = {};
  const magasins = new Map(Object.entries(caches).map(([nom, adresses]) => [nom, new Map(adresses.map((a) => [a, new Response('x')]))]));
  const source = lire('web/src/sw.js').replace('__VERSION__', 'essai').replace('__COQUILLE__', JSON.stringify(coquille)).replace('__MUSIQUE__', JSON.stringify(livres));
  const demandes = [];
  const ajoutes = [];
  vm.runInNewContext(source, {
    URL, Response, Request: class { constructor(url, o = {}) { this.url = url; this.cache = o.cache; } },
    fetch: async (r) => { demandes.push(typeof r === 'string' ? r : r.url); return new Response('reseau'); },
    self: {
      location: { origin: 'https://site.test' },
      addEventListener: (nom, f) => { ecouteurs[nom] = f; },
      skipWaiting: async () => {},
      clients: { claim: async () => {} },
    },
    caches: {
      keys: async () => [...magasins.keys()],
      delete: async (nom) => magasins.delete(nom),
      open: async (nom) => {
        if (!magasins.has(nom)) magasins.set(nom, new Map());
        const m = magasins.get(nom);
        return {
          keys: async () => [...m.keys()].map((url) => ({ url })),
          delete: async (requete) => m.delete(requete.url),
          match: async (cle) => m.get(typeof cle === 'string' ? cle : cle.url),
          put: async (cle, reponse) => { m.set(cle, reponse); },
          addAll: async (liste) => { ajoutes.push(...liste); },
        };
      },
      match: async () => undefined,
    },
  });
  return { ecouteurs, magasins, demandes, ajoutes };
}

test('à l’installation, chaque fichier de la coquille est redemandé au serveur (FWEBCODE-03)', async () => {
  // Sans cela, un fichier encore frais dans le cache HTTP (max-age=600) entrait périmé dans la coquille neuve.
  const { ecouteurs, ajoutes } = serviceWorker([], {}, ['./', 'js/app.js', 'strings/strings.fr.json']);
  let fin;
  ecouteurs.install({ waitUntil: (p) => { fin = p; } });
  await fin;
  assert.deepEqual(ajoutes.map((r) => [r.url, r.cache]), [['./', 'no-cache'], ['js/app.js', 'no-cache'], ['strings/strings.fr.json', 'no-cache']]);
});

test('le service worker retire de son cache les morceaux que le site ne livre plus', async () => {
  const base = 'https://site.test/app/musique/';
  const { ecouteurs, magasins } = serviceWorker(['musique/hamelech_basade.m4a', 'musique/yanuka_nigoun_3.m4a'], {
    'musique-2': [`${base}hamelech_basade.m4a`, `${base}niggoun_05.m4a`, `${base}ribo_sans_titre.m4a`],
    'musique-1': [`${base}niggoun_01.mp3`],
    'coquille-ancienne': ['https://site.test/app/'],
  });
  let fin;
  ecouteurs.activate({ waitUntil: (p) => { fin = p; } });
  await fin;
  assert.deepEqual([...magasins.keys()].sort(), ['musique-2']);
  assert.deepEqual([...magasins.get('musique-2').keys()], [`${base}hamelech_basade.m4a`]);
});

test('le service worker ne garde un morceau que s’il est livré', async () => {
  const { ecouteurs, magasins, demandes } = serviceWorker(['musique/hamelech_basade.m4a'], { 'musique-2': [] });
  const demande = async (url) => {
    const attentes = [];
    let reponse;
    ecouteurs.fetch({ request: { url, method: 'GET', mode: 'cors', headers: new Headers() }, waitUntil: (p) => attentes.push(p), respondWith: (p) => { reponse = p; } });
    await reponse;
    await Promise.all(attentes);
  };
  await demande('https://site.test/app/musique/hamelech_basade.m4a');
  await demande('https://site.test/app/musique/niggoun_05.m4a');
  assert.deepEqual([...magasins.get('musique-2').keys()], ['https://site.test/app/musique/hamelech_basade.m4a']);
  assert.ok(demandes.length >= 2);
});
