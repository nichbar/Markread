package now.link.markread

import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

data class PendingFile(val path: String, val name: String)

class MainActivity : FlutterActivity() {
    private val CHANNEL = "now.link.markread/files"
    private var pendingFile: PendingFile? = null
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getPendingFile") {
                val file = pendingFile
                if (file != null) {
                    pendingFile = null
                    result.success(mapOf("path" to file.path, "name" to file.name))
                } else {
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return

        val name = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) cursor.getString(idx) else "Untitled"
            } else "Untitled"
        } ?: "Untitled"

        val tempFile = File(cacheDir, name)
        contentResolver.openInputStream(uri)?.use { input ->
            tempFile.outputStream().use { output -> input.copyTo(output) }
        }

        val file = PendingFile(tempFile.absolutePath, name)
        pendingFile = file

        // Clear intent data so Flutter doesn't treat the content:// URI as a deep link
        intent.data = null

        // For warm start: push to Flutter via MethodChannel
        channel?.invokeMethod("onFileReceived", mapOf(
            "path" to file.path,
            "name" to file.name
        ))
    }
}
