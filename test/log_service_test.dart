import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/services/log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('日志落盘并可从内存缓冲读取', () async {
    LogService.reset();
    final dir = await Directory.systemTemp.createTemp('fortune_log_test');
    await LogService.init(logRoot: () async => dir);
    LogService.info('测试日志');
    LogService.error('测试异常', StateError('boom'));

    final logs = LogService.getRecentLogs();
    expect(logs.any((line) => line.contains('测试日志')), isTrue);
    expect(logs.any((line) => line.contains('测试异常')), isTrue);
    expect(LogService.logFilePath, contains(dir.path));

    final file = File(LogService.logFilePath);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('测试日志'));

    LogService.reset();
    await dir.delete(recursive: true);
  });

  test('初始化前的日志进入早期缓冲并在初始化后补写', () async {
    LogService.reset();
    LogService.info('早期日志');
    final dir = await Directory.systemTemp.createTemp('fortune_log_test');
    await LogService.init(logRoot: () async => dir);
    expect(File(LogService.logFilePath).readAsStringSync(), contains('早期日志'));
    LogService.reset();
    await dir.delete(recursive: true);
  });
}
