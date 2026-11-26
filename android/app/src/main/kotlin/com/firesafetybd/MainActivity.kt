package com.firesafetybd

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val MIC_PERMISSION_REQUEST = 7314
        private const val IDENTITY_CHANNEL = "com.firesafetybd/app_identity"
        private const val VOICE_CHANNEL = "com.firesafetybd/offline_voice"
        private const val VOICE_EVENTS_CHANNEL = "com.firesafetybd/offline_voice_events"
    }

    private var voiceEvents: EventChannel.EventSink? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingMicPermission: MethodChannel.Result? = null
    private var textToSpeech: TextToSpeech? = null
    private var ttsReady = false
    private var pendingSpeak: PendingSpeak? = null

    private data class PendingSpeak(
        val text: String,
        val locale: String,
        val result: MethodChannel.Result
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            IDENTITY_CHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "getSigningIdentity") {
                try {
                    result.success(
                        mapOf(
                            "packageName" to packageName,
                            "sha1" to installedCertificateSha1()
                        )
                    )
                } catch (error: Exception) {
                    result.error(
                        "SIGNING_INFO_UNAVAILABLE",
                        "Could not inspect installed APK signing certificate.",
                        null
                    )
                }
            } else {
                result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_EVENTS_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                voiceEvents = events
            }

            override fun onCancel(arguments: Any?) {
                voiceEvents = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestMicrophonePermission" -> requestMicrophonePermission(result)
                "isOfflineSpeechAvailable" -> {
                    result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                            SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
                    )
                }
                "startListening" -> {
                    val locale = call.argument<String>("locale") ?: "bn-BD"
                    startOfflineListening(locale, result)
                }
                "stopListening" -> {
                    speechRecognizer?.stopListening()
                    result.success(true)
                }
                "cancelListening" -> {
                    speechRecognizer?.cancel()
                    result.success(true)
                }
                "speak" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val locale = call.argument<String>("locale") ?: "bn-BD"
                    speakOffline(text, locale, result)
                }
                "stopSpeaking" -> {
                    textToSpeech?.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestMicrophonePermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingMicPermission != null) {
            result.error("PERMISSION_REQUEST_PENDING", "Microphone permission request is already open.", null)
            return
        }
        pendingMicPermission = result
        requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO),
            MIC_PERMISSION_REQUEST
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MIC_PERMISSION_REQUEST) {
            val result = pendingMicPermission
            pendingMicPermission = null
            result?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        }
    }

    private fun startOfflineListening(localeTag: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            result.error(
                "OFFLINE_SPEECH_UNAVAILABLE",
                "On-device speech recognition requires Android 12 or later.",
                null
            )
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            result.error("MIC_PERMISSION_REQUIRED", "Microphone permission is required.", null)
            return
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
            result.error(
                "OFFLINE_SPEECH_UNAVAILABLE",
                "No on-device speech recognition service is installed.",
                null
            )
            return
        }

        try {
            speechRecognizer?.destroy()
            val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            speechRecognizer = recognizer
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {
                    emitVoiceEvent("listening")
                }

                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}

                override fun onError(error: Int) {
                    emitVoiceEvent("error", mapOf("code" to error.toString()))
                }

                override fun onResults(results: Bundle?) {
                    val words = results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        .orEmpty()
                    emitVoiceEvent("result", mapOf("text" to words))
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val words = partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        .orEmpty()
                    if (words.isNotEmpty()) {
                        emitVoiceEvent("partial", mapOf("text" to words))
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, localeTag)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, localeTag)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(
                    RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                    2500L
                )
            }
            recognizer.startListening(intent)
            result.success(true)
        } catch (error: Exception) {
            speechRecognizer?.destroy()
            speechRecognizer = null
            result.error(
                "OFFLINE_SPEECH_UNAVAILABLE",
                "Could not start on-device speech recognition.",
                null
            )
        }
    }

    private fun speakOffline(
        text: String,
        localeTag: String,
        result: MethodChannel.Result
    ) {
        if (text.isBlank()) {
            result.error("EMPTY_SPEECH", "There is no question to read.", null)
            return
        }
        if (ttsReady && textToSpeech != null) {
            queueOfflineSpeech(text, localeTag, result)
            return
        }

        pendingSpeak?.result?.error(
            "TTS_REQUEST_REPLACED",
            "A newer read-aloud request replaced this one.",
            null
        )
        pendingSpeak = PendingSpeak(text, localeTag, result)

        if (textToSpeech == null) {
            textToSpeech = TextToSpeech(this) { status ->
                runOnUiThread {
                    val pending = pendingSpeak
                    if (status != TextToSpeech.SUCCESS || pending == null) {
                        pendingSpeak = null
                        pending?.result?.error(
                            "OFFLINE_TTS_UNAVAILABLE",
                            "The device text-to-speech engine is unavailable.",
                            null
                        )
                        return@runOnUiThread
                    }
                    ttsReady = true
                    textToSpeech?.setOnUtteranceProgressListener(
                        object : UtteranceProgressListener() {
                            override fun onStart(utteranceId: String?) {
                                emitVoiceEvent("speech_started")
                            }

                            override fun onDone(utteranceId: String?) {
                                emitVoiceEvent("speech_done")
                            }

                            override fun onError(utteranceId: String?) {
                                emitVoiceEvent("speech_error")
                            }
                        }
                    )
                    pendingSpeak = null
                    queueOfflineSpeech(pending.text, pending.locale, pending.result)
                }
            }
        }
    }

    private fun queueOfflineSpeech(
        text: String,
        localeTag: String,
        result: MethodChannel.Result
    ) {
        val engine = textToSpeech
        if (engine == null || !ttsReady) {
            result.error("OFFLINE_TTS_UNAVAILABLE", "Text-to-speech is not ready.", null)
            return
        }

        val requestedLocale = Locale.forLanguageTag(localeTag)
        val localVoice = engine.voices
            ?.filter {
                !it.isNetworkConnectionRequired &&
                    it.locale.language.equals(requestedLocale.language, ignoreCase = true)
            }
            ?.firstOrNull {
                it.locale.country.equals(requestedLocale.country, ignoreCase = true)
            }
            ?: engine.voices
                ?.firstOrNull {
                    !it.isNetworkConnectionRequired &&
                        it.locale.language.equals(requestedLocale.language, ignoreCase = true)
                }

        if (localVoice == null) {
            result.error(
                "OFFLINE_TTS_UNAVAILABLE",
                "No installed offline voice is available for $localeTag.",
                null
            )
            return
        }

        try {
            engine.voice = localVoice
            val status = engine.speak(
                text,
                TextToSpeech.QUEUE_FLUSH,
                Bundle(),
                UUID.randomUUID().toString()
            )
            if (status == TextToSpeech.ERROR) {
                result.error("OFFLINE_TTS_UNAVAILABLE", "Could not read the question.", null)
            } else {
                result.success(true)
            }
        } catch (error: Exception) {
            result.error("OFFLINE_TTS_UNAVAILABLE", "Could not read the question.", null)
        }
    }

    private fun emitVoiceEvent(type: String, values: Map<String, Any?> = emptyMap()) {
        val payload = mutableMapOf<String, Any?>("type" to type)
        payload.putAll(values)
        runOnUiThread { voiceEvents?.success(payload) }
    }

    @Suppress("DEPRECATION")
    private fun installedCertificateSha1(): String {
        val certificates = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(
                packageName, PackageManager.GET_SIGNING_CERTIFICATES
            ).signingInfo ?: error("Missing Android signing information")
            info.apkContentsSigners
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        }
        val signer = certificates?.firstOrNull() ?: error("No APK signing certificate found")
        val digest = MessageDigest.getInstance("SHA-1").digest(signer.toByteArray())
        return digest.joinToString(":") { byte -> "%02X".format(byte.toInt() and 0xFF) }
    }

    override fun onDestroy() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        voiceEvents = null
        super.onDestroy()
    }
}
