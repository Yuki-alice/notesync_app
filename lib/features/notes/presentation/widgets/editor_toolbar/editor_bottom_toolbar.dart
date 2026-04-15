import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;


import 'components/toolbar_button.dart';
import 'panels/format_panel.dart';
import 'panels/insert_panel.dart';
import 'panels/metadata_panel.dart';

enum ToolbarPanel { none, format, insert, metadata }

class EditorBottomToolbar extends StatelessWidget {
  final quill.QuillController controller;
  final ToolbarPanel activePanel;
  final ValueChanged<ToolbarPanel> onPanelChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onPickImage;
  final VoidCallback onFinish;

  const EditorBottomToolbar({
    super.key,
    required this.controller,
    required this.activePanel,
    required this.onPanelChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onPickImage,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unifiedBgColor = theme.colorScheme.surface;
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: unifiedBgColor,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 核心调度层：动态加载子面板
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              child: activePanel != ToolbarPanel.none
                  ? Container(
                decoration: BoxDecoration(
                  color: unifiedBgColor,
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15), width: 0.5)),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)),
                  // 路由分发给拆分出去的 Widgets
                  child: activePanel == ToolbarPanel.format
                      ? FormatPanel(key: const ValueKey('format'), controller: controller)
                      : (activePanel == ToolbarPanel.insert
                      ? InsertPanel(key: const ValueKey('insert'), controller: controller, onPickImage: onPickImage, onPanelChanged: onPanelChanged)
                      : const MetadataPanel(key: ValueKey('metadata'))),
                ),
              )
                  : const SizedBox.shrink(),
            ),

            // 🌟 底层主轴：永远只包含按钮调度逻辑
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _buildPanelToggleButton(context, panel: ToolbarPanel.insert, icon: Icons.add_rounded, isRotatingIcon: true),
                  const SizedBox(width: 4),
                  _buildPanelToggleButton(context, panel: ToolbarPanel.format, text: 'Aa'),
                  const SizedBox(width: 4),
                  _buildPanelToggleButton(context, panel: ToolbarPanel.metadata, icon: Icons.local_offer_outlined),

                  const SizedBox(width: 8),
                  const ToolbarDivider(),
                  const SizedBox(width: 8),

                  ToolbarIconButton(icon: Icons.undo_outlined, onPressed: onUndo, inactiveColor: iconColor),
                  ToolbarIconButton(icon: Icons.redo_outlined, onPressed: onRedo, inactiveColor: iconColor),

                  const Spacer(),

                  FilledButton.tonal(
                    onPressed: onFinish,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(60, 36),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('完成', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Toggle 按钮因为与主轴强相关，所以保留在壳子里
  Widget _buildPanelToggleButton(BuildContext context, {required ToolbarPanel panel, IconData? icon, String? text, bool isRotatingIcon = false}) {
    final theme = Theme.of(context);
    final isActive = activePanel == panel;
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => onPanelChanged(isActive ? ToolbarPanel.none : panel),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) isRotatingIcon ? AnimatedRotation(turns: isActive ? 0.125 : 0.0, duration: const Duration(milliseconds: 200), child: Icon(icon, size: 24, color: color)) : Icon(icon, size: 22, color: color),
              if (text != null) Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5)),
            ],
          ),
        ),
      ),
    );
  }
}