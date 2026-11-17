import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calendrier, levana, phaseLune, usageLevana } from '../src/js/calendrier-juif.js';
import { jour as zmanim } from '../src/js/zmanim.js';

const JER = { nom: 'Jérusalem', latitude: 31.76904, longitude: 35.21633, altitude: 0, fuseau: 'Asia/Jerusalem' };
const PARIS = { nom: 'Paris', latitude: 48.85341, longitude: 2.3488, altitude: 0, fuseau: 'Europe/Paris' };
/** Les options d'un lieu, comme optionsLevana() de app.js : tsét, lever du soleil, Israël ou non. */
const ici = (lieu, usage, enIsrael = lieu === JER) => ({
  usage, enIsrael,
  tset: (d) => +zmanim(lieu, d).find((x) => x.cle === 'tset').instant,
  netz: (d) => +zmanim(lieu, d).find((x) => x.cle === 'netz').instant,
});

// Audit du 16/11 : le dernier soir est celui dont la nuit (tsét) commence avant la fin (CA 426:3 ; YY 426:37).
test('Birkat haLevana (audit du 16/11) : le dernier soir d’après la tsét', () => {
  for (const usage of ['sept_quinze', 'sept_nuit_quinze']) {
    assert.equal(levana('2025-12-03', 'Europe/Paris', ici(PARIS, usage)).dernier, '2025-12-04');
    assert.equal(levana('2025-12-03', 'Asia/Jerusalem', ici(JER, usage)).dernier, '2025-12-04');
    assert.equal(levana('2026-01-30', 'Asia/Jerusalem', ici(JER, usage)).dernier, '2026-02-01');
  }
  assert.equal(levana('2026-05-28', 'Europe/Paris', ici(PARIS, 'trois_mi_mois')).dernier, '2026-05-30');
  assert.equal(typeof levana('2026-05-31', 'Europe/Paris', ici(PARIS, 'trois_mi_mois')).etat, 'object');
});

// Audit du 16/11 : le Yalkut Yosef compte d'après la date, jamais la nuit du 16, encore la nuit du 15 (YY 426:28 et 37).
test('Birkat haLevana (audit du 16/11) : Edot, jusqu’à la nuit du 15 incluse', () => {
  // Tichri 5785 : le 17/10/2024 au soir est la nuit du 16 Tichri.
  assert.equal(levana('2024-10-14', 'Asia/Jerusalem', ici(JER, 'sept_quinze')).dernier, '2024-10-17');
  assert.equal(levana('2024-10-14', 'Asia/Jerusalem', ici(JER, 'sept_nuit_quinze')).dernier, '2024-10-16');
  // Adar I 5787 à Paris : la nuit du 15 (21/02/2027) est encore permise.
  assert.equal(levana('2027-02-18', 'Europe/Paris', ici(PARIS, 'sept_quinze')).dernier, '2027-02-20');
  assert.equal(levana('2027-02-18', 'Europe/Paris', ici(PARIS, 'sept_nuit_quinze')).dernier, '2027-02-21');
  // Jamais la nuit du 16, sur deux ans, à Jérusalem et à Paris.
  for (const [lieu, zone] of [[JER, 'Asia/Jerusalem'], [PARIS, 'Europe/Paris']]) {
    for (let m = 0; m < 24; m++) {
      const d = new Date(Date.UTC(2026, m, 3, 12)).toISOString().slice(0, 10);
      const l = levana(d, zone, ici(lieu, 'sept_nuit_quinze'));
      const lendemain = new Date(Date.parse(`${l.dernier}T12:00:00Z`) + 86400000).toISOString().slice(0, 10);
      assert.ok(calendrier(lendemain, false, false, false).getJewishDayOfMonth() <= 15, `${d} : ${l.dernier}`);
    }
  }
});

// Audit du 16/11 : pas le soir de Chabbat ni de Yom tov, sauf le dernier (MB 426:12 ; YY 426:33).
test('Birkat haLevana (audit du 16/11) : ni Chabbat ni Yom tov, sauf le dernier soir', () => {
  const edot = levana('2026-04-24', 'Asia/Jerusalem', ici(JER, 'sept_nuit_quinze'));
  assert.deepEqual(edot.etat, { pas: 'chabbat' });
  assert.equal(edot.premierPossible, '2026-04-25');
  assert.deepEqual(levana('2026-04-24', 'Asia/Jerusalem', ici(JER, 'sept_mi_mois')).etat, { pas: 'chabbat' });
  assert.deepEqual(levana('2027-06-11', 'Europe/Paris', ici(PARIS, 'trois_mi_mois')).etat, { pas: 'chabbat' });
  // Le 2e soir de Chavouot ne compte qu'en diaspora.
  assert.deepEqual(levana('2029-05-20', 'Europe/Paris', ici(PARIS, 'trois_mi_mois')).etat, { pas: 'yom_tov' });
  assert.equal(levana('2029-05-20', 'Europe/Paris', { ...ici(PARIS, 'trois_mi_mois'), enIsrael: true }).etat, 'ce_soir');
  // Un dernier soir qui tombe un vendredi reste « dernier ».
  let vus = 0;
  for (let m = 0; m < 36; m++) {
    const d = new Date(Date.UTC(2026, m, 1, 12)).toISOString().slice(0, 10);
    const l = levana(d, 'Asia/Jerusalem', ici(JER, 'trois_mi_mois'));
    if (new Date(`${l.dernier}T12:00:00Z`).getUTCDay() === 5) { vus++; assert.equal(levana(l.dernier, 'Asia/Jerusalem', ici(JER, 'trois_mi_mois')).etat, 'dernier'); }
  }
  assert.ok(vus > 0);
});

