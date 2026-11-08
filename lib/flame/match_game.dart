import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/logic_rate.dart';
import '../game/match_controller.dart';
import 'board_component.dart';

/// Flame 游戏入口：棋盘组件铺满整个游戏区域。
///
/// 棋盘空闲（无动画、无粒子、无提示脉冲且贴图预热完成）时暂停引擎循环，
/// 静止画面保持最后一帧，CPU 与电量不再被空转的 ticker 消耗；
/// 控制器通知、窗口尺寸变化或启动预热到点后再恢复循环补画一帧。
class MatchGame extends FlameGame {
  MatchGame({
    required this.controller,
    required this.darkMode,
    this.logicRate = LogicRate.hz60,
  });

  final MatchController controller;
  final ValueListenable<bool> darkMode;
  final LogicRate logicRate;
  BoardComponent? _board;
  bool _idlePaused = false;

  /// 是否因空闲而暂停了引擎循环，供测试断言。
  @visibleForTesting
  bool get idlePaused => _idlePaused;

  /// 当前挂载的棋盘；拆除后为 null，供测试断言离场清理。
  @visibleForTesting
  BoardComponent? get board => _board;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(
      controller: controller,
      darkMode: darkMode,
      logicRate: logicRate,
    );
    board.onActivityChanged = _handleActivity;
    _board = board;
    _fit(board);
    await add(board);
  }

  @override
  void onRemove() {
    shutdown();
    super.onRemove();
  }

  /// 停止引擎循环并拆除棋盘：离开对局页时调用，避免残留 ticker、定时器与监听。
  void shutdown() {
    pauseEngine();
    _board?.teardown();
    _board = null;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final board = _board;
    if (board != null) {
      _fit(board);
      _wakeUp();
    }
  }

  void _fit(BoardComponent board) {
    board
      ..size = size.clone()
      ..position = Vector2.zero();
  }

  /// 供测试直接驱动空闲开关，不依赖 Flame 渲染盒是否已布局。
  @visibleForTesting
  void handleActivity(bool active) => _handleActivity(active);

  void _handleActivity(bool active) {
    if (active) {
      _wakeUp();
    } else if (!_idlePaused) {
      _idlePaused = true;
      pauseEngine();
    }
  }

  void _wakeUp() {
    if (!_idlePaused) return;
    _idlePaused = false;
    resumeEngine();
  }
}
