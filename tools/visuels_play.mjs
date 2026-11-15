// Compose les captures de la fiche Google Play (13/11) : 1080 × 1920, un titre, une phrase,
// et la capture réelle de l'application Android dans un cadre de téléphone.
//
// Les captures brutes viennent de l'émulateur (job « captures » de android.yml, étape
// « 27 visuels Play » de .github/captures/captures.py) : c'est l'application soumise, pas le
// site (audit du 12/11, TPLAYDOCS-06). Les légendes sont dans play/visuels/legendes.json.
//
// Usage : node tools/visuels_play.mjs <dossier des captures brutes> [dossier de sortie]
//   brutes attendues : play-<langue>-<clé>.png (ex. play-en-accueil.png, play-he-barriere.png)
//   sortie : play/visuels/<langue Play>/<NN>-<clé>.png, sans canal alpha.
import { readFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const ICI = dirname(fileURLToPath(import.meta.url));
const RACINE = resolve(ICI, '..');
const brutes = resolve(process.argv[2] || 'out');
const sortie = resolve(process.argv[3] || join(RACINE, 'play', 'visuels'));
const legendes = JSON.parse(readFileSync(join(RACINE, 'play', 'visuels', 'legendes.json'), 'utf8'));

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const police = (nom) => pathToFileURL(join(RACINE, 'web', 'src', 'polices', nom)).href;
const b64 = (chemin) => `data:image/png;base64,${readFileSync(chemin).toString('base64')}`;
const echappe = (t) => t.replace(/&/g, '&amp;').replace(/</g, '&lt;');

function page(langue, titre, phrase, image) {
  const he = langue === 'he';
  return `<!doctype html><html lang="${langue}" dir="${he ? 'rtl' : 'ltr'}"><meta charset="utf-8"><style>
@font-face { font-family: Hebreu; src: url(${police('varela_round.ttf')}); }
* { box-sizing: border-box; margin: 0; }
html, body { width: 1080px; height: 1920px; overflow: hidden; }
body { background: radial-gradient(1200px 900px at 50% 0, #2c6e57 0, #1d4a3b 38%, #10271f 100%);
  font-family: ${he ? 'Hebreu, ' : ''}'Inter Display', Inter, sans-serif; color: #fff; text-align: center; }
h1 { position: absolute; inset: 118px 60px auto; font-size: ${he ? 84 : 78}px; line-height: 1.08; font-weight: ${he ? 400 : 800};
  letter-spacing: ${he ? 0 : -1.5}px; text-wrap: balance; }
p { position: absolute; inset: 0 90px auto; top: var(--haut-phrase); font-family: ${he ? 'Hebreu, ' : ''}Inter, sans-serif;
  font-size: 39px; line-height: 1.28; color: #cfe3da; text-wrap: balance; }
.cadre { position: absolute; left: 170px; top: 548px; width: 740px; height: 1700px; border-radius: 78px;
  background: #0b1a15; padding: 11px; box-shadow: 0 40px 90px rgba(0, 0, 0, .45); }
.cadre img { width: 100%; border-radius: 68px; display: block; }
</style><body><h1 id="t">${echappe(titre)}</h1><p id="p">${echappe(phrase)}</p>
<div class="cadre"><img src="${image}"></div>
<script>document.documentElement.style.setProperty('--haut-phrase', (document.getElementById('t').getBoundingClientRect().bottom + 26) + 'px');</script>
</body></html>`;
}

const navigateur = await chromium.launch();
const onglet = await navigateur.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
let faits = 0, manquants = 0;
for (const [langue, jeu] of Object.entries(legendes.langues)) {
  mkdirSync(join(sortie, jeu.dossier), { recursive: true });
  let n = 0;
  for (const v of jeu.visuels) {
    n++;
    const brute = join(brutes, `play-${langue}-${v.cle}.png`);
    if (!existsSync(brute)) { console.log('MANQUE', brute); manquants++; continue; }
    await onglet.setContent(page(langue, v.titre, v.phrase, b64(brute)), { waitUntil: 'load' });
    await onglet.evaluate(() => document.fonts.ready);
    // Le titre et la phrase ne doivent pas descendre sur le téléphone.
    const bas = await onglet.evaluate(() => document.getElementById('p').getBoundingClientRect().bottom);
    if (bas > 520) console.log(`ATTENTION ${langue} ${v.cle} : la légende descend à ${Math.round(bas)} px (cadre à 548)`);
    const cible = join(sortie, jeu.dossier, `${String(n).padStart(2, '0')}-${v.cle}.png`);
    await onglet.screenshot({ path: cible, type: 'png', omitBackground: false });
    console.log('écrit', cible);
    faits++;
  }
}
await navigateur.close();
console.log(`${faits} visuel(s), ${manquants} capture(s) manquante(s)`);
process.exit(manquants ? 1 : 0);
