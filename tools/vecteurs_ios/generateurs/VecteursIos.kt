// Lance les générateurs de vecteurs (tâche Gradle « vecteurs » de tools/export_contenu/tables) :
// chaque fichier Vecteurs<Domaine>.kt de ce dossier déclare un objet du même nom, un Generateur.
// Arguments : le dossier de sortie, puis les noms des générateurs.

import java.io.File

fun main(args: Array<String>) {
    val sortie = File(args[0])
    for (nom in args.drop(1)) {
        val generateur = Class.forName(nom).getField("INSTANCE").get(null) as Generateur
        val cible = File(sortie, generateur.fichier)
        Ecrit.fichier(cible, generateur.produire())
        println("$nom → ${cible.name} (${cible.length()} octets)")
    }
}
