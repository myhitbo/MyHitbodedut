// L'espagnol et l'arabe tunisien (17/11) : l'interface seule est traduite. Les textes (siddour,
// Tehilim, Tikoun, ’hizouk, halakha, hilloulot, guide…) y restent en hébreu, jamais en français
// ni en anglais (RegleLangue). Les mêmes règles qu'Android : LangueApp.livree, Langues.TOUTES,
// LanguesTexte.defaut, ChizukCard.translationOf, Hilloulot.lienHalakha.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { LANGUES, creeTraduction, langueInitiale, langueLivree } from '../src/js/i18n.js';
import { LanguesTexte, Reference, RegleLangue, SourceDuJour } from '../src/js/regles.js';
import { ChizukRules } from '../src/js/chizuk.js';
import { lienHalakha } from '../src/js/jour-affiche.js';
import { pourLangue, sousTitreBloc } from '../src/js/tikkun.js';
import { invitationSujet } from '../src/js/hitbodedut.js';
import { litChaines } from '../tools/chaines.mjs';

const ICI = dirname(fileURLToPath(import.meta.url));
const RES = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res');
const chaines = (dossier) => litChaines(readFileSync(join(RES, dossier, 'strings.xml'), 'utf8'));

test('les cinq langues, dans l’ordre de Langues.kt, chacune nommée dans sa langue', () => {
  assert.deepEqual(LANGUES.map((l) => l.nom), ['עברית', 'English', 'Français', 'Español', 'تونسي']);
  assert.deepEqual(LANGUES.map((l) => l.code), ['he', 'en', 'fr', 'es', 'ar']);
  assert.deepEqual(LANGUES.map((l) => l.locale), ['he', 'en', 'fr', 'es-419', 'ar-TN']);
  // Les noms du sélecteur sont ceux d'Android.
  const kt = readFileSync(join(RES, '..', 'java', 'com', 'myhitbodedut', 'Langues.kt'), 'utf8');
  assert.match(kt, /Langue\("es", "Español"\),\s*Langue\("ar-TN", "تونسي"\)/);
});

test('la langue du téléphone : l’espagnol de partout, l’arabe de Tunisie seulement', () => {
  for (const es of ['es', 'es-MX', 'es-419', 'es-ES', 'es_AR']) assert.equal(langueInitiale('', [es]), 'es', es);
  for (const ar of ['ar-TN', 'ar_TN', 'ar-tn', 'ar-Arab-TN']) assert.equal(langueInitiale('', [ar]), 'ar', ar);
  // Un arabe d'ailleurs garde le repli d'avant, l'anglais ; ou la langue suivante qu'il lit.
  for (const ar of ['ar', 'ar-EG', 'ar-SA', 'ar-MA']) assert.equal(langueInitiale('', [ar]), 'en', ar);
  assert.equal(langueInitiale('', ['ar-EG', 'fr-FR']), 'fr');
  assert.equal(langueInitiale('', ['ar-EG', 'ar-TN']), 'ar');
  // L'hébreu, sous ses deux codes.
  assert.equal(langueInitiale('', ['he-IL']), 'he');
  assert.equal(langueInitiale('', ['iw']), 'he');
  assert.equal(langueInitiale('', ['iw-IL', 'es']), 'he');
  // Le choix des réglages l'emporte, l'étiquette d'Android comprise.
  assert.equal(langueInitiale('ar', ['fr-FR']), 'ar');
  assert.equal(langueInitiale('ar-TN', ['fr-FR']), 'ar');
  assert.equal(langueInitiale('es', ['he-IL']), 'es');
  assert.equal(langueLivree('ar-EG'), null);
  assert.equal(langueLivree('de'), null);
});

test('l’arabe s’écrit de droite à gauche, comme l’hébreu ; ses formats sont ceux de la Tunisie', () => {
  const ar = creeTraduction('ar', chaines('values-ar-rTN'));
  const es = creeTraduction('es', chaines('values-es'));
  assert.equal(ar.rtl, true);
  assert.equal(ar.locale, 'ar-TN');
  assert.equal(creeTraduction('he', { chaines: {}, pluriels: {} }).rtl, true);
  assert.equal(es.rtl, false);
  assert.equal(es.locale, 'es-419');
  for (const l of ['fr', 'en']) assert.equal(creeTraduction(l, { chaines: {}, pluriels: {} }).rtl, false);
  // Les six formes du pluriel arabe, choisies par Intl comme par Android.
  assert.equal(ar.p('ring_streak_detail', 1, 1, 7), 'السلسلة: نهار واحد من 7');
  assert.equal(ar.p('ring_streak_detail', 2, 2, 7), 'السلسلة: نهارين من 7');
  assert.equal(ar.p('ring_streak_detail', 3, 3, 7), 'السلسلة: 3 أيّام من 7');
  assert.equal(es.t('settings_language'), chaines('values-es').chaines.settings_language);
  // Les chiffres restent latins en Tunisie (comme le %d des chaînes).
  assert.match(new Intl.NumberFormat(ar.locale).format(1234), /^1\D?234$/);
});

