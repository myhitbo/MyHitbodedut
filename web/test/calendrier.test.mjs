// Le calendrier hébraïque, les ajouts de prière et les zmanim du web (10/10).
//
// Trois familles de vérifications, séparées exprès :
//  1. fidélité du portage : le web répond exactement ce que le code Android
//     (KosherJava 2.5.0) répond, jour par jour de 2025 à 2030, en Israël et
//     en diaspora, et à une seconde près pour les zmanim ;
//  2. comparaison avec Hebcal (@hebcal/core 6.14.1, dépendance de test
//     seulement, jamais servie) : là où les méthodes sont réellement les mêmes,
//     les deux moteurs doivent s'accorder ; là où elles diffèrent, l'écart est
//     nommé et borné ici. L'accord de deux moteurs n'est pas une preuve
//     d'exactitude ;
//  3. la règle d'Arvit le soir.
// Les validations halakhiques, elles, reviennent à un Rav (ZMANIM.md).

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { flags, HDate, HebrewCalendar, tachanun, GeoLocation as HGeo, Zmanim as HZmanim } from '@hebcal/core';
import { jour, jourDeLaPriere, TOUTES } from '../src/js/calendrier-juif.js';
import * as Z from '../src/js/zmanim.js';

const ICI = dirname(fileURLToPath(import.meta.url));
const VECTEURS = JSON.parse(readFileSync(join(ICI, 'vecteurs_kosherjava.json'), 'utf8'));

// --- 1. Fidélité au code Android ---------------------------------------------------
test('chaque jour de 2025 à 2030 : la même réponse que KosherJava', () => {
  let n = 0;
  for (const [cle, attendu] of Object.entries(VECTEURS.jours)) {
    const [iso, il] = cle.split('/');
    const j = jour(iso, il === 'il');
    assert.deepEqual({
      h: [j.jourHebreu, j.moisHebreu, j.anneeHebraique], t: j.dateHebraique, f: j.fetes, o: j.omer,
      p: j.paracha, x: j.chome, c: TOUTES.filter((c) => j.conditions.has(c)),
    }, attendu, cle);
    n++;
  }
  assert.equal(n, 3896);
});

test('zmanim : la même heure que KosherJava, à une seconde près, et les mêmes absences', () => {
  for (const r of VECTEURS.zmanim) {
    const lieu = { nom: r.lieu, latitude: r.lat, longitude: r.lon, altitude: 0, fuseau: r.fuseau };
    for (const z of [...Z.jour(lieu, r.date), Z.allumage(lieu, r.date, 18)]) {
      const attendu = r[z.cle];
      const ou = `${r.lieu} ${r.date} ${z.cle}`;
      assert.notEqual(z.statut, 'erreur', ou);
      if (attendu === 'ABSENT') { assert.equal(z.statut, 'absent', ou); continue; }
      assert.equal(z.statut, 'ok', ou);
      assert.ok(Math.abs(+z.instant - Date.parse(attendu)) <= 1000, `${ou} : ${z.instant.toISOString()} contre ${attendu}`);
    }
  }
});

test('zmanim des Edot et heures du ’hamets : la même heure que KosherJava, à une seconde près (audit du 16/11)', () => {
  let n = 0;
  for (const r of VECTEURS.zmanim) {
    const lieu = { nom: r.lieu, latitude: r.lat, longitude: r.lon, altitude: 0, fuseau: r.fuseau };
    const edot = Z.jour(lieu, r.date, 'edot').filter((z) => Z.CLES_EDOT.includes(z.cle)).map((z) => [`edot_${z.cle}`, z]);
    const hamets = ['edot', ''].flatMap((nusah) => Z.hamets(lieu, r.date, nusah).map((z, i) => [`hamets_${i}_${nusah || 'commun'}`, z]));
    for (const [cle, z] of [...edot, ...hamets]) {
      const attendu = r[cle];
      const ou = `${r.lieu} ${r.date} ${cle}`;
      assert.ok(attendu, ou);
      if (attendu === 'ABSENT') { assert.equal(z.statut, 'absent', ou); continue; }
      assert.equal(z.statut, 'ok', ou);
      assert.ok(Math.abs(+z.instant - Date.parse(attendu)) <= 1000, `${ou} : ${z.instant.toISOString()} contre ${attendu}`);
      n++;
    }
  }
  assert.ok(n > 500, `${n}`);
});

test('Edot : les zmanim du Yalkut Yosef, avec les écarts relevés par l’audit du 16/11', () => {
  const [jer, paris, ny] = LIEUX;
  const t = (l, iso, cle, nusah) => Z.jour(l, iso, nusah).find((z) => z.cle === cle).instant;
  const ecart = (l, iso, cle) => (+t(l, iso, cle, 'edot') - +t(l, iso, cle)) / 60e3;
  const hms = (d, f) => new Intl.DateTimeFormat('fr-FR', { timeZone: f, timeStyle: 'medium' }).format(d);
  // Aube à 72 min zmaniyot (Kitsour YY 89:12) : Jérusalem 2026-12-19, 05:33:20 contre 05:15:56 à 16,1°.
  assert.equal(hms(t(jer, '2026-12-19', 'alot', 'edot'), jer.fuseau).slice(0, 5), '05:33');
  // Plag du Yalkut Yosef (263:45) : 18:34:19 contre 18:18:18 selon le Gra, Jérusalem 2026-06-19.
  assert.equal(hms(t(jer, '2026-06-19', 'plag', 'edot'), jer.fuseau).slice(0, 5), '18:34');
  assert.ok(Math.abs(ecart(paris, '2026-06-20', 'plag') - 18.2) < 0.5);
  // Maguen Avraham en 72 min zmaniyot : Jérusalem 2026-06-20, 08:24:38 contre 08:31:19.
  assert.equal(hms(t(jer, '2026-06-20', 'szks_mga', 'edot'), jer.fuseau).slice(0, 5), '08:24');
  // Rabbénou Tam en zmaniyot : New York 2026-06-20, 22:01:07 contre 21:42:33.
  assert.equal(hms(t(ny, '2026-06-20', 'tset_rt', 'edot'), ny.fuseau).slice(0, 5), '22:01');
  // Le profil commun (Sfard, Ashkenaz) ne bouge pas.
  for (const nusah of ['sefard', 'ashkenaz']) assert.deepEqual(Z.jour(jer, '2026-06-20', nusah), Z.jour(jer, '2026-06-20'));
});

test('le profil web est celui d’Android, dans le même ordre', () => {
  const kotlin = readFileSync(join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'java', 'com', 'myhitbodedut', 'Zmanim.kt'), 'utf8');
  const [commun, edot] = kotlin.split('val PROFIL_EDOT');
  const cles = (texte) => [...texte.matchAll(/^\s+"([a-z_]+)" to Methode\(/gm)].map(([, c]) => c);
  assert.deepEqual(Z.CLES, cles(commun));
  // Le profil des Edot (audit du 16/11) : les mêmes lignes remplacées des deux côtés.
  assert.deepEqual(Z.CLES_EDOT, cles(edot.split('\n    )')[0]));
});

// --- 2. Hebcal, moteur de comparaison ------------------------------------------------
function chaqueJour(f) {
  for (let t = Date.UTC(2025, 8, 1); t <= Date.UTC(2030, 11, 31); t += 864e5) {
    const iso = new Date(t).toISOString().slice(0, 10);
    const [a, m, d] = iso.split('-').map(Number);
    for (const il of [false, true]) f(iso, il, new HDate(new Date(a, m - 1, d)), new Date(t).getUTCDay());
  }
}

