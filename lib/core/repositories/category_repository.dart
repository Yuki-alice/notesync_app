import 'package:isar/isar.dart';
import '../../../models/category.dart';
import '../../models/note.dart';

class CategoryRepository {
  final Isar _isar;

  CategoryRepository(this._isar);

  List<Category> getAllCategories() {
    return _isar.categorys.where().sortBySortOrder().findAllSync();
  }

  Category? getCategoryById(String id) {
    return _isar.categorys.where().idEqualTo(id).findFirstSync();
  }

  Future<void> addCategory(Category category) async {
    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
  }

  Future<void> updateCategory(Category category) async {
    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
  }

  Future<void> deleteCategory(String id) async {
    await _isar.writeTxn(() async {
      // 物理删除本地分类
      await _isar.categorys.where().idEqualTo(id).deleteAll();

      // 注意：由于是关系型数据库，分类被删后，属于该分类的笔记需要将 categoryId 置空
      final affectedNotes = await _isar.notes.filter().categoryIdEqualTo(id).findAll();
      for (var note in affectedNotes) {
        note.categoryId = null;
        note.version += 1;
        note.updatedAt = DateTime.now();
        await _isar.notes.put(note);
      }
    });
  }
}