import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/auth_result.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sign in with email and password
  /// Returns AuthResult with success status and error message if failed
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return AuthResult.success(response.user!.id);
      } else {
        return AuthResult.failure('Authentication failed');
      }
    } on AuthException catch (e) {
      return AuthResult.failure(_handleAuthError(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred: ${e.toString()}');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // Log error but don't throw - sign out should always succeed locally
      print('Sign out error: $e');
    }
  }

  /// Get current user session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentSession != null;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Check if current user's email is verified
  bool get isEmailVerified {
    final user = currentUser;
    if (user == null) return false;
    
    // Check email_confirmed_at field
    return user.emailConfirmedAt != null;
  }

  /// Resend email verification
  /// Returns true if email was sent successfully
  Future<bool> resendVerificationEmail() async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        return false;
      }

      // Resend confirmation email
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: user.email!,
      );
      
      return true;
    } catch (e) {
      print('Resend verification email error: $e');
      return false;
    }
  }

  /// Handle authentication errors and return user-friendly messages
  String _handleAuthError(AuthException error) {
    switch (error.statusCode) {
      case '400':
        if (error.message.contains('Invalid login credentials')) {
          return 'Invalid email or password';
        }
        return 'Invalid request. Please check your input.';
      case '401':
        return 'Invalid email or password';
      case '422':
        return 'Invalid email format';
      case '429':
        return 'Too many attempts. Please try again later.';
      default:
        return error.message;
    }
  }
}
