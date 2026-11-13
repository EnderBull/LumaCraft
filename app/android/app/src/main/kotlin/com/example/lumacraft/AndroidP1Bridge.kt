package com.example.lumacraft

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.ColorSpace
import android.graphics.ImageDecoder
import android.os.Build
import android.os.Debug
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.content.pm.PackageManager
import java.io.FileNotFoundException
import java.io.InputStream
import android.provider.OpenableColumns
import android.webkit.WebView
import android.webkit.WebChromeClient
import android.webkit.WebViewClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/** Android-only adapter for the P1 entry point. All rendering stays in Dart. */
internal class AndroidP1Bridge(private val activity: FlutterActivity) {
    private val worker = Executors.newSingleThreadExecutor()
    private var picker: MethodChannel.Result? = null
    private var pickingPreset = false
    private var pickingPhotos = false
    private var pickingPhotoLocation = false
    private var pendingLocationPicker: (() -> Unit)? = null
    private var locationPermissionPrompted = false
    private var presetOutput: File? = null
    private val incoming = ArrayDeque<Intent>()
    private var appChannel: MethodChannel? = null
    private var finishPlaceLookup: ((String) -> Unit)? = null

    fun cancelPlaceLookup() {
        finishPlaceLookup?.invoke("GEOCODE_ERR:地图查询已取消")
    }

