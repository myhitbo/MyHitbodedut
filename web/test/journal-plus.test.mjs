// Le journal enrichi (JournalPlus.kt), porté le 02/11 : les tests Android
// JournalCarnetTest, ParcoursTest (l'humeur) et DixAmeliorationsTest (le mois),
// puis le stockage et la sauvegarde, au format d'Android.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { JournalPlus } from '../src/js/regles.js';
import { creeStore, memoire } from '../src/js/store.js';

const plus = (avant = 0, apres = 0, gratitude = '', travail = '') => ({ avant, apres, gratitude, travail });

test('le résumé dit le sujet, l’humeur, la gratitude et la chose à travailler', () => {
  assert.equal(JournalPlus.resume(plus(2, 4, 'merci', 'la patience'), 'G', 'T', 'Sujet : Famille'),
    'Sujet : Famille\n🙁 → 🙂\nG : merci\nT : la patience');
  assert.equal(JournalPlus.resume(plus(0, 0, '', 'écouter'), 'G', 'T'), 'T : écouter');
  assert.equal(JournalPlus.resume(plus(2, 4, 'merci'), 'G'), '🙁 → 🙂\nG : merci');
  assert.equal(JournalPlus.resume(plus(), 'G'), '');
  // Une seule humeur notée : l'autre est un point.
  assert.equal(JournalPlus.resume(plus(0, 5), 'G'), '· → 😄');
  // En hébreu, la flèche va de droite à gauche.
  assert.equal(JournalPlus.resume(plus(1, 5), 'G', 'T', '', '←'), '😞 ← 😄');
});

test('une chose à travailler suffit à ce que le jour ne soit pas vide', () => {
  assert.equal(JournalPlus.vide(plus(0, 0, '', 'x')), false);
  assert.equal(JournalPlus.vide(plus(0, 0, '  ', '')), true);
});

test('lire ramène les valeurs dans ce que l’écran permet (optInt, coerceIn, take)', () => {
  assert.deepEqual(JournalPlus.lire(null), plus());
  assert.deepEqual(JournalPlus.lire({ avant: 9, apres: -2, gratitude: 'g'.repeat(300), travail: 3 }),
    plus(5, 0, 'g'.repeat(200), ''));
  assert.deepEqual(JournalPlus.lire({ avant: '3', apres: 2.7 }), plus(3, 2));
});

test('l’humeur moyenne ne compte que les jours notés avant et après', () => {
  assert.equal(JournalPlus.humeur([plus(2)]), null);
  assert.deepEqual(JournalPlus.humeur([plus(2, 4), plus(2, 4), plus(0, 5)]), { avant: 2, apres: 4, jours: 2 });
  assert.deepEqual(JournalPlus.humeur([plus(1, 4), plus(2, 5)]), { avant: 2, apres: 5, jours: 2 });
});

test('les minutes du mois, du 1er au dernier', () => {
  const m = JournalPlus.minutesDuMois({ '2026-10-01': 20, '2026-10-31': 45, '2026-11-01': 9 }, 2026, 10);
  assert.equal(m.length, 31); assert.equal(m[0], 20); assert.equal(m[2], 0); assert.equal(m[30], 45);
  assert.equal(JournalPlus.minutesDuMois({}, 2028, 2).length, 29);
});

test('le stockage : sous « journal_plus » du journal, effacé quand il est vide', () => {
  const stockage = memoire();
  const s = creeStore(stockage, { maintenant: () => new Date(2026, 10, 2, 12) });
  s.setJournalPlus('2026-11-01', plus(2, 4, 'merci', ''));
  const brut = JSON.parse(stockage.getItem('myhitbodedut-journal'));
  assert.deepEqual(brut.journal_plus, { '2026-11-01': { avant: 2, apres: 4, gratitude: 'merci', travail: '' } });
  assert.deepEqual(s.journalPlus('2026-11-01'), plus(2, 4, 'merci', ''));
  s.setJournalPlus('2026-11-01', plus());
  assert.deepEqual(JSON.parse(stockage.getItem('myhitbodedut-journal')).journal_plus, {});
  // Les journées n'en sont pas touchées.
  assert.equal(s.record('2026-11-01'), null);
});

test('la sauvegarde : exportée, réimportée, sans écraser ce qui est déjà noté', () => {
  const maintenant = () => new Date(2026, 10, 2, 12);
  const a = creeStore(memoire(), { maintenant });
  a.setJournalPlus('2026-11-01', plus(1, 5, 'g', 't'));
  a.setJournalPlus('2026-10-30', plus(3, 3));
  const fichier = a.exportJson();
  assert.deepEqual(JSON.parse(fichier).journal_plus['2026-11-01'], { avant: 1, apres: 5, gratitude: 'g', travail: 't' });

  const b = creeStore(memoire(), { maintenant });
  b.setJournalPlus('2026-10-30', plus(0, 0, 'déjà là'));
  assert.equal(b.importJson(fichier), 0);
  assert.deepEqual(b.journalPlus('2026-11-01'), plus(1, 5, 'g', 't'));
  assert.deepEqual(b.journalPlus('2026-10-30'), plus(0, 0, 'déjà là'));

  // Un fichier d'Android, sans la clé, s'importe comme avant ; une date future ou fausse est ignorée.
  const c = creeStore(memoire(), { maintenant });
  assert.equal(c.importJson(JSON.stringify({ format: 'myhitbodedut', version: 1, days: {} })), 0);
  c.importJson(JSON.stringify({ format: 'myhitbodedut', journal_plus: { '2027-01-01': { avant: 2 }, '2026-02-30': { avant: 2 } } }));
  assert.deepEqual(JSON.parse(c.exportJson()).journal_plus, {});
});

