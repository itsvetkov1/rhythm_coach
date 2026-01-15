package com.rhythmcoach.ai_rhythm_coach

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * Native Android AudioRecord implementation with full control over AGC settings.
 *
 * This bypasses flutter_sound to directly use Android's AudioRecord API,
 * allowing us to:
 * - Disable AGC (Automatic Gain Control)
 * - Use VOICE_RECOGNITION audio source (minimal processing)
 * - Get raw PCM data without amplification
 */
class NativeAudioRecorder {
    companion object {
        private const val TAG = "NativeAudioRecorder"

        // Audio configuration
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        // Buffer size (larger buffer = more stable, but higher latency)
        private const val BUFFER_SIZE_MULTIPLIER = 4
    }

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null
    private var outputFile: File? = null
    private var outputStream: FileOutputStream? = null

    /**
     * Initialize the audio recorder with specified audio source.
     *
     * @param audioSource Android MediaRecorder.AudioSource constant
     *                    - VOICE_RECOGNITION (6): Minimal AGC, designed for speech recognition
     *                    - UNPROCESSED (9): Raw audio, no processing (API 29+, may not be supported)
     *                    - MIC (1): Default microphone with standard processing
     */
    fun initialize(audioSource: Int = MediaRecorder.AudioSource.VOICE_RECOGNITION): Boolean {
        try {
            val minBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT
            )

            if (minBufferSize == AudioRecord.ERROR || minBufferSize == AudioRecord.ERROR_BAD_VALUE) {
                Log.e(TAG, "Failed to get minimum buffer size")
                return false
            }

            val bufferSize = minBufferSize * BUFFER_SIZE_MULTIPLIER

            Log.i(TAG, "Initializing AudioRecord with:")
            Log.i(TAG, "  Audio Source: $audioSource (${getAudioSourceName(audioSource)})")
            Log.i(TAG, "  Sample Rate: $SAMPLE_RATE Hz")
            Log.i(TAG, "  Channel: MONO")
            Log.i(TAG, "  Format: PCM_16BIT")
            Log.i(TAG, "  Buffer Size: $bufferSize bytes")

            audioRecord = AudioRecord(
                audioSource,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize")
                audioRecord = null
                return false
            }

            Log.i(TAG, "AudioRecord initialized successfully")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Error initializing AudioRecord: ${e.message}", e)
            audioRecord = null
            return false
        }
    }

    /**
     * Start recording to the specified file path.
     *
     * @param filePath Absolute path to output WAV file
     */
    fun startRecording(filePath: String): Boolean {
        if (audioRecord == null) {
            Log.e(TAG, "AudioRecord not initialized")
            return false
        }

        if (isRecording) {
            Log.w(TAG, "Already recording")
            return false
        }

        try {
            outputFile = File(filePath)
            outputStream = FileOutputStream(outputFile)

            // Write WAV header (will be updated with correct size later)
            writeWavHeader(outputStream!!, 0)

            audioRecord?.startRecording()
            isRecording = true

            Log.i(TAG, "Recording started to: $filePath")

            // Start recording thread
            recordingThread = thread(start = true) {
                recordAudioData()
            }

            return true

        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}", e)
            stopRecording()
            return false
        }
    }

    /**
     * Stop recording and finalize the WAV file.
     *
     * @return Path to the recorded file, or null if failed
     */
    fun stopRecording(): String? {
        if (!isRecording) {
            Log.w(TAG, "Not currently recording")
            return null
        }

        isRecording = false

        try {
            // Wait for recording thread to finish
            recordingThread?.join(2000)
            recordingThread = null

            audioRecord?.stop()

            // Finalize WAV file
            outputStream?.let { stream ->
                val fileSize = outputFile?.length() ?: 0
                stream.close()

                // Update WAV header with correct file size
                if (fileSize > 44) {
                    updateWavHeader(outputFile!!, fileSize - 44)
                    Log.i(TAG, "Recording stopped. File size: $fileSize bytes")
                    return outputFile?.absolutePath
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording: ${e.message}", e)
        } finally {
            outputStream = null
            outputFile = null
        }

        return null
    }

    /**
     * Release all resources.
     */
    fun release() {
        stopRecording()

        audioRecord?.release()
        audioRecord = null

        Log.i(TAG, "AudioRecord released")
    }

    /**
     * Main recording loop - reads audio data and writes to file.
     */
    private fun recordAudioData() {
        val bufferSize = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_FORMAT
        ) * BUFFER_SIZE_MULTIPLIER

        val buffer = ByteArray(bufferSize)
        var totalBytesRead = 0

        Log.i(TAG, "Recording thread started")

        while (isRecording) {
            val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0

            if (bytesRead > 0) {
                try {
                    outputStream?.write(buffer, 0, bytesRead)
                    totalBytesRead += bytesRead
                } catch (e: Exception) {
                    Log.e(TAG, "Error writing audio data: ${e.message}")
                    break
                }
            } else if (bytesRead < 0) {
                Log.e(TAG, "Error reading audio data: $bytesRead")
                break
            }
        }

        Log.i(TAG, "Recording thread finished. Total bytes: $totalBytesRead")
    }

    /**
     * Write WAV file header.
     */
    private fun writeWavHeader(output: FileOutputStream, dataSize: Long) {
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)

        // RIFF header
        header.put("RIFF".toByteArray())
        header.putInt((36 + dataSize).toInt()) // File size - 8
        header.put("WAVE".toByteArray())

        // fmt chunk
        header.put("fmt ".toByteArray())
        header.putInt(16) // fmt chunk size
        header.putShort(1) // Audio format (1 = PCM)
        header.putShort(1) // Number of channels
        header.putInt(SAMPLE_RATE) // Sample rate
        header.putInt(SAMPLE_RATE * 2) // Byte rate (SampleRate * NumChannels * BitsPerSample/8)
        header.putShort(2) // Block align (NumChannels * BitsPerSample/8)
        header.putShort(16) // Bits per sample

        // data chunk
        header.put("data".toByteArray())
        header.putInt(dataSize.toInt()) // Data size

        output.write(header.array())
    }

    /**
     * Update WAV header with actual data size after recording.
     */
    private fun updateWavHeader(file: File, dataSize: Long) {
        val raf = java.io.RandomAccessFile(file, "rw")

        // Update file size (at byte 4)
        raf.seek(4)
        raf.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
            .putInt((36 + dataSize).toInt()).array())

        // Update data size (at byte 40)
        raf.seek(40)
        raf.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN)
            .putInt(dataSize.toInt()).array())

        raf.close()
    }

    /**
     * Get human-readable name for audio source constant.
     */
    private fun getAudioSourceName(audioSource: Int): String {
        return when (audioSource) {
            MediaRecorder.AudioSource.DEFAULT -> "DEFAULT"
            MediaRecorder.AudioSource.MIC -> "MIC"
            MediaRecorder.AudioSource.VOICE_UPLINK -> "VOICE_UPLINK"
            MediaRecorder.AudioSource.VOICE_DOWNLINK -> "VOICE_DOWNLINK"
            MediaRecorder.AudioSource.VOICE_CALL -> "VOICE_CALL"
            MediaRecorder.AudioSource.CAMCORDER -> "CAMCORDER"
            MediaRecorder.AudioSource.VOICE_RECOGNITION -> "VOICE_RECOGNITION"
            MediaRecorder.AudioSource.VOICE_COMMUNICATION -> "VOICE_COMMUNICATION"
            9 -> "UNPROCESSED" // MediaRecorder.AudioSource.UNPROCESSED (API 29+)
            else -> "UNKNOWN($audioSource)"
        }
    }
}
