import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/company.dart';

class CompanyService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Company>> getCompanies() async {
    try {
      final response = await _apiClient.get('/companies/');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? response.data;
        return data.map((json) => Company.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch companies');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e, stackTrace) {
      debugPrint('Unexpected error in getCompanies: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Company> getCompany(int id) async {
    try {
      final response = await _apiClient.get('/companies/$id/');

      if (response.statusCode == 200) {
        return Company.fromJson(response.data);
      } else {
        throw Exception('Failed to fetch company');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Company not found');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e, stackTrace) {
      debugPrint('Unexpected error in getCompany: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Company> createCompany({
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    required String email,
    required String gstin,
    required String pan,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.post('/companies/', data: {
        'name': name,
        'description': description,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'pan': pan,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_ifsc': bankIfsc,
        'bank_branch': bankBranch,
        if (isActive != null) 'is_active': isActive,
      });

      if (response.statusCode == 201) {
        return Company.fromJson(response.data);
      } else {
        throw Exception('Failed to create company');
      }
    } on DioException catch (e) {
      debugPrint('DioException in createCompany: ${e.type}');
      debugPrint('Response status: ${e.response?.statusCode}');
      debugPrint('Response data: ${e.response?.data}');

      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Invalid company data');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('Unexpected error in createCompany: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Company> updateCompany({
    required int id,
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    required String email,
    required String gstin,
    required String pan,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankBranch,
    bool? isActive,
  }) async {
    try {
      final response = await _apiClient.patch('/companies/$id/', data: {
        'name': name,
        'description': description,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'phone': phone,
        'email': email,
        'gstin': gstin,
        'pan': pan,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_ifsc': bankIfsc,
        'bank_branch': bankBranch,
        if (isActive != null) 'is_active': isActive,
      });

      if (response.statusCode == 200) {
        return Company.fromJson(response.data);
      } else {
        throw Exception('Failed to update company');
      }
    } on DioException catch (e) {
      debugPrint('DioException in updateCompany: ${e.type}');
      debugPrint('Response status: ${e.response?.statusCode}');
      debugPrint('Response data: ${e.response?.data}');

      if (e.response?.statusCode == 400) {
        final errors = e.response?.data;
        if (errors is Map) {
          final errorMessage = errors.values.first;
          if (errorMessage is List) {
            throw Exception(errorMessage.first);
          }
          throw Exception(errorMessage.toString());
        }
        throw Exception('Invalid company data');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Company not found');
      }
      throw Exception('Network error: ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('Unexpected error in updateCompany: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }

  Future<void> deleteCompany(int id) async {
    try {
      final response = await _apiClient.delete('/companies/$id/');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete company');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Company not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e, stackTrace) {
      debugPrint('Unexpected error in deleteCompany: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Unexpected error: $e');
    }
  }
}
