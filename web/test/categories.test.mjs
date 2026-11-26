// Les ajouts du siddour en deux catégories (demande du 26/11, réponses Q1-Q15) : un ajout du calendrier ne s'affiche
// que le jour où il se dit, retiré sans bandeau les autres jours ; un ajout d'occasion reste replié mais visible. Les
// mêmes cas que CategoriesSiddurTest.kt.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { jour, jourDeLaPriere, jourVoisin } from '../src/js/calendrier-juif.js';
import { OCCASIONS, avecAdresse, avecSansTahanoun, conditionsPour, index, plan, segments, signature, texteDuJour } from '../src/js/siddur-jour.js';

const RAW = '../../android/app/src/main/res/raw/';
const lis = (f) => JSON.parse(readFileSync(new URL(RAW + f, import.meta.url), 'utf8'));
const annotations = lis('siddur_annotations.json');
const siddur = Object.fromEntries(['edot', 'sefard', 'ashkenaz'].map((n) => [n, lis(`siddur_${n}.json`)]));
const NUSAH = ['edot', 'sefard', 'ashkenaz'];
const plat = (t) => t.replace(/<[^>]+>/g, '').replace(/[֑-ׇ\s״׳"'()]/g, '');
const c = (iso, israel = false) => jour(iso, israel).conditions;

/**
 * Ce que la lecture montre (SiddurJour.lignes, app.js corpsDe) : les textes en clair, les replis (racine, libellé,
 * « pas aujourd'hui »), et tous les textes une fois les replis ouverts.
 */
function rendu(nusah, id, conditions, { israel = false, voisin = null } = {}) {
  const texte = siddur[nusah].textes.find((t) => t.id === id);
  const idx = index(annotations[nusah][id] ?? []);
  const k = conditionsPour(nusah, israel, conditions);
  const v = voisin ? conditionsPour(nusah, israel, voisin) : new Set();
  const clair = [];
  const tout = [];
  const replis = [];
  const titres = [];
  texte.sections.forEach((s, si) => {
    const texteDe = (i) => plat(texteDuJour(s.blocs[i].t ?? s.blocs[i].c, idx.indices.get(`${si}:${i}`) ?? [], k, v));
    const parts = plan(s, si, idx, k, v);
    if (parts.some((p) => p.etat !== 'retire')) titres.push(plat(s.titre ?? ''));
    for (const p of parts) {
      if (p.etat === 'retire') continue;
      if (p.etat === 'replie') replis.push({ racine: p.racine, libelle: p.libelle ?? p.annotation.libelle ?? null, pasAujourdhui: !!p.pasAujourdhui });
      const segs = p.annotation?.sorte === 'bloc' ? segments(p.lus, si, idx, k, v) : [{ blocs: p.lus }];
      for (const g of segs) {
        if (g.et) replis.push({ racine: g.et, libelle: g.libelle, pasAujourdhui: g.pasAujourdhui });
        for (const i of g.blocs) {
          tout.push(texteDe(i));
          if (p.etat !== 'replie' && !g.et) clair.push(texteDe(i));
        }
      }
    }
  });
  return { clair, tout, replis, titres };
}
const a = (l, p) => l.some((x) => x.includes(plat(p)));

test('semaine : le Birkat sans ajout du jour, les occasions repliées', () => {
  for (const n of NUSAH) {
    const r = rendu(n, 'birkat_hamazon', c('2026-11-17'));
    assert.ok(!a(r.tout, 'רצה והחליצנו') && !a(r.tout, 'יעלה ויבא') && !a(r.tout, 'על הנסים'), n);
    assert.ok(!r.replis.some((x) => x.racine === 'oubli'), n);
    assert.ok(r.replis.some((x) => x.racine === 'zimun' && !x.pasAujourdhui), n);
    assert.ok(r.replis.every((x) => OCCASIONS.has(x.racine) && !x.pasAujourdhui), n);
  }
});

test('Chabbat : Retsé en évidence, l\'oubli replié avec ses lignes du jour (Q5, Q11)', () => {
  for (const n of NUSAH) {
    const r = rendu(n, 'birkat_hamazon', c('2026-11-21'));
    assert.ok(a(r.clair, 'רצה והחליצנו') && r.replis.some((x) => x.racine === 'oubli'), n);
  }
  for (const n of ['sefard', 'ashkenaz']) {
    const r = rendu(n, 'birkat_hamazon', c('2026-11-21'));
    assert.ok(a(r.tout, 'אשר נתן שבתות למנוחה') && !a(r.tout, 'אשר נתן ראשי חדשים'), n);
  }
});

test('Roch \'Hodech : Ya\'alé véyavo avec sa ligne, « מגדול » seul (Sfard, Ashkenaz)', () => {
  for (const n of NUSAH) {
    const r = rendu(n, 'birkat_hamazon', c('2026-10-12'));
    assert.ok(a(r.clair, 'יחדש עלינו את החדש הזה') && a(r.clair, 'יעלה ויבא'), n);
    assert.ok(!a(r.tout, 'חג המצות הזה'), n);
  }
  for (const n of ['sefard', 'ashkenaz']) {
    assert.ok(a(rendu(n, 'birkat_hamazon', c('2026-10-12')).clair, 'מגדול ישועות'), n);
    assert.ok(!a(rendu(n, 'birkat_hamazon', c('2026-10-12')).clair, 'מגדיל ישועות'), n);
    assert.ok(a(rendu(n, 'birkat_hamazon', c('2026-11-17')).clair, 'מגדיל ישועות'), n);
  }
});

test('\'Hanouka et Pourim : Al hanissim avec la seule ligne du jour', () => {
  for (const n of NUSAH) {
    const h = rendu(n, 'chaharit', c('2026-12-07')).clair;
    assert.ok(a(h, 'בימי מתתיה') && !a(h, 'בימי מרדכי ואסתר'), n);
    const p = rendu(n, 'minha', c('2027-03-23')).clair;
    assert.ok(a(p, 'בימי מרדכי ואסתר') && !a(p, 'בימי מתתיה'), n);
  }
});

test('jeûne public : Anénou du particulier en clair, de l\'officiant sous « Avec minyan » ; sinon « Jeûne individuel » (Q2)', () => {
  for (const n of NUSAH) {
    const jeune = rendu(n, 'minha', c('2026-12-20'));
    assert.ok(!jeune.replis.some((x) => x.libelle === 'ajout_jeune_individuel'), n);
    const ordinaire = rendu(n, 'minha', c('2026-12-21'));
    assert.ok(ordinaire.replis.some((x) => x.libelle === 'ajout_jeune_individuel' && !x.pasAujourdhui), n);
    assert.ok(!a(ordinaire.tout, 'השליח ציבור אומר בחזרה') && !a(ordinaire.tout, 'אומר כאן הש״ץ עננו'), n);
  }
});

test('dix jours : la seule formule du jour, Kaddich compris (Q8)', () => {
  for (const n of NUSAH) {
    const t = rendu(n, 'chaharit', c('2027-10-05')).tout;
    const sceau = (f) => t.some((x) => new RegExp(`ברוךאתה[^,:]{4,12},?${f}:?$`).test(x));
    assert.ok(sceau('המלךהקדוש') && !sceau('האלהקדוש'), n);
  }
  assert.ok(a(rendu('sefard', 'chaharit', c('2027-10-05')).tout, 'לעלא ולעלא מכל'));
  assert.ok(!a(rendu('sefard', 'chaharit', c('2027-10-05')).tout, 'לעלא מן כל'));
  assert.ok(a(rendu('ashkenaz', 'chaharit', c('2027-10-05')).tout, 'עושה השלום במרומיו'));
  assert.ok(a(rendu('ashkenaz', 'kaddich', c('2027-10-05')).tout, 'לעלא לעלא מכל ברכתא'));
});

test('Eloul : Ledavid dès le 30 Av (Q13) ; replié en Edot hors d\'Eloul (Q10), retiré ailleurs', () => {
  assert.ok(c('2026-08-13').has('ledavid') && !c('2026-08-12').has('ledavid'));
  for (const n of NUSAH) assert.ok(a(rendu(n, 'chaharit', c('2026-08-13')).clair, 'יהוה אורי וישעי'), n);
  for (const n of ['sefard', 'ashkenaz']) assert.ok(!a(rendu(n, 'chaharit', c('2026-11-17')).tout, 'יהוה אורי וישעי'), n);
  const edot = rendu('edot', 'chaharit', c('2026-11-17'));
  assert.ok(edot.replis.some((x) => x.racine === 'ledavid' && x.pasAujourdhui) && a(edot.tout, 'יהוה אורי וישעי'));
});

test('vendredi soir : Retsé replié entre coucher et sortie, le soir qui suit aussi (Q6)', () => {
  assert.equal(jourVoisin('birkat_hamazon', '2026-11-20', 16, true, false), '2026-11-21');
  assert.equal(jourVoisin('birkat_hamazon', '2026-11-20', 18, true, true), '2026-11-20');
  assert.equal(jourVoisin('meen_chaloch', '2026-11-20', 17, null, null), '2026-11-21');
  assert.equal(jourVoisin('birkat_hamazon', '2026-11-20', 15, null, null), null);
  assert.equal(jourVoisin('chaharit', '2026-11-20', 17, true, false), null);
  for (const n of NUSAH) {
    assert.ok(!rendu(n, 'birkat_hamazon', c('2026-11-20')).replis.some((x) => x.racine === 'chabbat'), n);
    const avec = rendu(n, 'birkat_hamazon', c('2026-11-20'), { voisin: c('2026-11-21') });
    assert.ok(avec.replis.some((x) => x.racine === 'chabbat' && x.pasAujourdhui) && avec.replis.some((x) => x.racine === 'oubli'), n);
    assert.ok(!a(avec.clair, 'רצה והחליצנו'), n);
    assert.ok(rendu(n, 'meen_chaloch', c('2026-11-20'), { voisin: c('2026-11-21') }).replis.some((x) => x.racine === 'chabbat'), n);
  }
});

test('Israël ou diaspora non confirmé : le texte en dépend-il aujourd\'hui (Q7)', () => {
  const depend = (n, id, iso) => {
    const texte = siddur[n].textes.find((t) => t.id === id);
    const idx = index(annotations[n][id]);
    return signature(texte, idx, conditionsPour(n, true, c(iso, true))) !== signature(texte, idx, conditionsPour(n, false, c(iso, false)));
  };
  for (const n of NUSAH) {
    assert.ok(depend(n, 'chaharit', '2027-04-29'), n); // Isrou 'hag en Israël, 8ᵉ jour de Pessa'h en diaspora
    assert.ok(!depend(n, 'chaharit', '2027-01-19'), n);
    assert.ok(depend(n, 'chaharit', '2026-11-17'), n); // ותן טל ומטר
  }
  assert.ok(depend('ashkenaz', 'minha', '2027-06-01') && !depend('sefard', 'minha', '2027-06-01'));
});

test('omer : le compte du soir seulement (Q12)', () => {
  const soir = jourDeLaPriere('sefirat_haomer', '2027-04-29', 21);
  assert.equal(soir, '2027-04-30');
  assert.ok(c(soir).has('omer_8'));
  const compte = /^\S+(ניסן|אייר|סיון)\d+\./;
  for (const n of ['sefard', 'ashkenaz']) {
    const arvit = rendu(n, 'arvit', c(soir)).clair;
    assert.ok(arvit.some((x) => x.includes('8.היום')) && !arvit.some((x) => x.includes('7.היום') || x.includes('9.היום')), n);
    assert.equal(rendu(n, 'sefirat_haomer', c(soir)).clair.filter((x) => compte.test(x)).length, 1, n);
    assert.ok(!rendu(n, 'arvit', c('2026-11-18')).titres.includes(plat('ספירת העומר')), n);
    const hors = rendu(n, 'sefirat_haomer', c('2026-11-18'));
    assert.ok(hors.replis.length === 1 && hors.replis[0].pasAujourdhui, n);
    assert.equal(hors.tout.filter((x) => compte.test(x)).length, 49, n);
  }
  const edot = rendu('edot', 'sefirat_haomer', c(soir)).clair;
  assert.ok(a(edot, 'שמונה ימים לעמר') && !a(edot, 'שבעה ימים לעמר'));
});

test('« Pas de Ta\'hanoun aujourd\'hui » : le Ta\'hanoun retiré, למנצח reste (Q1)', () => {
  const sans = avecSansTahanoun(c('2026-11-16'), true);
  for (const n of NUSAH) {
    const r = rendu(n, 'chaharit', sans).clair;
    assert.ok(!a(r, 'ויאמר דוד אל גד') && !a(r, 'אנשי אמונה אבדו'), n);
    assert.ok(a(r, 'יענך יהוה ביום צרה'), n);
  }
  assert.ok(!rendu('sefard', 'chaharit', sans).titres.includes(plat('תחנון')));
});

test('le voyageur (Q3), l\'oubli (Q5), les usages datés (Q14), qui prie seul (Q4)', () => {
  for (const n of ['edot', 'ashkenaz']) {
    assert.ok(rendu(n, 'chaharit', c('2026-11-17')).replis.some((x) => x.libelle === 'ajout_voyageur_tal_oumatar'), n);
    assert.ok(!rendu(n, 'chaharit', c('2027-01-19')).replis.some((x) => x.libelle === 'ajout_voyageur_tal_oumatar'), n);
  }
  for (const n of NUSAH) {
    const oubli = (iso) => rendu(n, 'chaharit', c(iso)).tout.some((x) => x.includes('משיבהרוח') && x.includes('טעה'));
    assert.ok(oubli('2027-01-19') && !oubli('2027-06-01'), n);
  }
  assert.ok(rendu('edot', 'arvit', c('2026-10-12')).replis.some((x) => x.libelle === 'ajout_roch_hodech_usage'));
  assert.ok(!rendu('edot', 'arvit', c('2026-11-18')).replis.some((x) => x.libelle === 'ajout_roch_hodech_usage'));
  assert.ok(rendu('sefard', 'arvit', c('2026-11-18', true), { israel: true }).replis.some((x) => x.libelle === 'ajout_israel_usage'));
  assert.ok(!rendu('sefard', 'arvit', c('2026-11-18')).replis.some((x) => x.libelle === 'ajout_israel_usage'));
  for (const n of ['sefard', 'ashkenaz']) {
    const r = rendu(n, 'chaharit', c('2026-11-17'));
    assert.ok(r.replis.some((x) => x.racine === 'sans_minyan') && !a(r.clair, 'אל מלך נאמן'), n);
  }
});

test('l\'homme et la femme : la seule forme du réglage צדיק / צדקת (Q12)', () => {
  for (const n of NUSAH) {
    const f = rendu(n, 'birkot_hachahar', avecAdresse(c('2026-11-17'), 'f')).clair;
    const m = rendu(n, 'birkot_hachahar', avecAdresse(c('2026-11-17'), 'm')).clair;
    const aucun = rendu(n, 'birkot_hachahar', c('2026-11-17')).clair;
    assert.ok(a(f, 'שעשני כרצונו') && !a(f, 'שלא עשני אשה'), n);
    assert.ok(a(m, 'שלא עשני אשה') && !a(m, 'שעשני כרצונו'), n);
    assert.ok(a(aucun, 'שלא עשני אשה') && a(aucun, 'שעשני כרצונו'), n);
  }
  const e = rendu('edot', 'birkot_hachahar', avecAdresse(c('2026-11-17'), 'f')).clair;
  assert.ok(a(e, 'שלא עשני גויה') && !a(e, 'האשה אומרת'));
});

test('les textes d\'occasion ajoutés : brit mila, maison endeuillée, Mi chébérakh (Q15)', () => {
  for (const n of ['sefard', 'ashkenaz']) {
    assert.ok(rendu(n, 'birkat_hamazon', c('2026-11-16')).replis.some((x) => x.libelle === 'ajout_brit_mila'), n);
    const r = rendu(n, 'chaharit', c('2026-11-16'));
    for (const lib of ['ajout_mi_cheberakh_oleh', 'ajout_mi_cheberakh_malade', 'ajout_mi_cheberakh_yoledet', 'ajout_hagomel']) {
      assert.ok(r.replis.some((x) => x.libelle === lib), `${n} ${lib}`);
    }
    assert.ok(!r.tout.find((x) => x.includes('בעבורשעלהלתורה')).includes('ולכבודהשבת'), n);
  }
  const edot = rendu('edot', 'birkat_hamazon', c('2026-11-16'));
  assert.equal(edot.replis.filter((x) => x.racine === 'beit_avel').length, 3);
  assert.ok(a(edot.tout, 'מנחם אבלים שאכלנו משלו'));
});
