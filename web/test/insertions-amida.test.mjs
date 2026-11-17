// Audit halakhique du 16/11, insertions de la Amida (InsertionsAmidaTest.kt) : ce que le lecteur voit, jour par jour.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { ajouts } from '../src/js/jour-affiche.js';
import { conditionsPour, index, plan } from '../src/js/siddur-jour.js';

const RAW = '../../android/app/src/main/res/raw/';
const lis = (f) => JSON.parse(readFileSync(new URL(RAW + f, import.meta.url), 'utf8'));
const annotations = lis('siddur_annotations.json');
const siddur = Object.fromEntries(['edot', 'sefard', 'ashkenaz'].map((n) => [n, lis(`siddur_${n}.json`)]));
const nu = (s) => s.replace(/<[^>]+>/g, ' ').replace(/[֑-ׇ]/g, '').replace(/\s+/g, ' ').trim();
const AMIDOT = ['chaharit', 'minha', 'arvit'];

/** Les textes des blocs lisibles (hors replis) de l'office, le jour donné ; consignes comprises si demandé. */
function visibles(nusah, id, iso, consignes = false) {
  const texte = siddur[nusah].textes.find((t) => t.id === id);
  const c = conditionsPour(nusah, false, jour(iso, false).conditions);
  const idx = index(annotations[nusah][id]);
  const sortie = [];
  texte.sections.forEach((s, si) => {
    for (const p of plan(s, si, idx, c)) {
      if (p.etat !== 'replie') p.blocs.forEach((i) => (s.blocs[i].t || (consignes && s.blocs[i].c)) && sortie.push(nu(s.blocs[i].t || s.blocs[i].c)));
    }
  });
  return sortie;
}
const nb = (l, motif) => l.filter((t) => motif.test(t)).length;

/** Les annotations de bloc dont le texte répond au motif. */
function annotes(nusah, id, motif) {
  const texte = siddur[nusah].textes.find((t) => t.id === id);
  return annotations[nusah][id].filter((a) => a.sorte === 'bloc')
    .map((a) => ({ a, t: nu(texte.sections[a.s].blocs[a.b].t || texte.sections[a.s].blocs[a.b].c) })).filter((x) => motif.test(x.t));
}

test('Edot : la conclusion « העונה לעמו ישראל » suit l\'Anénou de l\'officiant (Yalkut Yosef 557:3)', () => {
  for (const id of ['chaharit', 'minha']) {
    const a = annotes('edot', id, /העונה לעמו ישראל בעת צרה/);
    assert.equal(a.length, 1, id);
    assert.equal(a[0].a.libelle, 'ajout_anenou_officiant', id);
    assert.equal(nb(visibles('edot', id, '2025-11-18'), /העונה לעמו ישראל בעת צרה/), 0, id);
  }
});

test('Edot : Na\'hem à Arvit, Cha\'harit et Min\'ha du 9 Av, un seul sceau (Yalkut Yosef 557:1)', () => {
  for (const id of AMIDOT) {
    const ticha = visibles('edot', id, '2027-08-12');
    assert.equal(nb(ticha, /^בתשעה באב אומרים: נחם/), 1, id);
    assert.equal(nb(ticha, /ברוך אתה \S+,? מנחם ציון/), 1, id);
    assert.equal(nb(ticha, /ברוך אתה \S+,? בונה ירושלים/), 0, id);
    const ord = visibles('edot', id, '2026-11-13');
    assert.equal(nb(ord, /נחם יהוה אלהינו|מנחם ציון/), 0, id);
    assert.equal(nb(ord, /ברוך אתה \S+,? בונה ירושלים/), 1, id);
  }
  for (const n of ['sefard', 'ashkenaz']) {
    assert.equal(nb(visibles(n, 'chaharit', '2027-08-12'), /נחם יהוה אלהינו/), 0, n);
    assert.equal(nb(visibles(n, 'minha', '2027-08-12'), /נחם יהוה אלהינו/), 1, n);
  }
});