test('la sauvegarde complète (audit du 12/11, FDONNEES-01) : tout ce qui est noté ou gardé fait l’aller-retour', () => {
  const maintenant = () => new Date(2026, 10, 12, 12);
  const a = creeStore(memoire(), { maintenant });
  a.setJournalPlus('2026-11-10', plus(2, 4, 'merci', 'la patience'));
  for (const n of [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((i) => i)) a.setTikkunDone(n, true);
  a.basculerFavori('l:likoutei_etsot');
  a.basculerFavori('s:minha');
  a.basculerChizukFavori('c12');
  a.basculerMarque({ cle: 'l:sefer_hamidot', nusah: '', section: 90, bloc: 3, apercu: 'קרי' });
  a.setSiddurNusah('ashkenaz');
  a.setLectureEchelle(1.4);
  a.setLecturePolice('frank');
  a.setLectureLangues('he+fr');
  a.setLectureSombre(true);
  const fichier = JSON.parse(a.exportJson());
  assert.equal(fichier.version, 2);
  for (const cle of ['journal_plus', 'tikkun_journal', 'favoris', 'chizuk_favoris', 'marques_pages']) assert.ok(cle in fichier, cle);

  const b = creeStore(memoire(), { maintenant });
  b.basculerFavori('l:nichmat');
  b.importJson(JSON.stringify(fichier));
  assert.deepEqual(b.journalPlus('2026-11-10'), plus(2, 4, 'merci', 'la patience'));
  assert.deepEqual(b.tikkunJournal(), a.tikkunJournal());
  // Réunis, sans perdre ce que b avait déjà.
  assert.deepEqual(new Set(b.favoris()), new Set(['l:nichmat', 'l:likoutei_etsot', 's:minha']));
  assert.deepEqual(b.chizukFavoris(), ['c12']);
  assert.deepEqual(b.marques(), a.marques());
  assert.equal(b.siddurNusah(), 'ashkenaz');
  assert.equal(b.lectureEchelle(), 1.4);
  assert.equal(b.lecturePolice(), 'frank');
  assert.equal(b.lectureLangues(), 'he+fr');
  assert.equal(b.lectureSombre(), true);
  // Un second import du même fichier ne double rien.
  b.importJson(JSON.stringify(fichier));
  assert.equal(b.marques().length, 1);
  assert.equal(b.favoris().length, 3);
});

test('la sauvegarde : Android et le site écrivent et relisent les mêmes clés (Store.kt / store.js)', async () => {
  const { readFileSync } = await import('node:fs');
  const kt = readFileSync(new URL('../../android/app/src/main/java/com/myhitbodedut/Store.kt', import.meta.url), 'utf8');
  const exportKt = kt.slice(kt.indexOf('fun exportJson('), kt.indexOf('fun importJson('));
  const importKt = kt.slice(kt.indexOf('private fun importerAjouts('), kt.indexOf('// --- Format'));
  const champsMarque = ['cle', 'nusah', 'section', 'bloc', 'apercu'];
  const clesKt = new Set([...exportKt.matchAll(/put\("([a-z_]+)"/g)].map((m) => m[1]).filter((c) => !champsMarque.includes(c)));
  const s = creeStore(memoire(), { maintenant: () => new Date(2026, 10, 12, 12) });
  const fichier = JSON.parse(s.exportJson());
  // Les réglages de la barrière et des rappels n'existent que sur Android : le site ne les écrit qu'après un import.
  // La typographie Souffle (apparence_police, 14/11), le ciel et la disposition de l'accueil (accueil_ciel, accueil_disposition, 15/11) aussi.
  const androidSeul = new Set(['window_start', 'window_end', 'snooze_minutes', 'reminder_enabled', 'reminder_minutes', 'reminder_times', 'lecture_langues', 'lecture_ecran_allume', 'apparence_police', 'accueil_ciel', 'accueil_disposition']);
  const clesWeb = new Set([...Object.keys(fichier), ...Object.keys(fichier.settings)]);
  for (const c of clesKt) if (!androidSeul.has(c)) assert.ok(clesWeb.has(c), `le site n'exporte pas « ${c} »`);
  for (const c of clesWeb) assert.ok(clesKt.has(c), `Android n'exporte pas « ${c} »`);
  // Ce qu'Android exporte, il le relit.
  for (const c of [...clesKt].filter((x) => !['format', 'version', 'exported_at'].includes(x))) {
    assert.ok(importKt.includes(`"${c}"`), `Android ne relit pas « ${c} »`);
  }
});
