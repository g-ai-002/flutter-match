import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/logic_rate.dart';
import '../game/match_controller.dart';
import 'board_component.dart';

/// Flame 游戏入口：棋盘组件铺满整个游戏区域。
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

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    final board = BoardComponent(
      controller: controller,
      darkMode: darkMode,
      logicRate: logicRate,
    );
    _board = board;
    _fit(board);
    await add(board);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final board = _board;
    if (board != null) _fit(board);
  }

  void _fit(BoardComponent board) {
    board
      ..size = size.clone()
      ..position = Vector2.zero();
  }
}
