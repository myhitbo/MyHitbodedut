// Le ciel du Jour (CielDuJour.kt ; étape 3 de la refonte, 14/11) : l'aube, le plein jour, le
// coucher ou la nuit, d'après les zmanim du lieu, sinon d'après l'heure. Depuis le 24/11, il
// couvre toute la page du Jour (TeintesCiel.kt, CielPage.kt) et bouge un peu (CielVivant.kt).
//
// L'aube va d'alot hacha'har à une heure après le lever ; le coucher, d'une heure avant la
// chkia à tsét hakokhavim ; la nuit, de tsét à alot. Un zman qui manque (nuit ou jour polaire)
// renvoie aux heures fixes. Les couleurs, les mesures et les mouvements sont ceux d'Android
// (le test les compare aux fichiers Kotlin).

export const PHASES = Object.freeze(['aube', 'jour', 'coucher', 'nuit']);

/** Ce que l'aube garde après le lever, et ce que le coucher prend avant la chkia. */
export const MARGE_MS = 60 * 60 * 1000;

/** Sans lieu : un matin et un soir moyens. */
export function parHeure(heures, minutes = 0) {
  const t = heures * 60 + minutes;
  if (t < 5 * 60) return 'nuit';
  if (t < 8 * 60) return 'aube';
  if (t < 17 * 60) return 'jour';
  if (t < 20 * 60) return 'coucher';
  return 'nuit';
}

/**
 * Avec les zmanim du jour (des Date, ou null) ; un zman qui manque renvoie à l'heure
 * [locale] ({ heures, minutes }), celle du lieu. Un jour trop court pour un plein jour passe
 * de l'aube au coucher.
 */
export function phase(maintenant, { alot, netz, chkia, tset } = {}, locale = { heures: maintenant.getHours(), minutes: maintenant.getMinutes() }) {
  if (!alot || !netz || !chkia || !tset) return parHeure(locale.heures, locale.minutes);
  const t = maintenant.getTime();
  if (t < alot.getTime()) return 'nuit';
  if (t < netz.getTime() + MARGE_MS) return 'aube';
  if (t < chkia.getTime() - MARGE_MS) return 'jour';
  if (t < tset.getTime()) return 'coucher';
  return 'nuit';
}

/** Le dégradé (haut, milieu, horizon), la colline, l'astre, sa lueur, et le voile du haut de l'écran. */
export const PALETTES = Object.freeze({
  aube: { haut: '#7B88C9', milieu: '#E3A3BE', horizon: '#FFD6AE', colline: '#7E9F86', astre: '#FFE7B8', lueur: '#FFE0A8', voile: '#E8A0B4' },
  jour: { haut: '#5FB1EA', milieu: '#A8DAF6', horizon: '#E6F6FC', colline: '#7CC293', astre: '#FFE97A', lueur: '#FFF6C8', voile: '#6FB8EA' },
  coucher: { haut: '#8A64B0', milieu: '#E58397', horizon: '#FDBA6E', colline: '#6C5A80', astre: '#FFC46A', lueur: '#FFAA5A', voile: '#F08A5D' },
  nuit: { haut: '#101B3D', milieu: '#1F2F63', horizon: '#33477F', colline: '#1D2A4C', astre: '#F6F0D6', lueur: '#F6F0D6', voile: '#2C3E7A' },
});

// --- Les teintes du ciel en fond du Jour (TeintesCiel.kt, 24/11) ------------------------------
//
// Le ciel de CielDuJour, assombri en thème sombre et pâli en thème clair, teinte gardée, juste
// assez pour que chaque texte de la page garde son contraste. La lueur et les nuages ont une
// opacité bornée par le même calcul ; étoiles, astre et couronne ne tombent jamais sous un texte.