test('Hebcal : mêmes dates hébraïques, mêmes Roch ’Hodech, mêmes jeûnes publics', () => {
  chaqueJour((iso, il, hd) => {
    const j = jour(iso, il);
    assert.deepEqual([j.jourHebreu, j.anneeHebraique], [hd.getDate(), hd.getFullYear()], iso);
    const ev = HebrewCalendar.getHolidaysOnDate(hd, il) ?? [];
    assert.equal(j.fetes.includes('roch_hodech'), ev.some((e) => e.getFlags() & flags.ROSH_CHODESH), `${iso} ${il}`);
    // Hebcal range aussi parmi les jeûnes mineurs les jeûnes volontaires
    // (BaHaB, Yom Kippour katan, jeûne des premiers-nés), et la veille de Tich'a bèAv dont le jeûne ne commence que le soir : ils n'appellent pas Anénou dans le siddour.
    const publics = ev.filter((e) => (e.getFlags() & (flags.MAJOR_FAST | flags.MINOR_FAST))
      && !/BeHaB|Katan|Bechorot|^Erev/.test(e.getDesc()));
    assert.equal(j.conditions.has('jeune') || j.fetes.includes('yom_kippour'), publics.length > 0, `${iso} ${il}`);
  });
});

test('Hebcal : Ta’hanoun, les écarts sont des coutumes, sauf le 15 Adar I, consigné', () => {
  const coutumes = [];
  const tranches = [];
  chaqueJour((iso, il, hd, semaine) => {
    if (semaine === 6) return;
    const h = tachanun(hd, il);
    const nous = jour(iso, il).conditions.has('tahanoun_chaharit');
    if (h.shacharit === nous) return;
    if (!h.allCongs) coutumes.push(iso);
    else tranches.push(`${iso} ${hd.getMonthName()} ${hd.getDate()}`);
  });
  // Hebcal dit lui-même « certaines communautés » pour chacun de ces jours.
  assert.ok(coutumes.length > 0 && coutumes.length < 100, `${coutumes.length}`);
  // Un seul vrai désaccord : Chouchan Pourim katan. KosherJava, moteur
  // retenu, suit le Choul'han Aroukh (OC 697:1 : ni Ta'hanoun le 14 ni le 15
  // Adar I) ; Hebcal le fait dire partout. Le résultat de KosherJava est
  // gardé, l'écart est écrit dans ZMANIM.md.
  assert.deepEqual([...new Set(tranches.map((t) => t.split(' ').slice(1).join(' ')))], ['Adar I 15']);
});

const LIEUX = [
  { nom: 'Jérusalem', latitude: 31.76904, longitude: 35.21633, altitude: 0, fuseau: 'Asia/Jerusalem' },
  { nom: 'Paris', latitude: 48.85341, longitude: 2.3488, altitude: 0, fuseau: 'Europe/Paris' },
  { nom: 'New York', latitude: 40.71427, longitude: -74.00597, altitude: 0, fuseau: 'America/New_York' },
  { nom: 'Melbourne', latitude: -37.814, longitude: 144.96332, altitude: 0, fuseau: 'Australia/Melbourne' },
];

test('chaque zman tombe le jour civil demandé, dans les 51 villes (FCALENDRIER-02, Sydney)', async () => {
  const { villes } = JSON.parse(readFileSync(join(ICI, '../../android/app/src/main/res/raw/villes.json'), 'utf8'));
  const lieu = (v) => ({ nom: v.nom.fr, latitude: v.latitude, longitude: v.longitude, altitude: v.altitude, fuseau: v.fuseau });
  const jourCivil = (t, fuseau) => new Intl.DateTimeFormat('en-CA', { timeZone: fuseau }).format(t);
  const auckland = { nom: 'Auckland', latitude: -36.85, longitude: 174.76, altitude: 0, fuseau: 'Pacific/Auckland' };
  for (const l of [...villes.map(lieu), auckland]) {
    for (const iso of ['2026-01-15', '2026-04-05', '2026-06-21', '2026-10-04', '2026-12-21', '2027-04-03']) {
      for (const z of Z.jour(l, iso)) {
        if (z.instant && z.cle !== 'chatsot_layla') assert.equal(jourCivil(z.instant, l.fuseau), iso, `${l.nom} ${iso} ${z.cle}`);
      }
    }
  }
  // KosherJava 2.5.0 : Sydney, netz du 21/06/2026 à 06:59:57 ; sortie de Chabbat du 03/04/2027 à 19:25:21.
  const sydney = lieu(villes.find((v) => v.nom.fr === 'Sydney'));
  const { horaires } = await import('../src/js/jour-affiche.js');
  const heure = (t) => new Intl.DateTimeFormat('fr-FR', { timeZone: sydney.fuseau, timeStyle: 'medium' }).format(t);
  assert.equal(heure(Z.jour(sydney, '2026-06-21').find((z) => z.cle === 'netz').instant), '06:59:57');
  assert.equal(heure(horaires(sydney, '2027-04-03', false, 18).find((z) => z.cle === 'sortie').instant), '19:25:21');
});

test('Hebcal : les zmanim de même méthode s’accordent à 5 secondes près', () => {
  // [clé du profil, méthode Hebcal réellement équivalente]
  const paires = [
    ['netz', (h) => h.seaLevelSunrise()], ['chkia', (h) => h.seaLevelSunset()],
    ['alot', (h) => h.alotHaShachar()], ['misheyakir', (h) => h.misheyakir()],
    ['szks_gra', (h) => h.sofZmanShma()], ['szks_mga', (h) => h.sofZmanShmaMGA()],
    ['szt_gra', (h) => h.sofZmanTfilla()], ['szt_mga', (h) => h.sofZmanTfillaMGA()],
    ['minha_gedola', (h) => h.minchaGedola()], ['minha_ketana', (h) => h.minchaKetana()],
    ['plag', (h) => h.plagHaMincha()], ['tset', (h) => h.tzeit(8.5)], ['tset_rt', (h) => h.tzeit72()],
  ];
  for (const lieu of LIEUX) {
    for (const iso of ['2026-01-15', '2026-03-29', '2026-06-21', '2026-10-25', '2026-12-21']) {
      const [a, m, d] = iso.split('-').map(Number);
      const h = new HZmanim(new HGeo(lieu.nom, lieu.latitude, lieu.longitude, 0, lieu.fuseau), new Date(a, m - 1, d), false);
      const z = Object.fromEntries(Z.jour(lieu, iso).map((x) => [x.cle, x]));
      for (const [cle, f] of paires) {
        const v = f(h);
        // tzeit72 rend un Temporal.ZonedDateTime, les autres une Date.
        const ecart = Math.abs(+z[cle].instant - (v instanceof Date ? +v : v.epochMilliseconds)) / 1000;
        assert.ok(ecart <= 5, `${lieu.nom} ${iso} ${cle} : ${ecart} s`);
      }
      // ’Hatsot n'est PAS la même méthode : Hebcal prend le milieu du lever
      // et du coucher, KosherJava 2.5.0 le passage au méridien. Jamais de
      // moyenne : on vérifie seulement que l'écart reste celui de la
      // définition (moins de deux minutes à ces latitudes).
      const milieu = (+z.netz.instant + +z.chkia.instant) / 2;
      assert.ok(Math.abs(milieu - +h.chatzot()) <= 2000, `${lieu.nom} ${iso} milieu du jour`);
      assert.ok(Math.abs(+z.chatsot.instant - +h.chatzot()) < 120_000, `${lieu.nom} ${iso} chatsot`);
    }
  }
});

