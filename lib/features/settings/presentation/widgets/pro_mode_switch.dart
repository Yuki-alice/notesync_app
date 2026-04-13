import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProModeSwitchTile extends StatefulWidget {
  const ProModeSwitchTile({super.key});

  @override
  State<ProModeSwitchTile> createState() => _ProModeSwitchTileState();
}

class _ProModeSwitchTileState extends State<ProModeSwitchTile> {
  bool _isProMode = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isProMode = prefs.getBool('isProMode') ?? false);
  }

  Future<void> _toggleMode(bool value) async {
    setState(() => _isProMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isProMode', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: _isProMode,
      onChanged: _toggleMode,
      // 🌟 修复：强行锁死 fontSize 15，和普通的列表对齐！
      title: Text(
          '专业编辑模式',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)
      ),
      // 🌟 修复：强行锁死 fontSize 12！
      subtitle: Text(
          '支持 Markdown 语法 (如 "# " 生成标题)',
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)
      ),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
        // 🌟 修复：把 Icon 的大小也锁死为 20！
        child: Icon(Icons.code_rounded, color: theme.colorScheme.primary, size: 20),
      ),
    );
  }
}