// Audit du 12/11 (TSIDDUR-01 à -07) : ce que le lecteur voit vraiment, jour par jour, sceaux et fins d'office comprises.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { conditionsPour, index, plan } from '../src/js/siddur-jour.js';

const RAW = '../../android/app/src/main/res/raw/';
const lis = (f) => JSON.parse(readFileSync(new URL(RAW + f, import.meta.url), 'utf8'));
const annotations = lis('siddur_annotations.json');
const siddur = Object.fromEntries(['edot', 'sefard', 'ashkenaz'].map((n) => [n, lis(`siddur_${n}.json`)]));
const nu = (s) => s.replace(/<[^>]+>/g, ' ').replace(/[֑-ׇ]/g, '').replace(/\s+/g, ' ').trim();

/** Les textes des blocs lisibles (hors replis) de l'office, le jour donné. */
function visibles(nusah, id, iso) {
  const texte = siddur[nusah].textes.find((t) => t.id === id);
  const c = conditionsPour(nusah, false, jour(iso, false).conditions);
  const idx = index(annotations[nusah][id]);
  const sortie = [];
  texte.sections.forEach((s, si) => {
    for (const p of plan(s, si, idx, c)) if (p.etat !== 'replie') p.blocs.forEach((i) => s.blocs[i].t && sortie.push(nu(s.blocs[i].t)));
  });
  return sortie;
}
const nb = (l, motif) => l.filter((t) => motif.test(t)).length;

test('TSIDDUR-01 : un seul sceau pour Jérusalem à Min\'ha Edot, ni Na\'hem ni Anénou un jour ordinaire', () => {
  const l = visibles('edot', 'minha', '2026-11-13');
  assert.equal(nb(l, /ברוך אתה \S+,? (בונה ירושלים|מנחם ציון)/), 1);
  assert.equal(nb(l, /העונה לעמו ישראל בעת צרה/), 0);
});

test('TSIDDUR-02 : Moussaf de Roch \'Hodech, la fin de Modim reste lue hors \'Hanouka', () => {
  for (const n of ['edot', 'sefard', 'ashkenaz']) assert.ok(nb(visibles(n, 'moussaf_rosh_hodech', '2026-11-11'), /הטוב שמך ולך נאה להודות/) > 0, n);
});

test('TSIDDUR-03 : la fin de Min\'ha et « שומר ישראל » ne se replient plus avec le Ta\'hanoun', () => {
  assert.ok(nb(visibles('sefard', 'minha', '2026-11-13'), /^עלינו לשבח/) > 0);
  assert.ok(nb(visibles('edot', 'minha', '2026-11-13'), /יהוה מלך גאות/) > 0);
  assert.ok(nb(visibles('sefard', 'chaharit', '2026-11-17'), /^שומר ישראל/) > 0);
});

test('TSIDDUR-04 : Moussaf ashkénaze, qui prie seul : un seul sceau de la Kedoucha', () => {
  assert.equal(nb(visibles('ashkenaz', 'moussaf_rosh_hodech', '2026-11-11'), /ברוך אתה \S+ האל הקדוש/), 1);
});

test('TSIDDUR-05 : Hallel partiel (Edot), pas de bénédiction « לגמור את ההלל »', () => {
  assert.equal(nb(visibles('edot', 'hallel', '2026-11-11'), /לגמור את ההלל/), 0);
  assert.ok(nb(visibles('edot', 'hallel', '2026-12-07'), /לגמור את ההלל/) > 0);
});

test('TSIDDUR-06 : dix jours et 9 Av, un seul sceau', () => {
  for (const n of ['sefard', 'ashkenaz']) {
    const dix = visibles(n, 'chaharit', '2027-10-05');
    assert.equal(nb(dix, /ברוך אתה \S+ האל הקדוש/), 0, n);
    assert.equal(nb(dix, /ברוך אתה \S+ המלך הקדוש/), 1, n);
    const ord = visibles(n, 'chaharit', '2026-11-13');
    assert.equal(nb(ord, /ברוך אתה \S+ האל הקדוש/), 1, n);
    assert.equal(nb(ord, /ברוך אתה \S+ המלך הקדוש/), 0, n);
  }
  for (const n of ['sefard', 'ashkenaz', 'edot']) {
    const l = visibles(n, 'minha', '2027-08-12');
    assert.equal(nb(l, /ברוך אתה \S+,? בונה ירושלים/), 0, n);
    assert.equal(nb(l, /ברוך אתה \S+,? מנחם ציון/), 1, n);
  }
});

test('TSIDDUR-07 : supplications du lundi et du jeudi (Edot) : lues le lundi, absentes le mardi', () => {
  assert.ok(nb(visibles('edot', 'chaharit', '2026-11-16'), /^אנשי אמונה/) > 0);
  assert.equal(nb(visibles('edot', 'chaharit', '2026-11-17'), /^אנשי אמונה/), 0);
});
