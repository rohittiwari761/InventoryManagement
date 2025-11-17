import 'package:flutter/foundation.dart';
import '../../../shared/models/item.dart';
import '../services/inventory_service.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryService _inventoryService = InventoryService();

  List<Item> _items = [];
  List<StoreInventory> _storeInventory = [];
  Map<int, List<StoreInventory>> _storeInventoryByStore = {}; // Cache inventory by store ID
  Item? _selectedItem;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination state for items list
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasMore = true;
  String? _currentSearch;

  // Pagination state for store inventory
  Map<int, int> _storeInventoryPages = {}; // Store ID -> current page
  Map<int, int> _storeInventoryTotalCounts = {}; // Store ID -> total count
  Map<int, bool> _storeInventoryHasMore = {}; // Store ID -> has more
  Map<int, bool> _storeInventoryIsLoadingMore = {}; // Store ID -> is loading more
  Map<int, String?> _storeInventorySearch = {}; // Store ID -> search query
  int? _currentStoreId;

  List<Item> get items => _items;
  List<StoreInventory> get storeInventory => _storeInventory;
  Item? get selectedItem => _selectedItem;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  int get totalCount => _totalCount;
  bool get hasMore => _hasMore;
  int get currentPage => _currentPage;

  // Store inventory pagination getters
  bool getStoreInventoryHasMore(int storeId) => _storeInventoryHasMore[storeId] ?? true;
  bool getStoreInventoryIsLoadingMore(int storeId) => _storeInventoryIsLoadingMore[storeId] ?? false;
  int getStoreInventoryTotalCount(int storeId) => _storeInventoryTotalCounts[storeId] ?? 0;

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

  Future<void> fetchItems({String? search}) async {
    _setLoading(true);
    _setError(null);
    _currentPage = 1;
    _currentSearch = search;

    try {
      final response = await _inventoryService.getItemsOrInventoryPaginated(
        page: 1,
        search: search,
      );

      // Separate items and store inventory data
      _items = response.results.whereType<Item>().toList();
      _storeInventory = response.results.whereType<StoreInventory>().toList();
      _totalCount = response.count;
      _hasMore = response.hasMore;

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final response = await _inventoryService.getItemsOrInventoryPaginated(
        page: _currentPage + 1,
        search: _currentSearch,
      );

      // Append new items
      _items.addAll(response.results.whereType<Item>());
      _storeInventory.addAll(response.results.whereType<StoreInventory>());
      _currentPage++;
      _hasMore = response.hasMore;

      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      _setError(e.toString());
    }
  }

  Future<void> searchItems(String query) async {
    await fetchItems(search: query);
  }

  Future<int> getTotalItemsCount() async {
    try {
      return await _inventoryService.getTotalItemsCount();
    } catch (e) {
      return _totalCount;
    }
  }

  Future<void> refreshItems() async {
    // Force refresh by clearing cache first
    _items.clear();
    notifyListeners();
    await fetchItems();
  }

  Future<void> fetchItem(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      _selectedItem = await _inventoryService.getItem(id);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> createItem({
    required String name,
    String? description,
    required String sku,
    String? hsnCode,
    required String unit,
    required double price,
    required double taxRate,
    required List<int> companies,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final item = await _inventoryService.createItem(
        name: name,
        description: description,
        sku: sku,
        hsnCode: hsnCode,
        unit: unit,
        price: price,
        taxRate: taxRate,
        companies: companies,
      );
      _items.add(item);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateItem({
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
    _setLoading(true);
    _setError(null);
    try {
      final updatedItem = await _inventoryService.updateItem(
        id: id,
        name: name,
        description: description,
        sku: sku,
        hsnCode: hsnCode,
        unit: unit,
        price: price,
        taxRate: taxRate,
        companies: companies,
      );
      
      final index = _items.indexWhere((i) => i.id == id);
      if (index != -1) {
        _items[index] = updatedItem;
      }
      
      if (_selectedItem?.id == id) {
        _selectedItem = updatedItem;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteItem(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _inventoryService.deleteItem(id);
      _items.removeWhere((i) => i.id == id);
      
      if (_selectedItem?.id == id) {
        _selectedItem = null;
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> fetchStoreInventory(int storeId, {String? search}) async {
    _setLoading(true);
    _setError(null);
    _currentStoreId = storeId;
    _storeInventoryPages[storeId] = 1;
    _storeInventorySearch[storeId] = search;

    try {
      final response = await _inventoryService.getStoreInventoryPaginated(
        storeId: storeId,
        page: 1,
        search: search,
      );

      _storeInventoryByStore[storeId] = response.results;
      _storeInventoryTotalCounts[storeId] = response.count;
      _storeInventoryHasMore[storeId] = response.hasMore;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> loadMoreStoreInventory(int storeId) async {
    if (_storeInventoryIsLoadingMore[storeId] == true ||
        _storeInventoryHasMore[storeId] == false) {
      return;
    }

    _storeInventoryIsLoadingMore[storeId] = true;
    notifyListeners();

    try {
      final currentPage = _storeInventoryPages[storeId] ?? 1;
      final searchQuery = _storeInventorySearch[storeId];

      final response = await _inventoryService.getStoreInventoryPaginated(
        storeId: storeId,
        page: currentPage + 1,
        search: searchQuery,
      );

      // Append new items to existing list
      final existingList = _storeInventoryByStore[storeId] ?? [];
      _storeInventoryByStore[storeId] = [...existingList, ...response.results];
      _storeInventoryPages[storeId] = currentPage + 1;
      _storeInventoryHasMore[storeId] = response.hasMore;

      _storeInventoryIsLoadingMore[storeId] = false;
      notifyListeners();
    } catch (e) {
      _storeInventoryIsLoadingMore[storeId] = false;
      _setError(e.toString());
    }
  }

  Future<void> refreshStoreInventory(int storeId) async {
    // Clear cache and refetch
    _storeInventoryByStore.remove(storeId);
    _storeInventoryPages.remove(storeId);
    _storeInventoryTotalCounts.remove(storeId);
    _storeInventoryHasMore.remove(storeId);
    notifyListeners();
    await fetchStoreInventory(storeId);
  }

  Future<void> searchStoreInventory(int storeId, String query) async {
    await fetchStoreInventory(storeId, search: query);
  }

  Future<bool> updateInventory({
    required int id,
    required double quantity,
    required double minStockLevel,
    required double maxStockLevel,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final updatedInventory = await _inventoryService.updateInventory(
        id: id,
        quantity: quantity,
        minStockLevel: minStockLevel,
        maxStockLevel: maxStockLevel,
      );

      // Update in general list
      final index = _storeInventory.indexWhere((inv) => inv.id == id);
      if (index != -1) {
        _storeInventory[index] = updatedInventory;
      }

      // Update in cached store inventory
      final storeId = updatedInventory.store;
      if (_storeInventoryByStore.containsKey(storeId)) {
        final storeIndex = _storeInventoryByStore[storeId]!.indexWhere((inv) => inv.id == id);
        if (storeIndex != -1) {
          _storeInventoryByStore[storeId]![storeIndex] = updatedInventory;
        }
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  void selectItem(Item item) {
    _selectedItem = item;
    notifyListeners();
  }

  void clearSelection() {
    _selectedItem = null;
    notifyListeners();
  }

  Future<bool> createStoreInventory({
    required int itemId,
    required int storeId,
    required int companyId,
    double quantity = 0.0,
    double minStockLevel = 0.0,
    double maxStockLevel = 0.0,
  }) async {
    _setError(null);
    try {
      final storeInventory = await _inventoryService.createStoreInventory(
        itemId: itemId,
        storeId: storeId,
        companyId: companyId,
        quantity: quantity,
        minStockLevel: minStockLevel,
        maxStockLevel: maxStockLevel,
      );

      // Add to general list
      _storeInventory.add(storeInventory);

      // Add to cached store inventory
      if (_storeInventoryByStore.containsKey(storeId)) {
        _storeInventoryByStore[storeId]!.add(storeInventory);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  List<Item> getItemsByCompany(int companyId) {
    return _items.where((item) => item.companies.contains(companyId)).toList();
  }

  List<StoreInventory> getLowStockItems() {
    return _storeInventory.where((inv) => inv.isLowStock).toList();
  }

  List<StoreInventory> getStoreInventory(int storeId) {
    // Check cache first, then fall back to filtering from general list
    if (_storeInventoryByStore.containsKey(storeId)) {
      return _storeInventoryByStore[storeId]!;
    }
    return _storeInventory.where((inv) => inv.store == storeId).toList();
  }

  // Get store inventory for current user's stores
  List<StoreInventory> getCurrentUserInventory(List<int> userStoreIds) {
    return _storeInventory.where((inv) => userStoreIds.contains(inv.store)).toList();
  }

  // Check if user has any inventory data
  bool hasStoreInventory() {
    return _storeInventory.isNotEmpty;
  }

  // Get total quantity across all stores for an item
  double getTotalQuantityForItem(int itemId) {
    return _storeInventory
        .where((inv) => inv.item == itemId)
        .fold(0.0, (sum, inv) => sum + inv.quantity);
  }

  Future<List<Map<String, dynamic>>> getStoreInventoryForTransfer(int storeId) async {
    try {
      final response = await _inventoryService.getStoreInventoryRaw(storeId);
      return List<Map<String, dynamic>>.from(response['inventory']);
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  void clear() {
    _items = [];
    _storeInventory = [];
    _storeInventoryByStore.clear();
    _selectedItem = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}