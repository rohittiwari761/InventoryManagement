import 'package:flutter/foundation.dart';
import '../../../shared/models/user.dart';
import '../services/auth_service.dart';

// Import custom exceptions
export '../services/auth_service.dart' show UnverifiedEmailException, PendingApprovalException, RejectedAccountException;

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _setLoading(true);
    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        _user = await _authService.getCurrentUser();
        _isAuthenticated = _user != null;
      } else {
        _isAuthenticated = false;
        _user = null;
      }
    } catch (e) {
      _isAuthenticated = false;
      _user = null;
      if (kDebugMode) {
        print('Auth check error: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.login(email, password);
      _isAuthenticated = true;
      _setLoading(false);
      print('DEBUG AuthProvider: Login successful'); // Debug
      return {'success': true};
    } on UnverifiedEmailException catch (e) {
      print('DEBUG AuthProvider: Caught UnverifiedEmailException'); // Debug
      // Return unverified status - we need to call setLoading to update UI
      _setLoading(false);
      return {
        'success': false,
        'unverified': true,
        'email': e.email,
        'message': e.message,
      };
    } on PendingApprovalException catch (e) {
      print('DEBUG AuthProvider: Caught PendingApprovalException - ${e.message}'); // Debug
      // Return pending approval status AND set error message so it displays in UI
      _setError('⏳ ${e.message}'); // Set error to display in error widget
      _setLoading(false);
      return {
        'success': false,
        'pending_approval': true,
        'email': e.email,
        'message': e.message,
      };
    } on RejectedAccountException catch (e) {
      print('DEBUG AuthProvider: Caught RejectedAccountException'); // Debug
      // Return rejected status AND set error message so it displays in UI
      _setError('❌ ${e.message}'); // Set error to display in error widget
      _setLoading(false);
      return {
        'success': false,
        'rejected': true,
        'email': e.email,
        'message': e.message,
      };
    } catch (e) {
      print('DEBUG AuthProvider: Caught generic exception - $e'); // Debug
      _setError(e.toString());
      _setLoading(false);
      return {'success': false, 'unverified': false};
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required String password,
    String? phone,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _authService.register(
        email: email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        password: password,
        phone: phone,
      );

      if (result['email_verification_required'] == true) {
        // Email verification required - don't set authenticated status
        _setLoading(false);
        return {
          'success': true,
          'email_verification_required': true,
          'message': result['message'],
          'email': result['email'],
        };
      } else {
        // Old flow - direct login after registration
        _user = result['user'];
        _isAuthenticated = true;
        _setLoading(false);
        return {'success': true, 'email_verification_required': false};
      }
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      await _authService.logout();
    } catch (e) {
      if (kDebugMode) {
        print('Logout error: $e');
      }
    } finally {
      _user = null;
      _isAuthenticated = false;
      _errorMessage = null;
      _setLoading(false);
    }
  }

  void forceLogout() {
    _user = null;
    _isAuthenticated = false;
    _errorMessage = null;
    _isLoading = false;
    // Also clear storage in force logout
    _authService.logout().catchError((e) {
      // Ignore errors during force logout
    });
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? invoiceLayoutPreference,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        invoiceLayoutPreference: invoiceLayoutPreference,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> refreshProfile() async {
    if (!_isAuthenticated) return false;

    try {
      _user = await _authService.getProfile();
      notifyListeners();
      return true;
    } catch (e) {
      if (e.toString().contains('Session expired')) {
        await logout();
      }
      return false;
    }
  }

  Future<bool> verifyEmail({
    required String email,
    required String verificationCode,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _user = await _authService.verifyEmail(
        email: email,
        verificationCode: verificationCode,
      );
      _isAuthenticated = true;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resendVerificationCode(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.resendVerificationCode(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.forgotPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.resetPassword(
        email: email,
        resetToken: resetToken,
        newPassword: newPassword,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }
}
