import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/item.dart';

class PaginatedResponse<T> {
  final List<T> results;
  final int count;
  final String? next;
  final String? previous;

  PaginatedResponse({
    required this.results,
    required this.count,
    this.next,
    this.previous,
  });

  bool get hasMore => next != null;
}

class InventoryService {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> getItemsOrInventory() async {
    try {
      final response = await _apiClient.get('/items/');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? response.data;
        
        // Check if response contains store inventory data or item data
        if (data.isNotEmpty) {
          final firstItem = data.first;
          
          if (firstItem.containsKey('quantity') && firstItem.containsKey('item_name')) {
            // This is store inventory data
            final inventory = data.map((json) => StoreInventory.fromJson(json)).toList();
            for (var inv in inventory) {
            }
            return inventory;
          } else {
            // This is item data
            final items = data.map((json) => Item.fromJson(json)).toList();
            return items;
          }
        } else {
        }
        return [];
      } else {
        throw Exception('Failed to fetch items');
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

  Future<List<Item>> getItems() async {
    final data = await getItemsOrInventory();
    return data.whereType<Item>().toList();
  }

  Future<PaginatedResponse<dynamic>> getItemsOrInventoryPaginated({int page = 1, String? search}) async {
    try {
      final queryParams = {'page': page.toString()};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.get(
        '/items/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        final List<dynamic> data = responseData['results'] ?? responseData;
        final int count = responseData['count'] ?? data.length;
        final String? next = responseData['next'];
        final String? previous = responseData['previous'];

        List<dynamic> parsedData = [];
        // Check if response contains store inventory data or item data
        if (data.isNotEmpty) {
          final firstItem = data.first;

          if (firstItem.containsKey('quantity') && firstItem.containsKey('item_name')) {
            // This is store inventory data
            parsedData = data.map((json) => StoreInventory.fromJson(json)).toList();
          } else {
            // This is item data
            parsedData = data.map((json) => Item.fromJson(json)).toList();
          }
        }

        return PaginatedResponse(
          results: parsedData,
          count: count,
          next: next,
          previous: previous,
        );
      } else {
        throw Exception('Failed to fetch items');
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

  Future<int> getTotalItemsCount() async {
    try {
      final response = await _apiClient.get('/items/', queryParameters: {'page': '1'});

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

  Future<Item> getItem(int id) async {
    try {
      final response = await _apiClient.get('/items/$id/');
      
      if (response.statusCode == 200) {
        return Item.fromJson(response.data);
      } else {
        throw Exception('Failed to fetch item');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Item not found');
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Item> createItem({
    required String name,
    String? description,
    required String sku,
    String? hsnCode,
    required String unit,
    required double price,
    required double taxRate,
    required List<int> companies,
  }) async {
    try {
      final response = await _apiClient.post('/items/', data: {
        'name': name,
        'description': description,
        'sku': sku,
        'hsn_code': hsnCode,
        'unit': unit,
        'price': price,
        'tax_rate': taxRate,
        'companies': companies,
      });

      if (response.statusCode == 201) {
        return Item.fromJson(response.data);
      } else {
        throw Exception('Failed to create item');
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
        throw Exception('Invalid item data');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Item> updateItem({
    required int id,
    required String name,
    String? description,
    required String sku,
    String? hsnCode,
    required String unit,
    required double price,
    required double taxRate,
    required List<int> companies,
  }) async {
    try {
      final response = await _apiClient.patch('/items/$id/', data: {
        'name': name,
        'description': description,
        'sku': sku,
        'hsn_code': hsnCode,
        'unit': unit,
        'price': price,
        'tax_rate': taxRate,
        'companies': companies,
      });

      if (response.statusCode == 200) {
        return Item.fromJson(response.data);
      } else {
        throw Exception('Failed to update item');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid item data');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Item not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<void> deleteItem(int id) async {
    try {
      final response = await _apiClient.delete('/items/$id/');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete item');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Item not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<List<StoreInventory>> getStoreInventory(int storeId) async {
    try {
      final response = await _apiClient.get('/items/inventory/store/$storeId/');

      if (response.statusCode == 200) {
        // New endpoint returns paginated response with 'results'
        final List<dynamic> data = response.data is Map && response.data.containsKey('results')
            ? response.data['results']
            : (response.data is List ? response.data : []);
        final inventory = data.map((json) => StoreInventory.fromJson(json)).toList();
        return inventory;
      } else {
        throw Exception('Failed to fetch store inventory');
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

  Future<PaginatedResponse<StoreInventory>> getStoreInventoryPaginated({
    required int storeId,
    int page = 1,
    int pageSize = 100,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.get(
        '/items/inventory/store/$storeId/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        final List<dynamic> data = responseData['results'] ?? [];
        final int count = responseData['count'] ?? data.length;
        final String? next = responseData['next'];
        final String? previous = responseData['previous'];

        final inventory = data.map((json) => StoreInventory.fromJson(json)).toList();

        return PaginatedResponse(
          results: inventory,
          count: count,
          next: next,
          previous: previous,
        );
      } else {
        throw Exception('Failed to fetch store inventory');
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

  Future<StoreInventory> updateInventory({
    required int id,
    required double quantity,
    required double minStockLevel,
    required double maxStockLevel,
  }) async {
    try {
      final response = await _apiClient.patch('/items/inventory/$id/', data: {
        'quantity': quantity,
        'min_stock_level': minStockLevel,
        'max_stock_level': maxStockLevel,
      });

      if (response.statusCode == 200) {
        return StoreInventory.fromJson(response.data);
      } else {
        throw Exception('Failed to update inventory');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Invalid inventory data');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Inventory record not found');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<StoreInventory> createStoreInventory({
    required int itemId,
    required int storeId,
    required int companyId,
    double quantity = 0.0,
    double minStockLevel = 0.0,
    double maxStockLevel = 0.0,
  }) async {
    try {
      final response = await _apiClient.post('/items/inventory/', data: {
        'item': itemId,
        'store': storeId,
        'company': companyId,
        'quantity': quantity,
        'min_stock_level': minStockLevel,
        'max_stock_level': maxStockLevel,
      });

      if (response.statusCode == 201) {
        return StoreInventory.fromJson(response.data);
      } else {
        throw Exception('Failed to create store inventory');
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
        throw Exception('Invalid inventory data');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  // Admin stock management methods
  Future<Map<String, dynamic>> getAdminStoreStock(
    int storeId, {
    int page = 1,
    int pageSize = 100,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.get(
        '/items/admin/store/$storeId/stock/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch store stock');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied. Admin permissions required.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Store not found or access denied.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Map<String, dynamic>> adminAddStock({
    required int itemId,
    required int storeId,
    required int companyId,
    required double quantity,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post('/items/admin/add-stock/', data: {
        'item_id': itemId,
        'store_id': storeId,
        'company_id': companyId,
        'quantity': quantity,
        'notes': notes ?? 'Stock addition',
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to add stock');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final error = e.response?.data['error'] ?? 'Invalid request data';
        throw Exception(error);
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied. Admin permissions required.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Item or store not found.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Map<String, dynamic>> adminUpdateStock({
    required int itemId,
    required int storeId,
    required int companyId,
    required double quantity,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post('/items/admin/update-stock/', data: {
        'item_id': itemId,
        'store_id': storeId,
        'company_id': companyId,
        'quantity': quantity,
        'notes': notes ?? 'Stock adjustment',
      });

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to update stock');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        final error = e.response?.data['error'] ?? 'Invalid request data';
        throw Exception(error);
      } else if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Access denied. Admin permissions required.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Item or store not found.');
      }
      throw Exception('Network error. Please try again.');
    } catch (e) {
      throw Exception('An unexpected error occurred');
    }
  }

  Future<Map<String, dynamic>> getStoreInventoryRaw(
    int storeId, {
    int page = 1,
    int pageSize = 100,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await _apiClient.get(
        '/items/admin/store/$storeId/stock/',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch store inventory');
      }
    } catch (e) {
      throw Exception('Error fetching store inventory: ${e.toString()}');
    }
  }
}