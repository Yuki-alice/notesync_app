import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/note.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  List<String> _resolvedImagePaths = [];
  bool _isLoadingImages = true;

  @override
  void initState() {
    super.initState();
    _prepareMediaGallery();
  }

  Future<void> _prepareMediaGallery() async {
    final notesProvider = context.read<NotesProvider>();
    final appDir = await getApplicationDocumentsDirectory();
    final imgDir = p.join(appDir.path, 'note_images');

    Set<String> uniqueImages = {};
    for (var note in notesProvider.filteredNotes) {
      final rawPaths = Note.extractAllImagePaths(note.content ?? '');
      for (var rawPath in rawPaths) {
        final fileName = p.basename(rawPath.replaceAll('\\', '/'));
        final localPath = p.join(imgDir, fileName);
        if (File(localPath).existsSync()) {
          uniqueImages.add(localPath);
        }
      }
    }

    if (mounted) {
      setState(() {
        _resolvedImagePaths = uniqueImages.toList();
        _isLoadingImages = false;
      });
    }
  }

  Color _parseColor(dynamic colorVal, Color defaultColor) {
    if (colorVal == null) return defaultColor;
    if (colorVal is int) return Color(colorVal);
    if (colorVal is String) {
      try {
        String hex = colorVal.replaceAll('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        return Color(int.parse(hex, radix: 16));
      } catch (_) { return defaultColor; }
    }
    return defaultColor;
  }

  void _openGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SimplePhotoViewer(
          imagePaths: _resolvedImagePaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final notesProvider = context.watch<NotesProvider>();
    final todosProvider = context.watch<TodosProvider>();
    final allNotes = notesProvider.filteredNotes;

    // 1. 基础数据计算
    int daysJoined = 1;
    if (auth.currentUser?.createdAt != null) {
      daysJoined = DateTime.now().difference(DateTime.parse(auth.currentUser!.createdAt)).inDays;
      if (daysJoined < 1) daysJoined = 1;
    }

    final notesCount = allNotes.length;
    final todosCount = todosProvider.todos.length;
    int totalWords = 0;

    // 2. 创作时段画像计算
    int morning = 0; int afternoon = 0; int night = 0;
    for (var note in allNotes) {
      totalWords += (note.content ?? '').length;
      final hour = note.createdAt.hour;
      if (hour >= 5 && hour < 12) morning++;
      else if (hour >= 12 && hour < 19) afternoon++;
      else night++;
    }

    String personaTitle = "均衡型记录者";
    String personaDesc = "你在各个时段都有挥洒灵感的习惯。";
    IconData personaIcon = Icons.balance_rounded;
    if (allNotes.isNotEmpty) {
      if (morning > afternoon && morning > night) {
        personaTitle = "晨间记录者"; personaDesc = "一日之计在于晨，你喜欢在清晨捕捉灵感。"; personaIcon = Icons.wb_twilight_rounded;
      } else if (night > morning && night > afternoon) {
        personaTitle = "深夜思想家"; personaDesc = "夜深人静时，是你思如泉涌的高光时刻。"; personaIcon = Icons.nights_stay_rounded;
      } else if (afternoon > morning && afternoon > night) {
        personaTitle = "午后观察家"; personaDesc = "伴随午后阳光，你留下了最多的足迹。"; personaIcon = Icons.wb_sunny_rounded;
      }
    }

    // 3. 🌟 新增：最近 15 天活跃度与动态评语计算
    final today = DateTime.now();
    const int daysToShow = 15;
    int activeDaysCount = 0;

    List<Map<String, dynamic>> recentActivity = List.generate(daysToShow, (index) {
      final date = today.subtract(Duration(days: daysToShow - 1 - index));
      final isActive = allNotes.any((n) => n.createdAt.year == date.year && n.createdAt.month == date.month && n.createdAt.day == date.day);
      if (isActive) activeDaysCount++;

      // 提取日期，最后一天显示“今”
      String label = date.day.toString();
      if (index == daysToShow - 1) label = '今';

      return {'isActive': isActive, 'label': label};
    });

    // 根据活跃度生成走心评语
    String activityComment;
    if (activeDaysCount >= 12) {
      activityComment = "太棒了！近期灵感大爆发，你的坚持令人惊叹！";
    } else if (activeDaysCount >= 7) {
      activityComment = "保持着极佳的记录节奏，继续加油哦！";
    } else if (activeDaysCount >= 3) {
      activityComment = "每一次提笔，都是与自己的一次深度对话。";
    } else {
      activityComment = "偶尔记录一下生活也是极好的，期待你的新故事。";
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('探索与统计', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ==========================================
          // 模块 1：数据总览
          // ==========================================
          _buildSectionHeader(theme, '数据总览', Icons.dashboard_rounded),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatHex(theme, '陪伴', '$daysJoined', '天', Icons.favorite_rounded),
                    _buildStatHex(theme, '待办', '$todosCount', '个', Icons.check_circle_rounded),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatHex(theme, '笔记', '$notesCount', '篇', Icons.description_rounded),
                    _buildStatHex(theme, '累计', totalWords >= 10000 ? '${(totalWords / 10000).toStringAsFixed(1)}W' : '$totalWords', '字', Icons.edit_note_rounded),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 2：大一统的“创作习惯”卡片 (🌟 核心重构)
          // ==========================================
          _buildSectionHeader(theme, '创作习惯', Icons.insights_rounded),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest, // 统一的卡片底色
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. 画像部分 ---
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(personaIcon, size: 24, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(personaTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 4),
                          Text(personaDesc, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- 2. 极简分隔线 ---
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                const SizedBox(height: 20),

                // --- 3. 15天热力图打卡区 ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('近 $daysToShow 天活跃记录', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, fontSize: 14)),
                    Text('$activeDaysCount / $daysToShow', style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 12,
                  children: recentActivity.map((day) {
                    final isActive = day['isActive'] as bool;
                    final isToday = day['label'] == '今';
                    return Column(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: isActive ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isActive ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(height: 6),
                        Text(day['label'], style: TextStyle(fontSize: 11, color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, fontWeight: isToday ? FontWeight.bold : FontWeight.w500)),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // --- 4. 走心动态评语 ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wb_incandescent_rounded, size: 18, color: theme.colorScheme.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activityComment,
                          style: TextStyle(fontSize: 13, color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 3：标签云
          // ==========================================
          _buildSectionHeader(theme, '分类标签', Icons.sell_rounded),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: notesProvider.tags.isEmpty
                ? _buildEmptyHint(theme, '暂无标签数据')
                : Wrap(
              spacing: 10, runSpacing: 10,
              children: notesProvider.tags.map((tag) {
                final color = _parseColor(tag.color, theme.colorScheme.primary);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text('# ${tag.name}', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 4：媒体画廊
          // ==========================================
          _buildSectionHeader(theme, '媒体画廊', Icons.photo_library_rounded),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: _isLoadingImages
                ? const Center(child: CircularProgressIndicator())
                : _resolvedImagePaths.isEmpty
                ? _buildEmptyHint(theme, '尚未在笔记中添加图片')
                : SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _resolvedImagePaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _openGallery(index),
                    child: Hero(
                      tag: 'gallery_image_$index',
                      child: Container(
                        width: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(
                            image: FileImage(File(_resolvedImagePaths[index])),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatHex(ThemeData theme, String label, String value, String unit, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  const SizedBox(width: 2),
                  Text(unit, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ],
              ),
              Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmptyHint(ThemeData theme, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(text, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ==========================================
// 独立组件：极简全屏图片查看器
// ==========================================
class _SimplePhotoViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const _SimplePhotoViewer({
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<_SimplePhotoViewer> createState() => _SimplePhotoViewerState();
}

class _SimplePhotoViewerState extends State<_SimplePhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.imagePaths.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemCount: widget.imagePaths.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Hero(
              tag: 'gallery_image_$index',
              child: Image.file(
                File(widget.imagePaths[index]),
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}