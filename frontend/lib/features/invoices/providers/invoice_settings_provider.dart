import 'package:flutter/material.dart';
import '../../../shared/models/invoice_settings.dart';
import '../services/invoice_settings_service.dart';

/// Provider for managing invoice settings state
class InvoiceSettingsProvider with ChangeNotifier {
  final InvoiceSettingsService _settingsService = InvoiceSettingsService();

  InvoiceSettings? _settings;
  bool _isLoading = false;
  String? _errorMessage;

  InvoiceSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSettings => _settings != null;

  /// Load invoice settings from API
  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    // Don't notify before async operation to avoid build-time setState

    try {
      _settings = await _settingsService.getInvoiceSettings();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      // Use defaults on error
      _settings = InvoiceSettings.defaults();
      notifyListeners();
    }
  }

  /// Save invoice settings to API
  Future<bool> saveSettings(InvoiceSettings settings) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _settingsService.updateInvoiceSettings(settings);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update specific settings fields
  Future<bool> updateSettings(Map<String, dynamic> updates) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await _settingsService.patchInvoiceSettings(updates);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Get default tax rate
  double get defaultTaxRate => _settings?.invoiceDefaultTaxRate ?? 18.0;

  /// Get default payment terms in days
  int get defaultPaymentTerms => _settings?.invoiceDefaultPaymentTerms ?? 30;

  /// Get default validity days
  int get defaultValidityDays => _settings?.invoiceValidityDays ?? 30;

  /// Get default terms and conditions
  String get defaultTermsAndConditions =>
      _settings?.invoiceTermsAndConditions ??
      '1. Goods once sold will not be taken back.\n2. Interest @ 18% p.a. will be charged on delayed payments.\n3. Subject to jurisdiction only.\n4. All disputes subject to arbitration only.';

  /// Get invoice number format preview
  String getInvoiceNumberPreview({int sequence = 1, String? storeCode}) {
    if (_settings == null) return 'INV/S01/2025-26/0001';

    final year = DateTime.now().year;
    final financialYear = DateTime.now().month >= 4
        ? '$year-${(year + 1).toString().substring(2)}'
        : '${year - 1}-${year.toString().substring(2)}';

    final sequenceStr = sequence.toString().padLeft(_settings!.invoiceSequencePadding, '0');

    final parts = <String>[
      _settings!.invoiceNumberPrefix,
      if (storeCode != null) storeCode,
    ];

    if (_settings!.invoiceResetFrequency == 'yearly') {
      parts.add(financialYear);
    } else if (_settings!.invoiceResetFrequency == 'monthly') {
      final month = DateTime.now().month.toString().padLeft(2, '0');
      parts.add('$year$month');
    }

    parts.add(sequenceStr);

    return parts.join(_settings!.invoiceNumberSeparator);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