// --- 3. Arvit le soir ------------------------------------------------------------------
test('Arvit et le Chema du coucher relèvent du jour hébreu suivant dès l’après-midi', () => {
  assert.equal(jourDeLaPriere('arvit', '2026-10-10', 19), '2026-10-11');
  assert.equal(jourDeLaPriere('chema_coucher', '2026-12-31', 23), '2027-01-01');
  assert.equal(jourDeLaPriere('arvit', '2026-10-10', 0), '2026-10-10');
  assert.equal(jourDeLaPriere('minha', '2026-10-10', 17), '2026-10-10');
  // Après la sortie des étoiles (28/10) : Birkat haMazon relève de demain ; Min'ha non.
  assert.equal(jourDeLaPriere('birkat_hamazon', '2026-10-10', 19, true), '2026-10-11');
  assert.ok(!jour(jourDeLaPriere('birkat_hamazon', '2026-10-10', 19, true), false).conditions.has('chabbat'));
  assert.equal(jourDeLaPriere('minha', '2026-10-10', 19, true), '2026-10-10');
  // Samedi soir : le dimanche, d'où la section de motsaé Chabbat.
  assert.ok(jour(jourDeLaPriere('arvit', '2026-10-10', 20), false).conditions.has('motsae_chabbat'));
});

test('soleil de minuit à Tromsø : absent, jamais en erreur', () => {
  const tromso = { nom: 'Tromsø', latitude: 69.6492, longitude: 18.9553, altitude: 0, fuseau: 'Europe/Oslo' };
  const z = Object.fromEntries(Z.jour(tromso, '2026-06-21').map((x) => [x.cle, x]));
  assert.equal(z.netz.statut, 'absent');
  assert.equal(z.chkia.statut, 'absent');
  assert.ok(Object.values(z).every((x) => x.statut !== 'erreur'));
});

// --- 4. Les annotations du siddour ---------------------------------------------------
test('siddour : chaque annotation désigne encore son bloc, et chaque libellé existe', async () => {
  const { empreinte, libelle, vrai, DERIVEES } = await import('../src/js/siddur-jour.js');
  const raw = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res');
  const annotations = JSON.parse(readFileSync(join(raw, 'raw', 'siddur_annotations.json'), 'utf8'));
  const chaines = readFileSync(join(raw, 'values', 'strings.xml'), 'utf8');
  for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
    const siddur = JSON.parse(readFileSync(join(raw, 'raw', `siddur_${nusah}.json`), 'utf8'));
    for (const [id, liste] of Object.entries(annotations[nusah])) {
      const texte = siddur.textes.find((t) => t.id === id);
      for (const a of liste) {
        const section = texte.sections[a.s];
        const vu = a.b === undefined ? empreinte(section.titre) : empreinte(section.blocs[a.b].t ?? section.blocs[a.b].c);
        assert.equal(vu, a.empreinte, `${nusah}/${id} §${a.s}/${a.b}`);
        assert.ok([...TOUTES, ...DERIVEES].includes(a.si.replace(/^!/, '')), a.si);
        assert.ok(chaines.includes(`name="${libelle(a.si)}"`), libelle(a.si));
        if (a.libelle) assert.ok(chaines.includes(`name="${a.libelle}"`), a.libelle);
      }
    }
  }
  assert.equal(vrai('!tahanoun_minha', new Set(['chabbat'])), true);
  assert.equal(vrai('!tahanoun_minha', new Set(['tahanoun_minha'])), false);
  // Anénou (Rema OC 565:3) : l'officiant dans les trois noussa'him, sous « Avec minyan » les jours de jeûne public
  // (26/11, Q2 : si « minyan », quand « jeune ») ; le particulier à Cha'harit seulement dans le siddour Edot.
  const anenou = (nusah, id) => annotations[nusah][id].map((a) => a.libelle).filter((l) => l?.startsWith('ajout_anenou'));
  const officiant = (nusah, id) => annotations[nusah][id].some((a) => a.si === 'minyan' && a.quand === 'jeune');
  for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
    assert.ok(officiant(nusah, 'chaharit'), nusah);
    assert.ok(officiant(nusah, 'minha') && anenou(nusah, 'minha').includes('ajout_anenou_particulier'), nusah);
    assert.equal(anenou(nusah, 'chaharit').includes('ajout_anenou_particulier'), nusah === 'edot', nusah);
  }
  // Roch 'Hodech (12/10) : Cha'harit renvoie au Hallel puis au Moussaf, textes présents dans chaque siddour.
  const { index } = await import('../src/js/siddur-jour.js');
  for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
    const siddur = JSON.parse(readFileSync(join(raw, 'raw', `siddur_${nusah}.json`), 'utf8'));
    // Les rappels (audit du 16/11) sont des renvois sans cible : hors de ce compte.
    const renvois = [...index(annotations[nusah].chaharit).renvois.values()].flat().filter((a) => a.cible);
    assert.deepEqual(renvois.map((a) => a.cible), ['hallel', 'moussaf_rosh_hodech'], nusah);
    for (const a of renvois) assert.ok(siddur.textes.some((t) => t.id === a.cible), `${nusah} ${a.cible}`);
    // Audit du 16/11 : pas le Moussaf de semaine un Chabbat Roch 'Hodech (2025-12-20), où l'on dit « אתה יצרת ».
    const moussaf = renvois.find((a) => a.cible === 'moussaf_rosh_hodech');
    assert.ok(vrai(moussaf.si, jour('2025-12-21', false).conditions) && !vrai(moussaf.si, jour('2025-12-20', false).conditions), nusah);
  }
});

