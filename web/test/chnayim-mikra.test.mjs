// « Chnayim mikra : les halakhot » (26/11, tools/chnayim_mikra/construction.py) : le même livre
// que sur Android (ChnayimMikraTest.kt), lu par le site depuis la même source, livres.json.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { LanguesTexte, Reference } from '../src/js/regles.js';

const lire = (chemin) => readFileSync(new URL(`../../${chemin}`, import.meta.url), 'utf8');
const livres = JSON.parse(lire('android/app/src/main/livres/livres.json'));
const livre = livres.textes.find((t) => t.id === 'chnayim_mikra');
const halakhot = livre.sections.flatMap((s) => s.blocs.filter((b) => b.id));
const table = JSON.parse(lire('tools/chnayim_mikra/sources.json'));

test('le livre est dans le groupe halakha, avec ses trois titres et ses huit chapitres', () => {
  assert.equal(livre.groupe, 'halakha');
  assert.deepEqual(livre.titre, { he: 'הלכות שנים מקרא ואחד תרגום', fr: 'Chnayim mikra : les halakhot', en: 'Shnayim mikra: the laws' });
  assert.equal(livre.sections.length, 8);
  for (const s of livre.sections) assert.ok(s.titre && s.titre_fr && s.titre_en, s.titre);
  // Le site en fait sa table comme build.mjs : chaque livre de livres.json, sans son texte ni son _meta.
  const build = lire('web/build.mjs');
  assert.match(build, /for \(const t of livres\.textes\) \{/);
  assert.match(build, /const \{ sections, _meta, \.\.\.entete \} = t;/);
  const { sections, _meta, ...entete } = livre;
  const ligne = { ...entete, chapitres: sections.length };
  assert.equal(ligne.chapitres, 8);
  assert.ok(_meta && !('_meta' in ligne));
  // L'écran des livres montre chaque livre de chaque groupe, sans liste à tenir.
  assert.match(lire('web/src/js/app.js'), /livres\.textes\.filter\(\(x\) => x\.groupe === g\.cle\)/);
  // Et Android range le même fichier sous le même identifiant.
  assert.match(lire('android/app/src/main/java/com/myhitbodedut/LivresBruts.kt'), /"chnayim_mikra" to R\.raw\.livre_chnayim_mikra,/);
  assert.deepEqual(JSON.parse(lire('android/app/src/main/res/raw/livre_chnayim_mikra.json')).textes[0], livre);
});

test('chaque halakha a son hébreu, son français, son anglais, ses références et son rite', () => {
  assert.ok(halakhot.length >= 15 && halakhot.length <= 35, `${halakhot.length}`);
  assert.deepEqual(halakhot.map((h) => h.id), halakhot.map((_, i) => `chm-${String(i + 1).padStart(2, '0')}`));
  halakhot.forEach((h, i) => {
    for (const champ of ['t', 'fr', 'en']) assert.ok(h[champ]?.trim(), `${h.id} ${champ}`);
    assert.ok(['tous', 'sefarade', 'ashkenaze'].includes(h.rite), h.id);
    assert.ok(h.refs.length > 0, h.id);
    assert.ok(h.t.startsWith(`<b>${Reference.lettres(i + 1).replace(/[׳״]/g, '')}</b>`), h.id);
    assert.ok(h.fr.startsWith(`<b>${i + 1}</b>`) && h.en.startsWith(`<b>${i + 1}</b>`), h.id);
    // Seules les balises que le site et Android savent rendre.
    for (const t of [h.t, h.fr, h.en]) assert.ok(!/<(?!\/?(b|small)>|br>)/.test(t), h.id);
  });
  assert.deepEqual(new Set(halakhot.map((h) => h.rite)), new Set(['tous', 'sefarade', 'ashkenaze']));
});

test('le rite se lit en tête de la halakha, dans les trois langues', () => {
  const etiquettes = {
    sefarade: ['[ספרדים – עדות המזרח]', '[Séfarades – rite Edot]', '[Sephardim – Edot rite]'],
    ashkenaze: ['[אשכנזים – נוסח אשכנז ונוסח ספרד]', '[Ashkénazes – rites Ashkenaz et Sfard]', '[Ashkenazim – Ashkenaz and Sfard rites]'],
  };
  for (const h of halakhot) {
    const textes = [h.t, h.fr, h.en];
    if (etiquettes[h.rite]) textes.forEach((t, k) => assert.ok(t.split('</b>')[1].startsWith(` <small>${etiquettes[h.rite][k]}</small>`), h.id));
    else for (const e of Object.values(etiquettes).flat()) assert.ok(!textes.some((t) => t.includes(e)), h.id);
  }
  assert.deepEqual(livre.rites, { tous: ['edot', 'sefard', 'ashkenaz'], sefarade: ['edot'], ashkenaze: ['ashkenaz', 'sefard'] });
});

test('en espagnol et en arabe, l’hébreu, comme sur Android', () => {
  const h = halakhot[0];
  for (const langue of ['es', 'ar']) {
    assert.equal(LanguesTexte.defaut(langue), 'he');
    assert.deepEqual(LanguesTexte.textes(LanguesTexte.defaut(langue), h.t, h.fr, h.en), [['he', h.t]]);
  }
  assert.deepEqual(LanguesTexte.textes(LanguesTexte.defaut('fr'), h.t, h.fr, h.en), [['he', h.t], ['fr', h.fr]]);
  assert.ok(halakhot.every((x) => !('es' in x) && !('ar' in x)));
});

test('la table de vérification suit le livre, citation par citation', () => {
  assert.equal(table.halakhot.length, halakhot.length);
  table.halakhot.forEach((l, i) => {
    const h = halakhot[i];
    assert.equal(l.id, h.id);
    assert.equal(l.rite, h.rite);
    for (const r of l.references) {
      assert.ok(h.refs.includes(r.reference), `${h.id} ${r.reference}`);
      if (r.citation) assert.ok(h.t.includes(r.citation), `${h.id} ${r.citation.slice(0, 30)}`);
      if (['hid', 'kav', 'malka'].includes(r.source)) {
        assert.match(r.url, /^https:\/\//);
        assert.equal(r.nature, 'paraphrase avec référence (œuvre protégée)');
        if (r.citation) assert.ok(r.citation.split(' ').length <= 16, `${h.id} : citation trop longue`);
      } else assert.ok(r.citation && r.lu_via, `${h.id} ${r.reference}`);
    }
  });
  // Les sources et licences du livre sont dans son _meta, et l'introduction crédite celles qui le demandent.
  assert.ok(livre._meta.sources.some((s) => s.includes('Kehot Publication Society (via API Sefaria), CC-BY-NC')));
  const intro = livre.sections[0].blocs[0];
  for (const t of [intro.t, intro.fr, intro.en]) assert.ok(t.includes('CC BY-NC') && t.includes('CC BY-NC-SA 2.5'));
});
