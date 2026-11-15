import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../utils/formatters.dart';

/// 日志服务：内存环形缓冲 + 按天文件落盘。
///
/// 初始化前的日志先进入早期缓冲，初始化后补写；日志目录不可用时降级为内存模式。
/// 日志行先进待写队列，合并后异步追加到文件：写盘不走 UI 线程上的同步 IO，
/// 连续多条日志只触发一次文件写入，错误日志则立即刷盘。
class LogService {
  static LogService? _instance;
  static final List<String> _earlyBuffer = [];
  final List<String> _buffer = [];
  final List<String> _pending = [];
  Timer? _flushTimer;
  Future<void>? _writing;

  Directory? _logDir;
  File? _logFile;
  DateTime? _logDate;
  bool _initialized = false;
  DateTime Function() _now = DateTime.now;

  static const int _maxBufferLines = 2000;
  static const int _maxEarlyLines = 500;
  static const int _maxFileSize = 5 * 1024 * 1024;
  static const int _maxRetentionDays = 7;

  /// 批量刷盘间隔：既不让日志长时间停留在内存，也不为每行日志各写一次文件。
  static const Duration flushDelay = Duration(milliseconds: 120);

  /// 合并后的文件写入次数，供测试断言多条日志只落盘一批。
  @visibleForTesting
  static int flushBatches = 0;

  LogService._();

  static Future<void> init({
    Future<Directory> Function()? logRoot,
    DateTime Function()? clock,
  }) async {
    _instance ??= LogService._();
    await _instance!._init(logRoot, clock);
  }

  /// 仅用于测试。
  static void reset() {
    _instance?._flushTimer?.cancel();
    _instance?._pending.clear();
    _instance = null;
    _earlyBuffer.clear();
  }

  /// 立即把尚未落盘的日志写入文件（退出、崩溃兜底或测试使用）。
  static Future<void> flush() async {
    final inst = _instance;
    if (inst == null) return;
    await inst._flushNow();
    // 上一批还在写时新到的日志，再补一次。
    if (inst._pending.isNotEmpty) await inst._flushNow();
  }

  Future<void> _init(
    Future<Directory> Function()? logRoot,
    DateTime Function()? clock,
  ) async {
    if (_initialized) return;
    if (clock != null) _now = clock;
    if (logRoot != null) {
      try {
        _logDir = await logRoot();
      } catch (e) {
        debugPrint('[LogService] 日志目录不可用，降级为内存日志: $e');
      }
    }
    _logFile = await _openTodayFile();
    _initialized = true;
    if (_logFile != null) {
      _logDate = _now();
      await _cleanOldLogs();
    }
    if (_earlyBuffer.isNotEmpty) {
      for (final line in _earlyBuffer) {
        _buffer.add(line);
        _pending.add(line);
      }
      _earlyBuffer.clear();
    }
    _write(
      'INFO',
      '==== LogService 已初始化, 日志文件: ${_logFile?.path ?? '内存模式'} ====',
    );
    // 早期日志在初始化完成时就落盘，启动后的排查不依赖后续刷新。
    await _flushNow();
  }

  static String get logFilePath => _instance?._logFile?.path ?? '';

  static void info(String message) => _log('INFO', message);

  static void warning(String message) => _log('WARN', message);

  static void error(String message, [Object? error, StackTrace? stack]) {
    _log('ERROR', error != null ? '$message | $error' : message);
    if (stack != null) _log('ERROR', stack.toString());
    // 错误日志可能对应一次崩溃，立刻刷盘，不等待批量定时器。
    final flush = _instance?._flushNow();
    if (flush != null) unawaited(flush);
  }

  static void _log(String level, String message) {
    final inst = _instance;
    if (inst == null || !inst._initialized) {
      final line = formatLogLine(
        inst?._now() ?? DateTime.now(),
        level,
        message,
      );
      _earlyBuffer.add(line);
      if (_earlyBuffer.length > _maxEarlyLines) _earlyBuffer.removeAt(0);
      return;
    }
    inst._write(level, message);
  }

  void _write(String level, String message) {
    final line = formatLogLine(_now(), level, message);
    _buffer.add(line);
    if (_buffer.length > _maxBufferLines) _buffer.removeAt(0);
    _pending.add(line);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_flushTimer != null || _writing != null) return;
    _flushTimer = Timer(flushDelay, () {
      _flushTimer = null;
      unawaited(_flushNow());
    });
  }

  /// 把队列里的日志一次性追加到当天文件；写入串行执行，避免多批交错。
  Future<void> _flushNow() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final running = _writing;
    if (running != null) return running;
    if (_pending.isEmpty) return Future.value();
    final future = _drain();
    _writing = future;
    return future.whenComplete(() {
      if (identical(_writing, future)) _writing = null;
    });
  }

  Future<void> _drain() async {
    try {
      while (_pending.isNotEmpty) {
        final chunk = _pending.join('\n');
        _pending.clear();
        await _refreshLogFile();
        final file = _logFile;
        if (file == null) continue;
        await file.writeAsString('$chunk\n', mode: FileMode.append);
        flushBatches++;
      }
    } catch (_) {
      // 磁盘不可写时保留内存缓冲，界面上仍能查看最近日志。
    }
  }

  Future<void> _refreshLogFile() async {
    final dir = _logDir;
    if (dir == null) return;
    final now = _now();
    final current = _logDate;
    final needSwitch =
        current == null ||
        current.year != now.year ||
        current.month != now.month ||
        current.day != now.day;
    if (needSwitch) {
      final file = await _openTodayFile();
      if (file != null) {
        _logFile = file;
        _logDate = now;
        await _cleanOldLogs();
      }
      return;
    }
    await _rotateIfNeeded();
  }

  Future<File?> _openTodayFile() async {
    final dir = _logDir;
    if (dir == null) return null;
    try {
      final now = _now();
      final file = File(
        '${dir.path}${Platform.pathSeparator}app_${formatDateKey(now)}.log',
      );
      if (!await file.exists()) await file.create(recursive: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<void> _rotateIfNeeded() async {
    final file = _logFile;
    if (file == null) return;
    try {
      if (!await file.exists() || await file.length() < _maxFileSize) return;
      final originalPath = file.path;
      final parent = file.parent;
      final baseName = file.uri.pathSegments.last.replaceAll('.log', '');
      var index = 1;
      File backup;
      do {
        backup = File(
          '${parent.path}${Platform.pathSeparator}${baseName}_$index.log',
        );
        index++;
      } while (await backup.exists());
      await file.rename(backup.path);
      final fresh = File(originalPath);
      if (!await fresh.exists()) await fresh.create();
      _logFile = fresh;
    } catch (_) {}
  }

  Future<void> _cleanOldLogs() async {
    final dir = _logDir;
    if (dir == null) return;
    try {
      final cutoff = _now().subtract(const Duration(days: _maxRetentionDays));
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('app_') || !name.endsWith('.log')) continue;
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// 最近日志（内存缓冲，含尚未落盘的早期日志）。
  static List<String> getRecentLogs([int lines = 200]) {
    final inst = _instance;
    final all = <String>[..._earlyBuffer, if (inst != null) ...inst._buffer];
    if (all.length <= lines) return all;
    return all.sublist(all.length - lines);
  }
}
