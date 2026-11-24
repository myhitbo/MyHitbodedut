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

// --- Le ciel continu (CielContinu.kt, Soleil.kt ; 24/11) ---------------------------------------
//
// Plus quatre ciels fixes : un ciel qui suit la hauteur du vrai soleil au lieu choisi (sinon un
// soleil moyen d'après l'heure), et passe sans à-coup par la nuit noire, le bleu du crépuscule, le
// violet, les rouges et les jaunes du lever, l'heure dorée, le bleu du jour, l'orange et le violet
// du soir.

const rad = (d) => d * Math.PI / 180;
const deg = (r) => r * 180 / Math.PI;

/** Le soleil à l'instant [ms] (UTC) pour [latitude], [longitude] : formules de la NOAA (Soleil.kt). */
export function soleil(ms, latitude, longitude) {
  const jd = ms / 86400000 + 2440587.5, t = (jd - 2451545) / 36525;
  const l0 = ((280.46646 + t * (36000.76983 + 0.0003032 * t)) % 360 + 360) % 360;
  const m = 357.52911 + t * (35999.05029 - 0.0001537 * t);
  const e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
  const c = Math.sin(rad(m)) * (1.914602 - t * (0.004817 + 0.000014 * t)) + Math.sin(rad(2 * m)) * (0.019993 - 0.000101 * t) + Math.sin(rad(3 * m)) * 0.000289;
  const omega = 125.04 - 1934.136 * t;
  const lambda = l0 + c - 0.00569 - 0.00478 * Math.sin(rad(omega));
  const eps = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60 + 0.00256 * Math.cos(rad(omega));
  const declinaison = deg(Math.asin(Math.sin(rad(eps)) * Math.sin(rad(lambda))));
  const y = Math.tan(rad(eps / 2)) ** 2;
  const equation = 4 * deg(y * Math.sin(2 * rad(l0)) - 2 * e * Math.sin(rad(m)) + 4 * e * y * Math.sin(rad(m)) * Math.cos(2 * rad(l0))
    - 0.5 * y * y * Math.sin(4 * rad(l0)) - 1.25 * e * e * Math.sin(2 * rad(m)));
  const minutes = ((ms % 86400000) + 86400000) % 86400000 / 60000;
  let h = (minutes + equation + 4 * longitude) / 4 - 180;
  h = ((h + 180) % 360 + 360) % 360 - 180;
  const phi = rad(latitude), delta = rad(declinaison);
  const hauteur = 90 - deg(Math.acos(Math.min(1, Math.max(-1, Math.sin(phi) * Math.sin(delta) + Math.cos(phi) * Math.cos(delta) * Math.cos(rad(h))))));
  const cosLever = (Math.sin(rad(-0.833)) - Math.sin(phi) * Math.sin(delta)) / (Math.cos(phi) * Math.cos(delta));
  return positionSoleil(hauteur, h, cosLever >= 1 ? 0 : cosLever <= -1 ? 180 : deg(Math.acos(cosLever)));
}

/** Sans lieu : levé à 6 h 30, couché à 18 h 30, ±50° (Soleil.parHeure). [heure] décimale. */
export function soleilParHeure(heure) {
  const h = (((heure - 12.5) * 15 + 180) % 360 + 360) % 360 - 180;
  return positionSoleil(50 * Math.sin(Math.PI * (heure - 6.5) / 12), h, 90);
}

function positionSoleil(hauteur, angleHoraire, angleLever) {
  const nuit = 360 - 2 * angleLever, jour = Math.abs(angleHoraire) <= angleLever, matin = angleHoraire < 0;
  return {
    hauteur, angleHoraire, angleLever, matin,
    progresJour: angleLever <= 0 ? 0.5 : Math.min(1, Math.max(0, (angleHoraire + angleLever) / (2 * angleLever))),
    // De jour, la plus proche borne : 1 le matin (la nuit tout juste finie), 0 l'après-midi.
    progresNuit: nuit <= 0 ? 0.5 : jour ? (matin ? 1 : 0) : Math.min(1, Math.max(0, (((angleHoraire - angleLever) % 360 + 360) % 360) / nuit)),
  };
}

