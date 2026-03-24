import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/note.dart';
import '../../models/todo.dart';
import '../../models/category.dart';
import '../../models/tag.dart';

class SimpleDatabaseService {
  late Isar _isar;

  Isar get isar => _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open([
      NoteSchema,
      TodoSchema,
      CategorySchema,
      TagSchema,
    ], directory: dir.path);
  }
}
