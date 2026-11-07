/// 全局格式化工具。
library;

String pad2(int value) => value.toString().padLeft(2, '0');

/// `yyyyMMdd`，用于日志文件名。
String formatDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${pad2(date.month)}${pad2(date.day)}';

/// 日期键前后平移若干天，用于判断每日挑战是否连续。
String shiftDateKey(String dateKey, int days) {
  final date = DateTime(
    int.parse(dateKey.substring(0, 4)),
    int.parse(dateKey.substring(4, 6)),
    int.parse(dateKey.substring(6, 8)),
  );
  return formatDateKey(date.add(Duration(days: days)));
}

/// `HH:mm:ss.SSS`，日志行首时间戳。
String formatLogTimestamp(DateTime time) =>
    '${pad2(time.hour)}:${pad2(time.minute)}:${pad2(time.second)}.'
    '${time.millisecond.toString().padLeft(3, '0')}';

String formatLogLine(DateTime time, String level, String message) =>
    '[${formatLogTimestamp(time)}][$level] $message';
