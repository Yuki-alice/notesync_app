import 'package:isar/isar.dart';
import '../../../models/tag.dart';
import '../../models/note.dart';

class TagRepository {
  final Isar _isar;

  TagRepository(this._isar);

  List<Tag> getAllTags() {
    return _isar.tags.where().sortByCreatedAtDesc().findAllSync();
  }

  Tag? getTagById(String id) {
    return _isar.tags.where().idEqualTo(id).findFirstSync();
  }

  Future<void> addTag(Tag tag) async {
    await _isar.writeTxn(() async {
      await _isar.tags.put(tag);
    });
  }

  Future<void> deleteTag(String id) async {
    await _isar.writeTxn(() async {
      await _isar.tags.where().idEqualTo(id).deleteAll();

      // 遍历删除笔记中关联的 TagId
      final affectedNotes = await _isar.notes.filter().tagIdsElementEqualTo(id).findAll();
      for (var note in affectedNotes) {
        final newTags = List<String>.from(note.tagIds)..remove(id);
        note.tagIds = newTags;
        note.version += 1;
        note.updatedAt = DateTime.now();
        await _isar.notes.put(note);
      }
    });
  }
}