import '../../../core/api/api_client.dart';
import '../../../shared/models/invoice_settings.dart';

/// Service for managing invoice settings
class InvoiceSettingsService {
  final ApiClient _apiClient = ApiClient();

  /// Get current user's invoice settings
  Future<InvoiceSettings> getInvoiceSettings() async {
    try {
      final response = await _apiClient.get('/auth/invoice-settings/');

      if (response.statusCode == 200) {
        final data = response.data;
        return InvoiceSettings.fromJson(data);
      } else if (response.statusCode == 404) {
        // Settings not found, return defaults
        return InvoiceSettings.defaults();
      } else {
        throw Exception('Failed to load invoice settings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading invoice settings: $e');
    }
  }

  /// Update user's invoice settings
  Future<InvoiceSettings> updateInvoiceSettings(InvoiceSettings settings) async {
    try {
      final response = await _apiClient.put(
        '/auth/invoice-settings/',
        data: settings.toJson(),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // API returns { message: '...', settings: {...} }
        if (data['settings'] != null) {
          return InvoiceSettings.fromJson(data['settings']);
        } else {
          return InvoiceSettings.fromJson(data);
        }
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update invoice settings');
      }
    } catch (e) {
      throw Exception('Error updating invoice settings: $e');
    }
  }

  /// Partial update of invoice settings
  Future<InvoiceSettings> patchInvoiceSettings(Map<String, dynamic> updates) async {
    try {
      final response = await _apiClient.patch(
        '/auth/invoice-settings/',
        data: updates,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['settings'] != null) {
          return InvoiceSettings.fromJson(data['settings']);
        } else {
          return InvoiceSettings.fromJson(data);
        }
      } else {
        final error = response.data;
        throw Exception(error['detail'] ?? 'Failed to update invoice settings');
      }
    } catch (e) {
      throw Exception('Error updating invoice settings: $e');
    }
  }
}
