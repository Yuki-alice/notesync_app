import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' hide Category;
import 'package:nsd/nsd.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:isar/isar.dart';

// 🌟 引入路径处理库
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// 🌟 引入所有模型
import '../../models/note.dart';
import '../../models/todo.dart';
import '../../models/category.dart';
import '../../models/tag.dart';

class LanSyncService extends ChangeNotifier {
  static const String _serviceType = '_notesync._tcp';

  HttpServer? _server;
  Registration? _mDnsRegistration;
  Discovery? _mDnsDiscovery;

  bool _isActive = false;
  bool get isActive => _isActive;

  int _serverPort = 0;
  int get serverPort => _serverPort;

  final List<Service> _discoveredDevices = [];
  List<Service> get discoveredDevices => _discoveredDevices;

  // ==========================================
  // 🚀 核心控制台
  // ==========================================
  Future<void> startEngine(String deviceName) async {
    if (_isActive) return;
    try {
      await _startLocalServer();
      await _broadcastPresence(deviceName, _serverPort);
      await _startRadar();
      _isActive = true;
      notifyListeners();
    } catch (e) {
      debugPrint('启动局域网引擎失败: $e');
      await stopEngine();
    }
  }

  Future<void> stopEngine() async {
    if (!_isActive) return;
    if (_mDnsRegistration != null) await unregister(_mDnsRegistration!);
    if (_mDnsDiscovery != null) await stopDiscovery(_mDnsDiscovery!);
    if (_server != null) await _server!.close(force: true);

    _mDnsRegistration = null;
    _mDnsDiscovery = null;
    _server = null;
    _discoveredDevices.clear();
    _isActive = false;
    _serverPort = 0;

    Future.microtask(() => notifyListeners());
  }

  // ==========================================
  // 🔄 强制刷新雷达
  // ==========================================
  Future<void> refreshRadar() async {
    if (!_isActive) return;
    if (_mDnsDiscovery != null) {
      await stopDiscovery(_mDnsDiscovery!);
      _mDnsDiscovery = null;
    }
    _discoveredDevices.clear();
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    await _startRadar();
  }

  // ==========================================
  // 📡 服务器端：吐出数据与图片流
  // ==========================================
  Future<void> _startLocalServer() async {
    final router = Router();

    router.get('/ping', (Request request) => Response.ok(jsonEncode({'status': 'ok'}), headers: {'content-type': 'application/json'}));

    // 🌟 API 1：拉取所有 JSON 数据
    router.get('/sync/pull', (Request request) async {
      try {
        final isar = Isar.getInstance()!;
        final notes = await isar.notes.where().findAll();
        final todos = await isar.todos.where().findAll();
        // 如果你的 Isar 生成的名称是 categorys 而不是 categories，请把下面对应的名称改掉
        final categories = await isar.categorys.where().findAll();
        final tags = await isar.tags.where().findAll();

        final payload = {
          'notes': notes.map((n) => n.toJson()).toList(),
          'todos': todos.map((t) => t.toJson()).toList(),
          'categories': categories.map((c) => c.toJson()).toList(),
          'tags': tags.map((t) => t.toJson()).toList(),
        };

        return Response.ok(jsonEncode(payload), headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.internalServerError(body: 'Database Error');
      }
    });

    // 🌟 API 2：获取实体图片文件 (微型图床)
    router.get('/sync/image/<fileName>', (Request request, String fileName) async {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appDir.path, 'note_images', fileName));

      if (await file.exists()) {
        return Response.ok(file.openRead(), headers: {
          'content-type': 'application/octet-stream',
          'content-length': (await file.length()).toString(),
        });
      }
      return Response.notFound('Image not found');
    });

