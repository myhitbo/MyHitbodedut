package com.myhitbodedut

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.DecodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer

/**
 * Un billet en PDF ou en photo (04/11) : on y cherche le code-barres de la carte d'embarquement
 * (PDF417, Aztec, QR, Data Matrix), lu par ZXing sur le téléphone — rien ne part, aucune
 * permission (le fichier est choisi par l'utilisateur). Le contenu du code est ensuite lu par
 * CarteEmbarquement. Hors du fil de l'interface.
 */
object LecteurBillet {

    private const val PAGES_MAX = 4
    private const val COTE_MAX = 2400

    /**
     * Le texte du premier code-barres trouvé, ou null s'il n'y en a pas. Les pages se rendent et se
     * décodent une à une (une seule en mémoire) et la lecture s'arrête au premier code (FVOL-17).
     * Un fichier qu'on ne peut pas ouvrir, ou la mémoire qui manque, lève une exception : l'écran
     * dit alors que le billet n'a pas pu être ouvert, et non qu'il n'a pas de code-barres.
     */
    fun code(context: Context, uri: Uri): String? {
        val type = context.contentResolver.getType(uri).orEmpty()
        if (type == "application/pdf" || uri.toString().endsWith(".pdf", ignoreCase = true)) return codeDuPdf(context, uri)
        val b = image(context, uri) ?: throw java.io.IOException("image illisible")
        return decoderEtLiberer(b)
    }

    private fun codeDuPdf(context: Context, uri: Uri): String? {
        val fd = context.contentResolver.openFileDescriptor(uri, "r") ?: throw java.io.IOException("fichier introuvable")
        fd.use {
            PdfRenderer(fd).use { pdf ->
                for (i in 0 until minOf(pdf.pageCount, PAGES_MAX)) {
                    val b = pdf.openPage(i).use { page ->
                        val echelle = COTE_MAX.toFloat() / maxOf(page.width, page.height)
                        val b = Bitmap.createBitmap((page.width * echelle).toInt().coerceAtLeast(1), (page.height * echelle).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
                        b.eraseColor(Color.WHITE)
                        page.render(b, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                        b
                    }
                    decoderEtLiberer(b)?.let { return it }
                }
            }
        }
        return null
    }

    /** Le code de l'image, puis de sa copie tournée de 90° ; les deux images sont libérées. */
    private fun decoderEtLiberer(b: Bitmap): String? {
        try {
            decoder(b)?.let { return it }
            val t = tourner(b)
            try { return decoder(t) } finally { t.recycle() }
        } finally {
            b.recycle()
        }
    }

    private fun image(context: Context, uri: Uri): Bitmap? = runCatching {
        val bornes = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bornes) }
        var echantillon = 1
        while (maxOf(bornes.outWidth, bornes.outHeight) / echantillon > COTE_MAX) echantillon *= 2
        context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = echantillon }) }
    }.getOrNull()

    private fun tourner(b: Bitmap): Bitmap = Bitmap.createBitmap(b, 0, 0, b.width, b.height, Matrix().apply { postRotate(90f) }, true)

    private fun decoder(b: Bitmap): String? {
        val pixels = IntArray(b.width * b.height)
        b.getPixels(pixels, 0, b.width, 0, 0, b.width, b.height)
        val source = RGBLuminanceSource(b.width, b.height, pixels)
        val indices = mapOf(
            DecodeHintType.POSSIBLE_FORMATS to listOf(BarcodeFormat.PDF_417, BarcodeFormat.AZTEC, BarcodeFormat.QR_CODE, BarcodeFormat.DATA_MATRIX),
            DecodeHintType.TRY_HARDER to true,
        )
        return runCatching { MultiFormatReader().decode(BinaryBitmap(HybridBinarizer(source)), indices).text }.getOrNull()
    }
}
