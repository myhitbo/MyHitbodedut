// La lecture de la Torah (26/11) : ce que build.mjs et les tests partagent.
//
//  - decoupeTexte : lecture_torah_texte.json (2,2 Mo) en un fichier par livre, que le site lit à la
//    demande (data/lecture_torah/<livre>.json) ;
//  - resume / vecteurs : la réponse de lecture-torah.js, jour par jour, sous la forme que
//    web/test/vecteurs_lecture_torah.json garde et que LectureTorahTest.kt relit (même calcul côté
//    Android). Régénérer : node web/tools/lecture-torah.mjs (depuis la racine du dépôt).

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ajouteJours } from '../src/js/calendrier.js';
import { fichierLivre, lectures, NUSAH, OFFICES } from '../src/js/lecture-torah.js';

const ICI = dirname(fileURLToPath(import.meta.url));
export const RAW = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res', 'raw');
export const VECTEURS = join(ICI, '..', 'test', 'vecteurs_lecture_torah.json');
/** Six années hébraïques entières (5786 à 5791) et leurs bords. */
export const DEBUT = '2025-09-01';
export const FIN = '2031-12-31';
/** Diaspora, Israël, Jérusalem (Pourim le 15). */
export const LIEUX = { dia: { enIsrael: false, mukafChoma: false }, il: { enIsrael: true, mukafChoma: false }, jer: { enIsrael: true, mukafChoma: true } };

/** Un fichier par livre : { livre, chapitres, paragraphes }. */
export function decoupeTexte(texte) {
  const sortie = {};
  for (const [livre, chapitres] of Object.entries(texte.livres)) {
    if (!/^[A-Za-z ]+$/.test(livre)) throw new Error(`Livre inattendu : ${livre}`);
    sortie[fichierLivre(livre)] = { livre, chapitres, paragraphes: texte.paragraphes?.[livre] ?? {} };
  }
  return sortie;
}

/** Une lecture en une ligne : clé | montées | haftara. */
export function resume(l) {
  const m = l.montees.map((x) => `${x.cle}:${x.livre} ${x.debut}-${x.fin}`).join(',');
  const h = l.haftara.map((x) => `${x.livre} ${x.debut}-${x.fin}`).join(',');
  return `${l.cle}|${m}|${h}`;
}

/**
 * { "AAAA-MM-JJ/lieu": { office: { nusah | "*": [résumé…] } } } pour les jours où l'on lit ; Jérusalem
 * seulement quand elle diffère d'Israël (vide si elle ne lit pas), le noussa'h « * » quand les trois s'accordent.
 */
export function vecteurs(donnees, debut = DEBUT, fin = FIN) {
  const jours = {};
  for (let iso = debut; iso <= fin; iso = ajouteJours(iso, 1)) {
    let israel = null;
    for (const [lieu, opts] of Object.entries(LIEUX)) {
      const parOffice = {};
      for (const office of OFFICES) {
        const parNusah = Object.fromEntries(NUSAH.map((n) => [n, lectures(donnees, iso, office, { ...opts, nusah: n }).map(resume)]));
        if (parNusah.edot.length === 0 && parNusah.sefard.length === 0 && parNusah.ashkenaz.length === 0) continue;
        const memes = NUSAH.every((n) => JSON.stringify(parNusah[n]) === JSON.stringify(parNusah.edot));
        parOffice[office] = memes ? { '*': parNusah.edot } : parNusah;
      }
      const cle = JSON.stringify(parOffice);
      if (lieu === 'il') israel = cle;
      if (lieu === 'jer' && cle === israel) continue;
      // Jérusalem sans lecture quand Israël en a une (le 14 Adar) : écrite vide.
      if (Object.keys(parOffice).length || lieu === 'jer') jours[`${iso}/${lieu}`] = parOffice;
    }
  }
  return { debut, fin, jours };
}

/** Le fichier des vecteurs, une entrée par ligne. */
export function ecritVecteurs(v, chemin = VECTEURS) {
  const lignes = Object.entries(v.jours).map(([k, x]) => `${JSON.stringify(k)}: ${JSON.stringify(x)}`);
  writeFileSync(chemin, `{\n"debut": ${JSON.stringify(v.debut)},\n"fin": ${JSON.stringify(v.fin)},\n"jours": {\n${lignes.join(',\n')}\n}\n}\n`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const donnees = JSON.parse(readFileSync(join(RAW, 'lecture_torah.json'), 'utf8'));
  const v = vecteurs(donnees);
  ecritVecteurs(v);
  console.log(`${Object.keys(v.jours).length} entrées écrites dans ${VECTEURS}`);
}