/** Les clés du matin et du soir : [hauteur, haut, milieu, horizon] (CielContinu.MATIN, SOIR). */
export const MATIN = Object.freeze([
  [-18, '#0A0E24', '#111839', '#1B2550'], [-12, '#121C44', '#22336C', '#3A4E8E'], [-6, '#222E69', '#56579A', '#B07898'],
  [-2, '#36408A', '#A86A92', '#F08870'], [0, '#4B5DA6', '#E2958A', '#FFAE76'], [3, '#5A80C4', '#EEC29C', '#FFDDA0'],
  [6, '#5994D6', '#B9D6EC', '#FBE5B6'], [12, '#5AA5E6', '#A4D5F4', '#E2F3FB'], [40, '#4E9BE2', '#96CDF2', '#DDF1FB'],
]);
export const SOIR = Object.freeze([
  [-18, '#0A0E22', '#101733', '#18224A'], [-12, '#131B46', '#23336C', '#3B4D8C'], [-6, '#2C2A6C', '#5B4891', '#A2698C'],
  [-3, '#463D8A', '#985C9C', '#DE7D78'], [0, '#675FA6', '#E6826E', '#FF8A50'], [2, '#6B7DC0', '#F0A472', '#FF9E5A'],
  [6, '#6395D2', '#E4D2B0', '#FFD79E'], [12, '#5AA5E6', '#A4D5F4', '#E2F3FB'], [40, '#4E9BE2', '#96CDF2', '#DDF1FB'],
]);
/** Les couleurs qui suivent la hauteur du soleil : [hauteur, couleur]. */
export const ASTRE = Object.freeze([[0, '#FF8C4E'], [3, '#FFB566'], [8, '#FFDB8A'], [20, '#FFF0B8'], [40, '#FFF6CE']]);
export const LUEUR = Object.freeze([[0, '#FF9A5C'], [3, '#FFBE7E'], [8, '#FFDFA0'], [20, '#FFF6C8']]);
export const NUAGE_CORPS = Object.freeze([[-12, '#5E6A8E'], [-6, '#6E6E9E'], [0, '#E8A9A0'], [4, '#F6D2B8'], [10, '#FFFFFF']]);
export const NUAGE_BORD = Object.freeze([[-12, '#7A86A8'], [-6, '#C88AA8'], [0, '#FFB070'], [4, '#FFD27A'], [10, '#FFF4DC']]);
export const LUNE = '#F6F0D6';

export function suite(liste, e) {
  if (e <= liste[0][0]) return rgb(liste[0][1]);
  if (e >= liste.at(-1)[0]) return rgb(liste.at(-1)[1]);
  const i = liste.findIndex(([h]) => h > e);
  return melange(liste[i - 1][1], liste[i][1], (e - liste[i - 1][0]) / (liste[i][0] - liste[i - 1][0]));
}
function selon(cles, e) {
  if (e <= cles[0][0]) return cles[0].slice(1).map(rgb);
  if (e >= cles.at(-1)[0]) return cles.at(-1).slice(1).map(rgb);
  const i = cles.findIndex(([h]) => h > e), a = cles[i - 1], b = cles[i], t = (e - a[0]) / (b[0] - a[0]);
  return [1, 2, 3].map((k) => melange(a[k], b[k], t));
}
/**
 * Les trois couleurs brutes du ciel pour [e] : celles du matin et du soir mêlées selon la part du
 * [matin] (1 ou true le matin, 0 ou false le soir, entre les deux autour de midi et de minuit).
 */
export function brutes(e, matin) {
  const m = matin === true ? 1 : matin === false ? 0 : matin;
  if (m >= 1) return selon(MATIN, e);
  if (m <= 0) return selon(SOIR, e);
  const a = selon(MATIN, e), b = selon(SOIR, e);
  return a.map((c, i) => melange(b[i], c, m));
}
export function rampe(x, de, a) { const t = Math.min(1, Math.max(0, (x - de) / (a - de))); return t * t * (3 - 2 * t); }
/**
 * La part du matin dans les couleurs d'après l'angle horaire du soleil (CielContinu.partMatin) :
 * 1 le matin, 0 le soir, un passage d'une heure environ autour de midi et de minuit, où le soleil
 * du nord reste bas (midi d'hiver) ou haut (minuit d'été) et où les deux suites ne se rejoignent pas.
 */
