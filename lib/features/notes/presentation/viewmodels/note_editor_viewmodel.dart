import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';

import '../../utils/markdown_export_service.dart';
import '../../utils/markdown_shortcut_service.dart';

String _encodeDeltaInBackground(List<dynamic> deltaJson) {
  return jsonEncode(deltaJson);
}

class NoteEditorViewModel extends ChangeNotifier {
  final NotesProvider notesProvider;
  final bool isProMode;

  late quill.QuillController quillController;
  late TextEditingController titleController;

  List<String> tags = [];
  String? category;
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
  }) {
    _editingNote = note;
    _initControllers();
  }

  void _initControllers() {
    titleController = TextEditingController(text: _editingNote?.title ?? '');
    tags = _editingNote?.tags.toList() ?? [];
    category = _editingNote?.category;

    try {
      if (_editingNote != null && _editingNote!.content.isNotEmpty) {
        if (_editingNote!.isRichText) {
          final jsonContent = jsonDecode(_editingNote!.content);
          quillController = quill.QuillController(
            document: quill.Document.fromJson(jsonContent),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          final doc = quill.Document()..insert(0, _editingNote!.content);
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
          // 🟢 极度精简：调用专属服务类进行格式化检测
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

  // 🟢 极度精简：调用专属导出服务
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

    if (_editingNote == null) {
      final newNote = await notesProvider.addNote(
          title: title.isEmpty ? '未命名笔记' : title,
          content: contentJson,
          tags: tags,
          category: category);
      _editingNote = newNote;
    } else {
      final updatedNote = _editingNote!.copyWith(
          title: title,
          content: contentJson,
          tags: tags,
          category: category,
          updatedAt: DateTime.now());
      await notesProvider.updateNote(updatedNote);
      _editingNote = updatedNote;
    }

    isDirty = false;
    notifyListeners();
  }

  void addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !tags.contains(trimmed)) {
      tags.add(trimmed);
      _markAsDirty();
    }
  }

  void removeTag(String tag) {
    tags.remove(tag);
    _markAsDirty();
  }

  void setCategory(String? newCategory) {
    category = newCategory;
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