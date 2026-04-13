import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/services/lan_sync_service.dart';
import '../../../../utils/toast_utils.dart';

class LanSyncRadarPage extends StatefulWidget {
  const LanSyncRadarPage({super.key});

  @override
  State<LanSyncRadarPage> createState() => _LanSyncRadarPageState();
}

class _LanSyncRadarPageState extends State<LanSyncRadarPage> {
  // 🌟 1. 去掉 late，变成可空变量，彻底防止未初始化报错
  LanSyncService? _lanSyncService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🌟 2. 这是 Flutter 官方推荐的安全获取上下文的地方，热重载也能完美捕获！
    _lanSyncService ??= context.read<LanSyncService>();
  }

  @override
  void dispose() {
    // 🌟 3. 安全调用：如果口袋里有东西，才去关引擎
    _lanSyncService?.stopEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lanSync = context.watch<LanSyncService>();
    final auth = context.read<AuthProvider>();

    final myDeviceName = '${auth.displayName.isNotEmpty ? auth.displayName : "我"}的 NoteSync';

    // 🌟 核心修复：提前过滤掉“自己”，并且【忽略大小写】比对
    final validDevices = lanSync.discoveredDevices.where((device) {
      // 1. 第一道防线：因为我们的端口是随机生成的，如果搜到的端口和自己一模一样，那100%是自己！
      if (device.port == lanSync.serverPort) return false;

      // 2. 第二道防线：忽略大小写的名字比对
      final deviceName = device.name?.toLowerCase() ?? '';
      if (deviceName == myDeviceName.toLowerCase()) return false;

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('局域网雷达测试', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. 雷达总控台
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
              border: Border.all(color: lanSync.isActive ? theme.colorScheme.primary.withOpacity(0.3) : Colors.transparent, width: 2),
            ),
            child: Column(
              children: [
                Icon(
                    lanSync.isActive ? Icons.radar_rounded : Icons.cell_tower_rounded,
                    size: 48,
                    color: lanSync.isActive ? theme.colorScheme.primary : theme.colorScheme.outline
                ),
                const SizedBox(height: 16),
                Text(lanSync.isActive ? '引擎正在运行' : '引擎已关闭', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  lanSync.isActive ? '我的设备名: $myDeviceName\n微型服务器端口: ${lanSync.serverPort}' : '开启引擎后，附近的设备将能发现你',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () {
                    if (lanSync.isActive) {
                      lanSync.stopEngine();
                    } else {
                      lanSync.startEngine(myDeviceName);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: lanSync.isActive ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                    foregroundColor: lanSync.isActive ? theme.colorScheme.error : theme.colorScheme.primary,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: Text(lanSync.isActive ? '关闭引擎' : '启动雷达与服务器', style: const TextStyle(fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const SizedBox(height: 40),

          // 🌟 2. 发现的设备列表 (使用过滤后的 validDevices)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('附近的设备 (${validDevices.length})', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14)),
              if (lanSync.isActive)
                IconButton(
                  onPressed: () {
                    // 点击后触发强制刷新，扫除幽灵设备！
                    lanSync.refreshRadar();
                  },
                  icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary),
                  tooltip: '刷新雷达',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (!lanSync.isActive)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('请先启动雷达', style: TextStyle(color: theme.colorScheme.outline))))
          else if (validDevices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('正在扫描同一 Wi-Fi 下的其他设备...', style: TextStyle(color: theme.colorScheme.outlineVariant)),
                  ],
                ),
              ),
            )
          else
            ...validDevices.map((device) {
              // 处理 Windows 喜欢用 .local 后缀作为 host 的情况
              final ipDisplay = device.host ?? "解析中...";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.smartphone_rounded, color: theme.colorScheme.primary),
                  ),
                  title: Text(device.name ?? '未知设备', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('IP: $ipDisplay | 端口: ${device.port}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      // 1. 弹出防误触/进度框
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => const AlertDialog(
                          content: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 20),
                              Text('正在握手并合并数据...'),
                            ],
                          ),
                        ),
                      );

                      // 2. 调用引擎执行终极 Pull 拉取
                      final host = device.host!;
                      final port = device.port!;
                      final success = await lanSync.pullFromDevice(host, port);

                      // 3. 关闭进度框
                      if (!context.mounted) return;
                      Navigator.pop(context);

                      // 4. 通知全局 UI 刷新数据
                      if (success) {
                        // 通知 Provider 重新从 Isar 加载最新数据
                        context.read<NotesProvider>().loadNotes();
                        context.read<TodosProvider>().loadTodos();

                        ToastUtils.showSuccess(context, '🎉 数据合并成功！');
                      } else {
                        ToastUtils.showError(context, '连接失败，请检查网络');
                      }
                    },
                    child: const Text('连接', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}