// Les textes de l'application Java : qui passe, sous quelle forme.
//
//   node --test nokia/test/

import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { litChaines } from '../../web/tools/chaines.mjs';
import { ChizukRules, MOMENTS } from '../../web/src/js/chizuk.js';
import { CLES_INTERFACE, DOSSIERS, LANGUES, decode, encode, hebreu, latin1, momentDe, textesLangues } from '../textes.mjs';

const ICI = dirname(fileURLToPath(import.meta.url));
const RES = join(ICI, '..', '..', 'android', 'app', 'src', 'main', 'res');
const chizuk = JSON.parse(readFileSync(join(RES, 'raw', 'chizuk.json'), 'utf8'));
const chaines = Object.fromEntries(LANGUES.map((l) =>
  [l, litChaines(readFileSync(join(RES, DOSSIERS[l], 'strings.xml'), 'utf8')).chaines]));
const copie = (o) => JSON.parse(JSON.stringify(o));
const ids = (d) => d.moments.flatMap((m) => m.textes.map((t) => t.id));
const HEBREU = /[\u05d0-\u05ea]/;

test('chaque ’hizouk publiable part une fois, sous son premier moment', () => {
  const d = textesLangues(chizuk, chaines);
  const attendus = chizuk.items.filter(ChizukRules.publiable).map((it) => it.id).sort();
  assert.ok(attendus.length > 0);
  assert.deepEqual([...ids(d)].sort(), attendus);
  for (const m of d.moments) {
    for (const t of m.textes) assert.equal(momentDe(chizuk.items.find((it) => it.id === t.id)), m.cle);
  }
  assert.deepEqual(d.moments.map((m) => m.cle), MOMENTS.filter((k) => d.moments.some((m) => m.cle === k)));
});

test('un texte non relu ou non vérifié ne part pas', () => {
  const donnees = copie(chizuk);
  donnees.items[0].relu = false;
  donnees.items[1].statut_verif = 'a_verifier';
  const d = textesLangues(donnees, chaines);
  assert.ok(!ids(d).includes(donnees.items[0].id));
  assert.ok(!ids(d).includes(donnees.items[1].id));
});

test('chaque langue a son texte : l’hébreu original, les traductions française et anglaise', () => {
  const d = textesLangues(chizuk, chaines);
  const [premier] = d.moments[0].textes;
  const item = chizuk.items.find((it) => it.id === premier.id);
  assert.equal(premier.texte.fr, latin1(item.fr));
  assert.equal(premier.texte.en, latin1(item.en));
  assert.equal(premier.texte.he, hebreu(item.he));
  assert.notEqual(premier.texte.fr, premier.texte.en);
  // Jamais une langue à la place d'une autre (RegleLangue) : ni hébreu dans les traductions, ni latin dans l'hébreu.
  for (const m of d.moments) {
    for (const t of m.textes) {
      assert.ok(!HEBREU.test(t.texte.fr) && !HEBREU.test(t.texte.en), t.id);
      assert.ok(HEBREU.test(t.texte.he), t.id);
      assert.ok(!/[a-zà-ÿ]{3}/i.test(t.texte.he), t.id);
      assert.ok(HEBREU.test(t.ref.he) && !HEBREU.test(t.ref.en), t.id);
    }
  }
});

test('les titres des moments et les mots de l’interface viennent de strings.xml, dans chaque langue', () => {
  const d = textesLangues(chizuk, chaines);
  for (const m of d.moments) {
    assert.equal(m.titre.fr, latin1(chaines.fr[`moment_${m.cle}`]));
    assert.equal(m.titre.en, latin1(chaines.en[`moment_${m.cle}`]));
    assert.equal(m.titre.he, hebreu(chaines.he[`moment_${m.cle}`]));
  }
  for (const k of CLES_INTERFACE) for (const l of LANGUES) assert.ok(d.interface[k][l], `${k} ${l}`);
  assert.equal(d.interface.chizuk_stuck.en, latin1(chaines.en.chizuk_stuck));
  assert.ok(HEBREU.test(d.interface.chizuk_stuck.he));
});

test('tout se dessine avec une police de téléphone : Latin-1, et les lettres hébraïques sans nikkoud', () => {
  assert.equal(latin1('cœur… l’âme — « oui »'), "coeur... l'âme - « oui »");
  assert.throws(() => latin1('שלום'));
  assert.equal(hebreu('עַל־כָּל־פָּנִים'), 'על-כל-פנים');
  assert.equal(hebreu('מוהר״ן, דק׳'), 'מוהר"ן, דק\'');
  const d = textesLangues(chizuk, chaines);
  for (const s of JSON.stringify(d)) {
    const cp = s.codePointAt(0);
    assert.ok(cp <= 0xff || (cp >= 0x5d0 && cp <= 0x5ea), s);
  }
});

test('textes.bin se relit à l’identique, comme DataInputStream', () => {
  const d = textesLangues(chizuk, chaines);
  const relu = decode(encode(d));
  assert.equal(relu.version, 2);
  assert.deepEqual(relu.langues, ['fr', 'en', 'he']);
  assert.deepEqual(relu.interface, d.interface);
  assert.deepEqual(relu.moments, d.moments.map((m) => ({ cle: m.cle, titre: m.titre, textes: m.textes.map((t) => ({ ref: t.ref, texte: t.texte })) })));
});

test('les mots de l’application : hitbodedout, jamais séance', () => {
  // Tous les fichiers Java (audit du 16/10 : seuls quatre sur dix étaient lus).
  const dossier = join(ICI, '..', 'app', 'src', 'myhitbodedut');
  const java = readdirSync(dossier).filter((n) => n.endsWith('.java'))
    .map((n) => readFileSync(join(dossier, n), 'utf8')).join('\n');
  // Les clés de strings.xml (session_done_title…) ne s'affichent pas : leur texte, si.
  const chainesAffichees = [...java.matchAll(/"([^"\n]*)"/g)].map((m) => m[1])
    .filter((c) => !CLES_INTERFACE.includes(c)).join('\n');
  assert.ok(!/s[ée]ance|session/i.test(chainesAffichees));
  assert.ok(chainesAffichees.includes('Hitbodedout'));
});
