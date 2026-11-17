// Écrit textes.bin pour l'application Java, depuis les ressources Android
// (français, anglais, hébreu).
//
//   node nokia/app/genere-textes.mjs <sortie>

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { litChaines } from '../../web/tools/chaines.mjs';
import { DOSSIERS, LANGUES, encode, textesLangues } from '../textes.mjs';

const ICI = dirname(fileURLToPath(import.meta.url));
const RES = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res');
const sortie = process.argv[2];
if (!sortie) throw new Error('usage : genere-textes.mjs <sortie>');

const chizuk = JSON.parse(readFileSync(join(RES, 'raw', 'chizuk.json'), 'utf8'));
const chaines = Object.fromEntries(LANGUES.map((l) =>
  [l, litChaines(readFileSync(join(RES, DOSSIERS[l], 'strings.xml'), 'utf8')).chaines]));
const donnees = textesLangues(chizuk, chaines);
const octets = encode(donnees);
mkdirSync(dirname(sortie), { recursive: true });
writeFileSync(sortie, octets);
const n = donnees.moments.reduce((s, m) => s + m.textes.length, 0);
console.log(`textes.bin : ${donnees.moments.length} moments, ${n} textes, ${LANGUES.join('/')}, ${octets.length} octets`);
