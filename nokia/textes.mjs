// Les textes de l'application Java, pour un téléphone à touches, en
// français, en anglais et en hébreu. Relus dans les ressources Android,
// jamais recopiés :
//   - le ’hizouk publiable (relevé de la source ET relu) : l'hébreu, et
//     ses traductions française et anglaise, rangé sous son premier moment ;
//   - les titres des moments et quelques mots de l'interface, dans
//     values/, values-en/ et values-iw/strings.xml.
//
// La règle des langues (RegleLangue, comme sur Android) se joue au
// téléphone : il ne garde que l'hébreu et la langue de l'interface, et en
// hébreu, rien que l'hébreu.
//
// Le fichier produit (textes.bin) se lit avec DataInputStream :
// readUTF pour les chaînes, readShort pour les nombres. Le français et
// l'anglais sont ramenés à Latin-1 : une police de téléphone à touches n'a
// pas toujours « œ » ni « … ». L'hébreu garde ses lettres (U+05D0 à U+05EA)
// mais perd le nikkoud et les signes de cantillation : une police de
// téléphone les dessine rarement, et souvent en carrés.

import { ChizukRules, MOMENTS } from '../web/src/js/chizuk.js';
import { Reference } from '../web/src/js/regles.js';

/** Les langues de l'application, dans l'ordre de textes.bin et de Mots.java (FR, EN, HE). */
export const LANGUES = ['fr', 'en', 'he'];

/** Le dossier des ressources Android de chaque langue. */
export const DOSSIERS = { fr: 'values', en: 'values-en', he: 'values-iw' };

/** Les mots de l'application reprises telles quelles (strings.xml). */
export const CLES_INTERFACE = ['chizuk_stuck', 'journal_empty', 'session_done_title', 'reminder_title'];

const REMPLACEMENTS = [
  [/[’‘׳]/g, "'"], [/[“”״]/g, '"'], [/…/g, '...'], [/œ/g, 'oe'], [/Œ/g, 'Oe'],
  [/[–—]/g, '-'], [/[\u00a0\u202f\u2009]/g, ' '], [/[\u200b-\u200f]/g, ''],
];

function remplace(texte) {
  let s = String(texte);
  for (const [motif, par] of REMPLACEMENTS) s = s.replace(motif, par);
  return s;
}

function verifie(s, permis) {
  const reste = [...s].find((c) => !permis(c.codePointAt(0)));
  if (reste) throw new Error(`Caractère indessinable : ${reste} (U+${reste.codePointAt(0).toString(16)}) dans « ${s.slice(0, 60)} »`);
  return s;
}

/** Ramène un texte à ce qu'une police Latin-1 sait dessiner. */
export function latin1(texte) {
  return verifie(remplace(texte), (cp) => cp <= 0xff);
}

/**
 * L'hébreu pour une police de téléphone : les lettres, sans nikkoud ni
 * cantillation ; le maqaf devient un trait d'union, le sof passouq deux-points.
 */
export function hebreu(texte) {
  const s = remplace(String(texte)
    .replace(/[֑-ׇֽֿׁׂׅׄ]/g, '')
    .replace(/־/g, '-')
    .replace(/׃/g, ':')
    .replace(/׀/g, '|'));
  return verifie(s, (cp) => cp <= 0xff || (cp >= 0x5d0 && cp <= 0x5ea));
}

/** Ce qu'une langue sait dessiner. */
export function pourPolice(texte, langue) {
  return langue === 'he' ? hebreu(texte) : latin1(texte);
}

/** Le premier moment d'un texte, dans l'ordre de l'application. */
export function momentDe(item) {
  return MOMENTS.find((m) => (item.moments || []).includes(m)) ?? null;
}

/**
 * chaines : { fr, en, he } (strings.xml de chaque langue).
 *   { interface: {cle: {fr, en, he}},
 *     moments: [{ cle, titre: {fr, en, he}, textes: [{ id, ref: {fr, en, he}, texte: {fr, en, he} }] }] }
 * texte.he est l'original ; texte.fr et texte.en ses traductions (vides si absentes).
 * Un moment sans texte publiable n'apparaît pas.
 */
