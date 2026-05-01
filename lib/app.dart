import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aandi_auth/aandi_auth.dart';

import 'app/api_error_feedback.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/dashboard/dashboard_nav_view_model.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/login/login_page.dart';
import 'features/tasks-manage/assignment_form_page.dart';
import 'features/tasks-manage/course_details_dialog.dart';

class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});

  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      navigatorKey: appNavigatorKey,
      initialLocation: '/dashboard',
      redirect: (context, state) async {
        final isLoginRoute = state.matchedLocation == '/login';
        final isLoggedIn =
            ref.read(authBlocProvider).isAuthenticated ||
            await _hasStoredAccessToken();

        if (!isLoggedIn && !isLoginRoute) {
          return '/login';
        }
        if (isLoggedIn && isLoginRoute) {
          return '/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        ShellRoute(
          builder: (context, state, child) => DashboardShellPage(
            selectedTab: _selectedTabForPath(state.uri.path),
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
            GoRoute(
              path: '/dashboard/courses/:courseSlug',
              builder: (context, state) => CourseDetailsPage(
                courseSlug: state.pathParameters['courseSlug']!,
              ),
            ),
            GoRoute(
              path: '/dashboard/courses/:courseSlug/assignments/new',
              builder: (context, state) => AssignmentFormPage.create(
                courseSlug: state.pathParameters['courseSlug']!,
              ),
            ),
            GoRoute(
              path:
                  '/dashboard/courses/:courseSlug/assignments/:assignmentId/edit',
              builder: (context, state) => AssignmentFormPage.edit(
                courseSlug: state.pathParameters['courseSlug']!,
                assignmentId: state.pathParameters['assignmentId']!,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AANDI Admin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }

  Future<bool> _hasStoredAccessToken() async {
    final tokens = await ref.read(tokenStoreProvider).read();
    return tokens?.accessToken.isNotEmpty ?? false;
  }
}

DashboardNavTab? _selectedTabForPath(String path) {
  if (path.startsWith('/dashboard/courses')) {
    return DashboardNavTab.tasksManage;
  }
  return null;
}
