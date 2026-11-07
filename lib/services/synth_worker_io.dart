import 'dart:isolate';

/// 在后台 isolate 中执行合成，避免阻塞首帧；失败时退回当前 isolate。
Future<T> runSynthTask<T>(T Function() task) async {
  try {
    return await Isolate.run(task);
  } catch (_) {
    return task();
  }
}
