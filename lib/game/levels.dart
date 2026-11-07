import '../models/level.dart';
import 'level_catalog.dart';

/// 关卡索引：查询、跳关等访问逻辑；关卡数据见 `level_catalog.dart`。
final List<Level> kLevels = buildLevelCatalog();

Level levelById(int id) => kLevels.firstWhere(
  (level) => level.id == id,
  orElse: () => kLevels.first,
);

Level? nextLevelOf(int id) {
  final index = kLevels.indexWhere((level) => level.id == id);
  if (index < 0 || index + 1 >= kLevels.length) return null;
  return kLevels[index + 1];
}
