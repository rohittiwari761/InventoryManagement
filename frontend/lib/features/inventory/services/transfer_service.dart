import '../../../core/api/api_client.dart';

class TransferService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> getTransfers() async {
    try {
      final response = await _apiClient.get('/items/transfers/');
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw Exception('Failed to fetch transfers');
      }
    } catch (e) {
      throw Exception('Error fetching transfers: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> getTransferHistory() async {
    try {
      final response = await _apiClient.get('/items/transfers/history/');
      
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      } else {
        throw Exception('Failed to fetch transfer history');
      }
    } catch (e) {
      throw Exception('Error fetching transfer history: ${e.toString()}');
    }
  }

  Future<bool> createTransfer({
    required int itemId,
    required int companyId,
    required int fromStoreId,
    required int toStoreId,
    required double quantity,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '/items/transfers/',
        data: {
          'item': itemId,
          'company': companyId,
          'from_store': fromStoreId,
          'to_store': toStoreId,
          'quantity': quantity,
          'notes': notes,
        },
      );

      return response.statusCode == 201;
    } catch (e) {
      throw Exception('Error creating transfer: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> createBatchTransfer({
    required int fromStoreId,
    required int toStoreId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '/items/transfers/batch/',
        data: {
          'from_store_id': fromStoreId,
          'to_store_id': toStoreId,
          'items': items,
          'notes': notes,
        },
      );

      if (response.statusCode == 201) {
        return response.data;
      } else {
        throw Exception('Failed to create batch transfer');
      }
    } catch (e) {
      throw Exception('Error creating batch transfer: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> getTransferDetail(int transferId) async {
    try {
      final response = await _apiClient.get('/items/transfers/$transferId/');
      
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to fetch transfer details');
      }
    } catch (e) {
      throw Exception('Error fetching transfer details: ${e.toString()}');
    }
  }
}