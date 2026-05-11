import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/core/services/privacy_service.dart';

/// PrivacyService 依赖 FlutterSecureStorage 和 HapticFeedback 的平台通道。
/// 测试前需注册 mock handler 以避免 MissingPluginException。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 模拟内存存储，使 setupPassword → lock → unlockWithPassword 流程可用
  final storage = <String, String>{};

  setUp(() {
    storage.clear();

    // Mock FlutterSecureStorage 平台通道
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        if (call.method == 'read') {
          return storage[call.arguments['key'] as String];
        }
        if (call.method == 'write') {
          final args = call.arguments as Map;
          storage[args['key'] as String] = args['value'] as String;
          return null;
        }
        if (call.method == 'delete') {
          storage.remove(call.arguments['key'] as String);
          return null;
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage_android'),
      (call) async => null,
    );

    // Mock HapticFeedback
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') return null;
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage_android'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  group('PrivacyService - encryptText / decryptText', () {
    test('roundtrip: encrypt then decrypt returns original text', () async {
      final service = PrivacyService();
      await service.setupPassword('TestPass123');

      const plainText = '这是一段私密笔记内容 Hello 123 !@#';
      final encrypted = service.encryptText(plainText);

      // 密文应包含前缀
      expect(encrypted.startsWith('AES_V1::'), true);
      // 密文不应等于明文
      expect(encrypted != plainText, true);

      final decrypted = service.decryptText(encrypted);
      expect(decrypted, plainText);

      service.lock();
    });

    test('empty string returns empty string', () async {
      final service = PrivacyService();
      await service.setupPassword('Pass');

      expect(service.encryptText(''), '');
      expect(service.decryptText(''), '');

      service.lock();
    });

    test('already encrypted text passes through', () async {
      final service = PrivacyService();
      await service.setupPassword('Pass');

      const already = 'AES_V1::somebase64:otherbase64';
      expect(service.encryptText(already), already);

      service.lock();
    });

    test('non-encrypted text passes through in decryptText', () async {
      final service = PrivacyService();
      await service.setupPassword('Pass');

      const plain = 'not encrypted';
      expect(service.decryptText(plain), plain);

      service.lock();
    });

    test('encryptText throws when locked', () {
      final service = PrivacyService();
      // service is locked by default (or after lock())
      service.lock();
      expect(
        () => service.encryptText('secret'),
        throwsA(isA<Exception>()),
      );
    });

    test('decryptText returns placeholder when locked', () {
      final service = PrivacyService();
      service.lock();
      // 需要一个带前缀的密文来触发 locked 分支
      const fake = 'AES_V1::iv:cipher';
      final result = service.decryptText(fake);
      expect(result.contains('私密内容'), true);
    });

    test('corrupted ciphertext returns error message', () async {
      final service = PrivacyService();
      await service.setupPassword('Pass');

      // 无效的 base64 数据
      const corrupted = 'AES_V1::invalid!!!:also!!!';
      final result = service.decryptText(corrupted);
      expect(result.contains('解密失败'), true);

      service.lock();
    });

    test('different plaintexts produce different ciphertexts', () async {
      final service = PrivacyService();
      await service.setupPassword('Pass');

      final e1 = service.encryptText('message A');
      final e2 = service.encryptText('message B');
      expect(e1 != e2, true);

      service.lock();
    });

    test('same plaintext produces different ciphertexts (random IV)', () async {
      final service = PrivacyService();
      await service.setupPassword('Pass');

      final e1 = service.encryptText('same message');
      final e2 = service.encryptText('same message');
      // GCM uses random IV, so ciphertexts should differ
      expect(e1 != e2, true);

      // But both should decrypt to the same plaintext
      expect(service.decryptText(e1), 'same message');
      expect(service.decryptText(e2), 'same message');

      service.lock();
    });
  });

  group('PrivacyService - setupPassword / unlockWithPassword', () {
    test('setup then unlock with correct password succeeds', () async {
      final service = PrivacyService();
      await service.setupPassword('MySecurePass!');

      // lock 后用正确密码解锁
      service.lock();
      expect(service.isUnlocked, false);

      final result = await service.unlockWithPassword('MySecurePass!');
      expect(result, true);
      expect(service.isUnlocked, true);

      service.lock();
    });

    test('unlock with wrong password fails', () async {
      final service = PrivacyService();
      await service.setupPassword('CorrectPass');

      service.lock();
      final result = await service.unlockWithPassword('WrongPass');
      expect(result, false);
      expect(service.isUnlocked, false);

      service.lock();
    });

    test('unlock when no password set returns false', () async {
      final service = PrivacyService();
      service.lock();
      // No setupPassword called → storage returns null → should return false
      final result = await service.unlockWithPassword('anything');
      expect(result, false);
    });

    test('password change then unlock with new password', () async {
      final service = PrivacyService();
      await service.setupPassword('OldPass');

      // changePassword 内部调用 unlockWithPassword + setupPassword
      await service.changePassword('OldPass', 'NewPass');

      service.lock();
      final result = await service.unlockWithPassword('NewPass');
      expect(result, true);

      // 旧密码应不再有效
      service.lock();
      final oldResult = await service.unlockWithPassword('OldPass');
      expect(oldResult, false);

      service.lock();
    });
  });

  group('PrivacyService - lock / isUnlocked', () {
    test('isUnlocked reflects state', () async {
      final service = PrivacyService();
      service.lock();
      expect(service.isUnlocked, false);

      await service.setupPassword('Pass');
      expect(service.isUnlocked, true);

      service.lock();
      expect(service.isUnlocked, false);

      service.lock();
    });
  });

  group('PrivacyService - file bytes encrypt / decrypt', () {
    test('roundtrip: encrypt then decrypt file bytes', () async {
      final service = PrivacyService();
      await service.setupPassword('FilePass');

      final original = Uint8List.fromList([1, 2, 3, 4, 5, 255, 0, 128]);
      final encrypted = service.encryptFileBytes(original);

      // 加密后应比原文长（12 字节 IV + GCM 认证标签）
      expect(encrypted.length, greaterThan(original.length));

      final decrypted = service.decryptFileBytes(encrypted);
      expect(decrypted, original);

      service.lock();
    });

    test('encryptFileBytes throws when locked', () {
      final service = PrivacyService();
      service.lock();
      expect(
        () => service.encryptFileBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()),
      );
    });

    test('decryptFileBytes throws when locked', () {
      final service = PrivacyService();
      service.lock();
      expect(
        () => service.decryptFileBytes(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<Exception>()),
      );
    });

    test('large file roundtrip', () async {
      final service = PrivacyService();
      await service.setupPassword('BigFilePass');

      // 10KB 模拟数据
      final original = Uint8List(10240);
      for (var i = 0; i < original.length; i++) {
        original[i] = i % 256;
      }

      final encrypted = service.encryptFileBytes(original);
      final decrypted = service.decryptFileBytes(encrypted);
      expect(decrypted, original);

      service.lock();
    });

    test('empty file roundtrip', () async {
      final service = PrivacyService();
      await service.setupPassword('EmptyPass');

      final original = Uint8List(0);
      final encrypted = service.encryptFileBytes(original);
      final decrypted = service.decryptFileBytes(encrypted);
      expect(decrypted, original);

      service.lock();
    });
  });
}
