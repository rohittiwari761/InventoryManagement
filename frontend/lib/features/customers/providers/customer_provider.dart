import 'package:flutter/foundation.dart';
import '../../../shared/models/customer.dart';
import '../services/customer_service.dart';

class CustomerProvider extends ChangeNotifier {
  final CustomerService _customerService = CustomerService();

  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;
  String? _errorMessage;

  List<Customer> get customers => _customers;
  Customer? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<void> fetchCustomers() async {
    _setLoading(true);
    _setError(null);
    try {
      _customers = await _customerService.getCustomers();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> fetchCustomer(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      _selectedCustomer = await _customerService.getCustomer(id);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<Customer?> createCustomer({
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
    _setLoading(true);
    _setError(null);
    try {
      final customer = await _customerService.createCustomer(
        name: name,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        country: country,
        gstin: gstin,
        phone: phone,
        email: email,
        website: website,
        contactPerson: contactPerson,
        pan: pan,
        isActive: isActive,
      );
      
      // Add to local list
      _customers.add(customer);
      _setLoading(false);
      return customer;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  Future<bool> updateCustomer({
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
    _setLoading(true);
    _setError(null);
    try {
      final updatedCustomer = await _customerService.updateCustomer(
        id: id,
        name: name,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        country: country,
        gstin: gstin,
        phone: phone,
        email: email,
        website: website,
        contactPerson: contactPerson,
        pan: pan,
        isActive: isActive,
      );
      
      // Update local list
      final index = _customers.indexWhere((customer) => customer.id == id);
      if (index != -1) {
        _customers[index] = updatedCustomer;
      }
      
      // Update selected customer if it's the same
      if (_selectedCustomer?.id == id) {
        _selectedCustomer = updatedCustomer;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteCustomer(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _customerService.deleteCustomer(id);
      
      // Remove from local list
      _customers.removeWhere((customer) => customer.id == id);
      
      // Clear selected customer if it's the same
      if (_selectedCustomer?.id == id) {
        _selectedCustomer = null;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> searchCustomers(String query) async {
    _setLoading(true);
    _setError(null);
    try {
      _customers = await _customerService.searchCustomers(query);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Customer? getCustomerById(int id) {
    try {
      return _customers.firstWhere((customer) => customer.id == id);
    } catch (e) {
      return null;
    }
  }

  void clearSelectedCustomer() {
    _selectedCustomer = null;
    notifyListeners();
  }

  void clear() {
    _customers.clear();
    _selectedCustomer = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}