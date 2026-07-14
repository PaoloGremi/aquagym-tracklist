import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/spotify/spotify_auth_service.dart';
import 'core_providers.dart';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthController extends StateNotifier<AuthStatus> {
  final SpotifyAuthService _auth;

  AuthController(this._auth) : super(AuthStatus.unknown) {
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    final loggedIn = await _auth.isLoggedIn;
    state = loggedIn ? AuthStatus.loggedIn : AuthStatus.loggedOut;
  }

  /// Ritorna un messaggio di errore leggibile in caso di fallimento, o
  /// null se il login è andato a buon fine.
  Future<String?> login() async {
    try {
      await _auth.login();
      state = AuthStatus.loggedIn;
      return null;
    } on SpotifyAuthException catch (e) {
      state = AuthStatus.loggedOut;
      return e.message;
    } catch (e) {
      state = AuthStatus.loggedOut;
      return 'Errore imprevisto durante il login: $e';
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    state = AuthStatus.loggedOut;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthStatus>((ref) {
  return AuthController(ref.watch(spotifyAuthServiceProvider));
});
