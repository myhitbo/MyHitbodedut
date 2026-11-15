// Bouchons : ce qu'Android fournirait aux fichiers de l'app compilés ici. Les chargeurs de l'app
// prennent un Context (load(context)) et Hilloulot rappelle le fil principal ; les tables ne
// passent jamais par là : un appel est une faute du programme, il s'arrête.
package android.content

abstract class Context {
    val resources: android.content.res.Resources get() = error("bouchon : Context n'existe pas hors d'Android")
    val applicationContext: Context get() = error("bouchon : Context n'existe pas hors d'Android")
}
