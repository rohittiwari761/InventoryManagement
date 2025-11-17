import 'package:flutter/foundation.dart';
import '../../../shared/models/store.dart';
import '../services/store_service.dart';

class StoreProvider extends ChangeNotifier {
  final StoreService _storeService = StoreService();
  
  List<Store> _stores = [];
  Store? _selectedStore;
  bool _isLoading = false;
  String? _errorMessage;

  List<Store> get stores => _stores;
  Store? get selectedStore => _selectedStore;
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

  Future<void> fetchStores() async {
    _setLoading(true);
    _setError(null);
    try {
      _stores = await _storeService.getStores();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> fetchStore(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      _selectedStore = await _storeService.getStore(id);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createStore({
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    String? email,
    required int company,
    int? manager,
    bool isActive = true,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final store = await _storeService.createStore(
        name: name,
        description: description,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        phone: phone,
        email: email,
        company: company,
        manager: manager,
        isActive: isActive,
      );
      _stores.add(store);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateStore({
    required int id,
    required String name,
    String? description,
    required String address,
    required String city,
    required String state,
    required String pincode,
    required String phone,
    String? email,
    required int company,
    int? manager,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedStore = await _storeService.updateStore(
        id: id,
        name: name,
        description: description,
        address: address,
        city: city,
        state: state,
        pincode: pincode,
        phone: phone,
        email: email,
        company: company,
        manager: manager,
        isActive: isActive,
      );
      
      final index = _stores.indexWhere((s) => s.id == id);
      if (index != -1) {
        _stores[index] = updatedStore;
      }
      
      if (_selectedStore?.id == id) {
        _selectedStore = updatedStore;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteStore(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _storeService.deleteStore(id);
      _stores.removeWhere((s) => s.id == id);
      
      if (_selectedStore?.id == id) {
        _selectedStore = null;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  void selectStore(Store store) {
    _selectedStore = store;
    notifyListeners();
  }

  void clearSelection() {
    _selectedStore = null;
    notifyListeners();
  }

  List<Store> getStoresByCompany(int companyId) {
    return _stores.where((store) => store.company == companyId).toList();
  }

  void clear() {
    _stores = [];
    _selectedStore = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}