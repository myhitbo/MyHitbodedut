// Les morceaux que le site livre (13/11, audit du 12/11, FPRODUIT-05).
//
// Un site public est une diffusion : il ne sert que les morceaux dont la
// diffusion publique est établie, ceux de la version Play (MusiquePlay.kt,
// fichiers dans main/res/raw ; PUBLICATION_PLAY_STORE.md § 3.2). Ce qui
// n'entre pas dans Play n'entre pas non plus dans le site. L'ordre et les
// titres restent ceux de l'application Android, lus dans son source.

import { existsSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

/** Cloudflare Pages, qui sert le site, refuse tout fichier de plus de 25 Mio. */
export const TAILLE_MAX = 25 * 1024 * 1024;

/** Les lignes « Bundled("id", R.raw.id, R.string.track_id) » d'une liste Kotlin, dans l'ordre. */
export function litListe(kt) {
  return [...kt.matchAll(/Bundled\("([a-z0-9_]+)", R\.raw\.\1, R\.string\.(track_[a-z0-9_]+)\)/g)]
    .map(([, id, titre]) => ({ id, titre }));
}

/**
 * Les morceaux livrés, tels que data/musique.json les décrit, avec le fichier d'origine
 * (`source`) que build.mjs copie. `android` : le dossier android/app/src/main.
 */
export function morceauxLivres(android) {
  const liste = join(android, 'java', 'com', 'myhitbodedut', 'MusiquePlay.kt');
  const morceaux = litListe(readFileSync(liste, 'utf8')).map(({ id, titre }) => {
    const source = join(android, 'res', 'raw', `${id}.m4a`);
    if (!existsSync(source)) throw new Error(`Morceau manquant : ${source}`);
    const octets = statSync(source).size;
    if (octets > TAILLE_MAX) throw new Error(`Morceau de plus de 25 Mio, refusé par Cloudflare Pages : ${source}`);
    return { id, titre, fichier: `musique/${id}.m4a`, octets, source };
  });
  if (morceaux.length === 0) throw new Error(`Aucun morceau trouvé dans ${liste}`);
  return morceaux;
}
