import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/store.dart';

class StoreService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Store>> getStores() async {
    try {
      // Try different approaches to get stores
      
      // First try the regular endpoint
      var response = await _apiClient.get('/stores/');
      
      if (response.statusCode == 200) {
        dynamic data;
        if (response.data is Map && response.data['results'] != null) {
          data = response.data['results'];
        } else if (response.data is List) {
          data = response.data;
        } else {
          data = [];
        }
        
        // If no stores found, try alternative endpoints
        if (data.isEmpty) {
          
          // Try without trailing slash
          try {
            response = await _apiClient.get('/stores');
            if (response.statusCode == 200 && response.data is List && response.data.isNotEmpty) {
              data = response.data;
            }
          } catch (altE) {
          }
        }
        
        if (data is List && data.isNotEmpty) {
          return data.map((json) => Store.fromJson(json)).toList();
        } else {
          return [];
        }
      } else {
        throw Exception('Failed to fetch stores - Status: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied. User may not have permission to view stores.');
      }
      throw Exception('Network error: ${e.response?.statusCode}. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Store> getStore(int id) async {
    try {
      final response = await _apiClient.get('/stores/$id/');
      
      if (response.statusCode == 200) {
        return Store.fromJson(response.data);
      } else {
        throw Exception('Failed to fetch store');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Store not found');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Store> createStore({
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    String? email,
    required int company,
    int? manager,
    bool isActive = true,
  }) async {
    try {
      final response = await _apiClient.post('/stores/', data: {
        'name': name,
        'description': description,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'email': email,
        'company': company,
        'manager': manager,
        'is_active': isActive,
      });

      if (response.statusCode == 201) {
        return Store.fromJson(response.data);
      } else {
        throw Exception('Failed to create store');
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
        throw Exception('Invalid store data');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Store> updateStore({
    required int id,
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    String? email,
    required int company,
    int? manager,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.patch('/stores/$id/', data: {
        'name': name,
        'description': description,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'email': email,
        'company': company,
        'manager': manager,
        if (isActive != null) 'is_active': isActive,
      });

      if (response.statusCode == 200) {
        return Store.fromJson(response.data);
      } else {
        throw Exception('Failed to update store');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid store data');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Store not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> deleteStore(int id) async {
    try {
      final response = await _apiClient.delete('/stores/$id/');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete store');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Store not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }
}