export const PASSAGE = 0.25;
export const partMatin = (angleHoraire) => rampe(Math.sin(rad(angleHoraire)), PASSAGE, -PASSAGE);
/** L'astre s'efface là où son arc recommence : le soleil autour de minuit (jour polaire), la lune autour de midi (nuit polaire). */
export const fonduArc = (angleHoraire, soleil) => (soleil ? rampe(Math.abs(angleHoraire), 180, 165) : rampe(Math.abs(angleHoraire), 0, 15));
export function partsSombre(e) {
  const nuit = [0.25, 0.40, 0.55], crepuscule = [0.36, 0.48, 0.56], jour = [0.38, 0.44, 0.52];
  const [a, b, t] = e <= -12 ? [nuit, nuit, 0] : e < -3 ? [nuit, crepuscule, (e + 12) / 9] : e < 6 ? [crepuscule, crepuscule, 0] : e < 12 ? [crepuscule, jour, (e - 6) / 6] : [jour, jour, 0];
  return a.map((v, i) => v + (b[i] - v) * t);
}
export const chaleur = (e) => rampe(e, -12, -6) * (1 - rampe(e, 6, 12));
export const allumage = (e) => rampe(e, -4, -14);
export const presenceNuages = (e) => 0.15 + 0.85 * rampe(e, -14, -6);
export const rayonsDores = (e) => rampe(e, -2, 2.5) * (1 - rampe(e, 6, 10));
export const soleilVisible = (e) => rampe(e, -3, 1);
export const soleilPlutotQueLune = (e) => e >= -3;
export const luneVisible = (e) => rampe(e, -3, -7);
/** La lueur large demeure un peu sous l'horizon, jusqu'à ce que la lune prenne le relais (0° à −3°). */
export const lueurVisible = (e) => rampe(e, -3, 0);
/** L'opacité de l'astre du moment et de sa lueur (EtatCiel.astreVisible, lueurVisible). */
export function visibilites(e, angleHoraire) {
  const estSoleil = soleilPlutotQueLune(e);
  const astre = (estSoleil ? soleilVisible(e) : luneVisible(e)) * fonduArc(angleHoraire, estSoleil);
  return { estSoleil, astre, lueur: estSoleil ? Math.max(soleilVisible(e), lueurVisible(e)) * fonduArc(angleHoraire, true) : astre };
}
export const elevationDessinee = (e) => Math.min(1, Math.max(0, Math.sin(rad(e)) / Math.sin(Math.PI / 3)));
export const rayonSoleil = (e) => 14 + 3 * (1 - rampe(e, 0, 15));
export const RAYON_LUNE = 12;
export const MOIS_LUNAIRE = 29.530589;
export function lune(jourDuMois) {
  const age = Math.min(30, Math.max(1, jourDuMois)) - 0.5;
  return { age, eclairee: (1 - Math.cos(2 * Math.PI * age / MOIS_LUNAIRE)) / 2, croissante: age < MOIS_LUNAIRE / 2 };
}

