import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/log_service.dart';
import 'services/logging_init.dart';
import 'services/music_service.dart';
import 'services/storage_service.dart';
import 'utils/constants.dart';
import 'utils/window_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LogService.error('Flutter 异常', details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error('未捕获异常', error, stack);
    return true;
  };

  await setupDesktopWindow();
  await initLogging();

  final storage = await StorageService.instance;
  LogService.info('应用启动: ${AppConstants.appName} v${AppConstants.version}');
  // 音频合成延后到首帧之后，避免和界面初始化抢主线程。
  MusicService.enabled = storage.musicEnabled;

  runApp(FortuneMatchApp(storage: storage));
}
