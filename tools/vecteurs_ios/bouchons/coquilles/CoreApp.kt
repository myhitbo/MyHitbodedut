package androidx.core.app

import android.content.Context

class NotificationManagerCompat private constructor() {
    fun cancel(id: Int) {}
    fun areNotificationsEnabled(): Boolean = true

    companion object {
        @JvmStatic fun from(@Suppress("UNUSED_PARAMETER") context: Context): NotificationManagerCompat = NotificationManagerCompat()
    }
}
