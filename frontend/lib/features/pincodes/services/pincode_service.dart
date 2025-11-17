import '../../../core/api/api_client.dart';

class PinCodeService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>?> lookupPinCode(String pincode) async {
    try {
      if (pincode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pincode)) {
        throw Exception('Invalid PIN code format. Must be 6 digits.');
      }

      final response = await _apiClient.get('/pincodes/lookup/$pincode/');
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Failed to lookup PIN code');
        }
      } else if (response.statusCode == 404) {
        throw Exception('PIN code not found');
      } else {
        throw Exception('Failed to lookup PIN code');
      }
    } catch (e) {
      throw Exception('Error looking up PIN code: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>?> lookupPinCodePost(String pincode) async {
    try {
      if (pincode.length != 6 || !RegExp(r'^\d{6}$').hasMatch(pincode)) {
        throw Exception('Invalid PIN code format. Must be 6 digits.');
      }

      final response = await _apiClient.post(
        '/pincodes/lookup/',
        data: {'pincode': pincode},
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data['data'];
        } else {
          throw Exception(data['error'] ?? 'Failed to lookup PIN code');
        }
      } else if (response.statusCode == 404) {
        final data = response.data;
        throw Exception(data['error'] ?? 'PIN code not found');
      } else {
        throw Exception('Failed to lookup PIN code');
      }
    } catch (e) {
      throw Exception('Error looking up PIN code: ${e.toString()}');
    }
  }
}