import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus { online, offline, unknown }

class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  NetworkStatus _status = NetworkStatus.unknown;

  NetworkStatus get status => _status;
  bool get isOnline => _status == NetworkStatus.online;

  Future<void> init() async {
    await _checkInitialStatus();
    _subscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkInitialStatus() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 网络状态检测失败: $e');
      _status = NetworkStatus.unknown;
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = isOnline;
    final hasConnection = results.any((r) =>
        r != ConnectivityResult.none);

    _status = hasConnection ? NetworkStatus.online : NetworkStatus.offline;

    if (wasOnline != isOnline) {
      if (kDebugMode) {
        debugPrint(' 网络状态变化: ${isOnline ? "在线" : "离线"}');
      }
      notifyListeners();
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
