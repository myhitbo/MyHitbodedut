// SessionRuleTest, SessionCounterTest, DanseMesureTest, ChizukBagTest et les
// règles d'affichage du ’hizouk, portés depuis Android ; puis la séance
// telle que le site l'enregistre.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DanseMesure, SessionRule } from '../src/js/seance.js';
import { ChizukBag, ChizukRules, MOMENTS } from '../src/js/chizuk.js';
import { creeStore, memoire } from '../src/js/store.js';

const ICI = dirname(fileURLToPath(import.meta.url));
const chizuk = JSON.parse(readFileSync(join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res', 'raw', 'chizuk.json'), 'utf8'));

const minute = 60000;
const debut = 1_700_000_000_000;

test('une séance minutée s’arrête à son terme', () => {
  const fin = debut + 20 * minute;
  assert.equal(SessionRule.enCours(debut, fin, 20, fin - 1), true);
  assert.equal(SessionRule.enCours(debut, fin, 20, fin), false);
  assert.equal(SessionRule.enCours(debut, fin, 20, fin + minute), false);
});

test('une séance ouverte ne s’arrête pas d’elle-même', () => {
  assert.equal(SessionRule.estOuverte(debut, SessionRule.OUVERTE), true);
  for (const s of [1, 60, 600, 86400]) {
    assert.equal(SessionRule.enCours(debut, 0, SessionRule.OUVERTE, debut + s * 1000), true, `${s} s`);
  }
  assert.equal(SessionRule.estOuverte(0, SessionRule.OUVERTE), false);
  assert.equal(SessionRule.enCours(0, 0, SessionRule.OUVERTE, debut), false);
});

test('la durée réelle et le reste', () => {
  assert.equal(SessionRule.minutesEcoulees(debut, debut + 59999), 0);
  assert.equal(SessionRule.minutesEcoulees(debut, debut + minute), 1);
  assert.equal(SessionRule.minutesEcoulees(debut, debut + 47 * minute + 30000), 47);
  assert.equal(SessionRule.minutesEcoulees(debut, debut - minute), 0);
  assert.equal(SessionRule.minutesEcoulees(0, debut), 0);
  const fin = debut + 10 * minute;
  assert.equal(SessionRule.minutesRestantes(fin, debut), 10);
  assert.equal(SessionRule.minutesRestantes(fin, fin - 1000), 1);
  assert.equal(SessionRule.minutesRestantes(fin, fin), 0);
  assert.equal(SessionRule.minutesRestantes(fin, fin + minute), 0);
});

test('le compteur masqué ne dit rien', () => {
  assert.equal(SessionRule.compteur(false, true), 'masque');
  assert.equal(SessionRule.compteur(true, true), 'masque');
  assert.equal(SessionRule.compteur(false, false), 'reste');
  assert.equal(SessionRule.compteur(true, false), 'ecoule');
});

// --- DanseMesure ---------------------------------------------------------------------
const instants = Array.from({ length: 401 }, (_, i) => i / 400);
test('chaque valeur de la danse reste dans ses bornes', () => {
  for (const t of instants) {
    const p = DanseMesure.pas(t);
    assert.ok(p.hauteur >= 0 && p.hauteur <= 1);
    assert.ok(p.flexion >= 0 && p.flexion <= 1);
    assert.ok(p.balance >= -1 && p.balance <= 1);
    assert.ok(p.poseB >= 0 && p.poseB <= 1);
  }
});
test('le mouvement est continu, boucle comprise', () => {
  const ts = [...instants, 1];
  for (let i = 0; i < ts.length - 1; i++) {
    const x = DanseMesure.pas(ts[i]);
    const y = DanseMesure.pas(ts[i + 1]);
    assert.ok(Math.abs(x.hauteur - y.hauteur) < 0.05, `hauteur à ${ts[i]}`);
    assert.ok(Math.abs(x.balance - y.balance) < 0.05, `balance à ${ts[i]}`);
    assert.ok(Math.abs(x.poseB - y.poseB) < 0.3, `pose à ${ts[i]}`);
  }
});
test('il change de jambe à chaque temps et touche le sol en changeant', () => {
  const pres = (a, b) => assert.ok(Math.abs(a - b) < 0.001, `${a} ≠ ${b}`);
  pres(DanseMesure.pas(0.2).poseB, 0);
  pres(DanseMesure.pas(0.7).poseB, 1);
  pres(DanseMesure.pas(0).hauteur, 0);
  pres(DanseMesure.pas(0.5).hauteur, 0);
  pres(DanseMesure.pas(0.25).hauteur, 1);
  pres(DanseMesure.pas(0.5).flexion, 1);
});

// --- ChizukBag -------------------------------------------------------------------------
const vivier = ['a', 'b', 'c', 'd'];
const identite = (l) => [...l];
test('un cycle sort chaque texte une fois et une seule', () => {
  const sortis = [];
  let reste = [];
  for (let i = 0; i < vivier.length; i++) {
    const t = ChizukBag.suivant(reste, vivier, sortis.at(-1) ?? null, identite);
    sortis.push(t.id);
    reste = t.reste;
  }
  assert.deepEqual(new Set(sortis), new Set(vivier));
  assert.equal(new Set(sortis).size, vivier.length);
  assert.deepEqual(reste, []);
});
test('le cycle suivant ne rouvre pas sur le dernier texte du précédent', () => {
  const t = ChizukBag.suivant([], vivier, 'a', identite);
  assert.equal(t.id, 'b');
  assert.ok(t.reste.includes('a'));
});
test('cas limites du sac', () => {
  assert.equal(ChizukBag.suivant([], ['a'], 'a', identite).id, 'a');
  assert.deepEqual(ChizukBag.suivant(['a'], [], null, identite), { id: null, reste: [] });
  const t = ChizukBag.suivant(['z', 'b'], vivier, null, identite);
  assert.equal(t.id, 'b');
  assert.ok(!t.reste.includes('z'));
});
test('chaque moment tire dans son propre vivier, et n’a que des textes relus', () => {
  for (const moment of MOMENTS) {
    const items = ChizukRules.pourMoment(chizuk, moment);
    assert.ok(items.length > 0, `${moment} : aucun texte`);
    for (const it of items) {
      assert.ok(moment === 'demande' || it.moments.includes(moment));
      assert.equal(it.statut_verif, 'verifie_texte');
      assert.equal(it.relu, true);
    }
  }
});

test('l’hébreu affiché est he, sans nikkoud pour les éditions sans licence de vocalisation', () => {
  const vocalisation = /[\u0591-\u05BD\u05BF-\u05C2\u05C4-\u05C7]/;
  let sansLicence = 0;
  for (const it of chizuk.items) {
    const he = ChizukRules.hebreu(chizuk, it);
    assert.equal(he, it.he);
    assert.ok(!('he_sans_nikkoud' in it), it.id);
    if (!(chizuk._meta.editions[it.edition]?.nikkoud_ok ?? false)) {
      sansLicence += 1;
      assert.ok(!vocalisation.test(he), `${it.id} : vocalisation livrée`);
    }
  }
  assert.ok(sansLicence > 0, 'aucun texte sans licence de vocalisation : le test ne prouve rien');
});

test('la traduction suit la règle des langues', () => {
  const it = chizuk.items[0];
  assert.equal(ChizukRules.traduction(it, 'he'), '');
  assert.equal(ChizukRules.traduction(it, 'iw'), '');
  assert.equal(ChizukRules.traduction(it, 'en'), it.en);
  assert.equal(ChizukRules.traduction(it, 'fr'), it.fr);
});

// --- La séance dans le stockage --------------------------------------------------------
function horloge(iso) {
  let t = new Date(iso).getTime();
  return { maintenant: () => new Date(t), avance: (ms) => { t += ms; } };
}

test('une séance minutée inscrit sa durée, même relue longtemps après son terme', () => {
  const h = horloge('2026-09-29T09:00:00');
  const s = creeStore(memoire(), { maintenant: h.maintenant, fuseau: 'Europe/Paris' });
  s.beginSession(20);
  assert.equal(s.isSessionRunning(), true);
  h.avance(3 * 3600 * 1000); // le téléphone a dormi trois heures
  assert.equal(s.isSessionRunning(), false);
  assert.equal(s.isSessionOver(), true);
  assert.equal(s.endSession().minutes, 20);
  assert.equal(s.isSessionOver(), false);
});

test('terminer avant le terme inscrit le temps réellement passé', () => {
  const h = horloge('2026-09-29T09:00:00');
  const s = creeStore(memoire(), { maintenant: h.maintenant, fuseau: 'Europe/Paris' });
  s.beginSession(60);
  h.avance(12 * minute + 30000);
  assert.equal(s.endSession({ avantTerme: true }).minutes, 12);
});

test('une séance ouverte court jusqu’à ce qu’on la close', () => {
  const h = horloge('2026-09-29T09:00:00');
  const s = creeStore(memoire(), { maintenant: h.maintenant, fuseau: 'Europe/Paris' });
  s.beginSession(0);
  h.avance(5 * 3600 * 1000);
  assert.equal(s.isSessionRunning(), true);
  assert.equal(s.isSessionOpen(), true);
  assert.equal(s.sessionCounter(), 'ecoule');
  assert.equal(s.endSession({ avantTerme: true }).minutes, 240);
});

test('les séances d’un jour s’additionnent, sujets compris, et le bravo attend une fois', () => {
  const h = horloge('2026-09-29T09:00:00');
  const s = creeStore(memoire(), { maintenant: h.maintenant, fuseau: 'Europe/Paris' });
  s.addSession(10, { theme: 'gratitude' });
  s.addSession(5);
  assert.deepEqual(s.record(), { date: '2026-09-29', minutes: 15, note: '', themes: ['gratitude'], noteSeule: false, faite: true });
  s.setPendingCelebration(15);
  assert.equal(s.takePendingCelebration(), 15);
  assert.equal(s.takePendingCelebration(), null);
});

test('le sac de ’hizouk survit d’un tirage à l’autre', () => {
  const s = creeStore(memoire(), { fuseau: 'Europe/Paris' });
  const vus = new Set();
  const n = ChizukRules.pourMoment(chizuk, 'ouverture').length;
  for (let i = 0; i < n; i++) vus.add(ChizukBag.tirer(s, chizuk, 'ouverture').id);
  assert.equal(vus.size, n, 'un texte est revenu avant la fin du cycle');
});

test('Ta’hanoun en fin de Tichri : toujours en Edot, au choix en Sfard, jamais en Ashkenaz', () => {
  const s = creeStore(memoire());
  assert.equal(s.sansTahanounFinTichri(), true); // Edot par défaut
  s.setSiddurNusah('sefard');
  assert.equal(s.sansTahanounFinTichri(), false);
  s.setSansTahanounFinTichriSfard(true);
  assert.equal(s.sansTahanounFinTichri(), true);
  s.setSiddurNusah('ashkenaz');
  assert.equal(s.sansTahanounFinTichri(), false);
});

test('à la demande : tout le publiable, et le partage garde la source (19/10)', () => {
  const publiables = chizuk.items.filter(ChizukRules.publiable).map((x) => x.id);
  assert.deepEqual(ChizukRules.pourMoment(chizuk, 'demande').map((x) => x.id), publiables);
  assert.equal(ChizukRules.partage('עִקַּר', '', 'Likoutei Moharan II, 25', 'https://x'), 'עִקַּר\n\n— Likoutei Moharan II, 25\n\nhttps://x');
});

test('les ambiances calculées : audibles, douces, jamais saturées, le silence se tait (19/10)', async () => {
  const { AMBIANCES, generer } = await import('../src/js/ambiance.js');
  for (const a of AMBIANCES) {
    const s = generer(a, 8000, 24);
    let crete = 0; let r = 0;
    for (const x of s) { crete = Math.max(crete, Math.abs(x)); r += x * x; }
    if (a === 'silence') assert.equal(crete, 0);
    else { assert.ok(Math.sqrt(r / s.length) > 0.02, a); assert.ok(crete <= 0.61, a); assert.equal(Math.abs(s[0]), 0, a); }
  }
  assert.deepEqual(generer('mer', 8000, 2), generer('mer', 8000, 2));
});

// La note après le bravo (audit FWEBLIVE-02) et la légende du décompte masqué (FWEBCODE-02) :
// app.js ne s'importe pas hors du navigateur, on lit donc le source.
const appSource = readFileSync(join(ICI, '..', 'src', 'js', 'app.js'), 'utf8');

test('toute séance inscrite propose la note après le bravo, comme sur Android', () => {
  const clore = appSource.slice(appSource.indexOf('function cloreSeance'), appSource.indexOf('function terminerMaintenant'));
  assert.match(clore, /if \(inscrite\) \{[\s\S]*?dateNote = date;[\s\S]*?noteApresBravo = true;/s);
  const hors = appSource.slice(appSource.indexOf('function declarerHorsTelephone'), appSource.indexOf('function ajoutTemps'));
  assert.match(hors, /if \(date === aujourdhui\) \{[^}]*dateNote = date;[^}]*noteApresBravo = true;/s);
});

test('la fin de séance se lit dans le stockage, les feuilles périmées se ferment (FWEBCODE-10, FWEBCODE-11)', () => {
  // Une page rechargée pendant la séance n'a plus le drapeau en mémoire : le tic lit le stockage.
  const tic = appSource.slice(appSource.indexOf('function demarreTic'), appSource.indexOf('function arreteTic'));
  assert.match(tic, /if \(store\.isSessionOver\(\)\) \{\s*cloreSeance\(\{ avantTerme: false \}\);/);
  assert.doesNotMatch(tic, /etaitEnCours/);
  const clore = appSource.slice(appSource.indexOf('function cloreSeance'), appSource.indexOf('function terminerMaintenant'));
  assert.match(clore, /^function cloreSeance\(\{ avantTerme \}\) \{\s*fermeLesFeuilles\(\);/);
  // « Abandonner ? » confirmé après le terme : la séance est déjà inscrite, le bravo reste.
  for (const nom of ['function terminerMaintenant', 'function annulerSeance']) {
    const i = appSource.indexOf(nom);
    assert.match(appSource.slice(i, appSource.indexOf('\n}\n', i)), /if \(store\.sessionStartedAt\(\) === 0\) \{ rendre\(\); return; \}/, nom);
  }
  assert.match(appSource, /addEventListener\('popstate', \(\) => \{\s*fermeLesFeuilles\(\);/);
  // Le retour ferme les feuilles : la note du bravo n'est ouverte qu'après lui.
  const bravo = appSource.slice(appSource.indexOf('function ecranBravo'), appSource.indexOf('// Un jour la danse'));
  assert.match(bravo, /if \(note && parHistorique\) addEventListener\('popstate', note, \{ once: true \}\);\s*retour\(\);/);
});

test('lecture en échec, page rechargée, langue changée : rien ne reste dans l’état d’avant (FWEBLIVE-06, FWEBCODE-11, FWEBCODE-15)', () => {
  // La fin d'un aperçu relance la musique de la séance après l'écouteur aléatoire, pas avant (FWEBCODE-14).
  const fin = appSource.slice(appSource.indexOf("lecteur.addEventListener('ended', () => {\n  const apercu"), appSource.indexOf("lecteur.addEventListener('pause'"));
  assert.match(fin, /setTimeout\(\(\) => \{ if \(store\.isSessionRunning\(\) && enEcoute === null\) demarreMusique\(\); \}, 0\)/);
  const echec = appSource.slice(appSource.indexOf('function echecLecture'), appSource.indexOf('function metadonnees'));
  assert.match(echec, /lecteur\.pause\(\);\s*lecteur\.removeAttribute\('src'\);\s*lecteur\.load\(\);\s*majMini\(\);/);
  const demarrer = appSource.slice(appSource.indexOf('async function demarrer'), appSource.indexOf('// Le premier lancement'));
  assert.match(demarrer, /rendre\(\);[\s\S]*if \(store\.isSessionRunning\(\)\) gardeEcranAllume\(\);/);
  const reglages = appSource.slice(appSource.indexOf('function ecranReglages'), appSource.indexOf("tr.t('reglage_lieu'), etat"));
  assert.match(reglages, /mini\?\.remove\(\); mini = null;/);
  // La région reste celle des réglages : troisième argument null.
  assert.match(reglages, /store\.setLieu\(\{ \.\.\.lieu, nom: titreTexte\(ville\.nom\) \}, ville, null\);/);
});

test('le site ne promet pas un son de fin qu’il ne joue pas', () => {
  assert.doesNotMatch(appSource, /tr\.t\('session_hidden_caption'\)/);
  assert.match(appSource, /tr\.t\('session_hidden_caption_web'\)/);
});

// « Terminer » appelait SessionRule sans l'importer : ReferenceError au toucher, la séance
// ne se terminait plus depuis le site (relecture du lot « séance », FSEANCE-12).
test('app.js importe chaque objet de règles qu’il appelle', () => {
  const dossier = join(ICI, '..', 'src', 'js');
  const importes = new Set();
  for (const m of appSource.matchAll(/^import\s*\{([^}]*)\}\s*from/gm)) {
    for (const nom of m[1].split(',')) {
      const t = nom.trim().split(/\s+as\s+/).pop();
      if (t) importes.add(t);
    }
  }
  for (const m of appSource.matchAll(/^import\s+\*\s+as\s+(\w+)/gm)) importes.add(m[1]);
  const declares = new Set([...appSource.matchAll(/^\s*(?:const|let|var|function|class)\s+([A-Z]\w*)/gm)].map((m) => m[1]));
  const manquants = [];
  for (const fichier of readdirSync(dossier).filter((f) => f.endsWith('.js') && f !== 'app.js')) {
    const source = readFileSync(join(dossier, fichier), 'utf8');
    for (const m of source.matchAll(/^export\s+(?:const|class|function)\s+([A-Z]\w*)/gm)) {
      const nom = m[1];
      if (importes.has(nom) || declares.has(nom)) continue;
      if (new RegExp(`(?<![.\\w$'"\`])${nom}\\.\\w`).test(appSource)) manquants.push(`${nom} (${fichier})`);
    }
  }
  assert.deepEqual(manquants, []);
});
