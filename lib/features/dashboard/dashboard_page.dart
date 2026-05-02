import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/logout_action.dart';
import 'dashboard_nav_view_model.dart';
import 'views/dashboard_body_view.dart';
import 'views/dashboard_sidebar_view.dart';

class DashboardShellPage extends ConsumerWidget {
  const DashboardShellPage({super.key, required this.child, this.selectedTab});

  final Widget child;
  final DashboardNavTab? selectedTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = selectedTab ?? ref.watch(dashboardNavViewModelProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 980;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: const Color(0xFFFCFCFC),
            body: Row(
              children: [
                DashboardSidebarView(selectedTab: currentTab),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFFCFCFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'A&I Admin',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: -0.5,
              ),
            ),
            centerTitle: true,
            leading: Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
            actions: [
              IconButton(
                onPressed: () => performLogout(context, ref),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          drawer: Drawer(child: DashboardSidebarView(selectedTab: currentTab)),
          body: child,
        );
      },
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key, this.selectedTab});

  final DashboardNavTab? selectedTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = selectedTab ?? ref.watch(dashboardNavViewModelProvider);

    return DashboardBodyView(
      selectedTab: currentTab!,
      onLogout: () => performLogout(context, ref),
      isDesktop: true,
    );
  }
}
