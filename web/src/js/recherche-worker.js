// La recherche dans toute l'application, hors du fil de l'interface (check-up du 11/11).
// Chaque texte est mis à plat une seule fois (sans voyelles, accents ni balises) quand son
// fichier arrive ; une frappe ne parcourt plus que des chaînes prêtes. Avant, les 28 Mo étaient
// renormalisés à chaque frappe sur le fil de l'interface : 388 ms sur PC, 2 à 4 s sur téléphone.
// Mêmes règles que la recherche d'app.js (nuRecherche, dansRecueil, extraitRecherche) ; app.js la
// garde en repli là où un Worker ne démarre pas. Arrêté en quittant la recherche : la mémoire revient.
'use strict';

// Sans accents latins ni apostrophe typographique : « priere » trouve « Prières » (29/10).
const nu = (t) => t.normalize('NFD').replace(/[̀-ͯ’‘]/g, '').replace(/<[^>]+>/g, ' ').replace(/[־׀]/g, ' ').replace(/[֑-ׇ"'״׳]/g, '').replace(/\s+/g, ' ').trim().toLowerCase();
const MAX = 30;

function extrait(t, q) {
  const i = Math.max(0, t.indexOf(q));
  const debut = Math.max(0, i - 30);
  return (debut > 0 ? '…' : '') + t.slice(debut, i + q.length + 50).trim() + (i + q.length + 50 < t.length ? '…' : '');
}

// Un fichier qui ne vient pas (hors ligne, là où le Worker ne passe pas par le service worker) :
// app.js reprend la recherche d'avant, qui lit les fichiers par le service worker.
const echec = () => postMessage({ echec: true });

const json = (url) => fetch(url).then((r) => { if (!r.ok) throw new Error(String(r.status)); return r.json(); });

/** Un recueil (siddour ou livres) : par texte, son titre brut et ses paragraphes à plat. */
const aPlat = (textes) => textes.map((t) => ({ titre: t.titre, blocs: t.sections ? blocsAPlat(t.sections) : null }));
const blocsAPlat = (sections) => sections.flatMap((s) => s.blocs.filter((b) => b.t).map((b) => nu(b.t)));

const siddurs = {};
const siddurEnCours = {};
let livres = null;
let livresEnCours = false;
let yalkut = null;
let yalkutEnCours = false;
let halakha = null;
let halakhaEnCours = false;
let demande = null;

function chargerSiddur(n) {
  if (siddurs[n] || siddurEnCours[n]) return;
  siddurEnCours[n] = true;
  json(`../data/siddur_${n}.json`).then((d) => { siddurs[n] = aPlat(d.textes); repondre(); }).catch(echec);
}

/** La table d'abord (titres), puis chaque livre l'un après l'autre : les résultats se complètent. */
function chargerLivres() {
  if (livres || livresEnCours) return;
  livresEnCours = true;
  json('../data/livres/table.json').then(async (table) => {
    livres = { textes: aPlat(table.textes), ids: table.textes.map((t) => t.id), complet: false };
    repondre();
    for (let i = 0; i < livres.ids.length; i++) {
      try {
        const d = await json(`../data/livres/${livres.ids[i]}.json`);
        livres.textes[i].blocs = blocsAPlat(d.sections);
      } catch { /* un livre en panne n'arrête pas les autres */ }
      repondre();
    }
    livres.complet = true;
    repondre();
  }).catch(echec);
}

function chargerYalkut() {
  if (yalkut || yalkutEnCours) return;
  yalkutEnCours = true;
  json('../data/yalkut_yosef.json').then((d) => {
    // Un se'if revient dans plusieurs périodes : une fois seulement (yalkut.js, recherche).
    const vus = new Set();
    yalkut = Object.values(d.periodes).flat().filter((x) => {
      const cle = `${x.p}|${x.l}`;
      if (vus.has(cle)) return false;
      vus.add(cle);
      return true;
    }).map((x) => ({ s: x.s, l: x.l, p: x.p, n: nu(x.t), ns: nu(x.s ?? '') }));
    repondre();
  }).catch(echec);
}

function chargerHalakha() {
  if (halakha || halakhaEnCours) return;
  halakhaEnCours = true;
  json('../data/ben_ish_hai.json').then((d) => {
    const tout = Object.keys(d.annees).sort().flatMap((a) => Object.values(d.annees[a])
      .flatMap((s) => s.h.map((t, i) => ({ n: nu(t), numero: i + 1, section: s.he, annee: Number(a) }))));
    if (d.hanouka) tout.push(...d.hanouka.h.map((t, i) => ({ n: nu(t), numero: i + 1, section: d.hanouka.he, annee: 1 })));
    halakha = tout;
    repondre();
  }).catch(echec);
}

/** Comme dansRecueil : le titre d'abord, sinon le premier paragraphe qui contient la recherche. */
function dansRecueil(textes, q, langue) {
  const r = [];
  for (let i = 0; i < textes.length && r.length < MAX; i++) {
    const t = textes[i];
    const traduit = langue === 'he' ? t.titre.he : (t.titre[langue] || t.titre.he);
    if (nu(t.titre.he).includes(q) || nu(traduit).includes(q)) { r.push({ i, parTitre: true }); continue; }
    const b = t.blocs?.find((x) => x.includes(q));
    if (b) r.push({ i, extrait: extrait(b, q) });
  }
  return r;
}

function repondre() {
  if (!demande) return;
  const { cle, q, portee, nusah, langue } = demande;
  const tefilot = portee === 'tout' || portee === 'tefilot';
  const sefarim = portee === 'tout' || portee === 'sefarim';
  const halakhot = portee === 'tout' || portee === 'halakhot';
  if (tefilot) chargerSiddur(nusah);
  if (sefarim) chargerLivres();
  if (halakhot) { chargerYalkut(); chargerHalakha(); }
  const sid = tefilot && siddurs[nusah] ? dansRecueil(siddurs[nusah], q, langue) : [];
  const liv = sefarim && livres ? dansRecueil(livres.textes, q, langue) : [];
  const yy = halakhot && yalkut ? yalkut.filter((x) => x.n.includes(q) || x.ns.includes(q)).slice(0, MAX)
    .map((x) => ({ s: x.s, l: x.l, p: x.p, extrait: extrait(x.n, q) })) : [];
  const bih = halakhot && halakha ? halakha.filter((x) => x.n.includes(q)).slice(0, MAX)
    .map((x) => ({ numero: x.numero, section: x.section, annee: x.annee, extrait: extrait(x.n, q) })) : [];
  const complet = (!tefilot || !!siddurs[nusah]) && (!sefarim || !!livres?.complet) && (!halakhot || (!!yalkut && !!halakha));
  // Un livre arrivé sans rien changer aux résultats : pas de nouvel affichage (02/11 : les
  // résultats bougeaient à chaque fichier).
  const reponse = JSON.stringify({ cle, sid, liv, yy, bih, complet });
  if (reponse === derniere) return;
  derniere = reponse;
  postMessage({ cle, sid, liv, yy, bih, complet });
}
let derniere = '';

onmessage = (e) => {
  demande = { ...e.data, q: nu(String(e.data.texte ?? '').trim()) };
  if (demande.q.length < 2) { postMessage({ cle: demande.cle, sid: [], liv: [], yy: [], bih: [], complet: true }); demande = null; return; }
  repondre();
};
