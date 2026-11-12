// L'écran d'ouverture (15/10) : le 'hassid devant le tziyoun une seconde et demie, puis un fondu.
// Script classique lu juste après le voile (index.html), avant le premier dessin : un voile déjà
// vu ne s'affiche pas du tout, au lieu d'attendre que app.js le retire.
// Une fois par jour, et un toucher l'écarte (check-up du 11/11) : rouvrir l'application coûtait
// chaque fois deux secondes avant de pouvoir toucher quoi que ce soit.
(function () {
  var voile = document.getElementById('ouverture');
  if (!voile) return;
  var d = new Date();
  var jour = d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  var deja = false;
  try {
    // Un rechargement dans la session ne le rejoue pas non plus (captures, mise à jour).
    deja = sessionStorage.getItem('ouverture-vue') === '1' || localStorage.getItem('ouverture-jour') === jour;
    sessionStorage.setItem('ouverture-vue', '1');
    localStorage.setItem('ouverture-jour', jour);
  } catch (e) { /* stockage refusé : on le montre */ }
  if (deja) { voile.remove(); return; }
  var leve = false;
  function lever() {
    if (leve) return;
    leve = true;
    voile.classList.add('fin');
    setTimeout(function () { voile.remove(); }, 300);
  }
  voile.addEventListener('pointerdown', lever);
  setTimeout(lever, 1500);
})();
