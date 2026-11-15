package androidx.core.content

import android.content.Context
import android.graphics.drawable.Drawable

object ContextCompat {
    fun getColor(context: Context, id: Int): Int = 0
    fun getDrawable(context: Context, id: Int): Drawable? = null
    fun checkSelfPermission(context: Context, permission: String): Int = 0
}
