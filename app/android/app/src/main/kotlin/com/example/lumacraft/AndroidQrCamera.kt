package com.example.lumacraft

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.Surface
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.abs

internal class AndroidQrCamera(
    private val activity: Activity,
    private val textures: TextureRegistry,
) {
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var session: CameraCaptureSession? = null
    private var camera: CameraDevice? = null
    private var reader: ImageReader? = null
    private var worker: HandlerThread? = null
    private var texture: TextureRegistry.SurfaceProducer? = null
    private var previewWidth = 0
    private var previewHeight = 0
    private var sensorOrientation = 0
    private var frontFacing = false
    private var pending: MethodChannel.Result? = null
    private var cameraError: String? = null
    @Volatile private var generation = 0
    private val requestedFrame = AtomicBoolean(false)
    private val latest = AtomicReference<Map<String, Any>?>(null)

    fun attach(channel: MethodChannel) {
        this.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> start(result)
                "stop" -> {
                    close()
                    result.success(null)
                }
                "previewGeometry" -> result.success(previewGeometry())
                "frame" -> {
                    if (cameraError != null) {
                        result.error("camera_disconnected", cameraError, null)
                    } else {
                        val frame = latest.getAndSet(null)
                        requestedFrame.set(true)
                        result.success(frame)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun start(result: MethodChannel.Result) {
        close()
        pending = result
        cameraError = null
        if (activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION)
        } else {
            open()
        }
    }

    fun onPermissionResult(requestCode: Int) {
        if (requestCode != CAMERA_PERMISSION || pending == null) return
        if (activity.checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            open()
        } else {
            fail("相机权限未开启，可在系统设置中允许后重试。")
        }
    }

    private fun previewGeometry(): Map<String, Any>? {
        val producer = texture ?: return null
        val displayDegrees = (activity.display?.rotation ?: Surface.ROTATION_0) * 90
        val sign = if (frontFacing) 1 else -1
        val turns = (sensorOrientation - displayDegrees * sign + 360) % 360 / 90
        val handlesRotation = producer.handlesCropAndRotation()
        val swapDimensions = handlesRotation && turns % 2 == 1
        return mapOf(
            "texture" to producer.id(),
            "width" to if (swapDimensions) previewHeight else previewWidth,
            "height" to if (swapDimensions) previewWidth else previewHeight,
            "turns" to if (handlesRotation) 0 else turns,
        )
    }

    @SuppressLint("MissingPermission")
    private fun open() {
        val current = generation
        try {
            val manager = activity.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameras = manager.cameraIdList.map { it to manager.getCameraCharacteristics(it) }
            val (id, info) = cameras.firstOrNull {
                it.second.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: cameras.firstOrNull() ?: return fail("设备上没有可用的相机。")
            val config = info.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?: return fail("相机不支持二维码预览。")
            val previewSizes = config.getOutputSizes(SurfaceTexture::class.java).toSet()
            val size = config.getOutputSizes(ImageFormat.YUV_420_888)
                .filter { it in previewSizes && it.width <= 1920 && it.height <= 1080 }
                .minByOrNull { abs(it.width - 1280) + abs(it.height - 720) }
                ?: return fail("相机不支持二维码预览尺寸。")
            val width = size.width
            val height = size.height
            previewWidth = width
            previewHeight = height
            sensorOrientation = info.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
            frontFacing = info.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
            val producer = textures.createSurfaceProducer().also { texture = it }
            producer.setSize(width, height)
            val preview = producer.surface
            val supportsRotateAndCropNone = Build.VERSION.SDK_INT >= 31 &&
                info.get(CameraCharacteristics.SCALER_AVAILABLE_ROTATE_AND_CROP_MODES)
                    ?.contains(CaptureRequest.SCALER_ROTATE_AND_CROP_NONE) == true
            val thread = HandlerThread("LumaCraft QR camera").also {
                it.start()
                worker = it
            }
            val frames = ImageReader.newInstance(width, height, ImageFormat.YUV_420_888, 3)
                .also { reader = it }
            frames.setOnImageAvailableListener({ source ->
                try {
                    source.acquireLatestImage()?.use { image ->
                        if (current != generation || !requestedFrame.getAndSet(false)) return@use
                        val plane = image.planes[0]
                        val pixels = ByteArray(width * height)
                        val buffer = plane.buffer
                        val start = buffer.position()
                        for (row in 0 until height) {
                            buffer.position(start + row * plane.rowStride)
                            buffer.get(pixels, row * width, width)
                        }
                        if (current == generation) {
                            latest.set(mapOf("bytes" to pixels, "width" to width, "height" to height))
                        }
                    }
                } catch (_: IllegalStateException) {
                    // The reader may have been closed while its callback was queued.
                }
            }, Handler(thread.looper))
            val focusModes = info.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES) ?: intArrayOf()
            manager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    if (current != generation) {
                        device.close()
                        return
                    }
                    camera = device
                    configure(device, preview, frames.surface, current, focusModes, supportsRotateAndCropNone)
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close()
                    if (current == generation) fail("相机连接已中断。")
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close()
                    if (current == generation) fail("无法打开相机，请检查相机是否正被占用。")
                }
            }, main)
        } catch (_: Exception) {
            fail("无法启动相机，请检查相机权限或稍后重试。")
        }
    }

    @Suppress("DEPRECATION")
    private fun configure(device: CameraDevice, preview: Surface, frames: Surface,
        current: Int, focusModes: IntArray, supportsRotateAndCropNone: Boolean) {
        try {
            val request = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                addTarget(preview)
                addTarget(frames)
                if (supportsRotateAndCropNone) {
                    set(CaptureRequest.SCALER_ROTATE_AND_CROP, CaptureRequest.SCALER_ROTATE_AND_CROP_NONE)
                }
                if (CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE in focusModes) {
                    set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                }
            }
            device.createCaptureSession(listOf(preview, frames), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(created: CameraCaptureSession) {
                    if (current != generation) {
                        created.close()
                        return
                    }
                    session = created
                    try {
                        created.setRepeatingRequest(request.build(), null, main)
                        val result = pending
                        pending = null
                        result?.success(previewGeometry())
                    } catch (_: Exception) {
                        fail("相机预览未能启动。")
                    }
                }

                override fun onConfigureFailed(created: CameraCaptureSession) {
                    created.close()
                    if (current == generation) fail("相机预览未能启动。")
                }
            }, main)
        } catch (_: Exception) {
            fail("相机预览未能启动。")
        }
    }

    private fun fail(message: String) {
        val result = pending
        pending = null
        close()
        cameraError = message
        result?.error("camera", message, null)
    }

    private fun close() {
        generation++
        pending?.success(null)
        pending = null
        requestedFrame.set(false)
        latest.set(null)
        session?.close()
        session = null
        camera?.close()
        camera = null
        reader?.setOnImageAvailableListener(null, null)
        val closingReader = reader
        val closingWorker = worker
        if (closingWorker != null) {
            Handler(closingWorker.looper).post { closingReader?.close() }
            closingWorker.quitSafely()
        } else {
            closingReader?.close()
        }
        reader = null
        worker = null
        texture?.release()
        texture = null
    }

    fun dispose() {
        close()
        channel?.setMethodCallHandler(null)
        channel = null
    }

    companion object {
        private const val CAMERA_PERMISSION = 713
    }
}
