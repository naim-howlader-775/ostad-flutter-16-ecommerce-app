import '../../../core/network/api_exceptions.dart';
import '../../../core/storage/preference_service.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

abstract class AuthRepository {
  Future<UserModel> login({
    required String username,
    required String password,
  });

  Future<UserModel?> checkAuthStatus();

  /// Refreshes access token using the stored refresh token.
  /// Returns true when a new access token was saved.
  Future<bool> refreshSession();

  UserModel? getCachedUser();

  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final PreferenceService preferenceService;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.preferenceService,
  });

  @override
  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    final data = await remoteDataSource.login(
      username: username,
      password: password,
    );

    // Save authentication tokens
    final accessToken = data['accessToken']?.toString();
    final refreshToken = data['refreshToken']?.toString();

    if (accessToken != null && accessToken.isNotEmpty) {
      await preferenceService.setAuthToken(accessToken);
    }
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await preferenceService.setRefreshToken(refreshToken);
    }

    final user = UserModel.fromMap(data);
    await preferenceService.setUserData(user.toMap());

    return user;
  }

  @override
  Future<UserModel?> checkAuthStatus() async {
    final token = preferenceService.getAuthToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    // Attempt to load locally cached user first for immediate UI responsiveness
    final cachedData = preferenceService.getUserData();
    UserModel? cachedUser;
    if (cachedData != null) {
      cachedUser = UserModel.fromMap(cachedData);
    }

    // Verify token validity against /auth/me
    try {
      final freshData = await remoteDataSource.getCurrentUser();
      final freshUser = UserModel.fromMap(freshData);
      await preferenceService.setUserData(freshUser.toMap());
      return freshUser;
    } on UnauthorizedException {
      final refreshed = await refreshSession();
      if (!refreshed) {
        await logout();
        return null;
      }
      try {
        final freshData = await remoteDataSource.getCurrentUser();
        final freshUser = UserModel.fromMap(freshData);
        await preferenceService.setUserData(freshUser.toMap());
        return freshUser;
      } catch (_) {
        await logout();
        return null;
      }
    } catch (_) {
      // In case of offline/network glitch, fallback to cached user if available
      return cachedUser;
    }
  }

  @override
  Future<bool> refreshSession() async {
    final refreshToken = preferenceService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final data = await remoteDataSource.refreshToken(refreshToken);
      final accessToken =
          data['accessToken']?.toString() ?? data['token']?.toString();
      final newRefresh = data['refreshToken']?.toString();

      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }

      await preferenceService.setAuthToken(accessToken);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await preferenceService.setRefreshToken(newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  UserModel? getCachedUser() {
    final cachedData = preferenceService.getUserData();
    if (cachedData == null) return null;
    return UserModel.fromMap(cachedData);
  }

  @override
  Future<void> logout() async {
    await preferenceService.clearAuthSession();
  }
}
