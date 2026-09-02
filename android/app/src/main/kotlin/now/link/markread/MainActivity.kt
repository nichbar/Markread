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

data class DiscoveredFont(
    val name: String,
    val path: String? = null,
    val hasChinese: Boolean = false,
    val isMonospace: Boolean = false
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "name" to name,
            "path" to path,
            "hasChinese" to hasChinese,
            "isMonospace" to isMonospace
        )
    }
}

class MainActivity : FlutterActivity() {
    private val CHANNEL_FILES = "now.link.markread/files"
    private val CHANNEL_SYSTEM_FONTS = "now.link.markread/system_fonts"
    private var pendingFile: PendingFile? = null
    private var filesChannel: MethodChannel? = null
    private var fontsChannel: MethodChannel? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private val fontDirs = listOf(
        "/system/fonts",
        "/product/fonts",
        "/system_ext/fonts",
        "/vendor/fonts"
    )

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

    private fun extractSystemFonts(): List<Map<String, Any?>> {
        val fontsMap = linkedMapOf<String, DiscoveredFont>()

        // 1. Register standard platform font aliases
        val standardAliases = listOf(
            DiscoveredFont("sans-serif", null, hasChinese = false, isMonospace = false),
            DiscoveredFont("sans-serif-medium", null, hasChinese = false, isMonospace = false),
            DiscoveredFont("sans-serif-condensed", null, hasChinese = false, isMonospace = false),
            DiscoveredFont("sans-serif-light", null, hasChinese = false, isMonospace = false),
            DiscoveredFont("serif", null, hasChinese = false, isMonospace = false),
            DiscoveredFont("monospace", null, hasChinese = false, isMonospace = true),
            DiscoveredFont("casual", null, hasChinese = false, isMonospace = false),
            DiscoveredFont("cursive", null, hasChinese = false, isMonospace = false)
        )
        for (font in standardAliases) {
            fontsMap[font.name.lowercase()] = font
        }

        // 2. Parse XML font configuration files
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
                parseFontsXml(file, fontsMap)
            }
        }

        // 3. Scan system and OEM font directories
        scanFontDirectories(fontsMap)

        return fontsMap.values
            .filter { it.name.isNotBlank() && !it.name.startsWith("@") }
            .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.name })
            .map { it.toMap() }
    }

    private fun resolveFontFilePath(fileNameOrPath: String): String? {
        val trimmed = fileNameOrPath.trim()
        if (trimmed.isEmpty()) return null

        val directFile = File(trimmed)
        if (directFile.isAbsolute && directFile.exists() && directFile.canRead()) {
            return directFile.absolutePath
        }

        for (dir in fontDirs) {
            val candidate = File(dir, trimmed)
            if (candidate.exists() && candidate.canRead()) {
                return candidate.absolutePath
            }
        }
        return null
    }

    private fun addOrUpdateFont(
        fontsMap: MutableMap<String, DiscoveredFont>,
        name: String,
        path: String?,
        hasChinese: Boolean,
        isMonospace: Boolean
    ) {
        val cleanName = name.trim()
        if (cleanName.isBlank() || cleanName.startsWith("@")) return

        val key = cleanName.lowercase()
        val existing = fontsMap[key]
        if (existing != null) {
            val resolvedPath = existing.path ?: path
            val resolvedChinese = existing.hasChinese || hasChinese
            val resolvedMono = existing.isMonospace || isMonospace
            fontsMap[key] = existing.copy(
                path = resolvedPath,
                hasChinese = resolvedChinese,
                isMonospace = resolvedMono
            )
        } else {
            fontsMap[key] = DiscoveredFont(
                name = cleanName,
                path = path,
                hasChinese = hasChinese,
                isMonospace = isMonospace
            )
        }
    }

    private fun parseFontsXml(file: File, fontsMap: MutableMap<String, DiscoveredFont>) {
        try {
            FileInputStream(file).use { stream ->
                val parser = Xml.newPullParser()
                parser.setInput(stream, "utf-8")
                var eventType = parser.eventType
                var currentFamilyName: String? = null
                var currentLang: String? = null
                var currentVariant: String? = null

                while (eventType != XmlPullParser.END_DOCUMENT) {
                    when (eventType) {
                        XmlPullParser.START_TAG -> {
                            val tag = parser.name
                            if (tag == "family") {
                                currentFamilyName = parser.getAttributeValue(null, "name")
                                currentLang = parser.getAttributeValue(null, "lang")
                                currentVariant = parser.getAttributeValue(null, "variant")
                                if (!currentFamilyName.isNullOrBlank()) {
                                    val isMono = isMonospaceFont(currentFamilyName, "")
                                    val isZh = isChineseLang(currentLang) || isChineseFont(currentFamilyName, "")
                                    addOrUpdateFont(fontsMap, currentFamilyName, null, isZh, isMono)
                                }
                            } else if (tag == "alias") {
                                val name = parser.getAttributeValue(null, "name")
                                if (!name.isNullOrBlank()) {
                                    val isMono = isMonospaceFont(name, "")
                                    val isZh = isChineseFont(name, "")
                                    addOrUpdateFont(fontsMap, name, null, isZh, isMono)
                                }
                            } else if (tag == "font") {
                                val postScriptName = parser.getAttributeValue(null, "postScriptName")
                                val weight = parser.getAttributeValue(null, "weight")
                                val isRegularWeight = weight == null || weight == "400" || weight == "normal"

                                // Check if this font element contains text or postScriptName
                                if (!postScriptName.isNullOrBlank()) {
                                    val clean = formatFontName(postScriptName)
                                    if (clean.isNotBlank()) {
                                        val isMono = isMonospaceFont(clean, postScriptName)
                                        val isZh = isChineseLang(currentLang) || isChineseFont(clean, postScriptName)
                                        addOrUpdateFont(fontsMap, clean, null, isZh, isMono)
                                    }
                                }
                            }
                        }
                        XmlPullParser.TEXT -> {
                            val text = parser.text?.trim()
                            if (!text.isNullOrBlank() && isFontFileName(text)) {
                                val resolvedPath = resolveFontFilePath(text)
                                val isZhLang = isChineseLang(currentLang)
                                val isSerifVariant = currentVariant.equals("serif", ignoreCase = true)

                                // Check specific font mappings
                                mapAndRegisterFontFile(text, resolvedPath, isZhLang, isSerifVariant, fontsMap)

                                if (currentFamilyName != null && currentFamilyName.isNotBlank()) {
                                    val isMono = isMonospaceFont(currentFamilyName, text)
                                    val isZh = isZhLang || isChineseFont(currentFamilyName, text)
                                    addOrUpdateFont(fontsMap, currentFamilyName, resolvedPath, isZh, isMono)
                                }
                            }
                        }
                        XmlPullParser.END_TAG -> {
                            if (parser.name == "family") {
                                currentFamilyName = null
                                currentLang = null
                                currentVariant = null
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

    private fun scanFontDirectories(fontsMap: MutableMap<String, DiscoveredFont>) {
        for (dirPath in fontDirs) {
            val dir = File(dirPath)
            if (dir.exists() && dir.isDirectory) {
                dir.listFiles()?.forEach { file ->
                    if (file.isFile && isFontFileName(file.name)) {
                        val path = file.absolutePath
                        val fileName = file.name

                        // Map known CJK / OEM / Monospace fonts
                        mapAndRegisterFontFile(fileName, path, false, false, fontsMap)

                        // Format general font name
                        val formattedName = formatFontName(fileName)
                        if (formattedName.isNotBlank() && !isInternalClockOrIconFont(fileName)) {
                            val isMono = isMonospaceFont(formattedName, fileName)
                            val isZh = isChineseFont(formattedName, fileName)
                            addOrUpdateFont(fontsMap, formattedName, path, isZh, isMono)
                        }
                    }
                }
            }
        }
    }

    private fun mapAndRegisterFontFile(
        fileName: String,
        filePath: String?,
        isZhLang: Boolean,
        isSerifVariant: Boolean,
        fontsMap: MutableMap<String, DiscoveredFont>
    ) {
        val lower = fileName.lowercase()

        // 1. CJK Serif fonts
        if (lower.contains("notoserifcjk") || lower.contains("notoserifsc") || lower.contains("notoserifhans") || (isZhLang && isSerifVariant)) {
            addOrUpdateFont(fontsMap, "Noto Serif SC", filePath, hasChinese = true, isMonospace = false)
            addOrUpdateFont(fontsMap, "Noto Serif CJK", filePath, hasChinese = true, isMonospace = false)
        } else if (lower.contains("notoseriftc") || lower.contains("notoserifhant") || lower.contains("notoserifhk")) {
            addOrUpdateFont(fontsMap, "Noto Serif TC", filePath, hasChinese = true, isMonospace = false)
        }

        // 2. CJK Sans fonts
        if (lower.contains("notosanscjk") || lower.contains("notosanssc") || lower.contains("notosanshans") || (isZhLang && !isSerifVariant)) {
            addOrUpdateFont(fontsMap, "Noto Sans SC", filePath, hasChinese = true, isMonospace = false)
            addOrUpdateFont(fontsMap, "Noto Sans CJK", filePath, hasChinese = true, isMonospace = false)
        } else if (lower.contains("notosanstc") || lower.contains("notosanshant") || lower.contains("notosanshk")) {
            addOrUpdateFont(fontsMap, "Noto Sans TC", filePath, hasChinese = true, isMonospace = false)
        }

        // 3. OEM Chinese fonts
        if (lower.contains("misansroundedsc") || lower.contains("misansround")) {
            addOrUpdateFont(fontsMap, "MiSans Rounded SC", filePath, hasChinese = true, isMonospace = false)
        } else if (lower.contains("misans")) {
            addOrUpdateFont(fontsMap, "MiSans", filePath, hasChinese = true, isMonospace = false)
        }

        if (lower.contains("harmonyos_sans_sc") || lower.contains("harmonyossanssc")) {
            addOrUpdateFont(fontsMap, "HarmonyOS Sans SC", filePath, hasChinese = true, isMonospace = false)
        } else if (lower.contains("harmonyos_sans_tc") || lower.contains("harmonyossanstc")) {
            addOrUpdateFont(fontsMap, "HarmonyOS Sans TC", filePath, hasChinese = true, isMonospace = false)
        }

        if (lower.contains("opposans") || lower.contains("oplussans")) {
            addOrUpdateFont(fontsMap, "OPPOSans", filePath, hasChinese = true, isMonospace = false)
        }

        if (lower.contains("vivosans")) {
            addOrUpdateFont(fontsMap, "VivoSans", filePath, hasChinese = true, isMonospace = false)
        }

        if (lower.contains("dela_gothic") || lower.contains("delagothicone")) {
            addOrUpdateFont(fontsMap, "Dela Gothic One", filePath, hasChinese = true, isMonospace = false)
        }

        if (lower.contains("beihaibeisc") || lower.contains("beihaibei")) {
            addOrUpdateFont(fontsMap, "Beihaibei SC", filePath, hasChinese = true, isMonospace = false)
        }

        if (lower.contains("droidsansfallback")) {
            addOrUpdateFont(fontsMap, "Droid Sans Fallback", filePath, hasChinese = true, isMonospace = false)
        }

        // 4. Monospace fonts
        if (lower.contains("droidsansmono")) {
            addOrUpdateFont(fontsMap, "Droid Sans Mono", filePath, hasChinese = false, isMonospace = true)
        }
        if (lower.contains("notosansmono")) {
            addOrUpdateFont(fontsMap, "Noto Sans Mono", filePath, hasChinese = false, isMonospace = true)
        }
        if (lower.contains("cutivemono")) {
            addOrUpdateFont(fontsMap, "Cutive Mono", filePath, hasChinese = false, isMonospace = true)
        }
        if (lower.contains("robotomono")) {
            addOrUpdateFont(fontsMap, "Roboto Mono", filePath, hasChinese = false, isMonospace = true)
        }
        if (lower.contains("jetbrainsmono") || lower.contains("jetbrains_mono")) {
            addOrUpdateFont(fontsMap, "JetBrains Mono", filePath, hasChinese = false, isMonospace = true)
        }
        if (lower.contains("firacode") || lower.contains("fira_code") || lower.contains("firamono") || lower.contains("fira_mono")) {
            addOrUpdateFont(fontsMap, "Fira Code", filePath, hasChinese = false, isMonospace = true)
        }
        if (lower.contains("sourcecodepro") || lower.contains("source_code_pro")) {
            addOrUpdateFont(fontsMap, "Source Code Pro", filePath, hasChinese = false, isMonospace = true)
        }
    }

    private fun isFontFileName(name: String): Boolean {
        val lower = name.lowercase()
        return lower.endsWith(".ttf") || lower.endsWith(".otf") || lower.endsWith(".ttc")
    }

    private fun isChineseLang(lang: String?): Boolean {
        if (lang == null) return false
        val lower = lang.lowercase()
        return lower.contains("zh") || lower.contains("cjk") || lower.contains("hans") || lower.contains("hant")
    }

    private fun isChineseFont(name: String, fileName: String): Boolean {
        val combined = "$name $fileName".lowercase()
        return combined.contains("zh") ||
                combined.contains("cjk") ||
                combined.contains("hans") ||
                combined.contains("hant") ||
                combined.contains("chinese") ||
                combined.contains("notosanssc") ||
                combined.contains("notoserifsc") ||
                combined.contains("notosanstc") ||
                combined.contains("notoseriftc") ||
                combined.contains("misans") ||
                combined.contains("harmonyos") ||
                combined.contains("opposans") ||
                combined.contains("oplussans") ||
                combined.contains("vivosans") ||
                combined.contains("delagothic") ||
                combined.contains("dela gothic") ||
                combined.contains("beihaibei") ||
                combined.contains("droidsansfallback")
    }

    private fun isMonospaceFont(name: String, fileName: String): Boolean {
        val combined = "$name $fileName".lowercase()
        return combined == "monospace" ||
                combined.contains("mono") ||
                combined.contains("code") ||
                combined.contains("typewriter") ||
                combined.contains("consolas") ||
                combined.contains("courier")
    }

    private fun isInternalClockOrIconFont(name: String): Boolean {
        val lower = name.lowercase()
        return lower.startsWith("androidclock") || lower.startsWith("miclock") || lower.contains("clock")
    }

    private fun formatFontName(rawName: String): String {
        if (rawName.isBlank() || rawName.startsWith("@")) return ""
        val clean = rawName
            .replace(Regex("\\.(ttf|otf|ttc)$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("[-_]?(Regular|Bold|Light|Medium|Thin|Black|Semibold|ExtraBold|VF|Overlay|Italic|BoldItalic)$", RegexOption.IGNORE_CASE), "")
            .replace(Regex("[-_]"), " ")
            .trim()
        return clean
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
