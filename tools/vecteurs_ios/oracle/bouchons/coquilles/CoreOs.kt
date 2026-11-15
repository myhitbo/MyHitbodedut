package androidx.core.os

import java.util.Locale

class LocaleListCompat private constructor(private val etiquettes: String) {
    fun toLanguageTags(): String = etiquettes
    fun isEmpty(): Boolean = etiquettes.isEmpty()
    fun size(): Int = if (etiquettes.isEmpty()) 0 else etiquettes.split(',').size
    operator fun get(i: Int): Locale? = etiquettes.split(',').getOrNull(i)?.let(Locale::forLanguageTag)

    companion object {
        @JvmStatic fun forLanguageTags(etiquettes: String?): LocaleListCompat = LocaleListCompat(etiquettes.orEmpty())
        @JvmStatic fun getEmptyLocaleList(): LocaleListCompat = LocaleListCompat("")
    }
}