// --- 5. L'onglet Zmanim et le calendrier (JourAfficheTest) ---------------------------
test('JourAffiche, audit du 16/11 : profil Edot, jeûnes, ’hamets, vendredi de fête, Jérusalem', async () => {
  const A = await import('../src/js/jour-affiche.js');
  const parIndex = (l) => Object.fromEntries(l.map((z) => [z.cle, z]));
  const [jer, paris, ny] = LIEUX;
  const hm = (d, f) => new Intl.DateTimeFormat('fr-FR', { timeZone: f, hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(d);
  // Vendredi de fête : les dates de l'audit, dans les trois noussa'h.
  for (const [l, iso, il] of [[jer, '2026-05-22', true], [ny, '2026-04-03', false], [paris, '2024-10-04', false]]) {
    for (const nusah of ['edot', 'sefard', 'ashkenaz']) {
      const h = parIndex(A.horaires(l, iso, il, 18, nusah));
      assert.equal(h.allumage.methode, 'avant_chkia', `${iso} ${nusah}`);
      assert.ok(+h.allumage.instant < +h.chkia.instant, `${iso} ${nusah}`);
    }
  }
  // Edot : sortie à Rabbénou Tam en zmaniyot ; après Chabbat, l'allumage de la fête suit cette sortie.
  const samedi = parIndex(A.horaires(jer, '2026-10-17', true, 18, 'edot'));
  // Les deux sorties, au choix du propriétaire (17/11) : Gueonim à tsét, puis Rabbénou Tam.
  assert.equal(+samedi.sortie_gueonim.instant, +samedi.tset.instant);
  assert.ok(+samedi.sortie_gueonim.instant < +samedi.sortie.instant);
  assert.equal(samedi.sortie.methode, 'rabbenou_tam_zmaniyot');
  assert.ok(!('sortie_gueonim' in parIndex(A.horaires(jer, '2026-10-17', true, 18, 'ashkenaz'))));
  assert.equal(+samedi.sortie.instant, +samedi.tset_rt.instant);
  const rh1 = parIndex(A.horaires(paris, '2026-09-12', false, 18, 'edot'));
  assert.equal(rh1.allumage.methode, 'apres_sortie');
  assert.equal(+rh1.allumage.instant, +rh1.tset_rt.instant);
  assert.equal(+parIndex(A.horaires(paris, '2025-09-23', false, 18, 'edot')).allumage.instant, +parIndex(A.horaires(paris, '2025-09-23', false, 18, 'edot')).tset.instant);
  assert.equal(+parIndex(A.horaires(jer, '2026-10-17', true, 18, 'ashkenaz')).sortie.instant, +parIndex(A.horaires(jer, '2026-10-17', true, 18)).tset.instant);
  // Jeûnes.
  const teveth = parIndex(A.horaires(paris, '2026-12-20', false, 18));
  assert.equal(+teveth.debut_jeune.instant, +teveth.alot.instant);
  assert.equal(+teveth.fin_jeune.instant, +teveth.tset.instant);
  assert.equal(+parIndex(A.horaires(paris, '2026-07-22', false, 18)).debut_jeune.instant, +parIndex(A.horaires(paris, '2026-07-22', false, 18)).chkia.instant);
  assert.ok(!('debut_jeune' in parIndex(A.horaires(paris, '2026-07-23', false, 18))));
  const samediAv = parIndex(A.horaires(paris, '2025-08-02', false, 18));
  assert.equal(+samediAv.debut_jeune.instant, +samediAv.chkia.instant);
  assert.ok('sortie' in samediAv);
  // 'Hamets : Jérusalem 2026-04-01, et le vendredi 2025-04-11 (14 Nissan un Chabbat).
  const edot = A.horaires(jer, '2026-04-01', true, 18, 'edot').filter((z) => z.cle.startsWith('hamets'));
  assert.deepEqual(edot.map((z) => z.cle), ['hamets_achila', 'hamets_achila', 'hamets_biour', 'hamets_biour']);
  assert.equal(hm(edot[0].instant, jer.fuseau), '10:13');
  assert.deepEqual(A.horaires(jer, '2026-04-01', true, 18, 'ashkenaz').filter((z) => z.cle.startsWith('hamets')).map((z) => hm(z.instant, jer.fuseau)),
    ['10:14', '10:38', '11:28', '11:40']);
  assert.deepEqual(A.horaires(jer, '2025-04-11', true, 18).filter((z) => z.cle.startsWith('hamets')).map((z) => z.cle), ['hamets_biour', 'hamets_biour']);
  // Jérusalem : 40 min hors Edot, 20 min pour les Edot.
  assert.equal(A.propositionAllumage('edot', true, 40), 'reglage_allumage_proposition_edot');
  assert.equal(A.propositionAllumage('edot', true, 20), null);
  assert.equal(A.propositionAllumage('sefard', true, 18), 'reglage_allumage_proposition');
  assert.equal(A.propositionAllumage('ashkenaz', false, 18), null);
  assert.ok(!A.coutumeJerusalem('edot', true, 40) && A.coutumeJerusalem('sefard', true, 40));
  // Edot : pas de Cha'harit avant l'aube du Yalkut Yosef (Paris, 2026-12-21 à 07:30).
  const t = new Date('2026-12-21T06:30:00Z');
  assert.equal(A.momentDuSiddour(paris, t, false, 'sefard'), 'chaharit');
  assert.notEqual(A.momentDuSiddour(paris, t, false, 'edot'), 'chaharit');
});
test('JourAffiche : allumage, sortie, ajouts nommés et grille, comme Android', async () => {
  const A = await import('../src/js/jour-affiche.js');
  const parIndex = (l) => Object.fromEntries(l.map((z) => [z.cle, z]));
  const jer = LIEUX[0];
  const paris = LIEUX[1];
  const vendredi = parIndex(A.horaires(jer, '2026-10-16', true, 18));
  assert.equal((+vendredi.chkia.instant - +vendredi.allumage.instant) / 1000, 18 * 60);
  assert.ok(!('sortie' in vendredi));
  const samedi = parIndex(A.horaires(jer, '2026-10-17', true, 18));
  assert.equal(+samedi.sortie.instant, +samedi.tset.instant);
  const rh1 = parIndex(A.horaires(paris, '2026-09-12', false, 18));
  assert.equal(rh1.allumage.methode, 'apres_tset');
  assert.ok('sortie' in parIndex(A.horaires(paris, '2026-09-13', false, 18)));
  // Fête un vendredi (FCALENDRIER-01) : allumage de Chabbat avant la chki'a, jamais à tsét.
  for (const [iso, israel] of [['2027-04-23', false], ['2027-06-11', false], ['2027-06-11', true], ['2028-09-22', false]]) {
    const h = parIndex(A.horaires(israel ? jer : paris, iso, israel, 18));
    assert.equal(h.allumage.methode, 'avant_chkia', iso);
    assert.ok(+h.allumage.instant < +h.chkia.instant, iso);
    assert.ok(!('sortie' in h), iso);
  }
  assert.deepEqual(A.ajouts(jour('2026-10-12', false).conditions),
    ['ajout_machiv_harouah', 'ajout_barkhenou', 'ajout_yaale_veyavo', 'ajout_hallel_partiel_sans_berakha', 'ajout_sans_tahanoun']);
  // Les Edot disent ברכנו / ברך עלינו ; les autres noussa'h ותן ברכה / ותן טל ומטר.
  assert.ok(A.ajouts(jour('2026-10-12', false).conditions, 'ashkenaz').includes('ajout_berakha'));
  assert.ok(A.ajouts(jour('2026-12-07', false).conditions).includes('ajout_barekh_alenou'));
  // Un Yom Tov en semaine et Kippour : pas de 9e bénédiction de semaine (FCALENDRIER-12).
  for (const iso of ['2027-04-22', '2026-09-21']) {
    assert.ok(!A.ajouts(jour(iso, false).conditions).some((k) => ['ajout_barkhenou', 'ajout_berakha', 'ajout_barekh_alenou', 'ajout_tal_oumatar'].includes(k)), iso);
    // Ni « Pas de Ta'hanoun », comme le Chabbat.
    assert.ok(!A.ajouts(jour(iso, false).conditions).some((k) => k.includes('tahanoun')), iso);
  }
  assert.ok(!A.ajouts(jour('2026-10-10', false).conditions).some((k) => ['ajout_barkhenou', 'ajout_berakha'].includes(k)));
  // Le nusah (JourAfficheTest) : bénédiction du Hallel partiel (OC 422:2),
  // Morid hatal ashkénaze hors d'Israël, Anénou du particulier (OC 565:3).
  const rc = jour('2026-10-12', false).conditions;
  assert.ok(A.ajouts(rc, 'sefard').includes('ajout_hallel_partiel_avec_berakha'));
  assert.ok(A.ajouts(rc, 'ashkenaz').includes('ajout_hallel_partiel_avec_berakha'));
  const ete = jour('2027-06-01', false).conditions;
  assert.ok(A.ajouts(ete, 'edot').includes('ajout_morid_hatal'));
  assert.ok(A.ajouts(ete, 'sefard').includes('ajout_morid_hatal'));
  assert.ok(!A.ajouts(ete, 'ashkenaz').includes('ajout_morid_hatal'));
  assert.ok(A.ajouts(ete, 'ashkenaz', true).includes('ajout_morid_hatal'));
  const jeune = jour('2026-12-20', false).conditions;
  assert.deepEqual(A.ajouts(jeune, 'edot').filter((k) => k.startsWith('ajout_anenou')), ['ajout_anenou_officiant', 'ajout_anenou_particulier_matin_minha']);
  assert.deepEqual(A.ajouts(jeune, 'ashkenaz').filter((k) => k.startsWith('ajout_anenou')), ['ajout_anenou_officiant', 'ajout_anenou_particulier_minha']);
  const av = jour('2027-08-12', false).conditions; // Tich'a bèAv 5787
  assert.ok(av.has('ticha_beav'));
  assert.deepEqual(A.ajouts(av, 'edot').filter((k) => k.startsWith('ajout_anenou')), ['ajout_anenou_officiant', 'ajout_anenou_particulier_trois']);
  assert.deepEqual(A.ajouts(av, 'sefard').filter((k) => k.startsWith('ajout_anenou')), ['ajout_anenou_officiant', 'ajout_anenou_particulier_minha']);
  // Veille de Roch Hachana (OC 581:3) ; fin de Tichri, Edot sans Ta'hanoun.
  assert.ok(!jour('2026-09-11', true).conditions.has('tahanoun_chaharit'));
  assert.ok(jour('2026-09-10', true).conditions.has('tahanoun_minha'));
  const { conditionsPour } = await import('../src/js/siddur-jour.js');
  const fin = jour('2026-10-05', true).conditions;
  assert.ok(fin.has('fin_tichri') && fin.has('tahanoun_chaharit'));
  assert.ok(!conditionsPour('edot', true, fin).has('tahanoun_chaharit'));
  assert.ok(!A.ajouts(fin, 'edot').includes('ajout_tahanoun'));
  assert.ok(A.ajouts(fin, 'ashkenaz').includes('ajout_tahanoun'));
  assert.ok(A.ajouts(fin, 'sefard', true).includes('ajout_tahanoun'));
  assert.ok(!A.ajouts(fin, 'sefard', true, true).includes('ajout_tahanoun'));
  assert.ok(conditionsPour('edot', true, jour('2026-10-13', true).conditions).has('tahanoun_chaharit'));
  // Avinou malkénou (14/10) : 10 Tévèt, jour des dix jours de pénitence, Roch Hachana un dimanche ;
  // jamais un jour ordinaire, Roch Hachana un Chabbat, le Chabbat Chouva, la veille de Kippour ni le 9 Av.
  const am = (d) => conditionsPour('ashkenaz', true, jour(d, true).conditions).has('avinou_malkenou');
  for (const d of ['2026-12-20', '2026-09-15', '2026-09-13', '2026-09-14']) assert.ok(am(d), d);
  for (const d of ['2026-12-21', '2026-09-12', '2026-09-19', '2026-09-20', '2027-08-12']) assert.ok(!am(d), d);
  assert.ok(jour('2027-08-12', true).conditions.has('ticha_beav'));
  // À Min'ha (TSIDDUR-09) : seulement si Ta'hanoun s'y dit.
  const amm = (d) => conditionsPour('ashkenaz', true, jour(d, true).conditions).has('avinou_malkenou_minha');
  for (const d of ['2026-12-20', '2026-09-15']) assert.ok(amm(d), d);
  for (const d of ['2027-03-22', '2028-09-29', '2026-12-21']) assert.ok(!amm(d), d);
  // Roch Hachana et Kippour, sans Ta'hanoun, gardent le leur ; jamais le vendredi (relecture du 15/11).
  for (const d of ['2026-09-13', '2028-09-21', '2026-09-21']) assert.ok(amm(d), d);
  for (const d of ['2028-09-22', '2026-09-18']) assert.ok(!amm(d), d);
  // Lecture de la Torah (15/10) : lundi, jeudi, Chabbat, Roch 'Hodech, jeûne, 'Hol hamoed ; pas un mardi ordinaire.
  for (const d of ['2026-10-19', '2026-10-15', '2026-10-17', '2026-11-11', '2026-12-20', '2026-09-29', '2026-04-16']) assert.ok(jour(d, true).conditions.has('kriat_hatorah'), d);
  for (const d of ['2026-10-20', '2026-10-21', '2026-10-23']) assert.ok(!jour(d, true).conditions.has('kriat_hatorah'), d);
  // Jérusalem : Pourim et Al hanissim le 15 Adar II 5787 (24/03/2027).
  assert.ok(!jour('2027-03-23', true, true).conditions.has('al_hanissim'));
  assert.ok(jour('2027-03-24', true, true).conditions.has('pourim'));
  assert.deepEqual(jour('2027-03-23', true, true).fetes, ['pourim_ailleurs']);
  assert.deepEqual(jour('2027-03-24', true, true).fetes, ['pourim_jerusalem']);
  assert.deepEqual(jour('2027-03-23', true).fetes, ['pourim']);
  assert.ok(jour('2027-03-23', true).conditions.has('al_hanissim'));
  assert.ok(!jour('2027-03-24', true).conditions.has('al_hanissim'));
  // Pourim triple 5785 : à Jérusalem, le dimanche 16 Adar (16/03/2025), ni Ta'hanoun ni למנצח ; ailleurs, si.
  for (const k of ['tahanoun_chaharit', 'tahanoun_minha', 'lamnatseah']) {
    assert.ok(!jour('2025-03-16', true, true).conditions.has(k), k);
    assert.ok(jour('2025-03-16', true).conditions.has(k) && jour('2025-03-16', false).conditions.has(k), k);
  }
  // Un 16 Adar ordinaire à Jérusalem (jeudi 16 Adar II 5787, 25/03/2027) : Ta'hanoun.
  assert.ok(jour('2027-03-25', true, true).conditions.has('tahanoun_chaharit'));
  // Ailleurs en Israël, l'Ashkenaz suit le Halikhot Chlomo (sans Ta'hanoun, למנצח gardé), précisé contre le
  // Michna Beroura ; Edot et Sfard (Yalkut Yosef) et la diaspora disent Ta'hanoun.
  const triple = jour('2025-03-16', true).conditions;
  assert.ok(triple.has('pourim_triple_hors_jerusalem'));
  assert.ok(!jour('2025-03-16', false).conditions.has('pourim_triple_hors_jerusalem') && !jour('2025-03-16', true, true).conditions.has('pourim_triple_hors_jerusalem'));
  const ashk = conditionsPour('ashkenaz', true, triple);
  assert.ok(!ashk.has('tahanoun_chaharit') && !ashk.has('tahanoun_minha') && ashk.has('lamnatseah'));
  assert.ok(A.ajouts(triple, 'ashkenaz', true).includes('ajout_sans_tahanoun_halikhot_chlomo'));
  for (const n of ['edot', 'sefard']) assert.ok(A.ajouts(triple, n, true).includes('ajout_tahanoun'), n);
  assert.ok(A.ajouts(jour('2025-03-16', false).conditions, 'ashkenaz', false).includes('ajout_tahanoun'));
  assert.ok(A.ajouts(jour('2025-03-16', true, true).conditions, 'ashkenaz', true).includes('ajout_sans_tahanoun'));
  // Le festin du dimanche à Jérusalem : « על הנסים » dans un « הרחמן » (Edot, Yalkut Yosef 688:6, § 15) ; seulement là.
  assert.ok(jour('2025-03-16', true, true).conditions.has('pourim_triple_festin') && !triple.has('pourim_triple_festin'));
  assert.ok(!jour('2025-03-15', true, true).conditions.has('pourim_triple_festin') && !jour('2025-03-16', false).conditions.has('pourim_triple_festin'));
  const chaines = readFileSync(join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res', 'values', 'strings.xml'), 'utf8');
  for (const n of ['edot', 'sefard', 'ashkenaz']) {
    for (const k of [...A.ajouts(rc, n), ...A.ajouts(jeune, n), ...A.ajouts(ete, n), ...A.ajouts(av, n)]) assert.ok(chaines.includes(`name="${k}"`), k);
  }
  const s = A.semaines(2026, 10);
  assert.equal(s.length, 5);
  assert.equal(s[0][4], '2026-10-01');
  assert.equal(s.flat().filter(Boolean).length, 31);
});

// Le calendrier hébraïque en vue principale (10/10) : chaque mois, contre Hebcal.
test('calendrier : les mois hébreux de 2026 à 2028, bornes et longueurs comme Hebcal', async () => {
  const A = await import('../src/js/jour-affiche.js');
  const iso = (d) => d.toISOString().slice(0, 10);
  for (let d = new Date(Date.UTC(2026, 0, 1, 12)); d < new Date(Date.UTC(2029, 0, 1)); d.setUTCDate(d.getUTCDate() + 1)) {
    const hd = new HDate(new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
    const debut = new HDate(1, hd.getMonth(), hd.getFullYear()).greg();
    const attendu = `${debut.getFullYear()}-${String(debut.getMonth() + 1).padStart(2, '0')}-${String(debut.getDate()).padStart(2, '0')}`;
    assert.equal(A.debutMoisHebreu(iso(d)), attendu, iso(d));
    if (hd.getDate() === 1) assert.equal(A.joursMoisHebreu(iso(d)).length, hd.daysInMonth(), iso(d));
  }
  const t = A.semainesHebreu('2026-10-10');
  assert.deepEqual(t[0], [null, null, null, null, null, null, '2026-09-12']);
  assert.equal(t.flat().filter(Boolean).length, 30);
  assert.equal(A.moisHebreuVoisin('2026-10-10', 1), '2026-10-12');
  assert.equal(A.moisHebreuVoisin('2026-10-10', -1), '2026-08-14');
  // 5787 est embolismique : Chevat, Adar I, Adar II, Nissan.
  assert.equal(A.moisHebreuVoisin('2027-01-15', 1), '2027-02-08');
  assert.equal(A.moisHebreuVoisin('2027-02-08', 1), '2027-03-10');
  assert.equal(A.moisHebreuVoisin('2027-03-10', 1), '2027-04-08');
});

// --- 6. L'algorithme de la NOAA ---------------------------------------------------------
test('zmanim : l’algorithme de la NOAA, à deux secondes près de ses formules', () => {
  assert.equal(Z.calculateur(LIEUX[1], '2026-10-10'), 'US National Oceanic and Atmospheric Administration Algorithm');
  const ref = JSON.parse(readFileSync(join(ICI, '..', '..', 'android', 'app', 'src', 'test', 'resources', 'zmanim_reference_noaa.json'), 'utf8'));
  assert.ok(ref.length >= 28);
  for (const r of ref) {
    const lieu = LIEUX.find((l) => l.nom === r.lieu);
    const z = Object.fromEntries(Z.jour(lieu, r.date).map((x) => [x.cle, x]));
    for (const cle of ['netz', 'chkia', 'alot', 'misheyakir', 'tset', 'chatsot']) {
      const local = Z.heure(z[cle].instant, lieu.fuseau);
      const secondes = (t) => t.split(':').map(Number).reduce((a, b) => a * 60 + b, 0);
      const vu = new Intl.DateTimeFormat('fr-FR', { hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23', timeZone: lieu.fuseau }).format(z[cle].instant);
      // ’Hatsot : l'équation du temps évaluée à JD − 0,5 par l'ancien calculateur
      // JavaScript de la NOAA, que KosherJava reprend (voir ZmanimTest).
      const tolerance = cle === 'chatsot' ? 20 : 2;
      assert.ok(Math.abs(secondes(vu) - secondes(r[cle])) <= tolerance, `${r.lieu} ${r.date} ${cle} : ${vu} contre ${r[cle]} (NOAA, ${local})`);
    }
  }
});

// --- 7. Le moment du siddour selon les zmanim (JourAfficheTest) ----------------------
test('siddour : la suggestion suit les zmanim du lieu, rien dans les creux', async () => {
  const A = await import('../src/js/jour-affiche.js');
  const { SiddurMoment } = await import('../src/js/regles.js');
  const jer = { nom: 'J', latitude: 31.76904, longitude: 35.21633, altitude: 0, fuseau: 'Asia/Jerusalem' };
  const z = Object.fromEntries(Z.jour(jer, '2026-10-16').map((x) => [x.cle, x.instant]));
  const d = (cle, s) => new Date(+z[cle] + s * 1000);
  assert.equal(A.momentDuSiddour(jer, d('alot', 60)), 'birkot_hachahar');
  assert.equal(A.momentDuSiddour(jer, d('misheyakir', 60)), 'chaharit');
  assert.equal(A.momentDuSiddour(jer, d('chatsot', -60)), 'chaharit');
  assert.equal(A.momentDuSiddour(jer, d('chatsot', 60)), null);
  assert.equal(A.momentDuSiddour(jer, d('minha_gedola', 60)), 'minha');
  assert.equal(A.momentDuSiddour(jer, d('chkia', -60)), 'minha');
  assert.equal(A.momentDuSiddour(jer, d('chkia', 60)), null);
  assert.equal(A.momentDuSiddour(jer, d('tset', 60)), 'arvit');
  assert.equal(A.momentDuSiddour(jer, new Date('2026-10-16T22:45:00+03:00')), 'chema_coucher');
  assert.equal(A.momentDuSiddour(jer, new Date('2026-10-16T02:00:00+03:00')), 'tikoun_hatsot');
  // Londres au solstice : pas d'aube, mais chki'a et tsét existent (FCALENDRIER-08).
  const londres = { nom: 'L', latitude: 51.5074, longitude: -0.1278, altitude: 0, fuseau: 'Europe/London' };
  assert.equal(A.momentDuSiddour(londres, new Date('2027-06-21T18:45:00+01:00')), 'minha');
  assert.equal(A.momentDuSiddour(londres, new Date('2027-06-21T09:00:00+01:00')), 'chaharit');
  assert.equal(A.momentDuSiddour(londres, new Date('2027-06-21T00:30:00+01:00')), 'chema_coucher');
  const tromso = { nom: 'T', latitude: 69.6492, longitude: 18.9553, altitude: 0, fuseau: 'Europe/Oslo' };
  assert.equal(A.momentDuSiddour(tromso, new Date('2026-06-21T14:00:00+02:00')), SiddurMoment.suggestion(14, 0));
});

// Audit du 16/11 : pas de Tikoun 'hatsot les nuits de Chabbat, de Yom tov et de 'Hol hamoed Pessa'h
// (consigne du texte ; Kitsour Yalkut Yosef, דיני תיקון חצות §נה) ; le Tikoun Ra'hel de midi à Bein hamétsarim (§מה).
test('siddour (audit du 16/11) : Tikoun ’hatsot selon la nuit, Tikoun Ra’hel de midi', async () => {
  const A = await import('../src/js/jour-affiche.js');
  const { SiddurMoment } = await import('../src/js/regles.js');
  const jer = { nom: 'J', latitude: 31.76904, longitude: 35.21633, altitude: 0, fuseau: 'Asia/Jerusalem' };
  const paris = { nom: 'P', latitude: 48.85341, longitude: 2.3488, altitude: 0, fuseau: 'Europe/Paris' };
  for (const t of ['2026-11-21T01:30:00+02:00', '2026-04-05T01:30:00+03:00', '2026-09-12T01:30:00+03:00', '2026-09-21T01:30:00+03:00', '2027-04-25T01:30:00+03:00', '2026-11-20T23:55:00+02:00']) {
    assert.equal(A.momentDuSiddour(jer, new Date(t)), 'chema_coucher', t);
  }
  assert.equal(A.momentDuSiddour(jer, new Date('2026-11-19T01:30:00+02:00')), 'tikoun_hatsot');
  // Le 2e jour de Soukkot ne compte qu'en diaspora ; en Israël, 'Hol hamoed Soukkot n'est pas exclu.
  assert.equal(A.momentDuSiddour(paris, new Date('2026-09-27T03:00:00+02:00'), false), 'chema_coucher');
  assert.equal(A.momentDuSiddour(paris, new Date('2026-09-27T03:00:00+02:00'), true), 'tikoun_hatsot');
  assert.equal(SiddurMoment.suggestion(1, 0, true), 'chema_coucher');
  assert.equal(SiddurMoment.suggestion(1, 0), 'tikoun_hatsot');
  // Bein hamétsarim : 20 Tamouz 5786 à 12 h 50, en Edot et en Sfard ; pas en Ashkenaz, ni le Chabbat.
  assert.equal(A.momentDuSiddour(jer, new Date('2026-07-05T12:50:00+03:00')), 'tikoun_hatsot');
  assert.equal(A.momentDuSiddour(jer, new Date('2026-07-05T12:50:00+03:00'), true, 'sefard'), 'tikoun_hatsot');
  assert.equal(A.momentDuSiddour(jer, new Date('2026-07-05T12:50:00+03:00'), true, 'ashkenaz'), null);
  assert.equal(A.momentDuSiddour(jer, new Date('2026-07-04T12:50:00+03:00')), null);
  assert.equal(A.momentDuSiddour(jer, new Date('2026-07-20T12:50:00+03:00')), 'tikoun_hatsot');
  assert.equal(A.momentDuSiddour(jer, new Date('2026-07-23T12:50:00+03:00')), null); // 9 Av
  assert.equal(A.momentDuSiddour(jer, new Date('2026-10-16T12:50:00+03:00')), null);
});

// --- Rappels de tefila (RappelsTefilaTest, 16/10) ---
import { rappelsTefila } from '../src/js/calendrier-juif.js';
test('rappels de tefila : mêmes cas que RappelsTefilaTest', () => {
  assert.deepEqual(rappelsTefila('2026-10-16', true), [{ type: 'pluie_debut', date: '2026-10-18' }]);
  assert.ok(!rappelsTefila('2026-10-16', false).some((r) => r.type === 'pluie_debut'));
  // Premier jour le samedi 5/12/2026 : on commence à motsaé Chabbat, rappel daté du dimanche 6 (FCALENDRIER-04).
  const pluie = (iso, n = 3) => rappelsTefila(iso, false, n).filter((r) => r.type === 'pluie_debut').map((r) => r.date);
  assert.deepEqual(rappelsTefila('2026-12-02', false, 6).filter((r) => r.type === 'pluie_debut').map((r) => r.date), ['2026-12-06']);
  for (const iso of ['2026-12-02', '2026-12-04', '2026-12-05']) assert.deepEqual(pluie(iso), ['2026-12-06'], iso);
  assert.deepEqual(pluie('2026-12-06'), []);
  assert.deepEqual(pluie('2031-12-05'), ['2031-12-07']);
  const p = rappelsTefila('2027-04-20', true).map((r) => `${r.type}@${r.date}`);
  for (const x of ['pluie_fin@2027-04-22', 'guechem_fin@2027-04-22', 'omer@2027-04-23']) assert.ok(p.includes(x), x);
  assert.ok(rappelsTefila('2027-09-30', false).some((r) => r.type === 'dix_jours' && r.date === '2027-10-02'));
  assert.ok(rappelsTefila('2027-10-21', true).some((r) => r.type === 'guechem_debut' && r.date === '2027-10-23'));
});

// --- Israël ou diaspora d'après la position (TerritoireIsraelTest, 16/10) ---
import { dansIsrael } from '../src/js/calendrier-juif.js';
test('territoire d’Israël : mêmes villes que TerritoireIsraelTest', () => {
  for (const [lat, lon] of [[31.7769, 35.2224], [32.0853, 34.7818], [29.5577, 34.9519], [33.2073, 35.57], [32.993, 35.69], [32.106, 35.171], [29.895, 35.06], [33.106, 35.806], [33.27, 35.77]]) assert.ok(dansIsrael(lat, lon), `${lat},${lon}`);
  for (const [lat, lon] of [[31.9539, 35.9106], [29.5321, 35.0063], [33.2705, 35.2038], [31.1316, 33.7984], [29.49, 34.876], [48.8566, 2.3522], [33.1256, 35.8244]]) assert.ok(!dansIsrael(lat, lon), `${lat},${lon}`);
});

// Audit du 16/11 (gravité haute) : le statut pour le Yom tov chéni suit la résidence (Choul'han Aroukh
// 496:3, Michna Beroura 496:13) ; un lieu de l'autre région pose la question sans rien changer. Remplace
// la règle du 12/11 (FCALENDRIER-06), où choisir un lieu redéduisait la région.
test('Israël / diaspora : un lieu ne change jamais le statut, il pose la question', async () => {
  const { decisionRegion } = await import('../src/js/calendrier-juif.js');
  const { creeStore, memoire } = await import('../src/js/store.js');
  const A = await import('../src/js/jour-affiche.js');
  // Mêmes cas que TerritoireIsraelTest.
  assert.deepEqual(decisionRegion(false, true, false, false), { region: null, proposition: false });
  assert.deepEqual(decisionRegion(true, false, false, true), { region: null, proposition: true });
  assert.deepEqual(decisionRegion(true, true, false, false), { region: null, proposition: null });
  assert.deepEqual(decisionRegion(true, false, true, false), { region: true, proposition: null });
  assert.deepEqual(decisionRegion(true, false, true, true), { region: null, proposition: true });

  const jerusalem = { nom: 'Ma position', latitude: 31.7769, longitude: 35.2224, altitude: 750, fuseau: 'Asia/Jerusalem' };
  const newYork = { nom: 'Ma position', latitude: 40.7128, longitude: -74.006, altitude: 10, fuseau: 'America/New_York' };
  const s = creeStore(memoire(), { maintenant: () => new Date(2026, 10, 13, 12), fuseau: 'Asia/Jerusalem' });
  // Le premier lieu fixe le statut.
  s.setLieuPosition(jerusalem);
  assert.equal(s.inIsrael(), true);
  assert.equal(s.regionProposee(), null);
  // Un Israélien à New York (position ou ville) : le statut reste Israël, la question est posée.
  s.setLieuPosition(newYork);
  assert.equal(s.inIsrael(), true);
  assert.equal(s.regionProposee(), false);
  assert.equal(s.lieu().latitude, 40.7128, 'la position, elle, est bien reprise');
  s.setLieu({ nom: 'New York', latitude: 40.7128, longitude: -74.006, altitude: 10, fuseau: 'America/New_York' }, { id: 5128581, pays: 'US' });
  assert.equal(s.inIsrael(), true);
  // « Garder » : le statut est déclaré, la question tombe ; les reprises ne la reposent pas en Israël.
  s.setInIsrael(true, true);
  assert.equal(s.regionProposee(), null);
  s.setLieuPosition(jerusalem);
  assert.equal(s.regionProposee(), null);
  // Revenu à New York, la question revient ; « J'habite hors d'Israël » change le statut.
  s.setLieuPosition(newYork);
  assert.equal(s.regionProposee(), false);
  s.setInIsrael(false, true);
  assert.equal(s.inIsrael(), false);
  assert.equal(s.regionProposee(), null);
  // Le drapeau voyage avec la sauvegarde.
  const fichier = JSON.parse(s.exportJson());
  assert.equal(fichier.settings.in_israel, false);
  assert.equal(fichier.settings.in_israel_manuel, true);
  // La note du Yom tov chéni (2026-10-04, Sim'hat Torah en diaspora).
  assert.equal(A.noteYomTovCheni('2026-10-04', true, false, 'edot'), 'note_ytc_ben_israel');
  assert.equal(A.noteYomTovCheni('2026-10-04', false, true, 'sefard'), 'note_ytc_ben_houl');
  assert.equal(A.noteYomTovCheni('2026-10-04', false, true, 'ashkenaz'), 'note_ytc_ben_houl_ashkenaz');
  assert.equal(A.noteYomTovCheni('2026-10-04', true, true, 'edot'), null);
  assert.equal(A.noteYomTovCheni('2026-10-14', true, false, 'edot'), null);
  // L'écran : la bascule des réglages est manuelle, la question aussi ; la position ne réécrit pas le statut.
  const app = readFileSync(join(ICI, '../src/js/app.js'), 'utf8');
  assert.ok(app.includes('store.setInIsrael(j === 0, true)'));
  assert.ok(app.includes('store.setInIsrael(proposee, true)'));
  assert.ok(!/store\.setInIsrael\(dansIsrael/.test(app));
});

test('rappels de tefila : nord et sud, Israël et diaspora', () => {
  const t = (israel, sud) => new Set(rappelsTefila('2027-10-21', israel, 3, undefined, sud).map((r) => r.type));
  assert.ok(t(true, false).has('guechem_debut'));
  assert.ok(t(false, false).has('guechem_debut'));
  assert.ok(!t(false, true).has('guechem_debut'));
  assert.ok(!rappelsTefila('2026-10-16', false, 3, undefined, true).some((r) => r.type === 'pluie_debut'));
});

test('Roch \'Hodech d\'une année embolismique : וּלְכַפָּרַת פֶּשַׁע (28/10)', async () => {
  const { jour } = await import('../src/js/calendrier-juif.js');
  const c = (iso) => jour(iso, false, false).conditions;
  // 5787 est embolismique (11ᵉ année du cycle). Kislev (30 'Hechvan, 1 Kislev) : les deux.
  for (const d of ['2026-11-10', '2026-11-11']) {
    assert.ok(c(d).has('embolismique') && c(d).has('embolismique_avant_nissan'), d);
  }
  // Roch 'Hodech Nissan 5787 (Adar II a 29 jours : 1 Nissan seul, 2027-04-08) : toute l'année seulement.
  assert.ok(c('2027-04-08').has('embolismique') && !c('2027-04-08').has('embolismique_avant_nissan'));
  // 5786 n'est pas embolismique : Roch 'Hodech Chevat 5786 (2026-01-19).
  assert.ok(!c('2026-01-19').has('embolismique'));
  // Hors Roch 'Hodech : rien.
  assert.ok(!c('2026-11-12').has('embolismique'));
});

// Audit du 16/11 (RappelsTefilaTest).
import { cleGuechemFin } from '../src/js/calendrier-juif.js';
test('Rappel de fin de משיב הרוח : l\'Ashkenaz de diaspora cesse à Min\'ha (Rema 114:3)', () => {
  assert.equal(cleGuechemFin('ashkenaz', false), 'rappel_guechem_fin_ashkenaz');
  assert.equal(cleGuechemFin('ashkenaz', true), 'rappel_guechem_fin');
  assert.equal(cleGuechemFin('sefard', false), 'rappel_guechem_fin');
  assert.equal(cleGuechemFin('edot', false), 'rappel_guechem_fin');
});

// Audit du 16/11 : Tikoun Ra'hel (Kitsour Yalkut Yosef, דיני תיקון חצות §נה et §נז), comme CalendrierJuif.C.TIKOUN_RAHEL ;
// le jour hébreu de la nuit pour Tikoun 'hatsot (avant minuit, le lendemain ; à midi, le jour même).
test('Tikoun Ra’hel selon le jour (audit du 16/11)', () => {
  const r = (iso, il = false) => jour(iso, il).conditions.has('tikoun_rahel');
  assert.equal(r('2026-11-19'), true);
  assert.equal(r('2026-07-23'), true); // 9 Av : Tikoun Ra'hel seul
  for (const iso of ['2027-03-09', '2026-04-08', '2026-09-15', '2027-05-12', '2026-12-08', '2027-03-23']) assert.equal(r(iso), false, iso);
  assert.equal(r('2026-10-04'), false); // Simha Torah en diaspora (23 Tichri)
  assert.equal(r('2026-10-04', true), true); // en Israël, le 23 Tichri
  assert.equal(r('2028-11-16', true), false); // chemita 5789, en Israël
  assert.equal(r('2028-11-16'), true);
  assert.ok(jour('2026-11-19', false).conditions.has('toujours'));
  assert.equal(jourDeLaPriere('tikoun_hatsot', '2026-11-20', 23), '2026-11-21');
  assert.equal(jourDeLaPriere('tikoun_hatsot', '2026-07-05', 12), '2026-07-05');
});

// Audit du 16/11 : les repères du jour (CalendrierJuifTest, mêmes dates) et les Chabbatot spéciaux.
test('repères du jour : Seli’hot, chofar, בה״ב, Yom Kippour katan, érouv tavchilin (audit du 16/11)', async () => {
  const { reperes } = await import('../src/js/calendrier-juif.js');
  const r = (iso, il, n) => reperes(iso, il, n);
  // בה״ב : Ashkenaz et Sfard, le מי שבירך du Chabbat d'avant ; rien en Edot (Rema 492:1 ; MB 492:3).
  for (const iso of ['2025-10-27', '2025-10-30', '2025-11-03', '2026-10-19', '2026-10-22', '2026-10-26']) {
    assert.ok(r(iso, false, 'ashkenaz').includes('repere_behab'), iso);
    assert.ok(r(iso, false, 'sefard').includes('repere_behab'), iso);
    assert.ok(!r(iso, false, 'edot').includes('repere_behab'), iso);
  }
  assert.deepEqual(r('2025-10-25', false, 'ashkenaz'), ['repere_behab_mi_cheberakh']);
  assert.ok(r('2026-04-27', true, 'ashkenaz').includes('repere_behab'));
  // Seli'hot : Edot dès le 2 Eloul, sauf Chabbat ; Ashkenaz dès le dimanche avant Roch Hachana (Rema 581:1).
  assert.deepEqual(r('2026-08-15', false, 'edot'), []);
  assert.deepEqual(r('2026-08-16', false, 'edot'), ['repere_selihot']);
  assert.deepEqual(r('2026-08-17', false, 'ashkenaz'), ['repere_chofar']);
  assert.deepEqual(r('2026-09-05', false, 'ashkenaz'), []);
  assert.deepEqual(r('2026-09-06', false, 'ashkenaz'), ['repere_selihot', 'repere_chofar']);
  assert.ok(r('2025-09-14', false, 'ashkenaz').includes('repere_selihot')); // Roch Hachana un lundi : une semaine plus tôt
  assert.ok(!r('2025-09-12', false, 'ashkenaz').includes('repere_selihot'));
  assert.deepEqual(r('2026-09-11', false, 'edot'), ['repere_selihot', 'repere_pas_de_chofar']);
  assert.deepEqual(r('2026-09-20', false, 'ashkenaz'), ['repere_selihot']);
  assert.deepEqual(r('2026-09-21', false, 'ashkenaz'), []);
  for (const iso of ['2025-11-20', '2026-11-09', '2024-11-28']) assert.deepEqual(r(iso, false, 'edot'), ['repere_yom_kippour_katan'], iso);
  assert.deepEqual(r('2026-05-21', true, 'edot'), ['repere_erouv_tavchilin']);
  assert.deepEqual(r('2024-10-16', false, 'edot'), ['repere_erouv_tavchilin']);
  assert.deepEqual(r('2024-10-16', true, 'edot'), []);
  assert.deepEqual(r('2026-11-19', false, 'ashkenaz'), []);
  // Chekalim, Zakhor ; à Jérusalem, le Chabbat 15 Adar d'un Pourim triple (Choul'han Aroukh O.H. 688:6).
  assert.equal(jour('2026-02-28', false).parachaSpeciale, 'זכור');
  assert.equal(jour('2027-03-06', false).parachaSpeciale, 'שקלים');
  assert.equal(jour('2025-03-15', true, true).parachaSpeciale, 'מפטיר ויבא עמלק');
  assert.equal(jour('2025-03-15', true, false).parachaSpeciale, null);
  assert.equal(jour('2026-11-21', false).parachaSpeciale, null);
});

// Audit du 16/11 (« Autres ») : le rappel de l'écran Musique, l'omer sauf Lag baOmer et Bein hamétsarim (YY 493:8, 551:6).
test('musique : rappel de l’omer et de Bein hamétsarim (audit du 16/11)', async () => {
  const { periodeSansMusique } = await import('../src/js/calendrier-juif.js');
  assert.equal(periodeSansMusique('2026-07-23'), 'bein_hametsarim'); // 9 Av 5786
  assert.equal(periodeSansMusique('2026-07-02'), 'bein_hametsarim'); // 17 Tamouz
  assert.equal(periodeSansMusique('2029-07-22'), 'bein_hametsarim'); // jeûne repoussé au 10 Av
  assert.equal(periodeSansMusique('2026-07-24'), null);
  assert.equal(periodeSansMusique('2026-04-20'), 'omer');
  assert.equal(periodeSansMusique('2026-05-05'), null); // Lag baOmer 5786
  assert.equal(periodeSansMusique('2026-11-19'), null);
});
