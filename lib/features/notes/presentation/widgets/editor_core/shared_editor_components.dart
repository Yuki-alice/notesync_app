import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:notesync_app/features/notes/presentation/widgets/editor_core/quill_styles_config.dart';
import 'package:url_launcher/url_launcher.dart';


import '../../../../../core/services/image_storage_service.dart';
import '../../viewmodels/note_editor_viewmodel.dart';
import '../note_image_embed.dart';


class EditorTitleField extends StatelessWidget {
  final ThemeData theme;
  final NoteEditorViewModel viewModel;
  final FocusNode focusNode;
  final FocusNode editorFocusNode;

  const EditorTitleField({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.focusNode,
    required this.editorFocusNode,
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
        hintStyle: TextStyle(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5
        ),
        filled: false,
        fillColor: Colors.transparent,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 36,
          fontWeight: FontWeight.w900,
          height: 1.3,
          letterSpacing: 0.5
      ),
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

  const EditorQuillArea({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.focusNode,
    required this.scrollController,
    required this.imageService,
  });

  @override
  State<EditorQuillArea> createState() => _EditorQuillAreaState();
}

class _EditorQuillAreaState extends State<EditorQuillArea> {
  bool _isImageSelected = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final viewModel = widget.viewModel;

    final defaultTextStyle = TextStyle(fontSize: 16, height: 1.8, color: theme.colorScheme.onSurface.withValues(alpha: 0.9), letterSpacing: 0.4);
    final listTextStyle = TextStyle(fontSize: 16, height: 1.25, color: theme.colorScheme.onSurface.withValues(alpha: 0.9), letterSpacing: 0.4);

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
        onLaunchUrl: (String? url) async {
          if (url == null || url.isEmpty) return;
          var parsedUrl = url.startsWith('http') ? url : 'https://$url';
          try {
            final uri = Uri.parse(parsedUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint('链接无法打开: $parsedUrl');
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
        customStyles: QuillStylesConfig.getStyles(theme),
      ),
    );
  }
}
