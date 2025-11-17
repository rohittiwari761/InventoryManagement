import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/storage_service.dart';
import '../../../shared/models/user.dart';

// Custom exception for unverified email during login
class UnverifiedEmailException implements Exception {
  final String message;
  final String email;

  UnverifiedEmailException({
    required this.message,
    required this.email,
  });

  @override
  String toString() => message;
}

// Custom exception for pending approval
class PendingApprovalException implements Exception {
  final String message;
  final String email;

  PendingApprovalException({
    required this.message,
    required this.email,
  });

  @override
  String toString() => message;
}

// Custom exception for rejected account
class RejectedAccountException implements Exception {
  final String message;
  final String email;

  RejectedAccountException({
    required this.message,
    required this.email,
  });

  @override
  String toString() => message;
}

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storage = StorageService();

  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;

        final user = User.fromJson(data['user']);
        
        await _storage.saveAuthData(
          accessToken: data['access'],
          refreshToken: data['refresh'],
          userData: data['user'],
        );

        return user;
      } else {
        throw Exception('Login failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        print('DEBUG: Login error response: $errors'); // Debug print
        if (errors is Map) {
          print('DEBUG: non_field_errors: ${errors['non_field_errors']}'); // Debug print

          // Check for unverified email error first
          if (errors.containsKey('non_field_errors') &&
              errors['non_field_errors'] is List &&
              errors['non_field_errors'].first == 'EMAIL_NOT_VERIFIED') {
            // Extract email - handle both string and list formats
            String extractedEmail = email; // fallback to input email
            if (errors['email'] != null) {
              if (errors['email'] is List && (errors['email'] as List).isNotEmpty) {
                extractedEmail = (errors['email'] as List).first.toString();
              } else if (errors['email'] is String) {
                extractedEmail = errors['email'] as String;
              }
            }

            // Extract message - handle both string and list formats
            String extractedMessage = 'Please verify your email address';
            if (errors['message'] != null) {
              if (errors['message'] is List && (errors['message'] as List).isNotEmpty) {
                extractedMessage = (errors['message'] as List).first.toString();
              } else if (errors['message'] is String) {
                extractedMessage = errors['message'] as String;
              }
            }

            throw UnverifiedEmailException(
              message: extractedMessage,
              email: extractedEmail,
            );
          }

          // Check for pending approval error
          if (errors.containsKey('non_field_errors') &&
              errors['non_field_errors'] is List &&
              (errors['non_field_errors'] as List).isNotEmpty &&
              (errors['non_field_errors'] as List).first == 'PENDING_APPROVAL') {
            print('DEBUG: Detected PENDING_APPROVAL error'); // Debug print
            // Extract email
            String extractedEmail = email;
            if (errors['email'] != null) {
              if (errors['email'] is List && (errors['email'] as List).isNotEmpty) {
                extractedEmail = (errors['email'] as List).first.toString();
              } else if (errors['email'] is String) {
                extractedEmail = errors['email'] as String;
              }
            }

            // Extract message
            String extractedMessage = 'Your account is pending admin approval';
            if (errors['message'] != null) {
              if (errors['message'] is List && (errors['message'] as List).isNotEmpty) {
                extractedMessage = (errors['message'] as List).first.toString();
              } else if (errors['message'] is String) {
                extractedMessage = errors['message'] as String;
              }
            }

            throw PendingApprovalException(
              message: extractedMessage,
              email: extractedEmail,
            );
          }

          // Check for rejected account error
          if (errors.containsKey('non_field_errors') &&
              errors['non_field_errors'] is List &&
              (errors['non_field_errors'] as List).isNotEmpty &&
              (errors['non_field_errors'] as List).first == 'ACCOUNT_REJECTED') {
            print('DEBUG: Detected ACCOUNT_REJECTED error'); // Debug print
            // Extract email
            String extractedEmail = email;
            if (errors['email'] != null) {
              if (errors['email'] is List && (errors['email'] as List).isNotEmpty) {
                extractedEmail = (errors['email'] as List).first.toString();
              } else if (errors['email'] is String) {
                extractedEmail = errors['email'] as String;
              }
            }

            // Extract message
            String extractedMessage = 'Your account access has been denied';
            if (errors['message'] != null) {
              if (errors['message'] is List && (errors['message'] as List).isNotEmpty) {
                extractedMessage = (errors['message'] as List).first.toString();
              } else if (errors['message'] is String) {
                extractedMessage = errors['message'] as String;
              }
            }

            throw RejectedAccountException(
              message: extractedMessage,
              email: extractedEmail,
            );
          }
          // Handle Django's non_field_errors format
          if (errors.containsKey('non_field_errors') &&
              errors['non_field_errors'] is List) {
            throw Exception(errors['non_field_errors'].first);
          }
          // Handle other field-specific errors
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Invalid email or password');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Invalid credentials');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Login service not available. Please contact support.');
      } else {
        throw Exception('Network error. Please try again.');
      }
    } catch (e) {
      if (e is UnverifiedEmailException ||
          e is PendingApprovalException ||
          e is RejectedAccountException) {
        rethrow;
      }
      throw Exception('An unexpected error occurred');
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
    try {
      final response = await _apiClient.post('/auth/register/', data: {
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
        'password_confirm': password,
        if (phone != null) 'phone': phone,
      });

      if (response.statusCode == 201) {
        final data = response.data;
        
        // Check if email verification is required
        if (data['email_verification_required'] == true) {
          return {
            'success': true,
            'email_verification_required': true,
            'message': data['message'] ?? 'Please verify your email address',
            'email': email,
          };
        } else {
          // Old flow - direct login after registration
          final user = User.fromJson(data['user']);
          
          await _storage.saveAuthData(
            accessToken: data['access'],
            refreshToken: data['refresh'],
            userData: data['user'],
          );

          return {
            'success': true,
            'email_verification_required': false,
            'user': user,
          };
        }
      } else {
        throw Exception('Registration failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Registration failed. Please check your details.');
      } else {
        throw Exception('Network error. Please try again.');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();

      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await _apiClient.post('/auth/logout/', data: {
            'refresh': refreshToken,
          });
        } catch (e) {
          // Don't rethrow - continue with local cleanup
        }
      }
    } catch (e) {
      // Ignore logout errors, we'll clear local data anyway
    } finally {
      try {
        await _storage.clearAuth();
      } catch (e) {
        // Silently handle storage clear errors
      }
    }
  }

  Future<User?> getCurrentUser() async {
    try {
      final userData = await _storage.getUserData();
      if (userData != null) {
        return User.fromJson(userData);
      }
    } catch (e) {
      await _storage.clearAuth();
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }

  Future<User> getProfile() async {
    try {
      final response = await _apiClient.get('/auth/profile/');

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        await _storage.saveUserData(response.data);
        return user;
      } else {
        throw Exception('Failed to get profile');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clearAuth();
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<User> updateProfile({
    required String firstName,
    required String lastName,
    String? phone,
    String? invoiceLayoutPreference,
  }) async {
    try {
      final response = await _apiClient.patch('/auth/profile/', data: {
        'first_name': firstName,
        'last_name': lastName,
        if (phone != null) 'phone': phone,
        if (invoiceLayoutPreference != null) 'invoice_layout_preference': invoiceLayoutPreference,
      });

      if (response.statusCode == 200) {
        final user = User.fromJson(response.data);
        await _storage.saveUserData(response.data);
        return user;
      } else {
        throw Exception('Failed to update profile');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid profile data');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post('/auth/change-password/', data: {
        'old_password': oldPassword,
        'new_password': newPassword,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to change password');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Admin-only restriction
        final errors = e.response?.data;
        if (errors is Map && errors.containsKey('error')) {
          throw Exception(errors['error']);
        }
        throw Exception('Password changes are only available for admin users. Please contact your administrator.');
      } else if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map && errors.containsKey('old_password')) {
          throw Exception('Current password is incorrect');
        }
        throw Exception('Invalid password data');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred');
    }
  }

  Future<User> verifyEmail({
    required String email,
    required String verificationCode,
  }) async {
    try {
      final response = await _apiClient.post('/auth/verify-email/', data: {
        'email': email,
        'verification_code': verificationCode,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        final user = User.fromJson(data['user']);
        
        // Save authentication data after successful verification
        await _storage.saveAuthData(
          accessToken: data['access'],
          refreshToken: data['refresh'],
          userData: data['user'],
        );

        return user;
      } else {
        throw Exception('Email verification failed');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          if (errors.containsKey('verification_code')) {
            throw Exception('Invalid verification code');
          }
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Invalid verification code');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found or verification expired');
      } else {
        throw Exception('Network error. Please try again.');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<bool> resendVerificationCode(String email) async {
    try {
      final response = await _apiClient.post('/auth/resend-verification/', data: {
        'email': email,
      });

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to resend verification code');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Failed to resend verification code');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found');
      } else {
        throw Exception('Network error. Please try again.');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await _apiClient.post('/auth/forgot-password/', data: {
        'email': email,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to send password reset email');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Admin-only restriction
        final errors = e.response?.data;
        if (errors is Map && errors.containsKey('error')) {
          throw Exception(errors['error']);
        }
        throw Exception('Password reset is only available for admin users. Please contact your administrator.');
      } else if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Invalid email address');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found');
      } else {
        throw Exception('Network error. Please try again.');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post('/auth/reset-password/', data: {
        'email': email,
        'reset_token': resetToken,
        'new_password': newPassword,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to reset password');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          if (errors.containsKey('reset_token')) {
            throw Exception('Invalid or expired reset token');
          }
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Invalid reset token or password');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found or reset token expired');
      } else {
        throw Exception('Network error. Please try again.');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }
}