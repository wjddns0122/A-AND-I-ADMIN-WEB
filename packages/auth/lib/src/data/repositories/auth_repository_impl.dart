import '../../domain/entities/auth_role.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api_client.dart';
import '../dtos/auth_dtos.dart';
import '../storage/token_store.dart';

final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthApiClient apiClient,
    required TokenStore tokenStore,
  }) : _apiClient = apiClient,
       _tokenStore = tokenStore;

  final AuthApiClient _apiClient;
  final TokenStore _tokenStore;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.login(
      LoginRequestDto(username: username, password: password),
    );

    final tokens = AuthTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresIn: response.expiresIn,
      tokenType: response.tokenType,
    );
    await _tokenStore.save(tokens);

    return AuthSession(user: response.user.toDomain(), tokens: tokens);
  }

  @override
  Future<String> refresh() async {
    final current = await _tokenStore.read();
    final refreshToken = current?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw AuthApiException('Refresh token is missing. Please log in again.');
    }

    final response = await _apiClient.refresh(
      RefreshRequestDto(refreshToken: refreshToken),
    );

    final nextTokens = AuthTokens(
      accessToken: response.accessToken,
      refreshToken: refreshToken,
      expiresIn: response.expiresIn,
      tokenType: current?.tokenType,
    );
    await _tokenStore.save(nextTokens);

    return nextTokens.accessToken;
  }

  @override
  Future<void> logout() async {
    final current = await _tokenStore.read();
    final refreshToken = current?.refreshToken;
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.logout(LogoutRequestDto(refreshToken: refreshToken));
      }
    } finally {
      await _tokenStore.clear();
    }
  }

  @override
  Future<AuthUser> me() async {
    final accessToken = await _requireAccessToken();
    final response = await _apiClient.me(accessToken: accessToken);
    return response.toDomain();
  }

  Future<String> _requireAccessToken() async {
    final tokens = await _tokenStore.read();
    if (tokens == null || tokens.accessToken.isEmpty) {
      throw AuthApiException('Access token is missing. Please log in again.');
    }
    return tokens.accessToken;
  }
}

extension on LoginUserDto {
  AuthUser toDomain() {
    return AuthUser(id: id, username: username, role: _mapRole(role));
  }
}

extension on MeResponseDto {
  AuthUser toDomain() {
    return AuthUser(id: id, username: username, role: _mapRole(role));
  }
}

AuthRole _mapRole(AuthRoleDto role) {
  return switch (role) {
    AuthRoleDto.user => AuthRole.user,
    AuthRoleDto.organizer => AuthRole.organizer,
    AuthRoleDto.admin => AuthRole.admin,
  };
}
