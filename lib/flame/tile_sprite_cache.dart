import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/material.dart';

import '../models/tile.dart';
import '../theme/tile_art.dart';

/// 棋子与冰层的贴图缓存：按格子尺寸缓存 Picture，尺寸变化时才重绘。
class TileSpriteCache {
  final TileGlyphCache _glyphs = TileGlyphCache();
  final Map<String, Picture> _tiles = {};
  final Map<int, Picture> _ice = {};
  int _cellKey = 0;

  /// 某类棋子的贴图，[cell] 为当前格子边长。
  Picture tile(TileType type, SpecialType special, double cell) {
    _syncCell(cell);
    final key = '${type.name}|${special.name}';
    return _tiles.putIfAbsent(key, () {
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
      paintIce(
        Canvas(recorder),
        Rect.fromLTWH(0, 0, cell, cell),
        layers,
      );
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

  void dispose() {
    for (final picture in _tiles.values) {
      picture.dispose();
    }
    for (final picture in _ice.values) {
      picture.dispose();
    }
    _tiles.clear();
    _ice.clear();
    _glyphs.clear();
    _cellKey = 0;
  }
}
