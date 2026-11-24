// Le ciel du Jour (CielDuJourTest.kt, 14/11) : les mêmes cas, et les mêmes couleurs qu'Android.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as Ciel from '../src/js/ciel.js';

const ICI = dirname(fileURLToPath(import.meta.url));
const ANDROID = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'java', 'com', 'myhitbodedut');

// Un jour de novembre à Jérusalem (UTC+2), en chiffres ronds.
const a = (h, m) => new Date(Date.UTC(2026, 10, 12, h - 2, m));
const z = { alot: a(5, 0), netz: a(6, 20), chkia: a(16, 40), tset: a(17, 5) };
const phase = (h, m) => Ciel.phase(a(h, m), z);

test('les zmanim bornent les quatre ciels', () => {
  assert.equal(phase(4, 59), 'nuit');
  assert.equal(phase(5, 0), 'aube');
  assert.equal(phase(7, 19), 'aube');
  assert.equal(phase(7, 20), 'jour');
  assert.equal(phase(15, 39), 'jour');
  assert.equal(phase(15, 40), 'coucher');
  assert.equal(phase(17, 4), 'coucher');
  assert.equal(phase(17, 5), 'nuit');
  assert.equal(phase(23, 59), 'nuit');
});

test('un jour trop court passe de l’aube au coucher', () => {
  const court = { alot: a(8, 0), netz: a(9, 0), chkia: a(10, 30), tset: a(11, 30) };
  assert.equal(Ciel.phase(a(9, 59), court), 'aube');
  assert.equal(Ciel.phase(a(10, 0), court), 'coucher');
  assert.equal(Ciel.phase(a(11, 30), court), 'nuit');
});

test('sans zman, l’heure du lieu décide', () => {
  assert.equal(Ciel.phase(a(12, 0), { ...z, alot: null }, { heures: 12, minutes: 0 }), 'jour');
  assert.equal(Ciel.phase(a(22, 0), { ...z, tset: null }, { heures: 22, minutes: 0 }), 'nuit');
  for (const [h, m, attendu] of [[4, 59, 'nuit'], [5, 0, 'aube'], [7, 59, 'aube'], [8, 0, 'jour'], [16, 59, 'jour'],
    [17, 0, 'coucher'], [19, 59, 'coucher'], [20, 0, 'nuit']]) {
    assert.equal(Ciel.parHeure(h, m), attendu, `${h}:${m}`);
  }
});

test('les couleurs du ciel sont celles d’Android', () => {
  const kt = readFileSync(join(ANDROID, 'CielDuJour.kt'), 'utf8');
  const champs = ['haut', 'milieu', 'horizon', 'colline', 'astre', 'lueur', 'voile'];
  for (const p of Ciel.PHASES) {
    const debut = kt.indexOf(`Phase.${p.toUpperCase()} to Palette(`);
    assert.ok(debut >= 0, `${p} absent de CielDuJour.kt`);
    // Le bloc de cette palette : jusqu'à la suivante, ou à la fin de la table.
    const bloc = kt.slice(debut).split(/\n\s*Phase\.|\n\s*\)/)[0];
    const android = [...bloc.matchAll(/0xFF([0-9A-F]{6})/g)].map((x) => `#${x[1]}`);
    assert.deepEqual(champs.map((c) => Ciel.PALETTES[p][c]), android, p);
  }
});

// --- Le ciel sur toute la page du Jour (24/11 : TeintesCiel.kt, CielPage.kt, CielVivant.kt) ---

const RES = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res');
const kotlin = (nom) => readFileSync(join(ANDROID, `${nom}.kt`), 'utf8');
const nombres = (texte) => [...texte.matchAll(/-?\d+(?:\.\d+)?/g)].map((x) => Number(x[0]));

