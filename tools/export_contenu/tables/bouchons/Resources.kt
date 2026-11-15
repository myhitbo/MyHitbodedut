package android.content.res

abstract class Resources {
    fun openRawResource(id: Int): java.io.InputStream = error("bouchon : Resources n'existe pas hors d'Android")
}
