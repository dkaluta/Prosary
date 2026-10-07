package com.dkaluta.prosary.ui.home

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import java.io.File
import java.io.IOException
import java.util.UUID

/** Gallery grants are temporary. Keep a bounded, orientation-correct private copy instead. */
internal object HomePhotoStore {
    private const val maximumSourceBytes = 50L * 1024 * 1024
    private const val maximumSide = 2048

    fun privateFile(filesDirectory: File, path: String): File? {
        if (path.isBlank()) return null
        val directory = File(filesDirectory, "homePhotos").canonicalFile
        val file = File(path).canonicalFile
        return file.takeIf { it.parentFile == directory && it.name.startsWith("home-photo-") && it.extension == "jpg" }
    }

    fun remove(filesDirectory: File, path: String) {
        val file = privateFile(filesDirectory, path) ?: return
        if (file.exists() && !file.delete()) throw IOException("Could not remove private photo")
    }

    fun load(filesDirectory: File, path: String): Bitmap {
        val file = privateFile(filesDirectory, path) ?: throw IOException("Invalid private photo")
        return BitmapFactory.decodeFile(file.path) ?: throw IOException("Unreadable private photo")
    }

    fun copy(context: Context, uri: Uri): String {
        val directory = File(context.filesDir, "homePhotos").apply { mkdirs() }
        val original = File.createTempFile("selected-", ".image", directory)
        val target = File(directory, "home-photo-${UUID.randomUUID()}.jpg")
        var bitmap: Bitmap? = null
        var rotated: Bitmap? = null
        try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                original.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    var bytes = 0L
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        bytes += count
                        if (bytes > maximumSourceBytes) throw IOException("Photo source is too large")
                        output.write(buffer, 0, count)
                    }
                }
            } ?: throw IOException("Photo is no longer accessible")
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(original.path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw IOException("Unsupported photo")
            var sample = 1
            while (maxOf(bounds.outWidth, bounds.outHeight) / sample > maximumSide) sample *= 2
            bitmap = BitmapFactory.decodeFile(original.path, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: throw IOException("Could not decode photo")
            val orientation = runCatching {
                ExifInterface(original.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
            val matrix = Matrix().apply {
                when (orientation) {
                    ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f, 1f)
                    ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
                    ExifInterface.ORIENTATION_FLIP_VERTICAL -> setScale(1f, -1f)
                    ExifInterface.ORIENTATION_TRANSPOSE -> { setRotate(90f); postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
                    ExifInterface.ORIENTATION_TRANSVERSE -> { setRotate(-90f); postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(-90f)
                }
            }
            val source = bitmap
            val finalImage = Bitmap.createBitmap(source, 0, 0, source.width, source.height, matrix, true)
            rotated = finalImage
            target.outputStream().use { output ->
                if (!finalImage.compress(Bitmap.CompressFormat.JPEG, 92, output)) throw IOException("Could not store photo")
            }
            return target.path
        } catch (error: Exception) {
            target.delete()
            throw error
        } finally {
            original.delete()
            if (rotated !== bitmap) rotated?.recycle()
            bitmap?.recycle()
        }
    }
}
