/// CPU 密集的音频合成任务：按平台选择执行方式。
library;

export 'synth_worker_io.dart'
    if (dart.library.js_interop) 'synth_worker_web.dart';
