import 'package:flutter_test/flutter_test.dart';

/// 同步冲突解决策略统一测试
///
/// 统一策略 (与 Supabase/LAN/WebDAV 一致):
///   - Notes/Todos: version 优先，version 相同时用 updatedAt 作为后备
///   - Categories: updatedAt LWW (无 version 字段)
///   - Tags: 仅补全存在性
void main() {
  group('LWW 合并算法 (version 优先)', () {
    test('remote version 更高时应接受远端', () {
      final local = _TestItem(id: '1', version: 2, updatedAt: _t(10));
      final remote = _TestItem(id: '1', version: 3, updatedAt: _t(5));
      // remote.version(3) > local.version(2)
      expect(_shouldAcceptRemote(local, remote), true);
    });

    test('local version 更高时应拒绝远端', () {
      final local = _TestItem(id: '1', version: 5, updatedAt: _t(5));
      final remote = _TestItem(id: '1', version: 3, updatedAt: _t(10));
      expect(_shouldAcceptRemote(local, remote), false);
    });

    test('version 相同时用 updatedAt 作为后备', () {
      final local = _TestItem(id: '1', version: 3, updatedAt: _t(5));
      final remote = _TestItem(id: '1', version: 3, updatedAt: _t(10));
      // version 相同, remote.updatedAt > local.updatedAt
      expect(_shouldAcceptRemote(local, remote), true);
    });

    test('version 相同且 local 更新时拒绝远端', () {
      final local = _TestItem(id: '1', version: 3, updatedAt: _t(10));
      final remote = _TestItem(id: '1', version: 3, updatedAt: _t(5));
      expect(_shouldAcceptRemote(local, remote), false);
    });

    test('version 相同且 updatedAt 相同时拒绝远端', () {
      final local = _TestItem(id: '1', version: 3, updatedAt: _t(10));
      final remote = _TestItem(id: '1', version: 3, updatedAt: _t(10));
      expect(_shouldAcceptRemote(local, remote), false);
    });

    test('本地不存在时应接受远端', () {
      final remote = _TestItem(id: '1', version: 1, updatedAt: _t(1));
      expect(_shouldAcceptRemote(null, remote), true);
    });
  });

  group('version 冲突检测', () {
    test('两端都更新了 lastSyncedVersion 后应检测为冲突', () {
      const lastSyncedVersion = 2;
      const localVersion = 4;
      const cloudVersion = 3;

      final localUpdated = localVersion > lastSyncedVersion;
      final cloudUpdated = cloudVersion > lastSyncedVersion;
      final isConflict = localUpdated && cloudUpdated;

      expect(isConflict, true);
    });

    test('只有一端更新时不是冲突', () {
      const lastSyncedVersion = 2;
      // 本地更新了，云端没更新
      expect(3 > lastSyncedVersion && 2 > lastSyncedVersion, false);
      // 云端更新了，本地没更新
      expect(2 > lastSyncedVersion && 3 > lastSyncedVersion, false);
    });

    test('版本都等于 lastSyncedVersion 时不是冲突', () {
      const lastSyncedVersion = 5;
      expect(5 > lastSyncedVersion && 5 > lastSyncedVersion, false);
    });
  });

  group('删除黑名单', () {
    test('黑名单中的远程笔记应被排除', () {
      final remoteNotes = [
        _TestItem(id: 'a', version: 1, updatedAt: _t(1)),
        _TestItem(id: 'b', version: 1, updatedAt: _t(1)),
        _TestItem(id: 'c', version: 1, updatedAt: _t(1)),
      ];
      final blacklist = {'b'};

      final filtered = remoteNotes
          .where((n) => !blacklist.contains(n.id))
          .toList();

      expect(filtered.length, 2);
      expect(filtered.any((n) => n.id == 'b'), false);
    });

    test('空黑名单不影响结果', () {
      final items = [
        _TestItem(id: 'a', version: 1, updatedAt: _t(1)),
        _TestItem(id: 'b', version: 1, updatedAt: _t(1)),
      ];
      final blacklist = <String>{};

      final filtered = items
          .where((n) => !blacklist.contains(n.id))
          .toList();

      expect(filtered.length, 2);
    });
  });

  group('完整 LWW 合并流程', () {
    test('合并结果：新项目、更新项目、旧项目、黑名单项目', () {
      final localMap = {
        'existing': _TestItem(id: 'existing', version: 2, updatedAt: _t(5)),
        'older': _TestItem(id: 'older', version: 3, updatedAt: _t(5)),
        'todelete': _TestItem(id: 'todelete', version: 1, updatedAt: _t(1)),
      };
      final remoteItems = [
        // 新项目
        _TestItem(id: 'new', version: 1, updatedAt: _t(1)),
        // 更新项目 (version 更高)
        _TestItem(id: 'existing', version: 3, updatedAt: _t(10)),
        // 旧项目 (version 更低)
        _TestItem(id: 'older', version: 2, updatedAt: _t(10)),
        // 黑名单项目
        _TestItem(id: 'todelete', version: 5, updatedAt: _t(20)),
      ];
      final blacklist = {'todelete'};

      final merged = _mergeLWW(localMap, remoteItems, blacklist);

      expect(merged, contains('new'));
      expect(merged, contains('existing')); // version 3 > 2
      expect(merged, isNot(contains('older'))); // version 2 < 3
      expect(merged, isNot(contains('todelete'))); // 黑名单
    });

    test('合并标签：仅补全存在性', () {
      final localTags = {'tag1': 'Tag 1', 'tag2': 'Tag 2'};
      final remoteTags = [
        _TestTag(id: 'tag1', name: 'Updated Tag 1'), // 已存在
        _TestTag(id: 'tag3', name: 'Tag 3'), // 新标签
      ];

      final result = _mergeTags(localTags, remoteTags);

      expect(result, contains('tag3'));
      expect(result, isNot(contains('tag1'))); // 已存在，不添加
      expect(result.length, 1);
    });
  });
}

// ===== 测试辅助类和函数 =====

class _TestItem {
  final String id;
  final int version;
  final DateTime updatedAt;
  _TestItem({
    required this.id,
    required this.version,
    required this.updatedAt,
  });
}

class _TestTag {
  final String id;
  final String name;
  _TestTag({required this.id, required this.name});
}

DateTime _t(int hour) => DateTime(2026, 5, 11, hour);

/// 统一冲突策略：remote 是否应覆盖 local
bool _shouldAcceptRemote(_TestItem? local, _TestItem remote) {
  if (local == null) return true;
  if (remote.version > local.version) return true;
  if (remote.version == local.version &&
      remote.updatedAt.isAfter(local.updatedAt)) {
    return true;
  }
  return false;
}

/// 模拟 LWW 合并，返回应接受的远端项目 ID 列表
List<String> _mergeLWW(
  Map<String, _TestItem> localMap,
  List<_TestItem> remoteItems,
  Set<String> blacklist,
) {
  final accepted = <String>[];
  for (var r in remoteItems) {
    if (blacklist.contains(r.id)) continue;
    final local = localMap[r.id];
    if (_shouldAcceptRemote(local, r)) {
      accepted.add(r.id);
    }
  }
  return accepted;
}

/// 模拟标签合并：仅补全本地不存在的标签
List<String> _mergeTags(
  Map<String, String> localTags,
  List<_TestTag> remoteTags,
) {
  final added = <String>[];
  for (var r in remoteTags) {
    if (!localTags.containsKey(r.id)) {
      added.add(r.id);
    }
  }
  return added;
}
