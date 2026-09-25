import 'package:go_router/go_router.dart';

import '../features/about/about_screen.dart';
import '../features/home/home_screen.dart';
import '../features/interview/interview_screen.dart';
import '../features/listen/listen_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/technology/technology_screen.dart';

/// Flat routing: the app is four destinations deep at most, so a shell
/// navigator would be ceremony without benefit.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
    GoRoute(
      path: '/interview',
      builder: (context, state) => const InterviewScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/listen',
      builder: (context, state) =>
          ListenScreen(request: state.extra! as ListenRequest),
    ),
    GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
    GoRoute(
      path: '/t/:technologyId',
      builder: (context, state) =>
          TechnologyScreen(technologyId: state.pathParameters['technologyId']!),
      routes: [
        GoRoute(
          path: 'practice',
          builder: (context, state) => PracticeScreen(
            technologyId: state.pathParameters['technologyId']!,
          ),
        ),
      ],
    ),
  ],
);
