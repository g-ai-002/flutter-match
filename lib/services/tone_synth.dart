import 'dart:math' as math;
import 'dart:typed_data';

/// 音效采样率：消除类短音效用 22.05 kHz 足够，数据量约为 44.1 kHz 的一半。
const int kSynthSampleRate = 22050;

/// 单枚乐音：正弦基频叠加二、三次谐波，可混入噪声模拟撞击与碎裂。
class SynthNote {
  const SynthNote({
    required this.frequency,
    required this.start,
    required this.duration,
    this.gain = 0.5,
    this.noise = 0,
    this.damp = 3.2,
    this.slide = 0,
  });

  /// 基频（Hz）。
  final double frequency;

  /// 相对整段音效的起始时间（秒）。
  final double start;

  /// 持续时长（秒）。
  final double duration;

  /// 音量，0 到 1。
  final double gain;

  /// 混入的噪声比例，用于表现碎裂与撞击。
  final double noise;

  /// 指数衰减速度，越大收得越快。
  final double damp;

  /// 频率滑音比例：结束时频率为 `frequency * (1 + slide)`。
  final double slide;
}

/// 纯 Dart 音效合成：把若干乐音渲染成 16 位单声道 WAV 字节。
///
/// 音效全部在运行时生成，代码仓库与安装包都不携带音频文件。
Uint8List synthesizeWav(
  List<SynthNote> notes, {
  int sampleRate = kSynthSampleRate,
}) {
  const tailSeconds = 0.05;
  final seconds = notes.fold<double>(
    0,
    (longest, note) => math.max(longest, note.start + note.duration),
  );
  final totalSamples = ((seconds + tailSeconds) * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(20261107);

  for (final note in notes) {
    final offset = (note.start * sampleRate).round();
    final count = (note.duration * sampleRate).round();
    final attack = math.max(1, (0.003 * sampleRate).round());
    final release = math.max(1, (0.008 * sampleRate).round());
    final gain = note.gain / 1.5;
    var phase = 0.0;
    for (var i = 0; i < count; i++) {
      final index = offset + i;
      if (index >= totalSamples) break;
      final progress = i / count;
      final envelope =
          math.min(1, i / attack) *
          math.min(1, (count - i) / release) *
          math.exp(-note.damp * progress);
      final frequency = note.frequency * (1 + note.slide * progress);
      phase += 2 * math.pi * frequency / sampleRate;
      final tone =
          math.sin(phase) +
          0.32 * math.sin(2 * phase) +
          0.12 * math.sin(3 * phase);
      final hit = note.noise * (random.nextDouble() * 2 - 1);
      mix[index] += envelope * (tone * gain + hit);
    }
  }

  return _encodePcm(mix, sampleRate);
}

/// 背景音乐采样率与循环长度：五声音阶拨弦，16 秒一循环。
const int kMusicSampleRate = 16000;
const double kMusicLoopSeconds = 16;

class _PluckNote {
  const _PluckNote({
    required this.start,
    required this.frequency,
    required this.duration,
    this.gain = 0.4,
    this.damp = 1.4,
  });

  final double start;
  final double frequency;
  final double duration;
  final double gain;
  final double damp;
}

/// C 宫五声音阶的欢快小调，主旋律与低音铺底交替。
const List<_PluckNote> _musicNotes = [
  // 低音铺底：每两小节换一次根音。
  _PluckNote(start: 0, frequency: 130.81, duration: 4.2, gain: 0.26, damp: 0.7),
  _PluckNote(start: 4, frequency: 174.61, duration: 4.2, gain: 0.24, damp: 0.7),
  _PluckNote(start: 8, frequency: 196.00, duration: 4.2, gain: 0.24, damp: 0.7),
  _PluckNote(start: 12, frequency: 146.83, duration: 4.2, gain: 0.26, damp: 0.7),
  // 主旋律：第一句上行。
  _PluckNote(start: 0.10, frequency: 523.25, duration: 0.9, gain: 0.44),
  _PluckNote(start: 0.55, frequency: 587.33, duration: 0.9, gain: 0.42),
  _PluckNote(start: 1.00, frequency: 659.25, duration: 1.0, gain: 0.46),
  _PluckNote(start: 1.60, frequency: 783.99, duration: 1.2, gain: 0.48),
  _PluckNote(start: 2.40, frequency: 659.25, duration: 0.9, gain: 0.42),
  _PluckNote(start: 2.85, frequency: 587.33, duration: 0.9),
  _PluckNote(start: 3.30, frequency: 523.25, duration: 1.4, gain: 0.44),
  // 第二句：围绕徵音展开。
  _PluckNote(start: 4.10, frequency: 587.33, duration: 0.9, gain: 0.42),
  _PluckNote(start: 4.55, frequency: 698.46, duration: 0.9, gain: 0.44),
  _PluckNote(start: 5.00, frequency: 880.00, duration: 1.2, gain: 0.46),
  _PluckNote(start: 5.70, frequency: 783.99, duration: 1.0, gain: 0.42),
  _PluckNote(start: 6.25, frequency: 698.46, duration: 0.9),
  _PluckNote(start: 6.70, frequency: 587.33, duration: 1.2, gain: 0.42),
  // 第三句：高音点缀。
  _PluckNote(start: 8.10, frequency: 783.99, duration: 0.8, gain: 0.46),
  _PluckNote(start: 8.50, frequency: 880.00, duration: 0.8, gain: 0.46),
  _PluckNote(start: 8.90, frequency: 1046.50, duration: 1.2, gain: 0.48),
  _PluckNote(start: 9.55, frequency: 880.00, duration: 0.9, gain: 0.42),
  _PluckNote(start: 10.00, frequency: 783.99, duration: 0.9, gain: 0.42),
  _PluckNote(start: 10.45, frequency: 698.46, duration: 1.4, gain: 0.44),
  // 第四句：回落收束。
  _PluckNote(start: 12.10, frequency: 659.25, duration: 0.9, gain: 0.44),
  _PluckNote(start: 12.55, frequency: 587.33, duration: 0.9, gain: 0.42),
  _PluckNote(start: 13.00, frequency: 523.25, duration: 1.0, gain: 0.44),
  _PluckNote(start: 13.65, frequency: 587.33, duration: 1.0),
  _PluckNote(start: 14.20, frequency: 523.25, duration: 1.6, gain: 0.42),
];

/// 合成背景音乐：古筝质感的拨弦叠加低音，首尾淡入淡出后无缝循环。
Uint8List synthesizeMusicWav({int sampleRate = kMusicSampleRate}) {
  final totalSamples = (kMusicLoopSeconds * sampleRate).round();
  final mix = Float64List(totalSamples);
  final random = math.Random(20261108);
  for (final note in _musicNotes) {
    final offset = (note.start * sampleRate).round();
    final count = math.min(
      (note.duration * sampleRate).round(),
      totalSamples - offset,
    );
    final attack = math.max(1, (0.004 * sampleRate).round());
    for (var i = 0; i < count; i++) {
      final time = i / sampleRate;
      final envelope = math.min(1, i / attack) * math.exp(-note.damp * time);
      final phase = 2 * math.pi * note.frequency * time;
      final tone =
          math.sin(phase) +
          0.34 * math.sin(2.002 * phase) +
          0.14 * math.sin(3.006 * phase) +
          0.05 * math.sin(4.011 * phase);
      final pick = (random.nextDouble() * 2 - 1) * 0.16 * math.exp(-70 * time);
      mix[offset + i] += envelope * note.gain * (tone * 0.42 + pick);
    }
  }

  var peak = 0.0;
  for (final value in mix) {
    final magnitude = value.abs();
    if (magnitude > peak) peak = magnitude;
  }
  final scale = peak > 0 ? 0.78 / peak : 1.0;
  final edge = (0.025 * sampleRate).round();
  for (var i = 0; i < totalSamples; i++) {
    final fadeIn = i < edge ? i / edge : 1.0;
    final fadeOut = i >= totalSamples - edge ? (totalSamples - i) / edge : 1.0;
    mix[i] *= scale * fadeIn * fadeOut;
  }
  return _encodePcm(mix, sampleRate);
}

/// 把 [-1,1] 的浮点混音编码为 16 位单声道 WAV。
Uint8List _encodePcm(Float64List mix, int sampleRate) {
  final totalSamples = mix.length;
  final data = ByteData(44 + totalSamples * 2);
  _writeAscii(data, 0, 'RIFF');
  data.setUint32(4, 36 + totalSamples * 2, Endian.little);
  _writeAscii(data, 8, 'WAVE');
  _writeAscii(data, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  _writeAscii(data, 36, 'data');
  data.setUint32(40, totalSamples * 2, Endian.little);

  for (var i = 0; i < totalSamples; i++) {
    final sample = (mix[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

void _writeAscii(ByteData data, int offset, String text) {
  for (var i = 0; i < text.length; i++) {
    data.setUint8(offset + i, text.codeUnitAt(i));
  }
}