function calculerArrets(e, matin, sombre, b, reserve) {
  const departs = brutes(e, matin), parts = partsSombre(e), w = chaleur(e);
  return departs.map((depart, i) => {
    let c = depart;
    if (sombre) {
      const cible = b * parts[i] * 0.9 ** reserve;
      if (luminance(c) > cible) {
        if (i > 0 && w > 0) {
          c = melange(c, departs[0], 0.45 * w);
          const [h, s, l] = hsl(c);
          c = deHsl(h, Math.min(s, 1 - 0.45 * w), l);
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

/** Les couleurs d'un nuage qui ne passe sous aucun texte, dans la bande des anneaux (TeintesCiel.nuageVif). */
export function nuageVif(c, sombre, corps) {
  if (sombre && corps) return luminance(c) > 0.10 ? aLuminance(c, 0.10) : c;
  if (sombre) return luminance(c) > 0.35 ? aLuminance(c, 0.35) : c;
  if (corps) return luminance(c) < 0.8 ? aLuminance(c, 0.8) : c;
  return c;
}

/**
 * Le ciel quand le soleil est à [e] degrés, avec la part du [matin] (partMatin, ou true / false),
 * sous des encres ([{ couleur, seuil }], claires si [sombre]) ; le papier si aucune teinte ne les
 * laisse lisibles (TeintesCiel.pourCiel). Les couleurs sont des [r, g, b].
 */
export function teintesCiel(e, matin, sombre, encres, papier) {
  const b = borne(encres, sombre);
  // Comme lisible(), la luminance de chaque encre calculée une fois : le calcul la demande des milliers de fois.
  const lues = encres.map((x) => ({ l: luminance(x.couleur), min: x.seuil + MARGE }));
  const ok = (fond) => { const l = luminance(fond); return lues.every((x) => (Math.max(l, x.l) + 0.05) / (Math.min(l, x.l) + 0.05) >= x.min); };
  const lisibles = ([haut, milieu, bas]) => Array.from({ length: ECHANTILLONS + 1 }, (_, i) => degrade({ haut, milieu, bas }, i / ECHANTILLONS)).every(ok);
  let reserve = 0;
  let a = calculerArrets(e, matin, sombre, b, 0);
  while (!lisibles(a) && reserve < 12) a = calculerArrets(e, matin, sombre, b, ++reserve);
  if (!lisibles(a)) a = [rgb(papier), rgb(papier), rgb(papier)];
  const t = { haut: a[0], milieu: a[1], bas: a[2] };
  const echantillons = Array.from({ length: ECHANTILLONS + 1 }, (_, i) => degrade(t, i / ECHANTILLONS));
  const tous = (fonds, couche, x) => fonds.every((f) => ok(melange(f, couche, x)));
  // Les nuages d'abord : le bord éclairé, puis le corps (en thème sombre, une silhouette plus sombre que le ciel).
  let bord = suite(NUAGE_BORD, e), corps = suite(NUAGE_CORPS, e);
  const plusSombre = Math.min(...echantillons.map(luminance));
  if (sombre) corps = aLuminance(corps, plusSombre * 0.6);
  else {
    if (luminance(corps) < b + 0.08) corps = aLuminance(corps, Math.min(b + 0.08, 1));
    if (luminance(bord) < b + 0.03) bord = aLuminance(bord, Math.min(b + 0.03, 1));
  }
  const bordAlpha = opaciteMax(sombre ? 0.5 : 0.8, (x) => tous(echantillons, bord, x));
  const sousBord = echantillons.map((f) => melange(f, bord, bordAlpha));
  const corpsAlpha = opaciteMax(sombre ? 0.6 : 0.8, (x) => tous(echantillons, corps, x) && tous(sousBord, corps, x));
  // La lueur large prend ce qui reste, nuages par-dessus compris.
  let lueur = suite(LUEUR, e);
  if (e < 0) lueur = melange(lueur, LUNE, rampe(e, 0, -12));
  if (!sombre && luminance(lueur) < b + 0.06) lueur = aLuminance(lueur, Math.min(b + 0.06, 1));
  const lueurAlpha = opaciteMax(sombre ? 0.9 : 0.85, (x) => echantillons.every((f) => {
    const sous = melange(f, lueur, x), bordDessus = melange(sous, bord, bordAlpha);
    return ok(sous) && ok(bordDessus) && ok(melange(sous, corps, corpsAlpha)) && ok(melange(bordDessus, corps, corpsAlpha));
  }));
  const detache = (c) => (!sombre && luminance(c) > ASTRE_CLAIR ? aLuminance(c, ASTRE_CLAIR) : c);
  const lisibleAjuste = (c0) => {
    let c = c0;
    for (let n = 0; n < 40 && !ok(c); n++) { const l = luminance(c); c = aLuminance(c, sombre ? l * 0.9 : Math.min(l + 0.01, 1)); }
    return c;
  };
  const loin = melange(a[2], a[0], 0.5), pres0 = melange(a[2], a[0], 0.9);
  return {
    ...t, lueur, lueurAlpha, couronne: suite(LUEUR, e), astre: detache(suite(ASTRE, e)), lune: detache(rgb(LUNE)),
    corps, corpsAlpha, bord, bordAlpha,
    corpsVif: nuageVif(suite(NUAGE_CORPS, e), sombre, true), bordVif: nuageVif(suite(NUAGE_BORD, e), sombre, false),
    etoile: sombre ? [255, 246, 236] : [120, 132, 196], etoileAlpha: sombre ? 0.9 : 0.8,
    collineLoin: lisibleAjuste(aLuminance(loin, luminance(a[2]) * (sombre ? 0.8 : 0.94))),
    collinePres: lisibleAjuste(aLuminance(pres0, luminance(a[2]) * (sombre ? 0.55 : 0.86))),
  };
}

// --- Le plan et les mouvements (CielPage.kt, PlanCiel ; CielVivant.kt) -------------------------

/** Les mouvements, en secondes et en px CSS (= dp) : les mêmes qu'Android. */
export const VIVANT = Object.freeze({
  scintillementMin: 8, scintillementMax: 16, scintillementBas: 0.45,
  deriveX: 3, deriveXS: 40, deriveY: 1.5, deriveYS: 31,
  souffleS: 12, souffleTaille: 0.06, souffleEclat: 0.18,
  nuageVitesse: 3, voileVitesse: 2, rayonsDegS: 2,
});
/** La couronne et la lueur en rayons du disque ; les rayons de l'heure dorée ; les étoiles loin du texte. */
export const COURONNE = 2.2;
export const LUEUR_RAYONS = 4.2;
export const RAYONS = 12;
export const MARGE_ETOILE = 6;
/** Les collines du bas du premier écran (px) ; le bord éclairé des nuages (px). */
export const COLLINES = 72;
export const BORD = 3;
/** Les trois nuages : départ (part de la largeur), place dans la hauteur des anneaux, échelle, forme (0 bombé, 1 long). */
export const NUAGES = Object.freeze([[0.08, 0.06, 0.9, 0], [0.30, 0.52, 0.8, 1], [0.62, 0.86, 0.75, 0]]);
export const NUAGE_VIF = 0.85;
/** La hauteur du nuage [i] de hauteur [haut] (PlanCiel.nuageY), et si sa bande est libre de texte (bandeLibre). */
export function nuageY(i, jauge, vue, haut) {
  const f = NUAGES[i][1];
  return jauge ? jauge.haut + f * Math.max(0, jauge.bas - jauge.haut - haut) : vue * (0.1 + 0.4 * f);
}
export const bandeLibre = (haut, bas, zones) => !zones.some((z) => z.bas > haut && z.haut < bas);
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

/** Combien d'étoiles et jusqu'où (PlanCiel.etoiles) : une pour 4 600 px², de 24 à 72, les quatre cinquièmes du haut. */
export function planEtoiles(largeur, hauteur) {
  return [Math.min(72, Math.max(24, Math.floor(largeur * hauteur / 4600))), 0.78];
}

const touche = (z, cx, cy, r) => cx + r > z.gauche && cx - r < z.droite && cy + r > z.haut && cy - r < z.bas;

/**
 * Le centre de l'astre sur son arc (PlanCiel.arc) : de la marge gauche des anneaux (progrès 0) à
 * la droite (1), derrière eux vers midi ; la hauteur (0 à 1) dans la hauteur des anneaux. Null
 * sous un texte ; au bord de l'écran étroit, il s'arrête. Zones : { gauche, haut, droite, bas }.
 */
export function arc(progres, hauteur, jauge, largeur, r, couronne, zones) {
  if (largeur < 2 * r) return null;
  const cx = (jauge.gauche + jauge.droite) / 2, gauche = jauge.gauche / 2, droite = (jauge.droite + largeur) / 2;
  const u = Math.cos(Math.PI * Math.min(1, Math.max(0, progres)));
  const pousse = Math.abs(u) ** 0.4;
  // Sur un écran étroit, le disque s'arrête au bord au lieu d'y disparaître.
  const x = Math.min(largeur - r, Math.max(r, u >= 0 ? cx - (cx - gauche) * pousse : cx + (droite - cx) * pousse));
  const bas = jauge.bas - couronne, hautArc = jauge.haut + couronne;
  const y = bas - Math.max(0, bas - hautArc) * Math.min(1, Math.max(0, hauteur));
  if (zones.some((z) => touche(z, x, y, couronne))) return null;
  return [x, y];
}

/** Les étoiles qui se montrent : aucune près d'un texte, d'une icône ou des anneaux (PlanCiel.libres). */
export function etoilesLibres(liste, largeur, hauteur, zones) {
  const ecart = MARGE_ETOILE + Math.max(VIVANT.deriveX, VIVANT.deriveY);
  return liste.map(([x, y, r]) => !zones.some((z) => touche(z, x * largeur, y * hauteur, r * 1.6 + ecart)));
}
