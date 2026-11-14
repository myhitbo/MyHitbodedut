// Les traductions des livres (audit du 12/11) : leurs balises sont rendues, jamais affichées,
// et les contresens corrigés ne reviennent pas.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const lire = (chemin) => readFileSync(new URL(`../../${chemin}`, import.meta.url), 'utf8');
const livres = JSON.parse(lire('android/app/src/main/livres/livres.json'));
const traductions = livres.textes.flatMap((t) => t.sections.flatMap((s) => s.blocs.flatMap((b) => [b.fr, b.en].filter((x) => typeof x === 'string'))));

test('les traductions n’ont que des balises que le site et Android savent rendre', () => {
  const balises = new Set(traductions.flatMap((t) => t.match(/<[^>]*>/g) ?? []));
  assert.deepEqual([...balises].sort(), ['</b>', '</small>', '<b>', '<br>', '<small>']);
  // Aucun « < » isolé qui s'afficherait tel quel.
  for (const t of traductions) assert.ok(!/<(?![/]?(b|small)>|br>)/.test(t), t.slice(0, 80));
});

test('les balises des traductions sont rendues : riche() sur le site, Html.fromHtml sur Android (FWEBLIVE-01)', () => {
  assert.match(lire('web/src/js/app.js'), /const paraTraduction = [^\n]*riche\(texte\)\);/);
  const K = 'android/app/src/main/java/com/myhitbodedut/';
  assert.match(lire(`${K}LanguesTexte.kt`), /fun riche\(t: CharSequence\): CharSequence =[\s\S]*Html\.fromHtml/);
  assert.match(lire(`${K}LanguesTexte.kt`), /fun vueTraduction[\s\S]*?text = riche\(texte\)/);
  assert.match(lire(`${K}LanguesTexte.kt`), /fun vueMarquee[\s\S]*?text = riche\(texte\)/);
  assert.match(lire(`${K}SiddurLectureActivity.kt`), /append\(LanguesTexte\.riche\(t\)\)/);
});

test('les contresens corrigés ne reviennent pas (YALKUT-01, MIDOT-01, HICHT-01, HICHT-02)', () => {
  const tout = traductions.join('\n');
  for (const faux of ['se garder très soigneusement de réduire', 'de saisir sa pensée afin', 'ne manger que selon la consultation',
    'careful to eat only according', 'et on la récite avant', 'one recites it before “lehit']) {
    assert.ok(!tout.includes(faux), faux);
  }
});

test('le site dit ce qui n’est pas traduit et d’où viennent les textes (COUV-01, 02, 05, TLIVRES-09)', () => {
  const app = lire('web/src/js/app.js');
  assert.match(app, /const sansTraduction = LanguesTexte\.manque\(languesLecture\(\), traduitIci\);/);
  assert.match(app, /lecture_traduction_partielle', chapitresTraduits, x\.sections\.length/);
  assert.equal((app.match(/tl\('lecture_traduction_auto'\)/g) ?? []).length, 3);
  assert.match(app, /function carteLicences\(\)[\s\S]*?licences_texte/);
  for (const dossier of ['values', 'values-en', 'values-iw']) {
    const xml = lire(`android/app/src/main/res/${dossier}/strings.xml`);
    for (const mot of ['licences_texte', 'KosherJava', 'CC BY-NC-SA 2.5', 'GeoNames']) assert.ok(xml.includes(mot), `${dossier} ${mot}`);
  }
});
