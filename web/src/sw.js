// Hors connexion.
//
// La coquille (code, chaînes, textes, illustrations, livres et biographies : environ 52 Mo gardés, 16 Mo transférés) est
// gardée à l'installation, pour que tout se lise hors connexion. La lecture de la Torah du jour (26/11) y est aussi : 2,3 Mo,
// 0,55 Mo transférés (data/lecture_torah.json et data/lecture_torah/<livre>.json), et le Targoum Onkelos de Chnayim mikra :
// 1,3 Mo, 0,23 Mo transférés (data/lecture_torah/targoum/<livre>.json), lus à la demande. La musique ne l'est pas d'office :
// chaque morceau est gardé la première fois qu'on l'écoute, puis servi depuis le téléphone.
//
// Safari lit un morceau par tranches (en-tête Range) et exige qu'on lui
// réponde tranche par tranche (206) : un fichier entier en réponse à une
// tranche ne se lit pas. D'où tranche().

const VERSION = '__VERSION__';
const COQUILLE = __COQUILLE__;
// Les morceaux que le site livre (« musique/<id>.m4a », build.mjs).
const MUSIQUE = __MUSIQUE__;
const CACHE_COQUILLE = `coquille-${VERSION}`;
// musique-2 : les morceaux en AAC (.m4a, 29/10) ; les MP3 de musique-1 sont effacés.
const CACHE_MUSIQUE = 'musique-2';

// Chaque fichier est redemandé au serveur (cache: 'no-cache', FWEBCODE-03) : avec max-age=600, un fichier
// changé moins de dix minutes après une visite entrait périmé dans la nouvelle coquille, sans requête,
// à côté du code neuf. Un fichier inchangé revient en 304, sans être retéléchargé.
self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE_COQUILLE).then((c) => c.addAll(COQUILLE.map((u) => new Request(u, { cache: 'no-cache' }))))
    .then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    for (const nom of await caches.keys()) {
      if (nom.startsWith('coquille-') && nom !== CACHE_COQUILLE) await caches.delete(nom);
      if (nom.startsWith('musique-') && nom !== CACHE_MUSIQUE) await caches.delete(nom);
    }
    // Un morceau que le site ne livre plus (13/11, FPRODUIT-05 : les niggounim dont la diffusion
    // publique n'est pas établie) ne reste pas non plus dans le téléphone.
    const musique = await caches.open(CACHE_MUSIQUE);
    for (const requete of await musique.keys()) {
      const chemin = new URL(requete.url).pathname;
      if (!MUSIQUE.some((f) => chemin.endsWith(`/${f}`))) await musique.delete(requete);
    }
    await self.clients.claim();
  })());
});

async function tranche(requete, reponse) {
  const plage = requete.headers.get('range');
  if (!plage) return reponse;
  const corps = await reponse.blob();
  const m = /bytes=(\d*)-(\d*)/.exec(plage);
  const taille = corps.size;
  let debut = m && m[1] !== '' ? Number(m[1]) : 0;
  let fin = m && m[2] !== '' ? Number(m[2]) : taille - 1;
  if (m && m[1] === '' && m[2] !== '') { debut = Math.max(0, taille - Number(m[2])); fin = taille - 1; }
  fin = Math.min(fin, taille - 1);
  if (debut > fin) return new Response(null, { status: 416, headers: { 'Content-Range': `bytes */${taille}` } });
  return new Response(corps.slice(debut, fin + 1), {
    status: 206,
    headers: {
      'Content-Type': reponse.headers.get('Content-Type') || 'audio/mp4',
      'Content-Range': `bytes ${debut}-${fin}/${taille}`,
      'Content-Length': String(fin - debut + 1),
      'Accept-Ranges': 'bytes',
    },
  });
}

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET' || url.origin !== self.location.origin) return;

  // Les morceaux livrés seulement : une adresse de /musique/ que le site ne sert plus n'est pas gardée.
  if (MUSIQUE.some((f) => url.pathname.endsWith(`/${f}`))) {
    const cle = url.origin + url.pathname;
    e.respondWith((async () => {
      const cache = await caches.open(CACHE_MUSIQUE);
      const garde = await cache.match(cle);
      if (garde) return tranche(e.request, garde);
      // Première écoute : le réseau sert la lecture, et le morceau entier
      // est gardé en même temps pour la suivante.
      e.waitUntil(fetch(cle).then((r) => (r.ok && r.status === 200 ? cache.put(cle, r) : null)).catch(() => {}));
      return fetch(e.request);
    })());
    return;
  }

  // La coquille : d'abord le téléphone, le réseau sinon. Une page ouverte
  // (navigation) retombe sur l'accueil gardé.
  e.respondWith((async () => {
    const garde = await caches.match(e.request, { ignoreSearch: true });
    if (garde) return garde;
    try {
      return await fetch(e.request);
    } catch (err) {
      if (e.request.mode === 'navigate') {
        const accueil = await caches.match('./');
        if (accueil) return accueil;
      }
      throw err;
    }
  })());
});
