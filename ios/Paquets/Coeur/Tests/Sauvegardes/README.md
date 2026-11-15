# Les fichiers d'or de la sauvegarde

Les trois fichiers du § 3.9 de `ios/PORTAGE.md`. L'oracle (`tools/vecteurs_ios/VecteursSauvegarde.kt`)
importe les deux premiers avec le vrai `Store.importJson` d'Android et note ce qu'en rend
`Store.exportJson` (`Tests/Vecteurs/sauvegarde.json`) ; les tests Swift (`SauvegardeTests`) doivent
rendre la même chose. Modifier un fichier ici, c'est relancer `tools/vecteurs_ios/lancer.sh`.

| Fichier | Ce qu'il prouve |
| --- | --- |
| `android-v1-forge.json` | les branches de l'import : `themes` absent ou qui n'est pas un tableau, `note_seule`, dates mal formées ou à venir, minutes hors bornes, en chaîne (« 25 », « 1e3 », « 20.9 », « 20d »), en `Long`, en booléen, note de 5 000 caractères, `null` lu « null », échappements, `reminder_minutes` sans `reminder_times`, prénom trop long, applications vides ou en double |
| `web-v1.json` | le fichier du site : `journal_plus` présent, clés de la barrière et des rappels absentes |
| `android-v1-reel.json` | la vraie sauvegarde du propriétaire (P7) : **hors du dépôt** (`.gitignore`), elle porte ses notes |

La vraie sauvegarde se vérifie sur la machine qui l'a, sans la versionner :

    cd ios/Paquets/Coeur
    MYHITBODEDUT_SAUVEGARDE_REELLE=/chemin/myhitbodedut-2026-11-15.json swift test --filter laSauvegardeReelleSeLitSansPerte

« Sans perte » : chaque journée et chacun des 21 réglages ressortent de l'export d'iOS avec la valeur du
fichier ; seuls changent `exported_at`, l'ordre des journées et des deux ensembles, `journal_plus`
(ajouté, vide) et un morceau qu'iOS ne livre pas (une URI `content://`, § 3.5). Sans fichier, le test
est sauté et le dit.
