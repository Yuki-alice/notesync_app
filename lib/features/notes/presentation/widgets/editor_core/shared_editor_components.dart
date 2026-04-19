import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:notesync_app/features/notes/presentation/widgets/editor_core/quill_styles_config.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:provider/provider.dart';
import '../../../../../core/providers/notes_provider.dart';
import '../../../../../core/theme/app_fonts.dart';
import '../../views/note_editor_page.dart';

import '../../../../../core/services/image_storage_service.dart';
import '../../viewmodels/note_editor_viewmodel.dart';
import '../note_image_embed.dart';

class EditorTitleField extends StatelessWidget {
  final ThemeData theme;
  final NoteEditorViewModel viewModel;
  final FocusNode focusNode;
  final FocusNode editorFocusNode;
  final bool isDesktop;

  const EditorTitleField({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.focusNode,
    required this.editorFocusNode,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: viewModel.titleController,
      focusNode: focusNode,
      textInputAction: TextInputAction.next,
      readOnly: viewModel.isReadOnly,
      onEditingComplete: () => editorFocusNode.requestFocus(),
      decoration: InputDecoration(
        hintText: '写个好标题...',
        hintStyle: AppFonts.editorTitle(context, isDesktop: isDesktop).copyWith(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: AppFonts.editorTitle(context, isDesktop: isDesktop),
      maxLines: null,
    );
  }
}

class EditorQuillArea extends StatefulWidget {
  final ThemeData theme;
  final NoteEditorViewModel viewModel;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final ImageStorageService imageService;
  final bool isDesktop;

  const EditorQuillArea({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.focusNode,
    required this.scrollController,
    required this.imageService,
    this.isDesktop = false,
  });

  @override
  State<EditorQuillArea> createState() => _EditorQuillAreaState();
}

class _EditorQuillAreaState extends State<EditorQuillArea> {
  bool _isImageSelected = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;

    return quill.QuillEditor.basic(
      controller: viewModel.quillController,
      focusNode: widget.focusNode,
      scrollController: widget.scrollController,
      config: quill.QuillEditorConfig(
        scrollable: false,
        expands: false,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        placeholder: '从这里开始你的灵感...',
        autoFocus: false,
        showCursor: !viewModel.isReadOnly && !_isImageSelected,

        // 🌟 终极护甲：防污染 URL 拦截系统
        onLaunchUrl: (String? url) async {
          if (url == null || url.isEmpty) return;

          // 【强力剥离】无论 Quill 怎么污染（https://notesync//note/ 等）
          // 我们直接用正则锁定 "notesync" 后面跟着的 UUID！
          if (url.contains('notesync')) {
            final RegExp regExp = RegExp(r'notesync[:/]*note/([a-zA-Z0-9\-]+)');
            final match = regExp.firstMatch(url);

            if (match != null) {
              final noteId = match.group(1)!;
              final provider = context.read<NotesProvider>();
              final targetNote = provider.getNoteById(noteId);

              if (targetNote != null) {
                await viewModel.saveNote(); // 穿越前保存当前状态
                if (!mounted) return;

                // 光速穿越！
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) => NoteEditorPage(note: targetNote),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
              return; // 处理完毕，阻断后续浏览器跳转
            }
          }

          // 【普通链接处理】
          var parsedUrl = url.startsWith('http') ? url : 'https://$url';
          try {
            final uri = Uri.parse(parsedUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint('无法打开外部链接: $parsedUrl');
          }
        },
        embedBuilders: [
          ImageEmbedBuilder(
            imageService: widget.imageService,
            onSelectionChange: (isSelected) {
              if (_isImageSelected != isSelected && mounted) {
                setState(() => _isImageSelected = isSelected);
              }
            },
          ),
        ],
        customStyles: widget.isDesktop
            ? QuillStylesConfig.getDesktopStyles(context)
            : QuillStylesConfig.getMobileStyles(context),
      ),
    );
  }
}