test('Carte du jour : Na\'hem dit à quels offices, selon le nusah', () => {
  const av = jour('2027-08-12', false).conditions;
  assert.ok(ajouts(av, 'edot').includes('ajout_ticha_beav_trois'));
  for (const n of ['sefard', 'ashkenaz']) assert.ok(ajouts(av, n).includes('ajout_ticha_beav_minha'), n);
  assert.ok(!ajouts(jour('2027-08-11', false).conditions, 'edot').some((k) => k.startsWith('ajout_ticha_beav')));
});

test('Edot : six consignes d\'oubli par Amida, repliées ; Arvit de Roch \'Hodech sans retour', () => {
  for (const id of AMIDOT) {
    assert.equal(annotes('edot', id, /\(ילקוט יוסף, קיצור שו״ע/).filter((x) => x.a.si === 'oubli').length, 6, id);
    assert.equal(nb(visibles('edot', id, '2026-12-07', true), /ילקוט יוסף, קיצור שו״ע/), 0, id);
  }
  assert.equal(annotes('edot', 'arvit', /^אם שכח יעלה ויבא בערבית של ראש חודש, אינו חוזר/).length, 1);
});

test('Sfard, Ashkenaz : qui a dit מוריד הטל ne recommence pas (Choul\'han Aroukh 114:5)', () => {
  for (const n of ['sefard', 'ashkenaz']) for (const id of AMIDOT) {
    assert.deepEqual(annotes(n, id, /^ואם לא אמר משיב הרוח ומוריד הגשם אבל אמר מוריד הטל/).map((x) => x.a.si), ['oubli'], `${n} ${id}`);
  }
});

test('Le voyageur entre Israël et la diaspora, pour טל ומטר (Yalkut Yosef 117:15-17, Michna Beroura 117:5)', () => {
  for (const n of ['edot', 'ashkenaz']) for (const id of AMIDOT) {
    const a = annotes(n, id, /^בן ארץ ישראל בחוץ לארץ/);
    assert.deepEqual(a.map((x) => [x.a.si, x.a.libelle]), [['facultatif', 'ajout_voyageur_tal_oumatar']], `${n} ${id}`);
  }
});

test('Ashkenaz, Min\'ha d\'un jeûne public : שים שלום sans שלום רב (Rema 127:2)', () => {
  const jeune = visibles('ashkenaz', 'minha', '2026-12-20');
  assert.equal(nb(jeune, /^שלום רב/), 0);
  assert.equal(nb(jeune, /שים שלום טובה/), 1);
  const ordinaire = visibles('ashkenaz', 'minha', '2026-12-21');
  assert.equal(nb(ordinaire, /^שלום רב/), 1);
  assert.equal(nb(ordinaire, /שים שלום טובה/), 0);
});

test('« ועל הנסים », avec le ו, dans les trois noussa\'h (Yalkut Yosef 682:4)', () => {
  for (const n of ['edot', 'sefard', 'ashkenaz']) for (const id of [...AMIDOT, 'birkat_hamazon', 'moussaf_rosh_hodech']) {
    const blocs = siddur[n].textes.find((t) => t.id === id).sections.flatMap((s) => s.blocs).filter((b) => b.t).map((b) => nu(b.t));
    assert.ok(!blocs.some((t) => /^\(?על הנסים ועל הפרקן/.test(t)), `${n} ${id}`);
    assert.ok(blocs.some((t) => /^\(?ועל הנסים ועל הפרקן/.test(t)), `${n} ${id}`);
  }
});

test('Ashkenaz, dix jours : la même note « עושה השלום » aux trois offices (Maté Efraïm 582:22)', () => {
  for (const id of AMIDOT) {
    const a = annotes('ashkenaz', id, /^בעשי״ת: בספר חיים/);
    assert.equal(a.length, 1, id);
    assert.ok(a[0].t.endsWith('(יש נוהגין לחתום: ברוך אתה יהוה עשה השלום. מטה אפרים תקפב:כב)'), id);
  }
});
