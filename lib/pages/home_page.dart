import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/daily_challenge.dart';
import '../game/endless.dart';
import '../models/level.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import 'achievements_page.dart';
import 'game_page.dart';
import 'level_select_page.dart';
import 'settings_page.dart';
import 'widgets/home_hero.dart';
import 'widgets/home_start_panel.dart';
import 'widgets/home_top_bar.dart';
import 'widgets/rules_dialog.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openGame(BuildContext context, Level level) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => GamePage(level: level)));
  }

  void _openEndless(BuildContext context) {
    const run = EndlessRun();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GamePage(level: run.level, endless: run),
      ),
    );
  }

  void _openLevels(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LevelSelectPage()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  void _openAchievements(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AchievementsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final daily = DailyChallenge.of(DateTime.now());

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: sceneGradient(isDark)),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 900 && constraints.maxHeight >= 620;
              final horizontal = constraints.maxWidth >= 900 ? 40.0 : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      children: [
                        HomeTopBar(
                          coins: settings.coins,
                          darkMode: settings.darkMode,
                          onShowRules: () => showRulesDialog(context),
                          onToggleDarkMode: () =>
                              settings.setDarkMode(!settings.darkMode),
                          onOpenSettings: () => _openSettings(context),
                        ),
                        const SizedBox(height: 10),
                        if (wide)
                          Row(
                            children: [
                              const Expanded(child: HomeHero()),
                              const SizedBox(width: 44),
                              SizedBox(
                                width: 420,
                                child: _startPanel(
                                  context,
                                  settings: settings,
                                  daily: daily,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          const HomeHero(),
                          const SizedBox(height: 24),
                          _startPanel(
                            context,
                            settings: settings,
                            daily: daily,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'v${AppConstants.version} · 本地运行，无需联网',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _startPanel(
    BuildContext context, {
    required SettingsProvider settings,
    required DailyChallenge daily,
  }) => HomeStartPanel(
    settings: settings,
    daily: daily,
    onStart: (level) => _openGame(context, level),
    onStartDaily: () => _openGame(context, daily.level),
    onStartEndless: () => _openEndless(context),
    onOpenLevels: () => _openLevels(context),
    onOpenSettings: () => _openSettings(context),
    onOpenAchievements: () => _openAchievements(context),
  );
}