    fun receive(intent: Intent?) {
        if (intent?.action !in listOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE, Intent.ACTION_VIEW)) return
        incoming.addLast(Intent(requireNotNull(intent)))
        appChannel?.invokeMethod("incoming", null)
    }

    @Suppress("DEPRECATION")
    private fun inputUris(intent: Intent): Set<Uri> = linkedSetOf<Uri>().apply {
        intent.data?.let { add(it) }
        intent.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) clip.getItemAt(index).uri?.let { add(it) }
        }
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.let { addAll(it) }
        } else {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let { add(it) }
        }
    }

    private fun hasPhotoLocationPermission() =
        activity.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    fun onPermissionResult(request: Int) {
        if (request != locationPermissionCode) return
        val launch = pendingLocationPicker
        pendingLocationPicker = null
        launch?.invoke()
    }

    private fun openPhoto(uri: Uri, locationAccess: Boolean): InputStream? {
        val resolver = activity.contentResolver
        if (!locationAccess || !hasPhotoLocationPermission()) return resolver.openInputStream(uri)
        // The system photo picker controls sharing for its own URIs. Read the
        // stream it granted, so its location-sharing decision is respected.
        if (uri.authority == MediaStore.AUTHORITY &&
            uri.pathSegments.firstOrNull()?.startsWith("picker") == true) {
            return resolver.openInputStream(uri)
        }
        try {
            val mediaUri = when {
                uri.authority == MediaStore.AUTHORITY -> uri
                DocumentsContract.isDocumentUri(activity, uri) -> MediaStore.getMediaUri(activity, uri)
                else -> null
            }
            if (mediaUri != null) {
                resolver.openInputStream(MediaStore.setRequireOriginal(mediaUri))?.let { return it }
            }
        } catch (_: SecurityException) {
            // The provider's original-media grant may be narrower than its file grant.
        } catch (_: IllegalArgumentException) {
            // This document provider does not expose a MediaStore equivalent.
        } catch (_: UnsupportedOperationException) {
            // This provider does not support the original-media request.
        } catch (_: FileNotFoundException) {
            // A provider can return an ordinary document stream only.
        }
        return resolver.openInputStream(uri)
    }

    private fun sessionPhoto(uri: Uri, locationAccess: Boolean = false): Map<String, Any?> {
        require(uri.scheme == "content") { "不支持的照片来源" }
        try {
            activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
            val folder = File(activity.filesDir, "session-photos").apply { mkdirs() }
            return copyDocument(uri, false, folder, locationAccess) + ("locationAccess" to locationAccess)
        }
        val name = documentName(uri)
        val file = File.createTempFile("p1-source-", photoSuffix(name), activity.cacheDir)
        file.delete()
        return mapOf("path" to file.path, "name" to name, "uri" to uri.toString(),
            "locationAccess" to locationAccess)
    }

    private fun materializePhoto(uri: Uri, path: String, locationAccess: Boolean): String {
        val file = File(path)
        require(uri.scheme == "content" &&
            file.parentFile?.canonicalFile == activity.cacheDir.canonicalFile &&
            file.name.startsWith("p1-source-"))
        val resolver = activity.contentResolver
        check(resolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission })
        if (!file.exists()) {
            val stage = File.createTempFile("p1-stage-", ".part", activity.cacheDir)
            try {
                requireNotNull(openPhoto(uri, locationAccess)).use { input ->
                    stage.outputStream().use { input.copyTo(it) }
                }
                check(stage.renameTo(file))
            } finally {
                stage.delete()
            }
        }
        return file.path
    }

    fun attach(channel: MethodChannel) {
        appChannel = channel
        channel.setMethodCallHandler { call, result ->
            if (Build.VERSION.SDK_INT < 31) {
                result.error("ANDROID_VERSION", "P1 requires Android 12 or newer.", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "startExport" -> {
                    val total = requireNotNull(call.argument<Int>("total"))
                    if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(
                        android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) {
                        activity.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 6122)
                    }
                    AndroidExportService.onCancel = { channel.invokeMethod("cancelExport", null) }
                    AndroidExportService.onStarted = { error ->
                        if (error == null) result.success(null) else result.error("EXPORT_START", error.message, null)
                    }
                    try {
                        activity.startForegroundService(Intent(activity, AndroidExportService::class.java)
                            .putExtra("total", total))
                    } catch (error: Exception) {
                        AndroidExportService.onStarted = null
                        result.error("EXPORT_START", error.message, null)
                    }
                }
                "exportProgress" -> {
                    AndroidExportService.active?.update(call.argument<Int>("completed") ?: 0, call.argument<Int>("total") ?: 0)
                    result.success(null)
                }
                "finishExport" -> {
                    AndroidExportService.onCancel = null
                    activity.stopService(Intent(activity, AndroidExportService::class.java))
                    result.success(null)
                }
                "peekIncoming" -> result.success(incoming.firstOrNull()?.let {
                    if (it.action == Intent.ACTION_VIEW) "preset" else "photos"
                })
                "discardIncoming" -> { incoming.removeFirstOrNull(); result.success(null) }
                "readIncoming" -> {
                    val next = incoming.removeFirstOrNull()
                    if (next == null) result.success(null) else background(result) {
                        val items = inputUris(next)
                        require(items.isNotEmpty() && items.size <= photoLimit) { "请选择 1～30 个文件" }
                        require(items.all { it.scheme == "content" }) { "不支持的文件来源" }
                        if (next.action == Intent.ACTION_VIEW) listOf(copyDocument(items.single(), true))
                        else items.map { sessionPhoto(it) }
                    }
                }
                "sweepSessionPhotos" -> background(result) {
                    val kept = call.argument<List<String>>("paths").orEmpty().toSet()
                    val folder = File(activity.filesDir, "session-photos")
                    for (file in folder.listFiles().orEmpty()) {
                        if (file.isFile && file.name.startsWith("p1-source-") && file.path !in kept) file.delete()
                    }
                    null
                }
                "materializePhoto" -> background(result) {
                    materializePhoto(Uri.parse(requireNotNull(call.argument<String>("uri"))),
                        requireNotNull(call.argument<String>("path")), call.argument<Boolean>("locationAccess") == true)
                }
                "pick" -> {
                    val preset = call.argument<Boolean>("preset") == true
                    if (requestDocument(result, Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = if (preset) "*/*" else "image/*"
                        }, requestCode)) {
                        pickingPreset = preset
                    }
                }
                "pickPhotos" -> pickPhotos(
                    result,
                    album = call.argument<Boolean>("album") == true,
                    requestLocation = call.argument<Boolean>("requestLocationMetadata") == true,
                )
                "savePreset" -> {
                    val file = File(requireNotNull(call.argument<String>("path")))
                    val name = call.argument<String>("name") ?: "LumaCraft-P2.lmp"
                    require(name.isNotBlank() && name == File(name).name)
                    if (requestDocument(result, Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = if (name.endsWith(".txt")) "text/plain" else "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, name)
                        }, saveRequestCode)) {
                        presetOutput = file
                    }
                }
                "settingsPath" -> result.success(File(activity.filesDir, "app-settings.json").path)
                "decode" -> background(result) {
                    decode(File(requireNotNull(call.argument<String>("path"))),
                        requireNotNull(call.argument<Int>("maxEdge")))
                }
                "publish" -> background(result) {
                    publish(File(requireNotNull(call.argument<String>("path"))),
                        call.argument<String>("name"), call.argument<String>("format"),
                        call.argument<Boolean>("replace") == true)
                }
                "pss" -> result.success(Debug.getPss())
                "lookupPlace" -> lookupPlace(call.argument<String>("url"), result)
                "map" -> showMap(
                    requireNotNull(call.argument<String>("url")), channel, result,
                    call.argument<Boolean>("select") == true,
                    call.argument<Boolean>("testConnection") == true,
                    call.argument<Boolean>("dark") == true,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun pickPhotos(result: MethodChannel.Result, album: Boolean, requestLocation: Boolean) {
        if (picker != null || pendingLocationPicker != null) {
            result.error("PICK_BUSY", "A document operation is already open.", null)
            return
        }
        val launch: () -> Unit = {
            val files = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "image/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            }
            val primary = if (album) {
                Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                    type = "image/*"
                    val limit = if (Build.VERSION.SDK_INT >= 33) {
                        minOf(photoLimit, MediaStore.getPickImagesMaxLimit())
                    } else photoLimit
                    putExtra(MediaStore.EXTRA_PICK_IMAGES_MAX, limit)
                    if (requestLocation && hasPhotoLocationPermission()) {
                        putExtra("android.provider.extra.REQUEST_LOCATION_METADATA_ACCESS", true)
                    }
                }
            } else files
            if (requestDocument(result, primary, requestCode, files)) {
                pickingPhotos = true
                pickingPhotoLocation = requestLocation && hasPhotoLocationPermission()
            }
        }
        if (requestLocation && !hasPhotoLocationPermission() && !locationPermissionPrompted) {
            locationPermissionPrompted = true
            pendingLocationPicker = launch
            activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_MEDIA_LOCATION), locationPermissionCode)
        } else {
            launch()
        }
    }

    private fun requestDocument(
        result: MethodChannel.Result,
        intent: Intent,
        request: Int,
        fallback: Intent = intent,
    ): Boolean {
        if (picker != null || pendingLocationPicker != null) {
            result.error("PICK_BUSY", "A document operation is already open.", null)
            return false
        }
        picker = result
        return try {
            try {
                activity.startActivityForResult(intent, request)
            } catch (missing: ActivityNotFoundException) {
                if (intent === fallback) throw missing
                activity.startActivityForResult(fallback, request)
            }
            true
        } catch (e: Exception) {
            picker = null
            result.error("PICKER", e.message, null)
            false
        }
    }

    fun onResult(request: Int, status: Int, data: Intent?) {
        if (request != requestCode && request != saveRequestCode) return
        val result = picker ?: return
        picker = null
        val photos = pickingPhotos
        pickingPhotos = false
        val locationAccess = pickingPhotoLocation
        pickingPhotoLocation = false
        val preset = pickingPreset
        pickingPreset = false
        val output = presetOutput
        presetOutput = null
        val uri = data?.data
        if (status != Activity.RESULT_OK || (uri == null && !photos)) {
            result.success(null)
            return
        }
        background(result) {
            val resolver = activity.contentResolver
            if (photos) {
                val uris = linkedSetOf<Uri>()
                if (uri != null) uris.add(uri)
                data?.clipData?.let { clip ->
                    for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
                }
                require(uris.size <= photoLimit) { "一次最多导入 ${photoLimit} 张照片" }
                val copies = mutableListOf<Map<String, Any?>>()
                try {
                    for (item in uris) copies.add(sessionPhoto(item, locationAccess))
                    return@background copies
                } catch (error: Exception) {
                    for (copy in copies) (copy["path"] as? String)?.let { File(it).delete() }
                    throw error
                }
            }
            val selected = checkNotNull(uri)
            if (request == saveRequestCode) {
                try {
                    requireNotNull(resolver.openOutputStream(selected, "w")).use { stream ->
                        checkNotNull(output).inputStream().use { input -> input.copyTo(stream) }
                    }
                } catch (e: Exception) {
                    runCatching { android.provider.DocumentsContract.deleteDocument(resolver, selected) }
                    throw e
                }
                return@background selected.toString()
            }
            copyDocument(selected, preset)
        }
    }

    private fun documentName(uri: Uri): String = activity.contentResolver
        .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
        ?.use { if (it.moveToFirst()) it.getString(0) else null } ?: "photo"

    private fun photoSuffix(name: String): String {
        val extension = name.substringAfterLast('.', "").lowercase()
        return if (extension in setOf("jpg", "jpeg", "heic", "heif", "hif")) ".$extension" else ".image"
    }

    private fun copyDocument(
        uri: Uri, preset: Boolean, folder: File = activity.cacheDir,
        locationAccess: Boolean = false,
    ): Map<String, String?> {
        val resolver = activity.contentResolver
        val name = documentName(uri)
        val file = File.createTempFile("p1-source-", if (preset) ".lmp" else photoSuffix(name), folder)
        try {
            val stream = if (preset) resolver.openInputStream(uri) else openPhoto(uri, locationAccess)
            requireNotNull(stream).use { input ->
                file.outputStream().use { target ->
                    if (!preset) {
                        input.copyTo(target)
                    } else {
                        val buffer = ByteArray(8192)
                        var total = 0
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            total += count
                            require(total <= 64 * 1024 * 1024) { "预设文件超过 64 MB" }
                            target.write(buffer, 0, count)
                        }
                    }
                }
            }
            return mapOf("path" to file.path, "name" to name, "mime" to resolver.getType(uri))
        } catch (e: Exception) {
            file.delete()
            throw e
        }
    }

    private fun decode(file: File, maxEdge: Int): Map<String, Any?> {
        var sourceWidth = 0
        var sourceHeight = 0
        var sourceColor: String? = null
        val bitmap = ImageDecoder.decodeBitmap(ImageDecoder.createSource(file)) { decoder, info, _ ->
            sourceWidth = info.size.width
            sourceHeight = info.size.height
            sourceColor = info.colorSpace?.name
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            decoder.setTargetColorSpace(ColorSpace.get(ColorSpace.Named.SRGB))
            val longest = maxOf(sourceWidth, sourceHeight)
            if (maxEdge > 0 && longest > maxEdge) {
                val scale = maxEdge.toDouble() / longest
                decoder.setTargetSize((sourceWidth * scale).roundToInt().coerceAtLeast(1),
                    (sourceHeight * scale).roundToInt().coerceAtLeast(1))
            }
        }
        var output: File? = null
        try {
            output = File.createTempFile("p1-decoded-", ".png", activity.cacheDir)
            output.outputStream().use { check(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
            return mapOf("path" to output.path, "sourceWidth" to sourceWidth,
                "sourceHeight" to sourceHeight, "width" to bitmap.width, "height" to bitmap.height,
                "sourceColor" to sourceColor, "targetColor" to bitmap.colorSpace?.name)
        } catch (e: Exception) {
            output?.delete()
            throw e
        } finally {
            bitmap.recycle()
        }
    }

    private fun publish(file: File, name: String?, format: String?, replace: Boolean): String {
        val png = format == "png"
        val displayName = name ?: "LumaCraft_P1_${System.currentTimeMillis()}.jpg"
        require(displayName == File(displayName).name)
        val resolver = activity.contentResolver
        val images = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val old = if (replace && name != null) resolver.query(images,
            arrayOf(MediaStore.Images.Media._ID),
            "${MediaStore.Images.Media.DISPLAY_NAME}=? AND ${MediaStore.Images.Media.RELATIVE_PATH}=? AND ${MediaStore.Images.Media.OWNER_PACKAGE_NAME}=? AND ${MediaStore.Images.Media.IS_PENDING}=0",
            arrayOf(name, "Pictures/LumaCraft/", activity.packageName), null)?.use {
                if (it.moveToFirst()) android.content.ContentUris.withAppendedId(images, it.getLong(0)) else null
            } else null
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, if (png) "image/png" else "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, if (name == null) "Pictures/LumaCraft P1" else "Pictures/LumaCraft")
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val uri = checkNotNull(resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values))
        try {
            requireNotNull(resolver.openOutputStream(uri)).use { output ->
                file.inputStream().use { input -> input.copyTo(output) }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            check(resolver.update(uri, values, null, null) == 1)
            // Publish the complete new file before removing an owned export.
            if (old != null) runCatching {
                if (resolver.delete(old, null, null) == 1) {
                    resolver.update(uri, ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
                    }, null, null)
                }
            }
            return uri.toString()
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
    }


    private fun lookupPlace(url: String?, result: MethodChannel.Result) {
        val page = Uri.parse(url.orEmpty())
        if (page.scheme != "http" || page.host != "127.0.0.1" ||
            page.path != "/geocode.html" || finishPlaceLookup != null) {
            result.error("PLACE_LOOKUP", "无法启动本机地图查询", null)
            return
        }
        val view = WebView(activity)
        var finished = false
        val timeout = Runnable {
            if (!finished) finishPlaceLookup?.invoke("GEOCODE_ERR:地图查询超时，请检查网络和高德设置")
        }
        finishPlaceLookup = { title ->
            finished = true
            finishPlaceLookup = null
            view.removeCallbacks(timeout)
            (view.parent as? ViewGroup)?.removeView(view)
            view.destroy()
            result.success(title)
        }
        view.alpha = 0f
        view.importantForAccessibility = android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO
        view.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            allowContentAccess = false
        }
        view.webChromeClient = object : WebChromeClient() {
            override fun onReceivedTitle(view: WebView, title: String) {
                if (title.startsWith("GEOCODE:") || title.startsWith("GEOCODE_ERR:")) {
                    view.post { if (!finished) finishPlaceLookup?.invoke(title.take(1024)) }
                }
            }
        }
        view.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                request.url != page

            override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                if (request.isForMainFrame) {
                    view.post {
                        if (!finished) finishPlaceLookup?.invoke("GEOCODE_ERR:本机地图页面加载失败")
                    }
                }
            }
        }
        activity.addContentView(view, FrameLayout.LayoutParams(1, 1))
        view.postDelayed(timeout, 15000)
        view.loadUrl(page.toString())
    }

    private fun showMap(
        url: String, channel: MethodChannel, result: MethodChannel.Result,
        selectPlace: Boolean, testConnection: Boolean, dark: Boolean,
    ) {
        val page = Uri.parse(url)
        check(page.scheme == "http" && page.host == "127.0.0.1")
        var onTitle: (String) -> Unit = {}
        val view = WebView(activity).apply {
            webChromeClient = object : WebChromeClient() {
                override fun onReceivedTitle(view: WebView, title: String) {
                    onTitle(title)
                }
            }
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = false
            settings.allowContentAccess = false
            webViewClient = object : WebViewClient() {
                override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                    if (!request.isForMainFrame) return
                    val prefix = if (testConnection) "TEST_FAIL:" else "STATE:"
                    onTitle(prefix + "手机本机地图页面加载失败。" +
                        if (error.description.toString().contains("ERR_CLEARTEXT_NOT_PERMITTED"))
                            "安卓拦截了本机连接。" else "请关闭页面后重试。")
                }

                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                    val uri = request.url
                    return uri.scheme != page.scheme || uri.host != page.host || uri.port != page.port
                }
            }
        }
        if (testConnection) {
            val container = android.widget.FrameLayout(activity)
            view.alpha = 0f
            container.addView(view, android.widget.FrameLayout.LayoutParams(1, 1))
            val dialog = AlertDialog.Builder(activity)
                .setTitle("测试高德连接")
                .setMessage("正在加载高德脚本并测试地址解析…")
                .setView(container)
                .setNegativeButton("取消", null)
                .create()
            var outcome: String? = null
            val timeout = Runnable {
                outcome = "TEST_FAIL:地图页面未在规定时间内返回结果，请检查网络后重试。"
                dialog.dismiss()
            }
            onTitle = { title ->
                if (dialog.isShowing && (title.startsWith("TEST_OK:") || title.startsWith("TEST_FAIL:"))) {
                    outcome = title.take(512)
                    dialog.dismiss()
                }
            }
            dialog.setOnDismissListener {
                view.removeCallbacks(timeout)
                container.removeView(view)
                view.destroy()
                result.success(outcome)
            }
            dialog.show()
            view.postDelayed(timeout, 20000)
        } else if (!selectPlace) {
            val dialog = AlertDialog.Builder(activity).setTitle("地图验证")
                .setView(view).setPositiveButton("关闭", null).create()
            onTitle = { title ->
                if (title.startsWith("STATE:") || title.startsWith("PICK:")) {
                    dialog.setTitle(title.substringAfter(':').take(100))
                    channel.invokeMethod("mapTitle", title.take(512))
                }
            }
            dialog.setOnDismissListener {
                view.destroy()
                result.success(null)
            }
            dialog.show()
        } else {
            showPlacePicker(view, dark, result) { handler -> onTitle = handler }
        }
        view.loadUrl(url)
    }

    private fun showPlacePicker(
        view: WebView, dark: Boolean, result: MethodChannel.Result,
        setTitleHandler: ((String) -> Unit) -> Unit,
    ) {
        val theme = if (dark) android.R.style.Theme_Material_NoActionBar
            else android.R.style.Theme_Material_Light_NoActionBar
        val dialog = Dialog(activity, theme)
        val ctx = dialog.context
        fun dp(value: Int) = (value * ctx.resources.displayMetrics.density).roundToInt()
        val background = Color.parseColor(if (dark) "#242320" else "#F3F0E8")
        val foreground = Color.parseColor(if (dark) "#F0ECE3" else "#28241D")
        val muted = Color.parseColor(if (dark) "#C7BDB0" else "#665E51")
        val accent = Color.parseColor(if (dark) "#E3AB57" else "#925D26")
        val onAccent = Color.parseColor(if (dark) "#291D0E" else "#FFFFFF")
        val root = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(background)
        }
        val heading = TextView(ctx).apply {
            text = "选择拍摄地点"
            setTextColor(foreground)
            textSize = 19f
            setPadding(dp(16), dp(12), dp(16), dp(12))
        }
        val footer = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(8), dp(16), dp(8))
        }
        val location = TextView(ctx).apply {
            text = "正在加载地图…"
            setTextColor(muted)
            textSize = 14f
            maxLines = 2
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, 0, 0, dp(6))
        }
        val actions = LinearLayout(ctx).apply { gravity = Gravity.END }
        val cancel = Button(ctx, null, android.R.attr.borderlessButtonStyle).apply {
            text = "取消"
            setTextColor(foreground)
            setOnClickListener { dialog.dismiss() }
        }
        var chosen: String? = null
        var accepted = false
        val confirm = Button(ctx).apply {
            text = "使用此地点"
            setTextColor(onAccent)
            isEnabled = false
            this.background = GradientDrawable().apply {
                cornerRadius = dp(8).toFloat()
                setColor(accent)
            }
            alpha = .45f
            setOnClickListener {
                accepted = true
                dialog.dismiss()
            }
        }
        actions.addView(cancel, LinearLayout.LayoutParams(dp(76), dp(44)))
        actions.addView(confirm, LinearLayout.LayoutParams(dp(132), dp(44)))
        footer.addView(location)
        footer.addView(actions)
        root.addView(heading)
        root.addView(view, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(footer)
        dialog.setContentView(root)
        val window = requireNotNull(dialog.window)
        window.setDecorFitsSystemWindows(false)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        root.setOnApplyWindowInsetsListener { target, insets ->
            val padding = insets.getInsets(WindowInsets.Type.systemBars() or
                WindowInsets.Type.displayCutout() or WindowInsets.Type.ime())
            target.setPadding(padding.left, padding.top, padding.right, padding.bottom)
            insets
        }
        setTitleHandler { title ->
            if (title.startsWith("PICK:") && title.length <= 4096) {
                val coordinates = title.substringAfterLast('|').split(',')
                val lon = coordinates.getOrNull(0)?.trim()?.toDoubleOrNull()
                val lat = coordinates.getOrNull(1)?.trim()?.toDoubleOrNull()
                if (title.count { it == '|' } >= 2 && coordinates.size == 2 &&
                    lon != null && lon in -180.0..180.0 && lat != null && lat in -90.0..90.0) {
                    chosen = title
                    val address = title.substringAfter('|').substringBeforeLast('|')
                    location.text = address.ifBlank { title.substringAfterLast('|') }
                    confirm.isEnabled = true
                    confirm.alpha = 1f
                }
            } else if (title.startsWith("STATE:") && chosen == null) {
                location.text = title.substringAfter(':').take(100)
            }
        }
        dialog.setOnDismissListener {
            root.removeView(view)
            view.destroy()
            result.success(if (accepted) chosen else null)
        }
        dialog.show()
        window.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT)
        root.requestApplyInsets()
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        worker.execute {
            try {
                val value = work()
                activity.runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("ANDROID_P1", e.message, null) }
            } catch (e: OutOfMemoryError) {
                activity.runOnUiThread { result.error("ANDROID_MEMORY", "Not enough memory to decode this photo.", null) }
            }
        }
    }

    companion object {
        private const val photoLimit = 30
        private const val requestCode = 6120
        private const val saveRequestCode = 6121
        private const val locationPermissionCode = 6123
    }
}