test('en espagnol et en arabe, les textes se lisent en hébreu seul : aucune traduction française ou anglaise', () => {
  for (const l of ['es', 'ar']) {
    // LanguesTexte.defaut : l'hébreu seul, comme en hébreu.
    assert.equal(LanguesTexte.defaut(l), 'he', l);
    assert.equal(LanguesTexte.mode(null, l), 'he', l);
    assert.deepEqual(LanguesTexte.textes(LanguesTexte.mode(null, l), 'שלום', 'Paix', 'Peace'), [['he', 'שלום']], l);
    assert.equal(LanguesTexte.manque(LanguesTexte.mode(null, l), false), false, l);
    // La carte de ’hizouk (ChizukCard.translationOf) : rien sous l'hébreu.
    assert.equal(ChizukRules.traduction({ he: 'שלום', fr: 'Paix', en: 'Peace' }, l), '', l);
    // RegleLangue : seul l'hébreu, ou la langue de l'interface, est permis.
    assert.equal(RegleLangue.permet(l, 'fr'), false, l);
    assert.equal(RegleLangue.permet(l, 'en'), false, l);
    assert.equal(RegleLangue.choisit(l, { fr: 'x', en: 'y' }), null, l);
    // Le Tikoun HaKlali : l'hébreu de la note, pas sa traduction.
    assert.equal(pourLangue({ he: 'א', fr: 'A', en: 'B' }, l), 'א', l);
    assert.equal(sousTitreBloc({ titre: { he: 'א', fr: 'A', en: 'A' } }, l), null, l);
    // Le guide du sujet n'a pas d'invitation en espagnol ni en arabe : rien plutôt que le français.
    assert.equal(invitationSujet({ famille: { sihah: { fr: 'f', en: 'e', he: 'ע' } } }, 'famille', 'sihah', l), null, l);
    // La source du jour : l'hébreu seul.
    const p = { texte: 'פסקה', indice: 0, source: { paragraphes_fr: ['para'], paragraphes_en: ['par'] } };
    assert.deepEqual(SourceDuJour.textes(p, LanguesTexte.mode(null, l)).map(([x]) => x), ['he'], l);
  }
  // Le français et l'anglais gardent l'hébreu et leur traduction ; l'hébreu, l'hébreu seul.
  assert.equal(LanguesTexte.defaut('fr'), 'he+fr');
  assert.equal(LanguesTexte.defaut('en'), 'he+en');
  assert.equal(LanguesTexte.defaut('he'), 'he');
  assert.equal(LanguesTexte.defaut('iw'), 'he');
  // Les langues du texte, choisies dans la barre de lecture, restent permises en toute langue.
  assert.equal(LanguesTexte.mode('he+fr', 'es'), 'he+fr');
  assert.equal(LanguesTexte.mode('fr+en', 'ar'), 'fr+en');
  assert.deepEqual(LanguesTexte.textes(LanguesTexte.mode('he+en', 'ar'), 'שלום', 'Paix', 'Peace'), [['he', 'שלום'], ['en', 'Peace']]);
});

test('la halakha du jour (halachayomit.co.il, qui a he, en, fr) : l’anglais pour l’espagnol, le français pour l’arabe', () => {
  assert.equal(lienHalakha('es'), 'https://halachayomit.co.il/en/default.aspx');
  assert.equal(lienHalakha('ar'), 'https://halachayomit.co.il/fr/default.aspx');
  assert.equal(lienHalakha('he'), 'https://halachayomit.co.il/he/default.aspx');
  assert.equal(lienHalakha('en'), 'https://halachayomit.co.il/en/default.aspx');
  assert.equal(lienHalakha('fr'), 'https://halachayomit.co.il/fr/default.aspx');
});

test('les noms traduits des hilloulot ne viennent qu’en français et en anglais (garde-fou sur app.js)', () => {
  const app = readFileSync(join(ICI, '..', 'src', 'js', 'app.js'), 'utf8');
  assert.match(app, /const nomTraduitHilloula = \(x\) => \(tr\.langue === 'fr' \? x\.fr \|\| x\.en : tr\.langue === 'en' \? x\.en : null\) \|\| null;/);
  // La page prend l'étiquette complète (es-419, ar-TN) et le sens de la langue.
  assert.match(app, /racine\.lang = tr\.locale;/);
  assert.match(app, /racine\.dir = tr\.rtl \? 'rtl' : 'ltr';/);
  // Aucun format d'Intl ne prend le code court : « ar » seul n'est pas la Tunisie.
  assert.doesNotMatch(app, /Intl\.\w+\(tr\.langue|toLocale\w*\(tr\.langue/);
  // La référence reste celle d'Android (Reference.localise) : graphie des données hors en/he.
  assert.equal(Reference.localise('Tehilim 1:1', 'es'), 'Tehilim 1:1');
});

test('le site construit livre les chaînes espagnoles et arabes (build.mjs)', () => {
  const build = readFileSync(join(ICI, '..', 'build.mjs'), 'utf8');
  assert.match(build, /\['es', 'values-es'\], \['ar', 'values-ar-rTN'\]/);
  const css = readFileSync(join(ICI, '..', 'src', 'app.css'), 'utf8');
  assert.match(css, /:root\[lang\|="ar"\] body \{ font-family: [^}]*"Noto Sans Arabic"/);
});
