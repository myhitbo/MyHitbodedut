// Audit du 16/11, structure des offices (Cha'harit, Min'ha, Arvit, Chema du coucher) : les mêmes
// cas que StructureOfficesTest.kt.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour } from '../src/js/calendrier-juif.js';
import { conditionsPour, enClair, index, plan } from '../src/js/siddur-jour.js';
import { momentOuvrable } from '../src/js/jour-affiche.js';

const raw = (f) => JSON.parse(readFileSync(new URL(`../../android/app/src/main/res/raw/${f}`, import.meta.url), 'utf8'));
const annotations = raw('siddur_annotations.json');
const siddur = { edot: raw('siddur_edot.json'), sefard: raw('siddur_sefard.json'), ashkenaz: raw('siddur_ashkenaz.json') };
const nu = (s) => s.replace(/<[^>]+>/g, ' ').replace(/[֑-ׇ]/g, '').replace(/\s+/g, ' ').trim();
// ישב בסתר suit ויהי נועם (Edot : dans le bloc « שובה »).
const ISHEV = /^ישב( \(תהלים צא\))? בסתר/;
const cond = (nusah, iso, israel = false) => conditionsPour(nusah, israel, jour(iso, israel).conditions);

/** L'état (« du_jour », « replie », « retire », « ordinaire », « libre ») des parties dont un bloc répond à [motif]. */
function etats(nusah, id, iso, motif, israel = false) {
  const texte = siddur[nusah].textes.find((t) => t.id === id);
  const idx = index(annotations[nusah][id]);
  const c = cond(nusah, iso, israel);
  return [...new Set(texte.sections.flatMap((s, si) => plan(s, si, idx, c)
    .filter((p) => p.blocs.some((i) => motif.test(nu(s.blocs[i].t ?? s.blocs[i].c))))
    .map((p) => p.etat)))];
}
/** Les repères du jour (indices sans passage retiré) d'un texte. */
const indices = (nusah, id, iso, israel = false) => {
  const c = cond(nusah, iso, israel);
  return annotations[nusah][id].filter((a) => a.sorte === 'indice' && !a.retire && (a.si.startsWith('!') ? !c.has(a.si.slice(1)) : c.has(a.si))).map((a) => a.texte);
};

test('Mizmor létoda (Sfard, Ashkenaz) : replié le Chabbat, à Pessa\'h, la veille de Pessa\'h et de Kippour', () => {
  for (const nusah of ['sefard', 'ashkenaz']) {
    assert.deepEqual(etats(nusah, 'chaharit', '2026-11-18', /^מזמור לתודה/), ['ordinaire'], nusah);
    for (const iso of ['2026-04-01', '2026-04-05', '2026-09-20', '2026-11-21']) {
      assert.deepEqual(etats(nusah, 'chaharit', iso, /^מזמור לתודה/), ['retire'], `${nusah} ${iso}`);
    }
  }
  assert.ok(cond('ashkenaz', '2025-10-09').has('mizmor_letoda')); // 'Hol hamoed Soukkot : on le dit
});

test('« שעשה לי כל צרכי » (Edot) : la bénédiction en clair le 9 Av, la consigne y donne l\'avis du Yalkut Yosef', () => {
  assert.deepEqual(etats('edot', 'birkot_hachahar', '2026-07-23', /^ברוך.*שעשה לי/), ['libre']);
  assert.deepEqual(etats('edot', 'birkot_hachahar', '2026-07-23', /^בתשעה באב ויום/), ['du_jour']);
  assert.deepEqual(etats('edot', 'birkot_hachahar', '2026-11-18', /^בתשעה באב ויום/), ['retire']);
});

