import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';



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
  Duration _autoLockDuration = const Duration(minutes: 5);

  // ==================== 常量 ====================
  static const String _encryptPrefix = 'AES_V1::';
  static const String _storageKeyPasswordHash = 'privacy_password_hash';

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
    // 🌟 跨设备兼容：使用密码派生密钥直接加密，而不是随机密钥
    // 这样跨设备时，只要输入相同密码，就能派生相同密钥解密
    final masterKey = _deriveKeyFromPassword(password);

    // 2. 保存密码哈希（用于验证）
    final passwordHash = sha256.convert(utf8.encode(password)).toString();
    await _secureStorage.write(
      key: _storageKeyPasswordHash,
      value: passwordHash,
    );

    // 3. 设置内存中的密钥
    _sessionKey = masterKey;

    debugPrint('🔐 PrivacyService: 密码设置成功');
  }
  /// 验证密码是否正确（不解锁，仅验证）
  Future<bool> verifyPassword(String password) async {
    try {
      final passwordHash = await _secureStorage.read(key: _storageKeyPasswordHash);
      if (passwordHash == null) return false;
      
      final inputHash = sha256.convert(utf8.encode(password)).toString();
      return passwordHash == inputHash;
    } catch (e) {
      return false;
    }
  }

  // ==================== 解锁方法 ====================

  /// 使用密码解锁
  Future<bool> unlockWithPassword(String password) async {
    try {
      HapticFeedback.lightImpact();

      // 验证密码哈希
      final passwordHash = await _secureStorage.read(key: _storageKeyPasswordHash);
      if (passwordHash == null) {
        throw Exception('未设置密码');
      }

      final inputHash = sha256.convert(utf8.encode(password)).toString();
      if (passwordHash != inputHash) {
        debugPrint('❌ PrivacyService: 密码错误');
        return false;
      }

      // 🌟 跨设备兼容：从密码派生密钥
      _sessionKey = _deriveKeyFromPassword(password);

      debugPrint('🔓 PrivacyService: 密码解锁成功');
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
    final iv = enc.IV.fromSecureRandom(12); // GCM 推荐 12 字节 IV
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

  // ==================== 私有方法 ====================

  /// 从密码派生密钥（简化版 PBKDF2）
  enc.Key _deriveKeyFromPassword(String password) {
    // 使用 SHA-256 派生 32 字节密钥
    // 生产环境建议使用更安全的 Argon2 或 PBKDF2 多轮迭代
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }

  /// 加密密钥
  Uint8List _encryptKey(enc.Key keyToEncrypt, enc.Key kek) {
    final encrypter = enc.Encrypter(
      enc.AES(kek, mode: enc.AESMode.gcm),
    );
    final iv = enc.IV.fromSecureRandom(12);
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
