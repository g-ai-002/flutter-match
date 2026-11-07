/// Web 没有 isolate，直接在事件循环中执行，合成量已按平台限制。
Future<T> runSynthTask<T>(T Function() task) async => task();
