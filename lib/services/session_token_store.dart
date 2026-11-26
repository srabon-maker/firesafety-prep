import 'dart:async';
import 'package:flutter/services.dart';

/// Serialized encrypted session operations. Never stores plaintext tokens.
/// Only a known Android decryption failure may discard the unreadable token.
class SessionTokenStore {
  SessionTokenStore({
    required Future<String?> Function() read,
    required Future<void> Function(String) write,
    required Future<void> Function() delete,
    required bool recoverAndroidCipher,
  }) : _read = read, _write = write, _delete = delete,
       _recoverAndroidCipher = recoverAndroidCipher;

  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final Future<void> Function() _delete;
  final bool _recoverAndroidCipher;
  Future<void> _tail = Future<void>.value();

  static const _storageError = SessionStorageException();

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  bool _isCipherFailure(PlatformException error) {
    if (!_recoverAndroidCipher) return false;
    final description = '${error.code} ${error.message} ${error.details}'.toLowerCase();
    return description.contains('bad_decrypt') ||
        description.contains('badpaddingexception') ||
        description.contains('aeadbadtagexception') ||
        description.contains('failed to unwrap key') ||
        description.contains('keypermanentlyinvalidatedexception');
  }

  Future<void> _deleteSafely() async {
    try {
      await _delete();
    } on PlatformException {
      throw _storageError;
    }
  }

  Future<String?> _readSafely() async {
    try {
      return await _read();
    } on PlatformException catch (error) {
      if (!_isCipherFailure(error)) throw _storageError;
      // The existing token cannot be decrypted. Remove only this key and
      // require normal login; do not delete other app data or bypass auth.
      await _deleteSafely();
      return null;
    }
  }

  Future<String?> read() => _serial(_readSafely);

  Future<void> write(String token) => _serial(() async {
    try {
      await _write(token);
    } on PlatformException catch (error) {
      if (!_isCipherFailure(error)) throw _storageError;
      await _deleteSafely();
      try {
        await _write(token);
      } on PlatformException {
        throw _storageError;
      }
    }
  });

  Future<void> clear() => _serial(_deleteSafely);

  Future<bool> deleteIfMatches(String expected) => _serial(() async {
    if (await _readSafely() != expected) return false;
    await _deleteSafely();
    return true;
  });
}

class SessionStorageException implements Exception {
  const SessionStorageException();
  @override
  String toString() => 'ফোনে লগইন তথ্য পড়া বা সংরক্ষণ করা যাচ্ছে না। অ্যাপ পুনরায় চালু করে চেষ্টা করুন। (SESSION_STORAGE)';
}
