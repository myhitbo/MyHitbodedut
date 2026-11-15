// Le fichier d'or du site (ios/PORTAGE.md § 3.9, « web-v2.json ») : une sauvegarde écrite par le
// vrai code du site (web/src/js/store.js), sur une horloge fixe, pour une utilisatrice qui a pratiqué,
// noté, gardé des favoris et réglé la lecture. Rien n'est tapé à la main dans le fichier produit.
//
//   node tools/vecteurs_ios/site/sauvegarde-site.mjs [sortie]
//
// Sortie par défaut : ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde/web-v2.json. Deux passes donnent
// les mêmes octets.
import { writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { creeStore, memoire } from '../../../web/src/js/store.js';

const ici = dirname(fileURLToPath(import.meta.url));
const sortie = process.argv[2] ?? resolve(ici, '../../../ios/Paquets/Coeur/Tests/Vecteurs/sauvegarde/web-v2.json');

// 2022 : loin de tout « aujourd'hui » où l'on relancera les tests (une journée à venir serait écartée).
const horloge = { t: Date.parse('2022-02-01T07:30:00Z') };
const s = creeStore(memoire(), { maintenant: () => new Date(horloge.t), fuseau: 'Europe/Paris' });
const jour = (iso, h = 8) => { horloge.t = Date.parse(`${iso}T0${h}:00:00Z`); };

jour('2022-01-30');
s.addSession(15, { theme: 'gratitude' });
s.addSession(10, { theme: 'famille' });
s.setJournalPlus('2022-01-30', { avant: 2, apres: 4, gratitude: 'La santé des enfants.', travail: 'La patience.' });
jour('2022-01-31');
s.addSession(20, { note: 'Dehors, avant le lever du jour / sous la pluie.' });
s.setNote('2022-02-01', 'Pas pu : une pensée seulement.');
jour('2022-02-01');
// Les dix psaumes du Tikoun, dits deux matins.
for (const n of [16, 32, 41, 42, 59, 77, 90, 105, 137, 150]) s.setTikkunDone(n, true);
jour('2022-01-31');
for (const n of [16, 32, 41, 42, 59, 77, 90, 105, 137, 150]) s.setTikkunDone(n, true);
jour('2022-02-01');
s.basculerFavori('s:chaharit');
s.basculerFavori('l:likoutei_moharan');
s.basculerChizukFavori('tehilim-145-18');
s.basculerMarque({ cle: 'l:likoutei_moharan', nusah: '', section: 3, bloc: 12, apercu: 'אשרי תמימי דרך' });
s.basculerMarque({ cle: 's:chaharit', nusah: 'sefard', section: 0, bloc: 4, apercu: 'מודה אני' });
s.setTargetMinutes(20);
s.setDailyGoal(30);
s.setShabbatMode(true);
s.setInIsrael(false, true);
s.setGuidedHitbodedut(true);
s.setFirstName('  Sarah  ');
s.setHideCountdown(false);
s.setMusicEnabled(true);
s.setMusicVolume(40);
s.setMusicShuffle(true);
s.setMusicTrackId('ianir_hello');
s.setAdresse('f');
s.setModeApparence('sombre');
s.setFond('sable');
s.setAccent('bordeaux');
s.setSiddurNusah('sefard');
s.setLectureEchelle(1.3);
s.setLecturePolice('frank');
s.setLectureSombre(true);
s.setLectureMasquee(false);
s.setLectureLangues('he+fr');
s.togglePausedDate('2022-01-28');

writeFileSync(sortie, s.exportJson() + '\n', 'utf8');
console.log(`web-v2.json → ${sortie}`);