test('Motsaé Chabbat : ויהי נועם replié avant un Yom tov dans la semaine (Sfard, Ashkenaz), pas en Edot', () => {
  // 2026-11-15 : un samedi soir ordinaire ; 2025-09-21 : Roch Hachana le mardi ; 2026-04-05 : 'Hol hamoed.
  for (const nusah of ['sefard', 'ashkenaz', 'edot']) {
    assert.deepEqual(etats(nusah, 'arvit', '2026-11-15', ISHEV), ['du_jour'], nusah);
    assert.deepEqual(etats(nusah, 'arvit', '2026-11-15', /^ואתה קדוש/), ['du_jour'], nusah);
    for (const iso of ['2025-09-21', '2026-04-05']) {
      const attendu = nusah === 'edot' ? 'du_jour' : 'retire';
      assert.deepEqual(etats(nusah, 'arvit', iso, ISHEV), [attendu], `${nusah} ${iso}`);
      assert.deepEqual(etats(nusah, 'arvit', iso, /^ואתה קדוש/), [attendu], `${nusah} ${iso}`);
    }
  }
  // Un samedi soir qui est Yom tov (Séder du 2025-04-12) : ni ויהי נועם ni אתה חוננתנו.
  for (const nusah of ['sefard', 'ashkenaz', 'edot']) assert.deepEqual(etats(nusah, 'arvit', '2025-04-13', ISHEV), ['retire'], nusah);
  assert.ok(!jour('2025-04-13', false).conditions.has('motsae_chabbat_yt'));
});

test('Motsaé Chabbat (Sfard) : עלינו une seule fois', () => {
  const alenou = (iso) => {
    const texte = siddur.sefard.textes.find((t) => t.id === 'arvit');
    const idx = index(annotations.sefard.arvit);
    const c = cond('sefard', iso);
    return texte.sections.flatMap((s, si) => enClair(s, si, idx, c).filter((i) => nu(s.blocs[i].t ?? '').startsWith('עלינו לשבח'))).length;
  };
  assert.equal(alenou('2026-11-15'), 1);
  assert.equal(alenou('2026-11-18'), 1);
  assert.equal(alenou('2025-09-21'), 1);
});

test('Le soir du 9 Av : ואתה קדוש sans ויהי נועם, même un motsaé Chabbat ; תתקבל estompé', () => {
  for (const nusah of ['sefard', 'ashkenaz', 'edot']) {
    for (const iso of ['2025-08-03', '2026-07-23']) {
      assert.deepEqual(etats(nusah, 'arvit', iso, ISHEV), ['retire'], `${nusah} ${iso}`);
      assert.deepEqual(etats(nusah, 'arvit', iso, /^ואתה קדוש/), ['du_jour'], `${nusah} ${iso}`);
    }
  }
  const tit = annotations.sefard.arvit.find((a) => a.sorte === 'bloc' && a.racine === 'veata_kadoch' && a.empreinte.startsWith('תתקבל'));
  assert.equal(tit.si, '!ticha_beav');
});

test('Téfilin : pas à \'Hol hamoed chez les Edot ni en Israël ; sans bénédiction en Ashkenaz de diaspora ; pas le 9 Av au matin', () => {
  assert.deepEqual(etats('edot', 'chaharit', '2026-11-18', /להניח תפלין/), ['ordinaire']);
  for (const [iso, il] of [['2025-10-09', false], ['2025-10-09', true], ['2026-04-09', false], ['2026-11-21', false]]) {
    assert.deepEqual(etats('edot', 'chaharit', iso, /להניח תפלין/, il), ['retire'], `${iso} ${il}`);
  }
  assert.deepEqual(etats('edot', 'chaharit', '2026-07-23', /להניח תפלין/), ['ordinaire']); // Yalkut Yosef 555:1
  assert.deepEqual(etats('ashkenaz', 'chaharit', '2025-10-09', /להניח תפלין/), ['ordinaire']);
  assert.ok(indices('ashkenaz', 'chaharit', '2025-10-09').some((t) => t.includes('בלי ברכה')));
  assert.ok(!indices('ashkenaz', 'chaharit', '2025-10-09', true).some((t) => t.includes('בלי ברכה')));
  assert.deepEqual(etats('ashkenaz', 'chaharit', '2025-10-09', /להניח תפלין/, true), ['retire']);
  assert.deepEqual(etats('ashkenaz', 'chaharit', '2026-07-23', /להתעטף בציצית/), ['retire']);
  assert.deepEqual(etats('ashkenaz', 'chaharit', '2026-11-18', /להתעטף בציצית/), ['ordinaire']);
});

