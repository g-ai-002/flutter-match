import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'providers/settings_provider.dart';
import 'services/music_service.dart';
import 'services/sound_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'utils/system_ui.dart';

class FortuneMatchApp extends StatefulWidget {
  const FortuneMatchApp({super.key, required this.storage});

  final StorageService storage;

  @override
  State<FortuneMatchApp> createState() => _FortuneMatchAppState();
}

class _FortuneMatchAppState extends State<FortuneMatchApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首帧之后再合成音频，音效与音乐都不占用启动时间。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Web 需要用户手势才能初始化音频，首次点击页面时再启动。
      if (kIsWeb) return;
      unawaited(SoundService.init());
      unawaited(MusicService.start());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        MusicService.resumeForLifecycle();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        MusicService.pauseForLifecycle();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    String? fontFamily;
    if (kIsWeb) {
      fontFamily = kWebFontFamily;
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      fontFamily = 'Microsoft YaHei UI';
    }
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(widget.storage),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          SkinState.active.select(settings.skin);
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: buildLightTheme(fontFamily: fontFamily),
            darkTheme: buildDarkTheme(fontFamily: fontFamily),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN')],
            locale: const Locale('zh', 'CN'),
            // Web 首次点击用于解除浏览器的自动播放限制。
            builder: (context, child) => SystemUiOverlay(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: kIsWeb
                    ? (_) {
                        SoundService.retryOnInteraction();
                        MusicService.retryOnInteraction();
                      }
                    : null,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
