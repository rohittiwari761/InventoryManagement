import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/user.dart';

class UserManagementService {
  final ApiClient _apiClient = ApiClient();

  Future<List<User>> getUsers() async {
    try {
      final response = await _apiClient.get('/auth/users/');

      if (response.statusCode == 200) {
        final responseData = response.data;
        final List<dynamic> data;

        // Handle both paginated and non-paginated responses
        if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [responseData];
        }

        // Debug: Print first user's assigned stores
        if (data.isNotEmpty) {
          if (data[0]['assigned_stores'] != null) {
          }
        }

        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch users');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<User> getUser(int id) async {
    try {
      final response = await _apiClient.get('/auth/users/$id/');
      
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      } else {
        throw Exception('Failed to fetch user');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('User not found');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<User> createUser({
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    String? phone,
    required String role,
    required String password,
    required String passwordConfirm,
  }) async {
    try {
      final response = await _apiClient.post('/auth/users/', data: {
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'role': role,
        'password': password,
        'password_confirm': passwordConfirm,
      });

      if (response.statusCode == 201) {
        if (response.data == null) {
          throw Exception('Server returned null response');
        }
        
        // Check if the response contains an ID, if not, fetch the user list to find the newly created user
        if (response.data['id'] == null) {
          // Try to find the user by email since the API doesn't return the ID
          try {
            final users = await getUsers();
            final newUser = users.firstWhere(
              (user) => user.email == response.data['email'] && user.username == response.data['username'],
            );
            return newUser;
          } catch (e) {
            // Create a temporary user object with the available data but no ID
            // This will allow the user creation to succeed but store assignment may still fail
            final tempUser = User.fromJson({
              ...response.data,
              'id': 0, // Temporary ID
            });
            return tempUser;
          }
        } else {
          final user = User.fromJson(response.data);
          return user;
        }
      } else {
        throw Exception('Failed to create user (Status: ${response.statusCode})');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          // Handle multiple field errors with user-friendly messages
          final errorMessages = <String>[];
          errors.forEach((key, value) {
            if (value is List) {
              if (key == 'email') {
                errorMessages.add('Email: ${value.join(", ")}');
              } else if (key == 'username') {
                errorMessages.add('Username: ${value.join(", ")}');
              } else {
                errorMessages.add('${key.toString().replaceAll('_', ' ').toUpperCase()}: ${value.join(", ")}');
              }
            } else {
              errorMessages.add('${key.toString().replaceAll('_', ' ').toUpperCase()}: $value');
            }
          });
          throw Exception(errorMessages.join('\n'));
        }
        throw Exception('Invalid user data: ${e.response?.data}');
      }
      throw Exception('Network error: ${e.message}. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<User> updateUser({
    required int id,
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    String? phone,
    required String role,
    required bool isActive,
  }) async {
    try {
      final response = await _apiClient.patch('/auth/users/$id/', data: {
        'email': email,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'role': role,
        'is_active': isActive,
      });

      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      } else {
        throw Exception('Failed to update user');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid user data');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      final response = await _apiClient.delete('/auth/users/$id/');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete user');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('User not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> assignUserToStore(int userId, int storeId) async {
    try {
      // Validate inputs
      if (userId <= 0 || storeId <= 0) {
        throw Exception('Invalid user ID or store ID');
      }

      final response = await _apiClient.post('/auth/assign-user-to-store/', data: {
        'user_id': userId,
        'store_id': storeId,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to assign user to store');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final error = e.response?.data['error'] ?? 'Invalid request';
        throw Exception('Bad Request: $error');
      } else if (e.response?.statusCode == 404) {
        final error = e.response?.data['error'] ?? 'Not found';
        throw Exception('Not Found: $error');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied: You do not have permission to assign users to this store');
      }
      throw Exception('Network error: ${e.response?.statusCode ?? "Unknown"}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<void> removeUserFromStore(int userId, int storeId) async {
    try {
      final response = await _apiClient.delete('/auth/remove-user-from-store/$userId/$storeId/');

      if (response.statusCode != 200) {
        throw Exception('Failed to remove user from store');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Store assignment not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<List<User>> getStoreUsers(int storeId) async {
    try {
      final response = await _apiClient.get('/stores/$storeId/users/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch store users');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<List<Map<String, dynamic>>> getUserStores(int userId) async {
    try {
      final response = await _apiClient.get('/auth/users/$userId/stores/');
      
      if (response.statusCode == 200) {
        if (response.data is List) {
          return List<Map<String, dynamic>>.from(response.data);
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to fetch user stores');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> changeUserPassword({
    required int userId,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    try {
      final response = await _apiClient.post('/auth/admin-change-password/', data: {
        'user_id': userId,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to change user password');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map && errors.containsKey('non_field_errors')) {
          throw Exception(errors['non_field_errors'].first);
        } else if (errors is Map && errors.containsKey('new_password')) {
          throw Exception(errors['new_password'].first);
        } else {
          throw Exception('Invalid password data');
        }
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied: You can only change password of users you created');
      } else if (e.response?.statusCode == 404) {
        throw Exception('User not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<User> approveUser(int userId) async {
    try {
      final response = await _apiClient.post('/auth/users/$userId/approve/', data: {});

      if (response.statusCode == 200) {
        return User.fromJson(response.data['user']);
      } else {
        throw Exception('Failed to approve user');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('User not found or access denied');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied: You can only approve users you created');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<User> rejectUser(int userId) async {
    try {
      final response = await _apiClient.post('/auth/users/$userId/reject/', data: {});

      if (response.statusCode == 200) {
        return User.fromJson(response.data['user']);
      } else {
        throw Exception('Failed to reject user');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('User not found or access denied');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied: You can only reject users you created');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<int> getPendingUsersCount() async {
    try {
      final response = await _apiClient.get('/auth/users/pending/count/');

      if (response.statusCode == 200) {
        return response.data['count'] ?? 0;
      } else {
        throw Exception('Failed to get pending users count');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      return 0;
    }
  }
}