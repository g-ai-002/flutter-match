import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../theme/tile_art.dart';

/// 棋子与冰层的贴图缓存：按格子尺寸缓存 Picture，尺寸变化时才重绘。
///
/// 键使用整数，避免每帧为每枚棋子拼接字符串。
class TileSpriteCache {
  final TileGlyphCache _glyphs = TileGlyphCache();
  final Map<int, Picture> _tiles = {};
  final Map<int, Picture> _ice = {};
  int _cellKey = 0;

  static int _tileKey(TileType type, SpecialType special) =>
      type.index * SpecialType.values.length + special.index;

  /// 某类棋子的贴图，[cell] 为当前格子边长。
  Picture tile(TileType type, SpecialType special, double cell) {
    _syncCell(cell);
    return _tiles.putIfAbsent(_tileKey(type, special), () {
      final recorder = PictureRecorder();
      paintTile(
        Canvas(recorder),
        Rect.fromLTWH(0, 0, cell, cell),
        type,
        special,
        _glyphs,
      );
      return recorder.endRecording();
    });
  }

  /// 某层数冰面的贴图，[cell] 为当前格子边长。
  Picture ice(int layers, double cell) {
    _syncCell(cell);
    return _ice.putIfAbsent(layers, () {
      final recorder = PictureRecorder();
      paintIce(Canvas(recorder), Rect.fromLTWH(0, 0, cell, cell), layers);
      return recorder.endRecording();
    });
  }

  /// 格子尺寸变化超过 1/4 像素时重建全部贴图与文字排版。
  void _syncCell(double cell) {
    final key = (cell * 4).round();
    if (key == _cellKey) return;
    dispose();
    _cellKey = key;
  }

  /// 丢弃全部贴图但保留当前格子尺寸，下一次取图时按新字体状态重录。
  void invalidate() {
    for (final picture in _tiles.values) {
      picture.dispose();
    }
    for (final picture in _ice.values) {
      picture.dispose();
    }
    _tiles.clear();
    _ice.clear();
    _glyphs.clear();
  }

  void dispose() {
    invalidate();
    _cellKey = 0;
  }
}
