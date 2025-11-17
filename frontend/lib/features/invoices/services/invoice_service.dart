import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/invoice.dart';

class PaginatedInvoiceResponse {
  final List<Invoice> results;
  final int count;
  final String? next;
  final String? previous;

  PaginatedInvoiceResponse({
    required this.results,
    required this.count,
    this.next,
    this.previous,
  });

  bool get hasMore => next != null;
}

class InvoiceService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Invoice>> getInvoices({int? storeId}) async {
    try {
      String endpoint = '/invoices/';
      if (storeId != null) {
        endpoint += '?store=$storeId';
      }
      
      final response = await _apiClient.get(endpoint);
      
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
        
        return data.map((json) => Invoice.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch invoices');
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

  Future<PaginatedInvoiceResponse> getInvoicesPaginated({
    int page = 1,
    int? storeId,
    String? search,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{'page': page.toString()};

      if (storeId != null) {
        queryParams['store'] = storeId.toString();
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final response = await _apiClient.get(
        '/invoices/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        final List<dynamic> data = responseData['results'] ?? responseData;
        final int count = responseData['count'] ?? data.length;
        final String? next = responseData['next'];
        final String? previous = responseData['previous'];

        final invoices = data.map((json) => Invoice.fromJson(json)).toList();

        return PaginatedInvoiceResponse(
          results: invoices,
          count: count,
          next: next,
          previous: previous,
        );
      } else {
        throw Exception('Failed to fetch invoices');
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

  Future<int> getTotalInvoicesCount({int? storeId}) async {
    try {
      final queryParams = <String, String>{'page': '1'};
      if (storeId != null) {
        queryParams['store'] = storeId.toString();
      }

      final response = await _apiClient.get(
        '/invoices/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        return responseData['count'] ?? 0;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  Future<Invoice> getInvoice(int id) async {
    try {
      if (kDebugMode) {
        debugPrint('=== FETCHING INVOICE $id FROM API ===');
      }
      final response = await _apiClient.get('/invoices/$id/');
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('Successfully fetched invoice $id');
        }
        
        final invoice = Invoice.fromJson(response.data);
        
        return invoice;
      } else {
        throw Exception('Failed to fetch invoice');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('API Error - Status: ${e.response?.statusCode}, Message: ${e.message}');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Invoice not found');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Unexpected error fetching invoice: $e');
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Invoice> createInvoice({
    int? companyId,  // Made optional for auto-assignment
    int? storeId,    // Made optional for auto-assignment
    required String customerName,
    String? customerAddress,
    String? customerCity,
    String? customerState,
    String? customerPincode,
    String? customerGstin,
    String? customerPhone,
    String? customerEmail,
    required List<InvoiceItemInput> items,
    String? notes,
    String? termsAndConditions,
    DateTime? dueDate,
    DateTime? invoiceDate,
    bool includeLogistics = false,
    String? driverName,
    String? driverPhone,
    String? vehicleNumber,
    String? transportCompany,
    String? lrNumber,
    DateTime? dispatchDate,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Creating invoice for customer: $customerName');
      }
      
      final requestData = <String, dynamic>{
        'customer_name': customerName,
        'customer_address': customerAddress ?? '',
        'customer_city': customerCity ?? '',
        'customer_state': customerState ?? '',
        'customer_pincode': customerPincode ?? '',
        'customer_gstin': customerGstin ?? '',
        'customer_phone': customerPhone ?? '',
        'customer_email': customerEmail ?? '',
        'invoice_date': (invoiceDate ?? DateTime.now()).toIso8601String().split('T')[0],
        'due_date': dueDate?.toIso8601String().split('T')[0],
        'items': items.map((item) => item.toJson()).toList(),
        'notes': notes ?? '',
        'place_of_supply': customerState ?? '',
        'reverse_charge': 'No',
        'invoice_type': 'tax_invoice',
        'terms_and_conditions': termsAndConditions ?? '1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged on delayed payments.\n3. Subject to jurisdiction only.\n4. All disputes subject to arbitration only.',
        'include_logistics': includeLogistics,
        'driver_name': driverName,
        'driver_phone': driverPhone,
        'vehicle_number': vehicleNumber,
        'transport_company': transportCompany,
        'lr_number': lrNumber,
        'dispatch_date': dispatchDate?.toIso8601String().split('T')[0],
      };
      
      // Only include company and store if provided (for admin users)
      if (companyId != null) {
        requestData['company'] = companyId;
      }
      if (storeId != null) {
        requestData['store'] = storeId;
      }
      
      if (kDebugMode) {
        debugPrint('Sending invoice creation request');
      }

      final response = await _apiClient.post('/invoices/', data: requestData);

      if (response.statusCode == 201) {
        if (response.data == null) {
          throw Exception('Server returned null response');
        }
        
        if (kDebugMode) {
          debugPrint('Invoice created successfully');
        }
        
        final createdInvoice = Invoice.fromJson(response.data);
        
        return createdInvoice;
      } else {
        throw Exception('Failed to create invoice (Status: ${response.statusCode})');
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
        throw Exception('Invalid invoice data: ${e.response?.data}');
      }
      throw Exception('Network error: ${e.message}. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<Invoice> updateInvoice({
    required int id,
    String? customerName,
    String? customerAddress,
    String? customerGstin,
    String? customerPhone,
    String? customerEmail,
    List<InvoiceItemInput>? items,
    String? notes,
    DateTime? dueDate,
    InvoiceStatus? status,
    bool? includeLogistics,
    String? driverName,
    String? driverPhone,
    String? vehicleNumber,
    String? transportCompany,
    String? lrNumber,
    DateTime? dispatchDate,
  }) async {
    try {
      final data = <String, dynamic>{};

      if (customerName != null) data['customer_name'] = customerName;
      if (customerAddress != null) data['customer_address'] = customerAddress;
      if (customerGstin != null) data['customer_gstin'] = customerGstin;
      if (customerPhone != null) data['customer_phone'] = customerPhone;
      if (customerEmail != null) data['customer_email'] = customerEmail;
      if (items != null) data['items'] = items.map((item) => item.toJson()).toList();
      if (notes != null) data['notes'] = notes;
      if (dueDate != null) data['due_date'] = dueDate.toIso8601String();
      if (status != null) data['status'] = status.value;
      if (includeLogistics != null) data['include_logistics'] = includeLogistics;
      if (driverName != null) data['driver_name'] = driverName;
      if (driverPhone != null) data['driver_phone'] = driverPhone;
      if (vehicleNumber != null) data['vehicle_number'] = vehicleNumber;
      if (transportCompany != null) data['transport_company'] = transportCompany;
      if (lrNumber != null) data['lr_number'] = lrNumber;
      if (dispatchDate != null) data['dispatch_date'] = dispatchDate.toIso8601String().split('T')[0];

      final response = await _apiClient.patch('/invoices/$id/', data: data);

      if (response.statusCode == 200) {
        return Invoice.fromJson(response.data);
      } else {
        throw Exception('Failed to update invoice');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid invoice data');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Invoice not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> deleteInvoice(int id) async {
    try {
      final response = await _apiClient.delete('/invoices/$id/');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete invoice');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Invoice not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<List<int>> generateInvoicePdf(int id) async {
    try {
      final response = await _apiClient.getWithOptions(
        '/invoices/$id/pdf/',
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/pdf',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        return response.data as List<int>;
      } else {
        throw Exception('Failed to generate invoice PDF');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Invoice not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> sendInvoiceEmail(int id, String emailAddress) async {
    try {
      final response = await _apiClient.post('/invoices/$id/send-email/', data: {
        'email': emailAddress,
      });

      if (response.statusCode != 200) {
        throw Exception('Failed to send invoice email');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Invoice not found');
      } else if (e.response?.statusCode == 400) {
        throw Exception('Invalid email address');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<List<Invoice>> getStoreInvoices(int storeId) async {
    return getInvoices(storeId: storeId);
  }

  Future<Map<String, dynamic>> getInvoiceStats({int? storeId}) async {
    try {
      String endpoint = '/invoices/stats/';
      if (storeId != null) {
        endpoint += '?store=$storeId';
      }
      
      final response = await _apiClient.get(endpoint);
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch invoice statistics');
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