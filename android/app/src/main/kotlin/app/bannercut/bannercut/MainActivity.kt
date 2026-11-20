package app.bannercut.bannercut

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException

class MainActivity : FlutterActivity() {
    private var pendingPhoto: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.bannercut/photo")
            .setMethodCallHandler { call, result ->
                when {
                    call.method != "pickPhoto" -> result.notImplemented()
                    pendingPhoto != null -> result.error("BUSY", "A picker is already open.", null)
                    else -> {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                        }
                        pendingPhoto = result
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, PHOTO_REQUEST)
                        } catch (exception: android.content.ActivityNotFoundException) {
                            pendingPhoto = null
                            result.error("PICKER", "No photo picker available.", null)
                        }
                    }
                }
            }
    }

    @Deprecated("Receives results for the platform document picker.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PHOTO_REQUEST) return
        val result = pendingPhoto ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingPhoto = null
            result.success(null)
            return
        }
        Thread {
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        if (output.size() + count > MAX_PHOTO_BYTES) {
                            throw IOException("Photo exceeds the size limit.")
                        }
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                } ?: throw IOException("Photo cannot be opened.")
                runOnUiThread {
                    if (pendingPhoto === result) {
                        pendingPhoto = null
                        result.success(bytes)
                    }
                }
            } catch (exception: Exception) {
                runOnUiThread {
                    if (pendingPhoto === result) {
                        pendingPhoto = null
                        result.error("PHOTO", "Photo cannot be read.", null)
                    }
                }
            }
        }.start()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pendingPhoto?.success(null)
        pendingPhoto = null
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.bannercut/photo")
            .setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        const val PHOTO_REQUEST = 410
        const val MAX_PHOTO_BYTES = 20 * 1024 * 1024
    }
}