    final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _serverPort = _server!.port;
  }

  // ==========================================
  // 🤝 客户端：拉取数据、下载图片并合并
  // ==========================================
  Future<bool> pullFromDevice(String host, int port) async {
    try {
      final uri = Uri.parse('http://$host:$port/sync/pull');
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 10);

      final request = await httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) return false;

      final jsonStr = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = jsonDecode(jsonStr);

      final isar = Isar.getInstance()!;
      final appDir = await getApplicationDocumentsDirectory();
      final localImgDir = Directory(p.join(appDir.path, 'note_images'));
      if (!await localImgDir.exists()) await localImgDir.create(recursive: true);

      await isar.writeTxn(() async {
        // --- 1. 合并分类 (LWW) ---
        final remoteCategories = data['categories'] as List<dynamic>? ?? [];
        for (var cMap in remoteCategories) {
          final remoteCat = Category.fromJson(cMap);
          final localCat = await isar.categorys.filter().idEqualTo(remoteCat.id).findFirst();
          if (localCat == null) {
            await isar.categorys.put(remoteCat);
          } else if (remoteCat.updatedAt.isAfter(localCat.updatedAt)) {
            remoteCat.isarId = localCat.isarId;
            await isar.categorys.put(remoteCat);
          }
        }

        // --- 2. 合并标签 (以远端为准补全) ---
        final remoteTags = data['tags'] as List<dynamic>? ?? [];
        for (var tMap in remoteTags) {
          final remoteTag = Tag.fromJson(tMap);
          final localTag = await isar.tags.filter().idEqualTo(remoteTag.id).findFirst();
          if (localTag == null) {
            await isar.tags.put(remoteTag);
          } else {
            remoteTag.isarId = localTag.isarId;
            await isar.tags.put(remoteTag);
          }
        }

        // --- 3. 合并笔记 (含图片下载与路径重写引擎) ---
        final remoteNotes = data['notes'] as List<dynamic>? ?? [];
        for (var remoteNoteMap in remoteNotes) {
          final remoteNote = Note.fromJson(remoteNoteMap);

          // 提取该笔记所有的图片路径
          final rawImagePaths = Note.extractAllImagePaths(remoteNote.content);
          String rewrittenContent = remoteNote.content;

          for (String rawPath in rawImagePaths) {
            final fileName = p.basename(rawPath.replaceAll('\\', '/'));
            final localFile = File(p.join(localImgDir.path, fileName));

            // 如果本地没有这张图片，向对方请求下载
            if (!await localFile.exists()) {
              final imgUri = Uri.parse('http://$host:$port/sync/image/$fileName');
              final imgReq = await httpClient.getUrl(imgUri);
              final imgRes = await imgReq.close();
              if (imgRes.statusCode == 200) {
                await imgRes.pipe(localFile.openWrite());
                debugPrint('✅ 成功下载缺失图片: $fileName');
              }
            }

            // 暴力重写：用本地的新绝对路径替换旧的绝对路径
            rewrittenContent = rewrittenContent.replaceAll(rawPath, localFile.path.replaceAll('\\', '/'));
          }

          remoteNote.content = rewrittenContent;

          final localNote = await isar.notes.filter().idEqualTo(remoteNote.id).findFirst();
          if (localNote == null) {
            await isar.notes.put(remoteNote);
          } else if (remoteNote.updatedAt.isAfter(localNote.updatedAt)) {
            remoteNote.isarId = localNote.isarId;
            await isar.notes.put(remoteNote);
          }
        }

        // --- 4. 合并待办 (LWW) ---
        final remoteTodos = data['todos'] as List<dynamic>? ?? [];
        for (var remoteTodoMap in remoteTodos) {
          final remoteTodo = Todo.fromJson(remoteTodoMap);
          final localTodo = await isar.todos.filter().idEqualTo(remoteTodo.id).findFirst();

          if (localTodo == null) {
            await isar.todos.put(remoteTodo);
          } else if (remoteTodo.updatedAt.isAfter(localTodo.updatedAt)) {
            remoteTodo.isarId = localTodo.isarId; // 保留本地 ID
            await isar.todos.put(remoteTodo);
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('拉取合并数据失败: $e');
      return false;
    }
  }

  // ==========================================
  // 🔍 广播与发现
  // ==========================================
  Future<void> _broadcastPresence(String name, int port) async {
    final service = Service(
      name: name, type: _serviceType, port: port,
      txt: {
        'app': Uint8List.fromList(utf8.encode('notesync')),
        'version': Uint8List.fromList(utf8.encode('2.2.0')),
      },
    );
    _mDnsRegistration = await register(service);
  }

  Future<void> _startRadar() async {
    _mDnsDiscovery = await startDiscovery(_serviceType);

    _mDnsDiscovery?.addListener(() {
      final discovery = _mDnsDiscovery;
      if (discovery == null) return;

      _discoveredDevices.clear();
      for (final service in discovery.services) {
        if (service.name != null && service.host != null) {
          _discoveredDevices.add(service);
        }
      }
      Future.microtask(() => notifyListeners());
    });
  }
}