/** L'arrêt du milieu du dégradé, et la réserve gardée au-dessus de chaque seuil. */
export const MILIEU = 0.55;
export const MARGE = 0.05;
/** Thème sombre : la luminance de chaque arrêt (haut, milieu, bas), en part de la plus haute permise. */
export const PART_SOMBRE = Object.freeze({ aube: [0.38, 0.48, 0.56], jour: [0.38, 0.44, 0.52], coucher: [0.36, 0.48, 0.56], nuit: [0.25, 0.40, 0.55] });
/** Thème clair : la luminance de chaque arrêt, au-dessus de la plus basse permise. */
export const ECART_CLAIR = Object.freeze([0.012, 0.03, 0.05]);
const ECHANTILLONS = 48;
const ASTRE_CLAIR = 0.55;

const LINEAIRE = Array.from({ length: 256 }, (_, v) => { const c = v / 255; return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4; });

/** '#RRGGBB' → [r, g, b]. */
export function rgb(hex) { const h = hex.replace('#', '').slice(-6); return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)); }
export function hex([r, g, b]) { return `#${[r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('').toUpperCase()}`; }
export function luminance(c) { const [r, g, b] = typeof c === 'string' ? rgb(c) : c; return 0.2126 * LINEAIRE[r] + 0.7152 * LINEAIRE[g] + 0.0722 * LINEAIRE[b]; }
export function contraste(a, b) { const x = luminance(a), y = luminance(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
/** [a] recouvert de [b] à l'opacité [t], canal par canal (arrondi comme Kotlin roundToInt). */
export function melange(a, b, t) { const x = typeof a === 'string' ? rgb(a) : a, y = typeof b === 'string' ? rgb(b) : b; return x.map((v, i) => Math.min(255, Math.max(0, Math.round(v + (y[i] - v) * t)))); }

function hsl([r8, g8, b8]) {
  const r = r8 / 255, g = g8 / 255, b = b8 / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b), l = (max + min) / 2;
  if (max === min) return [0, 0, l];
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  const h = max === r ? ((g - b) / d + (g < b ? 6 : 0)) / 6 : max === g ? ((b - r) / d + 2) / 6 : ((r - g) / d + 4) / 6;
  return [h, s, l];
}
function deHsl(h, s, l) {
  const c = (1 - Math.abs(2 * l - 1)) * s, hp = (h * 6) % 6, x = c * (1 - Math.abs((hp % 2) - 1));
  const [r, g, b] = hp < 1 ? [c, x, 0] : hp < 2 ? [x, c, 0] : hp < 3 ? [0, c, x] : hp < 4 ? [0, x, c] : hp < 5 ? [x, 0, c] : [c, 0, x];
  const m = l - c / 2;
  return [r, g, b].map((t) => Math.min(255, Math.max(0, Math.round((t + m) * 255))));
}
/** [c] amenée à la luminance [cible] en ne changeant que sa clarté ; du bon côté de la cible. */
export function aLuminance(c, cible) {
  const [h, s] = hsl(c);
  const assombrir = luminance(c) > cible;
  let bas = 0, haut = 1;
  for (let i = 0; i < 40; i++) { const m = (bas + haut) / 2; if (luminance(deHsl(h, s, m)) < cible) bas = m; else haut = m; }
  let l = assombrir ? bas : haut, r = deHsl(h, s, l);
  for (let g = 0; g < 64 && (assombrir ? luminance(r) > cible : luminance(r) < cible); g++) { l += assombrir ? -0.002 : 0.002; r = deHsl(h, s, Math.min(1, Math.max(0, l))); }
  return r;
}

/** Les encres ([{ couleur, seuil }]) gardent leur seuil, plus la marge. */
export function lisible(fond, encres) { return encres.every((e) => contraste(e.couleur, fond) >= e.seuil + MARGE); }
export function borne(encres, sombre) {
  return sombre ? Math.min(...encres.map((e) => (luminance(e.couleur) + 0.05) / e.seuil - 0.05))
    : Math.max(...encres.map((e) => e.seuil * (luminance(e.couleur) + 0.05) - 0.05));
}
/** La plus forte opacité (au plus [plafond]) pour laquelle [tient] ; 0 si même un voile ténu est de trop. */
export function opaciteMax(plafond, tient) {
  if (tient(plafond)) return plafond;
  if (!tient(0)) return 0;
  let bas = 0, haut = plafond;
  for (let i = 0; i < 24; i++) { const m = (bas + haut) / 2; if (tient(m)) bas = m; else haut = m; }
  return bas;
}

/** La couleur du dégradé à la hauteur [u] (0 en haut, 1 en bas de l'écran et au-delà). */
export function degrade(t, u) {
  if (u <= 0) return t.haut;
  if (u < MILIEU) return melange(t.haut, t.milieu, u / MILIEU);
  if (u < 1) return melange(t.milieu, t.bas, (u - MILIEU) / (1 - MILIEU));
  return t.bas;
}

function arrets(phase, sombre, b, reserve) {
  const p = PALETTES[phase];
  return [p.haut, p.milieu, p.horizon].map((depart, i) => {
    let c = rgb(depart);
    if (sombre) {
      const cible = b * PART_SOMBRE[phase][i] * 0.9 ** reserve;
      if (luminance(c) > cible) {
        if (i > 0 && (phase === 'aube' || phase === 'coucher')) {
          c = melange(c, p.haut, 0.45);
          const [h, s, l] = hsl(c);
          c = deHsl(h, Math.min(s, 0.55), l);
        }
        c = aLuminance(c, cible);
      }
    } else {
      const cible = b + ECART_CLAIR[i] + 0.01 * reserve;
      if (luminance(c) < cible) c = aLuminance(c, Math.min(cible, 1));
    }
    return c;
  });
}

/**
 * Le ciel de [phase] sous des encres ([{ couleur, seuil }], claires si [sombre]) ; le papier si
 * aucune teinte ne les laisse lisibles. Les couleurs sont des [r, g, b].
 */
export function teintesPage(phase, sombre, encres, papier) {
  const p = PALETTES[phase];
  const b = borne(encres, sombre);
  const lisibles = ([haut, milieu, bas]) => Array.from({ length: ECHANTILLONS + 1 }, (_, i) => degrade({ haut, milieu, bas }, i / ECHANTILLONS)).every((c) => lisible(c, encres));
  let reserve = 0;
  let a = arrets(phase, sombre, b, 0);
  while (!lisibles(a) && reserve < 12) a = arrets(phase, sombre, b, ++reserve);
  if (!lisibles(a)) a = [rgb(papier), rgb(papier), rgb(papier)];
  const t = { haut: a[0], milieu: a[1], bas: a[2] };
  const echantillons = Array.from({ length: ECHANTILLONS + 1 }, (_, i) => degrade(t, i / ECHANTILLONS));
  // Les nuages d'abord, sur tout le dégradé ; la lueur large prend ce qui reste, nuage par-dessus compris.
  const nuage = phase === 'jour' ? [255, 255, 255] : [255, 248, 240];
  const nuageAlpha = phase === 'nuit' ? 0 : opaciteMax(sombre ? 0.5 : 0.75, (a) => echantillons.every((e) => lisible(melange(e, nuage, a), encres)));
  let lueur = rgb(p.lueur);
  if (!sombre && luminance(lueur) < b + 0.06) lueur = aLuminance(lueur, b + 0.06);
  const lueurAlpha = opaciteMax(sombre ? 0.9 : 0.85, (a) => echantillons.every((e) => {
    const sous = melange(e, lueur, a);
    return lisible(sous, encres) && lisible(melange(sous, nuage, nuageAlpha), encres);
  }));
  const astre = !sombre && luminance(p.astre) > ASTRE_CLAIR ? aLuminance(rgb(p.astre), ASTRE_CLAIR) : rgb(p.astre);
  return { ...t, lueur, lueurAlpha, couronne: rgb(p.lueur), astre, nuage, nuageAlpha,
    etoile: sombre ? [255, 246, 236] : [120, 132, 196], etoileAlpha: sombre ? 0.9 : 0.8 };
}

// --- Le plan et les mouvements (CielPage.kt, PlanCiel ; CielVivant.kt) -------------------------

/** Les mouvements, en secondes et en px CSS (= dp) : les mêmes qu'Android. */
export const VIVANT = Object.freeze({
  scintillementMin: 8, scintillementMax: 16, scintillementBas: 0.45,
  deriveX: 3, deriveXS: 40, deriveY: 1.5, deriveYS: 31,
  souffleS: 12, souffleTaille: 0.06, souffleEclat: 0.18,
  nuageVitesse: 3, voileVitesse: 2,
});
/** Le rayon du disque (px), et la couronne et la lueur en rayons du disque. */
export const RAYON = Object.freeze({ jour: 14, nuit: 12, aube: 16, coucher: 17 });
export const COURONNE = 2.2;
export const LUEUR = 4.2;
export const MARGE_ETOILE = 6;
/** Les nuages du jour et le voile de l'aube et du coucher : départ (part de la largeur), hauteur (part de l'écran), échelle. */
export const NUAGES = Object.freeze([[0.08, 0.10, 1], [0.58, 0.42, 0.8]]);
export const VOILES = Object.freeze([[0.30, 0.20, 1]]);
export const TAILLE_NUAGE = Object.freeze([128, 48]);
export const TAILLE_VOILE = Object.freeze([240, 30]);

/** java.util.Random : la même suite qu'Android pour la même graine, donc les mêmes étoiles. */
export function hasardJava(graine) {
  const MASQUE = (1n << 48n) - 1n;
  let s = (BigInt(graine) ^ 0x5DEECE66Dn) & MASQUE;
  return {
    nextFloat() {
      s = (s * 0x5DEECE66Dn + 0xBn) & MASQUE;
      return Number(s >> 24n) / (1 << 24);
    },
  };
}

/** Les étoiles (CielVivant.etoiles) : [x, y (fractions), rayon (px), cycle (s), décalage (tours)]. */
export function etoiles(nombre, graine, rayonMin, rayonMax) {
  const r = hasardJava(graine);
  return Array.from({ length: nombre }, () => {
    const x = r.nextFloat(), y = r.nextFloat(), rayon = rayonMin + r.nextFloat() * (rayonMax - rayonMin);
    const cycle = VIVANT.scintillementMin + r.nextFloat() * (VIVANT.scintillementMax - VIVANT.scintillementMin);
    return [x, y, rayon, cycle, r.nextFloat()];
  });
}

/** Combien d'étoiles, jusqu'où, à quel éclat (PlanCiel.etoiles). */
export function planEtoiles(phase, sombre, largeur, hauteur) {
  if (phase === 'nuit') return [Math.min(72, Math.max(24, Math.floor(largeur * hauteur / 4600))), 0.78, 1];
  if (sombre && (phase === 'aube' || phase === 'coucher')) return [12, 0.3, 0.55];
  return [0, 0, 0];
}

const touche = (z, cx, cy, r) => cx + r > z.gauche && cx - r < z.droite && cy + r > z.haut && cy - r < z.bas;

/** Le centre de l'astre à côté des anneaux, ou null (PlanCiel.astre). Zones : { gauche, haut, droite, bas }. */
export function placeAstre(phase, jauge, largeur, zones) {
  const r = RAYON[phase], couronne = r * COURONNE;
  const bas = phase === 'aube' || phase === 'coucher';
  const cy = jauge.haut + (jauge.bas - jauge.haut) * (bas ? 0.72 : 0.2);
  const droite = phase !== 'aube';
  for (const aDroite of [droite, !droite]) {
    const libre = aDroite ? largeur - jauge.droite : jauge.gauche;
    if (libre < 2 * r + 8) continue;
    const cx = aDroite ? (jauge.droite + largeur) / 2 : jauge.gauche / 2;
    if (!zones.some((z) => touche(z, cx, cy, couronne))) return [cx, cy];
  }
  return null;
}

/** Les étoiles qui se montrent : aucune près d'un texte, d'une icône ou des anneaux (PlanCiel.libres). */
export function etoilesLibres(liste, largeur, hauteur, zones) {
  const ecart = MARGE_ETOILE + Math.max(VIVANT.deriveX, VIVANT.deriveY);
  return liste.map(([x, y, r]) => !zones.some((z) => touche(z, x * largeur, y * hauteur, r * 1.6 + ecart)));
}