test('les teintes, le plan et les mouvements sont ceux d’Android', () => {
  const teintes = kotlin('TeintesCiel');
  for (const p of Ciel.PHASES) {
    const ligne = teintes.match(new RegExp(`Phase\\.${p.toUpperCase()} to floatArrayOf\\(([^)]*)\\)`));
    assert.ok(ligne, `PART_SOMBRE ${p}`);
    assert.deepEqual(nombres(ligne[1]), Ciel.PART_SOMBRE[p], p);
  }
  assert.deepEqual(nombres(teintes.match(/ECART_CLAIR = floatArrayOf\(([^)]*)\)/)[1]), Ciel.ECART_CLAIR);
  assert.ok(teintes.includes(`const val MARGE = ${Ciel.MARGE}`) && teintes.includes(`const val MILIEU = ${Ciel.MILIEU}f`));
  const vivant = kotlin('CielVivant');
  for (const [cle, nom] of [['scintillementMin', 'SCINTILLEMENT_MIN_S'], ['scintillementMax', 'SCINTILLEMENT_MAX_S'], ['scintillementBas', 'SCINTILLEMENT_BAS'],
    ['deriveX', 'DERIVE_X_DP'], ['deriveXS', 'DERIVE_X_S'], ['deriveY', 'DERIVE_Y_DP'], ['deriveYS', 'DERIVE_Y_S'], ['souffleS', 'SOUFFLE_S'],
    ['souffleTaille', 'SOUFFLE_TAILLE'], ['souffleEclat', 'SOUFFLE_ECLAT'], ['nuageVitesse', 'NUAGE_DP_S'], ['voileVitesse', 'VOILE_DP_S']]) {
    const m = vivant.match(new RegExp(`const val ${nom} = (-?[\\d.]+)f?`));
    assert.ok(m, nom);
    assert.equal(Number(m[1]), Ciel.VIVANT[cle], nom);
  }
  const page = kotlin('CielPage');
  for (const p of Ciel.PHASES) assert.ok(page.includes(`CielDuJour.Phase.${p.toUpperCase()} -> ${Ciel.RAYON[p]}f`), `rayon ${p}`);
  assert.ok(page.includes(`const val COURONNE = ${Ciel.COURONNE}f`) && page.includes(`const val LUEUR = ${Ciel.LUEUR}f`));
  assert.deepEqual(nombres(page.match(/val NUAGES = floatArrayOf\(([^)]*)\)/)[1]), Ciel.NUAGES.flat());
  assert.deepEqual(nombres(page.match(/val VOILES = floatArrayOf\(([^)]*)\)/)[1]), Ciel.VOILES.flat());
  assert.ok(page.includes(`const val NUAGE_L = ${Ciel.TAILLE_NUAGE[0]}f`) && page.includes(`const val VOILE_H = ${Ciel.TAILLE_VOILE[1]}f`));
});

test('les mêmes étoiles qu’Android (java.util.Random, graine 29)', () => {
  // new java.util.Random(29).nextFloat(), cinq fois.
  const [x, y, rayon, cycle, decalage] = Ciel.etoiles(1, 29, 0.7, 1.7)[0];
  assert.ok(Math.abs(x - 0.7312365) < 1e-6 && Math.abs(y - 0.024344325) < 1e-6 && Math.abs(decalage - 0.9265251) < 1e-6);
  assert.ok(Math.abs(rayon - (0.7 + 0.7319032)) < 1e-6 && Math.abs(cycle - (8 + 0.20306146 * 8)) < 1e-5);
});