test('Min\'ha des jeûnes : la place de la lecture de la Torah (26/11), à la place des repères qui l\'annonçaient', () => {
  // La haftara selon le rite : web/test/lecture-siddur.test.mjs.
  for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
    const places = annotations[nusah].minha.filter((e) => e.sorte === 'lecture');
    assert.deepEqual(places.map((e) => [e.si, e.office]), [['jeune', 'minha']], nusah);
    assert.ok(!indices(nusah, 'minha', '2025-12-30').some((t) => t.includes('ויחל') || t.includes('דרשו') || t.includes('שובה ישראל')), nusah);
  }
});

test('Cha\'harit du 9 Av : « ואני זאת בריתי » retiré ; פטום הקטורת (Ashkenaz) replié', () => {
  for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
    const a = annotations[nusah].chaharit.find((e) => e.sorte === 'indice' && e.si === '!ticha_beav');
    assert.ok(a && nu(a.retire).startsWith('ואני זאת בריתי') && /עולם[:׃]?$/.test(nu(a.retire)), nusah);
  }
  assert.deepEqual(etats('ashkenaz', 'chaharit', '2026-07-23', /^פטום הקטרת/), ['retire']);
  assert.deepEqual(etats('ashkenaz', 'chaharit', '2026-11-18', /^פטום הקטרת/), ['ordinaire']);
});

test('לדוד ה׳ אורי : Chemini Atséret en Ashkenaz de diaspora ; Edot replié hors d\'Eloul', () => {
  assert.ok(cond('ashkenaz', '2025-10-14').has('ledavid'));
  assert.ok(!cond('ashkenaz', '2025-10-15').has('ledavid')); // Sim'hat Torah
  assert.ok(!cond('sefard', '2025-10-14').has('ledavid') && !cond('ashkenaz', '2025-10-14', true).has('ledavid'));
  // 26/11, Q10 : le Ledavid des Edot (le 'Hida le dit toute l'année) reste replié, non retiré.
  assert.deepEqual(etats('edot', 'chaharit', '2026-01-15', /^לדוד.*יהוה אורי/), ['replie']);
  assert.deepEqual(etats('edot', 'chaharit', '2026-08-20', /^לדוד.*יהוה אורי/), ['ordinaire']);
  assert.ok(indices('ashkenaz', 'minha', '2026-08-20').some((t) => t.includes('משנה ברורה')));
});

test('Edot : ממעמקים à Hochaana Rabba ; Sefer Torah, psaume 22 de Pourim, renvoi à l\'Omer', () => {
  assert.deepEqual(etats('edot', 'chaharit', '2025-10-13', /^שיר המעלות.*ממעמקים/), ['du_jour']);
  assert.deepEqual(etats('edot', 'chaharit', '2025-10-14', /^שיר המעלות.*ממעמקים/), ['retire']);
  assert.ok(indices('edot', 'chaharit', '2026-11-19').some((t) => t.includes('תכ״ג:ו')));
  assert.ok(indices('edot', 'arvit', '2026-03-03').some((t) => t.includes('אילת השחר')));
  assert.ok(!indices('edot', 'arvit', '2026-11-18').some((t) => t.includes('אילת השחר')));
  const r = annotations.edot.arvit.find((a) => a.sorte === 'renvoi' && a.empreinte === 'עלינו');
  assert.equal(r.cible, 'sefirat_haomer');
  assert.equal(r.si, 'omer');
});

test('Ashkenaz : la consigne des Seli\'hot n\'est plus repliée avec le Hallel ; Modim derabanan et Barekhou (minyan)', () => {
  assert.deepEqual(etats('ashkenaz', 'chaharit', '2025-12-30', /בת״צ אומרים סליחות/), ['libre']);
  for (const nusah of ['sefard', 'ashkenaz']) {
    assert.ok(annotations[nusah].chaharit.some((a) => a.si === 'minyan' && a.empreinte.startsWith('כשיגיע שליח צבור')), nusah);
  }
  assert.ok(annotations.edot.arvit.some((a) => a.si === 'minyan' && a.empreinte.startsWith('והקהל עונים')));
});

