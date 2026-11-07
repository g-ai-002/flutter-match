/// 棋盘动画时长（秒）：集中管理交换、消除、弹入与下落的节奏。
class BoardTimings {
  BoardTimings._();

  static const double swap = 0.14;
  static const double clear = 0.26;
  static const double pop = 0.2;
  static const double fallBase = 0.1;
  static const double fallPerCell = 0.045;
  static const double fallMax = 0.4;
  static const double spark = 0.42;
}
