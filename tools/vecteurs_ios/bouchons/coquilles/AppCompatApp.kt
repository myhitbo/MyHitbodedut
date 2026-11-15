// Coquilles : ce que les règles de l'app nomment d'androidx et de Material, signatures seules.
// Rien ici ne s'exécute dans un générateur ; ces classes ne servent qu'à compiler les fichiers
// d'Android tels qu'ils sont.
package androidx.appcompat.app

import android.content.Context
import android.content.DialogInterface
import android.view.View
import androidx.core.os.LocaleListCompat

object AppCompatDelegate {
    const val MODE_NIGHT_FOLLOW_SYSTEM = -1
    const val MODE_NIGHT_NO = 1
    const val MODE_NIGHT_YES = 2
    fun setDefaultNightMode(mode: Int) {}
    fun getApplicationLocales(): LocaleListCompat = LocaleListCompat.getEmptyLocaleList()
    fun setApplicationLocales(locales: LocaleListCompat) {}
}

class AlertDialog {
    class Builder(@Suppress("UNUSED_PARAMETER") context: Context) {
        fun setTitle(id: Int) = this
        fun setTitle(titre: CharSequence?) = this
        fun setMessage(id: Int) = this
        fun setMessage(message: CharSequence?) = this
        fun setItems(items: Array<out CharSequence>, ecouteur: DialogInterface.OnClickListener?) = this
        fun setView(vue: View?) = this
        fun setPositiveButton(id: Int, ecouteur: DialogInterface.OnClickListener?) = this
        fun setNegativeButton(id: Int, ecouteur: DialogInterface.OnClickListener?) = this
        fun setNeutralButton(id: Int, ecouteur: DialogInterface.OnClickListener?) = this
        fun show(): AlertDialog = AlertDialog()
    }
}
