package com.example.lumacraft

import android.content.Intent
import android.content.Context
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var receivedLaunch = false
    private val p1 by lazy { AndroidP1Bridge(this) }
    private var qrCamera: AndroidQrCamera? = null

    override fun provideFlutterEngine(context: Context): FlutterEngine =
        retainedEngine ?: FlutterEngine(context.applicationContext).also { retainedEngine = it }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun onResume() {
        super.onResume()
        val highest = display?.supportedModes?.map { it.refreshRate }
            ?.filter { it <= 120.5f }?.maxOrNull() ?: return
        val attributes = window.attributes
        if (attributes.preferredRefreshRate != highest) {
            attributes.preferredRefreshRate = highest
            window.attributes = attributes
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        p1.receive(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        qrCamera = AndroidQrCamera(this, flutterEngine.renderer).also {
            it.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumacraft/qr_camera"))
        }
        p1.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumacraft/android_p1"))
        if (!receivedLaunch) {
            receivedLaunch = true
            p1.receive(intent)
        }
        if (!flutterEngine.dartExecutor.isExecutingDart) {
            flutterEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        p1.onResult(requestCode, resultCode, data)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        qrCamera?.onPermissionResult(requestCode)
    }

    override fun onDestroy() {
        qrCamera?.dispose()
        p1.cancelPlaceLookup()
        super.onDestroy()
    }

    companion object {
        private var retainedEngine: FlutterEngine? = null
    }
}
