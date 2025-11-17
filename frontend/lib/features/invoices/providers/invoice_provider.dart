import 'package:flutter/foundation.dart';
import '../../../shared/models/invoice.dart';
import '../../../shared/utils/error_handler.dart';
import '../services/invoice_service.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceService _invoiceService = InvoiceService();

  List<Invoice> _invoices = [];
  Invoice? _selectedInvoice;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};

  // Pagination state
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true;
  String? _currentSearch;
  int? _currentStoreId;
  String? _currentStatus;

  // Cached calculations
  List<Invoice>? _cachedDraftInvoices;
  List<Invoice>? _cachedSentInvoices;
  List<Invoice>? _cachedPaidInvoices;
  List<Invoice>? _cachedOverdueInvoices;
  double? _cachedTotalRevenue;
  double? _cachedPendingAmount;
  double? _cachedOverdueAmount;
  double? _cachedTotalGST;
  int? _cachedCurrentFYInvoices;

  List<Invoice> get invoices => _invoices;
  Invoice? get selectedInvoice => _selectedInvoice;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get stats => _stats;
  int get totalCount => _totalCount;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _invalidateCache() {
    _cachedDraftInvoices = null;
    _cachedSentInvoices = null;
    _cachedPaidInvoices = null;
    _cachedOverdueInvoices = null;
    _cachedTotalRevenue = null;
    _cachedPendingAmount = null;
    _cachedOverdueAmount = null;
    _cachedTotalGST = null;
    _cachedCurrentFYInvoices = null;
  }

  Future<void> fetchInvoices({int? storeId, String? search, String? status}) async {
    _setLoading(true);
    _setError(null);
    _currentPage = 1;
    _currentSearch = search;
    _currentStoreId = storeId;
    _currentStatus = status;

    try {
      final response = await _invoiceService.getInvoicesPaginated(
        page: 1,
        storeId: storeId,
        search: search,
        status: status,
      );

      _invoices = response.results;
      _totalCount = response.count;
      _hasMore = response.hasMore;

      _invalidateCache(); // Clear cache when data changes
      if (kDebugMode) {
        debugPrint('Fetched ${_invoices.length} invoices (total: $_totalCount)');
        debugPrint('Invoice statuses: ${_invoices.map((inv) => inv.status).toList()}');
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> loadMoreInvoices() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final response = await _invoiceService.getInvoicesPaginated(
        page: _currentPage + 1,
        storeId: _currentStoreId,
        search: _currentSearch,
        status: _currentStatus,
      );

      // Append new invoices
      _invoices.addAll(response.results);
      _currentPage++;
      _hasMore = response.hasMore;

      _invalidateCache(); // Clear cache when data changes
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _setError(e.toString());
    }
  }

  Future<void> searchInvoices(String query, {int? storeId, String? status}) async {
    await fetchInvoices(storeId: storeId, search: query, status: status);
  }

  Future<int> getTotalInvoicesCount({int? storeId}) async {
    try {
      return await _invoiceService.getTotalInvoicesCount(storeId: storeId);
    } catch (e) {
      return _totalCount;
    }
  }

  Future<void> refreshInvoices() async {
    // Force refresh by clearing cache first
    _invoices.clear();
    notifyListeners();
    await fetchInvoices(
      storeId: _currentStoreId,
      search: _currentSearch,
      status: _currentStatus,
    );
  }

  Future<void> fetchInvoice(int id) async {
    if (kDebugMode) {
      debugPrint('Fetching invoice $id');
    }
    _setLoading(true);
    _setError(null);
    try {
      _selectedInvoice = await _invoiceService.getInvoice(id);
      if (kDebugMode) {
        debugPrint('Invoice $id fetched successfully');
      }
      _setLoading(false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching invoice $id: $e');
      }
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<Invoice?> createInvoice({
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
    _setLoading(true);
    _setError(null);
    try {
      final invoice = await _invoiceService.createInvoice(
        companyId: companyId,
        storeId: storeId,
        customerName: customerName,
        customerAddress: customerAddress,
        customerCity: customerCity,
        customerState: customerState,
        customerPincode: customerPincode,
        customerGstin: customerGstin,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        items: items,
        notes: notes,
        termsAndConditions: termsAndConditions,
        dueDate: dueDate,
        invoiceDate: invoiceDate,
        includeLogistics: includeLogistics,
        driverName: driverName,
        driverPhone: driverPhone,
        vehicleNumber: vehicleNumber,
        transportCompany: transportCompany,
        lrNumber: lrNumber,
        dispatchDate: dispatchDate,
      );
      _invoices.insert(0, invoice); // Add to beginning of list
      _setLoading(false);
      return invoice;
    } catch (e) {
      final appError = ErrorHandler.parseError(e);
      _setError(appError.userMessage);
      _setLoading(false);
      rethrow; // Re-throw so the UI can handle it with full context
    }
  }

  Future<bool> updateInvoice({
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
    _setLoading(true);
    _setError(null);
    try {
      final updatedInvoice = await _invoiceService.updateInvoice(
        id: id,
        customerName: customerName,
        customerAddress: customerAddress,
        customerGstin: customerGstin,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        items: items,
        notes: notes,
        dueDate: dueDate,
        status: status,
        includeLogistics: includeLogistics,
        driverName: driverName,
        driverPhone: driverPhone,
        vehicleNumber: vehicleNumber,
        transportCompany: transportCompany,
        lrNumber: lrNumber,
        dispatchDate: dispatchDate,
      );

      final index = _invoices.indexWhere((inv) => inv.id == id);
      if (index != -1) {
        _invoices[index] = updatedInvoice;
      }

      if (_selectedInvoice?.id == id) {
        _selectedInvoice = updatedInvoice;
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteInvoice(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _invoiceService.deleteInvoice(id);
      _invoices.removeWhere((inv) => inv.id == id);

      if (_selectedInvoice?.id == id) {
        _selectedInvoice = null;
      }

      // Invalidate cached stats so they recalculate with updated invoice list
      _invalidateCache();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<List<int>?> generateInvoicePdf(int id) async {
    try {
      return await _invoiceService.generateInvoicePdf(id);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<bool> sendInvoiceEmail(int id, String emailAddress) async {
    try {
      await _invoiceService.sendInvoiceEmail(id, emailAddress);
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<void> fetchInvoiceStats({int? storeId}) async {
    try {
      _stats = await _invoiceService.getInvoiceStats(storeId: storeId);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  void selectInvoice(Invoice invoice) {
    _selectedInvoice = invoice;
    notifyListeners();
  }

  void clearSelection() {
    _selectedInvoice = null;
    notifyListeners();
  }

  // Filtered getters with proper caching
  List<Invoice> get draftInvoices {
    _cachedDraftInvoices ??= _invoices
        .where((inv) => inv.status == InvoiceStatus.draft)
        .toList();
    return _cachedDraftInvoices!;
  }
  
  List<Invoice> get sentInvoices {
    _cachedSentInvoices ??= _invoices
        .where((inv) => inv.status == InvoiceStatus.sent)
        .toList();
    return _cachedSentInvoices!;
  }
  
  List<Invoice> get paidInvoices {
    _cachedPaidInvoices ??= _invoices
        .where((inv) => inv.status == InvoiceStatus.paid)
        .toList();
    return _cachedPaidInvoices!;
  }
  
  List<Invoice> get overdueInvoices {
    _cachedOverdueInvoices ??= _invoices
        .where((inv) => inv.status == InvoiceStatus.overdue)
        .toList();
    return _cachedOverdueInvoices!;
  }

  // Summary calculations - use backend stats if available, otherwise calculate from loaded invoices
  double get totalRevenue {
    // Prefer backend stats for accuracy across all invoices
    if (_stats.isNotEmpty && _stats.containsKey('total_revenue')) {
      return (_stats['total_revenue'] as num).toDouble();
    }
    // Fallback to client-side calculation from loaded invoices
    _cachedTotalRevenue ??= paidInvoices
        .fold<double>(0.0, (double sum, Invoice inv) => sum + inv.totalAmount);
    return _cachedTotalRevenue!;
  }

  double get pendingAmount {
    // Prefer backend stats for accuracy
    if (_stats.isNotEmpty && _stats.containsKey('pending_amount')) {
      return (_stats['pending_amount'] as num).toDouble();
    }
    // Fallback to client-side calculation
    _cachedPendingAmount ??= sentInvoices
        .fold<double>(0.0, (double sum, Invoice inv) => sum + inv.totalAmount);
    return _cachedPendingAmount!;
  }

  double get overdueAmount {
    // Note: Backend doesn't have overdue status, so this remains client-side
    _cachedOverdueAmount ??= overdueInvoices
        .fold<double>(0.0, (double sum, Invoice inv) => sum + inv.totalAmount);
    return _cachedOverdueAmount!;
  }

  double get totalGST {
    // Prefer backend stats for accuracy - total_tax_collected from all paid invoices
    if (_stats.isNotEmpty && _stats.containsKey('total_tax_collected')) {
      return (_stats['total_tax_collected'] as num).toDouble();
    }
    // Fallback to client-side calculation from loaded invoices
    _cachedTotalGST ??= paidInvoices
        .fold<double>(0.0, (double sum, Invoice inv) => sum + inv.totalTaxAmount);
    return _cachedTotalGST!;
  }

  int get currentFYInvoicesCount {
    if (_cachedCurrentFYInvoices == null) {
      final currentFY = _getCurrentFinancialYear();
      _cachedCurrentFYInvoices = _invoices.where((inv) => inv.financialYear == currentFY).length;
    }
    return _cachedCurrentFYInvoices!;
  }

  String _getCurrentFinancialYear() {
    final now = DateTime.now();
    final startYear = now.month >= 4 ? now.year : now.year - 1;
    final endYear = startYear + 1;
    return 'FY $startYear-${endYear.toString().substring(2)}';
  }

  int get totalInvoicesCount => _invoices.length;
  int get paidInvoicesCount => paidInvoices.length;
  int get pendingInvoicesCount => sentInvoices.length;
  int get overdueInvoicesCount => overdueInvoices.length;

  void clear() {
    _invoices = [];
    _selectedInvoice = null;
    _isLoading = false;
    _errorMessage = null;
    _stats = {};
    _invalidateCache();
    notifyListeners();
  }
}
