// Audit du 16/11, « Hallel et Moussaf » : les mêmes cas qu'Android (HallelMoussafTest.kt).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { conditionsPour, index, plan, vrai } from '../src/js/siddur-jour.js';

const RAW = '../../android/app/src/main/res/raw/';
const lis = (f) => JSON.parse(readFileSync(new URL(RAW + f, import.meta.url), 'utf8'));
const annotations = lis('siddur_annotations.json');
const siddur = Object.fromEntries(['edot', 'sefard', 'ashkenaz'].map((n) => [n, lis(`siddur_${n}.json`)]));
const chaines = readFileSync(new URL('../../android/app/src/main/res/values/strings.xml', import.meta.url), 'utf8');
const c = (iso, israel = false) => jour(iso, israel).conditions;
const plat = (s) => s.replace(/<[^>]+>/g, '').replace(/[֑-ׇ\s״׳"'()[\]]/g, '');

/** Les renvois et rappels du jour d'un texte, dans l'ordre (SiddurJour.lignes). */
function renvois(nusah, id, iso, israel = false) {
  const k = conditionsPour(nusah, israel, c(iso, israel));
  return annotations[nusah][id].filter((a) => a.sorte === 'renvoi' && vrai(a.si, k)).map((a) => a.cible ?? a.libelle);
}
/** Le passage se lit en clair ce jour-là (ni replié ni dans un groupe d'un autre jour). */
function clair(nusah, id, iso, passage, israel = false) {
  const texte = siddur[nusah].textes.find((t) => t.id === id);
  const k = conditionsPour(nusah, israel, c(iso, israel));
  const idx = index(annotations[nusah][id]);
  return texte.sections.some((s, si) => plan(s, si, idx, k).some((p) => p.etat !== 'replie' && p.blocs.some((i) => {
    const b = s.blocs[i];
    const a = idx.blocs.get(`${si}:${i}`);
    return b.t && plat(b.t).includes(plat(passage)) && (!a || vrai(a.si, k));
  })));
}

test('conditions déduites : Roch \'Hodech en semaine, \'Hol hamoèd, \'Hanouka sans Moussaf, soir du Séder, Hallel partiel', () => {
  assert.ok(c('2025-12-20').has('chabbat_roch_hodech') && !c('2025-12-20').has('roch_hodech_chol'));
  assert.ok(c('2025-12-21').has('roch_hodech_chol') && c('2026-10-12').has('roch_hodech_chol'));
  assert.ok(c('2025-12-17').has('hanouka_sans_moussaf'));
  for (const d of ['2025-12-20', '2025-12-21', '2026-12-05']) assert.ok(!c(d).has('hanouka_sans_moussaf'), d);
  assert.ok(c('2026-12-05').has('hanouka_hors_roch_hodech') && !c('2025-12-21').has('hanouka_hors_roch_hodech'));
  assert.ok(c('2026-04-06').has('hol_hamoed') && c('2026-04-03', true).has('hol_hamoed'));
  assert.ok(!c('2026-04-02').has('hol_hamoed') && !c('2026-04-03').has('hol_hamoed'));
  assert.ok(c('2026-04-02').has('leil_pessah') && c('2026-04-02', true).has('leil_pessah') && c('2026-04-03').has('leil_pessah'));
  assert.ok(!c('2026-04-03', true).has('leil_pessah') && !c('2026-04-08').has('leil_pessah') && !c('2026-04-09').has('leil_pessah'));
  assert.ok(c('2026-10-12').has('hallel_partiel') && !c('2025-12-17').has('hallel_partiel') && !c('2026-11-12').has('hallel_partiel'));
});

test('Chabbat Roch \'Hodech : le Hallel, pas le Moussaf de semaine ; « אתה יצרת » rappelé', () => {
  for (const n of ['edot', 'sefard', 'ashkenaz']) {
    const r = renvois(n, 'chaharit', '2025-12-20');
    assert.ok(r.includes('hallel') && !r.includes('moussaf_rosh_hodech') && r.includes('ajout_rappel_moussaf_chabbat_roch_hodech'), n);
    const s = renvois(n, 'chaharit', '2025-12-21');
    assert.ok(s.includes('moussaf_rosh_hodech') && !s.includes('ajout_rappel_moussaf_chabbat_roch_hodech'), n);
  }
});

test('\'Hol hamoèd : le Moussaf de la fête signalé, pas celui de Roch \'Hodech (Edot, Ashkenaz)', () => {
  for (const n of ['edot', 'ashkenaz']) {
    assert.deepEqual(renvois(n, 'chaharit', '2026-04-06'), ['hallel', 'ajout_rappel_moussaf_hol_hamoed'], n);
  }
});

test('Kaddich du Hallel : תתקבל tout jour de Moussaf, demi-Kaddich à \'Hanouka sans Moussaf, Ashkenaz compris', () => {
  for (const n of ['edot', 'sefard', 'ashkenaz']) {
    for (const d of ['2025-12-20', '2025-12-21', '2026-12-05', '2026-10-12']) assert.ok(clair(n, 'hallel', d, 'תתקבל'), `${n} ${d}`);
    assert.ok(!clair(n, 'hallel', '2025-12-17', 'תתקבל'), n);
    assert.ok(clair(n, 'hallel', '2025-12-17', 'יתגדל ויתקדש שמה רבא'), n);
  }
});

test('Edot : pas de bénédiction au Hallel partiel ; Sfard : la précision pour le minyan', () => {
  assert.ok(!clair('edot', 'hallel', '2026-10-12', 'וצונו לגמור את ההלל'));
  assert.ok(clair('edot', 'hallel', '2025-12-17', 'וצונו לגמור את ההלל'));
  assert.ok(renvois('sefard', 'hallel', '2026-10-12').includes('ajout_rappel_berakha_hallel_sefard'));
  assert.ok(!renvois('sefard', 'hallel', '2025-12-17').length);
});

test('Soir du Séder : Hallel après l\'Amida d\'Arvit (Edot, Sfard), rien en Ashkenaz', () => {
  for (const n of ['edot', 'sefard']) {
    assert.ok(renvois(n, 'arvit', '2026-04-02').includes('hallel'), n);
    assert.ok(renvois(n, 'arvit', '2026-04-03').includes('hallel'), n);
    assert.ok(!renvois(n, 'arvit', '2026-04-03', true).length, n);
  }
  assert.ok(!renvois('ashkenaz', 'arvit', '2026-04-02').length);
});

test('Edot : וּלְכַפָּרַת פֶּשַׁע plus à partir de Nissan (Kitsour Yalkut Yosef 423:14)', () => {
  const a = annotations.edot.moussaf_rosh_hodech.find((e) => e.texte === 'וּלְכַפָּרַת פֶּשַׁע');
  assert.equal(a.si, 'embolismique_avant_nissan');
  assert.ok(!vrai(a.si, c('2027-04-08')) && vrai(a.si, c('2026-11-11')));
});

test('Edot : ברכי נפשי après Moussaf, le psaume de \'Hanouka après lui à Roch \'Hodech Tévèt', () => {
  assert.ok(clair('edot', 'moussaf_rosh_hodech', '2026-10-12', 'ברכי נפשי את יהוה'));
  assert.ok(renvois('edot', 'moussaf_rosh_hodech', '2025-12-21').includes('ajout_rappel_psaume_hanouka_apres_moussaf'));
  assert.ok(!renvois('edot', 'moussaf_rosh_hodech', '2026-10-12').length);
  const ps30 = annotations.edot.chaharit.find((e) => e.sorte === 'bloc' && e.empreinte.includes('שירחנכת'));
  assert.equal(ps30.si, 'hanouka_hors_roch_hodech');
});

test('Roch \'Hodech : pas de תתקבל après ובא לציון (Edot), demi-Kaddich avant Moussaf', () => {
  const e = renvois('edot', 'chaharit', '2026-10-12');
  assert.ok(e.indexOf('ajout_rappel_sans_titkabal') >= 0);
  assert.ok(e.indexOf('ajout_rappel_demi_kaddich_moussaf_edot') < e.indexOf('moussaf_rosh_hodech'));
  const a = renvois('ashkenaz', 'chaharit', '2026-10-12');
  assert.ok(a.indexOf('ajout_rappel_demi_kaddich_moussaf') >= 0 && a.indexOf('ajout_rappel_demi_kaddich_moussaf') < a.indexOf('moussaf_rosh_hodech'));
  for (const n of ['edot', 'ashkenaz']) assert.deepEqual(renvois(n, 'chaharit', '2026-11-12'), [], n);
});

test('chaque rappel a sa chaîne', () => {
  for (const n of ['edot', 'sefard', 'ashkenaz']) {
    for (const a of Object.values(annotations[n]).flat().filter((x) => x.sorte === 'renvoi' && !x.cible)) {
      assert.ok(a.libelle && chaines.includes(`name="${a.libelle}"`), `${n} ${a.si}`);
    }
  }
});
