package com.rhythmcoach.ai_rhythm_coach

import android.media.MediaRecorder
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rhythmcoach.ai_rhythm_coach/native_audio"
    private var nativeRecorder: NativeAudioRecorder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val audioSource = call.argument<Int>("audioSource") ?: MediaRecorder.AudioSource.VOICE_RECOGNITION
                    val success = initializeRecorder(audioSource)
                    result.success(success)
                }
                "startRecording" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "filePath is required", null)
                    } else {
                        val success = nativeRecorder?.startRecording(filePath) ?: false
                        result.success(success)
                    }
                }
                "stopRecording" -> {
                    val path = nativeRecorder?.stopRecording()
                    result.success(path)
                }
                "release" -> {
                    nativeRecorder?.release()
                    nativeRecorder = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        Log.i("MainActivity", "Native audio platform channel registered")
    }

    private fun initializeRecorder(audioSource: Int): Boolean {
        // Release existing recorder if any
        nativeRecorder?.release()

        // Create new recorder
        nativeRecorder = NativeAudioRecorder()
        return nativeRecorder?.initialize(audioSource) ?: false
    }

    override fun onDestroy() {
        nativeRecorder?.release()
        super.onDestroy()
    }
}
