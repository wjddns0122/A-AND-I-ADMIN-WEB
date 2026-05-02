import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_nav_view_model.g.dart';

enum DashboardNavTab { usersManage, tasksManage, ojManage }

String dashboardLocationForTab(DashboardNavTab tab) {
  return switch (tab) {
    DashboardNavTab.usersManage => '/dashboard?tab=users',
    DashboardNavTab.tasksManage => '/dashboard?tab=tasks',
    DashboardNavTab.ojManage => '/dashboard?tab=oj',
  };
}

@riverpod
class DashboardNavViewModel extends _$DashboardNavViewModel {
  @override
  DashboardNavTab build() => DashboardNavTab.usersManage;

  void selectTab(DashboardNavTab tab) {
    state = tab;
  }
}
