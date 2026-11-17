// Audit halakhique du 16/11, « Birkat haMazon et bénédictions » : les conditions de la Havdala et
// du lendemain d'un jour d'ajouts, comme CalendrierJuif.kt (BerakhotAuditTest), et les notes de
// l'application (sorte « note »), rangées avec les cartes « seul » (SiddurJour.Sorte.NOTE).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour, jourDeLaPriere } from '../src/js/calendrier-juif.js';
import { index, plan, vrai } from '../src/js/siddur-jour.js';

const annotations = JSON.parse(readFileSync(new URL('../../android/app/src/main/res/raw/siddur_annotations.json', import.meta.url), 'utf8'));
const siddur = (n) => JSON.parse(readFileSync(new URL(`../../android/app/src/main/res/raw/siddur_${n}.json`, import.meta.url), 'utf8'));
const c = (iso, israel = false) => jour(iso, israel).conditions;
const nu = (s) => s.replace(/<[^>]+>/g, ' ').replace(/[֑-ׇ]/g, '').replace(/\s+/g, ' ').trim();

test('Havdala : flamme, bessamim, sortie du 9 Av un dimanche (CalendrierJuif.C.HAVDALA_NER…)', () => {
  const samedi9Av = c(jourDeLaPriere('havdala', '2025-08-02', 21, true));
  assert.ok(samedi9Av.has('ticha_beav') && samedi9Av.has('havdala_ner') && !samedi9Av.has('havdala_bessamim'));
  assert.ok(c('2025-08-04').has('lendemain_ticha_beav_dimanche') && !c('2025-08-04').has('havdala_ner'));
  assert.ok(!c('2026-07-24').has('lendemain_ticha_beav_dimanche'));
  assert.ok(c('2026-11-15').has('havdala_bessamim') && c('2026-11-14').has('havdala_ner'));
  assert.ok(!c('2026-04-10').has('havdala_ner') && !c('2026-04-10').has('havdala_bessamim'));
  assert.ok(c('2026-09-22').has('havdala_ner'));
});

test('le lendemain d\'un jour d\'ajouts, bein hamétsarim', () => {
  assert.ok(c('2026-11-15').has('lendemain_ajouts') && c('2026-12-11').has('lendemain_ajouts'));
  assert.ok(!c('2026-11-14').has('lendemain_ajouts') && !c('2026-11-17').has('lendemain_ajouts'));
  assert.ok(c('2026-07-02').has('bein_hametsarim') && c('2026-07-24').has('bein_hametsarim'));
  assert.ok(!c('2026-07-01').has('bein_hametsarim') && !c('2026-07-25').has('bein_hametsarim'));
});

test('Havdala Edot, le samedi soir du 9 Av : la coupe et les bessamim repliés, la flamme en clair', () => {
  const texte = siddur('edot').textes.find((t) => t.id === 'havdala');
  const idx = index(annotations.edot.havdala);
  const cond = c('2025-08-03');
  const clair = plan(texte.sections[0], 0, idx, cond).filter((p) => p.etat !== 'replie').flatMap((p) => p.blocs)
    .map((i) => texte.sections[0].blocs[i]).filter((b) => b.t).map((b) => nu(b.t));
  assert.ok(clair.some((x) => x.includes('מאורי האש')));
  assert.ok(!clair.some((x) => x.includes('בורא פרי הגפן') || x.includes('בשמים') || x.includes('המבדיל')));
  // La note du soir, rangée sous la flamme comme une carte « seul ».
  const notes = [...idx.seuls.values()].flat().filter((a) => a.sorte === 'note' && vrai(a.si, cond));
  assert.ok(notes.some((a) => a.texte.includes('בורא מאורי האש״ בלבד')));
});

test('les notes de l\'application désignent un bloc et ont un texte', () => {
  let n = 0;
  for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
    for (const liste of Object.values(annotations[nusah])) {
      for (const a of liste.filter((e) => e.sorte === 'note')) {
        assert.ok(a.texte && Number.isInteger(a.b), `${nusah} ${a.empreinte}`);
        n++;
      }
    }
  }
  assert.ok(n > 40, `${n}`);
});

// Edot : על הנסים de Pourim au pluriel dans l'Amida, comme dans le Birkat (Kitsour Yalkut Yosef 695:7).
test('Edot : « נסים ונפלאות » dans l\'על הנסים de Pourim de l\'Amida (Cha\'harit, Min\'ha, Arvit)', () => {
  const edot = siddur('edot');
  for (const id of ['chaharit', 'minha', 'arvit']) {
    const blocs = edot.textes.find((t) => t.id === id).sections.flatMap((s) => s.blocs).filter((b) => b.t).map((b) => nu(b.t));
    assert.ok(!blocs.some((t) => t.includes('נס ופלא')), id);
    assert.equal(blocs.filter((t) => t.includes('בימי מרדכי') && t.includes('ועשית עמהם נסים ונפלאות ונודה')).length, 1, id);
  }
});
