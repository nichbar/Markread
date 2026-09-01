package now.link.markread

import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Xml
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.xmlpull.v1.XmlPullParser
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

data class PendingFile(val path: String, val name: String)

class MainActivity : FlutterActivity() {
    private val CHANNEL_FILES = "now.link.markread/files"
    private val CHANNEL_SYSTEM_FONTS = "now.link.markread/system_fonts"
    private var pendingFile: PendingFile? = null
    private var filesChannel: MethodChannel? = null
    private var fontsChannel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        filesChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_FILES)
        filesChannel?.setMethodCallHandler { call, result ->
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

        fontsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_SYSTEM_FONTS)
        fontsChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getSystemFonts") {
                executor.execute {
                    try {
                        val fonts = extractSystemFonts()
                        mainHandler.post {
                            result.success(fonts)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("FONT_SCAN_ERROR", e.localizedMessage, null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }

        handleIntent(intent)
    }

    private fun extractSystemFonts(): List<String> {
        val fontNames = linkedSetOf<String>()
        val rawFontFiles = linkedSetOf<String>()

        val standardAliases = listOf(
            "sans-serif",
            "sans-serif-medium",
            "sans-serif-condensed",
            "sans-serif-light",
            "serif",
            "monospace",
            "casual",
            "cursive"
        )
        fontNames.addAll(standardAliases)

        val xmlPaths = listOf(
            "/system/etc/fonts.xml",
            "/system_ext/etc/fonts.xml",
            "/product/etc/fonts.xml",
            "/vendor/etc/fonts.xml",
            "/system/etc/system_fonts.xml"
        )

        for (path in xmlPaths) {
            val file = File(path)
            if (file.exists() && file.canRead()) {
                parseFontsXml(file, fontNames, rawFontFiles)
            }
        }

        scanFontDirectories(fontNames, rawFontFiles)

        return fontNames
            .map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("@") && !it.endsWith(".ttf", ignoreCase = true) && !it.endsWith(".otf", ignoreCase = true) }
            .distinctBy { it.lowercase() }
            .sortedWith(String.CASE_INSENSITIVE_ORDER)
    }

    private fun parseFontsXml(file: File, fontNames: MutableSet<String>, rawFontFiles: MutableSet<String>) {
        try {
            FileInputStream(file).use { stream ->
                val parser = Xml.newPullParser()
                parser.setInput(stream, "utf-8")
                var eventType = parser.eventType
                var currentFamilyName: String? = null
                var currentLang: String? = null

                while (eventType != XmlPullParser.END_DOCUMENT) {
                    when (eventType) {
                        XmlPullParser.START_TAG -> {
                            val tag = parser.name
                            if (tag == "family") {
                                currentFamilyName = parser.getAttributeValue(null, "name")
                                currentLang = parser.getAttributeValue(null, "lang")
                                if (!currentFamilyName.isNullOrBlank()) {
                                    fontNames.add(currentFamilyName.trim())
                                }
                            } else if (tag == "alias") {
                                val name = parser.getAttributeValue(null, "name")
                                if (!name.isNullOrBlank()) {
                                    fontNames.add(name.trim())
                                }
                            } else if (tag == "font") {
                                val postScriptName = parser.getAttributeValue(null, "postScriptName")
                                if (!postScriptName.isNullOrBlank()) {
                                    addFormattedFontName(postScriptName.trim(), fontNames)
                                }
                            }
                        }
                        XmlPullParser.TEXT -> {
                            val text = parser.text?.trim()
                            if (!text.isNullOrBlank() && (text.endsWith(".ttf", ignoreCase = true) || text.endsWith(".otf", ignoreCase = true) || text.endsWith(".ttc", ignoreCase = true))) {
                                rawFontFiles.add(text)
                                if (currentLang != null && (currentLang.contains("zh", ignoreCase = true) || currentLang.contains("cjk", ignoreCase = true) || currentLang.contains("hans", ignoreCase = true) || currentLang.contains("hant", ignoreCase = true))) {
                                    addChineseFontNames(text, fontNames)
                                }
                            }
                        }
                        XmlPullParser.END_TAG -> {
                            if (parser.name == "family") {
                                currentFamilyName = null
                                currentLang = null
                            }
                        }
                    }
                    eventType = parser.next()
                }
            }
        } catch (_: Exception) {
            // Ignore parse errors for optional vendor xml files
        }
    }

    private fun scanFontDirectories(fontNames: MutableSet<String>, rawFontFiles: MutableSet<String>) {
        val fontDirs = listOf(
            "/system/fonts",
            "/product/fonts",
            "/system_ext/fonts",
            "/vendor/fonts"
        )
        for (dirPath in fontDirs) {
            val dir = File(dirPath)
            if (dir.exists() && dir.isDirectory) {
                dir.listFiles()?.forEach { file ->
                    if (file.isFile) {
                        val name = file.name
                        if (name.endsWith(".ttf", ignoreCase = true) ||
                            name.endsWith(".otf", ignoreCase = true) ||
                            name.endsWith(".ttc", ignoreCase = true)) {
                            rawFontFiles.add(name)
                            addChineseFontNames(name, fontNames)
                        }
                    }
                }
            }
        }
    }

    private fun addChineseFontNames(fontFileName: String, fontNames: MutableSet<String>) {
        val lower = fontFileName.lowercase()
        when {
            lower.contains("notosanscjk") || lower.contains("notosanssc") || lower.contains("notosanshans") -> {
                fontNames.add("Noto Sans SC")
                fontNames.add("Noto Sans CJK")
            }
            lower.contains("notoserifcjk") || lower.contains("notoserifsc") || lower.contains("notoserifhans") -> {
                fontNames.add("Noto Serif SC")
                fontNames.add("Noto Serif CJK")
            }
            lower.contains("notosanstc") || lower.contains("notosanshant") || lower.contains("notosanshk") -> {
                fontNames.add("Noto Sans TC")
            }
            lower.contains("notoseriftc") || lower.contains("notoserifhant") || lower.contains("notoserifhk") -> {
                fontNames.add("Noto Serif TC")
            }
            lower.contains("misansroundedsc") || lower.contains("misansround") -> {
                fontNames.add("MiSans Rounded SC")
            }
            lower.contains("misans") -> {
                fontNames.add("MiSans")
            }
            lower.contains("harmonyos_sans_sc") || lower.contains("harmonyossanssc") -> {
                fontNames.add("HarmonyOS Sans SC")
            }
            lower.contains("harmonyos_sans_tc") || lower.contains("harmonyossanstc") -> {
                fontNames.add("HarmonyOS Sans TC")
            }
            lower.contains("opposans") || lower.contains("oplussans") -> {
                fontNames.add("OPPOSans")
            }
            lower.contains("vivosans") -> {
                fontNames.add("VivoSans")
            }
            lower.contains("dela_gothic") || lower.contains("delagothicone") -> {
                fontNames.add("Dela Gothic One")
            }
            lower.contains("beihaibeisc") -> {
                fontNames.add("Beihaibei SC")
            }
            lower.contains("droidsansfallback") -> {
                fontNames.add("Droid Sans Fallback")
            }
        }
    }

    private fun addFormattedFontName(name: String, fontNames: MutableSet<String>) {
        if (name.isBlank() || name.startsWith("@")) return
        val lower = name.lowercase()
        // Skip purely internal clock or icon fonts
        if (lower.startsWith("androidclock") || lower.startsWith("miclock")) return

        val cleanName = name
            .replace(Regex("[-_]?(Regular|Bold|Light|Medium|Thin|Black|Semibold|ExtraBold|VF|Overlay)$", RegexOption.IGNORE_CASE), "")
            .trim()

        if (cleanName.isNotEmpty() && !cleanName.startsWith("@")) {
            fontNames.add(cleanName)
        }
        addChineseFontNames(name, fontNames)
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
        filesChannel?.invokeMethod("onFileReceived", mapOf(
            "path" to file.path,
            "name" to file.name
        ))
    }
}
