package com.myhitbodedut

import org.json.JSONObject
import java.security.SecureRandom
import java.text.Normalizer
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * La sauvegarde chiffrée par mot de passe (audit de sécurité du 12/11/2026).
 *
 * L'export JSON emporte le journal, des écrits intimes, vers l'endroit que
 * l'on choisit : un nuage, un courriel. En clair, quiconque ouvrait le
 * fichier les lisait. La clé vient du mot de passe par PBKDF2-HMAC-SHA256,
 * le fichier est chiffré en AES-256-GCM, qui en garantit aussi l'intégrité.
 * Sans le mot de passe il est illisible, et rien ne le retrouve.
 *
 * Même format que la version web (coffre.js) :
 * { format, version, kdf, iterations, salt, iv, data }, salt, iv et data
 * (chiffré suivi du sceau GCM) en base64.
 */
object Coffre {
    const val FORMAT = "myhitbodedut-chiffre"
    const val ITERATIONS = 600_000
    private const val KDF = "PBKDF2-HMAC-SHA256"

    /** Un fichier fabriqué ne fait pas tourner le téléphone sans fin, ni ne ramène la clé à presque rien. */
    private const val ITERATIONS_MIN = 100_000
    private const val ITERATIONS_MAX = 5_000_000

    /** Le fichier lu est-il une sauvegarde chiffrée ? */
    fun estChiffre(texte: String): Boolean =
        runCatching { JSONObject(texte).optString("format") == FORMAT }.getOrDefault(false)

    private fun cle(motDePasse: String, sel: ByteArray, iterations: Int): SecretKeySpec {
        val spec = PBEKeySpec(Normalizer.normalize(motDePasse, Normalizer.Form.NFC).toCharArray(), sel, iterations, 256)
        try {
            return SecretKeySpec(SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded, "AES")
        } finally {
            spec.clearPassword()
        }
    }

    /** Chiffre [texte] ; [iterations] ne se règle que dans les tests. À appeler hors du fil de l'interface. */
    fun chiffrer(texte: String, motDePasse: String, iterations: Int = ITERATIONS): String {
        val alea = SecureRandom()
        val sel = ByteArray(16).also { alea.nextBytes(it) }
        val iv = ByteArray(12).also { alea.nextBytes(it) }
        val chiffre = Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.ENCRYPT_MODE, cle(motDePasse, sel, iterations), GCMParameterSpec(128, iv))
            doFinal(texte.toByteArray(Charsets.UTF_8))
        }
        val b64 = Base64.getEncoder()
        return JSONObject()
            .put("format", FORMAT)
            .put("version", 1)
            .put("kdf", KDF)
            .put("iterations", iterations)
            .put("salt", b64.encodeToString(sel))
            .put("iv", b64.encodeToString(iv))
            .put("data", b64.encodeToString(chiffre))
            .toString(2)
    }

    /** Le texte en clair, ou null : mot de passe faux, fichier abîmé ou fabriqué. À appeler hors du fil de l'interface. */
    fun dechiffrer(texte: String, motDePasse: String): String? = runCatching {
        val r = JSONObject(texte)
        if (r.optString("format") != FORMAT || r.optInt("version") != 1 || r.optString("kdf") != KDF) return null
        val iterations = r.optInt("iterations")
        if (iterations < ITERATIONS_MIN || iterations > ITERATIONS_MAX) return null
        val b64 = Base64.getDecoder()
        val sel = b64.decode(r.getString("salt"))
        val iv = b64.decode(r.getString("iv"))
        if (sel.size < 16 || iv.size != 12) return null
        val clair = Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, cle(motDePasse, sel, iterations), GCMParameterSpec(128, iv))
            doFinal(b64.decode(r.getString("data")))
        }
        String(clair, Charsets.UTF_8)
    }.getOrNull()
}