// Audit du 16/11 : la sortie de Kippour et du 9 Av à la tsét du lieu ; goûter d'abord à la sortie des autres jeûnes.
test('Birkat haLevana (audit du 16/11) : sortie du 9 Av à la tsét, 10 Tévèt', () => {
  const av = levana('2026-07-20', 'Europe/Paris', ici(PARIS, 'trois_mi_mois'));
  assert.equal(av.restriction, 'tisha_beav');
  assert.ok(av.debutMs >= Date.parse('2026-07-23T22:30:00+02:00'), new Date(av.debutMs).toISOString());
  assert.equal(levana('2025-12-30', 'Europe/Paris', ici(PARIS, 'trois_mi_mois')).jeune, true);
  assert.equal(levana('2026-12-20', 'Europe/Paris', ici(PARIS, 'trois_mi_mois')).jeune, true);
  assert.equal(levana('2025-12-29', 'Europe/Paris', ici(PARIS, 'trois_mi_mois')).jeune, false);
});

// 'Hechvan 5787 : du 18 au 25 octobre 2026 au soir, comme CalJ (LevanaTest.kt).
test('Birkat haLevana, Hechvan 5787', () => {
  const l = levana('2026-10-14', 'Asia/Jerusalem');
  assert.equal(l.premier, '2026-10-18');
  assert.equal(l.dernier, '2026-10-25');
  assert.deepEqual(l.etat, { dans: 4 });
  assert.ok(l.debut < l.point === false && l.debut < l.fin);
  assert.equal(levana('2026-10-18', 'Asia/Jerusalem').etat, 'ce_soir');
  assert.equal(levana('2026-10-25', 'Asia/Jerusalem').etat, 'dernier');
  assert.ok(levana('2026-10-26', 'Asia/Jerusalem').premier > '2026-11-01');
});

// Audit du 12/11, FCALENDRIER-03 : quand la fenêtre se ferme l'après-midi, le dernier soir est la veille (LevanaTest.kt).
test('Birkat haLevana, Kislev 5787 : la mi-mois tombe l’après-midi du 24/11 à Paris, dernier soir le 23', () => {
  const paris = 'Europe/Paris';
  for (const usage of ['trois_mi_mois', 'sept_mi_mois']) {
    const l = levana('2026-11-20', paris, { usage });
    assert.equal(l.dernier, '2026-11-23');
    assert.equal(levana('2026-11-23', paris, { usage }).etat, 'dernier');
    assert.equal(levana('2026-11-22', paris, { usage }).etat, 'ce_soir');
    assert.ok(l.finMs < Date.parse('2026-11-24T20:00:00+01:00'));
    assert.equal(typeof levana('2026-11-24', paris, { usage }).etat, 'object', 'le 24, la fenêtre suivante');
  }
  assert.equal(levana('2026-11-20', paris, { usage: 'sept_quinze' }).dernier, '2026-11-24');
  assert.equal(levana('2026-11-20', 'America/New_York', { usage: 'sept_quinze' }).dernier, '2026-11-23');
});

// Revue du 14/10 sur le texte (Choulhan Aroukh O.H. 426 ; Michna Beroura 426), mêmes valeurs que LevanaTest.kt.
test('Birkat haLevana : usages, motsaé Chabbat, Kippour, Tich\'a beAv', () => {
  const z = 'Asia/Jerusalem';
  const trois = levana('2026-10-14', z, { usage: 'trois_mi_mois' });
  assert.equal(trois.premier, '2026-10-14');
  assert.equal(trois.dernier, '2026-10-25');
  assert.equal(trois.motsae, '2026-10-17');
  const quinze = levana('2026-10-14', z, { usage: 'sept_quinze' });
  assert.equal(quinze.premier, '2026-10-18');
  assert.ok(quinze.finMs > trois.finMs);
  assert.equal(levana('2026-10-14', z, { usage: 'sept_mi_mois' }).motsae, null);
  const tichri = levana('2026-09-15', z, { usage: 'trois_mi_mois' });
  assert.equal(tichri.premier, '2026-09-21');
  assert.equal(tichri.restriction, 'kippour');
  const av = levana('2026-07-20', z, { usage: 'trois_mi_mois' });
  assert.equal(av.premier, '2026-07-23');
  assert.equal(av.restriction, 'tisha_beav');
  assert.equal(usageLevana('edot'), 'sept_nuit_quinze');
  assert.equal(usageLevana('sefard'), 'sept_mi_mois');
  assert.equal(usageLevana('ashkenaz'), 'trois_mi_mois');
  assert.equal(usageLevana('edot', 'trois_mi_mois'), 'trois_mi_mois');
});

test('la lune : nouvelle, premier quartier, pleine', () => {
  assert.ok(phaseLune(Date.parse('2026-10-10T12:00:00Z')).eclairage < 0.01);
  const q = phaseLune(Date.parse('2026-10-18T12:00:00Z'));
  assert.ok(q.eclairage > 0.4 && q.eclairage < 0.6 && q.croissante);
  assert.ok(phaseLune(Date.parse('2026-10-26T12:00:00Z')).eclairage > 0.99);
});
