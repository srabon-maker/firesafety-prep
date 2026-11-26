import 'dart:async';
import 'package:flutter/services.dart';

/// Uses Android's on-device speech recognizer and locally installed TTS voices.
/// No audio or transcript is sent to Fire Safety BD servers.
class OfflineVoiceService {
  OfflineVoiceService._();

  static const MethodChannel _methods =
      MethodChannel('com.firesafetybd/offline_voice');
  static const EventChannel _events =
      EventChannel('com.firesafetybd/offline_voice_events');

  static Stream<Map<String, dynamic>> get events =>
      _events.receiveBroadcastStream().where((event) => event is Map).map(
            (event) => Map<String, dynamic>.from(event as Map),
          );

  static Future<bool> requestMicrophonePermission() async =>
      await _methods.invokeMethod<bool>('requestMicrophonePermission') ?? false;

  static Future<bool> isOfflineSpeechAvailable() async =>
      await _methods.invokeMethod<bool>('isOfflineSpeechAvailable') ?? false;

  static Future<void> startListening(String localeTag) =>
      _methods.invokeMethod<void>('startListening', {'locale': localeTag});

  static Future<void> stopListening() =>
      _methods.invokeMethod<void>('stopListening');

  static Future<void> cancelListening() =>
      _methods.invokeMethod<void>('cancelListening');

  static Future<void> speak(String text, String localeTag) =>
      _methods.invokeMethod<void>(
        'speak',
        {'text': text, 'locale': localeTag},
      );

  static Future<void> stopSpeaking() =>
      _methods.invokeMethod<void>('stopSpeaking');
}