test('Chema du coucher : Vidouï (Edot), nuit du Séder (Sfard, Ashkenaz), « יהי רצון » le Chabbat (Edot)', () => {
  assert.deepEqual(etats('edot', 'chema_coucher', '2026-11-18', /^אנא יהוה/), ['ordinaire']);
  for (const iso of ['2026-11-21', '2026-11-15', '2027-03-11', '2026-09-12']) {
    assert.deepEqual(etats('edot', 'chema_coucher', iso, /^אנא יהוה/), ['retire'], iso);
  }
  for (const nusah of ['sefard', 'ashkenaz']) {
    assert.deepEqual(etats(nusah, 'chema_coucher', '2027-04-22', /^ישב בסתר/), ['retire'], nusah);
    assert.deepEqual(etats(nusah, 'chema_coucher', '2027-04-23', /^ישב בסתר/), ['retire'], nusah);
    assert.deepEqual(etats(nusah, 'chema_coucher', '2027-04-23', /^ישב בסתר/, true), ['ordinaire'], nusah);
    assert.deepEqual(etats(nusah, 'chema_coucher', '2026-11-18', /^ישב בסתר/), ['ordinaire'], nusah);
    assert.ok(indices(nusah, 'chema_coucher', '2026-11-18').some((t) => t.includes('ביאור הלכה')), nusah);
  }
  const yehi = annotations.edot.chema_coucher.find((a) => a.sorte === 'indice' && a.si === '!chome');
  assert.ok(nu(yehi.retire).startsWith('יהי רצון') && nu(yehi.retire).includes('וחולאים רעים'));
});

test('« Pour cette heure » : pas d\'office de semaine un Chabbat ou un Yom tov', () => {
  assert.equal(momentOuvrable('arvit', '2026-11-20', 20, false), null); // vendredi soir
  assert.equal(momentOuvrable('chaharit', '2026-11-21', 9, false), null);
  assert.equal(momentOuvrable('minha', '2026-09-21', 15, false), null); // Kippour
  assert.equal(momentOuvrable('arvit', '2026-11-21', 20, false), 'arvit'); // motsaé Chabbat
  assert.equal(momentOuvrable('chaharit', '2026-11-18', 9, false), 'chaharit');
  assert.equal(momentOuvrable('chema_coucher', '2026-11-20', 23, false), 'chema_coucher');
});

test('Méguila : שהחיינו la nuit seulement (Edot), « אשר הניא » la nuit seulement (Sfard, Ashkenaz)', async () => {
  const { nuit } = await import('../src/js/calendrier-juif.js');
  const etat = (nusah, deNuit, motif) => {
    const texte = siddur[nusah].textes.find((t) => t.id === 'megila');
    const c = cond(nusah, '2026-03-03');
    if (deNuit) c.add('nuit');
    const idx = index(annotations[nusah].megila);
    return [...new Set(texte.sections.flatMap((s, si) => plan(s, si, idx, c)
      .filter((p) => p.blocs.some((i) => motif.test(nu(s.blocs[i].t ?? s.blocs[i].c)))).map((p) => p.etat)))];
  };
  assert.deepEqual(etat('edot', true, /שהחינו/), ['ordinaire']);
  assert.deepEqual(etat('edot', false, /שהחינו/), ['retire']);
  for (const nusah of ['sefard', 'ashkenaz']) {
    assert.deepEqual(etat(nusah, true, /^א שר הניא/), ['ordinaire'], nusah);
    assert.deepEqual(etat(nusah, false, /^א שר הניא/), ['retire'], nusah);
    assert.deepEqual(etat(nusah, false, /שהחינו/), ['libre'], nusah); // Rema : aussi le jour
    assert.deepEqual(etat(nusah, false, /^ש ושנת יעקב/), ['libre'], nusah);
  }
  assert.equal(nuit(20, null, null), true);
  assert.equal(nuit(10, null, null), false);
  assert.equal(nuit(18, true, false), true);
  assert.equal(nuit(5, false, false), false);
});

