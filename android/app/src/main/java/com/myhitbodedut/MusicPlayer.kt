package com.myhitbodedut

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Lecture d'un morceau pendant la séance. Demande le focus audio, pour que
 * les autres applications se taisent, et s'arrête en fondu.
 */
class MusicPlayer(private val context: Context) {

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var volume = 1f

    /**
     * La demande de focus audio, la même du début à la fin (13/11, audit
     * FSEANCE-02). Android reconnaît un client à son écouteur : une demande
     * neuve à chaque reprise était un second client de la même application,
     * et le premier recevait AUDIOFOCUS_LOSS, donc coupait le morceau qu'on
     * venait de relancer. « Pause » puis « Lecture » donnait un instant de
     * son, puis le silence, et la position était perdue.
     */
    private val focusRequest: AudioFocusRequest by lazy {
        AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(attributes())
            .setOnAudioFocusChangeListener { change ->
                when (change) {
                    AudioManager.AUDIOFOCUS_LOSS -> stop(fade = false)
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> runCatching { player?.pause() }
                    AudioManager.AUDIOFOCUS_GAIN -> if (!enPause) runCatching { player?.start() }
                }
            }
            .build()
    }

    /** Le focus est demandé ou tenu : il n'y a rien à rendre sinon. */
    private var focusDemande = false

    val isPlaying: Boolean get() = runCatching { player?.isPlaying == true }.getOrDefault(false)

    /** Un morceau est chargé, qu'il joue ou qu'on l'ait mis en pause (mini-lecteur, 19/10). */
    val charge: Boolean get() = player != null

    /** Mis en pause par le mini-lecteur : ni le service ni le focus audio ne le relancent. */
    var enPause = false
        private set

    /** Position et durée du morceau, en millisecondes ; 0 sans morceau. */
    val position: Int get() = runCatching { player?.currentPosition ?: 0 }.getOrDefault(0)
    val duree: Int get() = runCatching { player?.duration ?: 0 }.getOrDefault(0).coerceAtLeast(0)

    fun pause() {
        enPause = true
        runCatching { player?.pause() }
    }

    fun reprendre() {
        enPause = false
        if (player != null && requestFocus()) runCatching { player?.start() }
    }

    fun aller(ms: Int) {
        runCatching { player?.seekTo(ms.coerceIn(0, duree)) }
    }

    /**
     * Joue `track`. Avec `onEnd`, le morceau ne boucle pas : la fin appelle
     * `onEnd`, qui enchaîne le suivant (lecture aléatoire).
     */
    fun start(
        track: Track,
        volumePercent: Int,
        loop: Boolean = true,
        onEnd: (() -> Unit)? = null
    ): Boolean {
        stop(fade = false)
        enPause = false
        // Les attributs audio se posent avant prepare(), sans quoi certains
        // appareils lèvent une exception d'état.
        val brut = MediaPlayer()
        val created = runCatching {
            brut.apply {
                setAudioAttributes(attributes())
                if (track.isBundled) {
                    context.resources.openRawResourceFd(track.rawRes).use { fd ->
                        setDataSource(fd.fileDescriptor, fd.startOffset, fd.declaredLength)
                    }
                } else {
                    setDataSource(context, track.uri!!)
                }
                prepare()
            }
        }.onFailure {
            // Le lecteur créé avant l'échec est libéré, sinon il restait en mémoire (FSEANCE-22).
            runCatching { brut.release() }
            Log.w(TAG, "lecture impossible : ${track.id}", it)
        }.getOrNull() ?: return false

        created.isLooping = loop && onEnd == null
        if (onEnd != null) {
            created.setOnCompletionListener { handler.post { if (player === created) onEnd() } }
        }
        player = created
        setVolume(volumePercent)

        if (!requestFocus()) {
            Log.w(TAG, "focus audio refusé : ${track.id}")
            stop(fade = false)
            return false
        }
        return runCatching { created.start(); true }
            .onFailure { Log.w(TAG, "démarrage impossible : ${track.id}", it) }
            .getOrDefault(false)
    }

    private companion object {
        const val TAG = "MusicPlayer"
    }

    fun setVolume(percent: Int) {
        volume = (percent.coerceIn(0, 100) / 100f)
        runCatching { player?.setVolume(volume, volume) }
    }

    fun stop(fade: Boolean = true) {
        val current = player ?: run { abandonFocus(); return }
        player = null
        if (!fade) {
            release(current)
            return
        }
        // Fondu court : couper net une musique de méditation est désagréable.
        var step = 10
        val level = volume
        val tick = object : Runnable {
            override fun run() {
                if (step <= 0) {
                    release(current)
                    return
                }
                val v = level * step / 10f
                runCatching { current.setVolume(v, v) }
                step--
                handler.postDelayed(this, 60L)
            }
        }
        handler.post(tick)
    }

    private fun release(target: MediaPlayer) {
        runCatching { if (target.isPlaying) target.stop() }
        runCatching { target.release() }
        // Un morceau relancé pendant le fondu du précédent tient le même
        // focus : la fin du fondu ne doit pas le lui retirer.
        if (player == null) abandonFocus()
    }

    private fun audioManager(): AudioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun attributes(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()

    /** Redemander avec la même demande ne retire rien à personne : c'est le même client. */
    private fun requestFocus(): Boolean {
        focusDemande = true
        return audioManager().requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonFocus() {
        if (!focusDemande) return
        focusDemande = false
        runCatching { audioManager().abandonAudioFocusRequest(focusRequest) }
    }
}
