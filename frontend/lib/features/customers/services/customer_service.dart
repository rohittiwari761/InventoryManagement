import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/customer.dart';

class CustomerService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _apiClient.get('/customers/');
      
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
        
        return data.map((json) => Customer.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch customers');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Customer> getCustomer(int id) async {
    try {
      final response = await _apiClient.get('/customers/$id/');
      
      if (response.statusCode == 200) {
        return Customer.fromJson(response.data);
      } else {
        throw Exception('Failed to fetch customer');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Customer not found');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Customer> createCustomer({
    required String name,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? country,
    String? gstin,
    String? phone,
    String? email,
    String? website,
    String? contactPerson,
    String? pan,
    bool isActive = true,
  }) async {
    try {
      final requestData = {
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'country': country,
        'gstin': gstin,
        'phone': phone,
        'email': email,
        'website': website,
        'contact_person': contactPerson,
        'pan': pan,
        'is_active': isActive,
      };

      final response = await _apiClient.post('/customers/', data: requestData);

      if (response.statusCode == 201) {
        if (response.data == null) {
          throw Exception('Server returned null response');
        }
        
        return Customer.fromJson(response.data);
      } else {
        throw Exception('Failed to create customer (Status: ${response.statusCode})');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          final errorMessages = <String>[];
          errors.forEach((key, value) {
            if (value is List) {
              errorMessages.add('${key.toString().replaceAll('_', ' ').toUpperCase()}: ${value.join(", ")}');
            } else {
              errorMessages.add('${key.toString().replaceAll('_', ' ').toUpperCase()}: $value');
            }
          });
          throw Exception(errorMessages.join('\n'));
        }
        throw Exception('Invalid customer data: ${e.response?.data}');
      }
      throw Exception('Network error: ${e.message}. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Customer> updateCustomer({
    required int id,
    String? name,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? country,
    String? gstin,
    String? phone,
    String? email,
    String? website,
    String? contactPerson,
    String? pan,
    bool? isActive,
  }) async {
    try {
      final data = <String, dynamic>{};
      
      if (name != null) data['name'] = name;
      if (address != null) data['address'] = address;
      if (city != null) data['city'] = city;
      if (state != null) data['state'] = state;
      if (pincode != null) data['pincode'] = pincode;
      if (country != null) data['country'] = country;
      if (gstin != null) data['gstin'] = gstin;
      if (phone != null) data['phone'] = phone;
      if (email != null) data['email'] = email;
      if (website != null) data['website'] = website;
      if (contactPerson != null) data['contact_person'] = contactPerson;
      if (pan != null) data['pan'] = pan;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _apiClient.patch('/customers/$id/', data: data);

      if (response.statusCode == 200) {
        return Customer.fromJson(response.data);
      } else {
        throw Exception('Failed to update customer');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid customer data');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Customer not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> deleteCustomer(int id) async {
    try {
      final response = await _apiClient.delete('/customers/$id/');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete customer');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Customer not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final response = await _apiClient.get('/customers/?search=$query');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        final List<dynamic> data;
        
        if (responseData is Map && responseData.containsKey('results')) {
          data = responseData['results'];
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [responseData];
        }
        
        return data.map((json) => Customer.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search customers');
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
}