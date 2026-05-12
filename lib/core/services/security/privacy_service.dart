import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../constants/storage_constants.dart';



/// 隐私服务 - 商业级安全实现
///
/// 安全架构：
/// 1. 主密钥 (Master Key): 从用户密码派生，用于加密笔记内容
/// 2. 密钥派生: 使用 PBKDF2 从密码派生 256 位密钥
class PrivacyService with WidgetsBindingObserver {
  static final PrivacyService _instance = PrivacyService._internal();
  factory PrivacyService() => _instance;
  PrivacyService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  // ==================== 核心依赖 ====================
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    // Windows 使用默认加密存储
  );

  // ==================== 密钥管理 ====================
  /// 内存中的主密钥（App 杀死即销毁）
  enc.Key? _sessionKey;

  /// 自动锁定计时器
  Timer? _autoLockTimer;

  /// 自动锁定时长（默认 5 分钟）
  Duration _autoLockDuration = StorageConstants.privacyAutoLockTimeout;

  /// 获取当前会话密钥的原始字节（用于 Isolate 中的解密操作）
  /// 返回 null 表示未解锁
  Uint8List? get sessionKeyBytes => _sessionKey?.bytes;

  // ==================== 常量 ====================
  static const String _encryptPrefix = 'AES_V1::';
  static const String _storageKeyPasswordHash = 'privacy_password_hash';

  // ==================== 回调 ====================
  /// 解锁成功后的回调列表
  final List<VoidCallback> _onUnlockCallbacks = [];

  /// 注册解锁回调
  void addOnUnlockListener(VoidCallback callback) {
    _onUnlockCallbacks.add(callback);
  }

  /// 移除解锁回调
  void removeOnUnlockListener(VoidCallback callback) {
    _onUnlockCallbacks.remove(callback);
  }

  /// 触发解锁回调
  void _notifyUnlockListeners() {
    for (final callback in _onUnlockCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('❌ PrivacyService: 解锁回调执行失败 - $e');
      }
    }
  }

  // ==================== 状态获取 ====================
  bool get isUnlocked => _sessionKey != null;
  Duration get autoLockDuration => _autoLockDuration;

  // ==================== 初始化与生命周期 ====================

  /// 初始化隐私服务
  Future<void> initialize() async {
    debugPrint('🔐 PrivacyService: 已初始化');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _startAutoLockTimer();
        break;
      case AppLifecycleState.resumed:
        _cancelAutoLockTimer();
        break;
      default:
        break;
    }
  }

  void _startAutoLockTimer() {
    _cancelAutoLockTimer();
    if (!isUnlocked) return;
    
    _autoLockTimer = Timer(_autoLockDuration, () {
      lock();
      debugPrint('🔒 PrivacyService: 自动锁定触发');
    });
    debugPrint('⏱️ PrivacyService: 自动锁定计时器启动 (${_autoLockDuration.inMinutes}分钟)');
  }

  void _cancelAutoLockTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
  }

  // ==================== 密码管理 ====================

  /// 检查是否已设置密码
  Future<bool> hasPassword() async {
    final passwordHash = await _secureStorage.read(key: _storageKeyPasswordHash);
    return passwordHash != null;
  }

  /// 设置/修改密码
  ///
  /// [password]: 用户密码
  Future<void> setupPassword(String password) async {
    final salt = _generateSalt();
    final masterKey = _deriveKeyFromPassword(password, salt: salt);

    // 存储格式：base64(salt):HMAC-SHA256(salt, password)
    final hash = _hashPasswordWithSalt(password, salt);
    final storedValue = '${base64Encode(salt)}:$hash';
    await _secureStorage.write(key: _storageKeyPasswordHash, value: storedValue);

    _sessionKey = masterKey;
    debugPrint('🔐 PrivacyService: 密码设置成功 (HMAC-SHA256 + salt)');
  }
  /// 验证密码是否正确（不解锁，仅验证）
  Future<bool> verifyPassword(String password) async {
    try {
      final storedValue = await _secureStorage.read(key: _storageKeyPasswordHash);
      if (storedValue == null) return false;

      final parts = storedValue.split(':');
      if (parts.length == 2) {
        // 新格式：base64(salt):hash
        final salt = base64Decode(parts[0]);
        final expectedHash = _hashPasswordWithSalt(password, salt);
        return parts[1] == expectedHash;
      }
      // 旧格式：无 salt，直接 SHA-256
      final inputHash = sha256.convert(utf8.encode(password)).toString();
      return storedValue == inputHash;
    } catch (e) {
      return false;
    }
  }

  // ==================== 解锁方法 ====================

  /// 使用密码解锁
  Future<bool> unlockWithPassword(String password) async {
    try {
      HapticFeedback.lightImpact();

      final storedValue = await _secureStorage.read(key: _storageKeyPasswordHash);
      if (storedValue == null) {
        throw Exception('未设置密码');
      }

      final parts = storedValue.split(':');
      if (parts.length == 2) {
        // 新格式：base64(salt):hash
        final salt = base64Decode(parts[0]);
        final expectedHash = _hashPasswordWithSalt(password, salt);
        if (parts[1] != expectedHash) {
          debugPrint('❌ PrivacyService: 密码错误');
          return false;
        }
        _sessionKey = _deriveKeyFromPassword(password, salt: salt);
        debugPrint('🔓 PrivacyService: 密码解锁成功 (HMAC-SHA256 + salt)');
      } else {
        // 向后兼容：旧格式无 salt，直接 SHA-256
        final inputHash = sha256.convert(utf8.encode(password)).toString();
        if (storedValue != inputHash) {
          debugPrint('❌ PrivacyService: 密码错误');
          return false;
        }
        _sessionKey = _deriveKeyFromPassword(password, salt: []);
        debugPrint('🔓 PrivacyService: 密码解锁成功 (legacy SHA-256)');
      }

      _notifyUnlockListeners();
      return true;
    } catch (e) {
      debugPrint('❌ PrivacyService: 密码解锁失败 - $e');
      return false;
    }
  }

  /// 锁定
  void lock() {
    _sessionKey = null;
    _cancelAutoLockTimer();
    debugPrint('🔒 PrivacyService: 已锁定');
  }

  /// 修改密码
  Future<void> changePassword(String oldPassword, String newPassword) async {
    // 1. 先用旧密码解锁
    final success = await unlockWithPassword(oldPassword);
    if (!success) {
      throw Exception('原密码错误');
    }

    // 2. 使用新密码重新设置
    await setupPassword(newPassword);

    debugPrint('🔐 PrivacyService: 密码修改成功');
  }

  /// 重置隐私空间（删除所有数据）
  Future<void> resetPrivacySpace() async {
    _sessionKey = null;
    await _secureStorage.delete(key: _storageKeyPasswordHash);
    debugPrint('🗑️ PrivacyService: 隐私空间已重置');
  }

  // ==================== 加密/解密 ====================

  String encryptText(String plainText) {
    if (plainText.isEmpty) return plainText;
    if (plainText.startsWith(_encryptPrefix)) return plainText;

    if (_sessionKey == null) {
      throw Exception('PrivacyService is locked! Cannot encrypt data.');
    }

    final encrypter = enc.Encrypter(
      enc.AES(_sessionKey!, mode: enc.AESMode.gcm),
    );
    final iv = enc.IV.fromSecureRandom(StorageConstants.aesGcmIvLength); // GCM 推荐 12 字节 IV
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return '$_encryptPrefix${iv.base64}:${encrypted.base64}';
  }

  String decryptText(String cipherText) {
    if (cipherText.isEmpty || !cipherText.startsWith(_encryptPrefix)) {
      return cipherText;
    }

    if (_sessionKey == null) {
      return '🔒 [私密内容，请解锁查看]';
    }

    try {
      final data = cipherText.substring(_encryptPrefix.length).split(':');
      if (data.length != 2) throw Exception('Corrupted cipher text');

      final iv = enc.IV.fromBase64(data[0]);
      final encrypted = enc.Encrypted.fromBase64(data[1]);
      final encrypter = enc.Encrypter(
        enc.AES(_sessionKey!, mode: enc.AESMode.gcm),
      );

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      debugPrint('❌ PrivacyService: 解密失败 - $e');
      return '❌ [解密失败: 密钥错误或数据损坏]';
    }
  }

  /// 批量解密（用于列表展示）
  List<String> decryptTexts(List<String> cipherTexts) {
    if (!isUnlocked) {
      return cipherTexts.map((_) => '🔒 [私密内容]').toList();
    }
    return cipherTexts.map(decryptText).toList();
  }

  // ==================== 文件加密/解密 ====================

  /// 加密文件字节
  /// 
  /// [fileBytes]: 原始文件字节
  /// 返回加密后的字节，格式: IV (12 bytes) + Ciphertext + Auth Tag (16 bytes)
  Uint8List encryptFileBytes(Uint8List fileBytes) {
    if (_sessionKey == null) {
      throw Exception('PrivacyService is locked! Cannot encrypt file.');
    }

    final encrypter = enc.Encrypter(
      enc.AES(_sessionKey!, mode: enc.AESMode.gcm),
    );
    final iv = enc.IV.fromSecureRandom(StorageConstants.aesGcmIvLength);
    final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);

    // 格式: IV + Ciphertext
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
    result.setAll(0, iv.bytes);
    result.setAll(iv.bytes.length, encrypted.bytes);
    return result;
  }

  /// 解密文件字节
  /// 
  /// [encryptedBytes]: 加密后的字节（格式: IV + Ciphertext）
  /// 返回原始文件字节
  Uint8List decryptFileBytes(Uint8List encryptedBytes) {
    if (_sessionKey == null) {
      throw Exception('PrivacyService is locked! Cannot decrypt file.');
    }

    try {
      // 分离 IV 和密文
      final iv = enc.IV(Uint8List.fromList(encryptedBytes.sublist(0, StorageConstants.aesGcmIvLength)));
      final encrypted = enc.Encrypted(
        Uint8List.fromList(encryptedBytes.sublist(StorageConstants.aesGcmIvLength)),
      );

      final encrypter = enc.Encrypter(
        enc.AES(_sessionKey!, mode: enc.AESMode.gcm),
      );

      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('❌ PrivacyService: 文件解密失败 - $e');
      throw Exception('文件解密失败: 密钥错误或数据损坏');
    }
  }

  // ==================== 私有方法 ====================

  /// 生成随机 salt（16 字节）
  List<int> _generateSalt() {
    return enc.SecureRandom(StorageConstants.saltLength).bytes;
  }

  /// 使用 HMAC-SHA256 实现 PBKDF2 密钥派生
  ///
  /// PBKDF2 参数：
  /// - iterations: 10000 次（抵抗暴力破解）
  /// - keyLength: 32 字节（AES-256 密钥长度）
  /// - hash: HMAC-SHA256
  /// - salt: 16 字节随机值（与密文一起存储）
  enc.Key _deriveKeyFromPassword(String password, {required List<int> salt}) {
    const iterations = StorageConstants.pbkdf2Iterations;
    const keyLength = StorageConstants.aesKeyLength;
    const hashLength = StorageConstants.sha256HashLength;

    final hmac = Hmac(sha256, utf8.encode(password));
    final blocks = (keyLength / hashLength).ceil();
    final derivedBytes = <int>[];

    for (var blockIndex = 1; blockIndex <= blocks; blockIndex++) {
      // U1 = HMAC(password, salt || INT_32_BE(blockIndex))
      final input = [...salt, ..._intToBigEndianBytes(blockIndex)];
      var u = hmac.convert(input).bytes;
      var result = List<int>.from(u);

      // U2..Uc = HMAC(password, U_{i-1})
      for (var iteration = 1; iteration < iterations; iteration++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < result.length; j++) {
          result[j] ^= u[j];
        }
      }

      derivedBytes.addAll(result);
    }

    return enc.Key(Uint8List.fromList(derivedBytes.sublist(0, keyLength)));
  }

  /// 将整数转为大端序 4 字节
  List<int> _intToBigEndianBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// 使用 HMAC-SHA256 对密码加盐哈希
  ///
  /// [password]: 用户密码
  /// [salt]: 16 字节随机 salt
  String _hashPasswordWithSalt(String password, List<int> salt) {
    final hmac = Hmac(sha256, salt);
    return hmac.convert(utf8.encode(password)).toString();
  }

  /// 加密密钥
  Uint8List _encryptKey(enc.Key keyToEncrypt, enc.Key kek) {
    final encrypter = enc.Encrypter(
      enc.AES(kek, mode: enc.AESMode.gcm),
    );
    final iv = enc.IV.fromSecureRandom(StorageConstants.aesGcmIvLength);
    final encrypted = encrypter.encryptBytes(keyToEncrypt.bytes, iv: iv);
    
    // 格式: IV (16 bytes) + Ciphertext
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
    result.setAll(0, iv.bytes);
    result.setAll(iv.bytes.length, encrypted.bytes);
    return result;
  }

  /// 解密密钥
  enc.Key _decryptKey(Uint8List encryptedData, enc.Key kek) {
    final encrypter = enc.Encrypter(
      enc.AES(kek, mode: enc.AESMode.gcm),
    );
    
    // 分离 IV 和密文
    final iv = enc.IV(Uint8List.fromList(encryptedData.sublist(0, 12)));
    final encrypted = enc.Encrypted(
      Uint8List.fromList(encryptedData.sublist(12)),
    );
    
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return enc.Key(Uint8List.fromList(decrypted));
  }

  /// 清理资源
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelAutoLockTimer();
    lock();
  }
}
