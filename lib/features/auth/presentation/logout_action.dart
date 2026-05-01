import 'package:aandi_auth/aandi_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';

Future<void> performLogout(BuildContext context, WidgetRef ref) async {
  final logout = ref.read(logoutUseCaseProvider);
  final tokenStore = ref.read(tokenStoreProvider);
  final authBloc = ref.read(authBlocProvider.notifier);

  try {
    await logout();
  } catch (_) {
    // 서버 로그아웃 실패 시에도 로컬 토큰 정리 진행
  } finally {
    await tokenStore.clear();
  }

  authBloc.onEvent(const AuthLogoutRequested());
  if (context.mounted) {
    context.go('/login');
  }
}
