import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/log_service.dart';
import 'services/logging_init.dart';
import 'services/music_service.dart';
import 'services/storage_service.dart';
import 'utils/constants.dart';
import 'utils/system_ui.dart';
import 'utils/window_setup.dart';

Future<void> main() async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.error('Flutter 异常', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error('未捕获异常', error, stack);
    return true;
  };

  // 日志落盘、窗口设置与本地存储互不依赖，并行启动，首帧只等最慢的一步。
  // 日志目录的磁盘探测不参与等待，早期日志先进内存缓冲，就绪后补写。
  final logging = initLogging();
  final (_, storage) = await (
    setupDesktopWindow(),
    StorageService.instance,
  ).wait;
  unawaited(logging);

  // Android 全屏沉浸：首页、设置页与对局页共用，状态栏不占用可用空间。
  applyAppChrome();

  LogService.info(
    '应用启动: ${AppConstants.appName} v${AppConstants.version}，'
    '初始化耗时 ${startup.elapsedMilliseconds}ms（日志落盘已异步进行）',
  );
  // 音频合成延后到首帧之后，避免和界面初始化抢主线程。
  MusicService.enabled = storage.musicEnabled;

  runApp(FortuneMatchApp(storage: storage));
}
