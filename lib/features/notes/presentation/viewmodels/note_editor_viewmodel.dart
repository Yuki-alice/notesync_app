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
        if (isProMode) {
          _checkMarkdownShortcuts();
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
    final title = titleController.text.trim();
    final delta = quillController.document.toDelta();
    final buffer = StringBuffer();

    if (title.isNotEmpty) {
      buffer.writeln('# $title\n');
    }

    String currentLine = '';

    for (final op in delta.toList()) {
      if (op.data is String) {
        final text = op.data as String;
        final attrs = op.attributes ?? {};

        if (text == '\n') {
          _appendLineToMarkdown(buffer, currentLine, attrs);
          currentLine = '';
        } else if (text.contains('\n')) {
          final parts = text.split('\n');
          for (int i = 0; i < parts.length - 1; i++) {
            currentLine += _formatInlineMarkdown(parts[i], attrs);
            _appendLineToMarkdown(buffer, currentLine, attrs);
            currentLine = '';
          }
          currentLine += _formatInlineMarkdown(parts.last, attrs);
        } else {
          currentLine += _formatInlineMarkdown(text, attrs);
        }
      } else if (op.data is Map) {
        final dataMap = op.data as Map;
        if (dataMap.containsKey('image')) {
          final imagePath = dataMap['image'];
          currentLine += '\n![图片]($imagePath)\n';
        }
      }
    }

    if (currentLine.isNotEmpty) {
      _appendLineToMarkdown(buffer, currentLine, {});
    }

    return buffer.toString().trim();
  }

  String _formatInlineMarkdown(String text, Map<String, dynamic> attrs) {
    if (text.isEmpty) return text;
    String result = text;
    if (attrs['bold'] == true) result = '**$result**';
    if (attrs['italic'] == true) result = '*$result*';
    if (attrs['strike'] == true) result = '~~$result~~';
    if (attrs['code'] == true) result = '`$result`';
    return result;
  }

  void _appendLineToMarkdown(StringBuffer buffer, String lineText, Map<String, dynamic> blockAttrs) {
    if (blockAttrs['header'] != null) {
      final level = blockAttrs['header'] as int;
      buffer.writeln('${"#" * level} $lineText\n');
    } else if (blockAttrs['blockquote'] == true) {
      buffer.writeln('> $lineText\n');
    } else if (blockAttrs['list'] == 'bullet') {
      buffer.writeln('- $lineText');
    } else if (blockAttrs['list'] == 'ordered') {
      buffer.writeln('1. $lineText');
    } else if (blockAttrs['list'] == 'checked') {
      buffer.writeln('- [x] $lineText');
    } else if (blockAttrs['list'] == 'unchecked') {
      buffer.writeln('- [ ] $lineText');
    } else {
      buffer.writeln(lineText);
    }
  }

  void _checkMarkdownShortcuts() {
    if (_isAutoFormatting) return;

    final selection = quillController.selection;
    if (!selection.isCollapsed) return;

    final index = selection.baseOffset;
    if (index <= 0) return;

    final lastChar = quillController.document.getPlainText(index - 1, 1);
    if (lastChar != ' ') return;

    final text = quillController.document.toPlainText();
    int lineStart = 0;
    for (int i = index - 2; i >= 0; i--) {
      if (text[i] == '\n') {
        lineStart = i + 1;
        break;
      }
    }

    final textBeforeCursor = text.substring(lineStart, index);

    quill.Attribute? attributeToApply;
    int lengthToDelete = 0;

    if (textBeforeCursor == '# ') {
      attributeToApply = quill.Attribute.h1;
      lengthToDelete = 2;
    } else if (textBeforeCursor == '## ') {
      attributeToApply = quill.Attribute.h2;
      lengthToDelete = 3;
    } else if (textBeforeCursor == '### ') {
      attributeToApply = quill.Attribute.h3;
      lengthToDelete = 4;
    } else if (textBeforeCursor == '- ' || textBeforeCursor == '* ' || textBeforeCursor == '+ ') {
      attributeToApply = quill.Attribute.ul;
      lengthToDelete = 2;
    } else if (RegExp(r'^\d+\.\s$').hasMatch(textBeforeCursor)) {
      attributeToApply = quill.Attribute.ol;
      lengthToDelete = textBeforeCursor.length;
    } else if (textBeforeCursor == '[] ' || textBeforeCursor == '[ ] ') {
      attributeToApply = quill.Attribute.unchecked;
      lengthToDelete = textBeforeCursor.length;
    } else if (textBeforeCursor == '[x] ' || textBeforeCursor == '[X] ') {
      attributeToApply = quill.Attribute.checked;
      lengthToDelete = textBeforeCursor.length;
    } else if (textBeforeCursor == '< ') {
      attributeToApply = quill.Attribute.blockQuote;
      lengthToDelete = 2;
    }

    if (attributeToApply != null) {
      _isAutoFormatting = true;
      Future.microtask(() {
        quillController.document.delete(lineStart, lengthToDelete);
        quillController.formatText(lineStart, 0, attributeToApply!);
        quillController.updateSelection(
          TextSelection.collapsed(offset: index - lengthToDelete),
          quill.ChangeSource.local,
        );
        _isAutoFormatting = false;
      });
    }
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