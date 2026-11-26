import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fire_safety_job_prep/services/session_token_store.dart';

PlatformException badCipher() => PlatformException(
    code: 'Exception encountered', message: 'read',
    details: 'javax.crypto.BadPaddingException: OPENSSL_internal:BAD_DECRYPT');

void main() {
  test('corrupt token is removed once, then fresh login works', () async {
    String? token = 'unreadable';
    var deletes = 0;
    final store = SessionTokenStore(
      read: () async { if (token == 'unreadable') throw badCipher(); return token; },
      write: (value) async { token = value; },
      delete: () async { deletes++; token = null; },
      recoverAndroidCipher: true,
    );
    expect(await Future.wait([store.read(), store.read()]), [null, null]);
    expect(deletes, 1);
    await store.write('new');
    expect(await store.read(), 'new');
    expect(await store.deleteIfMatches('old'), isFalse);
    expect(await store.read(), 'new');
  });

  test('unexpected platform error does not erase token or expose native details', () async {
    var deletes = 0;
    final store = SessionTokenStore(
      read: () async => throw PlatformException(code: 'unavailable', details: 'native trace'),
      write: (_) async {},
      delete: () async { deletes++; },
      recoverAndroidCipher: true,
    );
    await expectLater(store.read(), throwsA(isA<SessionStorageException>()));
    expect(deletes, 0);
  });

  test('failed recovery is safe and never reports successful logout', () async {
    final store = SessionTokenStore(
      read: () async => throw badCipher(),
      write: (_) async {},
      delete: () async => throw badCipher(),
      recoverAndroidCipher: true,
    );
    await expectLater(store.read(), throwsA(isA<SessionStorageException>()));
    await expectLater(store.clear(), throwsA(isA<SessionStorageException>()));
  });

  test('non-Android error does not reset token', () async {
    var deletes = 0;
    final store = SessionTokenStore(
      read: () async => throw badCipher(),
      write: (_) async {},
      delete: () async { deletes++; },
      recoverAndroidCipher: false,
    );
    await expectLater(store.read(), throwsA(isA<SessionStorageException>()));
    expect(deletes, 0);
  });

  test('write retries once after recognized cipher error', () async {
    var writes = 0;
    var deletes = 0;
    final store = SessionTokenStore(
      read: () async => null,
      write: (_) async { if (++writes == 1) throw badCipher(); },
      delete: () async { deletes++; },
      recoverAndroidCipher: true,
    );
    await store.write('fresh');
    expect(writes, 2);
    expect(deletes, 1);
  });

  test('a newer login cannot be erased by an earlier recovery', () async {
    final releaseRead = Completer<void>();
    String? token = 'broken';
    final store = SessionTokenStore(
      read: () async {
        if (token == 'broken') { await releaseRead.future; throw badCipher(); }
        return token;
      },
      write: (value) async { token = value; },
      delete: () async { token = null; },
      recoverAndroidCipher: true,
    );
    final pending = store.read();
    final login = store.write('new');
    releaseRead.complete();
    expect(await pending, isNull);
    await login;
    expect(await store.read(), 'new');
  });
}