/** Toutes les palettes d'Android, de jour et de nuit : le papier et les encres du Jour. */
function combinaisons() {
  const couleurs = (d) => Object.fromEntries([...readFileSync(join(RES, d, 'colors.xml'), 'utf8').matchAll(/<color name="([a-z0-9_]+)">(#[0-9A-Fa-f]{6,8})<\/color>/g)].map((m) => [m[1], m[2]]));
  const styles = (d) => Object.fromEntries([...readFileSync(join(RES, d, 'palettes.xml'), 'utf8').matchAll(/<style name="([A-Za-z.]+)"[^>]*>([\s\S]*?)<\/style>/g)]
    .map((m) => [m[1], Object.fromEntries([...m[2].matchAll(/<item name="([A-Za-z:]+)">([^<]+)<\/item>/g)].map((i) => [i[1], i[2]]))]));
  const tout = [];
  for (const sombre of [false, true]) {
    const c = sombre ? { ...couleurs('values'), ...couleurs('values-night') } : couleurs('values');
    const st = styles(sombre ? 'values-night' : 'values');
    const fonds = { 'Fond.Vert': { mhPaper: c.paper, mhInk: c.ink, mhMuted: c.muted }, ...Object.fromEntries(Object.entries(st).filter(([n]) => n.startsWith('Fond.'))) };
    const accents = { 'Accent.Vert': c.brand, ...Object.fromEntries(Object.entries(st).filter(([n]) => n.startsWith('Accent.')).map(([n, v]) => [n, v.mhBrand])) };
    for (const [fn, f] of Object.entries(fonds)) {
      for (const [an, brand] of Object.entries(accents)) {
        const papier = f.mhPaper;
        // Les légendes des anneaux, en ring_week_text et ring_streak_text comme sur Android.
        const encres = [[f.mhInk, 7], [f.mhMuted, 4.5], [brand, 4.5], [c.ring_week_text, 4.5], [c.ring_streak_text, 4.5]]
          .map(([couleur, seuil]) => ({ couleur: Ciel.rgb(couleur), seuil: Math.min(seuil, Ciel.contraste(couleur, papier)) }));
        tout.push({ nom: `${fn} × ${an} ${sombre ? 'sombre' : 'clair'}`, sombre, papier, encres });
      }
    }
  }
  return tout;
}

test('chaque texte reste lisible sur le ciel, lueur et nuages compris', () => {
  const fautes = [];
  const tout = combinaisons();
  assert.ok(tout.length >= 72);
  for (const k of tout) {
    for (const p of Ciel.PHASES) {
      const t = Ciel.teintesPage(p, k.sombre, k.encres, k.papier);
      for (let i = 0; i <= 200; i++) {
        const fond = Ciel.degrade(t, i / 160);
        const sousLueur = Ciel.melange(fond, t.lueur, t.lueurAlpha);
        for (const c of [fond, sousLueur, Ciel.melange(fond, t.nuage, t.nuageAlpha), Ciel.melange(sousLueur, t.nuage, t.nuageAlpha)]) {
          for (const e of k.encres) if (Ciel.contraste(e.couleur, c) < e.seuil) fautes.push(`${k.nom} ${p} : ${Ciel.hex(e.couleur)} sur ${Ciel.hex(c)}`);
        }
      }
    }
  }
  assert.deepEqual([...new Set(fautes)].slice(0, 20), []);
});

test('l’astre à côté des anneaux, aucune étoile sous un texte', () => {
  const jauge = { gauche: 75.5, haut: 180, droite: 335.5, bas: 440 };
  const textes = [{ gauche: 24, haut: 8, droite: 200, bas: 56 }, { gauche: 24, haut: 64, droite: 387, bas: 160 }, { gauche: 24, haut: 444, droite: 387, bas: 520 }];
  for (const p of Ciel.PHASES) {
    const a = Ciel.placeAstre(p, jauge, 411, textes);
    assert.ok(a, p);
    assert.equal(a[0] < jauge.gauche, p === 'aube', p);
  }
  assert.equal(Ciel.placeAstre('jour', { gauche: 16, haut: 4, droite: 252, bas: 240 }, 820, [{ gauche: 268, haut: 4, droite: 800, bas: 400 }]), null);
  const liste = Ciel.etoiles(60, 29, 0.7, 1.7);
  const libres = Ciel.etoilesLibres(liste, 411, 546, [...textes, jauge]);
  assert.ok(libres.filter(Boolean).length >= 15);
  liste.forEach(([x, y], i) => {
    if (libres[i]) assert.ok(![...textes, jauge].some((z) => x * 411 > z.gauche - 9 && x * 411 < z.droite + 9 && y * 546 > z.haut - 9 && y * 546 < z.bas + 9), `étoile ${i}`);
  });
});

test('le ciel vivant ne bouge que si le système le permet', () => {
  const css = readFileSync(join(ICI, '..', 'src', 'app.css'), 'utf8');
  const bloc = css.slice(css.indexOf('@media (prefers-reduced-motion: no-preference) {\n  .ciel-etoile'));
  const fin = bloc.indexOf('\n}\n');
  const anime = bloc.slice(0, fin);
  for (const n of ['ciel-scintille', 'ciel-derive-x', 'ciel-derive-y', 'ciel-souffle', 'ciel-nuage']) {
    assert.ok(anime.includes(n), `${n} hors de prefers-reduced-motion: no-preference`);
    // Nulle part ailleurs une animation ne lance ces mouvements.
    assert.equal(css.split(`animation: ${n}`).length - 1, 1, n);
  }
  // La plaque du hassid ne porte plus de ciel.
  const app = readFileSync(join(ICI, '..', 'src', 'js', 'app.js'), 'utf8');
  assert.ok(!app.includes('fenetreCiel') && app.includes('function poserCiel()'));
});