// Suite de l'audit du 16/11 : la double annotation (un bloc d'un groupe du jour qui demande aussi le minyan,
// ou un fragment d'un Kaddich qui ne se dit pas tel jour), l'Omer de chaque rite, le Pourim triple.
test('Double annotation : Kaddich des ajouts du jour, תתקבל du 9 Av, fin du Kaddich ashkénaze au motsaé Chabbat', async () => {
  const { segments } = await import('../src/js/siddur-jour.js');
  const segs = (nusah, id, iso, debut) => {
    const texte = siddur[nusah].textes.find((t) => t.id === id);
    const idx = index(annotations[nusah][id]);
    const c = cond(nusah, iso);
    return texte.sections.flatMap((s, si) => plan(s, si, idx, c).filter((p) => p.annotation?.sorte === 'bloc'
      && p.blocs.some((i) => nu(s.blocs[i].t ?? s.blocs[i].c).startsWith(debut)))
      .map((p) => ({ etat: p.etat, segments: segments(p.lus, si, idx, c).map((g) => g.et), n: segments(p.lus, si, idx, c).flatMap((g) => g.blocs).length })));
  };
  // לדוד ה׳ אורי en Eloul (Ashkenaz) : le psaume en clair, son Kaddich replié sous le minyan.
  const ledavid = segs('ashkenaz', 'chaharit', '2026-08-20', 'לדוד יהוה אורי');
  assert.equal(ledavid[0].etat, 'du_jour');
  assert.deepEqual(ledavid[0].segments, [null, 'minyan']);
  // « תתקבל » (Ashkenaz, fin de Cha'harit) : retiré le 9 Av (26/11, sans repli), dans le groupe du minyan.
  const tit = (iso) => segs('ashkenaz', 'chaharit', iso, 'תתקבל')[0];
  assert.ok(!tit('2026-07-23').segments.includes('!ticha_beav') && tit('2026-07-23').n === tit('2026-11-18').n - 1);
  assert.ok(annotations.edot.arvit.some((a) => a.et === '!ticha_beav' && a.empreinte.startsWith('תתקבל')));
  // Ashkenaz, Arvit du motsaé Chabbat : la fin du Kaddich est retirée (26/11), un repère la reprend après ואתה קדוש.
  assert.ok(segs('ashkenaz', 'arvit', '2026-11-15', 'תתקבל')[0].n < segs('ashkenaz', 'arvit', '2026-11-18', 'תתקבל')[0].n);
  assert.ok(annotations.ashkenaz.arvit.some((a) => a.sorte === 'indice' && a.si === 'vihi_noam' && a.texte.includes('תתקבל')));
  // Le Hallel et Birkat halevana : leurs Kaddich repliés (minyan).
  for (const nusah of ['edot', 'sefard']) {
    assert.ok(annotations[nusah].hallel.some((a) => a.si === 'minyan'), nusah);
    assert.ok(annotations[nusah].birkat_halevana.some((a) => a.si === 'minyan'), nusah);
  }
  assert.deepEqual(segs('edot', 'hallel', '2026-11-11', 'תתקבל')[0].segments, ['minyan']);
});

test('Page de l\'Omer : le texte de chaque rite (Sfard « לעמר », Ashkenaz « בעמר »), plus d\'emprunt aux Edot', () => {
  for (const [nusah, mot] of [['sefard', 'לעמר'], ['ashkenaz', 'בעמר']]) {
    const t = siddur[nusah].textes.find((x) => x.id === 'sefirat_haomer');
    assert.equal(t.nusah, undefined, nusah);
    assert.ok(t.source.includes('Metsudah'), nusah);
    assert.ok(t.sections[0].blocs.some((b) => b.t && nu(b.t).includes(`היום יום אחד ${mot}`)), nusah);
  }
});

test('Psaume 22 (Edot) : aussi le jeudi soir d\'un Pourim triple à Jérusalem', () => {
  const c = jour('2025-03-14', true, true).conditions; // vendredi 14 Adar 5785, Jérusalem
  assert.ok(c.has('pourim_triple_vendredi') && !c.has('pourim'));
  assert.ok(!jour('2025-03-14', true, false).conditions.has('pourim_triple_vendredi'));
  assert.ok(annotations.edot.arvit.some((a) => a.sorte === 'indice' && a.si === 'pourim_triple_vendredi' && a.texte.includes('אילת השחר')));
});
