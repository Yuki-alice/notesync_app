import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../core/services/privacy_service.dart';
import '../../../../core/utils/privacy_note_utils.dart';
import '../../../../models/note.dart';

import '../../utils/markdown_export_service.dart';
import '../../utils/markdown_shortcut_service.dart';

String _encodeDeltaInBackground(List<dynamic> deltaJson) {
  return jsonEncode(deltaJson);
}

class NoteEditorViewModel extends ChangeNotifier {
  final NotesProvider notesProvider;
  final bool isProMode;
  final bool isPrivate;

  late quill.QuillController quillController;
  late TextEditingController titleController;

  // 🌟 修正为 ID
  List<String> tagIds = [];
  String? categoryId;

  bool isDirty = false;
  int wordCount = 0;

  Note? _editingNote;
  final ImageStorageService _imageService = ImageStorageService();
  Timer? _autoSaveTimer;

  bool _isAutoFormatting = false;
  bool _isReadOnly = false;
  bool get isReadOnly => _isReadOnly;

  NoteEditorViewModel({
    Note? note,
    required this.notesProvider,
    this.isProMode = false,
    this.isPrivate = false,
  }) {
    _editingNote = note;
    _initControllers();
  }

  void _initControllers() {
    // 🌟 如果是隐私笔记，解密标题显示
    String title = _editingNote?.title ?? '';
    if (title.startsWith('AES_V1::')) {
      title = PrivacyService().decryptText(title);
      // 如果解密失败（包含 🔒 或 ❌ 标记），显示占位符
      if (title.contains('🔒') || title.contains('❌')) {
        title = '🔒 私密笔记';
      }
    }
    titleController = TextEditingController(text: title);
    // 🌟 修正为 ID
    tagIds = _editingNote?.tagIds.toList() ?? [];
    categoryId = _editingNote?.categoryId;

    try {
      if (_editingNote != null && _editingNote!.content.isNotEmpty) {
        // 🌟 如果是隐私笔记，解密内容
        String content = _editingNote!.content;
        if (content.startsWith('AES_V1::')) {
          content = PrivacyService().decryptText(content);
          // 如果解密失败（包含 🔒 或 ❌ 标记），显示占位文档
          if (content.contains('🔒') || content.contains('❌')) {
            content = '[{"insert":"🔒 私密内容，请解锁后查看\\n"}]';
          }
        }
        
        if (_editingNote!.isRichText) {
          final jsonContent = jsonDecode(content);
          quillController = quill.QuillController(
            document: quill.Document.fromJson(jsonContent),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          final doc = quill.Document()..insert(0, content);
          quillController = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } else {
        quillController = quill.QuillController.basic();
      }
    } catch (e) {
      quillController = quill.QuillController.basic();
    }

    _updateWordCount();
    titleController.addListener(_markAsDirty);

    quillController.document.changes.listen((event) {
      _updateWordCount();
      if (event.source == quill.ChangeSource.local) {
        _markAsDirty();

        if (isProMode && !_isAutoFormatting) {
          _isAutoFormatting = true;
          final didFormat = MarkdownShortcutService.format(quillController);
          if (didFormat) {
            Future.microtask(() => _isAutoFormatting = false);
          } else {
            _isAutoFormatting = false;
          }
        }
      }
    });
  }

  void toggleReadOnly() {
    _isReadOnly = !_isReadOnly;
    quillController.readOnly = _isReadOnly;
    notifyListeners();
  }

  String generateMarkdownContent() {
    return MarkdownExportService.generate(titleController.text.trim(), quillController);
  }

  void _updateWordCount() {
    wordCount = quillController.document.toPlainText().trim().length;
    notifyListeners();
  }

  void _markAsDirty() {
    if (!isDirty) {
      isDirty = true;
      notifyListeners();
    }
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), () {
      if (isDirty) saveNote();
    });
  }

  Future<void> pickAndInsertImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File file = File(image.path);
      final String localPath = await _imageService.saveImage(file);

      var index = quillController.selection.baseOffset;
      final length = quillController.document.length;
      if (index < 0) index = length - 1;

      quillController.document.insert(index, quill.BlockEmbed.image(localPath));
      quillController.document.insert(index + 1, '\n');

      quillController.updateSelection(TextSelection.collapsed(offset: index + 2), quill.ChangeSource.local);
      _markAsDirty();
    }
  }

  Future<void> saveNote() async {
    if (!isDirty && _editingNote != null) return;

    final title = titleController.text.trim();
    if (_editingNote == null && title.isEmpty && quillController.document.isEmpty()) return;

    final deltaJsonList = quillController.document.toDelta().toJson();
    final contentJson = await compute(_encodeDeltaInBackground, deltaJsonList);

    // 处理隐私笔记加密
    String finalTitle = title.isEmpty ? '未命名笔记' : title;
    String finalContent = contentJson;
    bool finalIsPrivate = isPrivate;

    if (isPrivate && PrivacyService().isUnlocked) {
      // 加密标题和内容
      finalTitle = PrivacyService().encryptText(finalTitle);
      finalContent = PrivacyService().encryptText(finalContent);
    }

    if (_editingNote == null) {
      final newNote = await notesProvider.addNote(
          title: finalTitle,
          content: finalContent,
          tagIds: tagIds,
          categoryId: categoryId,
          isPrivate: finalIsPrivate
      );
      _editingNote = newNote;
    } else {
      // 如果原笔记是隐私笔记，保持隐私状态
      final shouldEncrypt = _editingNote!.isPrivate || isPrivate;
      
      final updatedNote = _editingNote!.copyWith(
          title: shouldEncrypt && PrivacyService().isUnlocked 
              ? PrivacyService().encryptText(title.isEmpty ? '未命名笔记' : title)
              : title.isEmpty ? '未命名笔记' : title,
          content: shouldEncrypt && PrivacyService().isUnlocked
              ? PrivacyService().encryptText(contentJson)
              : contentJson,
          tagIds: tagIds,
          categoryId: categoryId,
          isPrivate: shouldEncrypt,
          version: _editingNote!.version + 1,
          updatedAt: DateTime.now());
      await notesProvider.updateNote(updatedNote);
      _editingNote = updatedNote;
    }

    isDirty = false;
    notifyListeners();
  }

  // 🌟 方法名和参数同步修正
  void addTag(String tagId) {
    if (tagId.isNotEmpty && !tagIds.contains(tagId)) {
      tagIds.add(tagId);
      _markAsDirty();
    }
  }

  void removeTag(String tagId) {
    tagIds.remove(tagId);
    _markAsDirty();
  }

  void setCategoryId(String? newCategoryId) {
    categoryId = newCategoryId;
    _markAsDirty();
  }

  void undo() { if (quillController.hasUndo) quillController.undo(); }
  void redo() { if (quillController.hasRedo) quillController.redo(); }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    quillController.dispose();
    titleController.dispose();
    super.dispose();
  }

  Note? get currentNote => _editingNote;
}