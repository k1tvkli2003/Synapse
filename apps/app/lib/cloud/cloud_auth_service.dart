import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_bootstrap.dart';

/// Email one-time-code sign-in. Chosen over magic links because it needs no
/// redirect-URL configuration on the Supabase project, so it works from any
/// deployment URL (Vercel preview/prod) without extra setup.
class CloudAuthService {
  const CloudAuthService();

  Stream<AuthState> get onAuthStateChange => cloud.auth.onAuthStateChange;

  User? get currentUser => cloud.auth.currentUser;

  Future<void> sendCode(String email) => cloud.auth.signInWithOtp(email: email);

  Future<AuthResponse> verifyCode(String email, String code) => cloud.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );

  Future<void> signOut() => cloud.auth.signOut();
}