export function textesLangues(chizuk, chaines) {
  const parLangue = (f) => Object.fromEntries(LANGUES.map((l) => [l, pourPolice(f(l), l)]));
  const chaine = (l, k) => {
    const v = chaines[l][k];
    if (v === undefined) throw new Error(`Chaîne manquante (${l}) : ${k}`);
    return v;
  };
  const moments = MOMENTS.map((cle) => ({
    cle,
    textes: chizuk.items
      .filter((it) => ChizukRules.publiable(it) && momentDe(it) === cle && String(it.he || '').trim() !== '')
      .map((it) => ({
        id: it.id,
        ref: parLangue((l) => Reference.localise(it.ref, l)),
        texte: parLangue((l) => (l === 'he' ? ChizukRules.hebreu(chizuk, it) : ChizukRules.traduction(it, l))),
      })),
  })).filter((m) => m.textes.length > 0)
    .map((m) => ({ cle: m.cle, titre: parLangue((l) => chaine(l, `moment_${m.cle}`)), textes: m.textes }));
  const iface = Object.fromEntries(CLES_INTERFACE.map((k) => [k, parLangue((l) => chaine(l, k))]));
  return { interface: iface, moments };
}

// --- Encodage DataOutputStream ----------------------------------------------------
function utf(s) {
  // Sans NUL ni caractère hors du plan de base, l'UTF-8 modifié de Java est l'UTF-8 ordinaire.
  if (s.includes('\0')) throw new Error('NUL interdit');
  if ([...s].some((c) => c.codePointAt(0) > 0xffff)) throw new Error('Caractère hors du plan de base');
  const octets = Buffer.from(s, 'utf8');
  if (octets.length > 0xffff) throw new Error('Chaîne trop longue pour readUTF');
  const tete = Buffer.alloc(2);
  tete.writeUInt16BE(octets.length);
  return Buffer.concat([tete, octets]);
}
function court(n) {
  const b = Buffer.alloc(2);
  b.writeUInt16BE(n);
  return b;
}

/**
 * Format 2 : version, n langues (code)…, n clés (clé, un texte par langue)…,
 * n moments (clé, un titre par langue, n textes (par langue : ref, texte)…)…
 * Le téléphone saute les langues qu'il ne montre pas sans les charger.
 */
export function encode(donnees) {
  const parts = [court(2), court(LANGUES.length), ...LANGUES.map(utf)];
  const cles = Object.keys(donnees.interface);
  parts.push(court(cles.length));
  for (const k of cles) {
    parts.push(utf(k));
    for (const l of LANGUES) parts.push(utf(donnees.interface[k][l]));
  }
  parts.push(court(donnees.moments.length));
  for (const m of donnees.moments) {
    parts.push(utf(m.cle));
    for (const l of LANGUES) parts.push(utf(m.titre[l]));
    parts.push(court(m.textes.length));
    for (const t of m.textes) for (const l of LANGUES) parts.push(utf(t.ref[l]), utf(t.texte[l]));
  }
  return Buffer.concat(parts);
}

/** Relit textes.bin comme le fera le téléphone (pour les tests). */
export function decode(octets) {
  let i = 0;
  const lireCourt = () => { const n = octets.readUInt16BE(i); i += 2; return n; };
  const lireUtf = () => { const n = lireCourt(); const s = octets.subarray(i, i + n).toString('utf8'); i += n; return s; };
  const version = lireCourt();
  const langues = [];
  for (let n = lireCourt(); n > 0; n--) langues.push(lireUtf());
  const parLangue = (lire) => Object.fromEntries(langues.map((l) => [l, lire()]));
  const iface = {};
  for (let n = lireCourt(); n > 0; n--) { const k = lireUtf(); iface[k] = parLangue(lireUtf); }
  const moments = [];
  for (let n = lireCourt(); n > 0; n--) {
    const cle = lireUtf();
    const titre = parLangue(lireUtf);
    const textes = [];
    for (let t = lireCourt(); t > 0; t--) {
      const ref = {};
      const texte = {};
      for (const l of langues) { ref[l] = lireUtf(); texte[l] = lireUtf(); }
      textes.push({ ref, texte });
    }
    moments.push({ cle, titre, textes });
  }
  if (i !== octets.length) throw new Error('Octets en trop');
  return { version, langues, interface: iface, moments };
}
