package android.os

class Looper private constructor() {
    companion object {
        fun getMainLooper(): Looper = error("bouchon : Looper n'existe pas hors d'Android")
    }
}

class Handler(@Suppress("UNUSED_PARAMETER") looper: Looper) {
    fun post(@Suppress("UNUSED_PARAMETER") r: Runnable): Boolean = error("bouchon : Handler n'existe pas hors d'Android")
}
