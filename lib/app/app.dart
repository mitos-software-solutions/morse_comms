import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/decoder/ui/decoder_screen.dart';
import '../features/encoder/ui/encoder_screen.dart';
import '../features/lessons/data/lesson_repository.dart';
import '../features/lessons/ui/lessons_screen.dart';
import '../features/player/player_service.dart';
import '../features/settings/bloc/settings_cubit.dart';
import '../features/settings/ui/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/encoder',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/encoder',
            builder: (context, state) => const EncoderScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/decoder',
            builder: (context, state) => const DecoderScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/lessons',
            builder: (context, state) => const LessonsScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ]),
      ],
    ),
  ],
);

class MorseCommsApp extends StatelessWidget {
  final PlayerService playerService;
  final SettingsCubit settingsCubit;
  final LessonRepository lessonRepository;

  const MorseCommsApp({
    super.key,
    required this.playerService,
    required this.settingsCubit,
    required this.lessonRepository,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: settingsCubit,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          return MultiRepositoryProvider(
            providers: [
              RepositoryProvider.value(value: playerService),
              RepositoryProvider.value(value: lessonRepository),
            ],
            child: MaterialApp.router(
              title: 'Morse Comms',
              routerConfig: _router,
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: settings.themeMode,
              debugShowCheckedModeBanner: false,
            ),
          );
        },
      ),
    );
  }
}


class _ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _ScaffoldWithNav({required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.keyboard),
            label: 'Encoder',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic),
            label: 'Decoder',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
